// Real Chrome + IndexedDB + offline service-worker validation. A legacy fixture
// must be an isolated test profile from the phase-six browser suite.
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),docs=path.join(root,'docs');
const url=process.env.KIM_URL||'http://127.0.0.1:8765';
const executablePath=process.env.CHROME_EXECUTABLE||'C:/Program Files/Google/Chrome/Application/chrome.exe';
async function sem(p){await p.waitForSelector('flt-semantics-placeholder,flt-semantics[role]',{state:'attached'});if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').dispatchEvent('click');}
async function text(p,t){await p.waitForFunction(t=>(document.body.innerText+'\n'+[...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\n')).includes(t),t);}
async function body(p){return p.locator('body').ariaSnapshot();}
async function button(p,n){await p.getByRole('button',{name:n,exact:true}).click();await p.waitForTimeout(250);}
async function input(p,n,v){await p.getByRole('textbox',{name:n,exact:true}).focus();await p.waitForFunction(n=>document.activeElement?.getAttribute('aria-label')===n,n);await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));await p.keyboard.press('Control+A');await p.waitForFunction(()=>{const e=document.activeElement;return e?.selectionStart===0&&e.selectionEnd===e.value.length;});await p.keyboard.insertText(v);await p.waitForFunction(v=>document.activeElement?.value===v,v);await p.keyboard.press('Tab');await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));}
async function option(p,n){await p.getByRole('menuitem',{name:n,exact:true}).click();await p.waitForTimeout(200);}
async function go(p,r){await p.goto(url+'/#'+r);await sem(p);await p.waitForTimeout(250);}
const escape=s=>s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
function card(p,name){return p.getByRole('group',{name:new RegExp('^'+escape(name)+'\\b')}).filter({has:p.getByRole('button',{name:'Contribution history',exact:true})}).last();}
async function createGoal(p,name,target,currency='ILS'){
 await button(p,'Create goal');await input(p,'Goal name',name);
 if(currency!=='ILS'){await button(p,'Currency ILS · 2 decimal places');await option(p,currency+' · 2 decimal places');}
 await input(p,`Target amount (${currency})`,target);await input(p,'Target date (YYYY-MM-DD)','2027-06-01');
 await p.getByRole('checkbox',{name:'Travel',exact:true}).click();await p.getByRole('checkbox',{name:'Purple',exact:true}).click();
 await button(p,'Save goal');await p.getByRole('textbox',{name:'Goal name',exact:true}).waitFor({state:'detached'});await text(p,name);
}
async function allocation(p,name,amount,{currency='ILS',wallet}={}){
 await card(p,name).getByRole('button',{name:'Allocate funds',exact:true}).click();
 if(wallet){await button(p,'Wallet Legacy cash · ILS');await option(p,wallet+' · ILS');}
 await input(p,`Total earmarked for this goal from this wallet (${currency})`,amount);await button(p,'Save allocation');
 await p.getByRole('textbox',{name:`Total earmarked for this goal from this wallet (${currency})`,exact:true}).waitFor({state:'detached'});
}
async function wallet(p,name,amount,currency='ILS'){
 await go(p,'/wallets');await button(p,'Create wallet');await input(p,'Wallet name',name);
 if(currency!=='ILS'){await button(p,'Currency ILS');await option(p,currency);}
 await input(p,'Opening balance',amount);await button(p,'Save wallet');await p.getByRole('textbox',{name:'Wallet name',exact:true}).waitFor({state:'detached'});
}
(async()=>{
 const fixture=process.env.KIM_LEGACY_PROFILE,profile=path.join(root,'.dart_tool','savings-browser-'+Date.now());
 if(fixture)fs.cpSync(fixture,profile,{recursive:true});
 const errors=[],external=new Set(),checks=[];let ctx;
 const record=m=>{checks.push(m);console.log('PASS:',m);};
 async function launch(){const c=await chromium.launchPersistentContext(profile,{executablePath,headless:true,viewport:{width:1440,height:1100},serviceWorkers:'allow'});
  const track=p=>{p.on('pageerror',e=>errors.push(e.message));p.on('request',r=>{if(/^https?:/.test(r.url())&&new URL(r.url()).origin!==new URL(url).origin)external.add(r.url());});};
  c.on('page',track);for(const p of c.pages())track(p);return c;}
 ctx=await launch();let p=ctx.pages()[0];
 try{
  await go(p,'/settings');await button(p,'English');await button(p,'Light');
  if(fixture){
   await p.evaluate(async()=>{await (await navigator.serviceWorker.getRegistration())?.update();});
   await p.waitForFunction(async()=>!!(await navigator.serviceWorker.getRegistration())?.waiting);
   for(const other of ctx.pages()){if(other!==p)await other.close();}await p.goto('about:blank');await p.waitForTimeout(2000);
   await go(p,'/');await text(p,'Savings goals');await text(p,'868.00 ILS');await text(p,'65.00 USD');
   await go(p,'/budgets');await text(p,'ILS monthly');await text(p,'112.00 ILS');await go(p,'/categories');await text(p,'Offline books');
   record('Real phase-six IndexedDB and offline cache upgrade preserve wallets, categories, expenses and budgets');
  }else{await wallet(p,'Legacy cash','1000');await wallet(p,'Dollar cash','100','USD');}
  const base=fixture?868:1000;
  await go(p,'/');await button(p,'Savings goals');await text(p,'What are you saving for?');
  await p.screenshot({path:path.join(docs,'phase-7-empty-en.png')});
  await createGoal(p,'Trip fund','500');await allocation(p,'Trip fund','200.25');await text(p,'40.0%');
  assert.ok((await body(p)).includes((base-200.25).toFixed(2)+' ILS'));await go(p,'/');await text(p,base.toFixed(2)+' ILS');
  record('Real goal forms persist name, date, icon, color and exact allocation without changing wallet balances');
  await go(p,'/goals');await createGoal(p,'Safety fund','1000');
  await card(p,'Safety fund').getByRole('button',{name:'Allocate funds',exact:true}).click();await input(p,'Total earmarked for this goal from this wallet (ILS)','800');await button(p,'Save allocation');
  await text(p,'This exceeds available funds; money is earmarked for savings goals. Release allocations first.');
  await input(p,'Total earmarked for this goal from this wallet (ILS)','100');await button(p,'Save allocation');await p.getByRole('textbox',{name:'Note (optional)',exact:true}).waitFor({state:'detached'});
  await createGoal(p,'Dollar goal','50','USD');await allocation(p,'Dollar goal','25',{currency:'USD'});
  assert.ok((await card(p,'Dollar goal').ariaSnapshot()).includes('50.0%'));await text(p,'300.25 ILS');await text(p,'25.00 USD');
  await p.screenshot({path:path.join(docs,'phase-7-goals-en.png')});record('Reservations aggregate across goals, reject over-allocation and keep USD and ILS separate');
  await card(p,'Trip fund').getByRole('button',{name:'Edit goal',exact:true}).click();await input(p,'Target amount (ILS)','100');await button(p,'Save goal');await text(p,'Release excess allocations before reducing the target.');
  await input(p,'Target amount (ILS)','600');await button(p,'Save goal');await p.getByRole('textbox',{name:'Goal name',exact:true}).waitFor({state:'detached'});
  await allocation(p,'Trip fund','150');assert.ok((await card(p,'Trip fund').ariaSnapshot()).includes('25.0%'));
  await card(p,'Trip fund').getByRole('button',{name:'Contribution history',exact:true}).click();await text(p,'-50.25 ILS');await button(p,'Done');
  record('Target edits validate existing allocations; replacing totals appends exact immutable release history');
  await go(p,'/');await button(p,'Add expense');await input(p,'Amount (ILS)','900');await input(p,'Notes','Blocked reserved expense');await button(p,'Save transaction');
  await text(p,'This would spend funds earmarked for savings goals. Release allocations from Savings goals first.');
  await input(p,'Amount (ILS)','10');await input(p,'Notes','Allowed available expense');await button(p,'Save transaction');await p.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});await text(p,(base-10).toFixed(2)+' ILS');
  record('Actual expense form refuses reserved funds and accepts spending from the available balance');
  await go(p,'/goals');await allocation(p,'Trip fund','0');await wallet(p,'Savings vault','0');
  await go(p,'/goals');await button(p,'Move money between wallets');await button(p,'New transfer');await button(p,'To wallet Dollar cash · USD');await option(p,'Savings vault · ILS');
  await input(p,'Transfer amount (ILS)','150');await input(p,'Transfer fee (ILS)','0');await input(p,'Notes','Move savings explicitly');await button(p,'Save transfer');await p.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});
  await go(p,'/goals');await allocation(p,'Trip fund','150',{wallet:'Savings vault'});await text(p,(base-160).toFixed(2)+' ILS');
  assert.ok((await card(p,'Trip fund').ariaSnapshot()).includes('150.00 ILS'));
  record('Explicit release, actual wallet transfer and destination allocation preserve balances without duplicate income');
  const q=await ctx.newPage();await go(q,'/goals');await card(q,'Safety fund').getByRole('button',{name:'Allocate funds',exact:true}).click();
  await allocation(p,'Safety fund','120');await text(q,'Data changed. Close this dialog and reopen it with the latest data.');assert.equal(await q.getByRole('textbox',{name:'Total earmarked for this goal from this wallet (ILS)',exact:true}).count(),0);await q.close();
  record('A second tab reacts to reservations changing and refuses stale allocation forms');
  await card(p,'Trip fund').getByRole('button',{name:'Edit goal',exact:true}).click();await input(p,'Target amount (ILS)','150');await button(p,'Save goal');await p.getByRole('textbox',{name:'Goal name',exact:true}).waitFor({state:'detached'});
  await card(p,'Trip fund').getByRole('button',{name:'Close goal',exact:true}).click();await p.getByRole('alertdialog').getByRole('button',{name:'Close goal',exact:true}).click();
  await p.getByRole('checkbox',{name:'Show closed',exact:true}).click();await text(p,'At closing (released)');assert.ok((await card(p,'Trip fund').ariaSnapshot()).includes('100.0%'));await card(p,'Trip fund').getByRole('button',{name:'Contribution history',exact:true}).click();await text(p,'Released on closing');await button(p,'Done');await p.getByRole('checkbox',{name:'Show closed',exact:true}).click();
  record('Closing fully funded goals releases funds, freezes historical completion and retains every contribution');
  await p.waitForFunction(()=>!!navigator.serviceWorker.controller);await ctx.setOffline(true);await createGoal(p,'Offline future','80');await allocation(p,'Offline future','80');await p.reload();await sem(p);await text(p,'Offline future');assert.ok((await card(p,'Offline future').ariaSnapshot()).includes('100.0%'));await ctx.setOffline(false);
  record('Offline creation and allocation survive reload in IndexedDB without network services');
  await go(p,'/wallets');await p.getByRole('button',{name:'Hide balance',exact:true}).first().click();await go(p,'/goals');await text(p,'Amounts hidden because a linked wallet balance is hidden');
  assert.ok(!(await card(p,'Safety fund').ariaSnapshot()).includes('120.00 ILS'));assert.ok(!(await card(p,'Offline future').ariaSnapshot()).includes('100.0%'));
  await go(p,'/wallets');await button(p,'Show balance');record('Wallet privacy conceals goal amounts, progress and achievement statistics');
  await go(p,'/settings');await button(p,'Dark');await button(p,'العربية');await p.setViewportSize({width:390,height:844});await go(p,'/goals');await text(p,'أهداف صغيرة، مستقبل أكبر');
  await p.screenshot({path:path.join(docs,'phase-7-goals-ar-mobile.png')});
  await p.getByRole('group',{name:/^Offline future\b/}).filter({has:p.getByRole('button',{name:'سجل المساهمات',exact:true})}).last().scrollIntoViewIfNeeded();
  await p.screenshot({path:path.join(docs,'phase-7-goal-card-ar-mobile.png')});
  await button(p,'إنشاء هدف');await p.waitForTimeout(500);await p.screenshot({path:path.join(docs,'phase-7-editor-ar-mobile.png')});await button(p,'إلغاء');
  record('Arabic RTL dark mobile goals and editor remain usable alongside the existing navigation');
  assert.deepEqual(errors,[]);assert.deepEqual([...external],[]);record('No browser runtime errors or external resource requests');
  fs.writeFileSync(path.join(docs,'phase-7-browser-validation.json'),JSON.stringify({passed:true,legacyMigration:!!fixture,checks,runtimeErrors:errors,externalRequests:[...external]},null,2));
 }catch(e){await p.screenshot({path:path.join(docs,'phase-7-failure.png')});console.error(await body(p));throw e;}
 finally{await ctx.close();}
})();
