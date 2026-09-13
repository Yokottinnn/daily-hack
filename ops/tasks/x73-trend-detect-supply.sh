#!/bin/bash
# **`trend-detect` の出力が安定しない理由を測る。測るだけ。費用 $0。**
#
# ## なぜここが効くのか（x69 の実測）
#
# `hashtag-follow` は**独自のタグを持たず、`trend-detect` の出力を使っている。**
#
#   [01:49] trend candidates: 0  → unique new authors: 0 → picks: 0
#   [08:03] trend candidates: 2  → unique new authors: 2 → picks: 2
#   [21:06] （返信側）11 件
#
# **返信もフォローも、供給元はここ 1 つ。** 増えれば両方 増える。
# 逆に 0 の回は、返信もフォローも丸ごと空振りする。
#
# ## 読むところ（**直さない。広げない**）
#
#   1. 1 回あたり何件 返しているか（時刻ごとの推移）
#   2. 0 件 になる回に偏りがあるか（深夜だけ、など）
#   3. どこから集めているか（検索語・タグ・mentions・home）
#   4. 絞り込みの条件（MIN_LIKES=2 / MAX_AGE_HOURS=18 がどこで効くか）
#   5. 途中で失敗していないか（`failed:` の行）
#
# **条件を緩めるのは、どこで減っているか分かってから。**
# 上限やしきい値を推測で動かさない。
#
# ## やらないこと
#
# **設定を変えない。投稿しない。フォローしない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（ログとソースを読むだけ・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/trend-detect-supply.md"
NODE_BIN="/usr/local/bin/node"
TD="$S/trend-detect.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# \`trend-detect\` の出力が安定しない理由"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`hashtag-follow\` は独自のタグを持たず、**\`trend-detect\` の出力を使っている。**"
echo "> **返信もフォローも供給元はここ 1 つ。** 0 件 の回は両方 空振りする。"
echo
echo "**測るだけ。広げない。**"

# ═══════════ 1. 1 回あたり何件 ═══════════
echo
echo "## 1. 1 回あたり何件 返しているか（**時刻ごとの推移**）"
echo
echo '```'
echo "  --- hashtag-follow 側（trend candidates: N） ---"
HL="$L/hashtag-follow.log"
if [ -f "$HL" ]; then
  grep -hE 'trend candidates:' "$HL" 2>/dev/null | grep -E '^\[' | tail -24 \
    | sed -E 's/^\[([0-9-]+)T([0-9:]+).*trend candidates: ([0-9]+).*/    \1 \2  \3 件/' | clean
else
  echo "    **$HL が無い。**"
fi
echo
echo "  --- 返信側（from N candidates） ---"
CW="$L/comment-warmup.log"
if [ -f "$CW" ]; then
  grep -hoE '^\[[0-9T:-]+\] picked [0-9]+ / max [0-9]+ \(from [0-9]+ candidates\)' "$CW" 2>/dev/null | tail -16 \
    | sed -E 's/^\[([0-9-]+)T([0-9:]+)\] picked ([0-9]+) \/ max ([0-9]+) \(from ([0-9]+) candidates\)/    \1 \2  候補 \5 件 → picked \3\/\4/' | clean
fi
echo
echo "  --- 0 件 だった回の時刻（UTC の時） ---"
grep -hE 'trend candidates: 0|no candidates' "$HL" "$CW" 2>/dev/null \
  | grep -oE 'T[0-9][0-9]:' | sort | uniq -c | sort -rn | head -10 | sed 's/^/    /'
echo
echo "  --- 0 件 以外の回の時刻（比較用） ---"
grep -hE 'trend candidates: [1-9]' "$HL" 2>/dev/null \
  | grep -oE 'T[0-9][0-9]:' | sort | uniq -c | sort -rn | head -10 | sed 's/^/    /'
echo '```'
echo
echo "**時刻に偏っていれば「その時間帯に投稿が少ない」で説明がつく。**"
echo "偏っていなければ、取りに行く側の問題を疑う。"

# ═══════════ 2. 途中で失敗していないか ═══════════
echo
echo "## 2. 途中で失敗していないか（**\`failed:\` の行**）"
echo
echo '```'
for f in comment-warmup.log comment-orchestrator.log hashtag-follow.log; do
  P="$L/$f"; [ -f "$P" ] || continue
  c="$(grep -cE 'failed:|timeout|Timeout' "$P" 2>/dev/null || echo 0)"
  printf '  %-30s %5s 件\n' "$f" "$c"
done
echo
echo "  --- 直近 12 件（実物） ---"
grep -hE 'failed:|timeout [0-9]+ms|Timeout' "$L"/comment-warmup.log "$L"/hashtag-follow.log 2>/dev/null \
  | tail -12 | cut -c1-190 | sed 's/^/    /' | clean
echo
echo "  --- 失敗した検索語（多い順） ---"
grep -hoE '(hashtag|query|search) [^ ]{1,24} failed' "$L"/comment-warmup.log "$L"/hashtag-follow.log 2>/dev/null \
  | sort | uniq -c | sort -rn | head -12 | sed 's/^/    /' | clean
echo '```'

# ═══════════ 3. どこから集めているか ═══════════
echo
echo "## 3. どこから集めているか（**設定の実物**）"
echo
echo '```'
if [ ! -f "$TD" ]; then
  echo "  **$TD が無い。**"
else
  echo "  $(wc -l < "$TD" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$TD" 2>/dev/null)"
  echo
  echo "  --- 集めに行く先 ---"
  grep -nE 'search\?q=|/home|/notifications|mentions|explore|hashtag|QUERIES|SOURCES|TAGS' "$TD" 2>/dev/null \
    | head -20 | cut -c1-190 | sed 's/^/    /' | clean
  echo
  echo "  --- 絞り込みの条件 ---"
  grep -nE 'MIN_LIKES|MAX_AGE|like_count|reply_count|retweet|age|filter|slice\(' "$TD" 2>/dev/null \
    | head -20 | cut -c1-190 | sed 's/^/    /' | clean
  echo
  echo "  --- 読み込んでいる設定ファイル ---"
  grep -noE '[A-Za-z0-9_.-]+\.json' "$TD" 2>/dev/null | awk -F: '{print $2}' | sort -u | sed 's/^/    /'
fi
echo '```'

# ═══════════ 4. 絞り込みの環境変数 ═══════════
echo
echo "## 4. 絞り込みの実値（**plist が渡している値**）"
echo
echo '```'
P="$LA/ai.openclaw.comment-warmup.plist"
if [ -f "$P" ]; then
  awk '/EnvironmentVariables/,/<\/dict>/' "$P" 2>/dev/null \
    | grep -oE '<key>[A-Za-z_]+</key>|<string>[^<]*</string>' \
    | sed 's/<[^>]*>//g' | paste - - 2>/dev/null | head -10 | sed 's/^/    /' | clean
else
  echo "    **plist が無い。**"
fi
echo
echo "  --- 候補の設定ファイル（更新日も見る） ---"
for f in trend-keywords.json hashtag-targets.json comment-targets.json x-growth.json; do
  Q="$D/$f"; [ -f "$Q" ] || continue
  printf '    %-28s %s\n' "$f" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$Q" 2>/dev/null)"
done
echo '```'
echo
echo "**\`MIN_LIKES=2\` と \`MAX_AGE_HOURS=18\` がどこで効くかを 3 章と突き合わせる。**"
echo "深夜は「18 時間 以内かつ いいね 2 以上」を満たす投稿がそもそも少ない可能性がある。"

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**ログとソースを読むだけ。LLM を呼ばない。ブラウザも触らない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**注意: 候補を増やすと返信の生成回数が増えるため、そちらは費用が動く。**"
echo
echo "| | 1 回あたり | 1 日あたり | 1 か月あたり |"
echo "| --- | --- | --- | --- |"
echo "| いま（x68 適用後・上限） | \$0.003 | \$0.048 | **\$1.44** |"
echo "| 候補が増えて上限に毎回 張り付いた場合 | \$0.003 | \$0.048 | **\$1.44** |"
echo
echo "**上限（MAX_PICKS 4 × 4 発火 = 16 件/日）は変えないので、"
echo "候補が増えても月額の上限は \$1.44 のまま。** 上限に近づくだけ。"
echo "**発火数や MAX_PICKS を上げる提案をするときは、増加後の月額を必ず併記する。**"
} > "$OUT" 2>&1

echo "trend-detect の供給 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
