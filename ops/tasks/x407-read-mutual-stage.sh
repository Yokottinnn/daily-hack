#!/bin/bash
# x407（2026-11-03・読むだけ・$0）: 利用者「未認証の相互は、アンフォローしても影響なさそうなやつは厳選してアンフォローしていいよ」。
# follow-balance が相互を外すかどうか決めている段（②③）と、反応の記録の読み込み・プロフィールの読み取りの部分を読む。**何も書き換えない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts/follow-balance.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x407-read-mutual-stage.md"
{
echo "# follow-balance の相互の段を読む（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 反応の記録の読み込み（engaged）"; echo '```'
n="$(grep -n 'engaged' "$S" | head -1 | cut -d: -f1)"; [ -n "$n" ] && sed -n "$((n>8?n-8:1)),$((n+22))p" "$S" | cut -c1-200
echo '```'
echo; echo "## プロフィールを読む部分（readProfile 相当・前後）"; echo '```'
sed -n 176,200p "$S" | cut -c1-200
echo '```'
echo; echo "## 相互の段（② ③）"; echo '```'
sed -n 455,500p "$S" | cut -c1-220
echo '```'
echo; echo "## 外す順番（rank）"; echo '```'
grep -nE 'rank' "$S" | head -12 | cut -c1-200
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
