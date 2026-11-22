#!/bin/bash
# **オーブンレンジ比較記事のアイリスを「3 店で売っている機種」に替えるため、MO-F2404・MS-F3003-B が公式サイトに載っているか（仕様・写真・取扱説明書）と、Yahoo! ショッピングで型番の商品があるかを読む（t994）。** 読むだけ・買わない・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者がダイアログで「オーブンレンジのアイリスを売っている機種に替える」を選んだ。t992 で楽天・Yahoo! に多く出たのが MO-F2404・MS-F3003-B。公式の一覧（t910）に無かったので、公式の検索と「スチーム流水解凍オーブンレンジ 24L」のページを読む。
# Cookie の無い新しいコンテキストで開く（ログインの情報を出さない）。店の画面の写真は撮らない。取扱説明書 PDF は手元で文字にし、設置の図の前後だけを出す（PDF は置かない）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t994-iris-oven-official-2.md"
PORT="${CDP_PORT:-18810}"
D="$RDIR/t994"; mkdir -p "$D/img"
TMPD="$HOME/.openclaw/workspace/tmp-t994"; mkdir -p "$TMPD"

{
  echo "# アイリスのスチームオーブンレンジ 公式と Yahoo! 2（t994・**\$0**）"
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

SCRIPT="$RDIR/.t994.mjs"
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
const BASE = 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/microwave-microwave-oven/';
const found = new Map([[BASE + 'steam-oven/steam-running-water-thawing-microwave-oven', '流水解凍 24L']]);
// 1) 公式の検索で製品ページを拾う
for (const q of ['MO-F2404', 'MS-F3003']) {
  if (left() < 120000) break;
  try {
    await p.goto(`https://www.irisohyama.co.jp/search/?q=${encodeURIComponent(q)}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80) })).filter((l) => /microwave/.test(l.h)));
    console.log(`\n## 公式の検索「${q}」 microwave のリンク ${links.length}`);
    for (const l of links.slice(0, 10)) { console.log(`- ${l.t}｜${l.h}`); if (!/manual|support|\.pdf/.test(l.h)) found.set(l.h, l.t); }
  } catch (e) { console.log(`- ⚠️ 検索 ${q}: ${String(e).slice(0, 140)}`); }
}
// 2) 製品ページを読む（最大 4）
let i = 0;
for (const [url] of [...found].slice(0, 4)) {
  if (left() < 70000) { console.log('- ⏱ 時間切れ'); break; }
  const key = `p${++i}`;
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3000);
    await p.evaluate(() => { for (const e of document.querySelectorAll('a,button,span,div')) if ((e.innerText || '').trim() === 'もっと読む' && e.children.length === 0) e.click(); });
    await p.waitForTimeout(1200);
    const text = await p.evaluate(() => (document.querySelector('main') || document.body).innerText);
    fs.writeFileSync(`${D}/${key}.txt`, `URL: ${p.url()}\nSTATUS: ${r ? r.status() : '?'}\n\n${text.slice(0, 60000)}`);
    const models = [...new Set((text.match(/[A-Z]{2,4}-[A-Z0-9]{4,8}(-[A-Z])?/g) || []))].slice(0, 10);
    console.log(`\n## ${key}（HTTP ${r ? r.status() : '?'}・本文 ${text.length} 字）${p.url()}\n- 型番: ${models.join(' / ')}`);
    const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((im) => ({ src: im.currentSrc || im.src, w: im.naturalWidth, h: im.naturalHeight, alt: (im.alt || '').slice(0, 60) })).filter((im) => im.src && /web-catalog|\/products\//.test(im.src) && !/logo|icon|banner/i.test(im.src)));
    let k = 0;
    for (const im of [...new Map(imgs.map((x) => [x.src, x])).values()].slice(0, 8)) {
      try {
        const res = await ctx.request.get(im.src, { timeout: 15000 });
        const buf = await res.body();
        const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
        const name = `${key}-${String(++k).padStart(2, '0')}.${ext}`;
        fs.writeFileSync(`${D}/img/${name}`, buf);
        console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
      } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
    }
    const pdfs = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => /\.pdf(\?|$)/i.test(h)));
    console.log(`- PDF ${pdfs.length} 件: ${pdfs.slice(0, 4).join(' ')}`);
    for (const [j, pdf] of pdfs.slice(0, 2).entries()) {
      if (left() < 50000) break;
      const res = await ctx.request.get(pdf, { timeout: 60000 });
      const buf = await res.body();
      fs.writeFileSync(`${TMPD}/${key}-${j}.pdf`, buf);
      console.log(`  - PDF ${key}-${j} ${buf.length}B（HTTP ${res.status()}）→ 手元だけ`);
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
// 3) Yahoo! で型番
for (const q of ['MO-F2404', 'MS-F3003-B', 'MO-F1808-B']) {
  if (left() < 15000) break;
  try {
    await p.goto(`https://shopping.yahoo.co.jp/search?p=${encodeURIComponent(q)}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3000);
    const items = await p.evaluate(() => {
      const seen = new Map();
      for (const a of document.querySelectorAll('a[href]')) {
        const m = a.href.match(/^https:\/\/store\.shopping\.yahoo\.co\.jp\/[^/]+\/[^/?#]+\.html/); if (!m) continue;
        const t = (a.getAttribute('title') || a.innerText || '').replace(/\s+/g, ' ').trim();
        if (t.length < 8) continue;
        if (!seen.has(m[0]) || seen.get(m[0]).length < t.length) seen.set(m[0], t.slice(0, 140));
      }
      return [...seen].map(([u, t]) => ({ u, t }));
    });
    const key = q.replace(/-B$/, '').replace(/-/g, '');
    const hits = items.filter((x) => x.t.normalize('NFKC').replace(/[-\s]/g, '').toUpperCase().includes(key) && !/専用|部品|トレー|角皿|中古/.test(x.t));
    console.log(`\n## Yahoo!「${q}」商品 ${items.length} 件・型番あり ${hits.length} 件`);
    for (const h of hits.slice(0, 6)) console.log(`- ${h.t.slice(0, 100)}｜${h.u}`);
  } catch (e) { console.log(`- ⚠️ Yahoo ${q}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t994-res.txt"
D="$D" TMPD="$TMPD" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
# 取扱説明書の設置の図の前後（「安全に設置する」から 50 行）
for F in "$TMPD"/*.pdf; do
  [ -s "$F" ] || continue
  k="$(basename "$F" .pdf)"
  osascript -l JavaScript -e 'ObjC.import("PDFKit"); function run(argv){ var d=$.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(argv[0])); if(!d) return ""; return d.string.js; }' "$F" > "$TMPD/$k.txt" 2>/dev/null
  n="$(grep -n -m1 '安全に設置する' "$TMPD/$k.txt" | cut -d: -f1)"
  echo "" >> "$OUT"; echo "## $k 取扱説明書（文字 $(wc -c < "$TMPD/$k.txt" | tr -d ' ') バイト・「安全に設置する」${n:-なし} 行目）" >> "$OUT"
  [ -n "$n" ] && sed -n "${n},$((n+50))p" "$TMPD/$k.txt" | grep -E "上|左|右|後|cm|開放|設置" | head -25 | sed 's/^/    /' >> "$OUT"
done
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
