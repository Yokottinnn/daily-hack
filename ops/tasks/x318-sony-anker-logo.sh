#!/bin/bash
# **ソニーと Anker のロゴを、ファイル名・アプリを指定して取る（x318）。費用 $0。**
#
# x317 では、ソニーは記事の先頭 3 件が子会社のロゴ（AXN・Aniplex・Arista）で本体が取れず、
# Anker は会社名入り（ANKER Innovations）だけだった。
#   ① Commons の `File:Sony logo.svg` を名前で引く（imageinfo の thumburl・幅 600）
#   ② App Store の Anker 公式アプリのアイコン（trackName と sellerName を出す）
# **採否はクラウド側で目で見て決める。** 1 回ごとに 4 秒 空ける。LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/x318-logos.md"
DIR="$RDIR/x318-logos"
rm -rf "$DIR"; mkdir -p "$DIR"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 && PY="$c" && break
done
[ -n "$PY" ] || { echo "python が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, json, sys, time, urllib.parse, urllib.request
OUT, DIR = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; contact via github.com/Yokottinnn/daily-hack)"}
def get(u):
    time.sleep(4)
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=25) as r:
        return r.read()
L = ["# ソニーと Anker のロゴ（x318）", "", f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "", "```"]
man = {}
for t in ["File:Sony logo.svg", "File:Sony wordmark.svg"]:
    try:
        u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({"action": "query", "titles": t, "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": 600, "format": "json"})
        pg = next(iter(json.loads(get(u))["query"]["pages"].values()))
        info = (pg.get("imageinfo") or [{}])[0]
        src = info.get("thumburl")
        if not src: L.append(f"  {t}: 無い"); continue
        lic = (info.get("extmetadata", {}).get("LicenseShortName") or {}).get("value", "")
        name = "sony-" + t.split(":")[1].split(".")[0].replace(" ", "-").lower() + ".png"
        blob = get(src); open(f"{DIR}/{name}", "wb").write(blob)
        man[name] = {"brand": "ソニー", "title": t, "page": info.get("descriptionurl"), "src": src, "license": lic,
                     "fetched": dt.date.today().isoformat(), "task": "ops/tasks/x318-sony-anker-logo.sh"}
        L.append(f"  {name:28s} {len(blob):7d} bytes [{lic}] {t}")
    except Exception as e:
        L.append(f"  {t}: **失敗** {type(e).__name__}: {str(e)[:160]}")
try:
    u = "https://itunes.apple.com/jp/search?" + urllib.parse.urlencode({"term": "Anker", "entity": "software", "country": "jp", "limit": 4})
    res = json.loads(get(u).decode("utf-8")).get("results", [])
    for i, x in enumerate(res[:4], 1):
        L.append(f"  app {i}: id={x.get('trackId')} {x.get('trackName')} / {x.get('sellerName')}")
        art = x.get("artworkUrl512")
        if art:
            name = f"anker-app-{i}.png"; open(f"{DIR}/{name}", "wb").write(get(art))
            man[name] = {"brand": x.get("trackName"), "seller": x.get("sellerName"), "src": art, "page": x.get("trackViewUrl"),
                         "fetched": dt.date.today().isoformat(), "task": "ops/tasks/x318-sony-anker-logo.sh"}
except Exception as e:
    L.append(f"  App Store **失敗** {type(e).__name__}: {str(e)[:160]}")
L += ["```", "", f"取れた画像: **{len(man)} 枚**。**LLM を呼んでいない（$0／回・$0／日・$0／月）。**"]
json.dump(man, open(f"{DIR}/_manifest.json", "w"), ensure_ascii=False, indent=2)
open(OUT, "w").write("\n".join(L) + "\n")
print(f"x318: {len(man)} 枚 / {OUT.split('/')[-1]}")
PYEOF
