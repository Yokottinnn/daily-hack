#!/bin/bash
# **大掃除のハウスクリーニング比較の記事のために、ナックダスキンの浴室・キッチン・エアコンの「料金プラン」を画面ごと撮る（料金が画像の中にあり本文から読めないため）（t494）。読むだけ・LLM 不使用・$0。**
# 2026-10-31 利用者がダイアログで「大掃除のハウスクリーニング比較」を選んだ。A8 の提携詳細から広告主のサイトを辿り、料金・メニューのページの「円」を含む行を出す。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t494-cleaning-prices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ハウスクリーニング 3 社の公式の料金（t494・**\$0**）"
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

# **拡張子は保つ**（`.new` 等を付けると Node が弾く・最上位ルール 14）
SCRIPT="$RDIR/.t494-prices.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const fs = await import('node:fs');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 });
const DIR = process.env.SHOT_DIR; fs.mkdirSync(DIR, { recursive: true });
for (const [key, u] of [['bath', 'https://nac-duskin.com/duskin-bathcleaning/'], ['kitchen', 'https://nac-duskin.com/duskin-kitchencleaning/'], ['aircon', 'https://nac-duskin.com/duskin-acclean/'], ['toilet', 'https://nac-duskin.com/duskin-toiletcleaning/']]) {
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
  await p.waitForTimeout(3500);
  // 「料金プラン」の見出しから 2,400px ぶんを撮る（画像の中の料金を目で読む）
  const y = await p.evaluate(() => { const h = [...document.querySelectorAll('h1,h2,h3,h4,p,div,span')].find((e) => /^料金プラン$/.test((e.innerText || '').trim())); return h ? h.getBoundingClientRect().top + window.scrollY - 40 : -1; });
  const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].filter((i) => /price|plan|ryokin|fee|menu/i.test(i.src + ' ' + i.alt)).map((i) => `${i.naturalWidth}x${i.naturalHeight} alt=${i.alt} ${i.src}`));
  console.log(`\n## ${key} ${u}\n- 料金プランの位置: ${y}`, ...imgs.slice(0, 12).map((x) => `\n- 画像 ${x}`));
  if (y < 0) continue;
  const H = await p.evaluate(() => document.documentElement.scrollHeight);
  for (let i = 0; i < 2; i++) {
    const top = Math.min(y + i * 1200, H - 1200);
    await p.screenshot({ path: `${DIR}/${key}-${i + 1}.png`, clip: { x: 0, y: top, width: 1280, height: 1200 }, fullPage: true }).catch((e) => console.log(`- ⚠️ 撮れない ${String(e).split('\n')[0]}`));
  }
  console.log(`- 撮った: ${key}-1.png・${key}-2.png`);
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t494-res.txt"
SHOT_DIR="$RDIR/t494-shots" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
cp "$OUT" "$RDIR/t494-cleaning-prices.md" 2>/dev/null
head -c 12000 "$OUT"
