#!/bin/bash
# **布団乾燥機の比較記事のために、アイリスオーヤマ（カラリエ）の公式ページ・発表資料・製品写真を読む（t830）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして。記事の質は絶対に下げないで」。blog3 が書く futon-dryer-comparison-2026 の材料。
# クラウドからはアイリスオーヤマの公式サイトが 403 で読めないので、Mac の Chrome（CDP）で開く。Cookie の無い新しいコンテキストで開く（ログインの情報をレポートに入れない・t688 の反省）。
# 本文は reports/t830/*.txt、写真は reports/t830/img/（横 500px 以上だけ・1 ページ 12 枚まで）、発表 PDF は reports/t830/*.pdf に置く。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t830-futon-dryer-iris.md"
PORT="${CDP_PORT:-18810}"
D="$RDIR/t830"; mkdir -p "$D/img"

{
  echo "# 布団乾燥機 アイリスオーヤマの公式ページ（t830・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

# 発表資料の PDF は curl で取る（描画は要らない）
for pair in "news-2026-0924|https://www.irisohyama.co.jp/news/2026/0924.pdf"; do
  k="${pair%%|*}"; u="${pair#*|}"
  code="$(curl -sS -L -m 40 -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36' -o "$D/$k.pdf" -w '%{http_code}' "$u" 2>/dev/null)"
  echo "- PDF $k: HTTP $code / $(wc -c < "$D/$k.pdf" 2>/dev/null | tr -d ' ') bytes" >> "$OUT"
done

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

SCRIPT="$RDIR/.t830.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 220000 - (Date.now() - t0);
const PAGES = [
  ['kararie-futon', 'https://www.irisohyama.co.jp/kararie/futon/'],
  ['fk-w3', 'https://www.irisohyama.co.jp/kararie/futon/fk-w3-product/'],
  ['fk-c5', 'https://www.irisohyama.co.jp/kararie/futon/fk-c5-product/'],
  ['support-fk-c5', 'https://www.irisohyama.co.jp/products/support/4967576773508'],
];
for (const [key, url] of PAGES) {
  if (left() < 20000) { console.log(`- ⏱ ${key} は時間切れ`); break; }
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3500);
    await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 900) { window.scrollTo(0, y); await new Promise((s) => setTimeout(s, 120)); } });
    await p.waitForTimeout(1200);
    const title = await p.title();
    const text = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${title}\nURL: ${p.url()}\nSTATUS: ${r ? r.status() : '?'}\n\n${text.slice(0, 90000)}`);
    const links = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => /kararie\/futon|fk-|\.pdf/i.test(h)))].slice(0, 40));
    const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((i) => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || '').slice(0, 60) })).filter((i) => i.src && i.w >= 500));
    console.log(`\n### ${key}（HTTP ${r ? r.status() : '?'}・「${title.slice(0, 60)}」・本文 ${text.length} 字・写真候補 ${imgs.length}）\n- URL: ${p.url()}`);
    for (const l of links) console.log(`  - link ${l}`);
    let n = 0;
    for (const im of [...new Map(imgs.map((i) => [i.src, i])).values()].slice(0, 12)) {
      try {
        const res = await ctx.request.get(im.src, { timeout: 15000 });
        const buf = await res.body();
        const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
        const name = `${key}-${String(++n).padStart(2, '0')}.${ext}`;
        fs.writeFileSync(`${D}/img/${name}`, buf);
        console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
      } catch (e) { console.log(`  - img ⚠️ ${im.src} ${String(e).slice(0, 80)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t830-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
