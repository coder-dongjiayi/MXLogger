// Reproducible store artwork. Uses the real unpacked extension, synthetic logs,
// and local HTML/CSS artwork. No npm dependencies or external network requests.
const fs = require('fs');
const os = require('os');
const path = require('path');
const {spawn} = require('child_process');
const {pathToFileURL} = require('url');

const source = __dirname;
const output = path.resolve(source, '..');
const extension = path.resolve(source, '../../dist/mxlogger-chrome-prototype');
const captures = path.join(source, 'captures');
fs.mkdirSync(captures, {recursive:true});
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'mxlogger-store-'));
const chrome = process.env.CHROME_BIN || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const browser = spawn(chrome, [
  '--headless=new', '--remote-debugging-pipe', '--enable-unsafe-extension-debugging',
  '--no-first-run', '--no-default-browser-check', '--disable-background-networking',
  '--disable-component-update', '--force-color-profile=srgb', `--user-data-dir=${profile}`,
], {stdio:['ignore','ignore','pipe','pipe','pipe']});
let sequence = 0, buffer = '', stderr = '';
const pending = new Map(), listeners = new Set();
browser.stderr.on('data', chunk => stderr += chunk);
browser.stdio[3].on('error', () => {});
browser.on('exit', (code, signal) => {
  for (const task of pending.values()) {
    clearTimeout(task.timer);
    task.reject(new Error(`Chrome exited: ${code ?? signal}. ${stderr.slice(-1600)}`));
  }
  pending.clear();
});
browser.stdio[4].on('data', chunk => {
  buffer += chunk.toString();
  let end;
  while ((end = buffer.indexOf('\0')) >= 0) {
    const message = JSON.parse(buffer.slice(0,end)); buffer = buffer.slice(end+1);
    if (message.id) {
      const task = pending.get(message.id);
      if (!task) continue;
      pending.delete(message.id); clearTimeout(task.timer);
      message.error ? task.reject(new Error(JSON.stringify(message.error))) : task.resolve(message.result);
    } else for (const listener of listeners) listener(message);
  }
});
function send(method, params={}, sessionId) {
  return new Promise((resolve,reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {pending.delete(id);reject(new Error(`Timeout: ${method}`));},45000);
    pending.set(id,{resolve,reject,timer});
    browser.stdio[3].write(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})})+'\0');
  });
}
async function evaluate(session,expression) {
  const r = await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true,userGesture:true},session);
  if(r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails));
  return r.result.value;
}
const pause = ms => new Promise(r=>setTimeout(r,ms));
async function until(action,label) {
  const end = Date.now()+40000;
  while(Date.now()<end) {if(await action())return;await pause(180);}
  throw new Error(`Waiting for ${label}`);
}
async function tab(width,height) {
  const {targetId} = await send('Target.createTarget',{url:'about:blank'});
  const {sessionId} = await send('Target.attachToTarget',{targetId,flatten:true});
  await send('Runtime.enable',{},sessionId);
  await send('Page.enable',{},sessionId);
  await send('Network.enable',{},sessionId);
  await send('Network.setBlockedURLs',{urls:['http://*','https://*']},sessionId);
  await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false},sessionId);
  await send('Emulation.setTimezoneOverride',{timezoneId:'Asia/Shanghai'},sessionId);
  return {targetId,session:sessionId};
}
const rootQuery = `const roots=[document];for(let i=0;i<roots.length;i++)for(const el of roots[i].querySelectorAll('*'))if(el.shadowRoot)roots.push(el.shadowRoot);`;
async function click(session,label,index=0) {
  await pause(350);
  let position;
  await until(async()=>{
    position = await evaluate(session,`(()=>{${rootQuery}
      const matches=roots.flatMap(root=>[...root.querySelectorAll('flt-semantics[role="button"],flt-semantics[role="checkbox"]')])
      .filter(el=>[el.getAttribute('aria-label'),el.textContent].some(t=>typeof t==='string' && t.trim().split('\\n').includes(${JSON.stringify(label)})))
      .filter(el=>{const r=el.getBoundingClientRect();return r.width>0&&r.height>0&&r.y>=0&&r.x>=0&&r.bottom<=innerHeight&&r.right<=innerWidth;});
      const el=matches[${index}];if(!el)return null;const r=el.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
    return position;
  },'button '+label);
  for(const type of ['mousePressed','mouseReleased'])await send('Input.dispatchMouseEvent',{type,...position,button:'left',clickCount:1},session);
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:2,y:2},session);
  await pause(500);
}
async function key(session,key,code,virtual,modifiers=0) {
  for(const type of ['keyDown','keyUp'])await send('Input.dispatchKeyEvent',{type,key,code,windowsVirtualKeyCode:virtual,modifiers},session);
}
async function fill(session,hint,text,index=0) {
  let point;
  await until(async()=>{
    point=await evaluate(session,`(()=>{${rootQuery}
      const items=roots.flatMap(r=>[...r.querySelectorAll('input,textarea')]).filter(el=>{const r=el.getBoundingClientRect();return el.type!=='file'&&r.width>0&&r.height>0&&[el.getAttribute('aria-label'),el.getAttribute('placeholder'),el.closest('flt-semantics')?.getAttribute('aria-label')].join(' ').includes(${JSON.stringify(hint)});});
      const el=items[${index}];if(!el)return null;const r=el.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
    return point;
  },'field '+hint);
  for(const type of ['mousePressed','mouseReleased'])await send('Input.dispatchMouseEvent',{type,...point,button:'left',clickCount:1},session);
  await key(session,'a','KeyA',65,4);
  await key(session,'Backspace','Backspace',8);
  await send('Input.insertText',{text},session);
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:2,y:2},session);
  await pause(600);
}
async function screenshot(session,file) {
  await pause(650);
  const r=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false},session);
  fs.writeFileSync(file,Buffer.from(r.data,'base64'));
  console.log('Saved '+path.relative(output,file));
}
const state = session => evaluate(session,'JSON.parse(window.mxPrototype.state())');

async function captureApp() {
  const {id}=await send('Extensions.loadUnpacked',{path:extension});
  const {targetId,session}=await tab(1184,900);
  await send('Page.addScriptToEvaluateOnNewDocument',{source:`localStorage.setItem('mxlogger-locale','en');localStorage.setItem('mxlogger-theme','dark');`},session);
  await send('Page.navigate',{url:`chrome-extension://${id}/index.html?verify=1`},session);
  await until(()=>evaluate(session,'Boolean(window.mxPrototype)'),'extension startup');
  await send('Page.setInterceptFileChooserDialog',{enabled:true},session);
  let chooser;
  const listen=message=>{if(message.sessionId===session&&message.method==='Page.fileChooserOpened')chooser=message.params;};
  listeners.add(listen);
  async function select(label,file) {
    chooser=null;await click(session,label);await until(()=>chooser,'file picker');
    await send('DOM.setFileInputFiles',{backendNodeId:chooser.backendNodeId,files:[path.join(source,'fixtures',file)]},session);
    await pause(400);
  }
  await select('Choose log file','demo-encrypted.mx');
  await click(session,'Next');
  await click(session,'Add key set');
  await fill(session,'16-byte decryption key','mxlogger-demo-01');
  await fill(session,'16-byte IV','demo-vector-0001');
  await screenshot(session,path.join(captures,'05-decrypt.png'));
  await click(session,'Start import');
  await until(async()=> (await state(session)).loaded>0,'demo import');
  console.log('Imported state: '+JSON.stringify(await state(session)));
  await send('Emulation.setDeviceMetricsOverride',{width:1184,height:538,deviceScaleFactor:1,mobile:false},session);
  await click(session,'Collapse all');
  await screenshot(session,path.join(captures,'01-overview.png'));
  await send('Emulation.setDeviceMetricsOverride',{width:1184,height:760,deviceScaleFactor:1,mobile:false},session);
  await screenshot(session,path.join(captures,'hero-overview.png'));
  await send('Emulation.setDeviceMetricsOverride',{width:1184,height:538,deviceScaleFactor:1,mobile:false},session);

  await click(session,'Switch to light mode');
  await fill(session,'Search logs','timeout');
  await until(async()=> (await state(session)).matched===8,'keyword matches');
  await screenshot(session,path.join(captures,'02-search.png'));

  await click(session,'Switch to dark mode');
  await send('Emulation.setDeviceMetricsOverride',{width:1184,height:840,deviceScaleFactor:1,mobile:false},session);
  await click(session,'View fullscreen');
  await fill(session,'Search within','timeout').catch(async()=>{
    const tree=await send('Accessibility.getFullAXTree',{},session);
    console.log(tree.nodes.filter(n=>n.role?.value==='textbox').map(n=>n.name?.value));
    throw new Error('Detail search field not found');
  });
  await screenshot(session,path.join(captures,'03-json.png'));
  await click(session,'Close (Esc)');
  await click(session,'View context (surrounding logs)');
  await screenshot(session,path.join(captures,'04-context.png'));
  listeners.delete(listen);
  await send('Target.closeTarget',{targetId});
}

const logo = `<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="3" width="42" height="42" rx="11" fill="#1b263b" stroke="#526584" stroke-width="1.5"/><rect x="11" y="11" width="11" height="11" rx="3" fill="#75849f"/><rect x="11" y="26" width="11" height="11" rx="3" fill="#75849f"/><rect x="26" y="26" width="11" height="11" rx="3" fill="#75849f"/><rect x="26" y="11" width="11" height="11" rx="3" fill="#71b7ff"/><path d="m31.5 16.5 9.5-9.5" stroke="#71b7ff" stroke-width="2.4" stroke-linecap="round"/><circle cx="41" cy="7" r="3.2" fill="#71b7ff"/></svg>`;
function imageData(name) {return 'data:image/png;base64,'+fs.readFileSync(path.join(captures,name)).toString('base64');}
const css = `
*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden}
body{font-family:-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif;-webkit-font-smoothing:antialiased;color:#f2f6fd;background:#0c111b}
.art{width:100%;height:100%;position:relative;overflow:hidden;background:radial-gradient(ellipse at 95% 0%,#193353 0,transparent 48%),#0c111b}
.art:before{content:'';position:absolute;inset:0;background-image:linear-gradient(#ffffff04 1px,transparent 1px),linear-gradient(90deg,#ffffff04 1px,transparent 1px);background-size:44px 44px;mask-image:linear-gradient(90deg,transparent,#000)}
.light{color:#172943;background:radial-gradient(ellipse at 100% 0%,#d2e4fd 0,transparent 60%),#edf3fa}
.brand{position:absolute;left:48px;top:30px;display:flex;align-items:center;gap:10px;font-size:12px;font-weight:650;letter-spacing:2px;color:#a4b5cd}
.brand svg{width:27px;height:27px}.light .brand{color:#526b8b}
.page{position:absolute;right:48px;top:38px;font:12px ui-monospace,Menlo,monospace;color:#8b9bb3;letter-spacing:2px}
h1{position:absolute;left:48px;top:79px;margin:0;font-size:46px;font-weight:720;letter-spacing:-1.8px;line-height:1.13}
.sub{position:absolute;left:50px;top:148px;margin:0;font-size:18px;color:#9bacc4;letter-spacing:-.2px}.light .sub{color:#5a708d}
.window{position:absolute;left:48px;top:204px;width:1184px;border-radius:14px;overflow:hidden;border:1px solid #4b628050;box-shadow:0 22px 50px #0005;background:#050506}
.chrome{height:32px;display:flex;align-items:center;justify-content:space-between;background:#1a2332;border-bottom:1px solid #34465b;padding:0 15px;font:10px ui-monospace,Menlo,monospace;color:#a2b1c7}
.light .chrome{background:#e1e9f5;border-color:#c5d1e1;color:#627695}
.dots{display:flex;gap:5px}.dots i{width:6px;height:6px;border-radius:50%;background:#66738a}.chrome .sample{font-size:9px;letter-spacing:1.4px;color:#8296b1}
.screen{display:block;width:100%;height:auto}.window.tall{width:1184px;height:572px}.window.tall .screen{width:100%;height:538px;object-fit:cover;object-position:top}
.split h1{top:170px;width:320px;font-size:46px;line-height:1.15}.split .sub{top:303px;width:298px;line-height:1.65;font-size:18px}
.split .window{left:395px;top:114px;width:836px}.split .window .screen{width:100%;height:auto}
.points{position:absolute;left:50px;top:455px;display:flex;flex-direction:column;gap:20px;font-size:15px;color:#c6d2e4}
.points span{display:flex;align-items:center;gap:12px}.points b{width:5px;height:5px;background:#70b9ff;border-radius:50%}
.footnote{position:absolute;left:50px;bottom:49px;font:11px ui-monospace,Menlo,monospace;letter-spacing:1.5px;color:#6688b0}
`;
function documentHTML(body,extra=''){return `<!doctype html><meta charset="utf-8"><style>${css}${extra}</style>${body}`;}
function brand(){return `<div class="brand">${logo}<span>MXLOGGER ANALYZER</span></div>`;}
function windowHTML(image,cls=''){return `<div class="window ${cls}"><div class="chrome"><div class="dots"><i></i><i></i><i></i></div><span>MXLogger Analyzer · .mx workspace</span><span class="sample">SAMPLE DATA</span></div><img class="screen" src="${imageData(image)}"></div>`;}
function slide(index,title,sub,image,light=false){return documentHTML(`<div class="art${light?' light':''}">${brand()}<div class="page">0${index} / 05</div><h1>${title}</h1><p class="sub">${sub}</p>${windowHTML(image,'tall')}</div>`);}
function splitSlide(index,title,sub,points,image){return documentHTML(`<div class="art split">${brand()}<div class="page">0${index} / 05</div><h1>${title}</h1><p class="sub">${sub}</p><div class="points">${points.map(p=>`<span><b></b>${p}</span>`).join('')}</div><div class="footnote">LOCAL LOGS. CLEAR ANSWERS.</div>${windowHTML(image)}</div>`);}

async function render() {
  const arts=[
    ['01-overview.png',1280,800,slide(1,'Your .mx logs, in focus.','Import and explore MXLogger logs in a dedicated Chrome workspace.','01-overview.png')],
    ['02-search.png',1280,800,slide(2,'Find the log that matters.','Search by keyword. Narrow it down by level, tag, name or time.','02-search.png',true)],
    ['03-json-details.png',1280,800,splitSlide(3,'Make JSON<br>easy to read.','Explore nested JSON with syntax highlighting and search inside each log.', ['Collapsible JSON trees','Highlighted search matches','Copy or export what you need'],'03-json.png')],
    ['04-context.png',1280,800,splitSlide(4,'An error is only<br>part of the story.','See the surrounding logs to understand what happened before and after.', ['Jump from a filtered result','Keep the surrounding timeline','Trace events across log levels'],'04-context.png')],
    ['05-local-decryption.png',1280,800,splitSlide(5,'Encrypted logs.<br>Local answers.','Decrypt on your machine with the KEY and IV used to create your logs.', ['Multiple KEY / IV sets','Session-only keys by default','Optional local key storage'],'05-decrypt.png')],
  ];
  const small=documentHTML(`<div class="art small"><div class="icon">${logo}</div><div class="name">MXLogger<br>Analyzer</div><div class="tagline">Local logs. Clear answers.</div><div class="rule"></div><div class="actions">IMPORT <i>·</i> DECRYPT <i>·</i> SEARCH</div><div class="file">.mx</div></div>`, `.small .icon{position:absolute;left:28px;top:27px;width:65px;height:65px}.small .name{position:absolute;left:112px;top:29px;font-size:32px;font-weight:720;line-height:1.08;letter-spacing:-1px}.small .tagline{position:absolute;left:32px;top:132px;font-size:22px;font-weight:530;letter-spacing:-.6px;color:#e1ebfa}.small .rule{position:absolute;left:32px;top:183px;width:376px;height:1px;background:#405a7b77}.small .actions{position:absolute;left:32px;top:208px;font-size:11px;letter-spacing:1.5px;font-weight:600;color:#a1b6d2}.small .actions i{font-style:normal;margin:0 8px;color:#5e7c9e}.small .file{position:absolute;right:34px;top:204px;font:21px ui-monospace,Menlo,monospace;color:#72b8ff}`);
  const hero=documentHTML(`<div class="art hero">${brand()}<h1>From logs<br>to answers.</h1><p class="sub">Import. Decrypt. Search.<br>All on your machine.</p><div class="badge"><span></span> LOCAL .mx LOGS &nbsp; / &nbsp; OFFLINE READY</div>${windowHTML('hero-overview.png')}<div class="glow"></div></div>`, `.hero .brand{left:64px;top:51px;font-size:15px;letter-spacing:1.3px}.hero .brand svg{width:38px;height:38px}.hero h1{left:64px;top:139px;font-size:75px;letter-spacing:-3.5px;line-height:1.02}.hero .sub{left:68px;top:327px;font-size:23px;line-height:1.55;color:#a8bcd6}.hero .badge{position:absolute;left:68px;bottom:51px;display:flex;align-items:center;gap:9px;font:11px ui-monospace,Menlo,monospace;letter-spacing:.7px;color:#84a6ce}.hero .badge span{width:6px;height:6px;border-radius:50%;background:#71b7ff}.hero .window{left:610px;top:91px;width:846px;transform:rotate(-4deg);transform-origin:center;box-shadow:-30px 30px 90px #0008;border-color:#546f964d}.hero .chrome{height:28px}.hero .glow{position:absolute;width:6px;height:6px;left:1280px;top:58px;border-radius:50%;background:#89c5ff;box-shadow:0 0 30px #71b7ff}`);
  arts.push(['promo-small-440x280.png',440,280,small],['promo-marquee-1400x560.png',1400,560,hero]);
  const {session,targetId}=await tab(1280,800);
  for(const [name,width,height,html] of arts){
    const htmlPath=path.join(source,name.replace('.png','.html'));
    fs.writeFileSync(htmlPath,html);
    await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false},session);
    await send('Page.navigate',{url:pathToFileURL(htmlPath).href},session);
    await until(()=>evaluate(session,`document.readyState==='complete'&&Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0)`),'artwork images');
    await evaluate(session,'document.fonts.ready.then(()=>true)');
    const layout=await evaluate(session,`({width:innerWidth,height:innerHeight,scrollWidth:document.documentElement.scrollWidth,titleBottom:document.querySelector('h1')?.getBoundingClientRect().bottom,subtitleTop:document.querySelector('.sub')?.getBoundingClientRect().top,images:[...document.images].map(i=>({loaded:i.naturalWidth>0}))})`);
    if(layout.width!==width||layout.height!==height||layout.images.some(i=>!i.loaded)||layout.titleBottom>layout.subtitleTop-8)throw new Error('Artwork layout failed '+name+' '+JSON.stringify(layout));
    await screenshot(session,path.join(output,name));
  }
  // A separate, non-uploadable overview makes all seven assets easy to review.
  const thumbs=arts.map(([name,w,h])=>`<div><img src="data:image/png;base64,${fs.readFileSync(path.join(output,name)).toString('base64')}"><p>${name} · ${w} × ${h}</p></div>`).join('');
  const contact=documentHTML(`<main>${thumbs}</main>`,`body{background:#e7ecf4;color:#3b4b63}main{display:grid;grid-template-columns:repeat(2,1fr);gap:25px;padding:30px}main div{min-width:0}main img{display:block;width:100%;height:350px;object-fit:contain;background:#dbe2ed;border-radius:8px}main p{font:13px ui-monospace,Menlo,monospace;margin:11px 0 0;text-align:center}`);
  const contactPath=path.join(source,'contact-sheet.html');fs.writeFileSync(contactPath,contact);
  await send('Emulation.setDeviceMetricsOverride',{width:1280,height:1670,deviceScaleFactor:1,mobile:false},session);
  await send('Page.navigate',{url:pathToFileURL(contactPath).href},session);
  await until(()=>evaluate(session,`document.readyState==='complete'&&[...document.images].every(i=>i.complete&&i.naturalWidth)`),'contact sheet');
  await screenshot(session,path.join(output,'preview-contact-sheet.png'));
  await send('Target.closeTarget',{targetId});
}

(async()=>{
  try{
    await send('Browser.getVersion');
    if(!process.argv.includes('--render-only'))await captureApp();
    await render();
  }finally{
    await send('Browser.close').catch(()=>browser.kill());
  }
})().catch(error=>{console.error(error.stack);process.exitCode=1;});
