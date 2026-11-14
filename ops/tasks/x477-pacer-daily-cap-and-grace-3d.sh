#!/bin/bash
# x477（2026-11-14・$0）: X にスパム（プラットフォーム操作）のラベルが付いた（x476 で 8 日にフォロー 186・解除 141）。
# 利用者がダイアログで選んだ 2 つを入れる。
#   ① 外す猶予を 24 時間 → 3 日（利用者「7日経ってからはさすがにやりすぎなので…3日とかはどう？」）: follow-balance と mutual-prune の plist の GRACE_DAYS=3
#   ② 1 日の上限と深夜の停止（「再開に備えて、1 日の上限と深夜の停止を作っておく」）: ops/lib/x-action-pacer.cjs を置き直す
#      （フォロー 10・解除 10・いいね 40 / 24 時間、JST 0〜7 時はフォロー・解除・いいねを押さない。投稿は対象外）
# LLM を呼ばない。ジョブを止めない（走っている最中のものは触らずに次の周回で）。
set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
W="$HOME/.openclaw/workspace"; LIB="$W/lib"; LA="$HOME/Library/LaunchAgents"
PB=/usr/libexec/PlistBuddy; UIDN="$(id -u)"; STAMP="$(date +%Y%m%d-%H%M%S)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x477-pacer-daily-cap-and-grace-3d.md"
NEW=3
{
echo "# 1 日の上限・深夜の停止と、外す猶予 3 日（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① 間隔の決まり（x-action-pacer.cjs）を置き直す"; echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null
TMP="$LIB/.x477-x-action-pacer.cjs"
if git -C "$REPO" show "origin/main:ops/lib/x-action-pacer.cjs" > "$TMP" 2>/dev/null && [ -s "$TMP" ] && "$NODE_BIN" --check "$TMP" 2>/dev/null && grep -q 'const DAILY' "$TMP"; then
  [ -f "$LIB/x-action-pacer.cjs" ] && cp -p "$LIB/x-action-pacer.cjs" "$LIB/x-action-pacer.cjs.bak.$STAMP"
  mv "$TMP" "$LIB/x-action-pacer.cjs"; echo "置いた: $LIB/x-action-pacer.cjs（$(wc -c < "$LIB/x-action-pacer.cjs" | tr -d ' ') bytes・元は .bak.$STAMP）"
  "$NODE_BIN" "$LIB/x-action-pacer.cjs" status 2>&1
else
  rm -f "$TMP"; echo "**取れない／壊れている。置かない（いまのまま）**"
fi
echo '```'
for LABEL in ai.openclaw.follow-balance ai.openclaw.mutual-prune; do
  P="$LA/$LABEL.plist"
  echo; echo "## ② $LABEL の GRACE_DAYS を $NEW に"; echo '```'
  if [ ! -f "$P" ]; then echo "plist が無い: $P"; echo '```'; continue; fi
  BEFORE="$("$PB" -c "Print :EnvironmentVariables:GRACE_DAYS" "$P" 2>/dev/null)"
  echo "変える前: ${BEFORE:-（未設定）}"
  ST="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')"
  if [ "$ST" = "running" ]; then echo "**いま走っている。触らない**（次の周回でやり直す）"; echo '```'; continue; fi
  cp -p "$P" "$P.bak-x477"
  if [ -n "$BEFORE" ]; then "$PB" -c "Set :EnvironmentVariables:GRACE_DAYS $NEW" "$P"; else "$PB" -c "Add :EnvironmentVariables:GRACE_DAYS string $NEW" "$P"; fi
  if ! plutil -lint "$P" >/dev/null 2>&1; then cp -p "$P.bak-x477" "$P"; echo "**plutil が通らない。元に戻した**"; echo '```'; continue; fi
  launchctl bootout "gui/$UIDN/$LABEL" 2>/dev/null
  BS="$(launchctl bootstrap "gui/$UIDN" "$P" 2>&1)"; echo "bootstrap rc=$? $(printf '%s' "$BS" | cut -c1-100)"
  PR="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
  if [ -z "$PR" ]; then echo "**載っていない**"; else echo "載っている ← launchd が持っている値:"; printf '%s\n' "$PR" | grep -aE 'GRACE_DAYS' | sed 's/^/  /'; fi
  echo '```'
done
} > "$OUT" 2>&1
grep -E '置いた|GRACE_DAYS =>|走っている|載っていない|取れない' "$OUT" | head -5 | cut -c1-140
exit 0
