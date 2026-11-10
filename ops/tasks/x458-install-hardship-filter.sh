#!/bin/bash
# x458（2026-11-10・$0）: 返信の相手選び（ng-filter）に「損・借金・トラブルを書いた投稿は外す」を足す。
# 利用者がダイアログで「損を書いた投稿には返信しない」を選んだ（x455/x456 で 3 日 67 件中 5 件が、含み損・借金に踏み込んだ返信だった）。
# reply-ng-rules.json（hardship_words）と reply-ng-check.cjs（判定 2-B）を Mac に配る。**古いものは .bak を残す。** LLM を呼ばない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x458-install-hardship-filter.md"; STAMP="$(date '+%Y%m%d-%H%M%S')"
{
echo "# 損・借金を書いた投稿を返信の相手から外す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null || true
ok=1
for pair in "ops/data/reply-ng-rules.json:$W/data/reply-ng-rules.json" "ops/lib/reply-ng-check.cjs:$W/scripts/reply-ng-check.cjs"; do
  src="${pair%%:*}"; dst="${pair#*:}"; tmp="$(dirname "$dst")/.x458-$(basename "$dst")"
  git -C "$REPO" show "origin/main:$src" > "$tmp" 2>/dev/null || { echo "  取れない: $src"; ok=0; continue; }
  case "$dst" in *.json) "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$tmp" || { echo "  JSON が壊れている: $src"; ok=0; rm -f "$tmp"; continue; };; *.cjs) "$NODE_BIN" --check "$tmp" || { echo "  構文エラー: $src"; ok=0; rm -f "$tmp"; continue; };; esac
  [ -f "$dst" ] && cp -p "$dst" "$dst.bak.$STAMP"
  mv "$tmp" "$dst"; echo "  入れた: $dst（前のものは .bak.$STAMP）"
done
echo "--- 試す（入れたものを、ng-filter-candidates.cjs を通して）"
printf '%s' '[{"text":"私の証券口座、前月比 -700000を超えてるよ #新NISA"},{"text":"【10月】借金90万円生活のリアルな家計簿"},{"text":"ふるさと納税の返礼品、我が家は米です #ポイ活"},{"text":"10月の電気代は13,049円でした"}]' \
 | "$NODE_BIN" "$W/scripts/ng-filter-candidates.cjs" 2>&1 >"$W/.x458-out.json" | head -6
echo "  残った候補: $("$NODE_BIN" -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).length)' "$W/.x458-out.json" 2>&1) 件（4 件中、2 件残れば正しい）"
rm -f "$W/.x458-out.json"
[ "$ok" = 1 ] && echo "  → 入れ終わった" || echo "  → **一部入っていない**"
echo '```'
} > "$OUT" 2>&1
grep -E '→|残った候補' "$OUT" | head -2
exit 0
