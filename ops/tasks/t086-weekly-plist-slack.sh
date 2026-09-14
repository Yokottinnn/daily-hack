#!/bin/bash
# **週次レポートの plist に `--slack` を足す。**（t085 が通っていれば）
#
# ## なぜ必要か（**私が作った問題**）
#
# t084 で入れた 811 行版は、**`--slack` を付けないと Slack へ投稿しない。**
#
#     plist: ["/opt/homebrew/bin/python3.11", "/Users/ny/scripts/weekly-blog-report.py"]
#                                              ^ 引数なし
#
# **このままだと次の月曜、レポートが Slack に出ない。** 入れ替えた私の責任で直す。
#
# ## 所有権について
#
# plist は原則 tweet2 の所有（docs/session-roles.md）。ただし
# `com.dailyhack.weekly-blog-report` は **ブログのレポートのジョブ**であり、
# **壊したのはこちら**なので直す。`docs/cross-session-requests.md` に記録を残す。
# **他の plist には一切 触らない。**
#
# ## 安全側
#
# - **`launchctl load` は使わない。** rc=0 でも載らない（最上位ルール 13）。
#   `bootout` → `bootstrap` を使い、**`launchctl list` で載ったことを確かめる**
# - plist は**日付つきで退避**してから書き換える
# - **`plutil` で構造を読み書きする。** XML を sed で書き換えない
# - t085 の marker が無ければ**何もしない**（空のレポートを Slack に出さないため）
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t086-weekly-plist-slack.md"
mkdir -p "$RDIR"
MARKER="$HOME/.config/daily-hack/weekly-report-ok"
LABEL="com.dailyhack.weekly-blog-report"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

{
  echo "# 週次レポートの plist に --slack を足す（t086）"
  echo
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo
} > "$OUT"

if [ ! -f "$MARKER" ]; then
  {
    echo "🚨 **t085 の marker が無い。何もしない。**"
    echo
    echo "新しい版がレポートを生成できていないので、\`--slack\` を足すと"
    echo "空のレポートが Slack に出る。先に t085 の結果を見ること。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi

if [ ! -f "$PLIST" ]; then
  echo "🚨 \`$PLIST\` が無い。何もしない。" >> "$OUT"
  cat "$OUT"; exit 0
fi

before="$(plutil -extract ProgramArguments json -o - "$PLIST" 2>/dev/null)"
{
  echo "## 着手前"
  echo
  echo '```'
  echo "$before"
  echo '```'
  echo
} >> "$OUT"

case "$before" in
  *--slack*)
    echo "✅ **すでに \`--slack\` が入っている。何もしない。**" >> "$OUT"
    cat "$OUT"; exit 0
    ;;
esac

BAK="$PLIST.bak-$(date '+%Y%m%d-%H%M%S')"
cp "$PLIST" "$BAK"

# **配列そのものを差し替える。** XML を sed で書き換えない（macOS の sed は -i '' が要る）。
# **要素数を plutil に尋ねない。** `-extract ... raw` が配列で何を返すかは環境依存で、
# 当て推量になる。すでに JSON で読めている `$before` に足して `-replace` で戻す。
NEWARGS="$(printf '%s' "$before" | python3 -c '
import json, sys
a = json.load(sys.stdin)
if "--slack" not in a:
    a.append("--slack")
print(json.dumps(a))
' 2>/dev/null)"

if [ -z "$NEWARGS" ]; then
  echo "🚨 **新しい引数列を組み立てられなかった。何もしない。**" >> "$OUT"
  cp "$BAK" "$PLIST"
  cat "$OUT"; exit 0
fi

plutil -replace ProgramArguments -json "$NEWARGS" "$PLIST" 2>/dev/null
ins_rc=$?

after="$(plutil -extract ProgramArguments json -o - "$PLIST" 2>/dev/null)"
{
  echo "## 書き換えた"
  echo
  echo "- 退避: \`$BAK\`"
  echo "- \`plutil -insert\` の rc: $ins_rc"
  echo
  echo '```'
  echo "$after"
  echo '```'
  echo
} >> "$OUT"

case "$after" in
  *--slack*) ;;
  *)
    {
      echo "🚨 **\`--slack\` が入らなかった。退避から戻す。**"
    } >> "$OUT"
    cp "$BAK" "$PLIST"
    cat "$OUT"; exit 0
    ;;
esac

if ! plutil -lint "$PLIST" >/dev/null 2>&1; then
  echo "🚨 **plist が壊れた。退避から戻す。**" >> "$OUT"
  cp "$BAK" "$PLIST"
  cat "$OUT"; exit 0
fi

# **load ではなく bootout → bootstrap**（最上位ルール 13）
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1
bs_rc=$?

{
  echo "## 読み直した"
  echo
  echo "- \`bootstrap\` の rc: $bs_rc"
  echo
  echo "### **これが証拠**（rc ではなく状態を見る・ルール 13）"
  echo
  echo '```'
  launchctl list 2>/dev/null | grep -F "$LABEL" || echo "(launchctl list に出てこない)"
  echo '```'
  echo
} >> "$OUT"

if launchctl list 2>/dev/null | grep -qF "$LABEL"; then
  echo "✅ **載っている。** 次の月曜 08:00 に \`--slack\` 付きで走る。" >> "$OUT"
else
  echo "🚨 **載っていない。** plist は直っているが、ジョブが読み込まれていない。" >> "$OUT"
fi

{
  echo
  echo "## 次の月曜に見ること"
  echo
  echo "- Slack \`#fun_reward-hack_blog\` にレポートが**届くこと**"
  echo "- そこに \`\${ALL_VISITS}\` のような**未展開の変数が無いこと**"
} >> "$OUT"

cat "$OUT"
exit 0
