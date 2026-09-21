#!/bin/bash
# **フォローしに行く 2 本が、相手のフォロワー数で絞っているかを読む。測るだけ。費用 $0。**
#
# ## なぜ
#
# `heartbeat.json` の `followback_bands`（Mac 側の集計）を並べ直したら、
# **帯で返し率が 10 倍 違った。**
#
#   帯            成熟  返った   返し率
#   0-99            15      3    20%
#   300-999         14      6    **42.9%**
#   1000-4999       29      5    17.2%
#   5000-49999      22      1    **4.5%**
#
# **いちばん多く当たっている 2 つの帯が、いちばん返らない帯だった。**
# 成熟した試行 81 件 のうち **51 件（63%）が 1000 人 以上**に使われている。
#
# **5000+ は母数 22 で 4.5%。** ここは低いと言い切れる。
#
# ## だが「いまどの帯を狙っているか」を見ていない
#
# **直す前に測る**（最上位ルール 15）。絞り込みが既に在るのに無いと思って足すと、
# 二重にかかって候補が消える。
#
# ## 何を出すか
#
#   ① `competitor-follower-follow` / `hashtag-follow` の plist の環境変数
#   ② その JS の中の「フォロワー数で弾く」判定（**変数名で引く**）
#   ③ 直近のログ（実際に何人 見て何人 フォローしたか）
#   ④ 種（seeds）がどのアカウントか。**大手ばかりなら、そのフォロワーも大手寄りになる**
#
# ## やらないこと
#
# **フォローしない。設定を変えない。上限を入れない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
D="$W/data"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-target-bands.md"
UID_N="$(id -u)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(xoxb-)[A-Za-z0-9-]+#\1<MASKED>#g' \
         -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# フォロー先は帯で絞っているか（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`followback_bands\` を並べ直したら、**帯で返し率が 10 倍 違った。**"
echo "> **300-999 が 42.9%、5000+ が 4.5%。** なのに成熟した試行 81 件 のうち"
echo "> **51 件（63%）が 1000 人 以上**に使われている。"
echo ">"
echo "> **直す前に、いま絞っているかを見る**（最上位ルール 15）。"
echo "> 既に絞りが在るのに足すと、二重にかかって候補が消える。"

echo
echo "## 1. plist の環境変数（**上限・下限がここに在ることが多い**）"
echo
echo '```'
for L2 in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  P="$LA/$L2.plist"
  echo "  ===== $L2 ====="
  if [ ! -f "$P" ]; then echo "    **plist が無い**"; continue; fi
  # **EnvironmentVariables の中身を出す。** plutil なら形を崩さず読める
  plutil -p "$P" 2>/dev/null \
    | grep -iE 'MIN_|MAX_|CAP|FOLLOWER|BAND|LIMIT|Program|StartCalendar|Hour|Minute' \
    | head -24 | cut -c1-160 | sed 's/^/    /'
  echo "    --- 載っているか ---"
  if launchctl print "gui/$UID_N/$L2" 2>&1 | grep -q 'Could not find service'; then
    echo "    **載っていない**"
  else
    launchctl print "gui/$UID_N/$L2" 2>/dev/null \
      | grep -E '^[[:space:]]*(state|runs) = |last exit code = ' | head -3 | sed 's/^/    /'
  fi
  echo
done
echo '```'

echo
echo "## 2. JS の中で、フォロワー数で弾いているか（**変数名で引く**）"
echo
echo "**\`readFileSync\` のような決め打ちで引かない。** x120 でそれをやって"
echo "**「使っていない」と誤判定した**（実体は \`loadJson()\` 経由だった）。"
echo
echo '```javascript'
for f in "$S/competitor-follower-follow.js" "$S/hashtag-follow.js"; do
  [ -f "$f" ] || { echo "  （$(basename "$f") が無い）"; continue; }
  echo "  ===== $(basename "$f") ====="
  grep -n -iE 'followers?_?count|followerCount|MIN_FOLLOW|MAX_FOLLOW|band|tooBig|tooSmall|skip.*follower' \
    "$f" 2>/dev/null | head -20 | cut -c1-170 | sed 's/^/    /' || echo "    （該当なし）"
  echo
done
echo '```'
echo
echo "**該当なしなら、いまは帯で絞っていない。** 5000+ に毎日 消えている。"

echo
echo "## 3. 種（seeds）は誰か"
echo
echo "**種が大手ばかりなら、そのフォロワーを辿っても大手寄りになる。**"
echo "絞りを足す前に、**種のほうが原因かもしれない。**"
echo
echo '```'
for f in "$D/competitor-seeds.json" "$D/follow-seeds.json" "$D/hashtag-follow-targets.json"; do
  [ -f "$f" ] || continue
  echo "  ===== $(basename "$f") / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null) ====="
  head -c 600 "$f" 2>/dev/null | clean | sed 's/^/    /'
  echo
done
ls -1 "$D" 2>/dev/null | grep -iE 'seed|hashtag|target' | sed 's/^/    /' || echo "    （seed 系のファイルが無い）"
echo '```'

echo
echo "## 4. 直近のログ（**見た人数と、実際にフォローした人数**）"
echo
echo '```'
for f in "$L/competitor-follower-follow.log" "$L/hashtag-follow.log"; do
  [ -f "$f" ] || continue
  echo "  ===== $(basename "$f") / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null) ====="
  tail -14 "$f" 2>/dev/null | cut -c1-170 | clean | sed 's/^/    /'
  echo
done
echo '```'
echo
echo "**「見た N / フォローした M」が両方 出ていないと、絞りが効いたか分からない。**"

echo
echo "## 5. 読み方（**このタスクでは直さない**）"
echo
echo "| 出方 | 次の一手 |"
echo "| --- | --- |"
echo "| 帯の絞りが無い | **5000+ を外す上限を入れる。** DOM 操作のみなので \$0 |"
echo "| 絞りが在るのに 5000+ が多い | **絞りが効いていない。** 判定を見る |"
echo "| 種が大手ばかり | **絞りより種を替えるほうが速い** |"
echo "| 載っていない | そもそも動いていない。**先に戻す話** |"
echo
echo "**母数の注意。** \`300-999\` は成熟 14 件 しかないので 42.9% は誤差が大きい。"
echo "**\`5000+\` は母数 22 で 4.5%** なので、こちらは低いと言い切れる。"
echo "**「300-999 を狙う」より「5000+ を外す」のほうが、根拠が強い。**"

echo
echo "## 6. 費用"
echo
echo "**plist とソースとログを読むだけ。LLM を呼ばない。**"
echo "**フォロー自体も DOM 操作のみで LLM を呼ばない**ので、帯を変えても課金は増えない。"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "フォロー先の帯を読む / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
