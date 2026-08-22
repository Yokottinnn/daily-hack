#!/bin/bash
# **緊急。私が plist を壊した。メモリ上の設定を回収して復元する。**
#
# ## 何をやってしまったか
#
# macOS の `plutil -extract KEY fmt FILE` は **`-o` を付けないと、
# 抽出結果でファイルそのものを上書きする。**
#
# ops/tasks/010 で全 `ai.openclaw.*.plist` に対して
#   plutil -extract EnvironmentVariables json "$P"
# を回したため、**すべての plist が EnvironmentVariables の中身だけに潰れた。**
# その後 013/014/015/016 の valid() も同じ書き方で、.bak まで潰した。
#
# 014 で見た「Label も ProgramArguments も無い」は 7/07 の故障ではなく、
# **私が壊した結果だった。** unloaded_count=56 はその規模。
#
# ## 今どうなっているか
#
# 稼働中の 11 件は launchd が**メモリに保持しているだけ**で、
# 再起動すれば全部消える。**メモリ上の設定が唯一残っている正解。**
#
# ## このタスクがやること（壊す操作は一切しない）
#
#   1. launchctl print で稼働中ジョブの完全な設定を回収して残す
#   2. Time Machine のローカルスナップショットの有無を確認する
#   3. 潰れた plist に残っている EnvironmentVariables を回収して残す
#
# **plutil -extract は使わない。** 使うなら必ず `-o -` を付ける。
# **このタスクは一切ファイルを書き換えない。読むだけ。**
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
W="$HOME/.openclaw/workspace"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/rescue-plists.md"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# plist の救出（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
echo
echo "**読むだけ。何も書き換えない。**"

echo
echo "## 1. 稼働中ジョブの完全な設定（メモリ上の唯一の正解）"
echo
for lbl in $(launchctl list 2>/dev/null | awk '{print $3}' | grep '^ai\.openclaw\.' | sort); do
  echo "### $lbl"
  echo '```'
  launchctl print "gui/$UID_N/$lbl" 2>/dev/null \
    | grep -E 'program|arguments|path =|interval|calendar|hour|minute|=>' \
    | mask | cut -c1-200 | head -40
  echo '```'
done

echo
echo "## 2. Time Machine のローカルスナップショット"
echo
echo "スナップショットがあれば、そこから壊す前の plist を取り出せる。"
echo '```'
tmutil listlocalsnapshots / 2>&1 | head -20
echo '```'
echo
echo "TimeMachine の設定:"
echo '```'
tmutil destinationinfo 2>&1 | head -10 | mask
echo '```'

echo
echo "## 3. 潰れた plist に残っている中身（環境変数は生きている）"
echo
echo "> \`plutil -p\` は読み取り専用なので安全。**\`-extract\` は使わない。**"
echo
for P in "$LA"/ai.openclaw.*.plist; do
  [ -f "$P" ] || continue
  lbl="$(basename "$P" .plist)"
  echo "### $lbl  更新=$(date -r "$P" '+%m-%d %H:%M' 2>/dev/null)  $(wc -c < "$P" | tr -d ' ') B"
  plutil -p "$P" 2>&1 | mask | cut -c1-180 | head -14
done

echo
echo "## 4. scripts の実在（復元先の確認）"
echo
for n in auto-thread-chainifier badge-followback competitor-follower-follow \
         hashtag-follow revenge-unfollow auto_detect_and_unfollow_inactive; do
  if [ -f "$W/scripts/$n.js" ]; then
    echo "- $n.js: あり（$(wc -l < "$W/scripts/$n.js" | tr -d ' ') 行）"
  else
    echo "- $n.js: **無い**"
  fi
done

echo
echo "## 5. Chrome CDP"
echo
echo "016 の実測で **18810 が応答している**（18800 ではなかった）。"
echo '```'
curl -fsS --noproxy '*' --max-time 5 http://127.0.0.1:18810/json/version 2>&1 | head -c 200 | mask
echo '```'
} > "$OUT" 2>&1

n_loaded="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -c '^ai\.openclaw\.' || true)"
n_snap="$(tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple' || true)"
echo "稼働中=${n_loaded}件の設定を回収 / TMスナップショット=${n_snap}件 / $(basename "$OUT")"
