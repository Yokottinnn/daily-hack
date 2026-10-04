#!/bin/bash
# **follow-balance の「フォロバを待つ猶予」を 7 日 → 1 日（24 時間）に戻し、その場で 1 回 走らせる。費用 $0。**
#
# ## 指示（2026-10-04 14 時台）
#
#   > 待て、いまって7日間フォローバックがなかったときのみフォローを外すようにしている？
#   > そんなルール決めてないけど。前に変更してって言ったよね？これは大問題だよ
#   > もっと期間を短くして　すぐに対応して
#
# **決めてあったのは 24 時間。** `docs/x-engagement-loop.md`「待つ期間 24 時間」、
# `ops/tasks/020-finish-loops.sh`「Jordan の指定は『24 時間でフォローバックが無ければアンフォロー』」。
# follow-balance.js は `GRACE_DAYS` の既定が 7 で、plist に値が無いため 7 日のまま動いていた
# （x229: 片思い 73 件 のうち猶予で守られて外せたのは 1 件）。
#
# ## 何をするか
#
#   ① いまの plist の GRACE_DAYS を読む（変える前を残す）
#   ② PlistBuddy で GRACE_DAYS=1 を書く（`sed -i` は使わない・最上位ルール 14）
#   ③ bootout → bootstrap（`load` は rc=0 でも載らない・最上位ルール 13）
#   ④ **`launchctl print` の environment に GRACE_DAYS=1 が出ること**を確かめる
#   ⑤ その場で kickstart（18:45 を待たない・最上位ルール 9）。最大 240 秒 見て、外した件数を出す
#
# **触るのは GRACE_DAYS だけ。** 1 回に外す上限（20 件・1 日 2 回）、ホワイトリスト、
# 比率の帯（0.45〜0.65）は変えない。mutual-prune（相互の見直し）の猶予 14 日 も触らない。
#
# ## 費用（最上位ルール 2-B）
#
# **follow-balance.js は LLM を呼ばない。DOM を読んで押すだけ。**
#   1 回あたり $0 ／ 1 日あたり $0（11:45 / 18:45）／ 1 か月あたり $0
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
LABEL="ai.openclaw.follow-balance"
P="$LA/$LABEL.plist"
PB="/usr/libexec/PlistBuddy"
LOG="$W/logs/follow-balance.log"
NEW=1
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-grace-24h.md"
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#"/[A-Za-z0-9_]{2,15}"#"/<伏せ>"#g'; }
env_of() { "$PB" -c "Print :EnvironmentVariables:$1" "$P" 2>/dev/null | tr -d ' \n'; }

{
echo "# follow-balance の猶予を 7 日 → 1 日（24 時間）に戻す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "## 1. 変える前"
echo
echo '```'
if [ ! -f "$P" ]; then echo "  **plist が無い: $P**。当て推量で作らない"; echo '```'; exit 1; fi
st="$(launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')"
printf '  GRACE_DAYS（plist）: %s\n' "$(env_of GRACE_DAYS | grep . || echo '（未設定 → スクリプトの既定 7）')"
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
printf '%s\n' "$PR" | grep -aE 'GRACE_DAYS|MIN_UNFOLLOW|MAX_UNFOLLOW|LIST_BUDGET_S|DECIDE_BUDGET_S' | sed 's/^/    /'
GOK=0; printf '%s\n' "$PR" | grep -aqE 'GRACE_DAYS => 1$|"GRACE_DAYS" => "1"|GRACE_DAYS => "1"' && GOK=1
echo '```'
echo
echo "## 4. その場で 1 回 走らせる（18:45 を待たない）"
echo
echo '```'
OFF=0; [ -f "$LOG" ] && OFF="$(wc -c < "$LOG" | tr -d ' ')"
KS="$(launchctl kickstart "gui/$UID_N/$LABEL" 2>&1)"; KRC=$?
printf '  kickstart rc=%s %s\n' "$KRC" "$(printf '%s' "$KS" | cut -c1-120)"
W0=0; DONE=0
while [ "$W0" -lt 240 ]; do
  sleep 5; W0=$((W0 + 5))
  if tail -c "+$((OFF + 1))" "$LOG" 2>/dev/null | tr -d '\000' | grep -aq '=== 外した:'; then DONE=1; break; fi
done
printf '  見ていた秒数 %s %s\n' "$W0" "$( [ "$DONE" = "1" ] && echo '← 終わった' || echo '← **240 秒 で見るのをやめた。走り続けている**（x232 で読む）' )"
echo
tail -c "+$((OFF + 1))" "$LOG" 2>/dev/null | tr -d '\000' | awk '!s[$0]++' \
  | grep -aE 'follow-balance start|実数（ヘッダー）|今回の上限|片思い:|外された:|守った内訳|外す候補 合計|✂|フォローしていない|ボタンが無い|ページが空|reply-followers.json に反映|=== 外した' \
  | cut -c1-200 | hide | sed 's/^/  /'
echo '```'
echo
if [ "$GOK" = "1" ]; then echo "- **launchd が GRACE_DAYS=1 を持っている。** 以後の 11:45 / 18:45 も 24 時間で判定する"
else echo "- **launchd の値に GRACE_DAYS=1 が見えない。** 上の表示を確かめること"; fi
echo "- 1 回に外すのは今までどおり 20 件まで（1 日 2 回）。比率の帯・ホワイトリストは変えていない"
echo "- 戻すときは plist の GRACE_DAYS を消して bootout → bootstrap"
echo
echo "**フォローしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q 'launchd が GRACE_DAYS=1 を持っている' "$OUT"; then echo "follow-balance の猶予を 24 時間に戻して走らせた / $(basename "$OUT")"
else echo "**猶予を戻せていない** / $(basename "$OUT")"; exit 1; fi
