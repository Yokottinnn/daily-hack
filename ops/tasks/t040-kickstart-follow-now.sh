#!/bin/bash
# **フォローを今すぐ走らせて、緩和の効果を実測する。定時を待たない。費用 $0。**
#
# ## なぜこれをやるのか
#
# `t039` でフィルタを緩めた。効果の実測を「次の定時実行（18:30）まで待つ」と
# 私が言ったが、**待つ理由が無い。`launchctl kickstart` で今すぐ走る。**
#
# ## 緩和前の基準線（今日の実測）
#
#   competitor-follower-follow  02:33Z → === end: 0/10 OK ===
#   hashtag-follow              01:18Z → === end: 1/5 OK ===
#
# **合計 1 人。** ここがどう変わるかを見る。
#
# ## やること
#
#   1. 2 つのジョブを `launchctl kickstart -k` で即実行
#   2. 最大 230 秒 ログを見張り、`=== end: N/M OK ===` が出たら止める
#   3. 通過率と、弾いた理由の内訳を出す
#   4. **`kankan1014` 型がまだ弾かれていないか**を名指しで確認
#
# **230 秒で切る。** `ops-run-tasks.sh` のロックは 300 秒で取り残し扱いになるため、
# それを超えると別のポーラーがロックを奪う。**自分でタイムアウトを持つ。**
#
# ## これは実際にフォローする
#
# 読むだけのタスクとは違う。**X 上で実際にフォローが発生する。**
# 日次上限（competitor 30 / hashtag 90）は生きているので、そこで止まる。
#
# **投稿はしない。LLM も呼ばない（フォローは Playwright の DOM 操作のみ）。**
#
# **ハンドルは伏せる。API キーは値を出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/kickstart-follow.md"
UID_N="$(id -u)"
BUDGET=230
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

CL="$W/logs/competitor-follower-follow.log"
HL="$W/logs/hashtag-follow.log"

{
echo "# フォローを今すぐ走らせた（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> 定時（18:30）を待つ理由が無い。**\`launchctl kickstart\` で即実行。**"
echo "> **緩和前の基準線: competitor 0/10・hashtag 1/5 ＝ 合計 1 人。**"
echo "> 投稿はしない。LLM も呼ばない（フォローは Playwright の DOM 操作のみ）。"

# 実行前の行数を控える（増えた分だけ読むため）
CB=$( [ -f "$CL" ] && wc -l < "$CL" | tr -d ' ' || echo 0 )
HB=$( [ -f "$HL" ] && wc -l < "$HL" | tr -d ' ' || echo 0 )

echo
echo "## 1. 起動"
echo
echo '```'
for j in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  if launchctl kickstart -k "gui/$UID_N/$j" 2>&1 | head -2; then
    echo "$j: kickstart した"
  else
    echo "$j: **kickstart に失敗**"
  fi
done
echo '```'

echo
echo "## 2. 終わるまで見張る（最大 ${BUDGET} 秒）"
echo
START=$(date +%s)
CDONE=0; HDONE=0
while :; do
  NOW=$(date +%s)
  [ $((NOW - START)) -ge "$BUDGET" ] && break
  [ -f "$CL" ] && tail -n +$((CB + 1)) "$CL" 2>/dev/null | grep -q '=== end:' && CDONE=1
  [ -f "$HL" ] && tail -n +$((HB + 1)) "$HL" 2>/dev/null | grep -q '=== end:' && HDONE=1
  [ "$CDONE" = "1" ] && [ "$HDONE" = "1" ] && break
  sleep 5
done
ELAPSED=$(( $(date +%s) - START ))
echo "- 見張った時間: **${ELAPSED} 秒** / competitor 完了=${CDONE} hashtag 完了=${HDONE}"

for pair in "competitor:$CL:$CB" "hashtag:$HL:$HB"; do
  name="${pair%%:*}"; rest="${pair#*:}"; log="${rest%%:*}"; base="${rest##*:}"
  echo
  echo "## 3-${name}. \`$(basename "$log")\`"
  echo
  if [ ! -f "$log" ]; then echo "- ログが無い"; continue; fi
  NEW="$(tail -n +$((base + 1)) "$log" 2>/dev/null)"
  if [ -z "$NEW" ]; then echo "- **新しい行が出ていない**（まだ起動中か、失敗）"; continue; fi

  echo "### 結果"
  echo
  echo '```'
  printf '%s\n' "$NEW" | grep -E '=== end:|today already follows|DAILY_CAP' | tail -5 | mask
  echo '```'
  echo
  echo "### 弾いた理由の内訳"
  echo
  echo '```'
  printf '%s\n' "$NEW" | grep -oE '❌ [^:]*(:|$)' | sed 's/[: ]*$//' | sort | uniq -c | sort -rn | head -12 | mask
  echo '```'
  echo
  echo "### 通ったもの"
  echo
  echo '```'
  printf '%s\n' "$NEW" | grep -E ': ✅' | tail -20 | hide | mask || echo "（なし）"
  echo '```'
  echo
  echo "### \`kankan1014\` 型（名前＋4桁数字）がまだ弾かれていないか"
  echo
  echo '```'
  printf '%s\n' "$NEW" | grep -E 'random-looking handle' | tail -10 | mask || echo "（ランダム判定で弾いたものは無い）"
  echo '```'
done

echo
echo "## 4. 当日のフォロー実績"
echo
echo '```'
TODAY="$(date +%Y-%m-%d)"
for f in "$W"/data/reply-followers.json "$W"/data/followed.json; do
  [ -f "$f" ] || continue
  n="$(grep -o "\"$TODAY" "$f" 2>/dev/null | wc -l | tr -d ' ')"
  echo "$(basename "$f"): 今日 ${n} 件 / 更新 $(stat -f '%Sm' -t '%H:%M' "$f" 2>/dev/null)"
done
echo '```'

echo
echo "---"
echo
echo "**緩和前は competitor 0/10・hashtag 1/5 ＝ 合計 1 人だった。**"
echo "**投稿していない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**フォローを即実行して実測した（\$0）** / $(basename "$OUT")"
