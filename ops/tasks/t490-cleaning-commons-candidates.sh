#!/bin/bash
# **大掃除のハウスクリーニング比較の表紙・節の写真の候補を Commons から取る（t490）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-10-31 利用者がダイアログで「大掃除のハウスクリーニング比較」を選んだ。候補は 480px の縮小で返し、採否はクラウド側で目で見て決める（blog-article スキル §1）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t490-cleaning-commons.md"
DIR="$RDIR/t490-commons"
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
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=25) as r:
        return r.read()
QS = {"aircon": "air conditioner cleaning", "aircon2": "split air conditioner indoor unit", "hood": "range hood kitchen", "bath": "bathroom bathtub Japan", "kitchen": "kitchen sink stainless", "toilet": "toilet Japan washlet", "tools": "cleaning tools bucket", "window": "window cleaning squeegee"}
L = ["# ハウスクリーニング記事の写真の候補（t490）", "", f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "", "```"]
man = {}
t0 = time.time()
for key, q in QS.items():
    if time.time() - t0 > 230: L.append("時間切れ"); break
    try:
        u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({"action": "query", "generator": "search", "gsrsearch": f"filetype:bitmap {q}", "gsrnamespace": 6, "gsrlimit": 10, "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": 480, "format": "json"})
        pages = (json.loads(get(u)).get("query") or {}).get("pages") or {}
        n = 0
        for pg in pages.values():
            ii = (pg.get("imageinfo") or [{}])[0]; ex = ii.get("extmetadata") or {}
            g = lambda k: re.sub(r"<[^>]+>", "", str(ex.get(k, {}).get("value", ""))).strip()
            lic = g("LicenseShortName")
            if re.search(r"non[- ]?free|fair use", lic, re.I) or (ii.get("width") or 0) < 1000 or (ii.get("width") or 0) < (ii.get("height") or 0): continue
            n += 1
            if n > 4: break
            name = f"{key}-{n}.jpg"
            open(f"{DIR}/{name}", "wb").write(get(ii["thumburl"]))
            man[name] = {"title": pg.get("title"), "page": ii.get("descriptionurl"), "url": ii.get("url"), "w": ii.get("width"), "h": ii.get("height"), "lic": lic, "artist": g("Artist")[:120], "fetched": dt.date.today().isoformat()}
            L.append(f"  {name:14s} {ii.get('width')}x{ii.get('height')} [{lic}] {pg.get('title')}")
    except Exception as e:
        L.append(f"  {key}: **失敗** {type(e).__name__}: {str(e)[:160]}")
L += ["```", "", f"候補 **{len(man)} 枚**。LLM を呼んでいない（$0）。"]
json.dump(man, open(f"{DIR}/_manifest.json", "w"), ensure_ascii=False, indent=2)
open(OUT, "w").write("\n".join(L) + "\n")
print(f"t490: {len(man)} 枚")
PYEOF
cat "$OUT" | head -c 4000
