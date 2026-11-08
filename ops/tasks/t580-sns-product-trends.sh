#!/bin/bash
# **X と TikTok で「いま買われている・話題の商品」を読む（t580・affiliate）。読むだけ・投稿しない・LLM 不使用・$0。**
#
# 利用者（2026-11-07）「商品比較の記事を増やしたい」「XとかのSNSのトレンドを掴んだ方がいい」。商品比較の記事の候補を X・TikTok の話題から選び直す。
# ① X の探索タブ（トレンド・ニュース・エンタメ）のトレンド語
# ② X の検索（話題順・直近 7 日・いいね 300 以上）をブログのジャンル語で。本文といいね・RT の数
# ③ TikTok Creative Center の日本の人気ハッシュタグ（7 日）
# 外部 HTTPS が開いていて読めるもの（trends24・Yahoo!リアルタイム・はてブ等）はクラウドで読む。240 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t580-sns-trends.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# X・TikTok の話題を読む（t580・**\$0**）"
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
SCRIPT="$RDIR/.t580-read.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1300, height: 1600 });
// ① 探索タブ
for (const tab of ['trending']) {
  console.log(`## X 探索: ${tab}\n`);
  try {
    await p.goto(`https://x.com/explore/tabs/${tab}`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(5000);
    for (let i = 0; i < 3; i++) { await p.mouse.wheel(0, 1400); await p.waitForTimeout(900); }
    const t = await p.evaluate(() => [...document.querySelectorAll('[data-testid="trend"]')].map(e => e.innerText.replace(/\s*\n\s*/g, ' ｜ ').slice(0, 140)));
    console.log(t.length ? t.map(x => `- ${x}`).join('\n') : '⚠️ トレンドの要素が 0 件（ログイン切れか DOM 変更）');
  } catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 120)}`); }
  console.log('');
}
// ② ジャンル語で話題順
const Q = ['買ってよかった', '買って正解', '神アイテム OR 神グッズ', '便利グッズ', 'コスパ最強', '楽天で買った OR 楽天で購入', 'Amazonで買った OR Amazonで購入', 'ブラックフライデー 買う', '冬 買ってよかった OR 寒さ対策 グッズ', 'ガジェット おすすめ', '100均 OR 無印 OR 3COINS 新作', 'ダイソー OR ニトリ 買ってよかった', 'クリスマスプレゼント 喜ばれた', '品切れ OR 売り切れ 続出'];
for (const q of Q) {
  if (Date.now() - T0 > 260000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  console.log(`## X 検索: ${q}\n`);
  try {
    const xq = encodeURIComponent(`(${q}) lang:ja min_faves:500 since:2026-10-24 -filter:replies`);
    await p.goto(`https://x.com/search?q=${xq}&src=typed_query&f=top`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4500);
    await p.mouse.wheel(0, 1600); await p.waitForTimeout(1200);
    const posts = await p.evaluate(() => [...document.querySelectorAll('article')].slice(0, 10).map(a => {
      const link = [...a.querySelectorAll('a[href*="/status/"]')].map(x => x.getAttribute('href')).find(h => /\/status\/\d+$/.test(h)) || '';
      const text = (a.querySelector('[data-testid="tweetText"]')?.innerText || '').replace(/\s+/g, ' ').slice(0, 150);
      const stat = (a.querySelector('[role="group"]')?.getAttribute('aria-label') || '').slice(0, 90);
      return [link, stat, text];
    }));
    console.log(posts.length ? posts.map(([l, s, t]) => `- https://x.com${l} ｜ ${s} ｜ ${t}`).join('\n') : '（0 件）');
  } catch (e) { console.log(`⚠️ 取れない: ${String(e).slice(0, 120)}`); }
  console.log('');
}
// ③ TikTok
console.log('## TikTok Creative Center: 日本の売れ筋商品（7 日）\n');
try {
  await p.goto('https://ads.tiktok.com/business/creativecenter/top-products/pc/ja?period=7&region=JP', { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(6000);
  const txt = await p.evaluate(() => document.body.innerText.replace(/\n{2,}/g, '\n').slice(0, 3000));
  console.log('```text\n' + txt + '\n```');
} catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 120)}`); }
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t580-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 320 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
