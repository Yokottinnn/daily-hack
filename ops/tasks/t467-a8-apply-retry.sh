#!/bin/bash
# **A8 の未提携の案件に提携申請をやり直す（t467・再申請 8/12）。** LLM 不使用・**$0**。
# 2026-10-31 利用者「もっともっと案件は増やしてね。制限する必要が無いので、アフィリエイトで収益を最大化することを念頭に」→ 申請の都度の確認は要らない（CLAUDE.md・決定ログ 2026-10-31）。
# t431〜t458 で「提携申請が失敗しました」「処理中です」「申請欄が無い（未提携）」になった 118 件をやり直す。続けて押すと失敗するので 1 件ごとに 8 秒あける。
# 再認証の画面は asp-probe.mjs の a8Reauth が Keychain で通す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t467-a8-apply.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の提携申請のやり直し 10 件（t467・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
[ -n "$NODE_BIN" ] || { echo "⚠️ node が無い" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
echo '```text' >> "$OUT"
JS="$RDIR/.asp-probe.mjs"
git -C "$REPO" show origin/main:scripts/asp/asp-probe.mjs > "$JS"
A8_GAP_MS=8000 A8_IDS=s00000015892032,s00000013124002,s00000022400001,s00000020286001,s00000023687001,s00000016397001,s00000021220003,s00000023934001,s00000027240002,s00000024389001 ASP_PROBE=a8apply OPS_REPORT_DIR="$RDIR" run_limited 280 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cat "$RDIR/asp-probe/a8apply.md" >> "$OUT" 2>/dev/null; cp "$RDIR/asp-probe/a8apply.md" "$RDIR/asp-probe/a8apply-t467.md" 2>/dev/null
head -c 6000 "$OUT"
