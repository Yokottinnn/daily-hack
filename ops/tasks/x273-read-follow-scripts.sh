#!/bin/bash
# **フォロー系スクリプトの全文を読む。何も変えない。費用 $0。**
#
# ## なぜ（2026-10-12）
#
#   利用者が「フォローを認証済みに寄せる」を選んだ（docs/growth-strategy.md）。直すのは 4 か所:
#   ① フォローの記録に verified を足す ② 競合の /verified_followers から取る
#   ③ hashtag-follow の枠を認証済みの的に回す（総量は増やさない）④ 認証済みの相互を mutual-prune から外す
#   **当て推量でパッチを書かない**（最上位ルール 20）ので、先に全文を読む。
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。** 1 分で終わる。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/follow-scripts.md"
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' -e 's#(xox[bpa]-)[A-Za-z0-9-]+#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(["'"'"'`])(?!heng_ji31590)([A-Za-z0-9_]{3,15})\1(?=\s*[,\]])/$1<伏せ>$1/g if /COMPETITORS|competitor/i; s/^(\s*\d+\s+\{?\s*(?:handle:\s*)?)(["'"'"'`])[A-Za-z0-9_]{3,15}\2/$1$2<伏せ>$2/'; }
{
echo "# フォロー系スクリプトの全文（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・何も変えていない）"
for f in competitor-follower-follow.js hashtag-follow.js follow-handle.js mutual-prune.js badge-followback.js; do
  P="$W/scripts/$f"
  echo; echo "## $f"; echo
  if [ ! -f "$P" ]; then echo "**無い**"; continue; fi
  echo '```javascript'
  printf '// %s 行\n' "$(wc -l < "$P" | tr -d ' ')"
  awk '{printf "%4d  %s\n", NR, $0}' "$P" | secrets | hide
  echo '```'
done
echo
echo "## competitor の一覧（件数だけ）"
echo
grep -n "COMPETITORS" "$W/scripts/competitor-follower-follow.js" | head -5 | secrets | hide
echo
echo "**何も変えていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "フォロー系スクリプトの全文を読んだ / $(basename "$OUT")"
