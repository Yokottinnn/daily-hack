#!/bin/bash
# **鍵を本当に読めるところまで持っていく（t144）。API は呼ばない・$0。**
#
# ## t142 の判定が甘かった
#
#   launchctl getenv <名前> >/dev/null 2>&1 && echo 在る    ← **rc しか見ていない**
#
# **`launchctl getenv` は未設定でも rc=0 を返す。** 最上位ルール 13 そのもので、
# t143 で値を取ったら**空だった。** ここでは**値の長さ**まで見る。
#
# 実体は plist の `EnvironmentVariables`（t142 の 1 節目）。
# `scripts/refresh-daily.sh` をそこから読むように直したので、**同じ順番で辿って**確かめる。
#
# ## もう 1 つ: `--dry-run` が古い記事を選んだ
#
# t143 は `may-2026-bank-campaigns-roundup` を選んだ。**作業ツリーが古いから。**
# 本番は `reset --hard origin/main` してから走るので、そちらに合わせて
# **origin/main を一時ディレクトリに展開して**選ばせる。
#
# **値は出さない。長さの桁だけ。**

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t144-refresh-key-verify.md"
mkdir -p "$RDIR"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
K="ANTHROPIC""_API""_KEY"

{
  echo "# 鍵を読めるところまで（t144・**API は呼ばない・\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "## 1) 順番に辿る（**長さだけ出す。値は出さない**）"
  echo ""
} > "$OUT"

FOUND=""
V="$(printenv "$K" 2>/dev/null)"
if [ -n "$V" ]; then FOUND="環境変数"; else echo "- 環境変数: 空" >> "$OUT"; fi

if [ -z "$FOUND" ]; then
  V="$(launchctl getenv "$K" 2>/dev/null)"
  if [ -n "$V" ]; then FOUND="launchctl getenv"
  else echo "- \`launchctl getenv\`: **rc は 0 でも値は空**（← t142 はここを取り違えた）" >> "$OUT"; fi
fi

if [ -z "$FOUND" ]; then
  for P in "$HOME/Library/LaunchAgents/com.bubblesnow.remote.plist" \
           "$HOME/Library/LaunchAgents/com.bubblesnow.remote.daily-hack.plist" \
           "$HOME/Library/LaunchAgents/com.bubblesnow.remote.daily-hack-blog.plist"; do
    [ -f "$P" ] || continue
    V="$(plutil -extract "EnvironmentVariables.$K" raw -o - "$P" 2>/dev/null)"
    if [ -n "$V" ]; then FOUND="plist: $(basename "$P")"; break; fi
    echo "- \`$(basename "$P")\`: 取り出せない" >> "$OUT"
  done
fi

if [ -n "$FOUND" ]; then
  echo "- ✅ **読めた** → $FOUND（**${#V} 文字**。値は出さない）" >> "$OUT"
else
  echo "- ⚠️ **どこからも読めない。** 新しい鍵を置いてもらう必要がある" >> "$OUT"
fi
unset V

{
  echo ""
  echo "## 2) 本番と同じ状態で選ばせる（origin/main を展開）"
  echo ""
  echo '```text'
} >> "$OUT"

TMP="$(mktemp -d)"
NODE_BIN="$(command -v node || echo /opt/homebrew/bin/node)"
if git -C "$REPO" archive origin/main | tar -x -C "$TMP" 2>/dev/null && [ -x "$NODE_BIN" ]; then
  ( cd "$TMP" && "$NODE_BIN" scripts/refresh-article.mjs --dry-run 2>&1 | head -6 ) >> "$OUT"
else
  echo "展開できなかった" >> "$OUT"
fi
rm -rf "$TMP"

{
  echo '```'
  echo ""
  echo "**\`ops/data/unindexed.txt\` の先頭が出ていれば正しい**（未インデックスの記事から回す）。"
  echo ""
  echo "## 3) 残り"
  echo ""
  echo "- 1) が ✅ なら、**05:30 に 1 本 走って PR が出る**"
  echo "- 1 回 **約 \$0.07**（推定・Sonnet 5）／ 1 日 **約 \$0.07** ／ 1 か月 **約 \$2.1**"
} >> "$OUT"

cat "$OUT"
