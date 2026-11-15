#!/bin/bash
# **マツキヨココカラのロゴを Mac の Chrome で撮る（x506）。** 読むだけ・LLM 不使用・$0／回。
# 2026-11-15 利用者のコメント「表紙…9つぐらいタイル型で…告知画像をまとめて」「アイコンが取得できていないものは公式サイトやそのほかサイト等から必ず取得してきて」。x505 で画像の URL を直接取ると Access Denied だったので、ページに出ているロゴの要素だけを撮る（ページ全体は撮らない）。
# ログイン不要の公開ページだけ。本文は保存しない。画像は reports/x506/ に置く。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/x506-bf-kv-logos-chrome.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ブラックフライデーの告知画像とロゴ（x506・**\$0**）"
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

D="$RDIR/x506"; mkdir -p "$D"
SCRIPT="$RDIR/.x506.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const pages = [
  ["matsukiyo", "https://www.matsukiyococokara.com/"],
  ["matsukiyoonline", "https://www.matsukiyococokara-online.com/store/"],
];
for (const [k,u] of pages) {
  let p;
  try {
    p = await ctx.newPage(); await p.setViewportSize({ width: 1280, height: 900 });
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4000);
    await p.mouse.wheel(0, 1200); await p.waitForTimeout(1500); await p.mouse.wheel(0, -1200); await p.waitForTimeout(800);
    const els = await p.$$('img[src*="logo"], header img, [class*=logo] img');
    console.log(`- ${k}: ロゴの候補 ${els.length} 個 ← ${p.url().slice(0, 90)}`);
    let n = 0;
    for (const el of els.slice(0, 4)) {
      const info = await el.evaluate(i => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, vis: i.getBoundingClientRect().width }));
      if (!info.vis) continue;
      n++; const f = `logo-${k}-${n}.png`;
      await el.screenshot({ path: `${D}/${f}`, omitBackground: true }).catch(e => console.log('    ⚠️ ' + String(e).slice(0, 80)));
      console.log(`    ${f}  ${info.w}x${info.h} ← ${info.src.slice(0, 150)}`);
    }
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0,100)}`); }
  await p?.close().catch(() => {});
}
process.exit(0);
JS
RES="$RDIR/.x506-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 3000 "$OUT"
