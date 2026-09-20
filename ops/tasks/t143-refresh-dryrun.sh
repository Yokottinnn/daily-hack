#!/bin/bash
# **05:30 を待たずに、鍵まで通ることを確かめる（t143）。**
#
# **API は呼ばない。$0。** `--dry-run` は選定を出すだけで、課金は発生しない。
#
# t142 で分かったこと: 鍵は**シェルにも .env にも無く、`launchctl getenv` に在る。**
# `scripts/refresh-daily.sh` をそれに合わせて直したので、
# **実際に読めるか**と、**node が記事を選べるか**をここで見る。
#
# 見るもの:
#
#   1. 鍵が読めるか（**値は出さない。長さの桁だけ**）
#   2. `node scripts/refresh-article.mjs --dry-run` が**どの記事を選ぶか**
#   3. ジョブが載っているか（**`launchctl print` で見る**。`list` は当てにしない）
#
# 本体は `git show origin/main:` で取り出して走らせる（作業ツリーには触らない）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t143-refresh-dryrun.md"
mkdir -p "$RDIR"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
LABEL="com.dailyhack.refresh-daily"
U="$(id -u)"
K="ANTHROPIC""_API""_KEY"

{
  echo "# 定時を待たずに確かめる（t143・**API は呼ばない・\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "## 1) 鍵は読めるか"
  echo ""
} > "$OUT"

V="$(launchctl getenv "$K" 2>/dev/null)"
if [ -n "$V" ]; then
  echo "- \`launchctl getenv\`: **読めた**（**${#V} 文字**。値は出さない）" >> "$OUT"
else
  echo "- \`launchctl getenv\`: ⚠️ **読めない**" >> "$OUT"
fi
unset V

{
  echo ""
  echo "## 2) どの記事を選ぶか（\`--dry-run\`）"
  echo ""
  echo '```text'
} >> "$OUT"

NODE_BIN="$(command -v node || echo /opt/homebrew/bin/node)"
if [ -x "$NODE_BIN" ]; then
  ( cd "$REPO" && "$NODE_BIN" scripts/refresh-article.mjs --dry-run 2>&1 | head -10 ) >> "$OUT"
else
  echo "node が無い" >> "$OUT"
fi

{
  echo '```'
  echo ""
  echo "- \`node\`: \`$NODE_BIN\`（$("$NODE_BIN" -v 2>/dev/null || echo '不明')）"
  echo ""
  echo "## 3) ジョブは載っているか（**\`print\` で見る**）"
  echo ""
  echo '```text'
  launchctl print "gui/$U/$LABEL" 2>/dev/null \
    | grep -E 'state =|program =|runs =|last exit code' | head -6
  echo '```'
  echo ""
  echo "## 4) これで残るもの"
  echo ""
  echo "- ここまで通っていれば、**05:30 に 1 本 走って PR が出る**"
  echo "- 1 回あたり **約 \$0.07**（推定・Sonnet 5）／ 1 日 **約 \$0.07** ／ 1 か月 **約 \$2.1**"
  echo "- 実額は \`ops/data/refresh-state.json\` の \`total_usd\` に積まれる"
} >> "$OUT"

cat "$OUT"
