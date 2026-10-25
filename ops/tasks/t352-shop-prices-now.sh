#!/bin/bash
# **3 店ボタンの価格を今すぐ 1 回取る（t352・affiliate）。** Yahoo! の Client ID が入った（t351 で API が通った）ので、明朝 6:40 を待たずに取る。LLM 不使用・**$0**。
# mac-weekly.sh の 2e と同じ。鍵は Keychain から環境変数で渡すだけで出さない。当たりがあるときだけ reports/board/shop-prices.json に置く
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t352-shop-prices-now.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
WORK="${TMPDIR:-/tmp}/t352"; rm -rf "$WORK"; mkdir -p "$WORK/shop-data" "$RDIR/board"
{ echo "# 3 店ボタンの価格を今すぐ取る（t352・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
git -C "$REPO" show origin/main:scripts/shop/fetch-prices.mjs > "$WORK/fetch.mjs"
for f in $(git -C "$REPO" ls-tree --name-only origin/main src/data/shop/); do git -C "$REPO" show "origin/main:$f" > "$WORK/shop-data/$(basename "$f")"; done
( export RAKUTEN_APP_ID="$(security find-generic-password -s dailyhack-rakuten-ws -a applicationId -w 2>/dev/null)"
  export RAKUTEN_ACCESS_KEY="$(security find-generic-password -s dailyhack-rakuten-ws -a accessKey -w 2>/dev/null)"
  export YAHOO_APP_ID="$(security find-generic-password -s dailyhack-yahoo-shopping -a clientId -w 2>/dev/null)"
  "$NODE_BIN" "$WORK/fetch.mjs" --dir "$WORK/shop-data" --out "$WORK/shop-prices.json" ) >> "$OUT" 2>&1
"$NODE_BIN" -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const c={}; for(const [s,rows] of Object.entries(j.series||{})) for(const r of Object.values(rows)) for(const [st,v] of Object.entries(r)){ const k=st+(v.found?" 当たり":v.skipped?" 鍵なし":v.error?" エラー":" 当たりなし"); c[k]=(c[k]||0)+1; }
console.log("- 結果: "+Object.entries(c).map(([k,v])=>k+" "+v).join("・")); console.log("- 鍵: "+JSON.stringify(j.keys)); (j.errors||[]).slice(0,5).forEach(e=>console.log("  - "+e));
const n=Object.values(c).length&&Object.entries(c).filter(([k])=>/当たり$/.test(k)).reduce((a,[,v])=>a+v,0); process.exit(n>0?0:1)' "$WORK/shop-prices.json" >> "$OUT" 2>&1 \
  && { cp "$WORK/shop-prices.json" "$RDIR/board/shop-prices.json"; echo "- reports/board/shop-prices.json に置いた" >> "$OUT"; } \
  || echo "- 当たりが無いので置かない" >> "$OUT"
echo "rc=0 / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 5000 "$OUT"
