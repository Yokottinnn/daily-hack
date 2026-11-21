#!/bin/bash
# x531（2026-11-21・$0）: フォロー先を返してくれる相手に寄せる（利用者がダイアログで「返してくれる相手に寄せる」を選んだ）。
#  フォロー返しの率（heartbeat の followback_bands）: 相手のフォロワー 100〜299 人 19.5%・1,000〜4,999 人 15.2%・5,000〜49,999 人 5.9%。
#  follow-handle.js は相手のフォロワーが 50,000 人まで通していた（上限が書き込み）。環境変数 FOLLOW_MAX_FOLLOWERS で上限を変えられるようにし（無ければ今までどおり 50000）、
#  競合のフォロワー・ハッシュタグのフォローの plist に FOLLOW_MAX_FOLLOWERS=4999 を入れる。件数（1 日の頭打ち）・間隔の決まりは変えない。
#  元に戻すとき: follow-handle.js は .bak-x531、plist は .bak-x531
# LLM を呼ばない。走っている最中のジョブは触らない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"; PB=/usr/libexec/PlistBuddy; UIDN="$(id -u)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x531-follow-max-followers.md"
F="$S/follow-handle.js"
{
echo "# フォロー先の上限を相手のフォロワー 4,999 人に（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① follow-handle.js"; echo '```'
OLD='if (follower_count < minFollowers || follower_count > 50000) {'
if grep -qF 'FOLLOW_MAX_FOLLOWERS' "$F"; then echo "もう入っている（触らない）"; PATCHED=1
elif [ "$(grep -cF "$OLD" "$F")" = "1" ]; then
  cp -p "$F" "$F.bak-x531"
  TMP="$S/.x531-follow-handle.js"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,t]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
s=s.replace("if (follower_count < minFollowers || follower_count > 50000) {","const maxFollowers = Number(process.env.FOLLOW_MAX_FOLLOWERS || 50000); // 2026-11-21 x531: フォロー返しの率が低い大きいアカウントを外す\n  if (follower_count < minFollowers || follower_count > maxFollowers) {");
s=s.replace("need ${minFollowers}-50000)","need ${minFollowers}-${maxFollowers})");
fs.writeFileSync(t,s);' "$F" "$TMP"
  if "$NODE_BIN" --check "$TMP" 2>/dev/null && grep -qF 'maxFollowers' "$TMP"; then mv "$TMP" "$F"; PATCHED=1; echo "書き換えた（元は .bak-x531）"; grep -nE 'maxFollowers' "$F" | cut -c1-180
  else rm -f "$TMP"; PATCHED=0; echo "**書き換えた版が node --check を通らない。触らない**"; fi
else PATCHED=0; echo "**書き換える行が 1 か所に決まらない（$(grep -cF "$OLD" "$F") か所）。触らない**"; fi
echo '```'
[ "$PATCHED" = "1" ] || { echo "**① ができなかったので ② はしない**"; exit 0; }
echo; echo "## ② plist に FOLLOW_MAX_FOLLOWERS=4999"
for n in competitor-follower-follow hashtag-follow; do
  LABEL="ai.openclaw.$n"; P="$LA/$LABEL.plist"; echo; echo "### $n"; echo '```'
  [ -f "$P" ] || { echo "plist が無い"; echo '```'; continue; }
  ST="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')"
  if [ "$ST" = "running" ]; then echo "**いま走っている。触らない**（次の周回でやり直す）"; echo '```'; continue; fi
  cp -p "$P" "$P.bak-x531"
  "$PB" -c "Set :EnvironmentVariables:FOLLOW_MAX_FOLLOWERS 4999" "$P" 2>/dev/null || "$PB" -c "Add :EnvironmentVariables:FOLLOW_MAX_FOLLOWERS string 4999" "$P"
  if ! plutil -lint "$P" >/dev/null 2>&1; then cp -p "$P.bak-x531" "$P"; echo "**plutil が通らない。元に戻した**"; echo '```'; continue; fi
  launchctl bootout "gui/$UIDN/$LABEL" 2>/dev/null; launchctl bootstrap "gui/$UIDN" "$P" 2>&1 | head -1
  PR="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
  if [ -z "$PR" ]; then echo "**載っていない**"; else echo "載っている ← launchd が持っている値:"; printf '%s\n' "$PR" | grep -aE 'FOLLOW_MAX_FOLLOWERS|FOLLOW_MIN_RATIO|DAILY_CAP' | sed 's/^[[:space:]]*/  /'; fi
  echo '```'
done
echo; echo "**誰もフォローしていない（次の周回から効く）。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '書き換えた|載っている ←|触らない|載っていない' "$OUT" | head -5 | cut -c1-140
exit 0
