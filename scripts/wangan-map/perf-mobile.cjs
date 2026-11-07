// イベントマップのスマホでの動きの速さを測る（2026-11-07 利用者「モバイルで非常にもっさりして全然動かない」）。iPhone 13 相当・CPU を 6 倍遅くしてドラッグと待機の描画回数を出す。
// 使い方: npm run build && npx http-server dist -p 4329 -s & → node scripts/wangan-map/perf-mobile.cjs http://localhost:4329/wangan-map/ asis noanim
// 動く絵を足したら、足す前と後で測る。ドラッグが 45 回／秒を下回るなら足し方を見直す（2026-11-07 の直したあとは 51 回／秒）
const { chromium, devices } = require('playwright');
const URL = process.argv[2] || 'http://localhost:4329/wangan-map/';
(async () => {
  const b = await chromium.launch();
  const variants = process.argv.slice(3).length ? process.argv.slice(3) : ['asis'];
  for (const v of variants) {
    const ctx = await b.newContext({ ...devices['iPhone 13'] });
    const p = await ctx.newPage();
    const cdp = await ctx.newCDPSession(p);
    await p.goto(URL); await p.waitForTimeout(1500);
    await p.evaluate(() => document.querySelectorAll('[class*=cookie],[id*=cookie]').forEach((e) => e.remove()));
    await p.evaluate((v) => {
      const svg = document.querySelector('.wmap-svg');
      if (v.includes('noanim')) svg.pauseAnimations();
      if (v.includes('nofilter')) svg.querySelectorAll('[filter]').forEach((e) => e.removeAttribute('filter'));
      if (v.includes('nocss')) document.querySelectorAll('.wm-waves,.wm-cloud1,.wm-cloud2,.wm-pin-pulse').forEach((e) => (e.style.animation = 'none'));
    }, v);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: 6 });
    const st = await p.$('.wmap-stage'); await st.scrollIntoViewIfNeeded(); const bb = await st.boundingBox();
    await p.evaluate(() => { window.__f = 0; window.__t0 = performance.now(); const tick = () => { window.__f++; window.__raf = requestAnimationFrame(tick); }; tick(); });
    // drag using touch-like mouse events
    await p.mouse.move(bb.x + bb.width / 2, bb.y + bb.height / 2); await p.mouse.down();
    for (let i = 0; i < 30; i++) { await p.mouse.move(bb.x + bb.width / 2 - i * 6, bb.y + bb.height / 2 - i * 3); }
    await p.mouse.up();
    const r = await p.evaluate(() => { cancelAnimationFrame(window.__raf); const s = (performance.now() - window.__t0) / 1000; return { fps: +(window.__f / s).toFixed(1), sec: +s.toFixed(1) }; });
    // idle fps (animations only)
    await p.evaluate(() => { window.__f = 0; window.__t0 = performance.now(); const tick = () => { window.__f++; window.__raf = requestAnimationFrame(tick); }; tick(); });
    await p.waitForTimeout(3000);
    const idle = await p.evaluate(() => { cancelAnimationFrame(window.__raf); return +(window.__f / ((performance.now() - window.__t0) / 1000)).toFixed(1); });
    console.log(v, 'drag fps', r.fps, `(${r.sec}s for 30 moves)`, 'idle fps', idle);
    await ctx.close();
  }
  await b.close();
})();
