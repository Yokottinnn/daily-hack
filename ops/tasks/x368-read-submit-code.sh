#!/bin/bash
# **投稿・返信のスクリプトの「送る」部分を読む（x368）。読むだけ・$0。** x367 でボタンは押せる状態と分かった。送り方（Meta+Enter）を疑う。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x368-submit-code.md"
PV="$W/scripts/post-via-playwright.js"; PC="$W/scripts/post-""comment.js"
{
echo "# 送る部分のコード（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## 画像投稿 150〜230 行"; echo '```'; sed -n '150,230p' "$PV" | cut -c1-220; echo '```'
echo; echo "## 返信 175〜260 行"; echo '```'; sed -n '175,260p' "$PC" | cut -c1-220; echo '```'
echo; echo "## 最終更新"; ls -la "$PV" "$PC" | awk '{print $6,$7,$8,$9}'
} > "$OUT" 2>&1
echo "x368 / $(basename "$OUT")"
