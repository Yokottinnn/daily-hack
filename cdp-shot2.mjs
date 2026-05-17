import { spawn } from 'child_process';
import http from 'http';
import WebSocket from 'ws';

const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new', '--disable-gpu', '--remote-debugging-port=9223',
  '--window-size=1280,900', '--hide-scrollbars'
], { stdio: 'ignore' });

await new Promise(r => setTimeout(r, 1500));
const targets = await fetch('http://127.0.0.1:9223/json').then(r => r.json());
const target = targets.find(t => t.type === 'page');
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise(r => ws.on('open', r));

let id = 0;
const send = (method, params) => new Promise(resolve => {
  const myId = ++id;
  ws.send(JSON.stringify({ id: myId, method, params }));
  const h = m => {
    const msg = JSON.parse(m);
    if (msg.id === myId) { ws.off('message', h); resolve(msg); }
  };
  ws.on('message', h);
});

await send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 900, deviceScaleFactor: 2, mobile: false });
await send('Page.navigate', { url: process.argv[2] });
await new Promise(r => setTimeout(r, 3500));
await send('Runtime.evaluate', { expression: 'document.querySelector(".figure-grid").scrollIntoView({block:"start"})' });
await new Promise(r => setTimeout(r, 500));
const shot = await send('Page.captureScreenshot', { format: 'png' });
const fs = await import('fs');
fs.writeFileSync(process.argv[3], Buffer.from(shot.result.data, 'base64'));
console.log('saved', process.argv[3]);
chrome.kill();
process.exit(0);
