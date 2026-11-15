#!/bin/bash
# **三越伊勢丹とマツキヨココカラのロゴを Mac の Chrome で取る（x505）。** 読むだけ・LLM 不使用・$0／回。
# 2026-11-15 利用者のコメント「表紙…9つぐらいタイル型で…告知画像をまとめて」「アイコンが取得できていないものは公式サイトやそのほかサイト等から必ず取得してきて」。x504 で Chrome が途中で閉じられて取れなかった三越伊勢丹・マツキヨココカラのロゴ。ページごとに新しいタブで開く。
# ログイン不要の公開ページだけ。本文は保存しない。画像は reports/x505/ に置く。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/x505-bf-kv-logos-chrome.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ブラックフライデーの告知画像とロゴ（x505・**\$0**）"
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

D="$RDIR/x505"; mkdir -p "$D"
SCRIPT="$RDIR/.x505.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const pages = [
  ["isetan", "https://www.mistore.jp/shopping"],
  ["isetan2", "https://www.isetan.mistore.jp/"],
  ["matsukiyo", "https://www.matsukiyococokara-online.com/store/"],
  ["matsukiyo2", "https://www.matsukiyococokara.com/"],
];
for (const [k,u] of pages) {
  let p;
  try {
    p = await ctx.newPage(); await p.setViewportSize({ width: 1280, height: 900 });
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4000);
    await p.mouse.wheel(0, 1200); await p.waitForTimeout(1500); await p.mouse.wheel(0, -1200); await p.waitForTimeout(800);
    const imgs = await p.evaluate(() => {
      const og = [...document.querySelectorAll('meta[property="og:image"],meta[name="twitter:image"]')].map(m => ({ src: m.content, w: 0, h: 0, why: 'og' }));
      const im = [...document.querySelectorAll('img')].map(i => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, why: (/logo/i.test(i.src + ' ' + i.alt + ' ' + i.className + ' ' + (i.closest('[class*=logo]') ? 'logo' : '')) ? 'logo' : 'img') }));
      return og.concat(im).filter(x => x.src && !x.src.startsWith('data:'));
    });
    const big = [];
    const logos = imgs.filter(x => x.why === 'logo').slice(0, 6);
    const ogs = imgs.filter(x => x.why === 'og').slice(0, 1);
    console.log(`- ${k}: 画像 ${imgs.length} 個（大きいもの ${big.length}・ロゴ ${logos.length}・og ${ogs.length}）← ${p.url().slice(0, 90)}`);
    let n = 0;
    for (const x of [...ogs, ...big, ...logos]) {
      n++;
      try {
        const r = await ctx.request.get(x.src, { headers: { referer: u }, timeout: 20000 });
        const ct = r.headers()['content-type'] || '';
        const ext = /svg/.test(ct) ? 'svg' : /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : /gif/.test(ct) ? 'gif' : 'jpg';
        const buf = await r.body(); const f = `${x.why}-${k}-${n}.${ext}`;
        fs.writeFileSync(`${D}/${f}`, buf);
        console.log(`    ${f}  ${buf.length} bytes  ${x.w}x${x.h} ← ${x.src.slice(0, 150)}`);
      } catch (e) { console.log(`    ⚠️ ${x.src.slice(0, 100)}: ${String(e).slice(0, 80)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0,100)}`); }
  await p?.close().catch(() => {});
}
process.exit(0);
JS
RES="$RDIR/.x505-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 3000 "$OUT"
