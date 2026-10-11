// Real release application and IndexedDB; no application mocks.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const url=process.env.KIM_URL || 'http://127.0.0.1:8765';
const docs=path.resolve(__dirname,'../docs');
async function semantics(page){await page.waitForSelector('flt-semantics-placeholder,flt-semantics[role]',{state:'attached'});if(await page.locator('flt-semantics-placeholder').count())await page.locator('flt-semantics-placeholder').dispatchEvent('click');}
async function text(page,value){await page.waitForFunction(t=>(document.body.innerText+'\n'+[...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\n')).includes(t),value);}
async function body(page){return page.locator('body').ariaSnapshot();}
async function button(page,name){await page.bringToFront();await page.getByRole('button',{name,exact:true}).click();await page.waitForTimeout(350);}
async function option(page,name){await page.getByRole('menuitem',{name,exact:true}).click();await page.getByRole('menu',{name:'Popup menu',exact:true}).waitFor({state:'detached'});await page.waitForTimeout(350);}
async function input(page,name,value){await page.bringToFront();await page.getByRole('textbox',{name,exact:true}).focus();await page.waitForFunction(n=>document.activeElement?.getAttribute('aria-label')===n,name);await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));await page.keyboard.press('Control+A');await page.waitForFunction(()=>{const e=document.activeElement;return e?.selectionStart===0 && e.selectionEnd===e.value.length;});await page.keyboard.insertText(value);await page.waitForFunction(v=>document.activeElement?.value===v,value);await page.keyboard.press('Tab');await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));}
async function go(page,route){await page.goto(url+'/#'+route);await semantics(page);await page.waitForTimeout(350);}
async function createWallet(page,name,amount,currency='ILS'){await button(page,'Create wallet');await input(page,'Wallet name',name);if(currency!=='ILS'){await button(page,'Currency ILS');await option(page,currency);}await input(page,'Opening balance',amount);await button(page,'Save wallet');await page.getByRole('textbox',{name:'Wallet name',exact:true}).waitFor({state:'detached'});await text(page,name);}
async function enter(page,amount,fee,rate,notes){await input(page,'Transfer amount (ILS)',amount);await input(page,'Transfer fee (ILS)',fee);await input(page,'Manual exchange rate (ILS / USD)',rate);await input(page,'Notes',notes);}
async function save(page){await button(page,'Save transfer');await page.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});}
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE || 'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
 const context=await browser.newContext({viewport:{width:1440,height:1100},serviceWorkers:'allow'});
 const errors=[],external=new Set(),checks=[];
 context.on('page',p=>{p.on('pageerror',e=>errors.push(e.message));p.on('request',r=>{if(/^https?:/.test(r.url()) && new URL(r.url()).origin!==new URL(url).origin){external.add(r.url());console.log('EXTERNAL:',r.url());}});});
 const record=m=>{checks.push(m);console.log('PASS:',m);};
 const page=await context.newPage();
 try{
  await page.goto(url);await semantics(page);await button(page,'الإعدادات');await button(page,'English');await button(page,'Wallets');
  await createWallet(page,'Everyday cash','100');await createWallet(page,'Dollar savings','0','USD');
  await button(page,'Wallet transfers');await text(page,'Move money with confidence');await button(page,'New transfer');
  await enter(page,'٢٠٫١٠','٠٫٣٥','٠٫٢٧٥','Travel reserve');await text(page,'5.53 USD');
  // Forward two immediate accessibility clicks; a single command must be stored.
  await page.getByRole('button',{name:'Save transfer',exact:true}).evaluate(e=>{e.click();e.click();});
  await page.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});await text(page,'Travel reserve');
  async function balances(cash,dollars){await go(page,'/wallets');await page.getByRole('button',{name:'Wallet details',exact:true}).nth(0).click();await text(page,'Financial history');await text(page,cash+' ILS');await go(page,'/wallets');await page.getByRole('button',{name:'Wallet details',exact:true}).nth(1).click();await text(page,'Financial history');await text(page,dollars+' USD');await go(page,'/transfers');}
  await balances('79.55','5.53');assert.equal(await page.getByRole('button',{name:'Edit transfer',exact:true}).count(),1);record('Arabic exact FX and source fees commit both wallet legs once under repeated save');
  await page.reload();await semantics(page);await text(page,'Travel reserve');await text(page,'0.275 USD');await text(page,'5.53 USD');record('Transfer amount fee notes and saved manual rate survive a real IndexedDB reload');
  await go(page,'/transactions');await text(page,'Expense · Transfer fee');assert.equal(await page.getByRole('button',{name:'Edit transaction',exact:true}).count(),1);assert.equal(await page.getByRole('button',{name:'Edit transaction',exact:true}).isEnabled(),false);assert.equal(await page.getByRole('button',{name:'Delete transaction',exact:true}).isEnabled(),false);record('Only fees appear as expenses; linked fees cannot be edited independently');
  await go(page,'/transfers');await button(page,'Edit transfer');await enter(page,'10','1','0.5','Travel corrected');await save(page);await balances('89.00','5.00');record('Editing principal fee and FX reverses old effects and records a replacement');
  const other=await context.newPage();await go(other,'/transfers');await button(other,'Edit transfer');await enter(other,'9','1','0.5','Stale attempt');
  await button(page,'Edit transfer');await enter(page,'12','1','0.5','Travel corrected');await save(page);
  await button(other,'Save transfer');await text(other,'Data changed. Close and reopen the form.');await button(other,'Close');await balances('87.00','6.00');record('Stale two-tab edit rejects every effect and leaves exact balances intact');
  await button(other,'Edit transfer');
  await go(page,'/wallets');await page.getByRole('button',{name:'Wallet details',exact:true}).nth(1).click();await text(page,'Financial history');await page.waitForTimeout(350);await button(page,'Hide balance');
  await other.waitForFunction(()=>{const e=document.querySelector('input[aria-label="Transfer amount (ILS)"]');const f=document.querySelector('input[aria-label="Transfer fee (ILS)"]');return e?.type==='password' && e.value==='' && f?.value==='';});
  assert.ok(!(await body(other)).includes('12.00'));await button(other,'Close');await other.close();await button(page,'Show balance');await go(page,'/transfers');record('Hiding either wallet clears an open editor and masks both amounts across tabs');
  await button(page,'New transfer');await enter(page,'100','0','1','Rejected debit');await button(page,'Save transfer');await text(page,'Insufficient balance to complete or reverse the transfer.');await button(page,'Close');await balances('87.00','6.00');record('Insufficient funds reject the complete transfer without either partial leg');
  await button(page,'Cancel transfer');await page.getByRole('alertdialog').getByRole('button',{name:'Cancel transfer',exact:true}).click();await text(page,'Cancelled');await balances('100.00','0.00');await page.reload();await semantics(page);await text(page,'Cancelled');assert.equal(await page.getByRole('button',{name:'Edit transfer',exact:true}).first().isEnabled(),false);record('Cancellation reverses both legs and fees while retaining readonly history after reload');
  await page.waitForFunction(async()=>!!(await navigator.serviceWorker.getRegistration())?.active && !!navigator.serviceWorker.controller);
  await context.setOffline(true);await page.reload();await semantics(page);await button(page,'New transfer');await enter(page,'0.10','0.01','0.5','Offline transfer');await save(page);await page.reload();await semantics(page);await text(page,'Offline transfer');await balances('99.89','0.05');await context.setOffline(false);record('Offline transfer and reload preserve both balances and exact fee');
  await input(page,'Search wallets, notes or transfer ID','Offline transfer');assert.ok(!(await body(page)).includes('Travel corrected'));await input(page,'Search wallets, notes or transfer ID','');await page.screenshot({path:path.join(docs,'phase-4-transfers-en.png')});record('Transfer history search filters real persisted records');
  await go(page,'/settings');await button(page,'Dark');await button(page,'العربية');await go(page,'/transfers');await page.setViewportSize({width:390,height:844});await text(page,'بين محافظك، بكل وضوح');await page.screenshot({path:path.join(docs,'phase-4-transfers-ar-mobile.png')});await button(page,'تحويل جديد');await page.screenshot({path:path.join(docs,'phase-4-editor-ar-mobile.png')});
  await input(page,'مبلغ التحويل (ILS)','٣٫٢٠');await input(page,'رسوم التحويل (ILS)','٠٫١٠');await input(page,'سعر الصرف اليدوي (ILS / USD)','٠٫٥');await input(page,'ملاحظات','تحويل عربي');await button(page,'حفظ التحويل');await text(page,'تحويل عربي');record('Arabic RTL dark mobile transfer accepts exact money and manual FX');
  await button(page,'تحويل جديد');await button(page,'تبديل المحفظتين');await input(page,'مبلغ التحويل (USD)','٠٫١٠');await input(page,'رسوم التحويل (USD)','٠٫٠١');await input(page,'سعر الصرف اليدوي (USD / ILS)','٢');await input(page,'ملاحظات','تحويل عكسي');await button(page,'حفظ التحويل');await text(page,'تحويل عكسي');await go(page,'/settings');await button(page,'English');await balances('96.79','1.54');record('Two active wallets can transfer in the reverse direction with a new manual quote');
  assert.deepEqual(errors,[]);assert.deepEqual([...external],[]);record('No browser runtime errors or external resource requests');
  fs.writeFileSync(path.join(docs,'phase-4-browser-validation.json'),JSON.stringify({passed:true,checks,runtimeErrors:errors,externalRequests:[...external]},null,2));
 }catch(e){await page.screenshot({path:path.join(docs,'phase-4-failure.png')});console.error(await body(page));throw e;}
 finally{await browser.close();}
})();
