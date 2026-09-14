#!/bin/bash
# **入れ替えた週次レポートが Mac で実際に動くかを確かめる。**（測るだけ）
#
# ## t084 で分かった、私の見立て違い
#
# 入れ替える前の `/Users/ny/scripts/weekly-blog-report.py` は
# **152 行の Python で、`ALL_VISITS` を 1 度も含んでいなかった。**
# つまり Slack に出ていた `${ALL_VISITS}` の出どころは、このファイルではない。
# **まだ特定できていない。** ここで探す。
#
# ## もう 1 つ、私が作った問題
#
# 入れた 811 行版は **`--slack` を付けないと Slack へ投稿しない。**
#
#     plist: ["/opt/homebrew/bin/python3.11", "/Users/ny/scripts/weekly-blog-report.py"]
#                                              ^ 引数なし
#
# **このままだと次の月曜、レポートが Slack に出ない。** 直す前に、
# まず「新しい版が Mac で本当に動くか」を確かめる。動かないなら直す意味がない。
#
# ## やること（**何も変更しない**）
#
#   1. `ALL_VISITS` を書いているファイルを Mac 全体から探す
#   2. 新しい版を **短い期間で 1 回 走らせる**（`--slack` は付けない＝投稿しない）
#   3. 動いたら marker を置く。t086 はそれを見てから plist を直す
#
# **API 料金は発生しない。** 使うのは Search Console API と Cloudflare API で、
# どちらも無料枠の読み取り。**LLM は使わない。$0/回・$0/日・$0/月。**
#
# **秘密は出さない。** 出力は公開リポジトリに載る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t085-weekly-report-verify.md"
MARKER="$HOME/.config/daily-hack/weekly-report-ok"
mkdir -p "$RDIR" "$(dirname "$MARKER")"
DST="${WEEKLY_REPORT_DST:-$HOME/scripts/weekly-blog-report.py}"

{
  echo "# 入れ替えた週次レポートは Mac で動くか（t085）"
  echo
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo
  echo "## 1. \`ALL_VISITS\` を書いているファイルを探す"
  echo
  echo '```'
} > "$OUT"
for d in "$HOME/scripts" "$HOME/openclaw" "$HOME/.openclaw" "$HOME/bin" "$HOME/Library/LaunchAgents"; do
  [ -d "$d" ] || continue
  grep -rl 'ALL_VISITS' "$d" 2>/dev/null | head -10
done >> "$OUT"
{
  echo '```'
  echo
  echo "（空なら、Slack の \`\${ALL_VISITS}\` は Mac のこれらの場所から出ていない）"
  echo
  echo "## 2. 新しい版を短い期間で 1 回 走らせる"
  echo
} >> "$OUT"

PY="/opt/homebrew/bin/python3.11"
command -v "$PY" >/dev/null 2>&1 || PY="python3"

if [ ! -f "$DST" ]; then
  echo "🚨 \`$DST\` が無い。t084 が効いていない。" >> "$OUT"
  rm -f "$MARKER"
  cat "$OUT"; exit 0
fi

# **--slack は付けない。** 投稿せず、標準出力に出すだけ。
t0=$(date +%s)
run_out="$("$PY" "$DST" --days 2 --gsc-days 3 --top 3 --top-pages 3 --top-queries 3 2>&1)"
rc=$?
t1=$(date +%s)

{
  echo "| 項目 | 値 |"
  echo "| --- | --- |"
  echo "| 終了コード | **$rc**（0 = 全部 取れた / 1 = 取れないものがあった） |"
  echo "| 所要 | $((t1 - t0)) 秒 |"
  echo "| 出力の行数 | $(printf '%s' "$run_out" | wc -l | tr -d ' ') |"
  echo
  echo "### 出力の先頭 40 行"
  echo
  echo '```'
  printf '%s\n' "$run_out" | head -40
  echo '```'
  echo
  echo "### \`\${\` が残っていないか（**未展開の変数がここで分かる**）"
  echo
  echo '```'
  printf '%s\n' "$run_out" | grep -n '\${' | head -10 || echo "(残っていない)"
  echo '```'
  echo
} >> "$OUT"

if [ "$(printf '%s' "$run_out" | wc -l | tr -d ' ')" -gt 10 ]; then
  date '+%Y-%m-%dT%H:%M:%S%z' > "$MARKER"
  echo "✅ **レポートが生成できた。** marker を置いた: \`$MARKER\`" >> "$OUT"
  echo "   t086 が plist に \`--slack\` を足してよい。" >> "$OUT"
else
  rm -f "$MARKER"
  echo "🚨 **レポートがほとんど出ていない。** marker は置かない。" >> "$OUT"
  echo "   この状態で \`--slack\` を足すと、空のレポートが Slack に出る。" >> "$OUT"
fi

cat "$OUT"
exit 0
