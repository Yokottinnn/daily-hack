#!/bin/bash
# **楽天だけ asp-sync を走らせ、ログインの各段階（URL・入力欄の文字数・エラー文）を出す（t243）。**
# LLM 不使用・**$0**。本体は scripts/asp/asp-sync.mjs（毎回 origin/main から取り出す）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t243-asp-sync-rakuten-debug3.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# asp-sync を 1 回 走らせる（t243・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
[ -n "$NODE_BIN" ] || { echo "⚠️ node が無い" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
echo "| ASP | Keychain |" >> "$OUT"; echo "| --- | --- |" >> "$OUT"
for id in a8 moshimo vc rakuten; do
  /usr/bin/security find-generic-password -s "dailyhack-asp-$id" >/dev/null 2>&1 && r="**在る**" || r="無い"
  echo "| $id | $r |" >> "$OUT"
done
echo "" >> "$OUT"
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
JS="$RDIR/.asp-sync.mjs"
git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$JS"
echo '```text' >> "$OUT"
ASP_ONLY=rakuten OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=220000 run_limited 240 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 2000 "$OUT"
# 楽天のログインの各段階（値は出さない）
/opt/homebrew/bin/node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(JSON.stringify(s.providers.rakuten,null,1))' "$RDIR/asp-sync/status.json" >> "$OUT" 2>&1
