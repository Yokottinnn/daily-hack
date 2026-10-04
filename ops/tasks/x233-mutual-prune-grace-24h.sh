#!/bin/bash
# **mutual-prune（相互の見直し）の猶予を 14 日 → 1 日（24 時間）にする。走らせない。費用 $0。**
#
# ## 指示（2026-10-04 14 時台）
#
#   > 待て、いまって7日間フォローバックがなかったときのみフォローを外すようにしている？
#   > そんなルール決めてないけど。前に変更してって言ったよね？これは大問題だよ
#   → 相互（休眠 30 日 以上・小さいアカウント）を外す mutual-prune の「フォローから 14 日 は外さない」も、
#     利用者が決めた値ではなかった。ダイアログで「相互の猶予 14 日も 24 時間にそろえる」を選んでもらった
#
# **触るのは GRACE_DAYS だけ。** 休眠 30 日・小さいアカウントの基準・1 回 8 件・6:00 / 18:00 は変えない。
# **走らせない**（「すぐ走らせる」は選ばれていない）。次の 18:00 から効く。
#
# 費用: mutual-prune.js は LLM を呼ばない。1 回 $0 ／ 1 日 $0 ／ 1 か月 $0
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
LABEL="ai.openclaw.mutual-prune"
P="$LA/$LABEL.plist"
PB="/usr/libexec/PlistBuddy"
NEW=1
OUT="${OPS_REPORT_DIR:-/tmp}/mutual-prune-grace-24h.md"
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#"/[A-Za-z0-9_]{2,15}"#"/<伏せ>"#g'; }
env_of() { "$PB" -c "Print :EnvironmentVariables:$1" "$P" 2>/dev/null | tr -d ' \n'; }

{
echo "# mutual-prune の猶予を 14 日 → 1 日（24 時間）にする（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "## 1. 変える前"
echo
echo '```'
if [ ! -f "$P" ]; then echo "  **plist が無い: $P**。当て推量で作らない"; echo '```'; exit 1; fi
st="$(launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')"
printf '  GRACE_DAYS（plist）: %s\n' "$(env_of GRACE_DAYS | grep . || echo '（未設定）')"
printf '  いまの状態: %s\n' "${st:-（載っていない）}"
if [ "$st" = "running" ]; then echo "  **いま走っている。止めずに、ここで終える**（次の周回でやり直す）"; echo '```'; exit 1; fi
echo '```'
echo
echo "## 2. 書き換える"
echo
echo '```'
if "$PB" -c "Print :EnvironmentVariables:GRACE_DAYS" "$P" >/dev/null 2>&1; then
  R="$("$PB" -c "Set :EnvironmentVariables:GRACE_DAYS $NEW" "$P" 2>&1)"; RC=$?
else
  R="$("$PB" -c "Add :EnvironmentVariables:GRACE_DAYS string $NEW" "$P" 2>&1)"; RC=$?
fi
printf '  GRACE_DAYS rc=%s %s → ファイル上の値 %s\n' "$RC" "$(printf '%s' "$R" | cut -c1-80)" "$(env_of GRACE_DAYS)"
if ! plutil -lint "$P" >/dev/null 2>&1; then echo "  **plutil -lint が通らない。載せ直さない**"; echo '```'; exit 1; fi
echo "  plutil -lint → OK"
echo '```'
echo
echo "## 3. 載せ直す（bootout → bootstrap）"
echo
echo '```'
launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
BS="$(launchctl bootstrap "gui/$UID_N" "$P" 2>&1)"; BRC=$?
printf '  bootstrap rc=%s %s\n' "$BRC" "$(printf '%s' "$BS" | cut -c1-120)"
PR="$(launchctl print "gui/$UID_N/$LABEL" 2>/dev/null)"
if [ -z "$PR" ]; then echo "  **載っていない**"; echo '```'; exit 1; fi
echo "  → 載っている"
echo "  --- launchd が持っている値（← これが証拠）---"
printf '%s\n' "$PR" | grep -aE 'GRACE_DAYS|MAX_UNFOLLOW|INACTIVE_DAYS|RATIO|ABS_MIN' | sed 's/^/    /'
GOK=0; printf '%s\n' "$PR" | grep -aqE 'GRACE_DAYS => 1$|"GRACE_DAYS" => "1"|GRACE_DAYS => "1"' && GOK=1
echo '```'
echo
if [ "$GOK" = "1" ]; then echo "- **launchd が GRACE_DAYS=1 を持っている。** 次の 18:00 から 24 時間で判定する（走らせていない）"
else echo "- **launchd の値に GRACE_DAYS=1 が見えない。** 上の表示を確かめること"; fi
echo "- 1 回 8 件・休眠 30 日・小さいアカウントの基準は変えていない"
echo "- 戻すときは plist の GRACE_DAYS を 14 にして bootout → bootstrap"
echo
echo "**外していない。フォローしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q 'launchd が GRACE_DAYS=1 を持っている' "$OUT"; then echo "mutual-prune の猶予を 24 時間にした / $(basename "$OUT")"
else echo "**猶予を戻せていない** / $(basename "$OUT")"; exit 1; fi
