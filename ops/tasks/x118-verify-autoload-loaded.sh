#!/bin/bash
# **autoload の 14 本 が本当に載っているかを、launchctl print で 1 本ずつ見る。**
# **測るだけ。費用 $0（launchctl を打つだけ・LLM を呼ばない）。**
#
# ## なぜ
#
# `heartbeat.json` の autoload がこう出ている（2026-09-21 03:51Z）。
#
#   {"target":14,"tried":0,"loaded":0,"labels":[]}
#
# **打った 0 / 載った 0。** これは 2 通りに読める。
#
#   ① 14 本 すべて既に載っているので、打つ必要が無かった（正常）
#   ② 載っているかの判定が壊れていて、外れていても打たない（**9/9 の再来**）
#
# **どちらなのかが、この数字だけでは分からない。**
# `tried:0` を「正常」と読んで 11 日間 気づかなかったのが 2026-09-09 だった。
#
# ## 何で確かめるか
#
# **`launchctl list | grep` は証拠にならない**（最上位ルール 13）。
# `list` は載っていても出ないことがあり、実際 2026-09-20 に
# `com.dailyhack.refresh-daily` を 3 回 とも「載っていない」と誤報した。
#
# **`launchctl print gui/<uid>/<ラベル>` で 1 本ずつ見る。**
# `state` / `runs` / `last exit code` まで出るので、
# **「載っている」と「動いている」を区別できる。**
#
# ## 特に見たいもの
#
# `ai.openclaw.follower-snapshot`。**フォロワー数の唯一の記録源。**
# 2026-09-09 に止まり、9/8 の 227 が 12 日間「いま」として出ていた。
# **9/9〜9/19 の 11 日分 が永久に欠けている**（docs/follower-tracking.md）。
#
# ## やらないこと
#
# **載せ直さない。外さない。設定を変えない。読むだけ。**
# 直すのは次のタスク（最上位ルール 15・測るものと直すものを分ける）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
LIST=""                                  # **実体はリポジトリ側。下で解決する**
OUT="${OPS_REPORT_DIR:-/tmp}/verify-autoload-loaded.md"
UID_N="$(id -u)"

# **一覧はリポジトリの ops/data/autoload-jobs.txt が正。** heartbeat が読んでいるのと同じもの
REPO=""
for c in "$HOME/projects/anta-baka-x/blog" "$HOME/.openclaw/workspace/blog"; do
  [ -f "$c/ops/data/autoload-jobs.txt" ] && REPO="$c" && break
done

{
echo "# autoload の 14 本 は本当に載っているか（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`heartbeat.json\` は \`{\"target\":14,\"tried\":0,\"loaded\":0}\` と出している。"
echo "> **打った 0 は「全部 載っている」とも「判定が壊れている」とも読める。**"
echo "> \`tried:0\` を正常と読んで 11 日間 気づかなかったのが 2026-09-09 だった。"
echo
echo "**\`launchctl list | grep\` は使わない**（載っていても出ないことがある・最上位ルール 13）。"
echo "**\`launchctl print gui/$UID_N/<ラベル>\` で 1 本ずつ見る。**"

echo
echo "## 1. 一覧はどこにあるか"
echo
echo '```'
if [ -n "$REPO" ]; then
  echo "  $REPO/ops/data/autoload-jobs.txt"
  LIST="$REPO/ops/data/autoload-jobs.txt"
else
  echo "  **リポジトリが見つからない。** 候補:"
  echo "    \$HOME/projects/anta-baka-x/blog"
  echo "    \$HOME/.openclaw/workspace/blog"
  echo "  当て推量でファイルを作らない。ここで終わる。"
fi
echo '```'

if [ ! -f "$LIST" ]; then
  echo
  echo "**一覧が読めないので、以降は出せない。**"
else

echo
echo "## 2. 1 本ずつ print する"
echo
echo '```'
printf '  %-42s %-12s %-6s %-10s %s\n' "ラベル" "state" "runs" "last-exit" "plist"
echo "  $(printf '%.0s-' $(seq 1 92))"

TOTAL=0; OK=0; NG=0
NGLIST=""
# **末尾に改行が無くても最後の 1 行を読む**（最上位ルール 14）
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  L="$(printf '%s' "$line" | tr -d '[:space:]')"
  [ -z "$L" ] && continue
  TOTAL=$((TOTAL + 1))
  P="$(launchctl print "gui/$UID_N/$L" 2>&1)"
  if printf '%s' "$P" | grep -q 'Could not find service'; then
    NG=$((NG + 1)); NGLIST="${NGLIST:+$NGLIST }$L"
    printf '  %-42s %-12s %-6s %-10s %s\n' "$L" "**載っていない**" "-" "-" "-"
    continue
  fi
  OK=$((OK + 1))
  st="$(printf '%s' "$P" | awk -F'= ' '/^[[:space:]]*state = /{print $2; exit}')"
  rn="$(printf '%s' "$P" | awk -F'= ' '/^[[:space:]]*runs = /{print $2; exit}')"
  ec="$(printf '%s' "$P" | awk -F'= ' '/last exit code = /{print $2; exit}')"
  pl="$(printf '%s' "$P" | awk -F'= ' '/^[[:space:]]*path = /{print $2; exit}')"
  printf '  %-42s %-12s %-6s %-10s %s\n' "$L" "${st:--}" "${rn:--}" "${ec:--}" "$(basename "${pl:--}")"
done < "$LIST"

echo
echo "  対象 $TOTAL 本 / 載っている $OK 本 / **載っていない $NG 本**"
echo '```'

if [ "$NG" -gt 0 ]; then
  echo
  echo "### **外れているものがある**"
  echo
  echo '```'
  for l in $NGLIST; do echo "  $l"; done
  echo '```'
  echo
  echo "**\`heartbeat\` は \`tried:0\` と言っている。** 外れているのに打っていないなら、"
  echo "**載っているかの判定が壊れている。** それが 9/9 に 11 日間 気づけなかった理由と同じ形。"
else
  echo
  echo "### 全部 載っている。**\`tried:0\` は正常だった**"
  echo
  echo "ただし **\`runs = 0\` のものは「載っているが一度も動いていない」。** 上の表で確認する。"
fi

echo
echo "## 3. フォロワー記録の口を、名指しで見る"
echo
echo "**\`ai.openclaw.follower-snapshot\` はフォロワー数の唯一の記録源。**"
echo "2026-09-09 に止まり、9/8 の 227 が 12 日間「いま」として出ていた。"
echo
echo '```'
launchctl print "gui/$UID_N/ai.openclaw.follower-snapshot" 2>&1 \
  | grep -E 'state|runs|last exit code|path =|program =|StartCalendarInterval|StartInterval|next' \
  | head -20 | sed 's/^/  /'
echo '```'

echo
echo "### 記録ファイルは増えているか（**これが一次情報**）"
echo
echo '```'
D="$W/data/follower-snapshots"
if [ -d "$D" ]; then
  echo "  $D"
  echo "  ファイル数: $(ls -1 "$D"/*.json 2>/dev/null | grep -c . | head -1)"
  echo "  --- 新しい順に 6 件（日付・人数）---"
  for f in $(ls -1t "$D"/*.json 2>/dev/null | head -6); do
    n="$(node -e 'try{const j=require(process.argv[1]);console.log(j.count ?? j.follower_count ?? "?")}catch(e){console.log("?")}' "$f" 2>/dev/null)"
    printf '    %-16s %s 人\n' "$(basename "$f")" "$n"
  done
else
  echo "  **$D が無い。記録がそもそも作られていない。**"
fi
echo '```'
echo
echo "**人数は \`count\`。\`followers\` はハンドルの配列で人数ではない**（docs/follower-tracking.md）。"

fi

echo
echo "## 4. 費用"
echo
echo "**\`launchctl print\` と \`ls\` だけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "autoload 14 本 の実態 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
