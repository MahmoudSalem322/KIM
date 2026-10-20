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
async function button(page,name) { await page.bringToFront(); await page.getByRole('button',{name,exact:true}).click(); await page.waitForTimeout(350); }
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
async function addTransaction(page,amount,notes,{kind='Expense',date='2020-02-29'}={}) {
 await button(page,'Add transaction');
 if(kind==='Income') await button(page,'Income');
 await input(page,'Amount (ILS)',amount);await input(page,'Date',date);await input(page,'Notes',notes);
 await button(page,'Save transaction');await page.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});await text(page,notes);
}
async function editTransaction(page,amount,notes,date='1999-01-01') {
 await page.getByRole('button',{name:'Edit transaction',exact:true}).first().click();await page.waitForTimeout(350);
 await input(page,'Amount (ILS)',amount);await input(page,'Date',date);await input(page,'Notes',notes);
 await button(page,'Save transaction');await page.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});await text(page,notes);
}
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE || 'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
 const context=await browser.newContext({viewport:{width:1440,height:1100},serviceWorkers:'allow'});
 const errors=[],external=new Set(),checks=[];
 context.on('page',page=>{page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(/^https?:/.test(r.url()) && new URL(r.url()).origin!==new URL(url).origin)external.add(r.url());});});
 const record=m=>{checks.push(m);console.log('PASS:',m);};
 const page=await context.newPage();
 try{
 await page.goto(url);await semantics(page);await button(page,'الإعدادات');await button(page,'English');await button(page,'Wallets');
 await create(page,'Everyday cash','100.00');
 await button(page,'Transactions');await addTransaction(page,'١٢٫٣٥','Lunch');
 await addTransaction(page,'50.10','Salary January',{kind:'Income',date:'2020-01-01'});
 async function balance(expected){await button(page,'Wallets');await page.getByRole('button',{name:'Wallet details',exact:true}).first().click();await text(page,expected+' ILS');await button(page,'Transactions');}
 await balance('137.75');record('Exact income and Arabic decimal expense update real wallet ledger');
 await page.reload();await semantics(page);await text(page,'Salary January');await text(page,'Lunch');record('Income expense notes and historical dates persist across reload');
 await input(page,'Search notes, category or wallet','Lunch');assert.ok(!(await body(page)).includes('Salary January'));
 await button(page,'Clear filters');
 await page.getByRole('button',{name:/^All types /}).click();await option(page,'Income');await text(page,'Salary January');assert.ok(!(await body(page)).includes('Lunch'));
 await button(page,'Clear filters');await input(page,'From date (YYYY-MM-DD)','2020-01-01');await input(page,'To date (YYYY-MM-DD)','2020-01-15');await text(page,'Salary January');assert.ok(!(await body(page)).includes('Lunch'));
 await button(page,'Clear filters');record('Search type and inclusive business-date filters select actual records');
 await input(page,'Search notes, category or wallet','Lunch');await editTransaction(page,'5.10','Lunch corrected');await button(page,'Clear filters');await balance('145.00');record('Editing a past expense preserves opening and corrects the net balance');
 const other=await context.newPage();await other.goto(url+'/#/transactions');await semantics(other);await input(other,'Search notes, category or wallet','Lunch');
 await other.getByRole('button',{name:'Edit transaction',exact:true}).first().click();await other.waitForTimeout(350);
 await button(page,'Wallets');await page.getByRole('button',{name:'Wallet details',exact:true}).first().click();await text(page,'145.00 ILS');await button(page,'Hide balance');
 await other.waitForFunction(()=>{const input=document.querySelector('input[aria-label="Amount (ILS)"]');return input?.type==='password' && input.value==='';});assert.equal(await other.getByRole('textbox',{name:'Amount (ILS)',exact:true}).inputValue(),'');assert.ok(!(await body(other)).includes('5.10'));
 await button(other,'Cancel');await button(page,'Show balance');await button(page,'Transactions');record('Live privacy masks transaction history and clears an open editor across tabs');
 await other.getByRole('button',{name:'Edit transaction',exact:true}).first().click();await other.waitForTimeout(350);await input(other,'Amount (ILS)','9.00');
 await input(page,'Search notes, category or wallet','Lunch');await editTransaction(page,'7.10','Lunch corrected');
 await button(other,'Save transaction');await text(other,'Data changed in another tab.');await button(other,'Cancel');await other.close();await button(page,'Clear filters');await balance('143.00');record('Stale two-tab edit rejected without duplicate effects or lost balance');
 await input(page,'Search notes, category or wallet','Lunch');await page.getByRole('button',{name:'Delete transaction',exact:true}).first().click();await page.getByRole('alertdialog').getByRole('button',{name:'Delete transaction',exact:true}).click();await text(page,'No transactions match these filters');await button(page,'Clear filters');await balance('150.10');
 await page.getByRole('button',{name:/^All statuses /}).click();await option(page,'Cancelled');await text(page,'Lunch corrected');assert.equal(await page.getByRole('button',{name:'Edit transaction',exact:true}).first().isEnabled(),false);await page.reload();await semantics(page);await balance('150.10');record('Confirmed deletion reverses once; cancelled evidence and balance survive reload');
 await page.waitForFunction(async()=>!!(await navigator.serviceWorker.getRegistration())?.active && !!navigator.serviceWorker.controller);
 await context.setOffline(true);await page.reload();await semantics(page);const today=(d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`)(new Date());await addTransaction(page,'0.01','Offline coffee',{date:today});await page.reload();await semantics(page);await text(page,'Offline coffee');await balance('150.09');await context.setOffline(false);record('Offline create and reload retain exact transactions and wallet balance');
 await page.screenshot({path:path.join(docs,'phase-3-transactions-en.png')});
 await button(page,'Overview');await text(page,'Offline coffee');record('Dashboard recent activity uses persisted real transactions');
 await button(page,'Settings');await button(page,'Dark');await button(page,'العربية');await button(page,'العمليات');await page.setViewportSize({width:390,height:844});await text(page,'سجل أموالك، بوضوح');await page.screenshot({path:path.join(docs,'phase-3-transactions-ar-mobile.png')});
 await button(page,'إضافة عملية');await page.screenshot({path:path.join(docs,'phase-3-editor-ar-mobile.png')});await button(page,'دخل');await input(page,'المبلغ (ILS)','٣٫٢٠');await input(page,'التاريخ','2000-02-29');await input(page,'ملاحظات','دخل قديم');await button(page,'حفظ العملية');await text(page,'دخل قديم');record('Arabic dark mobile entry accepts historical income and exact decimals');
 assert.deepEqual(errors,[]);assert.equal(external.size,0);record('No browser runtime errors or external resource requests');
 const report={passed:true,checks,runtimeErrors:errors,externalRequests:[...external]};fs.writeFileSync(path.join(docs,'phase-3-browser-validation.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
 }catch(e){await page.screenshot({path:path.join(docs,'phase-3-failure.png')});console.error(await body(page));throw e;}
 finally{await browser.close();}
})();
