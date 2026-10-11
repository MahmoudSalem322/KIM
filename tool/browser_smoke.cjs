// Optional release-browser smoke suite. npm install --prefix tool first.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const url = process.env.KIM_URL || 'http://127.0.0.1:8765';
const screenshots = path.resolve(__dirname, '../docs');

async function enableSemantics(page) {
  await page.waitForSelector('flt-semantics-placeholder', {state:'attached'});
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');
}

async function selected(page, name) {
  await page.waitForFunction(label => [...document.querySelectorAll('[role=button]')].some(el =>
    el.textContent.trim() === label && (el.getAttribute('aria-current') === 'true' || el.getAttribute('aria-pressed') === 'true' || el.getAttribute('aria-selected') === 'true')
  ), name);
}

(async()=>{
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_EXECUTABLE || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless:true,
  });
  const context = await browser.newContext({viewport:{width:1440,height:1100}, serviceWorkers:'allow'});
  const page = await context.newPage();
  const errors = [], external = new Set(), checks = [];
  page.on('pageerror', error=>errors.push(error.message));
  page.on('request', req=>{ if(/^https?:/.test(req.url()) && new URL(req.url()).origin !== new URL(url).origin) external.add(req.url()); });
  try {
    await page.goto(url);
    await enableSemantics(page);
    await page.getByRole('button',{name:'الإعدادات',exact:true}).waitFor();
    await page.screenshot({path:path.join(screenshots,'preview-ar-light.png')});
    checks.push('Arabic RTL desktop dashboard and accessible navigation');
    await page.getByRole('button',{name:'الإعدادات',exact:true}).click();
    await page.getByRole('button',{name:'English',exact:true}).click();
    await page.getByRole('button',{name:'Dark',exact:true}).click();
    await selected(page,'Dark');
    assert.equal(await page.locator('html').getAttribute('lang'),'en');
    await page.screenshot({path:path.join(screenshots,'preview-en-dark.png')});
    checks.push('English and dark theme controls apply');
    await page.getByRole('button',{name:'About local storage',exact:true}).click();
    await page.getByRole('button',{name:'Close',exact:true}).click();
    checks.push('Localized information dialog opens and closes');
    for (const [section,title] of [
      ['Wallets','Your wallets, in one place'], ['Transactions','A clear view of your money'],
      ['Budgets','Give every goal a plan'], ['Reports','See the bigger picture'],
    ]) {
      await page.getByRole('button',{name:section,exact:true}).click();
      await page.waitForFunction(text=>document.body.innerText.includes(text), title);
    }
    checks.push('All financial sections navigate to real empty states');
    await page.getByRole('button',{name:'Settings',exact:true}).click();
    await page.waitForFunction(()=>document.body.innerText.includes('Make this space yours'));
    console.log('Settings URL before reload:', page.url());
    await page.reload();
    await enableSemantics(page);
    await selected(page,'English'); await selected(page,'Dark');
    checks.push('Language and theme survive full page reload');
    await page.waitForFunction(async()=>{
      const registration = await navigator.serviceWorker.getRegistration();
      return !!registration?.active && !!navigator.serviceWorker.controller;
    });
    const cached = await page.evaluate(async()=>{
      const keys = (await caches.keys()).filter(key=>key.startsWith('kim-'));
      const counts = await Promise.all(keys.map(async key=>(await (await caches.open(key)).keys()).length));
      return counts.reduce((a,b)=>a+b,0);
    });
    assert.ok(cached > 20,'Full local bundle must be cached');
    await context.setOffline(true);
    await page.reload(); await enableSemantics(page);
    await selected(page,'English'); await selected(page,'Dark');
    await page.getByRole('button',{name:'Wallets',exact:true}).click();
    await page.waitForFunction(()=>document.body.innerText.includes('Your wallets, in one place'));
    checks.push('Offline reload restores app, settings and navigation');
    await context.setOffline(false);
    await page.setViewportSize({width:390,height:844});
    await page.getByRole('button',{name:/Settings/}).click();
    await page.getByRole('button',{name:'العربية',exact:true}).click(); await selected(page,'العربية');
    await page.screenshot({path:path.join(screenshots,'preview-ar-mobile-dark.png')});
    checks.push('Arabic RTL mobile navigation and settings');
    await page.setViewportSize({width:1366,height:600});
    await page.getByRole('button',{name:'الإعدادات',exact:true}).waitFor();
    await page.screenshot({path:path.join(screenshots,'preview-ar-short-desktop.png')});
    checks.push('Short desktop sidebar remains usable');
    if (process.env.KIM_MONEY_JS) {
      await page.addScriptTag({path:process.env.KIM_MONEY_JS});
      const result = await page.evaluate(()=>globalThis.kimMoneyResult);
      assert.equal(result,'7 JavaScript money/ID checks passed'); checks.push(result);
    }
    assert.equal(external.size,0,'Runtime must not fetch external resources');
    assert.deepEqual(errors,[],'No browser runtime exceptions');
    checks.push('No external requests or browser runtime exceptions');
    const report = {passed:true, checks, cachedFiles:cached, externalRequests:[...external], runtimeErrors:errors};
    fs.writeFileSync(path.join(screenshots,'browser-validation.json'),JSON.stringify(report,null,2));
    console.log(JSON.stringify(report,null,2));
  } catch(error) {
    await page.screenshot({path:path.join(screenshots,'browser-failure.png')});
    console.error(await page.locator('body').ariaSnapshot()); throw error;
  } finally { await browser.close(); }
})();
