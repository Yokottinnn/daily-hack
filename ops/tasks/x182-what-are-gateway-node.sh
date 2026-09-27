#!/bin/bash
# **`gateway` と `node` が何をするジョブかを読む。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# 期待されているのに載っていない。**放っておくと永久に警報が鳴り続ける。**
#
#   ops-watchdog の EXPECTED_JOBS に `ai.openclaw.gateway` と `ai.openclaw.node` が在る
#   heartbeat.json の jobs には**無い**。`unloaded` 側に在る
#
# **どちらかにしないと終わらない。**
#
#   重要なもの   → 載せ直す
#   不要なもの   → 期待一覧から外す（`.disabled` にリネームして警報を止める）
#
# **決めるには中身を知る必要がある。** 推測で消さない・推測で載せない。
#
# ## 何を出すか
#
#   ① plist の実体（`ProgramArguments` / 起動間隔 / ログの場所）
#   ② 動かすスクリプトの**先頭のコメント**（何をするジョブか、ふつう冒頭に書いてある）
#   ③ **最後に動いたのはいつか**（ログの更新時刻と末尾）
#   ④ LLM を呼ぶか（**載せ直すなら増額になるので先に知る**・最上位ルール 2-B）
#   ⑤ ほかのジョブから呼ばれていないか（依存の有無）
#
# ## やらないこと
#
# **載せない。消さない。リネームもしない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/gateway-node.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secret() { sed -E 's/(xox[abprs]-[A-Za-z0-9-]+)/<トークン伏せ>/g; s/([A-Za-z_]*(TOKEN|KEY|SECRET)[A-Za-z_]*[=:][[:space:]]*)[^ "]*/\1<伏せ>/g; s/(sk-ant-[A-Za-z0-9._-]+)/<伏せ>/g' ; }
clean() { hide | secret; }

# **`cnt -i` と呼ぶと `-i` がパターンになる**（x166 で踏んだ）。大小無視は別関数にする
cnt()  { c="$(grep -c  "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }
cntI() { c="$(grep -ci "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

{
echo "# gateway と node は何をするジョブか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **載せない。消さない。リネームもしない。** 読んで判断材料を出すだけ。"

for J in gateway node; do
  LABEL="ai.openclaw.$J"
  echo
  echo "## \`$J\`"
  echo
  echo '```'
  # 載っているか
  if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
    echo "  載っている（想定と違う）"
    launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | grep -E '^[[:space:]]+(state|runs) ' | sed 's/^/    /'
  else
    echo "  **載っていない**"
  fi
  # plist の在りか
  PL=""
  for cand in "$LA/$LABEL.plist" "$LA/$LABEL.plist.disabled"; do
    [ -f "$cand" ] && { PL="$cand"; break; }
  done
  if [ -z "$PL" ]; then
    echo "  **plist がどちらの名前でも無い** → 期待一覧から外すのが筋"
    ls -1 "$LA" 2>/dev/null | grep -i "$J" | sed 's/^/    /' || echo "    （それらしい plist も無い）"
  else
    printf '  plist: %s（%s bytes・更新 %s）\n' "$(basename "$PL")" \
      "$(wc -c < "$PL" | tr -d ' ')" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$PL" 2>/dev/null)"
    echo
    echo "  --- ProgramArguments ---"
    /usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$PL" 2>/dev/null | clean | sed 's/^/    /'
    echo "  --- 起動のしかた ---"
    for k in StartInterval StartCalendarInterval RunAtLoad KeepAlive; do
      v="$(/usr/libexec/PlistBuddy -c "Print :$k" "$PL" 2>/dev/null)"
      [ -n "$v" ] && printf '    %-22s %s\n' "$k" "$(printf '%s' "$v" | tr '\n' ' ' | cut -c1-80)"
    done
    echo "  --- EnvironmentVariables ---"
    /usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$PL" 2>/dev/null | clean | sed 's/^/    /' \
      || echo "    （無い）"
  fi
  echo '```'

  # 動かすスクリプトを探す
  echo
  echo "### 何をするジョブか（スクリプトの冒頭）"
  echo
  echo '```'
  SC=""
  if [ -n "$PL" ]; then
    # ProgramArguments の中から、実在するファイルを探す
    while IFS= read -r a || [ -n "$a" ]; do
      a="$(printf '%s' "$a" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      case "$a" in
        /*) [ -f "$a" ] && case "$a" in *.js|*.sh|*.mjs|*.cjs) SC="$a"; break ;; esac ;;
      esac
    done <<EOF
$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$PL" 2>/dev/null)
EOF
  fi
  # 見つからなければ名前で当たる
  if [ -z "$SC" ]; then
    for cand in "$S/$J.js" "$S/$J.sh" "$S/openclaw-$J.js" "$S/$J-daemon.js"; do
      [ -f "$cand" ] && { SC="$cand"; break; }
    done
  fi
  if [ -z "$SC" ]; then
    echo "  **動かすスクリプトが見つからない**"
    ls -1 "$S" 2>/dev/null | grep -i "^$J" | sed 's/^/    /' || echo "    （名前が似たものも無い）"
  else
    printf '  %s（%s 行・更新 %s）\n\n' "$(basename "$SC")" "$(wc -l < "$SC" | tr -d ' ')" \
      "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$SC" 2>/dev/null)"
    head -30 "$SC" 2>/dev/null | cut -c1-190 | clean | sed 's/^/    /'
    echo
    echo "  --- LLM を呼ぶか（**載せ直すなら増額になる**）---"
    printf '    anthropic %s / claude %s / openai %s / sk-ant %s / API_KEY %s\n' \
      "$(cntI 'anthropic' "$SC")" "$(cntI 'claude' "$SC")" "$(cntI 'openai' "$SC")" \
      "$(cnt 'sk-ant' "$SC")" "$(cnt 'API_KEY' "$SC")"
  fi
  echo '```'

  echo
  echo "### 最後に動いたのはいつか"
  echo
  echo '```'
  FOUND=""
  for f in "$L/$J.log" "$L/$J.out" "$L/$J.err" "$L/openclaw-$J.log"; do
    [ -f "$f" ] || continue
    FOUND="yes"
    printf '  %-26s 更新 %s / %s bytes\n' "$(basename "$f")" \
      "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)" "$(wc -c < "$f" | tr -d ' ')"
    tail -8 "$f" 2>/dev/null | cut -c1-180 | clean | sed 's/^/      /'
    echo
  done
  [ -z "$FOUND" ] && echo "  **ログが 1 本も無い（一度も動いていない可能性）**"
  echo '```'

  echo
  echo "### ほかから呼ばれていないか（**消す前に見る**）"
  echo
  echo '```'
  grep -l -F "$LABEL" "$S"/*.js "$S"/*.sh 2>/dev/null | sed 's|.*/|    |' || echo "    （どのスクリプトからも参照されていない）"
  echo '```'
done

echo
echo "---"
echo
echo "## 判断のしかた"
echo
echo "| 出方 | どうするか |"
echo "| --- | --- |"
echo "| plist が無い ／ ログが 1 本も無い | **期待一覧から外す。** 一度も動いていないものを警報の対象にしない |"
echo "| ログが在り、最近まで動いていた | **載せ直す。** 止まった理由を追う |"
echo "| LLM を呼ぶ | **載せ直しは増額。** 金額を出してから決める（最上位ルール 2-B） |"
echo "| ほかから参照されている | **消さない。** 依存が壊れる |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '判断のしかた' "$OUT" 2>/dev/null; then
  echo "gateway と node を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
