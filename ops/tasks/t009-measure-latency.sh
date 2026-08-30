#!/bin/bash
# **「マージしてから Mac で走るまで」の実時間を測る。**
#
# 「入れた」と「効いている」は別である。**数字で確かめる。**
#
# ## 測り方
#
# 自分自身のファイルが origin/main に入った時刻（コミット時刻）と、
# いま走っている時刻の差を取る。**これがそのまま待ち時間になる。**
#
#   マージ時刻  = git log -1 --format=%ct origin/main -- ops/tasks/<自分>
#   実行時刻    = date +%s
#   待ち時間    = 実行 - マージ
#
# ## どちらのジョブが走らせたかも見る
#
# ポーラーの plist だけ `OPS_PUSH=1` を持つ（`t008` がそう書いている）。
# heartbeat 経由のときは付かない。**環境変数で見分けられる。**
#
# 期待する結果:
#
#   実行者: ops-poller / 待ち時間: 60 秒以下
#
# 30 分近い値が出たら、ポーラーが動いていないか、拾えていない。
#
# **何も変更しない。読むだけ。LLM を呼ばない（費用 $0）。**
set -uo pipefail

SELF="t009-measure-latency.sh"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/measure-latency.md"
LBL="com.dailyhack.ops-poller"
HB="com.dailyhack.ops-heartbeat"
NOW="$(date +%s)"

{
echo "# マージから実行までの実測（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> **「入れた」と「効いている」は別。** 数字で確かめる。"

echo
echo "## 1. 待ち時間"
echo
git -C "$REPO" fetch -q origin main 2>/dev/null || true
MERGED="$(git -C "$REPO" log -1 --format=%ct origin/main -- "ops/tasks/$SELF" 2>/dev/null)"
if [ -z "$MERGED" ]; then
  echo "- **自分のコミット時刻が取れない。** 測定できない"
else
  DIFF=$((NOW - MERGED))
  echo "- main へ入った時刻: \`$(date -r "$MERGED" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$MERGED")\`"
  echo "- 実行された時刻:   \`$(date -r "$NOW" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$NOW")\`"
  echo
  echo "### **待ち時間: ${DIFF} 秒（$((DIFF / 60)) 分 $((DIFF % 60)) 秒）**"
  echo
  if [ "$DIFF" -le 90 ] 2>/dev/null; then
    echo "✅ **90 秒以内。ポーラーが効いている。**（前は最大 1,800 秒）"
  elif [ "$DIFF" -le 400 ] 2>/dev/null; then
    echo "⚠️ **90 秒は超えたが 30 分よりは大幅に短い。** ポーラーの間隔か起動の遅れを見ること"
  else
    echo "❌ **30 分に近い。ポーラーが拾えていない。** 下の 2 章を見ること"
  fi
fi

echo
echo "## 2. どちらのジョブが走らせたか"
echo
# ポーラーの plist だけ OPS_PUSH=1 を持つ（t008 がそう書いている）
if [ "${OPS_PUSH:-}" = "1" ]; then
  echo "- 実行者: **\`ops-poller\`**（\`OPS_PUSH=1\` が付いている）"
else
  echo "- 実行者: **\`ops-heartbeat\`**（\`OPS_PUSH\` が無い）"
  echo "  → ポーラーより先に heartbeat が拾ったか、**ポーラーが動いていない**"
fi

echo
echo "## 3. ジョブの状態"
echo
for L in "$LBL" "$HB"; do
  P="$HOME/Library/LaunchAgents/$L.plist"
  loaded="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$L" || true)"
  iv="$(plutil -extract StartInterval raw -o - "$P" 2>/dev/null || echo '無し')"
  echo "- \`$L\`: ロード=**${loaded}** 件 / StartInterval=**${iv}** 秒"
done

echo
echo "## 4. ポーラーのログ（末尾）"
echo
echo '```'
tail -6 "$HOME/.openclaw/logs/ops-poller.out.log" 2>/dev/null || echo "(out ログなし)"
echo '---'
tail -6 "$HOME/.openclaw/logs/ops-poller.err.log" 2>/dev/null || echo "(err ログなし)"
echo '```'
echo
echo "**何も変更していない。読んだだけ。** LLM 呼び出しなし（\$0）。"
} > "$OUT" 2>&1

D="$(grep -oE '待ち時間: [0-9]+ 秒' "$OUT" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
W="$(grep -oE '実行者: \*\*`[a-z-]+`' "$OUT" 2>/dev/null | grep -oE 'ops-[a-z]+' | head -1)"
echo "待ち時間 ${D:-?} 秒 / 実行者 ${W:-?} / $(basename "$OUT")"
