#!/bin/bash
# **週次レポートが走らせている実体を、リポジトリの版に入れ替える。**
#
# ## t080 で分かったこと
#
# plist が叩いているのは **リポジトリの外のコピー**だった。
#
#     com.dailyhack.weekly-blog-report.plist
#       ["/opt/homebrew/bin/python3.11", "/Users/ny/scripts/weekly-blog-report.py"]
#                                          ^^^^^^^^^^^^^^^^ リポジトリではない
#
# **だからリポジトリ側をいくら直しても、出てくるレポートは変わらない。**
# 2026-08-31 に見つけた `${ALL_VISITS}` 未展開が、9/6 に直したあとも
# 9/14 のレポートに出続けていたのはこれが理由。
#
# ## やること
#
#   1. いまの `/Users/ny/scripts/weekly-blog-report.py` を**日付つきで退避**
#   2. リポジトリの版を同じ場所へ**コピー**（plist は触らない）
#   3. `--help` 相当で**構文が通ることだけ**確かめる（本番実行はしない）
#
# **plist は tweet2 の所有（docs/session-roles.md）なので触らない。**
# 指している先のファイルを入れ替えるだけにする。
#
# ## 前提
#
# **t081 でクローンが main に追いついていること。** 追いついていなければ
# リポジトリ側に新しい版が無いので、**何もせずに止まる。**
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t082-install-weekly-report.md"
mkdir -p "$RDIR"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SRC="$REPO/scripts/weekly-blog-report.py"
DST="${WEEKLY_REPORT_DST:-$HOME/scripts/weekly-blog-report.py}"

{
  echo "# 週次レポートの実体を入れ替える（t082）"
  echo
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo
  echo "| | パス |"
  echo "| --- | --- |"
  echo "| コピー元（リポジトリ） | \`$SRC\` |"
  echo "| コピー先（plist が叩く先） | \`$DST\` |"
  echo
} > "$OUT"

if [ ! -f "$SRC" ]; then
  {
    echo "🚨 **コピー元が無い。何もしていない。**"
    echo
    echo "t081 でクローンが main に追いついていない可能性が高い。"
    echo "先に t081 の結果を見ること。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi

# **Python 版であることを確かめてから入れ替える。**
# 当て推量で上書きしない（CLAUDE.md「当て推量でファイルを作らない」）。
if ! head -3 "$SRC" | grep -q "python3"; then
  echo "🚨 **コピー元が Python スクリプトに見えない。何もしていない。**" >> "$OUT"
  cat "$OUT"; exit 0
fi

{
  echo "## 着手前の状態"
  echo
  if [ -f "$DST" ]; then
    echo "- コピー先は **ある**（$(wc -l < "$DST" | tr -d ' ') 行）"
    echo "- 1 行目: \`$(head -1 "$DST")\`"
    echo "- \`\${ALL_VISITS}\` を含む行数: **$(grep -c 'ALL_VISITS' "$DST" 2>/dev/null || echo 0)**"
  else
    echo "- コピー先は **無い**（plist が存在しないファイルを叩いている）"
  fi
  echo "- コピー元は $(wc -l < "$SRC" | tr -d ' ') 行"
  echo
} >> "$OUT"

mkdir -p "$(dirname "$DST")"

BAK=""
if [ -f "$DST" ]; then
  BAK="$DST.bak-$(date '+%Y%m%d-%H%M%S')"
  cp "$DST" "$BAK"
fi

cp "$SRC" "$DST"
chmod +x "$DST" 2>/dev/null || true

PY="/opt/homebrew/bin/python3.11"
command -v "$PY" >/dev/null 2>&1 || PY="python3"

{
  echo "## 入れ替えた"
  echo
  [ -n "$BAK" ] && echo "- 退避: \`$BAK\`" || echo "- 退避: （元ファイルが無かったので無し）"
  echo "- コピー先は $(wc -l < "$DST" | tr -d ' ') 行になった"
  echo
  echo "## 確かめる（**rc=0 では足りない・最上位ルール 13**）"
  echo
  # 構文検査。**本番実行はしない**（API を叩くうえ 5 分 を超えうる）
  if "$PY" -m py_compile "$DST" 2>/tmp/t082-compile.err; then
    echo "- ✅ \`$PY -m py_compile\` **通った**"
  else
    echo "- 🚨 **構文検査で落ちた。退避から戻す。**"
    echo
    echo '```'
    head -20 /tmp/t082-compile.err
    echo '```'
    [ -n "$BAK" ] && cp "$BAK" "$DST" && echo "（戻した）"
  fi
  echo "- 1 行目: \`$(head -1 "$DST")\`"
  echo "- 中身が同じか: $(cmp -s "$SRC" "$DST" && echo '**リポジトリ版と一致**' || echo '🚨 一致しない')"
  echo
  echo "## 次の週次レポートで見ること"
  echo
  echo "**\`\${ALL_VISITS}\` が数字になっていること。** なっていなければ、"
  echo "plist が別の場所を指しているか、python3.11 に依存が入っていない。"
} >> "$OUT"

cat "$OUT"
exit 0
