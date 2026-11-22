#!/bin/bash
# **オーブンレンジ比較記事のアイリスを替えるため、公式の製品ページ（特長の全文・写真）と取扱説明書 PDF の設置の寸法（上にあける隙間）を読む（t991）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者がダイアログで「オーブンレンジのアイリスを売っている機種に替える」を選んだ。候補 MS-F2601-B（26L タンク式）と MS-2402（24L タンク式過熱水蒸気）。
# クラウドからはアイリスオーヤマの公式サイトが 403 で読めないので、Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開く（ログインの情報を出さない）。
# 「もっと読む」を押して特長の全文を reports/t991/<key>.txt、製品の写真を reports/t991/img/、PDF は macOS の PDFKit（osascript）で文字にして設置の行だけを reports/t991/<key>-manual.txt に出す（PDF そのものは置かない）。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t991-iris-oven-official.md"
PORT="${CDP_PORT:-18810}"
D="$RDIR/t991"; mkdir -p "$D/img"
TMPD="$HOME/.openclaw/workspace/tmp-t991"; mkdir -p "$TMPD"

{
  echo "# アイリスのオーブンレンジ 公式ページと取扱説明書（t991・**\$0**）"
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
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"

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

SCRIPT="$RDIR/.t991.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D, TMPD = process.env.TMPD;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 200000 - (Date.now() - t0);
const BASE = 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/microwave-microwave-oven/steam-oven/';
const PAGES = [['ms-f2601', BASE + 'steam-oven-range-tank-type-26l'], ['ms-2402', BASE + 'steam-oven-range-tank-type-24l']];
for (const [key, url] of PAGES) {
  if (left() < 40000) { console.log('- ⏱ 時間切れ'); break; }
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3000);
    // 「もっと読む」を全部押す
    const n = await p.evaluate(() => { let c = 0; for (const e of document.querySelectorAll('a,button,span,div')) { if ((e.innerText || '').trim() === 'もっと読む' && e.children.length === 0) { e.click(); c++; } } return c; });
    await p.waitForTimeout(1500);
    await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 900) { window.scrollTo(0, y); await new Promise((s) => setTimeout(s, 120)); } });
    const text = await p.evaluate(() => (document.querySelector('main') || document.body).innerText);
    fs.writeFileSync(`${D}/${key}.txt`, `URL: ${p.url()}\nSTATUS: ${r ? r.status() : '?'}\nもっと読む: ${n}\n\n${text.slice(0, 60000)}`);
    console.log(`\n## ${key}（HTTP ${r ? r.status() : '?'}・本文 ${text.length} 字・もっと読む ${n} 回）\n- URL: ${p.url()}`);
    const imgs = await p.evaluate(() => {
      const og = (document.querySelector('meta[property="og:image"]') || {}).content;
      const list = [...document.querySelectorAll('img')].map((i) => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || '').slice(0, 60) }))
        .filter((i) => i.src && i.w >= 400 && !/\/news\//.test(i.src) && !/logo|banner|icon/i.test(i.src));
      if (og) list.unshift({ src: og, w: 0, h: 0, alt: 'og:image' });
      return list;
    });
    let k = 0;
    for (const im of [...new Map(imgs.map((i) => [i.src, i])).values()].slice(0, 8)) {
      try {
        const res = await ctx.request.get(im.src, { timeout: 15000 });
        const buf = await res.body();
        const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
        const name = `${key}-${String(++k).padStart(2, '0')}.${ext}`;
        fs.writeFileSync(`${D}/img/${name}`, buf);
        console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
      } catch (e) { console.log(`  - img ⚠️ ${im.src} ${String(e).slice(0, 80)}`); }
    }
    const pdfs = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => /\.pdf(\?|$)/i.test(h)));
    console.log(`- PDF のリンク ${pdfs.length} 件: ${pdfs.slice(0, 3).join(' ')}`);
    if (pdfs[0] && left() > 30000) {
      const res = await ctx.request.get(pdfs[0], { timeout: 60000 });
      const buf = await res.body();
      fs.writeFileSync(`${TMPD}/${key}.pdf`, buf);
      console.log(`- PDF ${buf.length}B（HTTP ${res.status()}）→ 手元に保存（公開しない）`);
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 160)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t991-res.txt"
D="$D" TMPD="$TMPD" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 215 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"

# PDF を文字にして、設置の寸法の行だけを出す（macOS の PDFKit。PDF は公開しない）
for key in ms-f2601 ms-2402; do
  F="$TMPD/$key.pdf"
  [ -s "$F" ] || { echo "- $key: PDF なし" >> "$OUT"; continue; }
  osascript -l JavaScript -e 'ObjC.import("PDFKit"); function run(argv){ var d=$.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(argv[0])); if(!d) return ""; return d.string.js; }' "$F" > "$TMPD/$key.txt" 2>/dev/null
  echo "- $key: PDF の文字 $(wc -c < "$TMPD/$key.txt" | tr -d ' ') バイト" >> "$OUT"
  grep -n -E "上方|上面|すき間|隙間|cm以上|設置" "$TMPD/$key.txt" | head -60 > "$D/$key-manual.txt"
  echo "  - 設置の行 $(wc -l < "$D/$key-manual.txt" | tr -d ' ') 行（reports/t991/$key-manual.txt）" >> "$OUT"
  head -30 "$D/$key-manual.txt" | sed 's/^/    /' >> "$OUT"
done
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
