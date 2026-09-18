#!/bin/bash
# **週次レポートを今すぐ走らせて、Slack に届くことを実物で確かめる。**
#
# ## なぜ待たないか
#
# 直した（t086 で plist に `--slack` を足した）のは **2026-09-15 02:26**。
# **9/14 が月曜だったので、次の定時は 9/21。** 3 日 待つ理由が無い
# （最上位ルール 9「待たなくていい時間を作らない」）。
#
#     launchctl kickstart -k gui/<uid>/com.dailyhack.weekly-blog-report
#
# これで定時と同じ経路（launchd → python3.11 → スクリプト → Slack）が丸ごと通る。
# **スクリプトを直接 叩かない。** それでは plist の引数が正しいかを確かめられない。
#
# ## 確かめること（**rc=0 では足りない・最上位ルール 13**）
#
#   1. `launchctl list` の **終了コード**（3 列目）が 0 になること
#   2. ログに出力が出ていること
#
# Slack に届いたかは**こちらのセッションが Slack を直接 読んで**確認する。
# タスク側では判定しない（届いた証拠は Slack の実物）。
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t087-kickstart-weekly.md"
mkdir -p "$RDIR"
LABEL="com.dailyhack.weekly-blog-report"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

{
  echo "# 週次レポートを今すぐ走らせる（t087）"
  echo
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo
  echo "## 着手前"
  echo
  echo "### plist の引数（\`--slack\` が入っているか）"
  echo
  echo '```'
  plutil -extract ProgramArguments json -o - "$PLIST" 2>/dev/null || echo "(読めなかった)"
  echo '```'
  echo
  echo "### launchctl list（3 列目が前回の終了コード）"
  echo
  echo '```'
  launchctl list 2>/dev/null | grep -F "$LABEL" || echo "(載っていない)"
  echo '```'
  echo
} > "$OUT"

if ! launchctl list 2>/dev/null | grep -qF "$LABEL"; then
  echo "🚨 **ジョブが載っていない。kickstart できない。**" >> "$OUT"
  cat "$OUT"; exit 0
fi

# **ログの位置を plist から読む。** 当て推量で探さない
LOG_OUT="$(plutil -extract StandardOutPath raw -o - "$PLIST" 2>/dev/null || echo "")"
LOG_ERR="$(plutil -extract StandardErrorPath raw -o - "$PLIST" 2>/dev/null || echo "")"
before_size=0
[ -n "$LOG_OUT" ] && [ -f "$LOG_OUT" ] && before_size=$(wc -c < "$LOG_OUT" | tr -d ' ')

t0=$(date +%s)
launchctl kickstart -k "gui/$(id -u)/$LABEL" >/dev/null 2>&1
ks_rc=$?

# **走り終わるのを待つ。** t085 の実測で 6 秒（2 日分）。定時は 7/28 日分なので長め
waited=0
while [ "$waited" -lt 150 ]; do
  sleep 10
  waited=$((waited + 10))
  # launchctl list の 1 列目が PID でなくなったら終了している
  pid="$(launchctl list 2>/dev/null | grep -F "$LABEL" | awk '{print $1}')"
  [ "$pid" = "-" ] && break
done
t1=$(date +%s)

{
  echo "## 走らせた"
  echo
  echo "| 項目 | 値 |"
  echo "| --- | --- |"
  echo "| \`kickstart\` の rc | $ks_rc |"
  echo "| 待った時間 | $((t1 - t0)) 秒 |"
  echo "| ログ（標準出力） | \`${LOG_OUT:-（plist に未設定）}\` |"
  echo
  echo "### **これが証拠** — launchctl list の 3 列目（終了コード）"
  echo
  echo '```'
  launchctl list 2>/dev/null | grep -F "$LABEL" || echo "(消えた)"
  echo '```'
  echo
} >> "$OUT"

code="$(launchctl list 2>/dev/null | grep -F "$LABEL" | awk '{print $2}')"
if [ "$code" = "0" ]; then
  echo "✅ **終了コード 0。** 正常に走り終わった。" >> "$OUT"
else
  echo "🚨 **終了コード $code。** 落ちている。" >> "$OUT"
fi

if [ -n "$LOG_OUT" ] && [ -f "$LOG_OUT" ]; then
  after_size=$(wc -c < "$LOG_OUT" | tr -d ' ')
  {
    echo
    echo "### ログの増分（$((after_size - before_size)) バイト）"
    echo
    echo '```'
    tail -c 1500 "$LOG_OUT" 2>/dev/null | tail -30
    echo '```'
  } >> "$OUT"
fi

{
  echo
  echo "## 次にこのセッションが見ること"
  echo
  echo "**Slack \`#fun_reward-hack_blog\` に週次レポートが届いているか。**"
  echo "届いていて、\`\${ALL_VISITS}\` のような未展開の変数が無ければ、直っている。"
} >> "$OUT"

cat "$OUT"
exit 0
