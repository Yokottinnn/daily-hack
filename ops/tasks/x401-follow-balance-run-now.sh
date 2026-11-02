#!/bin/bash
# x401（2026-11-02・$0）: 利用者「もう少し外せないか見てみて　外せる人は外して」（フォロー比率 0.663・目標 0.430）。
# ① follow-balance の直近 2 回の実行を、始まりから終わりまで読む（候補・外した・残した理由）
# ② 決まった時刻を待たずに、いま 1 回走らせる（launchctl kickstart。外す基準・間隔（最上位ルール 23）・上限は今のまま）
# LLM を呼ばない（1 回 $0）。他人のハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; F="$W/logs/follow-balance.log"; S="$W/scripts/follow-balance.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x401-follow-balance-run-now.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x|twitter)\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1.com/<伏せ>#g'; }
{
echo "# 比率の調整：直近の実行の中身といま 1 回走らせる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo; echo "## ① 直近 2 回の実行（重複行は除く）"; echo '```'
starts="$(grep -n 'start\|開始\|比率の目標（GLIDE）' "$F" | cut -d: -f1 | awk 'NR==1||$1-p>5{print} {p=$1}' | tail -2 | head -1)"
[ -n "$starts" ] && tail -n +"$starts" "$F" | awk '!seen[$0]++' | head -120 | cut -c1-230 | hide
echo '```'
echo; echo "## 理由ごとの数（直近 3 日・重複行は除く）"; echo '```'
D="$(node -e 'const o=[];for(let i=0;i<3;i++)o.push(new Date(Date.now()+9*3600e3-i*864e5).toISOString().slice(0,10));console.log(o.join("|"))')"
grep -E "$D" "$F" | awk '!seen[$0]++' | sed -E 's/^\[[^]]*\] *//; s/@[A-Za-z0-9_]+/@x/g; s/[0-9]+/N/g' | cut -c1-80 | sort | uniq -c | sort -rn | head -30
echo '```'
echo; echo "## 外し方の作り（間隔・上限・残す条件の行）"; echo '```'
grep -nE 'pacer|until|GRACE|verified|認証|mutual|相互|MAX_UNFOLLOW|MIN_UNFOLLOW|skip|残す' "$S" | head -40 | cut -c1-200
echo '```'
echo; echo "## ② いま 1 回走らせる"; echo '```'
L="gui/$(id -u)/ai.openclaw.follow-balance"
before="$(launchctl print "$L" 2>/dev/null | grep -E '^\s*runs =' | tr -d ' ')"
launchctl kickstart "$L" 2>&1; echo "kickstart rc=$?"
sleep 5
after="$(launchctl print "$L" 2>/dev/null | grep -E '^\s*(runs|state) =' | tr -s ' \n' ' ')"
echo "前: $before / 後: $after"
echo '```'
echo "**このタスクは外していない。外すのは follow-balance 本体（いま走らせた 1 回）。結果は次のタスクで読む**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
