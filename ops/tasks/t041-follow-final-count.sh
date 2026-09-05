#!/bin/bash
# **走り続けているフォローの最終結果を取る。費用 $0。**
#
# ## t040 の途中経過（231 秒で打ち切り）
#
#   評価 12 件 → 通過 0 件
#     6  ❌ follower>>following exclusion（ratio）  ← **0.15 に下げてもなお最大の障壁**
#     2  ❌ inactive (1483d ago)
#     2  ❌ follower count out of range (84000, need 100-50000)  ← 上限緩和は効いている
#     2  ❌ Phase 1（mutual-intent 判定）
#     0  ❌ random-looking handle  ← **kankan1014 の誤判定は直った**
#
# **kickstart は成功している。** ジョブはまだ回っていた（1 件あたり 約 19 秒 × cap 30）。
#
# ## やること（読むだけ）
#
#   1. `=== end: N/M OK ===` が出るまで最大 230 秒 見張る
#   2. 今日の全実行ぶんの内訳を数える（緩和前 02:33 の回も含めて比較）
#   3. ratio で弾いた実例を出す（**どれくらいのアカウントを切っているか**）
#   4. 当日のフォロー実績
#
# **kickstart しない**（t040 の実行が続いているので二重に走らせない）。
# **投稿しない。LLM も呼ばない。**
#
# **ハンドルは伏せる。API キーは値を出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-final-count.md"
BUDGET=230
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
CL="$W/logs/competitor-follower-follow.log"
HL="$W/logs/hashtag-follow.log"
TODAY="$(date +%Y-%m-%d)"

{
echo "# フォローの最終結果（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> **緩和前の基準線: competitor 0/10・hashtag 1/5 ＝ 合計 1 人。**"
echo "> \`t040\` の途中経過は 12 件 評価して通過 0、うち **6 件が ratio** で落ちていた。"
echo "> **kickstart しない**（実行中のものを二重に走らせない）。**読むだけ。**"

echo
echo "## 1. 終わるまで見張る（最大 ${BUDGET} 秒）"
echo
START=$(date +%s)
while :; do
  NOW=$(date +%s); [ $((NOW - START)) -ge "$BUDGET" ] && break
  CE=$(grep -c '=== end:' "$CL" 2>/dev/null || echo 0)
  # 直近 5 分以内に end が出ていれば完了とみなす
  if [ -f "$CL" ] && [ $(( $(date +%s) - $(stat -f %m "$CL" 2>/dev/null || echo 0) )) -gt 60 ]; then break; fi
  sleep 10
done
echo "- 見張った時間: **$(( $(date +%s) - START )) 秒**"
echo "- \`competitor-follower-follow.log\` 最終更新: $(stat -f '%Sm' -t '%H:%M:%S' "$CL" 2>/dev/null)"
echo "- \`hashtag-follow.log\` 最終更新: $(stat -f '%Sm' -t '%H:%M:%S' "$HL" 2>/dev/null)"

for pair in "competitor:$CL" "hashtag:$HL"; do
  name="${pair%%:*}"; log="${pair#*:}"
  echo
  echo "## 2-${name}. 今日の全実行"
  [ -f "$log" ] || { echo; echo "- ログが無い"; continue; }
  TD="$(grep -F "$TODAY" "$log" 2>/dev/null || true)"
  echo
  echo "### \`=== end: N/M OK ===\`（今日の各回）"
  echo
  echo '```'
  printf '%s\n' "$TD" | grep -E '=== end:' | mask || echo "（まだ出ていない＝実行中）"
  echo '```'
  echo
  echo "### 今日 弾いた理由の内訳"
  echo
  echo '```'
  printf '%s\n' "$TD" | grep -oE '❌ [^:(]*' | sed 's/ *$//' | sort | uniq -c | sort -rn | head -12 | mask
  echo '```'
  echo
  echo "### 今日 通ったもの"
  echo
  echo '```'
  printf '%s\n' "$TD" | grep -E ': ✅' | hide | mask || echo "（なし）"
  echo '```'
done

echo
echo "## 3. ratio で弾いた実例（**どれくらいのアカウントを切っているか**）"
echo
echo "\`fw\` = フォロー数 / \`fr\` = フォロワー数。**しきい値は現在 0.15。**"
echo
echo '```'
grep -F "$TODAY" "$CL" "$HL" 2>/dev/null | grep -oE 'ratio=[0-9.]+ \(fw=[0-9]+/fr=[0-9]+\)' \
  | sort -u | tail -20 | mask || echo "（該当なし）"
echo '```'

echo
echo "## 4. 当日のフォロー実績"
echo
echo '```'
for f in "$W"/data/reply-followers.json "$W"/data/followed.json "$W"/data/badge-followback-state.json; do
  [ -f "$f" ] || continue
  n="$(grep -o "\"$TODAY" "$f" 2>/dev/null | wc -l | tr -d ' ')"
  echo "$(basename "$f"): 今日 ${n} 件 / 更新 $(stat -f '%Sm' -t '%H:%M' "$f" 2>/dev/null)"
done
echo '```'

echo
echo "---"
echo
echo "**投稿していない。kickstart もしていない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**フォローの最終結果を出した（\$0）** / $(basename "$OUT")"
