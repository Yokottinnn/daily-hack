#!/bin/bash
# **外す上限を 8 → 20 に上げて、その場で 1 回 走らせる。費用 $0。**
#
# ## 指示（2026-09-28 23 時台）
#
# 「アンフォローうまく動いてる？」への報告のあと、ダイアログで **「上限 8 件 を上げる」** を選択。
#
# ## いま何が起きているか（一次情報）
#
#   11:45 と 18:45 の定期実行が両方 走った（`x190` で確認）
#   18:45  === 外した: 5 件 / 候補 8 件（今日のフォロー 2 件） / 一覧に混ざっていた未フォロー 3 件 ===
#   状態ファイル 25 件 / 覚えた未フォロー 8 件
#
# **候補 8 件 は上限に当たった数であって、片思いが 8 人 しか居ないという意味ではない。**
# `quota = min(MAX, max(MIN, 今日のフォロー数))` で、いま `MIN=MAX=8` なので常に 8 になる。
#
# ## いくつにするか
#
#   MIN_UNFOLLOW  8 → **20**
#   MAX_UNFOLLOW  8 → **20**      （1 日 2 回 なので **上限 40 件/日**）
#
# **これは上限であって予想ではない**（最上位ルール 2-B）。18:45 の実績は
# 候補 8 件 に対して **外れたのは 5 件**（62%）なので、20 なら **12〜13 件/回** が見込み。
#
# **20 を超えて上げない理由。** ① 片思いを使い切ると ② 相互を見に行く段に入る。
# 相互は「休眠 30 日 以上」か「5000 フォロワー 以上」しか切らない作りだが、
# **フォロー側の実績は今日 2 件**（上限 30/90 は天井であって実績ではない）。
# 外す側だけ大きく上げると、フォロー中が一方的に減る。まず 20 で様子を見る。
#
# ## 何をするか
#
#   ① いまの plist の値を読む（**変える前を残す**）
#   ② PlistBuddy で 2 つの値だけ書き換える（**`sed -i` は使わない**・最上位ルール 14）
#   ③ `bootout` → `bootstrap`（**`load` は rc=0 でも載らない**・最上位ルール 13）
#   ④ **`launchctl print` の environment に 20 が出ることを確かめる**
#      ← plist ファイルを読み直すだけでは「launchd が持っている値」の証拠にならない
#   ⑤ **その場で 1 回 kickstart する**（明日 11:45 を待たない・最上位ルール 9）
#   ⑥ ログの増えた分だけを読んで、上限 20 で動いたかを出す
#
# ## 時間（最上位ルール 15）
#
#   ①〜④  約 10 秒
#   ⑤⑥    **最大 210 秒 で見るのをやめる**（ジョブは launchd が持っているので走り続ける）
#   合計   **4 分 以内**
#
# ## 費用（最上位ルール 2-B）
#
# **`follow-balance.js` は LLM を呼ばない。DOM を読んで押すだけ。**
#
#   1 回あたり   **$0**
#   1 日あたり   **$0**（11:45 / 18:45 の 2 回）
#   1 か月あたり **$0**
#
# **上限を 8 → 20 に上げても $0 のまま。** 増額にならない。
set -uo pipefail

W="$HOME/.openclaw/workspace"
L="$W/logs"
D="$W/data"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
LABEL="ai.openclaw.follow-balance"
P="$LA/$LABEL.plist"
PB="/usr/libexec/PlistBuddy"
LOG="$L/follow-balance.log"
ST="$D/follow-balance-state.json"
NF="$D/follow-balance-notfollowing.json"
NEW=20
OUT="${OPS_REPORT_DIR:-/tmp}/raise-unfollow-cap.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

jn() {
  node -e '
    const fs = require("fs");
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { process.stdout.write("0"); process.exit(0); }
    process.stdout.write(String(Array.isArray(j) ? j.length : Object.keys(j || {}).length));
  ' "$1" 2>/dev/null
}

env_of() { "$PB" -c "Print :EnvironmentVariables:$1" "$P" 2>/dev/null | tr -d ' \n'; }

{
echo "# 外す上限を 8 → $NEW に上げる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **上限であって予想ではない。** 18:45 の実績は候補 8 件 に対して外れたのは **5 件**。"
echo "> **LLM を呼ばない（\$0／回・\$0／日・\$0／月）。上げても \$0 のまま。**"

echo
echo "## 1. 変える前"
echo
echo '```'
if [ ! -f "$P" ]; then
  echo "  **plist が無い: $P**"
  echo "  --- LaunchAgents に在る follow 系 ---"
  ls -1 "$LA" 2>/dev/null | grep -i follow | sed 's/^/    /' || echo "    （無し）"
  echo '```'
  echo
  echo "**当て推量で作らない。\`x183\` を読み直して置き直すこと。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
OLD_MIN="$(env_of MIN_UNFOLLOW)"
OLD_MAX="$(env_of MAX_UNFOLLOW)"
printf '  MIN_UNFOLLOW  %s\n' "${OLD_MIN:-（未設定）}"
printf '  MAX_UNFOLLOW  %s\n' "${OLD_MAX:-（未設定）}"
printf '  外した記録        %s 件\n' "$(jn "$ST")"
printf '  覚えた未フォロー  %s 件\n' "$(jn "$NF")"
echo '```'

echo
echo "## 2. 書き換える（**\`sed -i\` は使わない**）"
echo
echo '```'
for k in MIN_UNFOLLOW MAX_UNFOLLOW; do
  if "$PB" -c "Print :EnvironmentVariables:$k" "$P" >/dev/null 2>&1; then
    R="$("$PB" -c "Set :EnvironmentVariables:$k $NEW" "$P" 2>&1)"; RC=$?
  else
    R="$("$PB" -c "Add :EnvironmentVariables:$k string $NEW" "$P" 2>&1)"; RC=$?
  fi
  printf '  %-14s rc=%s %s\n' "$k" "$RC" "$(printf '%s' "$R" | cut -c1-80)"
done
echo
echo "  --- ファイルを読み直す ---"
printf '    MIN_UNFOLLOW  %s\n' "$(env_of MIN_UNFOLLOW)"
printf '    MAX_UNFOLLOW  %s\n' "$(env_of MAX_UNFOLLOW)"
echo
echo "  --- plist が壊れていないか ---"
if plutil -lint "$P" >/dev/null 2>&1; then
  echo "    plutil -lint → OK"
else
  echo "    **plutil -lint が通らない。載せ直さない。**"
  plutil -lint "$P" 2>&1 | cut -c1-160 | sed 's/^/      /'
  echo '```'
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'

echo
echo "## 3. 載せ直す（**\`load\` ではなく \`bootout\` → \`bootstrap\`**）"
echo
echo "**launchd は bootstrap した時点の環境変数を持つ。** ファイルを直しただけでは効かない。"
echo
echo '```'
launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
BS="$(launchctl bootstrap "gui/$UID_N" "$P" 2>&1)"; BRC=$?
printf '  bootstrap rc=%s %s\n' "$BRC" "$(printf '%s' "$BS" | cut -c1-120)"
echo "  （**rc=5 Input/output error は「もう載っている」の出方**・最上位ルール 13）"
echo
echo "  --- 載ったことの証拠 ---"
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
    | grep -aE '^[[:space:]]+(state|runs|path|program|last exit code) ' | sed 's/^/    /'
  echo "    → **載っている**"
else
  echo "    → **載っていない**"
  printf '%s\n' "$BS" | cut -c1-200 | sed 's/^/      /'
fi
echo
echo "  --- **launchd が持っている値**（← ここが本当の証拠）---"
launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
  | grep -aE 'MIN_UNFOLLOW|MAX_UNFOLLOW|LIST_BUDGET_S|DECIDE_BUDGET_S|MAX_PROFILE_READS' \
  | sed 's/^/    /'
echo '```'

echo
echo "## 4. その場で 1 回 走らせる（**明日 11:45 を待たない**）"
echo
echo "\`kickstart\` はすぐ返る。**ジョブは launchd が持っているので、"
echo "このタスクが見るのをやめても走り続ける。**"
echo
echo '```'
OFF=0
[ -f "$LOG" ] && OFF="$(wc -c < "$LOG" | tr -d ' ')"
S0="$(jn "$ST")"
KS="$(launchctl kickstart -k "gui/$UID_N/$LABEL" 2>&1)"; KRC=$?
printf '  kickstart rc=%s %s\n' "$KRC" "$(printf '%s' "$KS" | cut -c1-120)"
echo "  （**rc=0 は「やった」証拠にならない**。下のログで確かめる）"
echo
W0=0
DONE=0
while [ "$W0" -lt 210 ]; do
  sleep 3
  W0=$((W0 + 3))
  NB="$(tail -c "+$((OFF + 1))" "$LOG" 2>/dev/null | tr -d '\000')"
  if printf '%s' "$NB" | grep -aq '=== 外した:'; then DONE=1; break; fi
  if printf '%s' "$NB" | grep -aq 'DRY_RUN。1 件も外していない'; then DONE=1; break; fi
done
printf '  見ていた秒数 %s %s\n' "$W0" \
  "$( [ "$DONE" = "1" ] && echo '← **終わりの行が出た**' || echo '← **210 秒 で見るのをやめた。走り続けている**' )"
echo
echo "  --- 上限の行（**20 になっているか**）---"
tail -c "+$((OFF + 1))" "$LOG" 2>/dev/null | tr -d '\000' \
  | grep -aE '今回の上限|follow-balance start' | tail -4 | cut -c1-200 | clean | sed 's/^/    /'
echo
echo "  --- 増えた分 全部（**絞り込まない**）---"
tail -c "+$((OFF + 1))" "$LOG" 2>/dev/null | tr -d '\000' | tail -45 | cut -c1-240 | clean | sed 's/^/    /'
echo '```'

echo
echo "## 5. 結果"
echo
echo '```'
S1="$(jn "$ST")"
printf '  外した記録: %s → %s 件（差 **%s**）← **実際に外した数**\n' "$S0" "$S1" "$((S1 - S0))"
printf '  覚えた未フォロー: %s 件\n' "$(jn "$NF")"
echo
printf '  MIN_UNFOLLOW  %s → %s\n' "${OLD_MIN:-?}" "$(env_of MIN_UNFOLLOW)"
printf '  MAX_UNFOLLOW  %s → %s\n' "${OLD_MAX:-?}" "$(env_of MAX_UNFOLLOW)"
printf '  1 日あたりの上限  %s 件 → **%s 件**（11:45 と 18:45 の 2 回）\n' \
  "$(( ${OLD_MAX:-8} * 2 ))" "$((NEW * 2))"
echo '```'
echo
echo "**\`差\` が \`$((NEW))\` より小さいのは正常。** 一覧に混ざった未フォローと、"
echo "ホワイトリスト・猶予で守った分がある。18:45 は候補 8 件 で **外れたのは 5 件**。"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §4 の出方 | 意味 | 次 |"
echo "| --- | --- | --- |"
echo "| \`今回の上限 $NEW 件\` が出た | **効いている** | このまま毎日 回す |"
echo "| \`今回の上限 8 件\` のまま | **launchd が古い環境を持っている** | §3 の bootout が効いていない |"
echo "| 210 秒 で終わらなかった | 走り続けている | **次のタスクでログを読む**（止まってはいない） |"
echo "| \`候補\` が $NEW より大幅に少ない | **片思いを使い切った** | 上限をこれ以上 上げても増えない |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。上限を上げても \$0 のまま。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -aq 'launchd が持っている値' "$OUT" 2>/dev/null; then
  echo "外す上限を $NEW に上げた / $(basename "$OUT")"
else
  echo "**上げられていない。レポートを確認すること** / $(basename "$OUT")"
fi
