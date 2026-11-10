#!/bin/bash
# x466（2026-11-11・$0）: 返信の見張り（incoming-reply-watcher）が見る範囲を、こちらから出した投稿だけ 7 日に広げる。
# 利用者がダイアログで「見る範囲を 7 日に広げる」を選んだ。いまは出してから 24 時間以内の投稿しか見ておらず、
# 11/1 の投稿に 11/3 に付いた返信を取りこぼした（x464・x465）。他人への返信（id が comment- で始まるもの）は 24 時間のまま。
# 1 日 20 件の上限は変えない。前のスクリプトは .bak を残す。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts/incoming-reply-watcher.js"; STAMP="$(date '+%Y%m%d-%H%M%S')"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x466-widen-reply-watch-7d.md"
{
echo "# 返信の見張りを 7 日に広げる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'
cp -p "$S" "$S.bak.$STAMP"
"$NODE_BIN" -e '
const fs=require("fs");const f=process.argv[1];let s=fs.readFileSync(f,"utf8");
const a="const cutoff = Date.now() - 24 * 3600 * 1000;";
const b="e.posted_at && new Date(e.posted_at).getTime() > cutoff";
if(s.includes("cutoff7")){console.log("もう入っている");process.exit(0)}
if(!s.includes(a)||!s.includes(b)){console.log("NG 書き換える場所が見つからない");process.exit(1)}
s=s.replace(a,a+"\n  // x466: こちらから出した投稿は 7 日見る（他人への返信 comment-* は 24 時間のまま）\n  const cutoff7 = Date.now() - 7 * 24 * 3600 * 1000;");
s=s.replace(b,"e.posted_at && new Date(e.posted_at).getTime() > (String(e.id || \"\").startsWith(\"comment-\") ? cutoff : cutoff7)");
fs.writeFileSync(f+".x466.js",s);console.log("OK")' "$S"
R=$?
if [ $R -eq 0 ] && [ -f "$S.x466.js" ]; then
  if "$NODE_BIN" --check "$S.x466.js"; then mv "$S.x466.js" "$S"; echo "  入れた（前のものは .bak.$STAMP）"; else echo "  **構文エラー。入れない**"; rm -f "$S.x466.js"; fi
fi
grep -n 'cutoff7\|cutoff : cutoff7' "$S" | cut -c1-200
echo "--- 7 日で見ることになる投稿の数（今の時点）"
"$NODE_BIN" -e 'const q=require(process.argv[1]).queue;const c1=Date.now()-864e5,c7=Date.now()-7*864e5;const r=q.filter(e=>e.status==="posted"&&e.x_tweet_id&&e.x_tweet_id!=="2054071132509311284"&&e.posted_at&&new Date(e.posted_at).getTime()>(String(e.id||"").startsWith("comment-")?c1:c7));console.log("  合計 "+r.length+" 本（うち自分から出した投稿 "+r.filter(e=>!String(e.id).startsWith("comment-")).length+" 本）")' "$W/data/post_queue.json" 2>&1
echo '```'
} > "$OUT" 2>&1
grep -E '入れた|NG|構文' "$OUT" | head -1
exit 0
