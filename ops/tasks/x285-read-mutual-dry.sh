#!/bin/bash
# **x284 で切り離して走らせた mutual-prune の DRY（未認証で釣り合い ≥0.8 を含む）の結果を読む。何も外さない。費用 $0。**
# 終わっていなければ最大 3 分だけ待ち、それでも途中なら途中経過を出す（最上位ルール 15）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/mutual-dry-result.md"
L="$W/logs/x284-mutual-dry.log"
{
echo "# 相互フォローの整理・DRY の結果（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・外していない）"
echo
w=0; while pgrep -f "mutual-prune.js" >/dev/null 2>&1 && [ "$w" -lt 180 ]; do sleep 5; w=$((w+5)); done
pgrep -f "mutual-prune.js" >/dev/null 2>&1 && echo "**まだ走っている（途中経過）**" || echo "- 終わっている"
echo
echo '```'
grep -E "相互フォロー:|見たプロフィール|DRY_RUN" "$L" | sed -E 's/^\[[^]]*\] //'
echo
echo "外す候補（✂）の理由:"
grep "✂" "$L" | grep -o "釣り合い\|休眠\|格下" | sort | uniq -c
echo "外す候補のうち「釣り合い」だけが理由のもの: $(grep '✂' "$L" | grep '釣り合い' | grep -vc '休眠\|格下' | head -1)"
echo
echo "残した理由:"
grep "・ " "$L" | sed -E 's/.* — //; s/（.*//; s/ [0-9]+ 日.*//' | sort | uniq -c | sort -rn | head -8
echo
echo "釣り合いの値の分布（✂ の分）:"
grep "✂" "$L" | grep -o "釣り合い [0-9.]*" | awk '{v=$2; if(v<1)a++; else if(v<2)b++; else if(v<5)c++; else d++} END{print "  0.8〜1.0: "a+0"  1.0〜2.0: "b+0"  2.0〜5.0: "c+0"  5.0〜: "d+0}'
echo '```'
echo
echo "**1 件も外していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "相互フォローの整理の DRY 結果を読んだ / $(basename "$OUT")"
