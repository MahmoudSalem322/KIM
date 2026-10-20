// Test the real release app, real IndexedDB, and two browser tabs. No app mocks.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs'); const path=require('node:path');
const url=process.env.KIM_URL || 'http://127.0.0.1:8765';
const docs=path.resolve(__dirname,'../docs');
async function semantics(page) { await page.waitForSelector('flt-semantics-placeholder,flt-semantics[role]',{state:'attached'}); if(await page.locator('flt-semantics-placeholder').count()) await page.locator('flt-semantics-placeholder').dispatchEvent('click'); }
async function text(page,expected) { await page.waitForFunction(t=>(document.body.innerText+'\n'+[...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\n')).includes(t),expected); }
async function body(page) { return page.locator('body').ariaSnapshot(); }
// Flutter canvas route animations are not represented by DOM actionability.
async function button(page,name) { await page.getByRole('button',{name,exact:true}).click(); await page.waitForTimeout(350); }
async function option(page,name) {await page.getByRole('menuitem',{name,exact:true}).click(); await page.getByRole('menu',{name:'Popup menu',exact:true}).waitFor({state:'detached'}); await page.waitForTimeout(350);}
async function input(page,name,value) {
  // Flutter semantics inputs forward focus to its real text editing input.
  // Use native keyboard/paste events rather than setting the proxy DOM value.
  await page.bringToFront();
  await page.getByRole('textbox',{name,exact:true}).focus();
  await page.waitForFunction(n=>document.activeElement?.getAttribute('aria-label')===n,name);
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await page.keyboard.press('Control+A');
  await page.waitForFunction(()=>{const e=document.activeElement;return e?.selectionStart===0 && e.selectionEnd===e.value.length;});
  await page.keyboard.insertText(value);
  await page.waitForFunction(v=>document.activeElement?.value===v,value);
  await page.keyboard.press('Tab');
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));

}
async function create(page,name,amount,{currency='ILS',type='Cash',color='Emerald',icon='Wallet',customScale=2}={}) {
 await button(page,'Create wallet');
 await input(page,'Wallet name',name);
 if(type!=='Cash') {await button(page,'Wallet type Cash'); await option(page,type);}
 if(currency!=='ILS') {
   await button(page,'Currency ILS'); await option(page,currency.length===3 && currency!=='ABC'?currency:'Custom currency');
   if(currency==='ABC') {await input(page,'Currency code (3 letters)',currency);
     // Flutter focus traversal can open this dropdown when leaving the code field.
     if(!(await page.getByRole('menu',{name:'Popup menu',exact:true}).count())) await button(page,'Decimal places 2'); await option(page,String(customScale));}
 }
 await input(page,'Opening balance',amount);
 await page.getByRole('checkbox',{name:color,exact:true}).click();
 await page.getByRole('checkbox',{name:icon,exact:true}).click();
 await button(page,'Save wallet'); await text(page,name);
 await page.getByRole('textbox',{name:'Wallet name',exact:true}).waitFor({state:'detached'});
}
async function adjust(page,amount,reason) {
 await button(page,'Adjust balance');
 await input(page,'Correct current balance',amount);
 await input(page,'Adjustment reason',reason);
 await button(page,'Record adjustment'); await page.getByRole('textbox',{name:'Adjustment reason',exact:true}).waitFor({state:'detached'});
 await text(page,reason);
}
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE || 'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
 const context=await browser.newContext({viewport:{width:1440,height:1100},serviceWorkers:'allow'});
 const errors=[],external=new Set(),checks=[];
 context.on('page',page=>{page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(/^https?:/.test(r.url()) && new URL(r.url()).origin!==new URL(url).origin) external.add(r.url());});});
 const record=(message)=>{checks.push(message);console.log('PASS:',message);};
 const page=await context.newPage();
 try {
 await page.goto(url); await semantics(page);
 await button(page,'الإعدادات'); await button(page,'English'); await button(page,'Wallets');
 await create(page,'Daily cash','١٠٫٢٥',{color:'Blue',icon:'Cash'});
 record('Create customized wallet with exact Arabic opening amount');
 await page.getByRole('button',{name:'Wallet details',exact:true}).first().click();
 await text(page,'Financial history'); const firstUrl=page.url();
 assert.ok((await body(page)).includes('10.25 ILS')); assert.ok((await body(page)).includes('Opening balance'));
 const openingId=firstUrl.split('/').pop(); assert.match(openingId,/^[a-f0-9-]{36}$/);
 await text(page,openingId); record('Traceable opening entry and persistent detail route');
 await button(page,'Edit wallet');
 assert.equal(await page.getByRole('textbox',{name:'Opening balance',exact:true}).count(),0);
 assert.equal(await page.getByRole('button',{name:/^Currency /}).count(),0);
 await input(page,'Wallet name','Everyday cash');
 await page.getByRole('checkbox',{name:'Rose',exact:true}).click();
 await button(page,'Save wallet'); await text(page,'Everyday cash');
 await text(page,openingId); record('Metadata edits preserve original opening and immutable currency');
 await adjust(page,'11.40','Cash recount');
 const history=await body(page); assert.ok(history.includes('1.15 ILS')); assert.ok(history.includes('10.25 ILS')); assert.ok(history.includes('11.40 ILS'));
 record('Settlement records exact delta before after reason and operation ID');
 await button(page,'Hide balance'); await text(page,'Show balance');
 assert.ok(!(await body(page)).includes('10.25')); assert.ok(!(await body(page)).includes('11.40'));
 await button(page,'Overview'); await text(page,'Amounts hidden for wallet privacy');
 assert.ok(!(await body(page)).includes('11.40')); record('Hidden balances mask detail history and dashboard totals');
 await page.goto(firstUrl); await semantics(page); await button(page,'Show balance'); await text(page,'11.40 ILS');
 await page.reload(); await semantics(page); await text(page,'Everyday cash'); await text(page,'Cash recount');
 record('Wallet edits and ledger survive full reload');
 const other=await context.newPage(); await other.goto(firstUrl); await semantics(other); await text(other,'Everyday cash');
 await button(other,'Adjust balance');
 await button(page,'Hide balance'); await text(other,'Balance hidden');
 assert.equal(await other.getByRole('textbox',{name:'Correct current balance',exact:true}).inputValue(),'');
 assert.ok(!(await body(other)).includes('11.40'));
 await button(other,'Cancel'); await button(page,'Show balance'); await text(other,'11.40 ILS');
 record('Two-tab privacy update clears and conceals an already open settlement dialog');
 await button(other,'Adjust balance');
 await input(other,'Correct current balance','13.00');
 await input(other,'Adjustment reason','Stale count');
 await adjust(page,'12.00','Newer count');
 await button(other,'Record adjustment'); await text(other,'The wallet changed in another tab.');
 await button(other,'Cancel'); await other.reload(); await semantics(other); await text(other,'12.00 ILS');
 assert.ok(!(await body(other)).includes('Stale count')); await other.close();
 record('Two-tab stale settlement rejected without a duplicate or overwritten entry');
 await button(page,'All wallets');
 await create(page,'Reserve account','1250.000',{currency:'JOD',type:'Bank account',color:'Navy',icon:'Bank account'});
 // Delay only background notifications in the second tab. IndexedDB stays real;
 // a write transaction must still detect a stale order snapshot and reject it.
 const stale=await context.newPage(); await stale.addInitScript(()=>{
   const Native=window.BroadcastChannel;
   window.BroadcastChannel=class extends Native {set onmessage(handler){super.onmessage=(event)=>{if(!window.pauseWalletNotifications && handler) handler.call(this,event);};}};
   window.pauseWalletNotifications=true;
 });
 await stale.goto(url+'/#/wallets'); await semantics(stale); await text(stale,'Reserve account');
 await page.getByRole('button',{name:'Move down',exact:true}).first().click();
 await text(page,'Reserve account');
 await stale.getByRole('button',{name:'Move down',exact:true}).first().click();
 await text(stale,'The wallet changed in another tab.'); await stale.close();
 await page.reload(); await semantics(page); await text(page,'Reserve account');
 const ordered=await body(page); assert.ok(ordered.indexOf('Reserve account')<ordered.indexOf('Everyday cash'));
 record('Two-tab stale reorder rejected; successful order persists');
 await create(page,'Long-term funds','900719925474099312345.17',{color:'Purple',icon:'Savings'});
 await text(page,'900719925474099312345.17 ILS');
 await create(page,'Micro savings','0.123456',{currency:'ABC',customScale:6,color:'Emerald',icon:'Digital'});
 await text(page,'0.123456 ABC'); await page.screenshot({path:path.join(docs,'phase-2-wallets-en.png')});
 record('Huge JavaScript amount and custom six-decimal currency persist exactly');
 await page.goto(firstUrl); await semantics(page); await text(page,'Everyday cash');
 await button(page,'Archive wallet'); await page.getByRole('alertdialog').getByRole('button',{name:'Archive wallet',exact:true}).click();
 await text(page,'This wallet is archived');
 assert.equal(await page.getByRole('button',{name:'Edit wallet',exact:true}).isEnabled(),false);
 assert.equal(await page.getByRole('button',{name:'Adjust balance',exact:true}).isEnabled(),false);
 await button(page,'Hide balance'); await text(page,'Show balance');
 await button(page,'All wallets'); await button(page,'Archived (1)'); await text(page,'Everyday cash');
 await page.reload(); await semantics(page); await button(page,'Archived (1)'); await text(page,'Everyday cash');
 record('Archive retains history disables financial editing and permits privacy');
 await page.getByRole('button',{name:'Wallet details',exact:true}).first().click();
 await text(page,'Financial history'); await button(page,'Restore wallet');
 await page.getByRole('alertdialog').getByRole('button',{name:'Restore wallet',exact:true}).click();
 await button(page,'Show balance'); await text(page,'12.00 ILS');
 await page.screenshot({path:path.join(docs,'phase-2-detail-en.png')});
 record('Restore retains balance and appends to active order');
 await page.waitForFunction(async()=>!!(await navigator.serviceWorker.getRegistration())?.active && !!navigator.serviceWorker.controller);
 await context.setOffline(true); await page.reload(); await semantics(page);
 await text(page,'12.00 ILS'); await text(page,'Newer count');
 await button(page,'Edit wallet'); await input(page,'Wallet name','Offline cash');
 await button(page,'Save wallet'); await text(page,'Offline cash');
 await page.reload(); await semantics(page); await text(page,'Offline cash');
 record('Offline reload and real offline edit survive another reload');
 await context.setOffline(false);
 await button(page,'Settings'); await button(page,'Dark'); await button(page,'العربية');
 await button(page,'المحافظ'); await page.setViewportSize({width:390,height:844});
 await text(page,'محافظك، في مكان واحد'); await page.screenshot({path:path.join(docs,'phase-2-wallets-ar-mobile.png')});
 await button(page,'إنشاء محفظة'); await page.screenshot({path:path.join(docs,'phase-2-editor-ar-mobile.png')});
 await input(page,'اسم المحفظة','محفظة صغيرة');
 await input(page,'الرصيد الافتتاحي','-٢٫٥٠');
 await button(page,'حفظ المحفظة'); await text(page,'محفظة صغيرة');
 record('Arabic dark mobile creation supports exact negative opening');
 assert.deepEqual(errors,[]); assert.equal(external.size,0);
 record('No runtime errors or external resources');
 const report={passed:true,checks,externalRequests:[...external],runtimeErrors:errors};
 fs.writeFileSync(path.join(docs,'phase-2-browser-validation.json'),JSON.stringify(report,null,2)); console.log(JSON.stringify(report,null,2));
 } catch(e) {await page.screenshot({path:path.join(docs,'phase-2-failure.png')});console.error(await page.locator('body').ariaSnapshot());throw e;}
 finally {await browser.close();}
})();
