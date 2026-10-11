// X 告知の正方形画像（1080×1080）を JSON から作る。**記事ごとにスクリプトを増やさないため**の共通版。
//   node scripts/gen-x-panels.mjs ops/data/x-cards/<slug>.panels.json
//
// 骨格は JAL（4-service.jpg）と FUNDS（cards.mjs）で承認されたもの：**帯 ＋ 本体**。
// 本体は 3 通り。
//   wide … 横長の写真 ＋ 要点 3 つ（FUNDS の 1 枚目）
//   cal  … 見頃カレンダーのような横棒（日付の範囲を並べる）
//   html … 自由に組む（同じ CSS の部品 .rows / .steps / .big / .chips を使う）
// 写真・ロゴのパスは imageBase（public/images/<slug>）からの相対。**出所の行は出さない**（x-post-images §3）。
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const cfg = JSON.parse(fs.readFileSync(path.resolve(process.argv[2]), "utf8"));
const BASE = path.join(ROOT, cfg.imageBase);
const OUT = path.join(ROOT, cfg.out);
fs.mkdirSync(OUT, { recursive: true });

// **ブログの :root のトークンだけ**（x-post-images §1-B）。帯の地・見出しの差し色・地色
const THEMES = {
  plum:  { b1: "#2A1923", b2: "#46293A", k: "#F5C518", em: "#F5C518" },
  berry: { b1: "#A82959", b2: "#D63E76", k: "#FFF1C8", em: "#F5C518" },
  rose:  { b1: "#D63E76", b2: "#EC5C90", k: "#FFF1C8", em: "#FFF1C8" },
  ink:   { b1: "#1E1219", b2: "#2A1923", k: "#F5C518", em: "#F5C518" },
};
const T = THEMES[cfg.theme || "plum"];
const src = (p) => "file://" + path.join(BASE, p);

const items = (xs) => `<ul class="row">${xs.map((x) => `<li>${x.logo ? `<img class="ilogo" src="${src(x.logo)}" alt="">` : ""}<div class="h">${x.h}</div><div class="b">${x.b}</div>${x.s ? `<div class="s">${x.s}</div>` : ""}</li>`).join("")}</ul>`;

// cal: 10/1〜12/31 のような期間を横軸に、行ごとに棒を引く。open は「〜」で終わりが無いもの（右へ薄れる）
function cal(c) {
  const [y0, y1] = [new Date(c.from), new Date(c.to)];
  const span = (y1 - y0) / 864e5;
  const x = (d) => (100 * ((new Date(d) - y0) / 864e5)) / span;
  const months = c.months.map((m) => `<div class="m" style="left:${x(m.at)}%">${m.label}</div>`).join("");
  const ticks = (c.ticks || []).map((t) => `<div class="tick" style="left:${x(t)}%"></div>`).join("");
  const marks = (c.marks || []).map((m) => `<div class="mark" style="left:${x(m.at)}%"><span>${m.label}</span></div>`).join("");
  const rows = c.rows.map((r) => {
    const a = x(r.start), b = r.open ? Math.min(100, a + 9) : x(r.end);
    return `<div class="crow${r.hl ? " hl" : ""}"><div class="cn"><b>${r.name}</b>${r.sub ? `<i>${r.sub}</i>` : ""}</div>
      <div class="ct">${ticks}<div class="bar${r.open ? " open" : ""}" style="left:${a}%;width:${b - a}%"></div><div class="cl" style="left:${r.labelAt != null ? x(r.labelAt) : a}%">${r.label}</div></div></div>`;
  }).join("");
  return `<div class="cal"><div class="axis"><div class="cn"></div><div class="ct">${months}</div></div>${rows}<div class="marks"><div class="cn"></div><div class="ct">${marks}</div></div></div>`;
}

const page = (p) => `<!doctype html><html lang="ja"><head><meta charset="utf-8"><style>
:root{--b1:${T.b1};--b2:${T.b2};--k:${T.k};--em:${T.em};--pink:#D63E76;--pink-700:#A82959;--cream:#FFFBEE;--cream-2:#FFF1C8;--yellow:#F5C518;--ink:#2A1923;--ink-2:#5A4651;--line:#F1DCE5}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1080px;overflow:hidden}
body{font-family:"Noto Sans JP",sans-serif;background:var(--cream);color:var(--ink)}
header{height:${p.headH || 250}px;background:linear-gradient(135deg,var(--b1),var(--b2));display:flex;align-items:center;justify-content:space-between;gap:24px;padding:0 64px;position:relative;overflow:hidden}
header > *{position:relative;z-index:2}
header .bg{position:absolute;inset:-8px;z-index:0;background-size:cover;background-position:${p.bgPos || "center"};opacity:${p.bgOpacity ?? 0.16};filter:blur(1.5px)}
header .scrim{position:absolute;inset:0;z-index:1;background:linear-gradient(90deg,rgba(0,0,0,.35),rgba(0,0,0,.05))}
header .tt{min-width:0;flex:1}
header .k{font-size:31px;font-weight:700;color:var(--k);letter-spacing:.03em;white-space:nowrap}
header h1{font-size:${p.size || 70}px;font-weight:900;line-height:1.15;margin-top:8px;color:#fff;white-space:nowrap;text-shadow:0 2px 10px rgba(0,0,0,.25)}
header h1 em{font-style:normal;color:var(--em)}
header .logo{flex:0 0 auto;background:#fff;border-radius:22px;padding:14px 20px;box-shadow:0 10px 26px -12px rgba(0,0,0,.5)}
header .logo img{height:56px;display:block}
main{padding:34px 64px 0;display:flex;flex-direction:column;gap:26px}
.shot{position:relative;width:952px;height:${p.shotH || 560}px;border-radius:30px;overflow:hidden;background:#fff;border:8px solid #fff;box-shadow:0 22px 44px -18px rgba(42,25,35,.38)}
.shot img{width:100%;height:100%;object-fit:cover;object-position:${p.imgPos || "center"};display:block;border-radius:22px}
.shot .cap{position:absolute;left:22px;bottom:20px;background:rgba(30,18,25,.72);color:#fff;font-size:20px;font-weight:700;padding:8px 16px;border-radius:12px}
ul.row{list-style:none;display:flex;gap:18px}
ul.row li{flex:1;background:#fff;border:2px solid var(--line);border-radius:22px;padding:20px 22px;box-shadow:0 8px 24px -14px rgba(214,62,118,.28);min-width:0}
ul.row .ilogo{height:38px;max-width:100%;object-fit:contain;display:block;margin-bottom:8px}
ul.row .h{font-size:21px;font-weight:700;color:var(--pink)}
ul.row .b{font-size:27px;font-weight:900;line-height:1.3;margin-top:4px}
ul.row .s{font-size:18px;font-weight:500;color:var(--ink-2);margin-top:6px;line-height:1.45}
.note{background:var(--cream-2);border-radius:18px;padding:18px 24px;font-size:24px;font-weight:700;line-height:1.5}
.note b{color:var(--pink-700)}
/* cal */
.cal{background:#fff;border:2px solid var(--line);border-radius:26px;padding:22px 26px 18px;box-shadow:0 8px 24px -14px rgba(214,62,118,.28)}
.cal .axis,.cal .crow,.cal .marks{display:flex;align-items:center}
.cal .cn{flex:0 0 250px;display:flex;flex-direction:column}
.cal .cn b{font-size:27px;font-weight:900;line-height:1.2}
.cal .cn i{font-style:normal;font-size:17px;color:var(--ink-2);font-weight:500}
.cal .ct{flex:1;position:relative;height:100%}
.cal .axis{height:40px;border-bottom:2px solid var(--line)}
.cal .m{position:absolute;top:2px;font-size:22px;font-weight:900;color:var(--ink-2);padding-left:6px;border-left:2px solid var(--line);height:38px}
.cal .crow{height:${p.rowH || 74}px;border-bottom:1px dashed var(--line)}
.cal .crow.hl{background:linear-gradient(90deg,#FFF1C8,#FFFBEE);border-radius:14px}
.cal .tick{position:absolute;top:0;bottom:0;border-left:1px solid #F6E8EE}
.cal .bar{position:absolute;top:12px;height:22px;border-radius:11px;background:linear-gradient(90deg,#E8743B,#D63E76)}
.cal .bar.open{background:linear-gradient(90deg,#E8743B,rgba(214,62,118,0));border-radius:11px 0 0 11px}
.cal .crow.hl .bar{background:linear-gradient(90deg,#D63E76,#A82959)}
.cal .crow.hl .bar.open{background:linear-gradient(90deg,#A82959,rgba(168,41,89,0))}
.cal .cl{position:absolute;top:38px;font-size:19px;font-weight:700;white-space:nowrap;color:var(--ink)}
.cal .crow.hl .cl{color:var(--pink-700);font-weight:900}
.cal .marks{height:34px}
.cal .mark{position:absolute;top:-${(p.rowH || 74) * (p.rows || 0) + 6}px;bottom:30px;border-left:3px dashed var(--pink-700)}
.cal .mark span{position:absolute;bottom:-32px;left:-4px;white-space:nowrap;font-size:19px;font-weight:900;color:var(--pink-700);transform:translateX(-50%)}
/* html の部品 */
.rows{display:flex;flex-direction:column;gap:18px}
.rows .r{display:flex;align-items:center;gap:22px;background:#fff;border:2px solid var(--line);border-radius:24px;padding:20px 26px;box-shadow:0 8px 24px -14px rgba(214,62,118,.28)}
.rows .from{flex:0 0 250px;font-size:32px;font-weight:900}
.rows .from small{display:block;font-size:18px;font-weight:500;color:var(--ink-2)}
.rows .arrow{flex:0 0 auto;font-size:40px;font-weight:900;color:var(--pink)}
.rows .to{flex:1;display:flex;flex-direction:column;gap:6px;min-width:0}
.rows .to img{height:58px;max-width:420px;object-fit:contain;object-position:left;display:block}
.rows .to b{font-size:26px;font-weight:900}
.rows .to span{font-size:19px;color:var(--ink-2);font-weight:500}
.big{background:#fff;border:2px solid var(--line);border-radius:28px;padding:30px 34px;box-shadow:0 8px 24px -14px rgba(214,62,118,.28);text-align:center}
.big .lab{font-size:24px;font-weight:700;color:var(--ink-2)}
.big .num{font-size:92px;font-weight:900;line-height:1.15;color:var(--pink-700)}
.big .num small{font-size:46px}
.vs{display:flex;align-items:center;gap:20px}
.vs .c{flex:1;background:#fff;border:2px solid var(--line);border-radius:26px;padding:26px 26px;text-align:center;box-shadow:0 8px 24px -14px rgba(214,62,118,.28)}
.vs .c.on{border:4px solid var(--pink);background:#FFF6F9}
.vs .c .lab{font-size:24px;font-weight:700;color:var(--ink-2)}
.vs .c .v{font-size:58px;font-weight:900;line-height:1.2;margin-top:4px}
.vs .c.on .v{color:var(--pink-700)}
.vs .c .s{font-size:19px;color:var(--ink-2);font-weight:500;margin-top:4px}
.vs .arr{font-size:54px;font-weight:900;color:var(--pink)}
table.t{width:100%;border-collapse:separate;border-spacing:0;background:#fff;border:2px solid var(--line);border-radius:22px;overflow:hidden;font-size:25px}
table.t th{background:#FFF1C8;font-size:19px;font-weight:700;color:var(--ink-2);padding:12px 18px;text-align:left}
table.t td{padding:14px 18px;border-top:1px solid var(--line);font-weight:700}
table.t td.n{font-weight:900}
table.t tr.hl td{background:#FFF6F9;color:var(--pink-700);font-weight:900}
.steps{display:flex;flex-direction:column;gap:16px}
.steps .st{display:flex;align-items:center;gap:22px;background:#fff;border:2px solid var(--line);border-radius:24px;padding:20px 26px;box-shadow:0 8px 24px -14px rgba(214,62,118,.28)}
.steps .no{flex:0 0 64px;height:64px;border-radius:50%;background:var(--pink);color:#fff;font-size:36px;font-weight:900;display:flex;align-items:center;justify-content:center}
.steps b{font-size:30px;font-weight:900;display:block}
.steps span{font-size:20px;color:var(--ink-2);font-weight:500}
.strip{display:flex;gap:14px;height:${p.stripH || 210}px}
.strip img{flex:1;min-width:0;height:100%;object-fit:cover;border-radius:22px;border:6px solid #fff;box-shadow:0 12px 26px -14px rgba(42,25,35,.4)}
.logos{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
.logos div{background:#fff;border:2px solid var(--line);border-radius:18px;height:96px;display:flex;align-items:center;justify-content:center;padding:12px 18px}
.logos img{max-height:62px;max-width:100%;object-fit:contain}
.quote{background:#fff;border-left:10px solid var(--pink);border-radius:18px;padding:22px 28px;font-size:30px;font-weight:900;line-height:1.45;box-shadow:0 8px 24px -14px rgba(214,62,118,.28)}
.quote small{display:block;font-size:19px;font-weight:500;color:var(--ink-2);margin-top:8px}
.chips{display:flex;gap:14px}
.chips div{flex:1;background:var(--pink);color:#fff;border-radius:18px;padding:16px 18px;font-size:25px;font-weight:900;text-align:center;line-height:1.35}
${p.css || ""}
</style></head><body>
<header>${p.bgImage ? `<div class="bg" style="background-image:url('${src(p.bgImage)}')"></div><div class="scrim"></div>` : ""}<div class="tt"><div class="k">${p.kicker}</div><h1>${p.title}</h1></div>${p.logo ? `<div class="logo"><img src="${src(p.logo)}" alt=""></div>` : ""}</header>
<main>
${p.kind === "wide" ? `<div class="shot"><img src="${src(p.img)}" alt="">${p.caption ? `<div class="cap">${p.caption}</div>` : ""}</div>${items(p.items)}` : ""}
${p.kind === "cal" ? cal(p.cal) : ""}
${p.kind === "html" ? p.html.replace(/src="([^":]+)"/g, (_, f) => `src="${src(f)}"`) : ""}
${p.note ? `<div class="note">${p.note}</div>` : ""}
</main></body></html>`;

const browser = await chromium.launch({ executablePath: process.env.CHROME || "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
const pg = await browser.newPage({ viewport: { width: 1080, height: 1080 }, deviceScaleFactor: 1 });
for (const p of cfg.panels) {
  // **file:// の画像は setContent では読めない**（x-post-images §4）。出力先に一時 HTML を置いて goto する
  const tmp = path.join(OUT, ".tmp-" + p.file.replace(/\.\w+$/, ".html"));
  fs.writeFileSync(tmp, page(p));
  await pg.goto("file://" + tmp);
  await pg.waitForLoadState("networkidle");
  await pg.evaluate(() => document.fonts.ready);
  // 見出しが帯からはみ出すなら、収まるまで縮める（1 行のまま）
  const fitted = await pg.evaluate(() => {
    const h = document.querySelector("header h1"), box = document.querySelector("header .tt");
    let s = parseFloat(getComputedStyle(h).fontSize);
    while (h.scrollWidth > box.clientWidth && s > 40) { s -= 2; h.style.fontSize = s + "px"; }
    return s;
  });
  const bad = await pg.evaluate(() => [...document.images].filter((i) => !i.naturalWidth).map((i) => i.src));
  const bgOk = await pg.evaluate(async () => {
    const el = document.querySelector("header .bg"); if (!el) return true;
    const u = getComputedStyle(el).backgroundImage.slice(5, -2);
    return await new Promise((r) => { const i = new Image(); i.onload = () => r(i.naturalWidth > 0); i.onerror = () => r(false); i.src = u; });
  });
  // **読めない画像があれば止める。** 灰色の空カードがエラーも出さずに出力される（x-post-images §4）
  if (bad.length || !bgOk) throw new Error(p.file + ": 画像が読めない " + JSON.stringify(bad) + (bgOk ? "" : " ／ 帯の背景"));
  const overflow = await pg.evaluate(() => document.querySelector("main").scrollHeight + document.querySelector("header").offsetHeight > 1080);
  await pg.screenshot({ path: path.join(OUT, p.file), type: "jpeg", quality: 90 });
  fs.unlinkSync(tmp);
  console.log(p.file, "見出し " + fitted + "px", overflow ? "**下にはみ出している**" : "");
}
await browser.close();
