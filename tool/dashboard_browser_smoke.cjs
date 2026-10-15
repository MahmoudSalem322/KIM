// Real release app, local IndexedDB, and the same forms used by other pages.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');
const url = process.env.KIM_URL || 'http://127.0.0.1:8765';
const docs = path.resolve(__dirname, '../docs');
async function semantics(page) {
  await page.waitForSelector('flt-semantics-placeholder,flt-semantics[role]', {state:'attached'});
  if (await page.locator('flt-semantics-placeholder').count()) await page.locator('flt-semantics-placeholder').dispatchEvent('click');
}
async function text(page, value) {
  await page.waitForFunction(t => (document.body.innerText + '\n' + [...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\n')).includes(t), value);
}
async function body(page) { return page.locator('body').ariaSnapshot(); }
async function button(page, name) { await page.getByRole('button',{name,exact:true}).click(); await page.waitForTimeout(200); }
async function input(page, name, value) {
  await page.getByRole('textbox',{name,exact:true}).focus();
  await page.waitForFunction(n=>document.activeElement?.getAttribute('aria-label')===n,name);
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await page.keyboard.press('Control+A');
  await page.waitForFunction(()=>{const e=document.activeElement;return e?.selectionStart===0 && e.selectionEnd===e.value.length;});
  await page.keyboard.insertText(value); await page.waitForFunction(v=>document.activeElement?.value===v,value);
  await page.keyboard.press('Tab'); await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
}
async function go(page, route) { await page.goto(url+'/#'+route); await semantics(page); }
async function wallet(page, name, amount, currency='ILS') {
  await button(page,'Create wallet'); await input(page,'Wallet name',name);
  if (currency!=='ILS') { await button(page,'Currency ILS'); await page.getByRole('menuitem',{name:currency,exact:true}).click(); }
  await input(page,'Opening balance',amount); await button(page,'Save wallet');
  await page.getByRole('textbox',{name:'Wallet name',exact:true}).waitFor({state:'detached'});
}
async function transaction(page, shortcut, amount, notes, date) {
  await button(page,shortcut); await input(page,'Amount (ILS)',amount); await input(page,'Notes',notes);
  if(date) await input(page,'Date',date);
  await button(page,'Save transaction'); await page.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});
}
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE || 'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
 const context=await browser.newContext({viewport:{width:1440,height:1100},serviceWorkers:'allow'});
 const errors=[],external=new Set(),checks=[];
 const page=await context.newPage();
 page.on('pageerror',e=>errors.push(e.message));
 page.on('request',r=>{if(/^https?:/.test(r.url()) && new URL(r.url()).origin!==new URL(url).origin)external.add(r.url());});
 const record=m=>{checks.push(m);console.log('PASS:',m);};
 try {
  await go(page,'/'); await text(page,'ابدأ حكايتك المالية');
  await page.screenshot({path:path.join(docs,'phase-5-empty-ar.png')});
  await go(page,'/settings'); await button(page,'English'); await button(page,'Light');
  await go(page,'/wallets'); await wallet(page,'Everyday cash','200'); await wallet(page,'Dollar reserve','0','USD');
  await go(page,'/'); await text(page,'Your money, at a glance'); await text(page,'Incomplete total');
  record('Honest empty state and incomplete multi-currency total use real wallets');
  await transaction(page,'Add income','1000','October salary');
  await transaction(page,'Add expense','50','Groceries');
  const now=new Date(), prior=new Date(now.getFullYear(),now.getMonth()-1,15);
  const priorDate=`${prior.getFullYear()}-${String(prior.getMonth()+1).padStart(2,'0')}-15`;
  await transaction(page,'Add expense','10','Previous period',priorDate);
  await button(page,'Transfer'); await input(page,'Transfer amount (ILS)','20'); await input(page,'Transfer fee (ILS)','2');
  await input(page,'Manual exchange rate (ILS / USD)','0.5'); await input(page,'Notes','Savings move');
  await button(page,'Save transfer'); await page.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});
  await text(page,'1118.00 ILS'); await text(page,'1000.00 ILS'); await text(page,'52.00 ILS'); await text(page,'948.00 ILS');
  record('Dashboard shortcuts persist income, expense, transfer and fees; exact totals exclude principal and prior period');
  await page.screenshot({path:path.join(docs,'phase-5-dashboard-en.png')});
  // Period and currency are Material dropdowns, exposed as buttons and popup menus.
  await button(page,'Period This month'); await page.getByRole('menuitem',{name:'Last month',exact:true}).click();
  await text(page,'10.00 ILS'); await text(page,'1118.00 ILS');
  record('Changing calendar period filters actual history while preserving current balance');
  await button(page,'Period Last month'); await page.getByRole('menuitem',{name:'This month',exact:true}).click();
  await button(page,'Display currency ILS · 2 decimal places'); await page.getByRole('menuitem',{name:'USD · 2 decimal places',exact:true}).click();
  await text(page,'10.00 USD'); await text(page,'No expenses in this period');
  record('Display currency isolates USD and leaves transfers outside income and expenses');
  await button(page,'Display currency USD · 2 decimal places'); await page.getByRole('menuitem',{name:'ILS · 2 decimal places',exact:true}).click(); await text(page,'52.00 ILS');
  await page.getByRole('button',{name:/^202\d-\d\d-\d\d – [\s\S]*Income: 1000.00 ILS/}).first().click();
  await text(page,'Income & expenses');
  await page.getByRole('button',{name:/^Food: /}).click();
  assert.ok((await body(page)).includes('Where your money goes Food 50.00 ILS'));
  await page.screenshot({path:path.join(docs,'phase-5-charts-en.png')});
  record('Interactive bar selection and category selection expose exact amounts');
  await page.reload(); await semantics(page); await text(page,'1118.00 ILS'); await text(page,'52.00 ILS');
  await page.waitForFunction(async()=>!!(await navigator.serviceWorker.getRegistration())?.active && !!navigator.serviceWorker.controller);
  await context.setOffline(true); await page.reload(); await semantics(page); await text(page,'1118.00 ILS');
  await transaction(page,'Add expense','1','Offline purchase'); await text(page,'1117.00 ILS'); await text(page,'53.00 ILS');
  await page.reload(); await semantics(page); await text(page,'1117.00 ILS'); await context.setOffline(false);
  record('Offline reload and new expense preserve local data and update financial summary');
  await go(page,'/wallets'); await page.getByRole('button',{name:'Hide balance',exact:true}).first().click();
  await go(page,'/'); await text(page,'Amounts hidden for wallet privacy');
  assert.ok(!(await body(page)).includes('1117.00 ILS'));
  record('Hiding a wallet removes aggregate amounts and chart data from accessibility tree');
  await go(page,'/wallets'); await button(page,'Show balance');
  await go(page,'/settings'); await button(page,'Dark'); await button(page,'العربية');
  await page.setViewportSize({width:390,height:844}); await go(page,'/'); await text(page,'أموالك، بنظرة واحدة');
  assert.equal(await page.locator('html').getAttribute('lang'),'ar');
  await page.screenshot({path:path.join(docs,'phase-5-dashboard-ar-mobile.png')});
  await page.getByRole('button',{name:'إخفاء الرصيد',exact:true}).first().scrollIntoViewIfNeeded();
  await page.screenshot({path:path.join(docs,'phase-5-wallets-ar-mobile.png')});
  record('Arabic RTL dark mobile dashboard renders real balances, wallet cards and actions');
  assert.deepEqual(errors,[]); assert.deepEqual([...external],[]);
  record('No browser runtime errors or external resource requests');
  fs.writeFileSync(path.join(docs,'phase-5-browser-validation.json'),JSON.stringify({passed:true,checks,runtimeErrors:errors,externalRequests:[...external]},null,2));
 } catch(e) { await page.screenshot({path:path.join(docs,'phase-5-failure.png')}); console.error(await body(page)); throw e; }
 finally { await browser.close(); }
})();
