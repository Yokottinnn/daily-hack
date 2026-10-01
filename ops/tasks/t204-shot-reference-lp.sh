#!/bin/bash
# **参照 LP の画面を撮る（t204）。読むだけ・LLM 不使用・$0。**
#
# ## t203 で撮れなかった理由
#
# t203 は HTML（79,695 bytes）と CSS（20,777 bytes）は取れたが、**画面は撮れなかった。**
# 「`playwright-core` が無い」と判定して飛ばしている。
#
# **入っていないのではなく、探す場所が違った。** `docs/mac-environment.md` に書いてある:
#
# > **ブログのリポジトリに `playwright-core` は無い。** X のループが持っている。
# > `~/.openclaw/workspace/node_modules` と `~/openclaw/node_modules`
#
# t203 はブログのリポジトリに `cd` してから探していた。**棚卸しを読まずに書いた**
# （最上位ルール 14「推測で書く前にここを読む」）。
#
# ## やること
#
# **`createRequire` でその場所から読む**（`NODE_PATH` は ESM の import では効かない）。
# **既に動いている Chrome に CDP で繋ぐ。新しく起動しない**（t174 と同じ作り）。
#
#   ・PC  1200px **ページ全体**（`reports/lp-ref/pc.jpg`）
#   ・スマホ 390px **ページ全体**（`reports/lp-ref/sp.jpg`）
#
# **JPEG にする。** LP は縦に長く、全体の PNG は数 MB になる。
# `reports/` は公開ブランチに push されるので、重くしない。
#
# 判断はしない。撮るだけ。**$0/回・$0/日・$0/月。**

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t204-shot-reference-lp.md"
DIR="$RDIR/lp-ref"
PORT="${CDP_PORT:-18810}"
URL='https://app-mania.online/point/rank.php?ID=GSN_AppM_point_main_cpa_001a_res_04_ranking001_A000I'
mkdir -p "$DIR"

{
  echo "# 参照 LP の画面を撮る（t204・**\$0**）"
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

# ── 撮る ──────────────────────────────────────────────────
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
SCRIPT="$RDIR/.t204-shot.mjs"
cat > "$SCRIPT" <<'JS'
// **`NODE_PATH` は ESM の import では効かない。** createRequire で場所を指定する
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');

const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
for (const [w, h, name] of [[1200, 1000, 'pc'], [390, 844, 'sp']]) {
  const p = await ctx.newPage();
  try {
    await p.setViewportSize({ width: w, height: h });
    await p.goto(process.env.SHOT_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    // **遅延読み込みの画像を出すため、いちど下まで送ってから戻す**
    await p.evaluate(async () => {
      for (let y = 0; y < document.body.scrollHeight; y += 700) {
        window.scrollTo(0, y);
        await new Promise((r) => setTimeout(r, 120));
      }
      window.scrollTo(0, 0);
    });
    await p.waitForTimeout(1500);
    await p.screenshot({ path: `${process.env.SHOT_DIR}/${name}.jpg`, fullPage: true, type: 'jpeg', quality: 72 });
    const H = await p.evaluate(() => document.body.scrollHeight);
    console.log(`${name} ok height=${H}`);
  } catch (e) {
    console.log(`${name} NG ${String(e).slice(0, 160)}`);
  } finally {
    await p.close();
  }
}
// **繋いだだけの Chrome は閉じない。** X のループが使っている
await b.close().catch(() => {});
JS

PW_DIR="$PWDIR" CDP_PORT="$PORT" SHOT_DIR="$DIR" SHOT_URL="$URL" \
  run_limited 150 node "$SCRIPT" > "$DIR/shot.log" 2>&1
SRC=$?
rm -f "$SCRIPT"

{
  echo "## 結果"
  echo ""
  echo "| | |"
  echo "| --- | --- |"
  echo "| rc | **${SRC}** $([ "$SRC" = "124" ] && echo '（**打ち切り**）' || true) |"
  for f in pc sp; do
    if [ -s "$DIR/$f.jpg" ]; then
      echo "| \`$f.jpg\` | **$(wc -c < "$DIR/$f.jpg" | tr -d ' ') bytes** ✅ |"
    else
      echo "| \`$f.jpg\` | **撮れなかった** ❌ |"
    fi
  done
  echo ""
  echo "撮影のログ:"
  echo ""
  echo '```text'
  tail -6 "$DIR/shot.log" 2>/dev/null
  echo '```'
  echo ""
  echo "---"
  echo ""
  echo "> **判断はしていない。撮っただけ**（最上位ルール 20）。"
  echo ""
  echo "LLM 不使用。**\$0/回・\$0/日・\$0/月。**"
} >> "$OUT"
rm -f "$DIR/shot.log"

# **末尾に結果を 1 行**（heartbeat に載るのは末尾 5 行の先頭 300 字だけ）
echo "" >> "$OUT"
echo "STDOUT_SHOT rc=$SRC pc=$([ -s "$DIR/pc.jpg" ] && wc -c < "$DIR/pc.jpg" | tr -d ' ' || echo 0) sp=$([ -s "$DIR/sp.jpg" ] && wc -c < "$DIR/sp.jpg" | tr -d ' ' || echo 0)" >> "$OUT"
cat "$OUT"
