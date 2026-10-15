#!/bin/bash
# **記事ごとに「X で告知した痕跡」を Mac のキュー・投稿ログから探す。何も押さない。費用 $0。**
# x294 はキューの URL の書き方を当て推量して 0 件だった。今回は記事の slug そのもので全部を探す。
# 利用者の選択「ほかに告知していないブログがあれば教えて」（2026-10-15）。LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
R="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/announced-posts-by-slug.md"
{
echo "# 記事ごとの告知の痕跡（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## キューの形（1 件目のキーと、URL らしき値の例）"
echo '```'
node -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const a=Array.isArray(q)?q:(q.queue||[]); console.log("件数 "+a.length+" / 上位キー "+Object.keys(q).join(","));
if(a[0]) console.log("キー: "+Object.keys(a[0]).join(","));
const urls=new Set(); for(const e of a){ const s=JSON.stringify(e); (s.match(/https?:[^"\\ ]*posts[^"\\ ]*/g)||[]).forEach(u=>urls.add(u)); } console.log("posts を含む URL: "+urls.size); [...urls].slice(0,5).forEach(u=>console.log("  "+u));
' "$W/data/post_queue.json" 2>&1 | head -12
echo '```'
echo
echo "## 記事ごと（キュー・data・logs で slug が出た回数と、そのキューの tweet id）"
echo
echo "| 公開日 | slug | キュー | tweet id | data/logs の出現 |"
echo "| --- | --- | --- | --- | --- |"
git -C "$R" fetch -q origin main 2>/dev/null
for s in $(git -C "$R" ls-tree --name-only origin/main src/content/posts/ | sed 's#.*/##; s#\.md$##'); do
  d="$(git -C "$R" show "origin/main:src/content/posts/$s.md" 2>/dev/null | grep -m1 '^publishDate:' | sed 's/^[^:]*: *//; s/"//g')"
  qi="$(node -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); const a=Array.isArray(q)?q:(q.queue||[]); const s=process.argv[2];
let n=0; const ids=[]; for(const e of a){ if(JSON.stringify(e).includes(s)){ n++; const id=e.x_tweet_id||e.tweet_id||(e.result&&e.result.tweet_id); if(id) ids.push(id); } }
console.log(n+"\t"+(ids.slice(0,2).join(" ")||"-"));' "$W/data/post_queue.json" "$s" 2>/dev/null)"
  n="$(grep -rl -- "$s" "$W/data" "$W/logs" 2>/dev/null | grep -v post_queue.json | wc -l | tr -d ' ')"
  printf '| %s | %s | %s | %s | %s |\n' "$d" "$s" "$(printf '%s' "$qi" | cut -f1)" "$(printf '%s' "$qi" | cut -f2)" "$n"
done | sort -r
echo
echo "**何も押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "記事ごとの告知の痕跡を読んだ / $(basename "$OUT")"
