#!/bin/bash
# **本番の daily-hack.com で、楽天・Yahoo!・Amazon のボタンを実際に押して、成果リンクになっているかを確かめる（t582・blog3）。押すだけ・買わない・LLM 不使用・$0。**
#
# 利用者（2026-11-08）: 楽天と Yahoo! の行き先に「このブログから来た」印が見えず怪しい。プレビューでは確かめた
# （楽天は pt.afl.rakuten.co.jp/c/587f2635… を通り tg_af_histid を保存、Yahoo! は着地に sc_e=afvc_shp_3776384）。
# クラウドから本番は開けないので、Mac の Chrome で本番の同じボタンを押して、通った所・着いた先・保存された記録の名前を書き出す。
# 1 ボタンごとに新しいタブで開き、終わったら閉じる。記録の値は出さない（名前だけ）。全体で 260 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t582-affiliate-clicks.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 本番で 3 店ボタンを押して確かめる（t582・**\$0**）"
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

# ── 描画して押す ──
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

SCRIPT="$RDIR/.t582-click.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const CASES = [
  ['suitcase-xiaomi-nenmatsu-2026', '#shop-xiaomi-classic-pro-20'],
  ['denkidai-setsuyaku-koshiki-2026', '#shop-yamazen-ymm-w402'],
];
const T0 = Date.now();
for (const [slug, card] of CASES) {
  for (const store of ['rakuten', 'yahoo', 'amazon']) {
    if (Date.now() - T0 > 200000) { console.log('⚠️ 時間切れで打ち切り'); break; }
    const p = await ctx.newPage();
    try {
      await p.goto(`https://daily-hack.com/posts/${slug}/`, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await p.waitForTimeout(6000);
      const pat = store === 'rakuten' ? 'rakuten' : store === 'yahoo' ? 'yahoo|valuecommerce' : 'amazon';
      const href = await p.evaluate(([c, pat]) => {
        const a = [...document.querySelectorAll(`${c} a.shop-btn`)].find(x => new RegExp(pat).test(x.href));
        return a ? a.href : null;
      }, [card, pat]);
      console.log(`## ${slug} ／ ${store}\n`);
      if (!href) { console.log('⚠️ ボタンが見つからない\n'); await p.close(); continue; }
      console.log('- ボタンの行き先（押す前）: `' + href.slice(0, 160) + '`');
      const chain = [];
      const q = await ctx.newPage();
      q.on('response', r => { if (r.request().isNavigationRequest() && r.request().frame() === q.mainFrame()) chain.push(`${r.status()} ${r.url().slice(0, 170)}`); });
      await q.goto(href, { waitUntil: 'domcontentloaded', timeout: 30000, referer: `https://daily-hack.com/posts/${slug}/` }).catch(e => console.log('- ⚠️ ' + String(e).slice(0, 100)));
      await q.waitForTimeout(4000);
      console.log('- 通った所:\n' + chain.map(x => '  - `' + x + '`').join('\n'));
      console.log('- 着いた先: `' + q.url().slice(0, 220) + '`');
      const ck = (await ctx.cookies(['https://www.rakuten.co.jp', 'https://valuecommerce.com', 'https://shopping.yahoo.co.jp'])).map(c => c.name).filter(n => /histid|VC|af/i.test(n));
      console.log('- 計測の記録（名前だけ）: ' + [...new Set(ck)].join(' / ') + '\n');
      await q.close();
    } catch (e) { console.log('⚠️ ' + String(e).slice(0, 140) + '\n'); }
    await p.close().catch(() => {});
  }
}
await b.close().catch(() => {});
JS

RES="$RDIR/.t582-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 260 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。買い物はしない。" >> "$OUT"
cat "$OUT"
