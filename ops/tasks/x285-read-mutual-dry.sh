#!/bin/bash
# **x284 で切り離して走らせた mutual-prune の DRY（未認証で釣り合い ≥0.8 を含む）の結果を読む。何も外さない。費用 $0。**
# 終わっていなければ最大 3 分だけ待ち、それでも途中なら途中経過を出す（最上位ルール 15）。
# **利用者の選択（2026-10-12）「候補が妥当ならそのまま本番化」:** DRY が最後まで終わり、外す候補が相互の 3 割以下なら、
# mutual-prune の plist に MUTUAL_RATIO_CUT=0.8 を足して載せ直す（1 回に外す上限 MAX_UNFOLLOW=8 はそのまま）。
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
echo "## 本番化の判定"
echo
MUT="$(grep -o '相互フォロー: [0-9]*' "$L" | grep -o '[0-9]*' | head -1)"; MUT="${MUT:-0}"
CUT="$(grep -c '✂' "$L" | head -1)"; case "$CUT" in ''|*[!0-9]*) CUT=0;; esac
DONE=0; grep -q "DRY_RUN" "$L" && DONE=1
PL="$HOME/Library/LaunchAgents/ai.openclaw.mutual-prune.plist"
if [ "$DONE" = 1 ] && [ "$MUT" -gt 0 ] && [ $((CUT * 10)) -le $((MUT * 3)) ]; then
  cp "$PL" "$PL.bak-x285"
  /usr/libexec/PlistBuddy -c "Delete :EnvironmentVariables:MUTUAL_RATIO_CUT" "$PL" >/dev/null 2>&1
  /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:MUTUAL_RATIO_CUT string 0.8" "$PL"
  launchctl bootout "gui/$(id -u)/ai.openclaw.mutual-prune" >/dev/null 2>&1; sleep 2
  launchctl bootstrap "gui/$(id -u)" "$PL" 2>&1 | head -1
  echo "- **本番化した**（候補 $CUT ／ 相互 $MUT・3 割以下）。plist: $(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:MUTUAL_RATIO_CUT' "$PL")"
  echo '```'; launchctl print "gui/$(id -u)/ai.openclaw.mutual-prune" 2>&1 | grep -E "state =|MUTUAL_RATIO_CUT|MAX_UNFOLLOW" | head -3; echo '```'
else
  echo "- **本番化しなかった**（DRY 完了=$DONE ・候補 $CUT ／ 相互 $MUT）。3 割を超えるか、DRY が終わっていない"
fi
echo
echo "**この時点までに外したアカウントは無い（DRY）。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 戻すときは plist の .bak-x285。"
} > "$OUT" 2>&1
echo "相互フォローの整理の DRY 結果を読んだ / $(basename "$OUT")"
