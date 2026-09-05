#!/bin/bash
# **フィルタ本体 `follow-handle.js` を丸ごと読む。費用 $0。**
#
# ## t037 で分かったこと
#
# フィルタは 2 つのジョブの中に無い。**共通の `follow-handle.js` に入っている。**
#
#   competitor-follower-follow.js:17  const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
#   hashtag-follow.js:22              const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
#
# **1 箇所 直せば両方に効く。**
#
# あわせて 2 つ見つかった。
#
#   1. **日曜と月曜は丸ごと休み**
#      `if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN)`
#      週 7 日のうち 2 日、**28% が最初から動いていない**
#   2. 日次上限は plist の環境変数で外から変えられる
#      `COMPETITOR_FOLLOW_DAILY_CAP` / `HASHTAG_FOLLOW_DAILY_CAP`
#
# ## 出すもの（すべて無料・LLM を呼ばない）
#
#   1. `follow-handle.js` の**全文**（フィルタの実体。ここに全部ある）
#   2. 使っている**環境変数の一覧**（plist だけで変えられる範囲の確定）
#   3. plist の環境変数の**現在値**（推測せず実物）
#
# **全文を出す。** 抜粋にすると、また「読めたつもり」で推測することになる。
# 2026-09-05 に 170 字で切って裏取りできなくした失敗を繰り返さない。
#
# ## やらないこと
#
# **フォローしない。投稿しない。ジョブを触らない。書き換えない。LLM も呼ばない。**
#
# **API キーは値を出さない。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-handle.md"
FH="$W/scripts/follow-handle.js"
LA="$HOME/Library/LaunchAgents"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# フィルタ本体 \`follow-handle.js\`（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> フィルタは 2 つのジョブの中に無く、**ここに集まっている。1 箇所 直せば両方に効く。**"
echo "> **全文を出す。** 抜粋にすると、また推測することになる。"
echo "> **書き換えない。フォローしない。ジョブも触らない。**"

echo
echo "## 1. \`follow-handle.js\` 全文"
echo
if [ ! -f "$FH" ]; then
  echo "- **無い**（$FH）"
else
  echo "- $(wc -l < "$FH" | tr -d ' ') 行 / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$FH" 2>/dev/null)"
  echo
  echo '```javascript'
  cat -n "$FH" 2>/dev/null | cut -c1-200 | hide | mask
  echo '```'
fi

echo
echo "## 2. 使っている環境変数（**plist だけで変えられる範囲**）"
echo
echo '```'
grep -ohE 'process\.env\.[A-Z_][A-Z0-9_]*' "$FH" "$W/scripts/competitor-follower-follow.js" "$W/scripts/hashtag-follow.js" 2>/dev/null \
  | sed 's/process\.env\.//' | sort -u
echo '```'

echo
echo "## 3. plist の環境変数の現在値"
echo
for j in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  P="$LA/$j.plist"
  echo "### \`$j\`"
  echo
  echo '```'
  if [ -f "$P" ]; then
    /usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$P" 2>/dev/null | mask \
      || awk '/<key>EnvironmentVariables<\/key>/,/<\/dict>/' "$P" | mask
  else
    echo "（plist が無い）"
  fi
  echo '```'
  echo
done

echo
echo "---"
echo
echo "**何も変えていない（\$0）。** 次はここの数字と正規表現だけを、根拠を持って動かす。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**フィルタ本体を出した（変更なし・\$0）** / $(basename "$OUT")"
