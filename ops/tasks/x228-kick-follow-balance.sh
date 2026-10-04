#!/bin/bash
# **follow-balance を定時を待たずに 1 回 走らせ、x219 の修正で外せるようになったかを確かめる。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > いま 1 回走らせて確かめる
#
# x227 で「外されたら外し返す」「期日を過ぎたフォロバ無しを外す」を足した（2026-10-04「いま 1 回走らせて確かめる」）。定時（11:45 / 18:45）を待たずに
# `launchctl kickstart` で 1 回 走らせる。**外す数の上限は今までどおり（MAX_UNFOLLOW=20・比率で決まる）。設定は変えない。**
#
# follow-balance は 1 回 5〜6 分かかる（下調べを 4.7〜6.2 秒 × 40 件にしたぶん長い）。
# このタスクでは**走らせるだけ**にして、終わりを待たない（1 タスク 5 分以内・最上位ルール 15）。
# 結果は次のタスク（x229）でログから読む。
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

LABEL="ai.openclaw.follow-balance"
UIDN="$(id -u)"
L="$HOME/.openclaw/workspace/logs/follow-balance.log"
OUT="${OPS_REPORT_DIR:-/tmp}/kick-follow-balance-2.md"

{
echo "# follow-balance を 1 回 走らせる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo '```'
before="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null | awk -F'= ' '/^\truns =/{print $2; exit}')"
printf '  走らせる前の runs: %s\n' "${before:-?}"
printf '  ログの行数（前）: %s\n' "$(wc -l < "$L" 2>/dev/null | tr -d ' ')"
grep -c "x227" "$HOME/.openclaw/workspace/scripts/follow-balance.js" 2>/dev/null | head -1 | sed 's/^/  x227 の印: /'
launchctl kickstart "gui/$UIDN/$LABEL" 2>&1 | sed 's/^/  kickstart: /'
sleep 20
pr="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
printf '  20 秒後: state=%s runs=%s pid=%s\n' \
  "$(printf '%s' "$pr" | awk -F'= ' '/^\tstate =/{print $2; exit}')" \
  "$(printf '%s' "$pr" | awk -F'= ' '/^\truns =/{print $2; exit}')" \
  "$(printf '%s' "$pr" | awk -F'= ' '/^\tpid =/{print $2; exit}')"
echo
echo "  --- ログの末尾 6 行"
tail -6 "$L" 2>/dev/null | cut -c1-200 | sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#"/[A-Za-z0-9_]{2,15}"#"/<伏せ>"#g' | sed 's/^/  /'
echo '```'
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。結果は x229 で読む。**"
} > "$OUT" 2>&1

if grep -q 'state=running' "$OUT"; then echo "follow-balance を走らせた（実行中） / $(basename "$OUT")"
else echo "**走っているか分からない。レポートを確認すること** / $(basename "$OUT")"; fi
