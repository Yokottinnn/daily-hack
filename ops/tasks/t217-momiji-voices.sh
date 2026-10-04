#!/bin/bash
# **紅葉記事に埋め込む「行った人の声」を探す（t217）。読むだけ・LLM 不使用・$0。**
#
# blog-article スキル: X の実投稿と YouTube を、**実在するものだけ**埋め込む。
# 今年はまだ色づいていないので、X は**去年の見頃（2025-11〜12）の画像つき投稿**を 6 名所ぶん探す。
# YouTube は検索結果の動画 ID を **oEmbed で題名と投稿者を照合**する（題名で別の場所の動画を弾くため）。
# 投稿はここでは選ばない。選ぶのはクラウド側で、syndication API で照合してから。
# t215 と同じく、動いている Chrome に CDP で繋ぐ。新しく起動しない。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t217-momiji-voices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 描画してから本文を読む（t217・**\$0**）"
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
SCRIPT="$RDIR/.t217-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const SPOTS = ['明治神宮外苑 いちょう並木', '六義園 紅葉', '新宿御苑 紅葉', '昭和記念公園 紅葉', '高尾山 紅葉', 'いろは坂 紅葉'];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
let ok = 0;
for (const q of SPOTS) {
  console.log(`## ${q}\n`);
  // X: 去年の見頃の時期の投稿（今年はまだ色づいていない）
  const p = await ctx.newPage();
  try {
    const xq = encodeURIComponent(`${q} since:2025-11-01 until:2025-12-20 filter:images -filter:replies`);
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

RES="$RDIR/.t217-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 230 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
