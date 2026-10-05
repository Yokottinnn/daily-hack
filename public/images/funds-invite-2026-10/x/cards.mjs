// FUNDS 紹介投稿の画像 4 枚（2026-10-05）。JAL の 4-service.jpg（承認済み）と同じ骨格：帯 ＋ 左に公式画面 ＋ 右に要点 3 つ。
// 数字はすべて招待ページ（invy.jp）と funds.jp に書いてあるもの（x251 / x252 で読んだ）。
//   node public/images/funds-invite-2026-10/x/cards.mjs
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CARDS = [
  { file: "1-gift.jpg", shot: "c-gift.jpg", wide: true, kicker: "紹介リンクから口座開設するだけ", title: "投資に使える現金 <em>2,000円</em>",
    items: [["条件", "口座開設だけ", "投資はしなくていい"],
            ["期限", "2026/11/30の申請まで", "12/4までに開設完了したもの"],
            ["受け取り", "翌月末までに入金", "開設した月の翌月末が目安"]] },
  { file: "2-service.jpg", shot: "c-top.jpg", kicker: "Funds（ファンズ）ってこういうサービス", title: "固定利回りの資産運用",
    items: [["値動き", "株価や為替で値動きしない", "円建ての固定利回り"],
            ["手数料", "無料。1円から", "振込手数料だけは自分持ち"],
            ["規模", "会員16万人・募集1,500億円", "2026年9月11日の発表"]] },
  { file: "3-fund.jpg", shot: "c-fund.jpg", kicker: "募集中のファンドの見え方", title: "利回りと期間が先に決まってる", size: 64,
    items: [["募集時に決まる", "予定利回りと運用期間", "あとから動かない"],
            ["投資先", "上場企業が中心", "審査を通った企業だけ"],
            ["注意", "予定利回りは確約じゃない", "元本保証でもない"]] },
  { file: "4-story.jpg", shot: "c-story.jpg", kicker: "100万円を運用した例（過去のファンド）", title: "3ヶ月に1度、分配金",
    items: [["例", "Vターンシップファンド#1", "予定利回り3.00%・約36ヶ月"],
            ["分配金", "3ヶ月に1度 約7,500円", "累計 約90,000円（税引前）"],
            ["36ヶ月目", "分配金と元本が戻る", "別のファンドに再投資もできる"]] },
];

const html = (c) => `<!doctype html><html lang="ja"><head><meta charset="utf-8"><style>
:root{--pink-600:#D63E76;--yellow-500:#F5C518;--ink:#2A1923;--ink-2:#5A4651;--line:#F1DCE5;--cream-50:#FFFBEE}
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1080px;overflow:hidden}
body{font-family:"Noto Sans JP",sans-serif;background:var(--cream-50);color:var(--ink)}
header{height:250px;background:linear-gradient(135deg,#2A1923,#46293A);display:flex;flex-direction:column;justify-content:center;padding:0 64px}
header .k{font-size:32px;font-weight:700;color:var(--yellow-500);letter-spacing:.03em}
header h1{font-size:72px;font-weight:900;line-height:1.15;margin-top:10px;color:#fff;white-space:nowrap}
header h1 em{font-style:normal;color:var(--yellow-500)}
main{display:flex;gap:40px;padding:48px 64px 0}
.shot{flex:0 0 440px;height:730px;border-radius:32px;overflow:hidden;background:#fff;border:8px solid #fff;
      box-shadow:0 22px 44px -18px rgba(214,62,118,.38)}
.shot img{width:100%;height:100%;object-fit:cover;object-position:top;display:block;border-radius:24px}
ul{list-style:none;display:flex;flex-direction:column;justify-content:space-between;height:730px;flex:1}
li{background:#fff;border:2px solid var(--line);border-radius:24px;padding:30px 28px;box-shadow:0 8px 24px -14px rgba(214,62,118,.28)}
li .h{font-size:24px;font-weight:700;color:var(--pink-600)}
li .b{font-size:32px;font-weight:900;line-height:1.3;margin-top:6px}
li .s{font-size:22px;font-weight:500;color:var(--ink-2);margin-top:6px;line-height:1.45}
main.wide{flex-direction:column;align-items:center;gap:28px;padding:34px 64px 0}
.shotw{width:952px;height:580px;border-radius:32px;overflow:hidden;background:#fff;border:8px solid #fff;box-shadow:0 22px 44px -18px rgba(214,62,118,.38)}
.shotw img{width:100%;height:100%;object-fit:cover;display:block;border-radius:24px}
ul.row{flex-direction:row;height:auto;width:952px;gap:18px}
ul.row li{flex:1;padding:18px 20px}
ul.row li .h{font-size:20px} ul.row li .b{font-size:24px;margin-top:4px} ul.row li .s{font-size:17px;margin-top:4px}
</style></head><body>
<header><div class="k">${c.kicker}</div><h1 style="font-size:${c.size || 72}px">${c.title}</h1></header>
${c.wide ? `<main class="wide"><div class="shotw"><img src="../src/${c.shot}" alt=""></div>
<ul class="row">${c.items.map(([h, b, s]) => `<li><div class="h">${h}</div><div class="b">${b}</div><div class="s">${s}</div></li>`).join("")}</ul></main>`
: `<main><div class="shot" style="background:${c.bg || "#fff"}"><img src="../src/${c.shot}" alt="" style="object-fit:${c.fit || "cover"}"></div>
<ul>${c.items.map(([h, b, s]) => `<li><div class="h">${h}</div><div class="b">${b}</div><div class="s">${s}</div></li>`).join("")}</ul></main>`}
</body></html>`;

const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
const page = await browser.newPage({ viewport: { width: 1080, height: 1080 }, deviceScaleFactor: 1 });
for (const c of CARDS) {
  const tmp = path.join(HERE, ".tmp-" + c.file.replace(".jpg", ".html"));
  fs.writeFileSync(tmp, html(c));
  await page.goto("file://" + tmp); await page.waitForLoadState("networkidle");
  const ok = await page.evaluate(() => [...document.images].every((i) => i.naturalWidth > 0));
  const over = await page.evaluate(() => [...document.querySelectorAll("h1, li .b, li .s")].filter((e) => e.scrollWidth > e.clientWidth + 1).map((e) => e.textContent));
  if (!ok) throw new Error("画像が読めない: " + c.file);
  await page.screenshot({ path: path.join(HERE, c.file), type: "jpeg", quality: 90 });
  fs.unlinkSync(tmp);
  console.log(c.file, over.length ? "はみ出し: " + over.join(" / ") : "ok");
}
await browser.close();
