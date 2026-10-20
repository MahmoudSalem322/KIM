// Phase 12 release gate: real production build, real IndexedDB and service
// worker. Measures cold and cached start-up, cache size, offline navigation of
// every route at phone/tablet/desktop widths, and a persisted financial cycle.
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),docs=path.join(root,'docs'),url=process.env.KIM_URL||'http://127.0.0.1:8765';
const chrome=process.env.CHROME_EXECUTABLE||'C:/Program Files/Google/Chrome/Application/chrome.exe';
const routes=['/','/wallets','/transactions','/categories','/transfers','/budgets','/goals','/recurring','/notifications','/debts','/reports','/currencies','/settings'];
const viewports=[{width:320,height:640},{width:768,height:1024},{width:1440,height:900}];
async function sem(p){await p.waitForSelector('flt-semantics-placeholder,flt-semantics[role]',{state:'attached'});if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').dispatchEvent('click');}
const visible=p=>p.evaluate(()=>document.body.innerText+'\n'+[...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\n'));
async function text(p,t){await p.waitForFunction(t=>(document.body.innerText+'\n'+[...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\n')).includes(t),t);}
async function button(p,n){await p.getByRole('button',{name:n,exact:true}).first().click();await p.waitForTimeout(300);}
async function input(p,n,v){const el=p.getByRole('textbox',{name:n,exact:true});await el.focus();await p.waitForFunction(n=>document.activeElement?.getAttribute('aria-label')===n,n);await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));await p.keyboard.press('Control+A');await p.keyboard.insertText(v);await p.waitForFunction(v=>document.activeElement?.value===v,v);await p.keyboard.press('Tab');await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));}
async function go(p,r){await p.goto(url+'/#'+r);await sem(p);await p.waitForTimeout(300);}
async function firstFrame(p){await p.waitForFunction(()=>window.__kimFirstFrame!==undefined,null,{timeout:60000});return Math.round(await p.evaluate(()=>window.__kimFirstFrame));}
async function addTransaction(p,amount,notes,kind){await button(p,'Add transaction');if(kind==='Income')await button(p,'Income');await input(p,'Amount (ILS)',amount);await input(p,'Date','2026-10-20');await input(p,'Notes',notes);await button(p,'Save transaction');await p.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});await text(p,notes);}
(async()=>{
 const errors=[],consoleErrors=[],failed=[],external=new Set(),checks=[],metrics={};let bytes=0,requests=0;
 const ctx=await chromium.launchPersistentContext(path.join(root,'.dart_tool','release-browser-'+Date.now()),{executablePath:chrome,headless:true,viewport:{width:1440,height:900}});
 await ctx.addInitScript(()=>window.addEventListener('flutter-first-frame',()=>{window.__kimFirstFrame=performance.now();}));
 const track=p=>{p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(m.type()==='error')consoleErrors.push(m.text());});p.on('requestfailed',r=>failed.push(`${r.failure()?.errorText} ${r.url()}`));p.on('request',r=>{if(/^https?:/.test(r.url())&&new URL(r.url()).origin!==new URL(url).origin)external.add(r.url());});p.on('requestfinished',async r=>{try{const s=await r.sizes();bytes+=s.responseBodySize;requests++;}catch{}});};
 ctx.on('page',track);let p=ctx.pages()[0];if(p)track(p);else p=await ctx.newPage();
 const record=t=>{checks.push(t);console.log('PASS:',t);};
 try{
  await p.goto(url+'/#/');metrics.coldFirstFrameMs=await firstFrame(p);await sem(p);metrics.coldRequests=requests;metrics.coldTransferMiB=+(bytes/1048576).toFixed(2);
  assert.equal(await p.locator('#loading').count(),0);record(`Cold start renders the first frame in ${metrics.coldFirstFrameMs} ms and removes the HTML loader`);
  await go(p,'/settings');await button(p,'English');await text(p,'Backup & restore');
  await go(p,'/wallets');await button(p,'Create wallet');await input(p,'Wallet name','Release cash');await input(p,'Opening balance','1000.50');await button(p,'Save wallet');await text(p,'1000.50 ILS');
  await go(p,'/transactions');await addTransaction(p,'250','Release salary','Income');await addTransaction(p,'100.25','Release groceries','Expense');
  await go(p,'/wallets');await text(p,'1150.25 ILS');record('Wallet, income and expense created through the UI keep an exact balance');
  await p.reload();await sem(p);await text(p,'1150.25 ILS');record('Exact balance and English preference survive a full reload');
  await p.waitForFunction(()=>!!navigator.serviceWorker.controller,null,{timeout:120000});
  const cache=await p.evaluate(async()=>{let files=0,size=0;for(const key of await caches.keys()){const c=await caches.open(key);for(const req of await c.keys()){files++;size+=(await (await c.match(req)).blob()).size;}}return {files,size};});
  metrics.cachedFiles=cache.files;metrics.cacheMiB=+(cache.size/1048576).toFixed(2);assert.ok(cache.size<30*1048576,'offline cache should stay below 30 MiB');record(`Service worker precached ${cache.files} files (${metrics.cacheMiB} MiB) for offline use`);
  await ctx.setOffline(true);await p.evaluate(()=>{delete window.__kimFirstFrame;});await p.reload();metrics.offlineFirstFrameMs=await firstFrame(p);await sem(p);await text(p,'1150.25 ILS');record(`Offline reload renders cached app in ${metrics.offlineFirstFrameMs} ms with persisted data`);
  for(const vp of viewports){await p.setViewportSize(vp);for(const r of routes){await go(p,r);const shown=await visible(p);assert.ok(!shown.includes('This page does not exist'),`${r} at ${vp.width}px`);}}
  await go(p,'/missing-release-route');await text(p,'This page does not exist');
  record(`All ${routes.length} routes open offline at ${viewports.map(v=>v.width).join('/')}px; unknown routes show the recovery page`);
  await p.setViewportSize({width:1440,height:900});await go(p,'/');await p.screenshot({path:path.join(docs,'phase-12-dashboard-en.png')});
  await go(p,'/settings');await button(p,'Dark');await button(p,'العربية');await p.setViewportSize({width:320,height:640});await go(p,'/wallets');await text(p,'Release cash');await p.screenshot({path:path.join(docs,'phase-12-wallets-ar-320.png')});
  await go(p,'/');await p.screenshot({path:path.join(docs,'phase-12-dashboard-ar-320.png')});await p.setViewportSize({width:768,height:1024});await go(p,'/reports');await p.screenshot({path:path.join(docs,'phase-12-reports-ar-tablet.png')});
  record('Arabic RTL dark theme renders on 320px phones and tablets while offline');
  await ctx.setOffline(false);
  assert.deepEqual(errors,[]);assert.deepEqual(consoleErrors,[]);assert.equal(external.size,0);record('No page exceptions, console errors or external network requests');
  fs.writeFileSync(path.join(docs,'phase-12-browser-validation.json'),JSON.stringify({checks,metrics,errors,consoleErrors,external:[...external]},null,2)+'\n');
  console.log(JSON.stringify(metrics));
 }catch(e){console.error((await p.locator('body').ariaSnapshot().catch(()=>'')).slice(-8000));await p.screenshot({path:path.join(docs,'phase-12-failure.png')}).catch(()=>{});console.error({errors,consoleErrors,failed,external:[...external]});throw e;}finally{await ctx.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
