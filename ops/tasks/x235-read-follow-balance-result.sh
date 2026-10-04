#!/bin/bash
# **x234 で走らせた follow-balance の結果を読む。読むだけ。費用 $0。**
#
# x234 は最大 240 秒 しか見ない。同じ周回で走ったときは、**終わるまで最大 270 秒 待つ**。
# それでも走っていれば、そう書く（推測で「外せた」と言わない）。
#
#   ① いま走っているか（launchctl print）
#   ② 今回の実行のログ（最後の「start」以降）: 外した件数・開き直した件数・ボタンが無かった件数
#   ③ いまのヘッダーの数は follow-balance のログに出る「実数（ヘッダー）」を使う
#
# **外さない。フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

LABEL="ai.openclaw.follow-balance"
UIDN="$(id -u)"
L="$HOME/.openclaw/workspace/logs/follow-balance.log"
OUT="${OPS_REPORT_DIR:-/tmp}/read-follow-balance-result-4.md"
mask() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#"/[A-Za-z0-9_]{2,15}"#"/<伏せ>"#g'; }

# x228 と同じ周回で走ることがある。**走っている間は最大 270 秒 待つ**（1 タスク 5 分 以内・最上位ルール 15）
waited=0
while [ "$waited" -lt 270 ]; do
  st="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')"
  [ "$st" = "running" ] || break
  sleep 10; waited=$((waited + 10))
done

{
echo "# follow-balance の結果（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo '```'
echo "  終わるのを待った: ${waited} 秒"
pr="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
printf '  state=%s runs=%s last_exit=%s\n' \
  "$(printf '%s' "$pr" | awk -F'= ' '/^\tstate =/{print $2; exit}')" \
  "$(printf '%s' "$pr" | awk -F'= ' '/^\truns =/{print $2; exit}')" \
  "$(printf '%s' "$pr" | awk -F'= ' '/last exit code =/{print $2; exit}')"
echo '```'
echo
# 最後の start 以降（ログは各行が 2 回ずつ書かれるので重複を除く）
ln="$(grep -n 'follow-balance start' "$L" 2>/dev/null | tail -1 | cut -d: -f1)"
if [ -z "$ln" ]; then echo "**ログに start が無い**"; else
  RUN="$(tail -n +"$ln" "$L" | awk '!s[$0]++')"
  echo "## 数"
  echo
  echo '```'
  printf '%s\n' "$RUN" | grep -E 'follow-balance start|実数（ヘッダー）|今回の上限|片思い:|守った内訳|外された:|外す候補 合計|reply-followers.json に反映|=== 外した' | cut -c1-220 | mask | sed 's/^/  /'
  n_reload="$(printf '%s\n' "$RUN" | grep -c 'ページが空。開き直す' | head -1)"
  n_nobtn="$(printf '%s\n' "$RUN" | grep -c 'フォロー中のボタンが無い' | head -1)"
  n_notf="$(printf '%s\n' "$RUN" | grep -c 'フォローしていない' | head -1)"
  echo
  printf '  開き直した: %s 件 ／ ボタンが無かった: %s 件 ／ そもそも未フォロー: %s 件\n' "${n_reload:-0}" "${n_nobtn:-0}" "${n_notf:-0}"
  if printf '%s\n' "$RUN" | grep -q '=== 外した'; then echo "  **この実行は終わっている**"; else echo "  **まだ終わっていない（外した件数の行が無い）**"; fi
  echo '```'
  echo
  echo "## 今回の実行のログ（重複を除いた末尾 40 行）"
  echo
  echo '```'
  printf '%s\n' "$RUN" | tail -40 | cut -c1-200 | mask | sed 's/^/  /'
  echo '```'
fi
echo
echo "**外していない。フォローしていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q 'この実行は終わっている' "$OUT"; then echo "follow-balance の結果を読んだ / $(basename "$OUT")"
else echo "**まだ終わっていないか読めない** / $(basename "$OUT")"; fi
