#!/bin/bash
# **badge-followback.js の「候補 → 判定 → 処理済みに記録」の部分を読む。費用 $0。**
# x297: 上限は無い。なのに候補 21〜30 件に対して返せたのは 8〜13 件で、残りは処理済みとして二度と試されていない疑い。
# 認証済みフォロワー 43 人がフォロー返し待ち（x296）。直す前に、何で飛ばしているかを読む（推測で書かない）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; B="$W/scripts/badge-followback.js"
OUT="${OPS_REPORT_DIR:-/tmp}/followback-loop-read.md"
{
echo "# badge-followback.js の判定と記録（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```javascript'
sed -n '86,112p;136,215p' "$B" | grep -v -i "token\|secret"
echo '```'
echo
echo "## 処理済みの記録"
f="$(grep -oE "[A-Za-z0-9_./-]*(processed|badge)[A-Za-z0-9_.-]*\.json" "$B" | sort -u | head -5)"
echo '```'
echo "$f"
for x in $f; do p="$W/$x"; [ -f "$p" ] || p="$W/data/$(basename "$x")"; [ -f "$p" ] && node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const k=Object.keys(j);console.log(process.argv[1].replace(/.*\//,"")+": キー "+k.join(","));for(const a of k){if(Array.isArray(j[a]))console.log("  "+a+": "+j[a].length+" 件")}' "$p" 2>&1; done
echo '```'
echo
echo "## 前倒しの回の結果"
echo '```'
tail -3 "$W/logs/badge-followback.log" | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/"handles":\[[^\]]*\]/"handles":["<伏せ>"]/g'
echo '```'
echo "**読むだけ。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "badge-followback の判定と記録を読んだ / $(basename "$OUT")"
