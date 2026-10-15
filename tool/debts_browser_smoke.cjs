const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),docs=path.join(root,'docs'),url=process.env.KIM_URL||'http://127.0.0.1:8765';
async function sem(p){await p.waitForSelector('flt-semantics-placeholder,flt-semantics[role]',{state:'attached'});if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').dispatchEvent('click');}
async function text(p,t){await p.waitForFunction(t=>(document.body.innerText+'\n'+[...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\n')).includes(t),t);}
async function button(p,n){await p.getByRole('button',{name:n,exact:true}).click();await p.waitForTimeout(250);}
async function input(p,n,v){await p.getByRole('textbox',{name:n,exact:true}).focus();await p.waitForFunction(n=>document.activeElement?.getAttribute('aria-label')===n,n);await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));await p.keyboard.press('Control+A');await p.waitForFunction(()=>{const e=document.activeElement;return e?.selectionStart===0&&e.selectionEnd===e.value.length;});await p.keyboard.insertText(v);await p.waitForFunction(v=>document.activeElement?.value===v,v);await p.keyboard.press('Tab');await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));}
async function option(p,n){await p.getByRole('menuitem',{name:n,exact:true}).click();await p.waitForTimeout(200);}
async function go(p,r){await p.goto(url+'/#'+r);await sem(p);await p.waitForTimeout(250);}
function card(p,name){return p.getByRole('group',{name:new RegExp('^'+name+'\\b')}).filter({has:p.getByRole('button',{name:'Edit debt',exact:true})}).last();}
async function wallet(p,name,balance){await go(p,'/wallets');await button(p,'Create wallet');await input(p,'Wallet name',name);await input(p,'Opening balance',balance);await button(p,'Save wallet');await p.getByRole('textbox',{name:'Wallet name',exact:true}).waitFor({state:'detached'});}
async function create(p,name,amount,{borrowed=false,currency='ILS'}={}){
 await go(p,'/debts');await button(p,'Add debt record');await input(p,'Person',name);
 if(borrowed){await button(p,'Debt direction I lent — owed to me');await option(p,'I borrowed — I owe');}
 if(currency!=='ILS'){await button(p,'Currency ILS / 2');await option(p,currency+' / 2');}
 await input(p,`Original amount (${currency})`,amount);await input(p,'Due date (YYYY-MM-DD)','2026-01-01');await input(p,'Notes','Administrative agreement');await button(p,'Save administrative record');await p.getByRole('textbox',{name:'Person',exact:true}).waitFor({state:'detached'});
 await p.getByRole('checkbox',{name:borrowed?'I borrowed — I owe':'I lent — owed to me',exact:true}).click();await text(p,name);
}
async function selectWallet(p,name){const b=p.getByRole('button',{name:/^Wallet /});const label=await b.getAttribute('aria-label');if(label!==`Wallet ${name} · ILS`){await b.click();await option(p,name+' · ILS');}}
async function cash(p,name,amount,{principal=false,walletName='Debt cash'}={}){
 await card(p,name).getByRole('button',{name:principal?'Record original cash movement':'Record payment',exact:true}).click();await selectWallet(p,walletName);
 if(!principal)await input(p,'Cash amount (ILS)',amount);await input(p,'Cash date (YYYY-MM-DD)',principal?'2026-10-13':'2026-10-14');
 await button(p,'Record cash movement');await p.getByRole('textbox',{name:'Cash date (YYYY-MM-DD)',exact:true}).waitFor({state:'detached'});
}
async function history(p,name){const c=card(p,name);if(await c.getByRole('button',{name:'Edit cash movement',exact:true}).count()===0)await c.getByRole('button',{name:'Cash movements & payments',exact:true}).click();return c;}
async function checkBalance(p,name,expected){await go(p,'/wallets');const c=p.getByRole('group',{name:new RegExp(name)}).filter({has:p.getByRole('button',{name:'Wallet details',exact:true})}).last();assert.ok((await c.ariaSnapshot()).includes(expected+' ILS'));}
(async()=>{
 const fixture=process.env.KIM_LEGACY_PROFILE,profile=path.join(root,'.dart_tool','debts-browser-'+Date.now());if(fixture)fs.cpSync(fixture,profile,{recursive:true});
 const checks=[],errors=[],external=new Set();const record=m=>{checks.push(m);console.log('PASS:',m);};
 const ctx=await chromium.launchPersistentContext(profile,{executablePath:process.env.CHROME_EXECUTABLE||'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,viewport:{width:1440,height:1100},serviceWorkers:'allow'});
 const track=p=>{p.on('pageerror',e=>errors.push(e.message));p.on('request',r=>{if(/^https?:/.test(r.url())&&new URL(r.url()).origin!==new URL(url).origin)external.add(r.url());});};ctx.on('page',track);for(const p of ctx.pages())track(p);const p=ctx.pages()[0];
 try{
  await go(p,'/settings');await button(p,'English');await button(p,'Light');
  if(fixture){await p.evaluate(async()=>{await (await navigator.serviceWorker.getRegistration())?.update();});await p.waitForFunction(async()=>!!(await navigator.serviceWorker.getRegistration())?.waiting);
   for(const other of ctx.pages())if(other!==p)await other.close();await p.goto('about:blank');await p.waitForTimeout(2000);await go(p,'/goals');await text(p,'Offline future');await text(p,'80.00 ILS');record('Actual phase-seven IndexedDB and offline cache migrate without losing goals or reservations');}
  await wallet(p,'Debt cash','1000');await wallet(p,'Other debt cash','100');
  await create(p,'Alex','400');await checkBalance(p,'Debt cash','1000.00');await go(p,'/debts');await text(p,'Overdue');
  record('Administrative loan record and due status persist without a cash movement');
  await cash(p,'Alex','400',{principal:true});await checkBalance(p,'Debt cash','600.00');await go(p,'/debts');
  await cash(p,'Alex','125.25');assert.ok((await card(p,'Alex').ariaSnapshot()).includes('274.75 ILS'));await checkBalance(p,'Debt cash','725.25');await go(p,'/debts');
  record('Explicit original lending and exact partial collection update the selected wallet and outstanding amount');
  let c=await history(p,'Alex');await c.getByRole('button',{name:'Edit cash movement',exact:true}).first().click();await input(p,'Cash amount (ILS)','200');await button(p,'Record cash movement');await p.getByRole('textbox',{name:'Cash date (YYYY-MM-DD)',exact:true}).waitFor({state:'detached'});await checkBalance(p,'Debt cash','800.00');
  await go(p,'/debts');c=await history(p,'Alex');await c.getByRole('button',{name:'Cancel cash movement',exact:true}).first().click();await p.getByRole('alertdialog').getByRole('button',{name:'Cancel cash movement',exact:true}).click();await text(p,'Cancelled');await checkBalance(p,'Debt cash','600.00');
  await go(p,'/debts');await cash(p,'Alex','400');assert.ok((await card(p,'Alex').ariaSnapshot()).includes('Settled'));await checkBalance(p,'Debt cash','1000.00');record('Repayment editing and cancellation reverse old cash, preserve history and reopen debt; full payment settles it');
  await create(p,'Sam','300',{borrowed:true});await cash(p,'Sam','300',{principal:true});await cash(p,'Sam','50');await checkBalance(p,'Debt cash','1250.00');await go(p,'/debts');await p.getByRole('checkbox',{name:'I borrowed — I owe',exact:true}).click();
  c=await history(p,'Sam');await c.getByRole('button',{name:'Edit cash movement',exact:true}).first().click();await selectWallet(p,'Other debt cash');await input(p,'Cash amount (ILS)','75');await button(p,'Record cash movement');await p.getByRole('textbox',{name:'Cash date (YYYY-MM-DD)',exact:true}).waitFor({state:'detached'});
  await checkBalance(p,'Other debt cash','25.00');await checkBalance(p,'Debt cash','1300.00');await go(p,'/debts');await p.getByRole('checkbox',{name:'I borrowed — I owe',exact:true}).click();
  c=await history(p,'Sam');await c.getByRole('button',{name:'Cancel cash movement',exact:true}).first().click();await p.getByRole('alertdialog').getByRole('button',{name:'Cancel cash movement',exact:true}).click();await checkBalance(p,'Other debt cash','100.00');
  record('Borrowing adds cash, repayments deduct it, and changing payment wallet atomically restores the old wallet');
  await go(p,'/debts');await p.getByRole('checkbox',{name:'I borrowed — I owe',exact:true}).click();await card(p,'Sam').getByRole('button',{name:'Record payment',exact:true}).click();await selectWallet(p,'Debt cash');await input(p,'Cash amount (ILS)','301');await button(p,'Record cash movement');await text(p,'The payment exceeds the outstanding debt.');await button(p,'Cancel');
  await p.screenshot({path:path.join(docs,'phase-8-debts-en.png')});record('Overpayment is rejected without changing debt or cash');
  await create(p,'Dollar agreement','20',{currency:'USD'});assert.ok((await card(p,'Dollar agreement').ariaSnapshot()).includes('20.00 USD'));await card(p,'Dollar agreement').getByRole('button',{name:'Record payment',exact:true}).click();assert.equal(await p.getByRole('button',{name:'Wallet Debt cash · ILS',exact:true}).count(),0);await button(p,'Cancel');
  record('Currency and precision stay explicit; ILS wallets are absent from a USD cash form');
  await p.waitForFunction(()=>!!navigator.serviceWorker.controller);await ctx.setOffline(true);await create(p,'Offline debt','50');await cash(p,'Offline debt','10');await p.reload();await sem(p);await text(p,'Offline debt');assert.ok((await card(p,'Offline debt').ariaSnapshot()).includes('40.00 ILS'));await ctx.setOffline(false);record('Debt and payment persist after an offline reload using only local resources');
  await go(p,'/wallets');const wc=p.getByRole('group',{name:/Debt cash/}).filter({has:p.getByRole('button',{name:'Hide balance',exact:true})}).last();await wc.getByRole('button',{name:'Hide balance',exact:true}).click();await go(p,'/debts');await text(p,'Amounts and status hidden because a linked wallet balance is hidden');assert.ok(!(await card(p,'Offline debt').ariaSnapshot()).includes('40.00 ILS'));
  record('Hidden wallet balances also conceal linked debt amounts, status and financial history');
  await go(p,'/settings');await button(p,'Dark');await button(p,'العربية');await p.setViewportSize({width:390,height:844});await go(p,'/debts');await text(p,'حقوقك والتزاماتك، بوضوح');await p.screenshot({path:path.join(docs,'phase-8-debts-ar-mobile.png')});await button(p,'إضافة سجل دين');await p.waitForTimeout(500);await p.screenshot({path:path.join(docs,'phase-8-editor-ar-mobile.png')});await button(p,'إلغاء');
  record('Arabic RTL dark mobile debt page and editor work with the existing navigation');
  assert.deepEqual(errors,[]);assert.deepEqual([...external],[]);record('No browser runtime errors or external resource requests');
  fs.writeFileSync(path.join(docs,'phase-8-browser-validation.json'),JSON.stringify({passed:true,legacyMigration:!!fixture,checks,runtimeErrors:errors,externalRequests:[...external]},null,2));
 }catch(e){await p.screenshot({path:path.join(docs,'phase-8-failure.png')});console.error(await p.locator('body').ariaSnapshot());throw e;}finally{await ctx.close();}
})();
