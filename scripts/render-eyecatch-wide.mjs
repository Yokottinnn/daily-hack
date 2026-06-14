#!/usr/bin/env node
/**
 * render-eyecatch-wide.mjs — ブログ専用 ネイティブ16:9 eyecatch レンダラ
 *
 * X用サムネ(1:1)とは別物。ブログeyecatchは最初から 1600x900 横長で設計する。
 * 正方形を貼って余白で埋める方式は禁止（feedback_eyecatch_quality_gate）。
 *
 * Playwright は sns-templates の node_modules を借用（createRequire）。
 * Usage: node scripts/render-eyecatch-wide.mjs <data.json> <out.jpg>
 */
import { createRequire } from 'module';
import fs from 'node:fs';
import path from 'node:path';

const SNS = '/Users/ny_taxa/projects/anta-baka-x/sns-templates';
const require = createRequire(SNS + '/');
const { chromium } = require('playwright');

const FONTS = SNS + '/fonts';
// 透過版キャラを優先（背景の白四角を出さない）。無ければ通常assets。
const ASSETS_T = SNS + '/assets-transparent';
const ASSETS = SNS + '/assets';
function charSrc(file) {
  return fs.existsSync(path.join(ASSETS_T, file)) ? `${ASSETS_T}/${file}` : `${ASSETS}/${file}`;
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function panelHtml(p, side) {
  const stats = p.stats.map(s => `
    <div class="vs-stat"><span class="vs-st-label">${esc(s.label)}</span><span class="vs-st-val">${esc(s.value)}</span></div>`).join('');
  return `
  <div class="vs-panel vs-${side}" style="--pc:${p.color}">
    <div class="vs-head">${esc(p.name)}</div>
    <div class="vs-tag">${esc(p.tag)}</div>
    <div class="vs-stats">${stats}</div>
  </div>`;
}

function buildVsHtml(d) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  @font-face { font-family:"RocknRoll One"; src:url("file://${FONTS}/rocknroll-one-japanese-400.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:400; src:url("file://${FONTS}/zen-maru-gothic-japanese-400.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:700; src:url("file://${FONTS}/zen-maru-gothic-japanese-700.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:900; src:url("file://${FONTS}/zen-maru-gothic-japanese-900.woff2") format("woff2"); }
  @font-face { font-family:"Bebas Neue"; src:url("file://${FONTS}/bebas-neue-latin-400.woff2") format("woff2"); }
  :root{ --ink:#2A1923; --ink-soft:#5A4651; --magenta-strong:#D63E76; --magenta-deep:#A82959; --magenta-light:#FDE4EE; --neon:#FFEC00; }
  *{margin:0;padding:0;box-sizing:border-box;}
  html,body{width:1600px;height:900px;}
  body{ font-family:"Zen Maru Gothic",sans-serif; color:var(--ink); position:relative; overflow:hidden;
    background:radial-gradient(circle at 4% 4%,#FDE9F0 0%,transparent 36%),radial-gradient(circle at 96% 96%,#FFFBEE 0%,transparent 40%),linear-gradient(135deg,#FFF5F8 0%,#FFFFFF 52%,#FFFBEE 100%); }
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle, rgba(120,120,140,.05) 1.6px, transparent 1.6px);background-size:30px 30px;}
  .stage{position:absolute;inset:0;padding:42px 50px 36px;display:flex;flex-direction:column;}
  .head{display:flex;justify-content:space-between;align-items:flex-start;}
  .brand{display:inline-flex;align-items:center;gap:10px;background:#fff;border:2px solid var(--magenta-light);padding:9px 20px 9px 14px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:18px;height:18px;border-radius:50%;background:var(--magenta-strong);}
  .brand span{font-family:"RocknRoll One";font-size:23px;color:var(--ink);}
  .badge{background:var(--magenta-strong);color:#fff;font-family:"RocknRoll One";font-size:23px;padding:10px 22px;border-radius:14px;transform:rotate(3deg);box-shadow:0 10px 22px -8px rgba(214,62,118,.55);}
  .title-band{text-align:center;margin-top:6px;}
  .title-band .kk{color:var(--magenta-strong);font-weight:900;font-size:24px;}
  .title-band h1{font-family:"RocknRoll One";font-size:52px;color:var(--ink);line-height:1.1;}
  .arena{flex:1;display:flex;align-items:center;justify-content:center;gap:0;margin-top:10px;}
  .vs-panel{flex:1;align-self:stretch;background:#fff;border:3px solid var(--pc);border-radius:24px;padding:0 0 20px;overflow:hidden;box-shadow:0 16px 36px -18px rgba(0,0,0,.3);display:flex;flex-direction:column;margin:14px 0;}
  .vs-head{background:var(--pc);color:#fff;font-family:"RocknRoll One";font-size:40px;text-align:center;padding:18px 10px;}
  .vs-tag{align-self:center;margin:14px 0 4px;background:var(--pc);color:#fff;font-weight:900;font-size:20px;padding:5px 18px;border-radius:999px;opacity:.92;}
  .vs-stats{padding:8px 26px 0;display:flex;flex-direction:column;gap:12px;margin-top:8px;}
  .vs-stat{display:flex;flex-direction:column;gap:3px;border-bottom:1px dashed #e7d7de;padding-bottom:10px;}
  .vs-st-label{font-size:18px;color:var(--ink-soft);font-weight:700;}
  .vs-st-val{font-size:27px;color:var(--ink);font-weight:900;line-height:1.25;}
  .center{width:230px;display:flex;flex-direction:column;align-items:center;justify-content:center;flex:0 0 230px;z-index:2;}
  .vs-badge{width:104px;height:104px;border-radius:50%;background:var(--ink);color:#fff;font-family:"Bebas Neue";font-size:54px;display:flex;align-items:center;justify-content:center;box-shadow:0 10px 24px -8px rgba(0,0,0,.5);border:4px solid #fff;}
  .center .char{width:200px;height:200px;object-fit:contain;margin-top:-6px;filter:drop-shadow(0 10px 16px rgba(120,30,60,.22));}
  .center .speech{background:#fff;border:2px solid var(--magenta-light);border-radius:16px;padding:8px 14px;font-size:18px;font-weight:700;color:var(--magenta-deep);text-align:center;margin-top:-10px;box-shadow:0 8px 18px -10px rgba(214,62,118,.5);}
  .foot{display:flex;justify-content:space-between;align-items:center;margin-top:12px;background:linear-gradient(90deg,#1E6EC8 0%,#7a3a8f 50%,#D2232D 100%);border-radius:16px;padding:14px 26px;}
  .foot .verdict{color:#fff;font-weight:900;font-size:25px;}
  .foot .verdict b{color:var(--neon);}
  .foot .handle{color:#FFE0E6;font-family:"Bebas Neue";font-size:24px;letter-spacing:.04em;}
  </style></head><body>
  <div class="dots"></div>
  <div class="stage">
    <div class="head">
      <div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div>
      <div class="badge">${esc(d.badge)}</div>
    </div>
    <div class="title-band">
      <div class="kk">${esc(d.kicker)}</div>
      <h1>${d.title_html}</h1>
    </div>
    <div class="arena">
      ${panelHtml(d.left, 'left')}
      <div class="center">
        <div class="vs-badge">VS</div>
        <img class="char" src="file://${charSrc(d.character)}" alt="">
        <div class="speech">${esc(d.speech)}</div>
      </div>
      ${panelHtml(d.right, 'right')}
    </div>
    <div class="foot">
      <div class="verdict">${d.verdict_html}</div>
      <div class="handle">${esc(d.handle)}</div>
    </div>
  </div>
  </body></html>`;
}

// 共通フォント＆ブランド部品（構図テンプレ間で再利用）
const FF = `
  @font-face { font-family:"RocknRoll One"; src:url("file://${FONTS}/rocknroll-one-japanese-400.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:400; src:url("file://${FONTS}/zen-maru-gothic-japanese-400.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:700; src:url("file://${FONTS}/zen-maru-gothic-japanese-700.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:900; src:url("file://${FONTS}/zen-maru-gothic-japanese-900.woff2") format("woff2"); }
  @font-face { font-family:"Bebas Neue"; src:url("file://${FONTS}/bebas-neue-latin-400.woff2") format("woff2"); }
  :root{ --magenta:#EC5C90; --magenta-strong:#D63E76; --magenta-deep:#A82959; --magenta-light:#FDE4EE; --magenta-faint:#FFF5F8; --cream-light:#FFFBEE; --ink:#2A1923; --ink-soft:#5A4651; --neon:#FFEC00; }
  *{margin:0;padding:0;box-sizing:border-box;}
  html,body{width:1600px;height:900px;}
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle, rgba(214,62,118,.06) 1.6px, transparent 1.6px);background-size:30px 30px;}
  .brand{display:inline-flex;align-items:center;gap:10px;background:#fff;border:2px solid var(--magenta-light);padding:9px 20px 9px 14px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:18px;height:18px;border-radius:50%;background:var(--magenta-strong);}
  .brand span{font-family:"RocknRoll One";font-size:23px;color:var(--ink);}
  .badge{background:var(--magenta-strong);color:#fff;font-family:"RocknRoll One";font-size:22px;padding:10px 22px;border-radius:14px;transform:rotate(3deg);box-shadow:0 10px 22px -8px rgba(214,62,118,.55);}
  .foot{display:flex;justify-content:space-between;align-items:center;background:linear-gradient(90deg,var(--magenta-strong),var(--magenta-deep));border-radius:16px;padding:14px 26px;}
  .foot .verdict{color:#fff;font-weight:900;font-size:25px;} .foot .verdict b{color:var(--neon);}
  .foot .handle{color:#FFD9E6;font-family:"Bebas Neue";font-size:24px;letter-spacing:.04em;}
  .mark{position:relative;z-index:0;} .mark::after{content:"";position:absolute;left:-6px;right:-6px;bottom:7px;height:24px;background:var(--neon);z-index:-1;border-radius:4px;transform:rotate(-1deg);}
`;

// 【stat】ビッグナンバー型
function buildStatHtml(d) {
  const pts = (d.points || []).map(p => `<div class="sp"><span class="sp-k">${esc(p.k)}</span><span class="sp-v">${p.v_html || esc(p.v)}</span></div>`).join('');
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FF}
  body{font-family:"Zen Maru Gothic",sans-serif;color:var(--ink);position:relative;overflow:hidden;background:radial-gradient(circle at 6% 4%,var(--magenta-light) 0%,transparent 36%),radial-gradient(circle at 96% 98%,var(--cream-light) 0%,transparent 42%),linear-gradient(135deg,var(--magenta-faint),#fff 55%,var(--cream-light));}
  .stage{position:absolute;inset:0;padding:46px 56px 40px;display:flex;flex-direction:column;}
  .head{display:flex;justify-content:space-between;align-items:flex-start;}
  .body{flex:1;display:flex;gap:44px;align-items:center;}
  .left{flex:1;display:flex;flex-direction:column;}
  .kicker{color:var(--magenta-strong);font-weight:900;font-size:26px;}
  h1{font-family:"RocknRoll One";line-height:1.12;font-size:58px;margin:4px 0 20px;}
  .statbox{background:#fff;border:3px solid var(--magenta-light);border-radius:28px;padding:22px 40px 26px;box-shadow:0 18px 40px -20px rgba(214,62,118,.5);align-self:flex-start;}
  .stat-label{font-size:23px;font-weight:900;color:var(--ink-soft);display:block;}
  .stat-big{font-family:"RocknRoll One";font-size:118px;line-height:1.02;color:var(--magenta-strong);}
  .stat-big small{font-size:48px;}
  .right{width:440px;display:flex;flex-direction:column;gap:13px;}
  .sp{background:#fff;border:2px solid var(--magenta-light);border-left:9px solid var(--magenta);border-radius:14px;padding:12px 18px;display:flex;flex-direction:column;box-shadow:0 10px 24px -16px rgba(120,30,60,.35);}
  .sp-k{font-size:17px;font-weight:800;color:var(--ink-soft);} .sp-v{font-size:26px;font-weight:900;color:var(--ink);}
  .charrow{display:flex;align-items:flex-end;gap:12px;margin-top:4px;}
  .charrow .char{width:148px;height:148px;object-fit:contain;filter:drop-shadow(0 10px 16px rgba(120,30,60,.22));}
  .charrow .speech{background:#fff;border:2px solid var(--magenta-light);border-radius:16px;padding:10px 14px;font-size:18px;font-weight:700;color:var(--magenta-deep);}
  .foot{margin-top:14px;}
  </style></head><body><div class="dots"></div><div class="stage">
  <div class="head"><div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div><div class="badge">${esc(d.badge)}</div></div>
  <div class="body">
    <div class="left"><div class="kicker">${esc(d.kicker)}</div><h1>${esc(d.title1)} ${d.title2_html || ''}</h1>
      <div class="statbox"><span class="stat-label">${esc(d.stat.label)}</span><span class="stat-big">${d.stat.big_html || esc(d.stat.big)}</span></div></div>
    <div class="right">${pts}
      <div class="charrow"><img class="char" src="file://${charSrc(d.character)}"><div class="speech">${esc(d.speech)}</div></div></div>
  </div>
  <div class="foot"><div class="verdict">${d.verdict_html}</div><div class="handle">${esc(d.handle)}</div></div>
  </div></body></html>`;
}

// 【timeline】年表型
function buildTimelineHtml(d) {
  const ev = (d.events || []).map(e => `<div class="tl-row"><div class="tl-date">${esc(e.date)}</div><div class="tl-dot" style="background:${e.color || '#D63E76'}"></div><div class="tl-card"><span class="tl-kind" style="background:${e.color || '#D63E76'}">${esc(e.kind)}</span><span class="tl-name">${esc(e.name)}</span></div></div>`).join('');
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FF}
  body{font-family:"Zen Maru Gothic",sans-serif;color:var(--ink);position:relative;overflow:hidden;background:radial-gradient(circle at 4% 6%,var(--magenta-light) 0%,transparent 34%),linear-gradient(135deg,var(--magenta-faint),#fff 55%,var(--cream-light));}
  .stage{position:absolute;inset:0;padding:46px 56px 40px;display:flex;flex-direction:column;}
  .head{display:flex;justify-content:space-between;align-items:flex-start;}
  .body{flex:1;display:flex;gap:34px;margin-top:12px;}
  .left{width:540px;display:flex;flex-direction:column;}
  .kicker{color:var(--magenta-strong);font-weight:900;font-size:26px;}
  h1{font-family:"RocknRoll One";font-size:64px;line-height:1.12;margin:4px 0 14px;}
  .subline{font-size:23px;font-weight:700;color:var(--ink-soft);}
  .char-wrap{margin-top:auto;display:flex;align-items:flex-end;gap:12px;}
  .char{width:238px;height:238px;object-fit:contain;filter:drop-shadow(0 12px 20px rgba(120,30,60,.25));}
  .speech{background:#fff;border:2px solid var(--magenta-light);border-radius:18px;padding:12px 16px;font-size:19px;font-weight:700;color:var(--magenta-deep);margin-bottom:40px;}
  .tl{flex:1;display:flex;flex-direction:column;justify-content:center;gap:11px;}
  .tl-row{display:grid;grid-template-columns:118px 22px 1fr;align-items:center;gap:14px;}
  .tl-date{font-family:"Bebas Neue";font-size:25px;color:var(--ink-soft);text-align:right;letter-spacing:.02em;}
  .tl-dot{width:20px;height:20px;border-radius:50%;border:4px solid #fff;box-shadow:0 0 0 3px var(--magenta-light);justify-self:center;}
  .tl-card{background:#fff;border:2px solid var(--magenta-light);border-radius:14px;padding:11px 18px;display:flex;align-items:center;gap:13px;box-shadow:0 10px 24px -16px rgba(120,30,60,.4);}
  .tl-kind{color:#fff;font-weight:900;font-size:16px;padding:3px 12px;border-radius:999px;white-space:nowrap;}
  .tl-name{font-weight:900;font-size:25px;color:var(--ink);}
  .foot{margin-top:14px;}
  </style></head><body><div class="dots"></div><div class="stage">
  <div class="head"><div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div><div class="badge">${esc(d.badge)}</div></div>
  <div class="body">
    <div class="left"><div class="kicker">${esc(d.kicker)}</div><h1>${esc(d.title1)}${d.title2_html || ''}</h1><div class="subline">${esc(d.subline)}</div>
      <div class="char-wrap"><img class="char" src="file://${charSrc(d.character)}"><div class="speech">${esc(d.speech)}</div></div></div>
    <div class="tl">${ev}</div>
  </div>
  <div class="foot"><div class="verdict">${d.verdict_html}</div><div class="handle">${esc(d.handle)}</div></div>
  </div></body></html>`;
}

// 【feature】マガジン表紙型
function buildFeatureHtml(d) {
  const chips = (d.chips || []).map(c => `<span class="fchip">${esc(c)}</span>`).join('');
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FF}
  body{font-family:"Zen Maru Gothic",sans-serif;color:var(--ink);position:relative;overflow:hidden;background:radial-gradient(circle at 88% 14%,var(--magenta-light) 0%,transparent 42%),radial-gradient(circle at 2% 98%,var(--cream-light) 0%,transparent 46%),linear-gradient(120deg,#fff,var(--magenta-faint));}
  .stage{position:absolute;inset:0;padding:46px 56px 40px;}
  .head{display:flex;justify-content:space-between;align-items:flex-start;}
  .kicker{color:var(--magenta-strong);font-weight:900;font-size:30px;margin-top:26px;}
  h1{font-family:"RocknRoll One";font-size:90px;line-height:1.1;margin:8px 0 20px;max-width:1000px;}
  .fchips{display:flex;gap:12px;flex-wrap:wrap;max-width:980px;}
  .fchip{background:#fff;border:2px solid var(--magenta-light);border-radius:999px;padding:9px 22px;font-size:23px;font-weight:900;color:var(--magenta-deep);box-shadow:0 8px 18px -10px rgba(214,62,118,.4);}
  .subline{font-size:25px;font-weight:700;color:var(--ink-soft);margin-top:22px;max-width:880px;}
  .char{position:absolute;right:46px;bottom:90px;width:400px;height:400px;object-fit:contain;filter:drop-shadow(0 16px 26px rgba(120,30,60,.28));}
  .speech{position:absolute;right:300px;bottom:430px;background:#fff;border:2px solid var(--magenta-light);border-radius:18px;padding:11px 17px;font-size:20px;font-weight:800;color:var(--magenta-deep);box-shadow:0 10px 22px -12px rgba(214,62,118,.5);}
  .foot{position:absolute;left:56px;right:56px;bottom:40px;}
  </style></head><body><div class="dots"></div><div class="stage">
  <div class="head"><div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div><div class="badge">${esc(d.badge)}</div></div>
  <div class="kicker">${esc(d.kicker)}</div>
  <h1>${esc(d.title1)}${d.title2_html || ''}</h1>
  <div class="fchips">${chips}</div>
  <div class="subline">${esc(d.subline)}</div>
  <img class="char" src="file://${charSrc(d.character)}">
  <div class="speech">${esc(d.speech)}</div>
  <div class="foot"><div class="verdict">${d.verdict_html}</div><div class="handle">${esc(d.handle)}</div></div>
  </div></body></html>`;
}

function buildHtml(d) {
  if (d.layout === 'vs') return buildVsHtml(d);
  if (d.layout === 'stat') return buildStatHtml(d);
  if (d.layout === 'timeline') return buildTimelineHtml(d);
  if (d.layout === 'feature') return buildFeatureHtml(d);
  const cards = d.ranking.map((r, i) => {
    const rec = r.recommended;
    return `
    <div class="rank-card${rec ? ' is-top' : ''}">
      ${rec ? `<div class="ribbon">${esc(r.ribbon || '★ コスパ◎')}</div>` : ''}
      <div class="rank-no${rec ? ' gold' : ''}">${i + 1}</div>
      <div class="dot" style="background:${r.color}"></div>
      <div class="rc-name">${esc(r.name)}</div>
      <div class="rc-metric">
        <span class="rc-val">${esc(r.value)}</span>
        <span class="rc-unit">${esc(r.unit)}</span>
      </div>
    </div>`;
  }).join('');

  return `<!doctype html><html><head><meta charset="utf-8"><style>
  @font-face { font-family:"RocknRoll One"; src:url("file://${FONTS}/rocknroll-one-japanese-400.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:400; src:url("file://${FONTS}/zen-maru-gothic-japanese-400.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:700; src:url("file://${FONTS}/zen-maru-gothic-japanese-700.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:900; src:url("file://${FONTS}/zen-maru-gothic-japanese-900.woff2") format("woff2"); }
  @font-face { font-family:"Bebas Neue"; src:url("file://${FONTS}/bebas-neue-latin-400.woff2") format("woff2"); }
  :root{
    --magenta:#EC5C90; --magenta-strong:#D63E76; --magenta-deep:#A82959;
    --magenta-light:#FDE4EE; --magenta-faint:#FFF5F8; --cream-light:#FFFBEE;
    --ink:#2A1923; --ink-soft:#5A4651; --neon:#FFEC00;
  }
  *{margin:0;padding:0;box-sizing:border-box;}
  html,body{width:1600px;height:900px;}
  body{
    font-family:"Zen Maru Gothic",sans-serif; color:var(--ink); position:relative; overflow:hidden;
    background:
      radial-gradient(circle at 4% 6%, var(--magenta-light) 0%, transparent 34%),
      radial-gradient(circle at 98% 96%, var(--cream-light) 0%, transparent 40%),
      linear-gradient(135deg, var(--magenta-faint) 0%, #FFFFFF 52%, var(--cream-light) 100%);
  }
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle, rgba(214,62,118,.06) 1.6px, transparent 1.6px);background-size:30px 30px;}
  .stage{position:absolute;inset:0;padding:46px 56px 40px;display:flex;flex-direction:column;}
  /* header */
  .head{display:flex;justify-content:space-between;align-items:flex-start;}
  .brand{display:inline-flex;align-items:center;gap:10px;background:#fff;border:2px solid var(--magenta-light);
    padding:9px 20px 9px 14px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:18px;height:18px;border-radius:50%;background:var(--magenta-strong);}
  .brand span{font-family:"RocknRoll One";font-size:24px;color:var(--ink);}
  .badge{background:var(--magenta-strong);color:#fff;font-family:"RocknRoll One";font-size:24px;
    padding:10px 22px;border-radius:14px;transform:rotate(3deg);box-shadow:0 10px 22px -8px rgba(214,62,118,.55);}
  /* body */
  .body{flex:1;display:flex;gap:40px;align-items:stretch;margin-top:18px;}
  .left{width:600px;display:flex;flex-direction:column;position:relative;}
  .kicker{color:var(--magenta-strong);font-weight:900;font-size:26px;margin-bottom:6px;letter-spacing:.02em;}
  h1{font-family:"RocknRoll One";line-height:1.12;color:var(--ink);}
  h1 .l1{font-size:${d.title1_size || 104}px;display:block;white-space:nowrap;}
  h1 .l2{font-size:${d.title2_size || 74}px;display:block;margin-top:2px;white-space:nowrap;}
  .mark{position:relative;display:inline-block;z-index:0;}
  .mark::after{content:"";position:absolute;left:-6px;right:-6px;bottom:8px;height:26px;background:var(--neon);z-index:-1;border-radius:4px;transform:rotate(-1deg);}
  .subline{font-size:27px;font-weight:700;color:var(--ink-soft);margin-top:22px;}
  .char-wrap{margin-top:auto;display:flex;align-items:flex-end;gap:14px;}
  .char{width:300px;height:300px;object-fit:contain;filter:drop-shadow(0 12px 20px rgba(120,30,60,.25));}
  .speech{position:relative;background:#fff;border:2px solid var(--magenta-light);border-radius:20px;
    padding:16px 20px;font-size:23px;font-weight:700;color:var(--magenta-deep);box-shadow:0 10px 22px -12px rgba(214,62,118,.5);margin-bottom:60px;}
  .speech::after{content:"";position:absolute;left:-12px;bottom:22px;border:10px solid transparent;border-right-color:#fff;}
  /* right ranking */
  .right{flex:1;display:flex;flex-direction:column;justify-content:center;gap:14px;}
  .rank-card{position:relative;display:flex;align-items:center;gap:18px;background:#fff;border:2px solid var(--magenta-light);
    border-radius:20px;padding:16px 24px;box-shadow:0 10px 26px -14px rgba(120,30,60,.3);}
  .rank-card.is-top{border:3px solid #F5B81E;padding:20px 24px;box-shadow:0 16px 34px -14px rgba(245,160,20,.55);}
  .ribbon{position:absolute;top:-15px;right:18px;background:#F5B81E;color:#5A3B00;font-family:"RocknRoll One";font-size:18px;padding:4px 14px;border-radius:999px;}
  .rank-no{width:46px;height:46px;flex:0 0 46px;border-radius:50%;background:var(--magenta-light);color:var(--magenta-deep);
    font-family:"Bebas Neue";font-size:34px;display:flex;align-items:center;justify-content:center;}
  .rank-no.gold{background:#F5B81E;color:#fff;}
  .dot{width:16px;height:16px;border-radius:50%;flex:0 0 16px;}
  .rc-name{font-weight:900;font-size:32px;color:var(--ink);flex:1;}
  .rc-metric{display:flex;flex-direction:column;align-items:flex-end;line-height:1;}
  .rc-val{font-weight:900;font-size:30px;color:var(--magenta-strong);}
  .rc-unit{font-size:16px;color:var(--ink-soft);margin-top:5px;font-weight:700;}
  /* footer */
  .foot{display:flex;justify-content:space-between;align-items:center;margin-top:14px;
    background:linear-gradient(90deg,var(--magenta-strong),var(--magenta-deep));border-radius:16px;padding:14px 26px;}
  .foot .verdict{color:#fff;font-weight:900;font-size:25px;}
  .foot .verdict b{color:var(--neon);}
  .foot .handle{color:#FFD9E6;font-family:"Bebas Neue";font-size:24px;letter-spacing:.04em;}
  ${d.theme === 'alert' ? `
  /* ===== ALERT THEME（改悪・速報・警告）===== */
  body{ color:#FDECEF;
    background:
      radial-gradient(circle at 6% 4%, #5a1020 0%, transparent 36%),
      radial-gradient(circle at 96% 98%, #3a0a16 0%, transparent 42%),
      linear-gradient(135deg, #1c0a10 0%, #2a0d16 52%, #1a0810 100%); }
  .dots{ background-image:radial-gradient(circle, rgba(255,80,90,.07) 1.6px, transparent 1.6px); }
  .brand{ background:#1c0a10; border-color:#7a2330; }
  .brand .b-dot{ background:#FF3B4E; }
  .brand span{ color:#FDECEF; }
  .badge{ background:#FF3B4E; color:#1c0a10; }
  .kicker{ color:#FF6470; }
  h1{ color:#FFFFFF; }
  .mark::after{ background:#FF3B4E; }
  .subline{ color:#E7B9C2; }
  .speech{ background:#2a0d16; border-color:#7a2330; color:#FFD9DE; }
  .speech::after{ border-right-color:#2a0d16; }
  .rank-card{ background:#26101a; border:2px solid #5a1a28; box-shadow:0 10px 26px -14px rgba(0,0,0,.5); }
  .rank-no{ background:#5a1a28; color:#FFB3BC; }
  .rc-name{ color:#FFFFFF; }
  .rc-val{ color:#FF6470; }
  .rc-unit{ color:#C99AA4; }
  .foot{ background:linear-gradient(90deg,#FF3B4E,#A8121F); }
  .foot .verdict b{ color:#FFE34D; }
  ` : ''}
  </style></head><body>
  <div class="dots"></div>
  <div class="stage">
    <div class="head">
      <div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div>
      <div class="badge">${esc(d.badge)}</div>
    </div>
    <div class="body">
      <div class="left">
        <div class="kicker">${esc(d.kicker)}</div>
        <h1><span class="l1">${esc(d.title1)}</span><span class="l2">${d.title2_html}</span></h1>
        <div class="subline">${esc(d.subline)}</div>
        <div class="char-wrap">
          <img class="char" src="file://${charSrc(d.character)}" alt="">
          <div class="speech">${esc(d.speech)}</div>
        </div>
      </div>
      <div class="right">${cards}</div>
    </div>
    <div class="foot">
      <div class="verdict">${d.verdict_html}</div>
      <div class="handle">${esc(d.handle)}</div>
    </div>
  </div>
  </body></html>`;
}

async function main() {
  const [, , dataArg, outArg] = process.argv;
  const data = JSON.parse(fs.readFileSync(dataArg, 'utf8'));
  const html = buildHtml(data);
  const outAbs = path.resolve(outArg);
  const tmpHtml = outAbs.replace(/\.(jpg|png|jpeg)$/i, '.debug.html');
  fs.mkdirSync(path.dirname(outAbs), { recursive: true });
  fs.writeFileSync(tmpHtml, html);

  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  await page.goto('file://' + tmpHtml, { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);
  const pngPath = outAbs.replace(/\.jpg$/i, '.png');
  await page.screenshot({ path: pngPath, clip: { x: 0, y: 0, width: 1600, height: 900 } });
  await browser.close();

  // 2x PNG → 1600x900 JPG に縮小（web最適）
  const sharp = (() => { try { return require('sharp'); } catch { return null; } })();
  if (sharp) {
    await sharp(pngPath).resize(1600, 900).jpeg({ quality: 90 }).toFile(outAbs);
    fs.unlinkSync(pngPath);
  } else {
    // sharp無し: PIL で 1600x900 JPG に縮小
    const { execSync } = require('child_process');
    execSync(`python3 -c "from PIL import Image; Image.open('${pngPath}').convert('RGB').resize((1600,900), Image.LANCZOS).save('${outAbs}', quality=90)"`);
    fs.unlinkSync(pngPath);
  }
  fs.unlinkSync(tmpHtml);
  console.log('saved', outAbs);
}
main();
