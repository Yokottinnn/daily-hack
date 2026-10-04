#!/bin/bash
# **Instagram・TikTok・Threads で記事案の題材の反応を読む（t231）。読むだけ・LLM 不使用・$0。**
#
# t230 は X だけだった。記事案 10 本の題材語で、Instagram のハッシュタグ（投稿数）・TikTok 検索（再生数）・
# Threads 検索（いいね）を読む。ログイン状態は Mac の Chrome 次第なので、読めなかったら画面の文字をそのまま出す。240 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t231-sns-trends.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# X・TikTok の話題を読む（t231・**\$0**）"
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
SCRIPT="$RDIR/.t231-read.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1300, height: 1600 });
const TAGS = ['マンション価格', 'こどもnisa', '値上げ', 'ポイ活', 'sfc修行', 'ららぽーと豊洲', '年収の壁', 'ネオバンク', 'クリスマスケーキ2026', 'イルミネーション2026', '業務スーパー', 'ハロウィン2026'];
const txt = async (n) => (await p.evaluate(() => document.body.innerText)).replace(/\n{2,}/g, '\n').slice(0, n);
const go = async (u, w) => { await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }); await p.waitForTimeout(w); };
for (const t of TAGS) {
  if (Date.now() - T0 > 210000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  console.log(`## ${t}\n`);
  try { await go(`https://www.instagram.com/explore/tags/${encodeURIComponent(t)}/`, 3500);
    const m = await p.evaluate(() => (document.body.innerText.match(/[\d,.]+\s*(万|件)?\s*(件の)?投稿/) || [''])[0] || (document.querySelector('meta[name="description"]')?.content || ''));
    console.log(`- Instagram: ${m || '（数が出ない）'}`);
  } catch (e) { console.log(`- Instagram: ⚠️ ${String(e).slice(0, 80)}`); }
  try { await go(`https://www.tiktok.com/search/video?q=${encodeURIComponent(t)}`, 5000);
    const v = await p.evaluate(() => [...document.querySelectorAll('[data-e2e="search_video-item"], [data-e2e="search-card-desc"], div[class*="DivItemContainer"]')].slice(0, 8).map(e => e.innerText.replace(/\s+/g, ' ').slice(0, 110)));
    console.log(v.length ? v.map(x => `- TikTok: ${x}`).join('\n') : '- TikTok: （動画の要素が無い）\n```text\n' + (await txt(500)) + '\n```');
  } catch (e) { console.log(`- TikTok: ⚠️ ${String(e).slice(0, 80)}`); }
  try { await go(`https://www.threads.com/search?q=${encodeURIComponent(t)}&serp_type=default`, 4500);
    const th = await txt(900);
    console.log('- Threads:\n```text\n' + th + '\n```');
  } catch (e) { console.log(`- Threads: ⚠️ ${String(e).slice(0, 80)}`); }
  console.log('');
}
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t231-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
