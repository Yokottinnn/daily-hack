#!/bin/bash
# **ローソンのロゴを Wikipedia / Commons から名前で探して取る（t634）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 コンビニの都道府県別店舗数の記事用。t632 では「Lawson convenience store logo」で別物しか出なかった。
# ① 英語版・日本語版ウィキペディアの記事の画像（pageimages）② Commons の「Lawson logo」検索、の順で最大 4 枚を reports/t634/ に置く。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t634"; rm -rf "$D"; mkdir -p "$D"
OUT="$RDIR/t634-lawson-logo.md"
PY=""; for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do command -v "$c" >/dev/null 2>&1 && PY="$c" && break; done
[ -n "$PY" ] || { echo "python が無い" | tee "$OUT"; exit 1; }
"$PY" - "$OUT" "$D" <<'PYEOF'
import json, sys, time, urllib.parse, urllib.request
OUT, D = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "daily-hack-blog/1.0 (https://daily-hack.fieldbeside.com/)"}
def get(u):
    time.sleep(2)
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=25) as r: return r.read()
L = ["# ローソンのロゴ候補（t634・$0）", "", "```"]; man = {}; n = 0
titles = []
for host, page in [("en.wikipedia.org", "Lawson (store)"), ("ja.wikipedia.org", "ローソン")]:
    try:
        j = json.loads(get(f"https://{host}/w/api.php?" + urllib.parse.urlencode({"action":"query","format":"json","titles":page,"prop":"images","imlimit":50})))
        for p in j["query"]["pages"].values():
            for im in p.get("images", []):
                t = im["title"]
                if "logo" in t.lower() or "ロゴ" in t: titles.append(t.replace("ファイル:", "File:"))
    except Exception as e: L.append(f"{host}: 読めない {e}")
try:
    j = json.loads(get("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({"action":"query","format":"json","list":"search","srnamespace":6,"srsearch":"Lawson logo svg","srlimit":8})))
    titles += [s["title"] for s in j["query"]["search"] if "lawson" in s["title"].lower()]
except Exception as e: L.append(f"commons 検索: 読めない {e}")
seen = []
for t in titles:
    if t in seen or n >= 4: continue
    seen.append(t)
    try:
        j = json.loads(get("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({"action":"query","format":"json","titles":t,"prop":"imageinfo","iiprop":"url|extmetadata","iiurlwidth":600})))
        p = list(j["query"]["pages"].values())[0]; info = (p.get("imageinfo") or [{}])[0]
        if not info.get("thumburl"): L.append(f"{t}: Commons に無い"); continue
        n += 1; name = f"lawson{n}.png"; open(f"{D}/{name}", "wb").write(get(info["thumburl"]))
        lic = (info.get("extmetadata", {}).get("LicenseShortName") or {}).get("value", "")
        man[name] = {"title": t, "page": info.get("descriptionurl"), "src": info["thumburl"], "license": lic}
        L.append(f"{name} | {t} | {lic}")
    except Exception as e: L.append(f"{t}: 取れない {e}")
json.dump(man, open(f"{D}/_manifest.json", "w"), ensure_ascii=False, indent=1)
L += [f"候補 {len(seen)} / 取得 {n} 枚", "```", "**読むだけ。LLM 不使用（$0／回）。**"]
open(OUT, "w").write("\n".join(L) + "\n")
PYEOF
echo "t634 / $(basename "$OUT")"
