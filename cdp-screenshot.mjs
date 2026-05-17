import { spawn } from 'child_process';
import http from 'http';
import WebSocket from 'ws';

const chromeArgs = [
  '--headless=new',
  '--disable-gpu',
  '--remote-debugging-port=9222',
  '--window-size=1280,900',
  '--hide-scrollbars'
];

const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', chromeArgs, { stdio: 'ignore' });

await new Promise(r => setTimeout(r, 1500));

const res = await new Promise((resolve, reject) => {
  http.get('http://127.0.0.1:9222/json', r => {
    let d = '';
    r.on('data', c => d += c);
    r.on('end', () => resolve(JSON.parse(d)));
  }).on('error', reject);
});

const target = res.find(t => t.type === 'page');
const ws = new WebSocket(target.webSocketDebuggerUrl);

await new Promise(r => ws.on('open', r));

let id = 0;
const send = (method, params) => new Promise(resolve => {
  const myId = ++id;
  ws.send(JSON.stringify({ id: myId, method, params }));
  ws.on('message', m => {
    const msg = JSON.parse(m);
    if (msg.id === myId) resolve(msg);
  });
});

await send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 900, deviceScaleFactor: 2, mobile: false });
await send('Page.navigate', { url: 'http://localhost:4321/posts/furusato-tax-daily-goods-2026/' });
await new Promise(r => setTimeout(r, 3000));
await send('Runtime.evaluate', { expression: 'document.querySelector(".figure-grid").scrollIntoView({block:"start"})' });
await new Promise(r => setTimeout(r, 500));
const shot = await send('Page.captureScreenshot', { format: 'png' });
const fs = await import('fs');
fs.writeFileSync('/tmp/cdp-shot.png', Buffer.from(shot.result.data, 'base64'));
console.log('saved');
chrome.kill();
process.exit(0);
