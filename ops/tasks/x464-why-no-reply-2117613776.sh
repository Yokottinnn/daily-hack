#!/bin/bash
# x464（2026-11-11・読むだけ・$0）: 利用者「このリプライってなんで返信してないの？」。
# 相手の返信 2117613776182853984（11/3 22:44 JST・こちらの 2116727000358646078 への返信）に、incoming-reply-watcher が返さなかった理由を読む。
# **何も書き換えない・返信しない。** 他人のハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/x464-why-no-reply.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 相手の返信に返さなかった理由（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## ① ログ・データに 2 つの ID が出てくるか"; echo '```'
for id in 2117613776182853984 2116727000358646078; do echo "--- $id"; grep -rl "$id" "$L" "$D" 2>/dev/null | sed "s#$HOME#~#" | head -10; grep -rh "$id" "$L"/incoming-reply-watcher*.log 2>/dev/null | awk '!s[$0]++' | head -8 | cut -c1-220 | hide; done
echo '```'
echo; echo "## ② 11/3 22:40〜11/4 12:00 JST（13:40〜03:00 UTC）の incoming-reply-watcher の動き"; echo '```'
grep -hE '2026-11-03T1[3-9]|2026-11-03T2|2026-11-04T0[0-2]' "$L/incoming-reply-watcher.log" 2>/dev/null | awk '!s[$0]++' | grep -vE '^\s*$' | head -60 | cut -c1-200 | hide
echo '```'
echo; echo "## ③ 見る範囲と上限の設定（スクリプトの定数）"; echo '```'
grep -nE 'RECENT|MAX_|CAP|LIMIT|limit|recent|slice\(0|hours|HOURS|skip|SKIP' "$W/scripts/incoming-reply-watcher.js" 2>/dev/null | head -40 | cut -c1-180
echo '```'
echo; echo "## ④ 返さなかった理由の集計（11/1 以降・skip 系の行）"; echo '```'
grep -hE '2026-11' "$L/incoming-reply-watcher.log" 2>/dev/null | grep -iE 'skip|見送|対象外|ng|filter|already|cap' | sed -E 's/^\[[^]]*\] *//; s/@[A-Za-z0-9_]+/@<伏せ>/g; s/[0-9]{15,}/<ID>/g' | cut -c1-90 | sort | uniq -c | sort -rn | head -20
echo '```'
echo; echo "## ⑤ ジョブ"; echo '```'
launchctl print "gui/$(id -u)/ai.openclaw.incoming-reply-watcher" 2>/dev/null | grep -E '^\s+(state|runs|last exit code|run interval) =' | head -5
echo '```'
} > "$OUT" 2>&1
echo "x464 / $(basename "$OUT")"
exit 0
