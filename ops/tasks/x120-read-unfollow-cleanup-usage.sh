#!/bin/bash
# **`unfollow-cleanup.js` が follower-history.json を何に使っているかを読む。**
# **測るだけ。費用 $0（grep するだけ・LLM を呼ばない）。**
#
# ## x119 で分かったところまで
#
# `follower-history.json`（**2026-05-23 で止まり、最後の行が `0 人` の誤読**）を
# 名指ししているのは **`unfollow-cleanup.js` だけ**だった（あとは全部 その `.bak`）。
#
# **だが x119 の grep は定数の宣言行しか出せていない。**
#
#   35: const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
#
# **これでは読み手か書き手か分からない。** 宣言だけして使っていない可能性もある。
# **変数名 `FOLLOWER_HISTORY` で引き直す必要がある。**
#
# ## なぜ急ぐか
#
# **`unfollow-cleanup` はフォローを外す側。** もし
# 「フォロワーが減った ＝ 外された ＝ こちらも外す」のような判定に使っていると、
# **`0 人` を読んだ瞬間に全員 が『減った』ことになる。**
#
# フォロワーを 300 人 に増やそうとしている最中に、**外す側が誤爆していないかを見る。**
#
# ## 何を出すか
#
#   ① `FOLLOWER_HISTORY` を使っている全行（前後 6 行）
#   ② readFileSync / writeFileSync のどちらか
#   ③ **この JS を起動している plist はどれか**（載っているか・最後に動いたのはいつか）
#   ④ 直近のログ（外した件数が出ていれば、それが一次情報）
#
# ## やらないこと
#
# **外さない。止めない。消さない。直さない。読むだけ**（最上位ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
JS="$W/scripts/unfollow-cleanup.js"
OUT="${OPS_REPORT_DIR:-/tmp}/read-unfollow-cleanup-usage.md"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"

{
echo "# unfollow-cleanup は follower-history を何に使っているか（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x119 で、名指ししているのは **\`unfollow-cleanup.js\` だけ**と分かった（他は \`.bak\`）。"
echo "> **だが出せたのは定数の宣言行だけで、読み手か書き手か分からない。**"
echo ">"
echo "> **これは フォローを外す側。** \`0 人\` を「全員 減った」と読む作りなら、"
echo "> **フォロワーを増やそうとしている最中に外す側が誤爆している。**"

echo
echo "## 1. 使っている全行（**変数名で引く**）"
echo
echo '```javascript'
if [ -f "$JS" ]; then
  grep -n -B6 -A6 'FOLLOWER_HISTORY' "$JS" 2>/dev/null | cut -c1-200 | sed 's/^/  /'
else
  echo "  **$JS が無い**"
fi
echo '```'

echo
echo "## 2. 読んでいるのか、書いているのか"
echo
echo '```'
if [ -f "$JS" ]; then
  echo "  --- 読み（readFileSync / existsSync）---"
  grep -n 'FOLLOWER_HISTORY' "$JS" 2>/dev/null \
    | grep -E 'readFileSync|existsSync|require\(' | cut -c1-180 | sed 's/^/    /' \
    || echo "    （無し）"
  echo "  --- 書き（writeFileSync / appendFileSync）---"
  grep -n 'FOLLOWER_HISTORY' "$JS" 2>/dev/null \
    | grep -E 'writeFileSync|appendFileSync|createWriteStream' | cut -c1-180 | sed 's/^/    /' \
    || echo "    （無し）"
  echo
  echo "  総出現回数: $(grep -c 'FOLLOWER_HISTORY' "$JS" | head -1)"
fi
echo '```'
echo
echo "**宣言だけで一度も使っていないなら、消してよい。** 上の 2 つが両方 空ならそれ。"

echo
echo "## 3. この JS を起動している plist はどれか"
echo
echo '```'
HITS="$(grep -rl 'unfollow-cleanup' "$LA" 2>/dev/null | head -10)"
if [ -z "$HITS" ]; then
  echo "  **LaunchAgents に該当が無い。** 誰も自動では起動していない"
else
  # **末尾に改行が無くても最後の 1 行を読む**（最上位ルール 14）
  printf '%s\n' "$HITS" | while IFS= read -r p || [ -n "$p" ]; do
    [ -z "$p" ] && continue
    L="$(basename "$p" .plist)"
    echo "  ===== $L ====="
    echo "    plist: $p"
    case "$p" in *.disabled) echo "    **.disabled なので載らない**" ;; esac
    P="$(launchctl print "gui/$UID_N/$L" 2>&1)"
    if printf '%s' "$P" | grep -q 'Could not find service'; then
      echo "    **載っていない**"
    else
      printf '%s' "$P" | grep -E '^[[:space:]]*(state|runs|program) = |last exit code = ' \
        | head -6 | sed 's/^/    /'
    fi
  done
fi
echo '```'
echo
echo "**\`launchctl list | grep\` では見ない**（載っていても出ないことがある・最上位ルール 13）。"

echo
echo "## 4. 直近のログ（**外した件数が出ていれば、それが一次情報**）"
echo
echo '```'
FOUND=0
for f in "$W/logs/"*unfollow*.log "$W/logs/"*cleanup*.log; do
  [ -f "$f" ] || continue
  FOUND=1
  echo "  ===== $(basename "$f") / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null) ====="
  tail -12 "$f" 2>/dev/null | cut -c1-170 | sed 's/^/    /'
  echo
done
[ "$FOUND" = "0" ] && echo "  （unfollow / cleanup のログが無い）"
echo '```'

echo
echo "## 5. 読み方（**このタスクでは直さない**）"
echo
echo "| 出方 | 次の一手 |"
echo "| --- | --- |"
echo "| 宣言だけで未使用 | **ファイルごと消してよい。** 定数の行も消す |"
echo "| 書き手だけ | **4 か月 書けていない。** 止めるか、\`follower-snapshots/\` に寄せる |"
echo "| **読み手が在り、plist が載っている** | **いま誤爆しうる。最優先で直す** |"
echo "| 読み手が在るが plist が載っていない | 動いていないので急がない。直すときに一緒に直す |"
echo
echo "**正しい記録は \`follower-snapshots/YYYY-MM-DD.json\` の \`count\`**"
echo "（\`followers\` はハンドルの配列で人数ではない。docs/follower-tracking.md）。"

echo
echo "## 6. 費用"
echo
echo "**\`grep\` と \`launchctl print\` だけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "unfollow-cleanup の使い方を読む / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
