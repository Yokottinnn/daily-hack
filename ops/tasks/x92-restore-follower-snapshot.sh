#!/bin/bash
# **`follower-snapshot` を載せ直して、その場で 1 回 走らせる。費用 $0（DOM 読み取りのみ）。**
#
# ## なぜこれだけを戻すのか
#
# x91 で分かったこと。**未ロード 60 件 はゴミではない。**
# 実行ファイルは全部 在り、**ほぼ全てが `2026-09-09` で一斉に止まっている。**
# tab-guard の `haltAutomation` の痕跡で、手で戻したのは**追跡している 12 本だけ**だった。
#
# そのうち `follower-snapshot` は、
#
#   - **LLM を呼ばない**（CDP で `/followers` を読むだけ。$0）
#   - 止まる直前まで**正常に動いていた**（9/07 → 224、9/08 → 227）
#   - **止まっていること自体が監視を殺していた。**
#     `heartbeat` の `followers.now` は「最後に記録された日の値」なので、
#     **9/8 の 227 が 12 日間「いま」として出ていた。**
#     さらに `now_date == prev_date` で `span_days` が 0 になり、
#     watchdog の「増えていない」判定は `span >= 3` の条件で丸ごと飛んでいた
#
# **目標は 9/30 までに 300。** 成果を測る口が塞がったままでは、何をしても分からない。
#
# ## 戻さないもの（**このタスクでは触らない**）
#
# `grok-trending-daily` / `trend-daily` / `draft-*` / `engage-daily` などは
# **戻すと LLM を呼ぶ。** 1 回・1 日・1 か月 を出して確認を取るまで触らない
# （最上位ルール 2-B）。
#
# ## 次の定時（明日 00:35）を待たない（最上位ルール 9）
#
# 載せ直したら **`launchctl kickstart -k` でその場で 1 回 走らせ、
# ログに新しい行が増えることまで見る。**
#
# ## rc=0 を証拠にしない（最上位ルール 13）
#
#   載った証拠    : `launchctl list` に出るか（`load` ではなく `bootstrap`）
#   走った証拠    : **follower-snapshot.log の行数が増えたか**
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
W="$HOME/.openclaw/workspace"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/restore-follower-snapshot.md"
LABEL="ai.openclaw.follower-snapshot"
P="$LA/$LABEL.plist"
FS="$L/follower-snapshot.log"
UID_NUM="$(id -u)"

hide() { sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(xox[bp]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

loaded_p() { launchctl list 2>/dev/null | awk '{print $3}' | grep -qxF "$LABEL"; }

{
echo "# \`follower-snapshot\` を戻す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`heartbeat\` の \`followers.now\` は**最後に記録された日の値。**"
echo "> 9/8 の 227 を **12 日間「いま」として出していた。**"
echo "> \`span_days\` が 0 になるため、**「増えていない」の警報も死んでいた。**"
echo
echo "**\$0**（CDP で \`/followers\` を読むだけ。LLM を呼ばない）。"

# ═══════════ 0. 当てる前 ═══════════
echo
echo "## 0. 当てる前"
echo
echo '```'
if [ -f "$P" ]; then
  echo "  plist: 在（$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)）"
else
  echo "  **plist が無い。ここで止まる。**"
fi
if loaded_p; then echo "  launchctl: **既に載っている**"; else echo "  launchctl: 載っていない"; fi
if [ -f "$FS" ]; then
  BEFORE_LINES="$(wc -l < "$FS" | tr -d ' ')"
  echo "  ログ: $BEFORE_LINES 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$FS" 2>/dev/null)"
  echo "  最後の記録: $(tail -1 "$FS" 2>/dev/null | sed -E 's/.*"today":"([^"]*)".*"count_today":([0-9]+).*/\1 → \2 人/' | cut -c1-80)"
else
  BEFORE_LINES=0
  echo "  ログ: **無い**"
fi
echo '```'

# **`exit` は打たない。** `{ } > "$OUT"` の中で抜けると、最後の要約行が出なくなり
# `heartbeat.json` の `tasks` に何も載らない。**進めるかどうかは旗で持つ。**
GO=1
[ -f "$P" ] || GO=0

# ═══════════ 1. 載せる ═══════════
echo
echo "## 1. 載せる（**\`load\` ではなく \`bootstrap\`**）"
echo
echo '```'
if [ "$GO" = "0" ]; then
  echo "  **plist が無いので載せない。**"
elif loaded_p; then
  echo "  既に載っているので bootstrap は打たない"
else
  launchctl bootstrap "gui/$UID_NUM" "$P" 2>&1 | head -3 | sed 's/^/    /'
  echo "    bootstrap を打った（**rc は証拠にならない**）"
fi
if [ "$GO" = "1" ]; then
  echo
  echo "  --- **証拠: launchctl list に出るか** ---"
  ROW="$(launchctl list 2>/dev/null | awk -v l="$LABEL" '$3==l {print "PID=" $1 "  最後の終了コード=" $2}')"
  if [ -n "$ROW" ]; then
    echo "    **載った** — $ROW"
  else
    echo "    **載っていない。** 走らせても意味がないので、ここから先はやらない。"
    GO=0
  fi
fi
echo '```'

# ═══════════ 2. その場で 1 回 走らせる ═══════════
echo
echo "## 2. その場で 1 回 走らせる（**明日の 00:35 を待たない**）"
echo
echo '```'
if [ "$GO" = "0" ]; then
  echo "  **載っていないので走らせない。**"
else
  echo "  kickstart -k を打つ"
  launchctl kickstart -k "gui/$UID_NUM/$LABEL" 2>&1 | head -3 | sed 's/^/    /'
  echo
  echo "  --- ログの行が増えるまで見る（最大 150 秒）---"
  GREW=0
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 15
    NOW_LINES="$([ -f "$FS" ] && wc -l < "$FS" | tr -d ' ' || echo 0)"
    echo "    $(( i * 15 )) 秒後: $NOW_LINES 行（開始時 $BEFORE_LINES 行）"
    if [ "$NOW_LINES" -gt "$BEFORE_LINES" ] 2>/dev/null; then GREW=1; break; fi
  done
  echo
  if [ "$GREW" = "1" ]; then
    echo "  **増えた。実際に走って書いた。**"
    echo "  --- 増えた行 ---"
    tail -1 "$FS" 2>/dev/null | cut -c1-175 | sed 's/^/    /' | clean
  else
    echo "  **150 秒 では増えなかった。**"
    echo "  走っている途中か、CDP に繋がらずに落ちたかのどちらか。"
    echo "  --- 終了コード ---"
    launchctl list 2>/dev/null | awk -v l="$LABEL" '$3==l {print "    PID=" $1 "  最後の終了コード=" $2}'
    echo "  --- .out の末尾（失敗していればここに出る）---"
    tail -3 "$L/follower-snapshot.out" 2>/dev/null | cut -c1-175 | sed 's/^/    /' | clean
  fi
fi
echo '```'

# ═══════════ 3. いまの値 ═══════════
echo
echo "## 3. 記録の推移（**目標は 9/30 までに 300**）"
echo
echo '```'
if [ -f "$FS" ]; then
  grep -oE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][^}]*"count_today":[0-9]+' "$FS" 2>/dev/null \
    | sed -E 's/^([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]).*"count_today":([0-9]+)$/\1 \2/' \
    | awk '{ last[$1] = $2 } END { for (d in last) print d, last[d] }' \
    | sort | tail -8 | sed 's/^/    /'
else
  echo "    **ログが無い。**"
fi
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**CDP で \`/followers\` を読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0**（1 日 1 回・00:35） |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**戻していないもの**: \`grok-trending-daily\` / \`trend-daily\` / \`draft-*\` /"
echo "\`engage-daily\` などは LLM を呼ぶので、金額を出して確認を取るまで触らない。"
echo
echo "いま動いている分の**実測**は pipeline-heartbeat の \`cost_24h_usd\` が **\$0.021/日**"
echo "（1 か月 約 \$0.63）。上限は \$0.048/日・\$1.44/月 で、**これは安全弁であって実績ではない。**"
} > "$OUT" 2>&1

echo "follower-snapshot を戻す / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
