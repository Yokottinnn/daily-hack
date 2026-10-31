#!/bin/bash
# **大掃除のハウスクリーニング比較の写真 7 枚を Commons から本番の大きさ（幅 1600）で取る（t493）。** 読むだけ・LLM 不使用・$0。
# t490 の候補をクラウド側で目で見て選んだもの。ライセンスと撮影者を _manifest.json に残す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t493-cleaning-photos.md"
DIR="$RDIR/t493-photos"
rm -rf "$DIR"; mkdir -p "$DIR"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 && PY="$c" && break
done
[ -n "$PY" ] || { echo "python が無い" | tee "$OUT"; exit 1; }
"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, json, re, sys, time, urllib.parse, urllib.request
OUT, DIR = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; contact via github.com/Yokottinnn/daily-hack)"}
def get(u):
    time.sleep(2)
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=40) as r:
        return r.read()
PICK = {
 "aircon-unit": "File:Panasonic AIR CONDITIONER INDOOR UNIT CS-C10KJ2 (2).jpg",
 "aircon-wall": "File:Mitsubishi Heavy Industries aircon indoor unit FDKN208C.jpg",
 "hood": "File:California Kitchen Range Hood.jpg",
 "bath": "File:JP 日本 Japan 京都 Kyoto 四条 Shijo FORZA 酒店 Hotel Forza Kyoto Shijo Kawaramachi room bathroom white bathtub water with 沐浴粉 Bath powder in green yellow 日本製造 June 2026 N13P 02.jpg",
 "kitchen": "File:California Kitchen Farm Sink.jpg",
 "toilet": "File:Modern japanese toilet.jpg",
 "hood-black": "File:Cappa d'aspirazione Silverline.jpg",
}
L = ["# ハウスクリーニング記事の写真（t493）", "", f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "", "```"]
man = {}
for key, t in PICK.items():
    try:
        u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({"action": "query", "titles": t, "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": 1600, "format": "json"})
        pg = next(iter(json.loads(get(u))["query"]["pages"].values()))
        ii = (pg.get("imageinfo") or [{}])[0]; ex = ii.get("extmetadata") or {}
        g = lambda k: re.sub(r"<[^>]+>", "", str(ex.get(k, {}).get("value", ""))).strip()
        blob = get(ii["thumburl"]); open(f"{DIR}/{key}.jpg", "wb").write(blob)
        man[key] = {"title": t, "page": ii.get("descriptionurl"), "src": ii.get("thumburl"), "lic": g("LicenseShortName"), "licUrl": g("LicenseUrl"), "artist": g("Artist")[:160], "fetched": dt.date.today().isoformat(), "task": "ops/tasks/t493-cleaning-photos.sh"}
        L.append(f"  {key:12s} {len(blob):8d} bytes [{man[key]['lic']}] {man[key]['artist'][:60]}")
    except Exception as e:
        L.append(f"  {key}: **失敗** {type(e).__name__}: {str(e)[:160]}")
L += ["```", "", f"取れた写真 **{len(man)} 枚**。LLM を呼んでいない（$0）。"]
json.dump(man, open(f"{DIR}/_manifest.json", "w"), ensure_ascii=False, indent=2)
open(OUT, "w").write("\n".join(L) + "\n")
PYEOF
cat "$OUT" | head -c 4000
