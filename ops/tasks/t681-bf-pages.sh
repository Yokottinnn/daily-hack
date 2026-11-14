#!/bin/bash
# **ブラックフライデー2026の各店の公式ページを Chrome で開いて本文を取る（t681）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-15 利用者「この記事を参考にしてブラックライトのまとめ記事を作って。クオリティは紹介した記事より高くしてね」（ブラックフライデーのまとめ）。curl だと Bot 対策で 403 になる公式ページを、Mac の Chrome（CDP）で開いて本文（innerText）を保存する。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t681-bf-pages.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ブラックフライデーの公式ページ（t681・**\$0**）"
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

D="$RDIR/t681"; mkdir -p "$D"
SCRIPT="$RDIR/.t681.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [["aeonretail", "https://aeonretail.com/Page/p-bf_advance.aspx"], ["dyson", "https://www.dyson.co.jp/deals"], ["mistore", "https://www.mistore.jp/shopping/feature/shops_f3/blackfriday_sp"], ["hanayashiki", "https://www.hanayashiki.net/events/event/BlackFriday2026/"], ["his", "https://www.his-j.com/campaign/blackfriday/kanto.html"], ["hands", "https://hands.net/season/black-friday/"], ["aoyama", "https://www.y-aoyama.jp/ec/shop/"], ["jal", "https://www.jal.co.jp/jp/ja/campaign/blackflyday/"], ["babiesrus", "https://www.babiesrus.co.jp/ja-jp/promotions/blackfriday-baby/"], ["toysrus", "https://www.toysrus.co.jp/ja-jp/promotions/blackfriday-toy/"], ["disney", "https://store.disney.co.jp/special/black-friday-sale.html"], ["uniqlo", "https://www.uniqlo.com/jp/ja/special-feature/kanshasai"], ["gu", "https://www.gu-global.com/jp/ja/feature/special/women"], ["hm", "https://www2.hm.com/ja_jp/seasonal/black-friday.html"], ["fujiya", "https://www.fujiya-peko.co.jp/cake/sougyousai/"], ["tower", "https://tower.jp/article/feature_item/2026/11/05/0104"], ["rakutencard", "https://www.rakuten-card.co.jp/campaign/spt/googlepay_touch/"], ["rakuten", "https://event.rakuten.co.jp/campaign/blackfriday/"], ["amazon", "https://www.amazon.co.jp/blackfriday"], ["welcia", "https://m.e-welcia.com/drug/202610_blackfriday_cp_app"], ["playstation", "https://store.playstation.com/ja-jp/pages/latest"], ["linegift", "https://gift.line.me/"]];
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4500);
    const t = await p.evaluate(() => document.body ? document.body.innerText : '');
    const ti = await p.title();
    fs.writeFileSync(`${D}/${k}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${t}`);
    console.log(`- ${k}: ${t.length} 文字 「${ti.slice(0,60)}」 → ${p.url().slice(0,90)}`);
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0,100)}`); }
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t681-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 9000 "$OUT"
