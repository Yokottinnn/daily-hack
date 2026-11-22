#!/bin/bash
# **オーブンレンジ比較記事のアイリスを MO-F1808-B（公式で販売中・楽天・Amazon・Yahoo! で売っている）に替えるため、公式の写真・取扱説明書の設置の寸法と、Amazon の商品ページの題名・色を読む（t995）。** 読むだけ・買わない・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者がダイアログで「オーブンレンジのアイリスを売っている機種に替える」を選んだ。t990〜t994 で、公式の現行一覧にあって 3 店で売っているのは MO-F1808-B だけだった（MS-F2601-B は Amazon だけ、MO-F2404・MS-F3003-B は公式サイトに無い、MS-Y2403 は生産終了）。
# Cookie の無い新しいコンテキストで開く（ログインの情報を出さない）。店の画面の写真は撮らない。取扱説明書 PDF は手元で文字にし、設置の図の前後だけを出す（PDF は置かない）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t995-iris-mo-f1808.md"
PORT="${CDP_PORT:-18810}"
D="$RDIR/t995"; mkdir -p "$D/img"
TMPD="$HOME/.openclaw/workspace/tmp-t995"; mkdir -p "$TMPD"

{
  echo "# アイリス MO-F1808-B の公式の写真・取扱説明書と Amazon（t995・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **\`playwright-core\` が無い。ここで止める。**" >> "$OUT"; cat "$OUT"; exit 0
fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。ここで止める。**" >> "$OUT"; cat "$OUT"; exit 0
fi

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

SCRIPT="$RDIR/.t995.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D, TMPD = process.env.TMPD;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 }).catch(() => {});
const t0 = Date.now();
const left = () => 210000 - (Date.now() - t0);
// 1) 公式の 18L のページ: MO-F1808-B の節の写真と取扱説明書
try {
  const url = 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/microwave-microwave-oven/steam-oven/steam-oven-18l';
  const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await p.waitForTimeout(3000);
  await p.evaluate(() => { for (const e of document.querySelectorAll('a,button,span,div')) if ((e.innerText || '').trim() === 'もっと読む' && e.children.length === 0) e.click(); });
  await p.waitForTimeout(1500);
  await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 700) { window.scrollTo(0, y); await new Promise((s) => setTimeout(s, 150)); } });
  const text = await p.evaluate(() => (document.querySelector('main') || document.body).innerText);
  fs.writeFileSync(`${D}/official-18l.txt`, `URL: ${p.url()}\nSTATUS: ${r ? r.status() : '?'}\n\n${text.slice(0, 60000)}`);
  console.log(`## 公式 18L（HTTP ${r ? r.status() : '?'}・本文 ${text.length} 字）`);
  const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((im) => ({ src: im.currentSrc || im.src, w: im.naturalWidth, h: im.naturalHeight, alt: (im.alt || '').slice(0, 60) })).filter((im) => im.src && /web-catalog/.test(im.src)));
  let k = 0;
  for (const im of [...new Map(imgs.map((x) => [x.src, x])).values()].slice(0, 10)) {
    try {
      const res = await ctx.request.get(im.src, { timeout: 15000 });
      const buf = await res.body();
      const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
      const name = `official-${String(++k).padStart(2, '0')}.${ext}`;
      fs.writeFileSync(`${D}/img/${name}`, buf);
      console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
    } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
  }
  // MO-F1808-B の JAN 4967576495301 の近くの PDF（ページの PDF を全部挙げ、順番で対応づける）
  const pdfs = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => /\.pdf(\?|$)/i.test(h)));
  console.log(`- PDF ${pdfs.length} 件: ${pdfs.join(' ')}`);
  // 495301 を含む画像の ID から、MO-F1808-B の取扱説明書を探す（無ければ 2 本目＝ページの順）
  for (const [j, pdf] of pdfs.slice(0, 3).entries()) {
    if (left() < 120000) break;
    const res = await ctx.request.get(pdf, { timeout: 60000 });
    const buf = await res.body();
    fs.writeFileSync(`${TMPD}/m${j}.pdf`, buf);
    console.log(`  - PDF m${j} ${buf.length}B（HTTP ${res.status()}）${pdf} → 手元だけ`);
  }
} catch (e) { console.log(`- ⚠️ 公式: ${String(e).slice(0, 140)}`); }
// 2) Amazon の商品ページ（題名・色）
for (const asin of ['B09572Y1QQ', 'B09PRHJQC1']) {
  if (left() < 30000) break;
  try {
    await p.goto(`https://www.amazon.co.jp/dp/${asin}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3000);
    const v = await p.evaluate(() => {
      const title = ((document.querySelector('#productTitle') || {}).innerText || '').trim();
      const colors = [...document.querySelectorAll('#variation_color_name li, #inline-twister-row-color_name li, [id^="color_name_"]')].map((li) => (li.getAttribute('title') || li.innerText || '').replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 8);
      const model = [...document.querySelectorAll('#productDetails_techSpec_section_1 tr, #productOverview_feature_div tr, #detailBullets_feature_div li')].map((x) => x.innerText.replace(/\s+/g, ' ').trim()).filter((t) => /型番|モデル|メーカー/.test(t)).slice(0, 6);
      return { title: title.slice(0, 150), colors, model, cart: /カートに入れる|今すぐ買う/.test(document.body.innerText) };
    });
    console.log(`\n## Amazon ${asin}\n- 題名: ${v.title}\n- 色: ${v.colors.join(' / ') || '—'}\n- 型番の行: ${v.model.join(' ／ ') || '—'}\n- カート: ${v.cart ? 'あり' : '無い'}`);
  } catch (e) { console.log(`- ⚠️ Amazon ${asin}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t995-res.txt"
D="$D" TMPD="$TMPD" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
for F in "$TMPD"/*.pdf; do
  [ -s "$F" ] || continue
  k="$(basename "$F" .pdf)"
  osascript -l JavaScript -e 'ObjC.import("PDFKit"); function run(argv){ var d=$.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(argv[0])); if(!d) return ""; return d.string.js; }' "$F" > "$TMPD/$k.txt" 2>/dev/null
  n="$(grep -n -m1 '安全に設置する' "$TMPD/$k.txt" | cut -d: -f1)"
  echo "" >> "$OUT"; echo "## $k 取扱説明書（文字 $(wc -c < "$TMPD/$k.txt" | tr -d ' ') バイト・型番の語: $(grep -o -E 'MO-F18[0-9]{2}[A-Z-]*|KMO-F18[0-9]{2}[A-Z-]*' "$TMPD/$k.txt" | sort -u | head -5 | tr '\n' ' ')・「安全に設置する」${n:-なし} 行目）" >> "$OUT"
  [ -n "$n" ] && sed -n "${n},$((n+50))p" "$TMPD/$k.txt" | awk -v s="$n" '{print s+NR-1": "$0}' | grep -E "上|左|右|後|cm|開放" | head -25 | sed 's/^/    /' >> "$OUT"
done
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
