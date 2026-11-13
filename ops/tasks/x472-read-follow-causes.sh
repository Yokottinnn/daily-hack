#!/bin/bash
# x472（2026-11-13・読むだけ・$0）: ①フォロー比率が下がらない（follow-balance が 3 件しか外せない）②competitor-follower-follow が 8 人中 0 人
# の原因を読む。直近 2 日の回の全行と、判定しているコードの箇所を出す。何も変えない。LLM を呼ばない。ハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/x472-read-follow-causes.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#"path":"/[A-Za-z0-9_]+"#"path":"/<伏せ>"#g; s#x\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#x.com/<伏せ>#g'; }
{
echo "# フォローの原因を読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 1. follow-balance の直近 2 日（要約の行）"; echo '```'
grep -hE '^\[2026-11-1[23]T' "$L/follow-balance.log" 2>/dev/null | awk '!s[$0]++' | grep -E 'start|フォロー中:|実数|=== 外した|空で' | cut -c1-220 | hide
echo '```'
echo; echo "## 2. follow-balance の最後の回（全行・末尾 80 行）"; echo '```'
LAST="$(grep -nE '=== follow-balance start' "$L/follow-balance.log" 2>/dev/null | tail -1 | cut -d: -f1)"
[ -n "$LAST" ] && tail -n +"$LAST" "$L/follow-balance.log" | head -80 | cut -c1-240 | hide
echo '```'
echo; echo "## 3. follow-balance の『未フォロー』の判定（コード）"; echo '```'
F="$S/follow-balance.js"; ls -l "$F" 2>&1 | awk '{print $5, $6, $7, $8}'
grep -nE '未フォロー|notFollowing|not_following|follow_btns|フォロー中のボタン|unfollowBtn|data-testid' "$F" 2>/dev/null | head -40 | cut -c1-220
echo '```'
echo; echo "## 4. competitor-follower-follow の直近 2 日（全行）"; echo '```'
grep -hE '^\[2026-11-1[123]T' "$L/competitor-follower-follow.log" 2>/dev/null | awk '!s[$0]++' | tail -80 | cut -c1-240 | hide
echo '```'
echo; echo "## 5. competitor-follower-follow の判定（コード）"; echo '```'
F2="$(ls "$S"/competitor-follower-follow*.js 2>/dev/null | head -1)"; echo "${F2:-（見つからない）}"
[ -n "$F2" ] && grep -nE 'OK|skip|SKIP|reason|filter|verified|ratio|bio|ng|follow_btns|data-testid' "$F2" | head -50 | cut -c1-220
echo '```'
} > "$OUT" 2>&1
grep -E '=== 外した|=== end' "$OUT" | tail -3 | cut -c1-160
exit 0
