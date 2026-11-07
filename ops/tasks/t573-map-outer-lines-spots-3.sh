#!/bin/bash
# **イベントマップの外側に引く鉄道の路線（駅の並び・路線の色）と、名所の位置を OpenStreetMap から取る（t573・2026-11-07）。** 読むだけ・LLM 不使用・$0。
# t572 の診断: overpass-api.de は User-Agent の無い問い合わせを 406 で断る（予備の窓口は混雑で 504）。名乗りを付けた。
# t570 は 1 回の問い合わせが重く、Overpass がエラーの画面を返した。路線・停車駅・名所の 3 回に分け、間を空け、エラーの中身を記録する。
# 2026-11-07 利用者「各駅の路線と、最低限の有名スポットだけはマッピングしたい。高輪ゲートウェイとか六本木ヒルズとか皇居とか」。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; mkdir -p "$RDIR"
OUT="$RDIR/t573-map-outer-lines-spots.json"; MD="$RDIR/t573-map-outer-lines-spots.md"
BB='35.5873,139.7145,35.7076,139.8414'
Q1a="[out:json][timeout:180];relation[\"route\"~\"^(subway|train|monorail)\$\"]($BB);out body;"
Q1b="[out:json][timeout:180];relation[\"route\"~\"^(subway|train|monorail)\$\"]($BB)->.r;node(r.r:\"stop\");out skel;"
SP='皇居|東京タワー|六本木ヒルズ|六本木ヒルズ森タワー|東京ミッドタウン|高輪ゲートウェイシティ|TAKANAWA GATEWAY CITY|国会議事堂|日比谷公園|浜離宮恩賜庭園|増上寺|東京国際フォーラム|歌舞伎座|麻布台ヒルズ|虎ノ門ヒルズ|東京スカイツリー|両国国技館|清澄庭園|夢の島公園|葛西臨海公園|品川シーズンテラス|しながわ水族館|大井競馬場|東京駅|皇居外苑|北の丸公園|新宿御苑|明治神宮外苑|東京ドーム|上野恩賜公園|浅草寺'
Q2="[out:json][timeout:60];nwr[\"name\"~\"^($SP)\$\"]($BB);out center tags;"
ERRS=""
fetch() { local q="$1" o="$2"; for ep in https://overpass-api.de/api/interpreter https://overpass.kumi.systems/api/interpreter https://maps.mail.ru/osm/tools/overpass/api/interpreter; do
  curl -sS -m 100 -A "daily-hack-map/1.0 (+https://daily-hack.fieldbeside.com)" --data-urlencode "data=$q" "$ep" -o "$o" 2>/dev/null
  if node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$o" 2>/dev/null; then echo "$ep"; return 0; fi
  ERRS="$ERRS\n- $ep: $(sed -e 's/<[^>]*>//g' "$o" 2>/dev/null | tr -s ' \n' ' ' | grep -o 'runtime error[^.]*\|rate_limited[^.]*\|Too Many[^.]*\|timeout[^.]*' | head -1 | cut -c1-160)"
  sleep 4; done; return 1; }
E1=$(fetch "$Q1a" "$OUT.r1") || { printf "# t573 失敗（路線）%b
" "$ERRS" > "$MD"; rm -f "$OUT".r*; exit 1; }
sleep 5
E3=$(fetch "$Q1b" "$OUT.r3") || { printf "# t573 失敗（停車駅）%b
" "$ERRS" > "$MD"; rm -f "$OUT".r*; exit 1; }
sleep 5
E2=$(fetch "$Q2" "$OUT.r2") || { printf "# t573 失敗（名所）%b\n" "$ERRS" > "$MD"; rm -f "$OUT".r*; exit 1; }
node -e '
const fs=require("fs"); const a=JSON.parse(fs.readFileSync(process.argv[1],"utf8")), b=JSON.parse(fs.readFileSync(process.argv[2],"utf8")), c=JSON.parse(fs.readFileSync(process.argv[5],"utf8")); a.elements=a.elements.concat(c.elements);
const nodes={}; for (const e of a.elements) if (e.type==="node") nodes[e.id]=[+e.lat.toFixed(5),+e.lon.toFixed(5)];
const lines=[]; const seen=new Set();
for (const e of a.elements) { if (e.type!=="relation") continue; const t=e.tags||{};
  const pts=(e.members||[]).filter(m=>m.type==="node"&&/^stop/.test(m.role||"")&&nodes[m.ref]).map(m=>nodes[m.ref]);
  if (pts.length<2) continue;
  const name=t["name:ja"]||t.name||""; const ref=t.ref||""; const key=(t.network||"")+"|"+(t.operator||"")+"|"+ref+"|"+(t.colour||"")+"|"+pts.length+"|"+[pts[0],pts[pts.length-1]].sort().join();
  if (seen.has(key)) continue; seen.add(key);
  lines.push({ name, ref, route:t.route, colour:t.colour||"", operator:t.operator||"", network:t.network||"", pts });
}
const spots=[]; for (const e of b.elements) { const t=e.tags||{}; const c=e.center||{lat:e.lat,lon:e.lon}; if(!c||c.lat==null) continue; spots.push({ name:t.name, lat:+c.lat.toFixed(5), lon:+c.lon.toFixed(5), kind:t.tourism||t.leisure||t.building||t.amenity||t.historic||t.landuse||t.railway||"" }); }
fs.writeFileSync(process.argv[3], JSON.stringify({ generated:new Date().toISOString(), source:"OpenStreetMap contributors (Overpass API)", lines, spots }, null, 0)+"\n");
fs.writeFileSync(process.argv[4], "# t573\n\n路線 "+lines.length+" ・名所 "+spots.length+"\n\n"+[...new Set(lines.map(l=>l.name))].slice(0,80).join(" / ")+"\n\n"+spots.map(s=>s.name).join(" / ")+"\n");
console.log("路線",lines.length,"名所",spots.length);
' "$OUT.r1" "$OUT.r2" "$OUT" "$MD" "$OUT.r3"
rm -f "$OUT.r1" "$OUT.r2" "$OUT.r3"
