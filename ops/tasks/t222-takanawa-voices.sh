#!/bin/bash
# **高輪ゲートウェイシティの記事に埋め込む「行った人の声」を探す（t222）。読むだけ・LLM 不使用・$0。**
#
# t217 と同じ作り。X は 2026-03 以降の画像つき投稿、YouTube は動画 ID を oEmbed で照合する。
# 検索語は、検索候補に出ていた「ランチ」「サウナ」と、28F の LUFTBAUM・MoN Takanawa。
# 投稿はここでは選ばない。選ぶのはクラウド側で、syndication API で照合してから。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t222-takanawa-voices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 描画してから本文を読む（t222・**\$0**）"
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
SCRIPT="$RDIR/.t222-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const SPOTS = ['ニュウマン高輪 ランチ', '高輪ゲートウェイシティ', 'LUFTBAUM 高輪', '高輪SAUNAS', 'MoN Takanawa'];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
let ok = 0;
for (const q of SPOTS) {
  console.log(`## ${q}\n`);
  // X: 去年の見頃の時期の投稿（今年はまだ色づいていない）
  const p = await ctx.newPage();
  try {
    const xq = encodeURIComponent(`${q} since:2026-03-01 filter:images -filter:replies`);
    await p.goto(`https://x.com/search?q=${xq}&src=typed_query&f=top`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(5000);
    const posts = await p.evaluate(() => [...document.querySelectorAll('article')].slice(0, 6).map(a => {
      const link = [...a.querySelectorAll('a[href*="/status/"]')].map(x => x.getAttribute('href')).find(h => /\/status\/\d+$/.test(h)) || '';
      const text = (a.querySelector('[data-testid="tweetText"]')?.innerText || '').replace(/\s+/g, ' ').slice(0, 120);
      return [link, text];
    }));
    console.log(`**X**（${posts.length} 件）\n`);
    for (const [l, t] of posts) console.log(`- https://x.com${l} — ${t}`);
    console.log('');
    ok++;
  } catch (e) { console.log(`⚠️ X 取れない: ${String(e).slice(0, 140)}\n`); } finally { await p.close(); }
  // YouTube: 検索結果の動画 ID と題名 → oEmbed で照合
  const y = await ctx.newPage();
  try {
    await y.goto(`https://www.youtube.com/results?search_query=${encodeURIComponent(q)}`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await y.waitForTimeout(4000);
    const vids = await y.evaluate(() => [...new Set([...document.querySelectorAll('a#video-title')].map(a => a.href))].slice(0, 4));
    console.log(`**YouTube**（${vids.length} 件・oEmbed で照合）\n`);
    for (const v of vids) {
      const id = (v.match(/v=([\w-]{11})/) || [])[1];
      if (!id) continue;
      try {
        const r = await fetch(`https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v=${id}`);
        const j = await r.json();
        console.log(`- ${id} — ${j.title} ／ ${j.author_name}`);
      } catch (e) { console.log(`- ${id} — ⚠️ oEmbed 失敗`); }
    }
    console.log('');
  } catch (e) { console.log(`⚠️ YouTube 取れない: ${String(e).slice(0, 140)}\n`); } finally { await y.close(); }
}
console.log(`---\n\n**対象 ${SPOTS.length} / X が読めた ${ok}**`);
await b.close().catch(() => {});
JS

RES="$RDIR/.t222-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 230 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
