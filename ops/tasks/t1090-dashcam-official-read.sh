#!/bin/bash
# **ドライブレコーダーの比較記事の材料: コムテック・ケンウッド・セルスターの公式の製品ページ・写真と、6 社のロゴを読む（t1090）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして」。blog3 の dashcam-comparison-2026（ZDR065・ZDR-851R・DRV-X80EM・CS-N210）。
# comtec.co.jp・cellstar.co.jp はクラウドから届かず、kenwood.com は 403 なので、Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開く（ログインの情報を持ち込まない）。
# 製品ページの URL は推測で組み立てず、入口のページのリンクから型番で探す。本文は reports/t1090/<key>.txt、写真の候補は reports/t1090/img/。240 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1090-dashcam-official.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ドライブレコーダー コムテック・ケンウッド・セルスターの公式ページ（t1090・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

# ── playwright-core を探す（**棚卸しに書いてある場所から**） ──
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  {
    echo "⚠️ **\`playwright-core\` がどちらにも無い。**"
    echo ""
    echo '```text'
    ls -d "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules" 2>&1
    echo '```'
    echo ""
    echo "**ここで止める。** 推測で埋めない（最上位ルール 20）。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: **\`$PWDIR\`** に在る" >> "$OUT"

# ── Chrome が CDP で上がっているか（**ポートの LISTEN では足りない**・ルール 13） ──
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  {
    echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** 新しく起動はしない（t174 と同じ）"
    echo ""
    echo "**ここで止める。** Chrome が戻ってから同じものを出し直す。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"
echo "" >> "$OUT"

# ── 描画して読む ──────────────────────────────────────────
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
D="$RDIR/t1090"; rm -rf "$D"; mkdir -p "$D/img"
SCRIPT="$RDIR/.t1090.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし（ログインの情報を持ち込まない）
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 232000 - (Date.now() - t0);
const seen = new Set();
async function open(url) {
  await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(3000);
  return p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || a.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 60) })));
}
async function read(key, url, opt = {}) {
  if (left() < 15000) { console.log(`- ⏱ ${key} は時間切れ`); return []; }
  if (seen.has(url)) return []; seen.add(url);
  try {
    const links = await open(url);
    for (let i = 1; i <= 6; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 6), i); await p.waitForTimeout(400); }
    const ti = await p.title();
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${txt.slice(0, 90000)}`);
    const imgs = await p.evaluate(() => {
      const out = [];
      for (const im of document.querySelectorAll('img')) { const s = im.currentSrc || im.src; if (s && im.naturalWidth >= 500) out.push({ s, w: im.naturalWidth, h: im.naturalHeight, alt: (im.alt || '').slice(0, 60) }); }
      const og = document.querySelector('meta[property="og:image"]'); if (og) out.unshift({ s: og.content, w: 0, h: 0, alt: 'og:image' });
      return out;
    });
    console.log(`\n### ${key}\n- 「${ti.slice(0, 80)}」 ${p.url()}\n- 本文 ${txt.length} 文字 / 画像（幅500以上）${imgs.length} 枚`);
    let n = 0; const got = new Set();
    for (const im of imgs) {
      if (n >= (opt.imgs ?? 6) || left() < 12000) break;
      if (got.has(im.s) || /logo|icon|sprite|badge|banner|bnr/i.test(im.s)) continue; got.add(im.s);
      try {
        const r = await ctx.request.get(im.s, { headers: { Referer: url }, timeout: 15000 });
        if (!r.ok()) { console.log(`  - img ✗ ${r.status()} ${im.s.slice(0, 120)}`); continue; }
        const buf = await r.body(); const ct = r.headers()['content-type'] || '';
        const ext = /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : /avif/.test(ct) ? 'avif' : 'jpg';
        n++; const f = `${key}-${n}.${ext}`; fs.writeFileSync(`${D}/img/${f}`, buf);
        console.log(`  - img ${f} ${im.w}x${im.h} ${buf.length}B 「${im.alt}」 ${im.s.slice(0, 140)}`);
      } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
    }
    return links;
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); return []; }
}
// 型番の製品ページを、入口のページのリンクから探す（URL を推測で組み立てない）。見つからなければ「ドライブレコーダー」の一覧を 1 段たどってもう一度探す
async function find(maker, starts, model, onlyHost) {
  const re = new RegExp(model.replace(/-/g, '[-_]?'), 'i');
  const pool = [];
  for (const s of starts) {
    if (left() < 30000) break;
    try { const l = await open(s); pool.push(...l); console.log(`- ${maker} 入口 ${s} → リンク ${l.length} 件（${(await p.title()).slice(0, 50)}）`); } catch (e) { console.log(`- ${maker} 入口 ${s} ⚠️ ${String(e).slice(0, 90)}`); }
    const hit = pool.find((l) => re.test(l.h) && l.h.includes(onlyHost));
    if (hit) return hit.h;
  }
  const lists = [...new Map(pool.filter((l) => l.h.includes(onlyHost) && (/drive.?recorder|d-recorder|dashcam|drv/i.test(l.h) || /ドライブレコーダー/.test(l.t))).map((l) => [l.h, l])).values()].slice(0, 4);
  for (const l of lists) {
    if (left() < 30000) break;
    try { const ll = await open(l.h); console.log(`- ${maker} 一覧 ${l.h} → ${ll.length} 件`); const hit = ll.find((x) => re.test(x.h) && x.h.includes(onlyHost)); if (hit) return hit.h; } catch (e) { console.log(`- ${maker} 一覧 ⚠️ ${String(e).slice(0, 90)}`); }
  }
  const near = pool.filter((l) => re.test(l.t)).slice(0, 5);
  console.log(`- ⚠️ ${maker} ${model} の製品ページが見つからない（文字で当たったリンク: ${near.map((x) => x.h).join(' ') || 'なし'}）`);
  return near[0]?.h || '';
}
const targets = [
  ['comtec-zdr065', 'コムテック', ['https://www.comtec.co.jp/', 'https://www.comtec.co.jp/products/'], 'ZDR065', 'comtec.co.jp'],
  ['comtec-zdr851r', 'コムテック', ['https://www.comtec.co.jp/products/', 'https://www.comtec.co.jp/'], 'ZDR-851R', 'comtec.co.jp'],
  ['kenwood-drvx80em', 'ケンウッド', ['https://www.kenwood.com/jp/car/drive-recorders/', 'https://www.kenwood.com/jp/car/'], 'DRV-X80EM', 'kenwood.com'],
  ['cellstar-csn210', 'セルスター', ['https://www.cellstar.co.jp/', 'https://www.cellstar.co.jp/products/'], 'CS-N210', 'cellstar.co.jp'],
];
for (const [key, maker, starts, model, host] of targets) {
  if (left() < 30000) { console.log(`- ⏱ ${key} は時間切れ`); break; }
  const u = await find(maker, starts, model, host);
  if (!u) continue;
  const links = await read(key, u, { imgs: 6 });
  // 「仕様」「スペック」のページが別にあれば読む
  const spec = links.find((l) => l.h.includes(host) && l.h !== u && (/spec|siyou|shiyou/i.test(l.h) || /^(仕様|製品仕様|スペック|主な仕様)/.test(l.t)));
  if (spec) await read(key + '-spec', spec.h, { imgs: 0 });
}
// ロゴ: 6 社のトップのヘッダーの logo（img・svg）
for (const [k, u] of [['comtec', 'https://www.comtec.co.jp/'], ['kenwood', 'https://www.kenwood.com/jp/'], ['cellstar', 'https://www.cellstar.co.jp/'], ['yupiteru', 'https://www.yupiteru.co.jp/'], ['pioneer', 'https://jpn.pioneer/ja/carrozzeria/'], ['alpine', 'https://www.alpine.co.jp/']]) {
  if (left() < 10000) break;
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }); await p.waitForTimeout(2500);
    const cands = await p.evaluate(() => {
      const out = [];
      for (const im of document.querySelectorAll('header img, img[src*="logo" i], img[alt*="logo" i], img[class*="logo" i], a[class*="logo" i] img, h1 img')) out.push({ s: im.currentSrc || im.src, alt: im.alt || '', w: im.naturalWidth, h: im.naturalHeight });
      const svg = document.querySelector('header svg, a[class*="logo" i] svg, [class*="logo" i] svg, h1 svg');
      return { imgs: out.slice(0, 6), svg: svg ? svg.outerHTML.slice(0, 60000) : '' };
    });
    console.log(`\n- ロゴ ${k}: img ${cands.imgs.length} / svg ${cands.svg.length} 文字`);
    let n = 0;
    for (const c of cands.imgs) {
      if (!c.s || n >= 3) continue;
      try { const r = await ctx.request.get(c.s, { headers: { Referer: u }, timeout: 15000 }); const buf = await r.body(); const ct = r.headers()['content-type'] || ''; const ext = /svg/.test(ct) || /\.svg/.test(c.s) ? 'svg' : /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : /gif/.test(ct) ? 'gif' : 'jpg'; n++; fs.writeFileSync(`${D}/img/logo-${k}-${n}.${ext}`, buf); console.log(`  - logo-${k}-${n}.${ext} ${c.w}x${c.h} 「${c.alt}」 ${c.s.slice(0, 140)}`); } catch (e) { console.log(`  - ⚠️ ${String(e).slice(0, 80)}`); }
    }
    if (cands.svg) { fs.writeFileSync(`${D}/img/logo-${k}-inline.svg`, cands.svg); console.log(`  - logo-${k}-inline.svg`); }
  } catch (e) { console.log(`- ロゴ ${k} ⚠️ ${String(e).slice(0, 100)}`); }
}
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
JS
RES="$RDIR/.t1090-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 245 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; ls -la "$D" "$D/img" | awk '{print $5, $9}' >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
