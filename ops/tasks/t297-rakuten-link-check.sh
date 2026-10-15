#!/bin/bash
# **楽天アフィリエイトのリンクの形を確かめる（t297）。** 記事に入れる前に、実際に開いて飛び先を見る。読むだけ・LLM 不使用・**$0**。
# ID は 2026-10-14 に取った個人名義のもの（docs/affiliate-registry.md）。形を推測で記事に書かない（blog-article スキル）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$RDIR/t297-rakuten-link-check.md"; mkdir -p "$RDIR"
ID="587f2635.77bb335f.587f2636.e34c8733"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
{ echo "# 楽天リンクの飛び先（t297・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
enc() { /usr/bin/python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$1"; }
for T in "https://event.rakuten.co.jp/furusato/" "https://travel.rakuten.co.jp/HOTEL/5547/5547.html" "https://event.travel.rakuten.co.jp/special/sales/"; do
  E="$(enc "$T")"
  L="https://hb.afl.rakuten.co.jp/hgc/$ID/?pc=$E&m=$E"
  R="$(curl -s -o /dev/null -L --max-time 25 -A "$UA" -w '%{http_code} %{num_redirects} %{url_effective}' "$L")"
  echo "- 元: \`$T\`" >> "$OUT"; echo "  - リンク: \`$L\`" >> "$OUT"; echo "  - 結果: \`$R\`（状態 / 転送回数 / 最後の URL）" >> "$OUT"
  H="$(curl -s -D - -o /dev/null --max-time 25 -A "$UA" "$L" | tr -d '\r' | awk 'tolower($1)=="location:"{print $2; exit}')"
  echo "  - 1 回目の転送先: \`${H:-なし}\`" >> "$OUT"
done
cat "$OUT"
