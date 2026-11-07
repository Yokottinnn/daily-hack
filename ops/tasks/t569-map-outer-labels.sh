#!/bin/bash
# **イベントマップの外側（縮小したときに見える範囲）の駅と地名の位置を OpenStreetMap から取る（t569・2026-11-07）。** 読むだけ・LLM 不使用・$0。
# 2026-11-07 利用者「−ボタンで引いたとき、お台場エリア以外は一切表示されていないのが見栄えが悪い。湾岸エリア以外も地名や駅名くらいは表示させて」。
# 範囲は地図の縮小できる範囲（MAP_PAN）: 北西 35.7076,139.7145 〜 南東 35.5873,139.8414。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; mkdir -p "$RDIR"
OUT="$RDIR/t569-map-outer-labels.json"; MD="$RDIR/t569-map-outer-labels.md"
Q='[out:json][timeout:60];(node["railway"="station"]["name"](35.5873,139.7145,35.7076,139.8414);node["place"~"^(suburb|quarter)$"]["name"](35.5873,139.7145,35.7076,139.8414););out body;'
ok=0
for ep in https://overpass-api.de/api/interpreter https://overpass.kumi.systems/api/interpreter https://maps.mail.ru/osm/tools/overpass/api/interpreter; do
  if curl -sS -m 90 --data-urlencode "data=$Q" "$ep" -o "$OUT.raw" 2>"$RDIR/t569.err"; then
    if node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$OUT.raw" 2>/dev/null; then ok=1; echo "ep=$ep"; break; fi
  fi
done
if [ "$ok" != 1 ]; then { echo "# t569 失敗"; echo; echo '```'; head -c 600 "$RDIR/t569.err" 2>/dev/null; head -c 400 "$OUT.raw" 2>/dev/null; echo '```'; } > "$MD"; rm -f "$OUT.raw"; echo "取れなかった"; exit 1; fi
node -e '
const fs=require("fs"); const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const st={}, pl=[];
for (const e of j.elements||[]) { const t=e.tags||{}; const name=t.name; if(!name) continue;
  if (t.railway==="station") { const k=name.replace(/駅$/,""); (st[k]=st[k]||{name:k,lat:0,lon:0,n:0,ops:new Set()}); st[k].lat+=e.lat; st[k].lon+=e.lon; st[k].n++; if(t.operator) st[k].ops.add(t.operator); }
  else pl.push({ name, kind:t.place, lat:+e.lat.toFixed(5), lon:+e.lon.toFixed(5) });
}
const stations=Object.values(st).map(s=>({name:s.name,lat:+(s.lat/s.n).toFixed(5),lon:+(s.lon/s.n).toFixed(5),count:s.n,operators:[...s.ops].slice(0,4)}));
const out={ generated:new Date().toISOString(), source:"OpenStreetMap contributors (Overpass API)", bbox:[35.5873,139.7145,35.7076,139.8414], stations, places:pl };
fs.writeFileSync(process.argv[2], JSON.stringify(out,null,1)+"\n");
fs.writeFileSync(process.argv[3], "# t569 外側の駅と地名\n\n駅 "+stations.length+" ・地名 "+pl.length+"\n");
console.log("駅",stations.length,"地名",pl.length);
' "$OUT.raw" "$OUT" "$MD"
rm -f "$OUT.raw" "$RDIR/t569.err"
