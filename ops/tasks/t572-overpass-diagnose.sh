#!/bin/bash
# **Overpass が路線の問い合わせに何を返しているかを測る（t572）。** t570・t571 が失敗し、中身が残らなかった。読むだけ・$0。
# あわせて別の取り先（Wikidata の SPARQL）に繋がるかを見る。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; mkdir -p "$RDIR"; MD="$RDIR/t572-overpass-diagnose.md"
BB='35.5873,139.7145,35.7076,139.8414'
show() { local ep="$1" q="$2" f="$RDIR/.t572.out"; local code; code=$(curl -sS -m 70 -w '%{http_code}' --data-urlencode "data=$q" "$ep" -o "$f" 2>&1 | tail -1)
  echo "- $ep → HTTP $code / $(wc -c < "$f" 2>/dev/null | tr -d ' ') bytes"; echo '```'; sed -e 's/<[^>]*>/ /g' "$f" 2>/dev/null | tr -s ' \n\t' ' ' | head -c 400; echo; echo '```'; rm -f "$f"; }
{
echo "# t572 Overpass の診断（$(date '+%Y-%m-%d %H:%M:%S')）"; echo
echo "## 小さな問い合わせ（駅 1 か所の周り）"; show https://overpass-api.de/api/interpreter '[out:json][timeout:25];node["railway"="station"](35.68,139.76,35.682,139.768);out;'
echo "## 状態"; echo '```'; curl -sS -m 20 https://overpass-api.de/api/status 2>&1 | head -c 500; echo; echo '```'
for ep in https://overpass-api.de/api/interpreter https://overpass.kumi.systems/api/interpreter https://maps.mail.ru/osm/tools/overpass/api/interpreter; do
  echo "## 路線の一覧（$ep）"; show "$ep" "[out:json][timeout:120];relation[\"route\"=\"subway\"]($BB);out tags;"; sleep 3; done
echo "## Wikidata（東京の駅と路線・路線の色）"
SQ='SELECT ?s ?sL ?coord ?line ?lineL ?col WHERE { ?s wdt:P31/wdt:P279* wd:Q55488; wdt:P625 ?coord; wdt:P81 ?line. OPTIONAL{?line wdt:P465 ?col} SERVICE wikibase:box { ?s wdt:P625 ?coord. bd:serviceParam wikibase:cornerSouthWest "Point(139.7145 35.5873)"^^geo:wktLiteral. bd:serviceParam wikibase:cornerNorthEast "Point(139.8414 35.7076)"^^geo:wktLiteral. } SERVICE wikibase:label { bd:serviceParam wikibase:language "ja". } } LIMIT 5'
code=$(curl -sS -m 60 -G -w '%{http_code}' -H 'Accept: application/sparql-results+json' -H 'User-Agent: daily-hack-map/1.0' --data-urlencode "query=$SQ" https://query.wikidata.org/sparql -o "$RDIR/.t572.wd" 2>&1 | tail -1)
echo "- HTTP $code / $(wc -c < "$RDIR/.t572.wd" | tr -d ' ') bytes"; echo '```'; head -c 900 "$RDIR/.t572.wd"; echo; echo '```'; rm -f "$RDIR/.t572.wd"
} > "$MD" 2>&1
echo "done"
