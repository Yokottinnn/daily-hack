#!/bin/bash
# **死んでいる follower-history.json を、誰が読んでいるかを洗う。測るだけ。費用 $0。**
#
# ## なぜ消す前に洗うのか
#
# `~/.openclaw/workspace/data/follower-history.json` は **2026-05-23 で止まっている**うえ、
# **最後の行が誤読**で残っている。
#
#   2026-05-22   51 人
#   2026-05-23    0 人   ← -51。明らかな誤読
#   （以降 4 か月 記録なし）
#
# **これを信じる仕組みがあれば「フォロワー 0 人」と判断する。**
# 4 か月 誰にも気づかれていない。
#
# **黙って消すと、読んでいた側が今度は「ファイルが無い」で落ちる。**
# 落ち方が変わるだけで、直ったことにはならない。**だから先に読み手を洗う。**
#
# ## 何を見るか
#
#   ① `follower-history` を名指ししているファイル（scripts / ops / plist / リポジトリ）
#   ② その行の前後（読んでいるのか、書いているのか）
#   ③ ファイル自身の最終更新時刻と行数
#
# ## やらないこと
#
# **消さない。直さない。読むだけ。**
# 消す／直すのは次のタスク（最上位ルール 15・測るものと直すものを分ける）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
F="$W/data/follower-history.json"
OUT="${OPS_REPORT_DIR:-/tmp}/trace-follower-history-readers.md"

REPO=""
for c in "$HOME/projects/anta-baka-x/blog" "$W/blog"; do
  [ -d "$c/.git" ] && REPO="$c" && break
done

{
echo "# follower-history.json を誰が読んでいるか（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> このファイルは **2026-05-23 で止まり、最後の行が \`0 人\` の誤読**（前日 51 人）。"
echo "> **信じる仕組みがあれば「フォロワー 0 人」と判断する。**"
echo "> **黙って消すと、読んでいた側が今度は「ファイルが無い」で落ちる。**"
echo "> だから先に読み手を洗う。**このタスクは消さない。読むだけ。**"

echo
echo "## 1. ファイル自身"
echo
echo '```'
if [ -f "$F" ]; then
  # **macOS は `stat -f`**（`-c` は Linux・最上位ルール 14）
  echo "  path : $F"
  echo "  size : $(wc -c < "$F" | tr -d ' ') bytes / $(wc -l < "$F" | tr -d ' ') 行"
  echo "  mtime: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$F" 2>/dev/null)"
  echo "  --- 末尾 3 行 ---"
  tail -3 "$F" | cut -c1-160 | sed 's/^/    /'
else
  echo "  **$F が無い。** もう消えている"
fi
echo '```'

echo
echo "## 2. 名指ししているファイル"
echo
echo "**\`follower-history\` という語で当たる。** 拡張子は問わない。"
echo
echo '```'
HITS=""
for d in "$W/scripts" "$W/ops" "$W" "$HOME/Library/LaunchAgents"; do
  [ -d "$d" ] || continue
  echo "  --- $d ---"
  # **node_modules と .git は見ない**（量が出て読めなくなる）
  R="$(grep -rl --exclude-dir=node_modules --exclude-dir=.git \
        --exclude='follower-history.json' 'follower-history' "$d" 2>/dev/null | head -40)"
  if [ -n "$R" ]; then
    printf '%s\n' "$R" | sed 's/^/    /'
    HITS="${HITS:+$HITS }$R"
  else
    echo "    （無し）"
  fi
done
if [ -n "$REPO" ]; then
  echo "  --- $REPO（リポジトリ）---"
  R="$( (cd "$REPO" && git grep -l 'follower-history' -- . 2>/dev/null) | head -40)"
  if [ -n "$R" ]; then printf '%s\n' "$R" | sed "s|^|    |"; else echo "    （無し）"; fi
else
  echo "  --- リポジトリが見つからない。候補を挙げるだけにする ---"
  echo "    \$HOME/projects/anta-baka-x/blog"
fi
echo '```'

echo
echo "## 3. 読んでいるのか、書いているのか"
echo
echo "**名前が出るだけでは足りない。** \`readFileSync\` なら読み手、"
echo "\`writeFileSync\` / \`appendFileSync\` なら書き手。**前後を出して見分ける。**"
echo
echo '```'
if [ -z "$HITS" ]; then
  echo "  ワークスペース側に該当が無い。**消してよい可能性が高い**"
else
  for f in $HITS; do
    echo "  ===== $f ====="
    grep -n -B2 -A2 'follower-history' "$f" 2>/dev/null | head -24 | cut -c1-170 | sed 's/^/    /'
    echo
  done
fi
echo '```'

echo
echo "## 4. 判断の材料（**このタスクでは決めない**）"
echo
echo "| 出方 | 意味 |"
echo "| --- | --- |"
echo "| 該当が 1 件も無い | **消してよい。** 誰も読んでいない |"
echo "| 書き手だけ在る | **書き手が壊れている。** 4 か月 書けていない。直すか止めるか |"
echo "| 読み手が在る | **\`0 人\` を読んでいる。** \`follower-snapshots/\` の \`count\` に向け直す |"
echo
echo "**\`follower-snapshots/YYYY-MM-DD.json\` の \`count\` が正しい記録**"
echo "（\`followers\` はハンドルの配列で人数ではない。docs/follower-tracking.md）。"

echo
echo "## 5. 費用"
echo
echo "**\`grep\` と \`stat\` だけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "follower-history の読み手を洗う / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
