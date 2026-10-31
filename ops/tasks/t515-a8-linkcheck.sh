#!/bin/bash
# **記事のバナー（ふるさと本舗・au PAY ふるさと納税・一休・ユアマイスター）が、提携サイト向けの広告リンクか、セルフバックかを A8 の画面で確かめる（t515）。** 読むだけ・$0。
# 2026-10-31 利用者「もっともっと案件は増やしてね。制限する必要が無いので、アフィリエイトで収益を最大化することを念頭に」→ 申請の都度の確認は要らない（CLAUDE.md・決定ログ 2026-10-31）。
# 再認証の画面は asp-probe.mjs の a8Reauth が Keychain で通す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t515-a8-apply.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の広告リンクの出どころ（t515・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
A8_IDS=s00000025743001,s00000023934001,s00000000218001,s00000020962001 ASP_PROBE=a8linkcheck OPS_REPORT_DIR="$RDIR" run_limited 280 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cat "$RDIR/asp-probe/a8linkcheck.md" >> "$OUT" 2>/dev/null; cp "$RDIR/asp-probe/a8linkcheck.md" "$RDIR/asp-probe/a8linkcheck-t515.md" 2>/dev/null
head -c 6000 "$OUT"
