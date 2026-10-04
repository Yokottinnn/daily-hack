#!/bin/bash
# **mutual-prune（相互の見直し）の、直してから初めての回（10/4 6:00）の結果を読む。読むだけ。費用 $0。**
#
# ## 指示（2026-10-04）
#
#   > 相互フォローでこっそりフォローを外せそうな人はいる？
#   > 定期的にフォローを外すように指示していたつもりだけどちゃんと動いてる？
#
# x224（10/4 01:02）で「空のページは開き直す」「終わったら必ず終了させる」を入れた。
# その後の回を読み、**外せたか・候補が何件で、何に守られて外さなかったか**を出す。
#
#   ① いまの状態（launchctl print）と、居座りが無いか（終わっているか）
#   ② x224 以降の回ごとに: start／見たプロフィール／外す候補／外した行／done
#   ③ 守った理由の内訳（件数だけ。ハンドルは出さない）
#
# **外さない。フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

LABEL="ai.openclaw.mutual-prune"
UIDN="$(id -u)"
L="$HOME/.openclaw/workspace/logs/mutual-prune.log"
OUT="${OPS_REPORT_DIR:-/tmp}/read-mutual-prune-0600.md"
# @付き・パス・URL に加え、「checking N handles: a,b,c」のような裸のハンドル並びも伏せる
mask() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#"/[A-Za-z0-9_]{2,15}"#"/<伏せ>"#g; s#x\.com/[A-Za-z0-9_]{2,15}#x.com/<伏せ>#g; s/(handles?:).*/\1 <伏せ>/'; }

{
echo "# mutual-prune の結果（直してから）（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## ① いまの状態"
echo
echo '```'
pr="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
if [ -z "$pr" ]; then echo "  **載っていない**（launchctl print が通らない）"; else
  printf '  state=%s runs=%s last_exit=%s pid=%s\n' \
    "$(printf '%s' "$pr" | awk -F'= ' '/^\tstate =/{print $2; exit}')" \
    "$(printf '%s' "$pr" | awk -F'= ' '/^\truns =/{print $2; exit}')" \
    "$(printf '%s' "$pr" | awk -F'= ' '/last exit code =/{print $2; exit}')" \
    "$(printf '%s' "$pr" | awk -F'= ' '/^\tpid =/{print $2; exit}')"
fi
printf '  ログ: %s 行・更新 %s\n' "$(wc -l < "$L" | tr -d ' ')" "$(stat -f '%Sm' -t '%m/%d %H:%M' "$L")"
echo '```'
echo
echo "## ② x224（10/4 01:02）以降の回"
echo
# x224 以降の行だけ（ログは UTC。10/4 01:02 JST = 10/3 16:02Z）。重複行を除く
RUN="$(awk '{ t = substr($0, 2, 20); if (t >= "2026-10-03T16:02:00") print }' "$L" | awk '!s[$0]++')"
n_start="$(printf '%s\n' "$RUN" | grep -c -E 'start' | head -1)"
if [ -z "$RUN" ] || [ "${n_start:-0}" = "0" ]; then
  echo "**x224 以降に走った記録が無い。** 末尾 15 行:"
  echo; echo '```'; tail -15 "$L" | awk '!s[$0]++' | cut -c1-200 | mask | sed 's/^/  /'; echo '```'
else
  echo '```'
  # 「・ @… — 理由」の行（守った人）は件数だけにして、それ以外を出す
  printf '%s\n' "$RUN" | grep -v -E '^\[[^]]*\]   ・ @' | cut -c1-220 | mask | tail -60 | sed 's/^/  /'
  echo '```'
  echo
  echo "## ③ 守った理由の内訳（x224 以降・のべ）"
  echo
  echo '```'
  printf '%s\n' "$RUN" | grep -E '^\[[^]]*\]   ・ @' | sed -E 's/.* — //; s/[0-9]+ 日/N 日/g' | sort | uniq -c | sort -rn | sed 's/^/  /'
  echo '```'
fi
echo
echo "**外していない。フォローしていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q '## ③\|走った記録が無い' "$OUT"; then echo "mutual-prune の結果を読んだ / $(basename "$OUT")"
else echo "**読めない** / $(basename "$OUT")"; exit 1; fi
