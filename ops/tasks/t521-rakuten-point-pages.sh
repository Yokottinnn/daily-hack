#!/bin/bash
# **大掃除のハウスクリーニング比較の記事のために、楽天市場のポイントアップ（SPU・お買い物マラソン・5と0のつく日・勝ったら倍・スーパーSALE）の公式ページを読み、最大倍率の内訳と条件を集める（t521）。読むだけ・LLM 不使用・$0。**
# 2026-10-31 利用者がダイアログで「大掃除のハウスクリーニング比較」を選んだ。A8 の提携詳細から広告主のサイトを辿り、料金・メニューのページの「円」を含む行を出す。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t521-cleaning-prices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ハウスクリーニング 3 社の公式の料金（t521・**\$0**）"
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
SCRIPT="$RDIR/.t521-prices.mjs"
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
const PAGES = [
  ['spu', 'https://event.rakuten.co.jp/campaign/point-up/everyday/point/'],
  ['marathon', 'https://event.rakuten.co.jp/campaign/point-up/marathon/'],
  ['marathon-guide', 'https://event.rakuten.co.jp/campaign/point-up/marathon/guide/'],
  ['pointday', 'https://event.rakuten.co.jp/campaign/card/pointday/'],
  ['sports', 'https://event.rakuten.co.jp/campaign/sports/'],
  ['supersale', 'https://event.rakuten.co.jp/campaign/supersale/'],
  ['top', 'https://www.rakuten.co.jp/'],
];
const t0 = Date.now();
for (const [key, u] of PAGES) {
  if (Date.now() - t0 > 200000) { console.log('- ⏱ 時間切れ'); break; }
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch((e) => console.log(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`));
  await p.waitForTimeout(4000);
  const d = await p.evaluate(() => {
    const t = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean);
    // 個人の数字（「あなた」「現在の倍率」）は出さない
    const keep = t.filter((x) => /倍|%|％|上限|ポイント|エントリー|期間|条件|対象|付与|SPU/.test(x) && !/あなた|会員ランク|保有|現在の/.test(x) && x.length < 160);
    const alts = [...document.querySelectorAll('img[alt]')].map((i) => i.alt.trim()).filter((a) => /倍|最大|%/.test(a)).slice(0, 30);
    return { title: document.title, url: location.href, keep: [...new Set(keep)].slice(0, 140), alts: [...new Set(alts)] };
  }).catch(() => ({ title: '（読めない）', url: u, keep: [], alts: [] }));
  console.log(`\n## ${key}｜${d.title}\n- ${d.url}`, ...d.keep.map((x) => `\n  - ${x}`), ...d.alts.map((x) => `\n  - 画像 alt: ${x}`));
  await p.screenshot({ path: `${DIR}/${key}.png`, fullPage: false }).catch(() => {});
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t521-res.txt"
SHOT_DIR="$RDIR/t521-shots" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
cp "$OUT" "$RDIR/t521-cleaning-prices.md" 2>/dev/null
head -c 12000 "$OUT"
