#!/bin/bash
# x550（2026-11-24・読むだけ・$0）: スレッドの 2 投稿目（返信）が 11/22 の CAMP で 2 回とも落ちた原因を読む。
# 11/23 の湾岸のイルミは同じ道で通っている。落ちたときの全文のエラーと、post-comment.js の本文の確かめ方を出す。
# **何も書き換えない・押さない。** 他人のハンドルと秘密は伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/x550-read-reply-step-failure.md"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g; s/(post-comment\.js) "[A-Za-z0-9+\/=]{20,}"/$1 <本文>/g'; }
PC="$S/post-comment.js"; PCN="post-""comment.js"
{
echo "# 返信の 2 投稿目が落ちた原因（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 1. 11/22 CAMP の落ちた行（エラーの全文・本文は伏せる）"; echo '```'
grep -h '"step":"thread-reply' "$L/publish-camp-koyomi-oneshot.log" 2>/dev/null | head -2 | clean | fold -w 220 | head -60
echo '```'
echo; echo "## 2. 通った 11/23 イルミの同じ所"; echo '```'
grep -h -A3 'type-text' "$L/publish-wangan-illumination-oneshot.log" 2>/dev/null | head -12 | clean | cut -c1-220
echo '```'
echo; echo "## 3. $PCN の、本文を確かめるところ（mismatch・got_len・attached・x154・like）"; echo '```'
ls -la "$PC" 2>&1 | sed "s#$HOME#~#"
grep -n -E 'mismatch|got_len|not attached|detached|x154|like|type-text|insertText|keyboard\.type|fill\(|innerText|textContent' "$PC" 2>/dev/null | cut -c1-200 | clean
echo '```'
n="$(grep -n 'mismatch' "$PC" 2>/dev/null | head -1 | cut -d: -f1)"
if [ -n "${n:-}" ]; then echo; echo "## 4. mismatch の前後"; echo '```'; s=$(( n > 70 ? n - 70 : 1 )); sed -n "${s},$(( n + 15 ))p" "$PC" | cut -c1-200 | clean; echo '```'; fi
echo; echo "## 5. x154（いいね）を呼ぶところ"; echo '```'
grep -rn -l 'x154' "$S" 2>/dev/null | head -5 | sed "s#$HOME#~#"
grep -n -B3 -A12 'x154' "$PC" 2>/dev/null | head -50 | cut -c1-200 | clean
echo '```'
echo; echo "## 6. 2 投稿目の本文の頭（CAMP とイルミ・キューから）"; echo '```'
node -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const r=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);for(const id of ["x-blog-20261122-camp-koyomi","x-blog-20261123-wangan-illumination","x-blog-20261125-cruise-ranking"]){const e=r.find(x=>x&&x.id===id);if(!e){console.log(id,"無い");continue}const t=(e.thread_chain&&e.thread_chain[1]&&e.thread_chain[1].text)||"";console.log(id,"len="+t.length,"先頭="+JSON.stringify(t.slice(0,30)),"改行="+(t.split("\n").length-1),"URL="+/https?:\/\//.test(t))}' "$W/data/post_queue.json" 2>&1
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
