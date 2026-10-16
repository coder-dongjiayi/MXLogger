// No npm packages needed. Chrome DevTools runs through a private pipe.
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const root = path.resolve(__dirname, '..');
const extension = path.join(root, 'dist/mxlogger-chrome-prototype');
const fontManifest = JSON.parse(fs.readFileSync(path.join(root, 'web/font-manifest.json'), 'utf8'));
const fontURL = fontManifest.pack.url;
const fontURLs = fontManifest.pack.sources.map(source => source.url);
const uiCharacters = [...new Set(JSON.stringify(JSON.parse(fs.readFileSync(path.join(root, '../mxlogger_analyzer_lib/lib/src/app/l10n/app_zh.arb'),'utf8')))
  + fs.readFileSync(path.join(root, 'lib/main.dart'), 'utf8'))]
  .filter(character => /[\u3400-\u9fff]/.test(character)).join('');
const executable = process.env.CHROME_BIN || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'mxlogger-chrome-'));
const browser = spawn(executable, [
  '--headless=new', '--remote-debugging-pipe', '--enable-unsafe-extension-debugging',
  '--no-first-run', '--no-default-browser-check', '--disable-background-networking',
  '--disable-component-update', '--window-size=1440,1100', `--user-data-dir=${profile}`,
], { stdio: ['ignore', 'ignore', 'pipe', 'pipe', 'pipe'] });

let sequence = 0;
let incoming = '';
let stderr = '';
const pending = new Map();
const listeners = new Set();
const errors = [];
const requests = new Set();
const checks = [];
let testSession;

browser.stderr.on('data', chunk => { stderr += chunk.toString(); });
browser.stdio[4].on('data', chunk => {
  incoming += chunk.toString();
  let end;
  while ((end = incoming.indexOf('\0')) >= 0) {
    const message = JSON.parse(incoming.slice(0, end));
    incoming = incoming.slice(end + 1);
    if (message.id) {
      const task = pending.get(message.id);
      if (task) {
        pending.delete(message.id);
        clearTimeout(task.timeout);
        if (message.error) task.reject(new Error(JSON.stringify(message.error)));
        else task.resolve(message.result);
      }
    } else {
      for (const listener of listeners) listener(message);
    }
  }
});

function send(method, params = {}, sessionId) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    const timeout = setTimeout(() => { pending.delete(id); reject(new Error(`Timeout: ${method}`)); }, method === 'Browser.close' ? 5000 : 180000);
    pending.set(id, { resolve, reject, timeout });
    browser.stdio[3].write(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }) + '\0');
  });
}

async function evaluate(session, expression) {
  const response = await send('Runtime.evaluate', {
    expression, awaitPromise: true, returnByValue: true, userGesture: true,
  }, session);
  if (response.exceptionDetails) throw new Error(JSON.stringify(response.exceptionDetails));
  return response.result.value;
}

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(action, label, timeout = 40000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await action()) return;
    await delay(150);
  }
  throw new Error(`Timed out waiting for ${label}`);
}

function check(label) { checks.push(label); console.log(`PASS ${label}`); }
function rows(result) {
  const fields = Object.keys(expected.records[0]);
  return result.rows.map(row => Object.fromEntries(fields.map(field => [field, row[field]])));
}
const expected = JSON.parse(fs.readFileSync(path.join(extension, 'samples/expected.json'), 'utf8'));

async function click(session, label, index = 0) {
  // Flutter commits semantics after the frame that updates async list data.
  await delay(550);
  let center;
  await until(async () => {
    center = await evaluate(session, `(() => {
      const label = ${JSON.stringify(label)};
      const roots = [document];
      for (let i = 0; i < roots.length; i++) {
        for (const element of roots[i].querySelectorAll('*')) {
          if (element.shadowRoot) roots.push(element.shadowRoot);
        }
      }
      const element = roots.flatMap(root => [...root.querySelectorAll('flt-semantics[role="button"],flt-semantics[role="checkbox"]')])
        .filter(el => [el.getAttribute('aria-label'),el.textContent].some(value => typeof value === 'string' && value.trim().split('\\n').includes(label)))
        .filter(el => {const rect=el.getBoundingClientRect();return rect.width>0 && rect.height>0 && rect.y>=0 && rect.x>=0 && rect.bottom<=innerHeight && rect.right<=innerWidth;})[${index}];
      if (!element) return null;
      const rect = element.getBoundingClientRect();
      return {x: rect.x + rect.width / 2, y: rect.y + rect.height / 2};
    })()`);
    return center;
  }, `button ${label}`);
  for (const type of ['mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', { type, ...center, button: 'left', clickCount: 1 }, session);
  }
  await delay(350);
}

async function query(session, options = {}) {
  return JSON.parse(await evaluate(session,
    `window.mxPrototype.call('query', ${JSON.stringify(JSON.stringify(options))})`));
}

async function clearCryptDialog(session) {
  await delay(750);
  while (await evaluate(session, `(() => {
    const roots=[document];
    for(let i=0;i<roots.length;i++)for(const el of roots[i].querySelectorAll('*'))if(el.shadowRoot)roots.push(el.shadowRoot);
    return roots.some(root=>[...root.querySelectorAll('flt-semantics[role="button"]')].some(el=>[el.getAttribute('aria-label'),el.textContent].some(value=>typeof value==='string' && value.trim()==='移除这一组')));
  })()`)) await click(session, '移除这一组');
}

async function key(session, key, code, virtualKey, modifiers = 0) {
  for (const type of ['keyDown', 'keyUp']) await send('Input.dispatchKeyEvent', {
    type, key, code, windowsVirtualKeyCode: virtualKey, modifiers,
  }, session);
}

async function fillText(session, hint, text, index = 0) {
  await delay(550);
  let center;
  await until(async () => {
    center = await evaluate(session, `(() => {
      const roots = [document];
      for (let i = 0; i < roots.length; i++) for (const el of roots[i].querySelectorAll('*')) if (el.shadowRoot) roots.push(el.shadowRoot);
      const inputs = roots.flatMap(root => [...root.querySelectorAll('input,textarea')]);
      const matches = inputs.filter(el => {
        const label = [el.getAttribute('aria-label'),el.getAttribute('placeholder'),el.closest('flt-semantics')?.getAttribute('aria-label')].join(' ');
        const rect = el.getBoundingClientRect();
        return el.type !== 'file' && rect.width > 0 && rect.height > 0 && label.includes(${JSON.stringify(hint)});
      });
      const el = matches[${index}];
      if (!el) return null;
      const rect = el.getBoundingClientRect();
      return {x: rect.x + rect.width/2, y: rect.y + rect.height/2};
    })()`);
    return center;
  }, 'text field ' + hint);
  for (const type of ['mousePressed','mouseReleased']) await send('Input.dispatchMouseEvent', {type,...center,button:'left',clickCount:1},session);
  // Flutter moves its native editing input after the focus frame commits.
  await delay(150);
  await key(session, 'a', 'KeyA', 65, 4);
  await key(session, 'Backspace', 'Backspace', 8);
  if (text) await send('Input.insertText', {text}, session);
  await delay(250);
}

async function state(session) {
  return JSON.parse(await evaluate(session, 'window.mxPrototype.state()'));
}

async function hasText(session, text) {
  const found = await evaluate(session, `(() => {
    const roots = [document];
    for (let i = 0; i < roots.length; i++) for (const el of roots[i].querySelectorAll('*')) if (el.shadowRoot) roots.push(el.shadowRoot);
    return roots.some(root => [...root.querySelectorAll('*')].some(el =>
      [el.getAttribute('aria-label'), el.getAttribute('aria-valuetext'), el.value, el.textContent]
        .some(value => typeof value === 'string' && value.replace(/\\s/g, '').includes(${JSON.stringify(text.replace(' ',''))}.replace(/\\s/g,'')))));
  })()`);
  if (found) return true;
  const tree = await send('Accessibility.getFullAXTree', {}, session);
  const normalized = text.replace(/\s/g,'');
  return tree.nodes.some(node => [node.name,node.value,node.description,...(node.properties||[]).map(property=>property.value)]
    .some(value=>typeof value?.value === 'string' && value.value.replace(/\s/g,'').includes(normalized)));
}

async function screenshot(session, name) {
  await delay(500);
  const shot = await send('Page.captureScreenshot', {format: 'png'}, session);
  fs.writeFileSync(path.join(root, 'dist', name), Buffer.from(shot.data, 'base64'));
}

async function verify() {
  const version = await send('Browser.getVersion');
  const { id } = await send('Extensions.loadUnpacked', { path: extension });
  check('Manifest V3 extension loaded in ' + version.product);
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId: session } = await send('Target.attachToTarget', { targetId, flatten: true });
  testSession = session;
  const monitor = message => {
    if (message.method === 'Runtime.consoleAPICalled' && message.params.args.some(a=>String(a.value).includes('DEBUG'))) console.log(message.params.args.map(a=>a.value || a.description).join(' '));
    if (message.method === 'Network.requestWillBeSent') requests.add(message.params.request.url);
    if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails);
    if (message.method === 'Log.entryAdded' && message.params.entry.level === 'error') errors.push(message.params.entry);
    if (message.method === 'Target.attachedToTarget') {
      const child = message.params.sessionId;
      Promise.all([
        send('Runtime.enable', {}, child), send('Network.enable', {}, child),
        send('Log.enable', {}, child),
      ]).then(() => send('Runtime.runIfWaitingForDebugger', {}, child)).catch(error => errors.push(String(error)));
    }
  };
  listeners.add(monitor);
  await send('Runtime.enable', {}, session);
  await send('Network.enable', {}, session);
  await send('Log.enable', {}, session);
  await send('Page.enable', {}, session);
  await send('Target.setAutoAttach', { autoAttach: true, waitForDebuggerOnStart: true, flatten: true }, session);
  await send('Network.setBlockedURLs', { urls: ['http://*', 'https://*'] }, session);
  await send('Network.emulateNetworkConditions', {
    offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0,
  }, session);
  const localeScript = await send('Page.addScriptToEvaluateOnNewDocument', { source: `localStorage.removeItem('mxlogger-locale'); Object.defineProperty(navigator, 'language', {get:()=> 'ja-JP'}); Object.defineProperty(navigator, 'languages', {get:()=> ['ja-JP']});` }, session);
  await send('Page.addScriptToEvaluateOnNewDocument', {source: `
    window.mxStartupEvents = [];
    const OriginalWorker = Worker;
    window.Worker = class extends OriginalWorker {
      constructor(...args) {
        super(...args);
        this.addEventListener('message', event => {
          const message = JSON.parse(event.data);
          if (message.startup) window.mxStartupEvents.push(message.startup);
        });
      }
    };
  `}, session);
  await send('Page.navigate', { url: `chrome-extension://${id}/index.html?verify=1` }, session);
  await until(() => evaluate(session, 'Boolean(window.mxPrototype)'), 'Flutter and SQLite startup');
  await send('Page.removeScriptToEvaluateOnNewDocument', { identifier: localeScript.identifier }, session);
  check('Flutter + CanvasKit + SQLite WASM started offline under extension CSP');
  assert.strictEqual((await state(session)).locale, 'en');
  assert.strictEqual((await state(session)).fonts.loaded, false);
  assert.strictEqual((await state(session)).fonts.recommendedCjk, true);
  check('Unsupported browser locale (Japanese) falls back to English');
  await click(session, '切换为中文');

  const fontCheck = await evaluate(session, `(async () => {
    const manifest = await (await fetch('assets/FontManifest.json')).json();
    const entry = manifest.find(family => family.family === 'NotoSansSC');
    const asset = entry.fonts[0].asset;
    const bytes = await (await fetch('assets/' + asset)).arrayBuffer();
    const kit = window.flutterCanvasKit;
    const typeface = kit.Typeface.MakeFreeTypeFaceFromData(bytes);
    if (!typeface) throw new Error('CanvasKit cannot decode the Chinese font');
    const font = new kit.Font(typeface, 16);
    const text = ${JSON.stringify(uiCharacters)} + 'ABC123';
    const glyphs = Array.from(font.getGlyphIDs(text));
    font.delete();
    typeface.delete();
    const placeholderAsset = manifest.find(family => family.family === 'MXMissingGlyph').fonts[0].asset;
    const placeholderFace = kit.Typeface.MakeFreeTypeFaceFromData(await (await fetch('assets/' + placeholderAsset)).arrayBuffer());
    const placeholderFont = new kit.Font(placeholderFace,16);
    const placeholders = Array.from(placeholderFont.getGlyphIDs('龘ひ𠮷',3));
    placeholderFont.delete(); placeholderFace.delete();
    return {asset, missing: [...text].filter((character, index) => glyphs[index] === 0), placeholders};
  })()`);
  assert(fontCheck.asset.endsWith('.woff2'));
  assert.deepStrictEqual(fontCheck.missing, []);
  assert(fontCheck.placeholders.every(glyph => glyph !== 0), JSON.stringify(fontCheck));
  assert(!fs.existsSync(path.join(extension,'assets/assets/fonts/NotoSansSC.woff2')));
  assert(fs.statSync(path.join(root,'dist/mxlogger-chrome-prototype.zip')).size < 5 * 1048576);
  check('Small UI font covers all Chinese interface labels; placeholder avoids automatic font downloads');
  const bundledFonts = await evaluate(session, `(async () => {
    const manifest = await (await fetch('assets/FontManifest.json')).json();
    const samples = {Roboto:'ABC123éЖΩñ',NotoSansSymbols2:'⚠☑✓',NotoSansMath:'↔∫∞√∑'};
    const kit = window.flutterCanvasKit;
    const result = {};
    for (const [family, text] of Object.entries(samples)) {
      const asset = manifest.find(entry => entry.family === family).fonts[0].asset;
      const face = kit.Typeface.MakeFreeTypeFaceFromData(await (await fetch('assets/' + asset)).arrayBuffer());
      const font = new kit.Font(face, 16);
      result[family] = {asset,missing:[...text].filter((char,index)=>!font.getGlyphIDs(text,[...text].length)[index])};
      font.delete(); face.delete();
    }
    return result;
  })()`);
  for (const font of Object.values(bundledFonts)) {
    assert(font.asset.endsWith('.woff2'));
    assert.deepStrictEqual(font.missing, []);
  }
  assert(!fs.existsSync(path.join(extension,'assets/fonts/fallback/Roboto-Regular.ttf')));
  assert(!fs.existsSync(path.join(extension,'fonts/roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2')));
  check('Compressed Roboto and common symbol fonts render offline without duplicate fallback files');
  await evaluate(session, `window.mxPrototype.fontProbe(${JSON.stringify('{"message":"\\u9f98"}')})`);
  assert.strictEqual((await state(session)).fonts.missing, true);
  check('Missing-font detection examines decoded Unicode in JSON strings');

  if (process.argv.includes('--font-live-only')) {
    await send('Network.setBlockedURLs', {urls:[]}, session);
    await send('Network.emulateNetworkConditions', {offline:false,latency:0,downloadThroughput:-1,uploadThroughput:-1}, session);
    await click(session, '字体设置');
    await click(session, '下载安装字体');
    await until(async () => {
      const fonts = (await state(session)).fonts;
      if (fonts.error && !fonts.busy) throw new Error('Live font download failed: ' + fonts.error);
      return fonts.cached && !fonts.busy;
    }, 'live official font download', 120000);
    assert([...requests].filter(url=>/^https?:/.test(url)).every(url=>fontURLs.includes(url)));
    assert.deepStrictEqual(errors, []);
    check('Live pinned Google Fonts download succeeds under extension CSP without host permissions');
    fs.writeFileSync(path.join(root,'dist/font-download-verification.json'), JSON.stringify({browser:version.product,checks,resources:[...requests],errors},null,2));
    return;
  }

  await send('Page.setInterceptFileChooserDialog', { enabled: true }, session);
  let chooser;
  const chooserListener = message => {
    if (message.method === 'Page.fileChooserOpened') chooser = message.params;
  };
  listeners.add(chooserListener);
  async function selectFiles(label, fileNames) {
    chooser = null;
    await click(session, label);
    await until(() => Boolean(chooser), 'file chooser');
    await send('DOM.setFileInputFiles', {
      backendNodeId: chooser.backendNodeId,
      files: fileNames.map(name => path.isAbsolute(name) ? name : path.join(root, 'web/samples', name)),
    }, session);
  }
  await selectFiles('选择日志文件', ['sample_plain.mx']);
  await until(async () => (await state(session)).wizardFiles === 1, 'wizard selected file');
  await delay(350);
  await click(session, '下一步');
  await delay(600);
  assert(await hasText(session, 'KEY 和 IV 仅保存在当前浏览器会话中'));
  assert(await hasText(session, '在此浏览器保存 KEY 和 IV'));
  await click(session, '开始导入');
  await until(async () => (await query(session)).total === expected.records.length, 'plain import');
  await until(async () => (await state(session)).loaded === expected.records.length, 'shared log cards');
  let result = await query(session);
  assert.deepStrictEqual(rows(result), expected.records);
  assert.strictEqual(result.fileHeader, expected.fileHeader);
  check('Native file chooser and complete import wizard match all native fields and timestamps');
  await click(session, '收起筛选区');
  assert.strictEqual((await state(session)).headerCollapsed, true);
  assert.deepStrictEqual(rows(await query(session)), expected.records);
  await screenshot(session, 'analyzer-collapsed.png');
  await click(session, '展开筛选区');
  assert.strictEqual((await state(session)).headerCollapsed, false);
  check('Header collapse button preserves the log dataset and restores filters');
  await screenshot(session, 'analyzer-dark.png');

  await click(session, '清除数据');
  await click(session, '清空');
  await until(async () => (await query(session)).total === 0, 'initial cache clear');
  assert.strictEqual((await state(session)).wizardFiles, 0);
  await evaluate(session, 'window.mxPrototype.importSample(false)');
  await until(async () => (await state(session)).loaded === 12, 'reimport after clear');
  check('Clearing recreates storage and resets stale wizard file handles');

  await fillText(session, '搜索日志', 'timeout');
  await until(async () => (await state(session)).matched === 1, 'search in shared UI');
  await click(session, '全屏查看');
  await until(() => hasText(session, '关闭 (Esc)'), 'detail dialog');
  await fillText(session, '在本条日志中搜索', 'timeout');
  await click(session, '下一处 (Enter)');
  await screenshot(session, 'analyzer-detail.png');
  await click(session, '关闭 (Esc)');
  await delay(350);
  await click(session, '查看上下文（全局前后日志）');
  await until(() => hasText(session, '当前日志'), 'context anchor');
  const sampleContext = JSON.parse(await evaluate(session, `window.mxPrototype.call('context', '${JSON.stringify({timestamp:expected.records[5].timestamp})}')`));
  assert.strictEqual(sampleContext.olderCount,5);
  assert.strictEqual(sampleContext.total,12);
  await screenshot(session, 'analyzer-context.png');
  await key(session, 'Escape', 'Escape', 27);
  await delay(350);
  check('Real keyword input, log details and global context dialogs');
  const downloads = fs.mkdtempSync(path.join(os.tmpdir(), 'mxlogger-export-'));
  await send('Browser.setDownloadBehavior', {behavior:'allow',downloadPath:downloads,eventsEnabled:true});
  await click(session, '分享日志（当前筛选结果）');
  await until(() => fs.readdirSync(downloads).some(name => name.endsWith('.txt')), 'filtered TXT export');
  const exported = fs.readFileSync(path.join(downloads, fs.readdirSync(downloads).find(name=>name.endsWith('.txt'))),'utf8');
  assert(exported.includes('timeout after 15s'));
  assert(exported.includes('筛选结果 1/12 条'));
  assert(!exported.includes('cold start 412ms'));
  check('Browser download contains exactly the current filtered logs and header');
  await click(session, '清除搜索内容');
  await until(async () => (await state(session)).matched === 12, 'clear keyword');

  // The diagnostic import uses the exact same host/repository/store pipeline.
  result = JSON.parse(await evaluate(session, 'window.mxPrototype.importSample(true)'));
  assert.deepStrictEqual(rows(result), expected.records);
  check('Worker AES-CFB import feeds the shared analyzer pages');

  result = await query(session, { keyword: 'timeout' });
  assert.strictEqual(result.matched, 1);
  result = await query(session, { levels: [3] });
  assert.strictEqual(result.matched, expected.records.filter(row => row.level === 3).length);
  result = await query(session, { limit: 3, offset: 3 });
  assert.deepStrictEqual(rows(result), expected.records.slice(3, 6));
  check('SQL keyword search, level filtering and pagination');

  await click(session, '切换到浅色模式');
  await until(async () => (await state(session)).theme === 'light', 'light theme');
  await screenshot(session, 'analyzer-light.png');
  await click(session, '切换为英文');
  await until(async () => (await state(session)).locale === 'en', 'English locale');
  await send('Page.reload', { ignoreCache: true }, session);
  await until(() => evaluate(session, 'Boolean(window.mxPrototype)'), 'reload recovery');
  const startup = await evaluate(session, 'window.mxStartupEvents');
  const cacheReads = startup.filter(event => event.stage === 'cache' && event.total > 0);
  assert(cacheReads.length >= 2, 'Cache restore must report its byte progress');
  assert.strictEqual(cacheReads[0].loaded, 0);
  const lastRead = cacheReads[cacheReads.length - 1];
  assert.strictEqual(lastRead.loaded, lastRead.total);
  for (let i = 1; i < cacheReads.length; i++) {
    assert(cacheReads[i].loaded >= cacheReads[i - 1].loaded);
  }
  assert(startup.some(event => event.stage === 'index'));
  assert(startup.some(event => event.stage === 'ready'));
  check('Reopening reports real cache bytes from 0 to 100 percent and distinct startup stages');
  result = await query(session);
  assert.deepStrictEqual(rows(result), expected.records);
  assert.strictEqual(result.fileName, 'sample_encrypted.mx');
  assert.strictEqual((await state(session)).theme, 'light');
  assert.strictEqual((await state(session)).locale, 'en');
  assert.strictEqual((await state(session)).cryptEntries, 0);
  assert.strictEqual((await state(session)).persistCrypt, false);
  assert.strictEqual(await evaluate(session, 'localStorage.getItem("mx_crypt_entries")'), null);
  assert.strictEqual((await state(session)).canReparse, false);
  check('Logs, theme and language persist; decryption keys stay session-only');
  await click(session, '切换为中文');
  await click(session, '切换到深色模式');

  await selectFiles('更换日志文件', ['sample_encrypted.mx']);
  await click(session, '开始导入');
  await until(() => hasText(session, '解析失败'), 'missing-key error');
  assert.deepStrictEqual(rows(await query(session)), expected.records);
  check('Missing decryption parameters preserve existing data');

  await selectFiles('更换日志文件', ['sample_encrypted.mx']);
  await click(session, '添加一组');
  await fillText(session, '16位解密密钥', 'wrong_key');
  await click(session, '添加一组');
  await fillText(session, '16位解密密钥', 'mxlogger123', 1);
  await click(session, '开始导入');
  await until(async () => (await state(session)).canReparse && (await state(session)).importStatus === 'idle', 'candidate key import');
  assert.deepStrictEqual(rows(await query(session)), expected.records);
  assert.strictEqual((await state(session)).cryptEntries, 2);
  check('Real encrypted file import tries multiple KEY/IV groups in order');
  await click(session, '管理解密 KEY / IV');
  await click(session, '移除这一组', 1);
  await click(session, '应用并重新解析');
  await until(() => hasText(session, '重新解析失败'), 'failed reparse');
  assert.deepStrictEqual(rows(await query(session)), expected.records);
  await click(session, '管理解密 KEY / IV');
  await click(session, '添加一组');
  await fillText(session, '16位解密密钥', 'mxlogger123');
  await click(session, '应用并重新解析');
  await until(() => hasText(session, '已使用新 Key/IV 重新解析'), 'successful reparse');
  assert.deepStrictEqual(rows(await query(session)), expected.records);
  check('KEY/IV management reparses original File handles and preserves data on failure');

  await click(session, '管理解密 KEY / IV');
  assert(await hasText(session, '不会上传到任何服务器'));
  await click(session, '在此浏览器保存 KEY 和 IV');
  assert.strictEqual((await state(session)).persistCrypt, true);
  await click(session, '添加一组');
  await fillText(session, '16位解密密钥', 'local_key_123456');
  await fillText(session, '16位偏移向量', 'local_iv_1234567');
  await click(session, '应用并重新解析');
  await until(async () => (await state(session)).cryptEntries === 3 && (await state(session)).importStatus === 'idle', 'save keys with persistence enabled');
  const savedCrypt = await evaluate(session, 'localStorage.getItem("mx_crypt_entries")');
  assert.deepStrictEqual(JSON.parse(savedCrypt), [
    {key:'wrong_key',iv:'',enabled:true},
    {key:'mxlogger123',iv:'',enabled:true},
    {key:'local_key_123456',iv:'local_iv_1234567',enabled:true},
  ]);
  await send('Page.reload', {ignoreCache:true}, session);
  await until(() => evaluate(session, 'Boolean(window.mxPrototype)'), 'persistent key recovery');
  assert.strictEqual((await state(session)).cryptEntries, 3);
  assert.strictEqual((await state(session)).persistCrypt, true);
  assert.strictEqual(await evaluate(session, 'localStorage.getItem("mx_crypt_entries")'), savedCrypt);
  assert.deepStrictEqual(rows(await query(session)), expected.records);
  check('Opt-in stores all KEY/IV groups locally and restores them after reload');

  await click(session, '管理解密 KEY / IV');
  assert(await hasText(session, 'KEY 和 IV 仅保存在此浏览器中'));
  await screenshot(session, 'analyzer-crypt-local.png');
  await click(session, '在此浏览器保存 KEY 和 IV');
  assert.strictEqual((await state(session)).persistCrypt, false);
  assert.deepStrictEqual(await evaluate(session, '["mx_crypt_entries","mx_crypt_key","mx_crypt_iv"].map(key => localStorage.getItem(key))'), [null,null,null]);
  await click(session, '取消');
  assert.strictEqual((await state(session)).cryptEntries, 3);
  await send('Page.reload', {ignoreCache:true}, session);
  await until(() => evaluate(session, 'Boolean(window.mxPrototype)'), 'opt-out key removal');
  assert.strictEqual((await state(session)).cryptEntries, 0);
  assert.strictEqual((await state(session)).persistCrypt, false);
  check('Opt-out removes persisted keys, keeps the active session and survives reload');

  await selectFiles('更换日志文件', ['sample_plain.mx']);
  await clearCryptDialog(session);
  await click(session, '开始导入');
  await until(async () => (await query(session)).fileName === 'sample_plain.mx', 'local file import');
  assert.deepStrictEqual(rows(await query(session)), expected.records);
  check('Shared data-page file selection imports into worker storage');

  const fixturePaths = [0,1].map(index => path.join(root, 'tool/fixtures', `fixture${index}.mx`));
  await selectFiles('更换日志文件', fixturePaths);
  await click(session, '导入前清空已有数据');
  await click(session, '开始导入');
  await until(async () => (await query(session)).total === 100, 'multi-file replacement');
  await until(async () => (await state(session)).loaded === 50, 'first virtual page');
  result = await query(session);
  assert.strictEqual(result.fileName, 'fixture0.mx +1');
  assert.deepStrictEqual(result.levels, {'0':20,'1':20,'2':20,'3':20,'4':20});
  assert.strictEqual(JSON.parse(result.rows[0].fileHeader).source, 'fixture0');
  assert.strictEqual(JSON.parse(result.rows[99].fileHeader).source, 'fixture1');
  await evaluate(session, `Object.defineProperty(navigator, 'language', {get:()=> 'en-US', configurable:true})`);
  assert.strictEqual((await state(session)).fonts.loaded, false);
  assert.strictEqual((await state(session)).fonts.missing, true);
  assert.strictEqual((await state(session)).fonts.recommendedCjk, true);
  await screenshot(session, 'font-needed.png');
  check('Chinese/Japanese log content prompts for fonts even with an English browser language');

  await click(session, '字体设置');
  await selectFiles('导入本地字体文件', ['sample_plain.mx']);
  await until(async () => (await state(session)).fonts.error === 'invalid', 'reject non-font file');
  assert(await hasText(session, '字体文件无效或校验失败'));
  assert.strictEqual((await query(session)).total, 100);
  await selectFiles('导入本地字体文件', [path.join(root,'dist/font-packs/mxlogger-cjk.woff2')]);
  await until(async () => (await state(session)).fonts.cached && !(await state(session)).fonts.busy, 'install local WOFF2 font', 60000);
  assert.strictEqual((await state(session)).fonts.missing, false);
  assert.strictEqual((await state(session)).fonts.error, null);
  await screenshot(session, 'font-installed.png');
  await click(session, '完成');
  await send('Page.reload', {ignoreCache:true}, session);
  await until(() => evaluate(session, 'Boolean(window.mxPrototype)'), 'offline font cache recovery');
  assert.strictEqual((await state(session)).fonts.cached, true);
  assert.strictEqual((await state(session)).fonts.loaded, true);
  assert.strictEqual((await state(session)).fonts.error, null);
  assert.deepStrictEqual([...requests].filter(url=>/^https?:/.test(url)), []);
  check('Invalid font is recoverable; local WOFF2 installs and reloads from offline cache');

  await click(session, '字体设置');
  await click(session, '移除字体缓存');
  assert.strictEqual((await state(session)).fonts.cached, false);
  assert.strictEqual((await state(session)).fonts.loaded, true);
  await click(session, '完成');
  await send('Page.reload', {ignoreCache:true}, session);
  await until(() => evaluate(session, 'Boolean(window.mxPrototype)'), 'font cache removal');
  assert.strictEqual((await state(session)).fonts.loaded, false);
  assert.strictEqual((await query(session)).total, 100);
  check('Removing a font cache preserves logs and takes effect on the next page load');

  // Fulfill the explicit download with the exact pinned upstream font bytes.
  // This exercises the real fetch, CORS, digest, progress and cache pipeline
  // without depending on Internet availability during regression tests.
  let fontDownloadCount = 0;
  let fontMode = 'invalid';
  let heldFontRequest;
  const fontDownloadListener = message => {
    if (message.method !== 'Fetch.requestPaused') return;
    const request = message.params.request;
    if (!fontURLs.includes(request.url)) return;
    fontDownloadCount++;
    try {
      assert.strictEqual(request.method, 'GET');
      assert.strictEqual(request.postData, undefined);
      if (fontMode === 'cancel') { heldFontRequest = message.params.requestId; return; }
      const valid = fontMode === 'fallback' && request.url === fontURLs[1];
      send('Fetch.fulfillRequest', {
        requestId:message.params.requestId, responseCode:200,
        responseHeaders:[{name:'Content-Type',value:'font/ttf'},{name:'Access-Control-Allow-Origin',value:'*'}],
        body:valid ? fs.readFileSync(path.join(root,'assets/fonts/NotoSansSC.ttf')).toString('base64') : Buffer.from('invalid font response').toString('base64'),
      }, session).catch(error => errors.push(String(error)));
    } catch (error) { errors.push(String(error)); }
  };
  listeners.add(fontDownloadListener);
  await send('Fetch.enable', {patterns:fontURLs.map(url=>({urlPattern:url,requestStage:'Request'}))}, session);
  await send('Network.setBlockedURLs', {urls:[]}, session);
  await send('Network.emulateNetworkConditions', {offline:false,latency:0,downloadThroughput:-1,uploadThroughput:-1}, session);
  await click(session, '字体设置');
  await click(session, '下载安装字体');
  await until(async () => (await state(session)).fonts.error === 'download' && !(await state(session)).fonts.busy, 'font source error details');
  assert.strictEqual((await state(session)).fonts.cached, false);
  assert.deepStrictEqual((await state(session)).fonts.attempts.map(attempt=>attempt.code), ['integrity','integrity']);
  assert(await hasText(session, 'jsDelivr：文件校验失败'));
  assert(await hasText(session, 'Google Fonts (GitHub)：文件校验失败'));
  await screenshot(session, 'font-download-error.png');
  check('Failed sources show specific reasons and never install unverified font data');

  fontMode = 'cancel';
  fontDownloadCount = 0;
  await click(session, '下载安装字体');
  await until(() => Boolean(heldFontRequest), 'pending font request');
  await click(session, '取消下载');
  await until(async () => !(await state(session)).fonts.busy, 'font download cancellation');
  assert.strictEqual(fontDownloadCount, 1);
  assert.strictEqual((await state(session)).fonts.error, null);
  assert.strictEqual((await state(session)).fonts.cached, false);
  await send('Fetch.failRequest', {requestId:heldFontRequest,errorReason:'Aborted'}, session).catch(() => {});
  check('Cancel stops downloading without showing a network error or starting a fallback request');

  const failureChecks = await evaluate(session, `(async () => {
    const originalFetch = window.fetch, originalTimeout = window.setTimeout;
    const bytes = new Uint8Array([1,2,3,4]);
    const hash = await window.mxFontDigest(bytes);
    const urls = ${JSON.stringify(fontURLs)};
    const results = [];
    // Accelerate only the bridge's deadlines; test both a stalled connection
    // and a body that stops delivering bytes after headers have arrived.
    window.setTimeout = (callback,ms,...args) => originalTimeout(callback,[12000,20000,120000].includes(ms) ? (ms === 120000 ? 500 : 20) : ms,...args);
    try {
      for (const mode of ['http','network','connect','body']) {
        let calls = 0;
        window.fetch = async (url,options) => {
          calls++;
          if (options.method !== 'GET' || options.credentials !== 'omit') throw new Error('Unexpected request');
          if (url === urls[1]) return new Response(bytes);
          if (mode === 'http') return new Response('',{status:503});
          if (mode === 'network') throw new TypeError('Failed to fetch');
          if (mode === 'connect') return new Promise((resolve,reject) => options.signal.addEventListener('abort',()=>reject(new DOMException('Aborted','AbortError'))));
          return new Response(new ReadableStream({start(controller) {
            options.signal.addEventListener('abort',()=>controller.error(new DOMException('Aborted','AbortError')));
          }}));
        };
        const result = await window.mxDownloadFont(urls,hash,()=>{});
        results.push({mode,calls,error:result.error,attempts:JSON.parse(result.attempts),bytes:Array.from(result.bytes || [])});
      }
    } finally {window.fetch = originalFetch;window.setTimeout = originalTimeout;}
    return results;
  })()`);
  for (const result of failureChecks) {
    assert.strictEqual(result.calls, 2);
    assert.strictEqual(result.error, null);
    assert.deepStrictEqual(result.bytes, [1,2,3,4]);
    assert.strictEqual(result.attempts[0].code, ['connect','body'].includes(result.mode) ? 'timeout' : result.mode);
  }
  assert.strictEqual(failureChecks[0].attempts[0].status, 503);
  check('HTTP errors, failed connections and stalled transfers switch sources with accurate reasons');

  fontMode = 'fallback';
  fontDownloadCount = 0;
  await click(session, '下载安装字体');
  await until(async () => (await state(session)).fonts.cached && !(await state(session)).fonts.busy, 'verified font download', 60000);
  assert.strictEqual(fontDownloadCount, 2);
  assert.strictEqual((await state(session)).fonts.error, null);
  assert.strictEqual((await state(session)).fonts.sourceIndex, 1);
  check('Unavailable or invalid primary source switches automatically to a verified fallback');
  await click(session, '完成');
  await send('Fetch.disable', {}, session);
  listeners.delete(fontDownloadListener);
  await send('Network.setBlockedURLs', {urls:['http://*','https://*']}, session);
  await send('Network.emulateNetworkConditions', {offline:true,latency:0,downloadThroughput:0,uploadThroughput:0}, session);
  await send('Page.reload', {ignoreCache:true}, session);
  await until(() => evaluate(session, 'Boolean(window.mxPrototype)'), 'downloaded font offline recovery');
  assert.strictEqual((await state(session)).fonts.cached, true);
  assert.strictEqual((await state(session)).fonts.error, null);
  fontCheck.packMissing = await evaluate(session, `(async () => {
    const records = await window.mxFontStore('list');
    const kit = window.flutterCanvasKit;
    const face = kit.Typeface.MakeFreeTypeFaceFromData(records[0].bytes);
    const font = new kit.Font(face,16);
    const text = '中文日志解析器用户登录失败網絡錯誤龘龖齉日本語ひらがなカタカナABC123';
    const glyphs = Array.from(font.getGlyphIDs(text));
    font.delete(); face.delete();
    return [...text].filter((character,index) => glyphs[index] === 0);
  })()`);
  assert.deepStrictEqual(fontCheck.packMissing, []);
  check('Explicit font-only GET validates upstream bytes and caches complete Chinese/Japanese coverage offline');
  await until(async () => (await state(session)).loaded === 50, 'font reload list recovery');
  await screenshot(session, 'analyzer-json.png');
  check('Multi-file replacement deduplicates overlaps and retains per-file headers');
  await send('Input.dispatchMouseEvent', {type:'mouseWheel',x:700,y:850,deltaY:200000,deltaX:0},session);
  await until(async () => (await state(session)).loaded === 100, 'next virtual page');
  check('Shared list loads the second page from worker SQL');
  for (const [options, count] of [
    [{scope:'content',keyword:'日本語'},100],
    [{scope:'name',keyword:'Auth'},50],
    [{scope:'tag',keyword:'session'},50],
    [{tags:['auth'],names:['Auth'],levels:[0,2]},20],
    [{fromUs:1700000000000001+10*123457,toUs:1700000000000001+19*123457},10],
  ]) assert.strictEqual((await query(session, options)).matched, count);
  const context = JSON.parse(await evaluate(session, `window.mxPrototype.call('context', '${JSON.stringify({timestamp:1700000000000001+50*123457,limit:3})}')`));
  assert.strictEqual(context.olderCount,50);
  assert.strictEqual(context.total,100);
  assert.deepStrictEqual(context.older.map(row=>JSON.parse(row.msg).index),[49,48,47]);
  assert.deepStrictEqual(context.newer.map(row=>JSON.parse(row.msg).index),[51,52,53]);
  const options = JSON.parse(await evaluate(session, `window.mxPrototype.call('options','{}')`));
  assert(options.tags.includes('session') && options.names.includes('Network'));
  check('Scope, tag/name, level/time combinations and context pagination retain desktop semantics');
  await click(session, '回到顶部');
  await delay(700);
  await fillText(session, '搜索日志', 'JSON_FIXTURE');
  await until(async () => {const value=await state(session);return value.filter.keyword==='JSON_FIXTURE' && value.loaded===50 && value.matched===100;}, 'JSON keyword');
  await click(session, '全屏查看');
  await fillText(session, '在本条日志中搜索', '深层内容');
  await click(session, '下一处 (Enter)');
  await screenshot(session, 'analyzer-json-detail.png');
  await click(session, '关闭 (Esc)');
  await click(session, '清除搜索内容');
  check('Chinese/Japanese JSON cards and search expand nested detail matches offline');

  await fillText(session, '搜索日志', '#session');
  await key(session,'Enter','Enter',13);
  await until(async () => (await state(session)).matched===50,'tag autocomplete');
  await delay(550);
  await key(session,'Backspace','Backspace',8);
  await until(async () => (await state(session)).matched===100,'remove autocomplete filter');
  await fillText(session, '搜索日志', '@Network');
  await key(session,'Enter','Enter',13);
  await until(async () => (await state(session)).matched===50,'name autocomplete');
  await delay(550);
  await key(session,'Backspace','Backspace',8);
  await until(async () => (await state(session)).matched===100,'remove autocomplete filter');
  check('Keyboard tag and name autocomplete queries worker options');
  for (const type of ['dragEnter','dragOver','drop']) await send('Input.dispatchDragEvent', {
    type,x:700,y:500,data:{items:[],files:[path.join(root,'web/samples/sample_plain.mx')],dragOperationsMask:1},
  },session);
  await until(async ()=>(await query(session)).total===12,'dragged file import');
  assert.deepStrictEqual(rows(await query(session)),expected.records);
  check('Native browser file drag/drop runs the shared import pipeline');

  const largeIndex = process.argv.indexOf('--large');
  if (largeIndex >= 0) {
    for (let i=0;i<2;i++) {
      const file = process.argv[largeIndex+1+i];
      if (!file || !fs.existsSync(file)) throw new Error('Provide plaintext and encrypted large fixtures');
      await selectFiles('更换日志文件', [file]);
      await clearCryptDialog(session);
      if (i === 1) {
        await click(session, '添加一组');
        await fillText(session, '16位解密密钥', 'mxlogger_key_123');
        await fillText(session, '16位偏移向量', 'mxlogger_iv_4567');
      }
      await click(session, '导入前清空已有数据');
      const began = Date.now();
      await click(session, '开始导入');
      const responseBegan = Date.now();
      await state(session);
      assert(Date.now()-responseBegan < 3000, 'UI thread blocked during large import');
      await until(async () => { const value = await state(session); return value.matched === 770000 && value.importStatus === 'idle'; }, '770,000-record import', 180000);
      result = await query(session, {keyword:'SENTINEL_RARE'});
      assert.strictEqual(result.total,770000);
      assert.strictEqual(result.matched,8);
      assert.deepStrictEqual(result.levels, {'0':261899,'1':261631,'2':138407,'3':92816,'4':15247});
      await send('Page.reload', {ignoreCache:true}, session);
      await until(() => evaluate(session,'Boolean(window.mxPrototype)'), 'large cache recovery');
      assert.strictEqual((await query(session,{keyword:'SENTINEL_MID'})).matched,762);
      check(`${i===0?'Plain':'AES-CFB'} 127.4 MiB / 770,000 logs: responsive UI, exact counts and reload (${Date.now()-began} ms)`);
    }
  }

  await click(session, '清除数据');
  await click(session, '清空');
  await until(async () => (await query(session)).total === 0, 'clear data');
  await send('Page.reload', { ignoreCache: true }, session);
  await until(() => evaluate(session, 'Boolean(window.mxPrototype)'), 'reload cleared data');
  assert.strictEqual((await query(session)).total, 0);
  check('Confirmed clearing persists and returns to the import wizard');

  await evaluate(session, 'window.mxPrototype.importSample(false)');
  await until(async () => (await state(session)).loaded === expected.records.length, 'final preview');
  await screenshot(session, 'prototype-preview.png');
  listeners.delete(chooserListener);
  const external = [...requests].filter(url => /^https?:/.test(url));
  assert.deepStrictEqual(external, fontURLs, `Unexpected remote requests: ${external.join(', ')}`);
  assert.deepStrictEqual(errors, [], `Browser errors: ${JSON.stringify(errors)}`);
  check('Only the user-requested font sources are contacted; no log uploads, CSP errors or JavaScript exceptions');
  const report = {
    browser: version.product, extensionId: id, checks,
    sampleRecords: expected.records.length, resources: [...requests],
    errors, profile, fontCheck,
    zipBytes: fs.statSync(path.join(root, 'dist/mxlogger-chrome-prototype.zip')).size,
  };
  fs.writeFileSync(path.join(root, 'dist/verification.json'), JSON.stringify(report, null, 2));
  console.log('Report: ' + path.join(root, 'dist/verification.json'));
}

verify().catch(async error => {
  console.error(error.stack);
  if (errors.length) console.error(JSON.stringify(errors.slice(0,10).map(e => ({text: e.text, description: e.exception && e.exception.description, url: e.url})), null, 2));
  if (testSession) {
    try {
      console.error('State:', await state(testSession));
      console.error(await evaluate(testSession, `(() => {
        const roots = [document];
        for (let i = 0; i < roots.length; i++) for (const el of roots[i].querySelectorAll('*')) if (el.shadowRoot) roots.push(el.shadowRoot);
        return roots.flatMap(root => [...root.querySelectorAll('flt-semantics')].map(el => ({label:el.getAttribute('aria-label'), role:el.getAttribute('role'),text:el.textContent.slice(0,120), rect:el.getBoundingClientRect().toJSON()}))).slice(0,20);
      })()`));
      const screenshot = await send('Page.captureScreenshot', { format: 'png' }, testSession);
      fs.writeFileSync(path.join(root, 'dist/verification-failure.png'), Buffer.from(screenshot.data, 'base64'));
    } catch (_) {}
  }
  if (!checks.length) console.error(stderr.slice(-4000));
  process.exitCode = 1;
}).finally(async () => {
  try { await send('Browser.close'); } catch (_) { browser.kill('SIGTERM'); }
  for (const task of pending.values()) clearTimeout(task.timeout);
  // Close both ends of the private CDP transport. Chromium children can keep
  // inherited pipe descriptors alive even after the browser has exited.
  browser.stdio[3].destroy();
  browser.stdio[4].destroy();
  browser.stderr.destroy();
  browser.unref();
});
