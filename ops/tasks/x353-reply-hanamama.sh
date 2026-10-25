#!/bin/bash
# **はな🌷さん（status/2114189203710132540）へ応援の返信を 1 件 出す（x353）。LLM 不使用・$0。**
# 利用者「この投稿に応援のコメントしておいて」「特に確認不要なので、深いこと考えずにさっとやっておいて」→ 文面をダイアログで見せて「投稿して」をもらった（2026-10-26）。
POST_APPROVAL_QUOTE="投稿して"
POST_APPROVAL_AT="2026-10-26 ダイアログの回答（はな🌷さんへの応援の返信の文面を示した問いに、その他で記入）"
POST_SET_KEY="reply-hanamama"
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x353-reply-hanamama.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
# シャドウバン対策の関所（x352）を通す
[ -f "$W/lib/x-action-guard.cjs" ] && export NODE_OPTIONS="${NODE_OPTIONS:-} --require $W/lib/x-action-guard.cjs"
TEXT_B64="5bm05YaF44Gr5Y+O55uK5YyW44CB44Ki44K/44K344KC54uZ44Gj44Gm44KL44Gu44KI44CC5q+O5pel44Oq44Ki44Or44KS6LyJ44Gb44KL44Gu6KaL44Gm44KL44GL44KJ44CB5LiA57eS44Gr6LWw44KK5YiH44KK44G+44GX44KH8J+Sqg=="
TARGET="https://x.com/hanamama_3/status/2114189203710132540"
LOCK="$W/data/.x353-done"
{
echo "# はな🌷さんへの応援の返信（$(date '+%Y-%m-%d %H:%M:%S') JST・$0）"
if [ -f "$LOCK" ]; then echo "もう出した（$(cat "$LOCK")）。二度は出さない。"; else
echo '```'
cd "$W" && RES=$("$NODE_BIN" scripts/post-comment.js "$TEXT_B64" "$TARGET" 2>/tmp/x353.err | tail -1)
echo "$RES"
tail -5 /tmp/x353.err 2>/dev/null | grep -E 'x-action|error|Error' || true
echo '```'
case "$RES" in *'"ok":true'*) echo "$RES" > "$LOCK"; echo "**出た。**";; *) echo "**出ていない。**";; esac
fi
} > "$OUT" 2>&1
echo "x353 / $(basename "$OUT")"
