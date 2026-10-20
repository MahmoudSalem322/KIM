// Controlled Chrome/IndexedDB fixtures only. Optional legacy profile comes
// from the phase-eight suite, never a personal browser profile.
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),docs=path.join(root,'docs'),url=process.env.KIM_URL||'http://127.0.0.1:8765';
const calendar=d=>d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
const today=new Date(),day=calendar(today),prior=calendar(new Date(today.getFullYear(),today.getMonth(),today.getDate()-2));
async function sem(p){await p.waitForSelector('flt-semantics-placeholder,flt-semantics[role]',{state:'attached'});if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').dispatchEvent('click');}
async function text(p,t){await p.waitForFunction(t=>(document.body.innerText+'\n'+[...document.querySelectorAll('[aria-label]')].map(e=>e.getAttribute('aria-label')).join('\n')).includes(t),t);}
async function button(p,n){await p.getByRole('button',{name:n,exact:true}).click();await p.waitForTimeout(250);}
async function input(p,n,v){await p.getByRole('textbox',{name:n,exact:true}).focus();await p.waitForFunction(n=>document.activeElement?.getAttribute('aria-label')===n,n);await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));await p.keyboard.press('Control+A');await p.waitForFunction(()=>{const e=document.activeElement;return e?.selectionStart===0&&e.selectionEnd===e.value.length;});await p.keyboard.insertText(v);await p.waitForFunction(v=>document.activeElement?.value===v,v);await p.keyboard.press('Tab');await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));}
async function option(p,n){await p.getByRole('menuitem',{name:n,exact:true}).click();await p.waitForTimeout(200);}
async function go(p,r){await p.goto(url+'/#'+r);await sem(p);await p.waitForTimeout(250);}
function planCard(p,name){return p.getByRole('group',{name:new RegExp('^'+name+'\\b')}).filter({has:p.getByRole('button',{name:'Recorded occurrences',exact:true})}).last();}
function notice(p,name,kind){return p.getByRole('group',{name:new RegExp('^'+kind+' '+name+'\\b')}).filter({has:p.getByRole('button',{name:'Open details',exact:true})}).last();}
async function wallet(p){await go(p,'/wallets');while(await p.getByRole('button',{name:'Show balance',exact:true}).count()){await p.getByRole('button',{name:'Show balance',exact:true}).first().click();await p.waitForTimeout(250);}await button(p,'Create wallet');await input(p,'Wallet name','Recurring cash');await input(p,'Opening balance','1000');await button(p,'Save wallet');await p.getByRole('textbox',{name:'Wallet name',exact:true}).waitFor({state:'detached'});}
async function balance(p,expected){await go(p,'/wallets');const c=p.getByRole('group',{name:/^Recurring cash\b/}).filter({has:p.getByRole('button',{name:'Wallet details',exact:true})}).last();assert.ok((await c.ariaSnapshot()).includes(expected+' ILS'));}
async function paid(p,name){for(let i=0;i<60;i++){if(!await planCard(p,name).getByRole('button',{name:'Record due payment',exact:true}).isEnabled())return;await p.waitForTimeout(100);}throw new Error('Occurrence did not finish recording');}
async function subscription(p,name,amount,{automatic=false,date=day,daily=false}={}){
 await go(p,'/recurring');await button(p,'Add subscription');await input(p,'Name',name);
 const current=p.getByRole('button',{name:/^Wallet /});await current.click();await option(p,'Recurring cash · ILS / 2');
 await input(p,'Amount (ILS)',amount);await input(p,'Next payment (YYYY-MM-DD)',date);
 await p.getByRole('button',{name:/^Expense category /}).click();await option(p,'Bills');
 if(daily){await button(p,'Repeat cycle Monthly');await option(p,'Daily');}
 if(automatic)await p.getByRole('checkbox',{name:'Automatically record due expenses',exact:true}).click();
 await button(p,'Save subscription');await p.getByRole('textbox',{name:'Name',exact:true}).waitFor({state:'detached'});await text(p,name);
}
(async()=>{
 const fixture=process.env.KIM_LEGACY_PROFILE,profile=path.join(root,'.dart_tool','recurring-browser-'+Date.now());if(fixture)fs.cpSync(fixture,profile,{recursive:true});
 const checks=[],errors=[],external=new Set();let ctx;const record=m=>{checks.push(m);console.log('PASS:',m);};
 async function launch(){const c=await chromium.launchPersistentContext(profile,{executablePath:process.env.CHROME_EXECUTABLE||'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,viewport:{width:1440,height:1100},serviceWorkers:'allow'});
  const track=p=>{p.on('pageerror',e=>errors.push(e.message));p.on('request',r=>{if(/^https?:/.test(r.url())&&new URL(r.url()).origin!==new URL(url).origin)external.add(r.url());});};c.on('page',track);for(const p of c.pages())track(p);return c;}
 ctx=await launch();let p=ctx.pages()[0];
 try{
  await go(p,'/settings');await button(p,'English');await button(p,'Light');
  if(fixture){await p.evaluate(async()=>{await (await navigator.serviceWorker.getRegistration())?.update();});await p.waitForFunction(async()=>!!(await navigator.serviceWorker.getRegistration())?.waiting);
   for(const q of ctx.pages())if(q!==p)await q.close();await p.goto('about:blank');await p.waitForTimeout(2000);await go(p,'/debts');await text(p,'Alex');await go(p,'/goals');await text(p,'Offline future');record('Real schema-eight IndexedDB and offline cache upgrade preserve debts, goals and wallets');}
  await wallet(p);await subscription(p,'Internet catchup','10',{automatic:true,date:prior,daily:true});
  await ctx.close();ctx=await launch();p=ctx.pages()[0];await go(p,'/recurring');await p.waitForTimeout(1500);await balance(p,'970.00');
  await p.reload();await sem(p);await balance(p,'970.00');record('Closing and reopening catches up three actual daily expenses once; subsequent reload never repeats them');
  await subscription(p,'Streaming manual','25.25');await button(p,'Process due payments');await balance(p,'970.00');await go(p,'/recurring');
  await planCard(p,'Streaming manual').getByRole('button',{name:'Record due payment',exact:true}).click();await p.getByRole('alertdialog').getByRole('button',{name:'Record due payment',exact:true}).click();
  await paid(p,'Streaming manual');
  await balance(p,'944.75');record('Reminder-only subscriptions do not auto-debit; explicit due recording creates one exact wallet expense');
  await go(p,'/recurring');await p.screenshot({path:path.join(docs,'phase-9-calendar-en.png')});await planCard(p,'Internet catchup').scrollIntoViewIfNeeded();await p.screenshot({path:path.join(docs,'phase-9-subscriptions-en.png')});
  await planCard(p,'Internet catchup').getByRole('button',{name:'Pause',exact:true}).click();await planCard(p,'Internet catchup').getByRole('button',{name:'Resume',exact:true}).waitFor();await planCard(p,'Internet catchup').getByRole('button',{name:'Edit subscription',exact:true}).click();
  await input(p,'Amount (ILS)','12');await button(p,'Save subscription');await p.getByRole('textbox',{name:'Name',exact:true}).waitFor({state:'detached'});
  await planCard(p,'Internet catchup').getByRole('button',{name:'Resume',exact:true}).click();await p.getByRole('alertdialog').getByRole('button',{name:'Resume',exact:true}).click();
  await planCard(p,'Internet catchup').getByRole('button',{name:'Pause',exact:true}).waitFor();
  await planCard(p,'Internet catchup').getByRole('button',{name:'Cancel subscription',exact:true}).click();await p.getByRole('alertdialog').getByRole('button',{name:'Cancel subscription',exact:true}).click();await planCard(p,'Internet catchup').getByRole('button',{name:'Cancel subscription',exact:true}).waitFor({state:'detached'});await balance(p,'944.75');
  record('Pause, future edits, resume and permanent cancellation preserve existing expenses and cash');
  await go(p,'/budgets');await button(p,'Create budget');await input(p,'Name','Subscription budget');await input(p,'Planned amount (ILS)','100');await button(p,'Category All expenses');await option(p,'Bills');await button(p,'Save');await p.getByRole('textbox',{name:'Name',exact:true}).waitFor({state:'detached'});
  await go(p,'/notifications');await text(p,'Subscription budget');const b=notice(p,'Subscription budget','Budget threshold reached');await b.getByRole('button',{name:'Mark read',exact:true}).click();
  await b.getByRole('button',{name:'Mark unread',exact:true}).waitFor();
  await notice(p,'Streaming manual','Subscription expense recorded').getByRole('button',{name:'Dismiss alert',exact:true}).click();
  await notice(p,'Streaming manual','Subscription expense recorded').waitFor({state:'detached'});
  await p.reload();await sem(p);await text(p,'Subscription budget');assert.ok((await notice(p,'Subscription budget','Budget threshold reached').ariaSnapshot()).includes('Mark unread'));
  record('Internal center derives real subscription and budget alerts and persists read and dismiss state after reload');
  await go(p,'/transactions');await input(p,'Search notes, category or wallet','Streaming manual');await button(p,'Edit transaction');await input(p,'Amount (ILS)','5');await button(p,'Save transaction');await p.getByRole('textbox',{name:'Notes',exact:true}).waitFor({state:'detached'});
  await go(p,'/notifications');assert.ok(!(await p.locator('body').ariaSnapshot()).includes('Subscription budget'));
  await go(p,'/transactions');await input(p,'Search notes, category or wallet','Streaming manual');await button(p,'Delete transaction');await p.getByRole('alertdialog').getByRole('button',{name:'Delete transaction',exact:true}).click();
  await go(p,'/recurring');await button(p,'Process due payments');await balance(p,'970.00');
  record('Correcting and deleting a generated expense removes stale budget alerts and never recreates its occurrence');
  await go(p,'/debts');await button(p,'Add debt record');await input(p,'Person','Reminder borrower');await input(p,'Original amount (ILS)','25');await input(p,'Due date (YYYY-MM-DD)',prior);await button(p,'Save administrative record');await p.getByRole('textbox',{name:'Person',exact:true}).waitFor({state:'detached'});
  await go(p,'/notifications');await text(p,'Reminder borrower');await notice(p,'Reminder borrower','Debt due soon or overdue').getByRole('button',{name:'Open details',exact:true}).click();
  const dc=p.getByRole('group',{name:/^Reminder borrower\b/}).filter({has:p.getByRole('button',{name:'Record payment',exact:true})}).last();await dc.getByRole('button',{name:'Record payment',exact:true}).click();await p.getByRole('button',{name:/^Wallet /}).click();await option(p,'Recurring cash · ILS');await button(p,'Record cash movement');await p.getByRole('textbox',{name:'Cash date (YYYY-MM-DD)',exact:true}).waitFor({state:'detached'});
  await go(p,'/notifications');assert.ok(!(await p.locator('body').ariaSnapshot()).includes('Reminder borrower'));record('Debt due alerts disappear after a real complete repayment');
  await ctx.grantPermissions(['notifications'],{origin:url});await go(p,'/notifications');const sw=await p.evaluate(()=>navigator.serviceWorker.controller?.scriptURL);
  await p.evaluate(()=>{const C=window.Notification;window.__kimNotices=[];window.Notification=new Proxy(C,{construct(target,args){window.__kimNotices.push(args);return Reflect.construct(target,args);}});});
  await button(p,'Enable local notifications');await text(p,'Disable local notifications');await p.waitForFunction(()=>window.__kimNotices?.length>0);
  const os=await p.evaluate(()=>window.__kimNotices);assert.ok(os.every(args=>!JSON.stringify(args).includes('Internet')&&!JSON.stringify(args).includes('borrower')&&!JSON.stringify(args).includes('ILS')));
  assert.equal(await p.evaluate(()=>navigator.serviceWorker.controller?.scriptURL),sw);await button(p,'Disable local notifications');
  await p.screenshot({path:path.join(docs,'phase-9-notifications-en.png')});
  record('Opt-in browser notifications contain no financial details and preserve the existing offline service worker');
  await p.waitForFunction(()=>!!navigator.serviceWorker.controller);await ctx.setOffline(true);await subscription(p,'Offline subscription','7.25');
  await planCard(p,'Offline subscription').getByRole('button',{name:'Record due payment',exact:true}).click();await p.getByRole('alertdialog').getByRole('button',{name:'Record due payment',exact:true}).click();
  await p.reload();await sem(p);await text(p,'Offline subscription');
  const needsRetry=await planCard(p,'Offline subscription').getByRole('button',{name:'Record due payment',exact:true}).isEnabled();
  await balance(p,needsRetry?'995.00':'987.75');await go(p,'/recurring');
  if(needsRetry){await planCard(p,'Offline subscription').getByRole('button',{name:'Record due payment',exact:true}).click();await p.getByRole('alertdialog').getByRole('button',{name:'Record due payment',exact:true}).click();await paid(p,'Offline subscription');}
  await balance(p,'987.75');record('Forced reload during a manual write leaves either all effects or none; retry cannot duplicate the expense');
  await p.reload();await sem(p);await balance(p,'987.75');await ctx.setOffline(false);record('Offline subscription creation and payment survive a reload in real IndexedDB');
  await go(p,'/wallets');const wc=p.getByRole('group',{name:/^Recurring cash\b/}).filter({has:p.getByRole('button',{name:'Hide balance',exact:true})}).last();await wc.getByRole('button',{name:'Hide balance',exact:true}).click();
  await go(p,'/notifications');assert.ok(!(await p.locator('body').ariaSnapshot()).includes('Offline subscription'));await go(p,'/recurring');await text(p,'Payment details hidden for wallet privacy');
  record('Hidden wallets conceal payment amounts, forecasts and internal alert details');
  await go(p,'/settings');await button(p,'Dark');await button(p,'العربية');await p.setViewportSize({width:390,height:844});await go(p,'/recurring');await text(p,'التزاماتك، بخطوة مسبقة');await p.screenshot({path:path.join(docs,'phase-9-calendar-ar-mobile.png')});
  await button(p,'إضافة اشتراك');await p.waitForTimeout(500);await p.screenshot({path:path.join(docs,'phase-9-editor-ar-mobile.png')});await button(p,'إلغاء');await go(p,'/notifications');await p.screenshot({path:path.join(docs,'phase-9-notifications-ar-mobile.png')});record('Arabic RTL dark mobile calendar, subscription editor and notification center remain usable');
  assert.deepEqual(errors,[]);assert.deepEqual([...external],[]);record('No browser runtime errors or external resource requests');
  fs.writeFileSync(path.join(docs,'phase-9-browser-validation.json'),JSON.stringify({passed:true,legacyMigration:!!fixture,checks,runtimeErrors:errors,externalRequests:[...external]},null,2));
 }catch(e){await p.screenshot({path:path.join(docs,'phase-9-failure.png')});console.error(await p.locator('body').ariaSnapshot());throw e;}finally{await ctx.close();}
})();
