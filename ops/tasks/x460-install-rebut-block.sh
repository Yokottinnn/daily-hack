#!/bin/bash
# x460（2026-11-10・$0）: 返信の出口の検査（tone-gate）に「言い負かす書き方は送らない」を足す。
# 利用者がダイアログで「言い負かす返信を止める」を選んだ（「税制上変わらなくない？😏」「銘柄の選別ミス？」）。
# reply-tone-rules.json（block_patterns.rebut）を Mac に配る。前のものは .bak を残す。LLM を呼ばない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x460-install-rebut-block.md"; STAMP="$(date '+%Y%m%d-%H%M%S')"
DST="$W/data/reply-tone-rules.json"; TMP="$W/data/.x460-reply-tone-rules.json"
{
echo "# 言い負かす返信を送らない（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null || true
if git -C "$REPO" show origin/main:ops/data/reply-tone-rules.json > "$TMP" 2>/dev/null && "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$TMP"; then
  [ -f "$DST" ] && cp -p "$DST" "$DST.bak.$STAMP"; mv "$TMP" "$DST"; echo "  入れた: $DST（前のものは .bak.$STAMP）"
else echo "  **取れない・JSON が壊れている**"; rm -f "$TMP"; fi
echo "--- 試す（tone-gate.cjs に通す）"
for t in "新NISAの非課税枠を国債で埋めるのと、通常口座で買うのって税制上変わらなくない？😏" "ぐんま名月、アタシも好きよ。今年のやつ、甘さとか去年と比べて変わった？"; do
  printf '%s' "{\"ok\":true,\"text\":\"$t\"}" | "$NODE_BIN" "$W/scripts/tone-gate.cjs" 2>&1 | head -2 | cut -c1-200
done
echo "  （1 つ目が ok:false、2 つ目が ok:true なら正しい）"
echo '```'
} > "$OUT" 2>&1
grep -cE '"ok":false' "$OUT" | sed 's/^/ok:false の行: /'
exit 0
