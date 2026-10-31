#!/bin/bash
# **A8 の未提携の案件にまとめて提携申請する（t450・20/28）。** LLM 不使用・**$0**。
# 2026-10-31 利用者「もっともっと案件は増やしてね。制限する必要が無いので、アフィリエイトで収益を最大化することを念頭に」→ 申請の都度の確認は要らない（CLAUDE.md・決定ログ 2026-10-31）。
# 候補は t428〜t430（ブログの題材 42 語の検索）の未提携 571 件から、アダルト・出会い・ギャンブル・カードローン・法人向け・ポイントサイト専用などを除いた 444 件。
# 再認証の画面は asp-probe.mjs の a8Reauth が Keychain で通す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t450-a8-apply.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の提携申請 16 件（t450・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
A8_IDS=s00000023614001,s00000008115003,s00000025337003,s00000025337002,s00000025337001,s00000008115001,s00000024962001,s00000024360001,s00000000064010,s00000024605001,s00000021681001,s00000021288017,s00000023526001,s00000021288005,s00000026800001,s00000024055001 ASP_PROBE=a8apply OPS_REPORT_DIR="$RDIR" run_limited 280 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cat "$RDIR/asp-probe/a8apply.md" >> "$OUT" 2>/dev/null; cp "$RDIR/asp-probe/a8apply.md" "$RDIR/asp-probe/a8apply-t450.md" 2>/dev/null
head -c 6000 "$OUT"
