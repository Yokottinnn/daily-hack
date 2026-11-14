#!/bin/bash
# **百貨店のロゴを Wikimedia Commons から名前で探して取る（t625）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 百貨店の店舗別売上ランキングの記事用（最上位ルール 17: ブランド名の左にロゴ）。クラウドからは Commons が 429。
# ブランドごとに「<名前> logo」で検索し、上位 3 件を幅 600px の PNG で reports/t625/ に置く。採否はクラウド側で目で見て決める。1 回ごとに 3 秒空ける。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t625"; rm -rf "$D"; mkdir -p "$D"
OUT="$RDIR/t625-dept-store-logos.md"
PY=""; for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do command -v "$c" >/dev/null 2>&1 && PY="$c" && break; done
[ -n "$PY" ] || { echo "python が無い" | tee "$OUT"; exit 1; }
"$PY" - "$OUT" "$D" <<'PYEOF'
import datetime as dt, json, sys, time, urllib.parse, urllib.request
OUT, D = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "daily-hack-blog/1.0 (https://daily-hack.fieldbeside.com/)"}
def get(u):
    time.sleep(3)
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=25) as r: return r.read()
B = [("takashimaya","Takashimaya logo"),("isetan","Isetan logo"),("mitsukoshi","Mitsukoshi logo"),("daimaru","Daimaru logo"),("matsuzakaya","Matsuzakaya logo"),("hankyu","Hankyu Department Store logo"),("hanshin","Hanshin Department Store logo"),("matsuya","Matsuya Ginza logo"),("daiwa","Daiwa department store Kanazawa logo")]
L = ["# 百貨店のロゴ候補（t625・$0）", "", f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "", "```"]
man = {}; got = 0; tried = 0
for key, q in B:
    try:
        u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({"action":"query","format":"json","generator":"search","gsrnamespace":6,"gsrsearch":q,"gsrlimit":6,"prop":"imageinfo","iiprop":"url|extmetadata","iiurlwidth":600})
        pages = sorted(json.loads(get(u)).get("query",{}).get("pages",{}).values(), key=lambda p: p.get("index",0))
    except Exception as e:
        L.append(f"{key}: 検索できない {e}"); continue
    n = 0
    for p in pages:
        if n >= 3: break
        info = (p.get("imageinfo") or [{}])[0]; src = info.get("thumburl")
        if not src: continue
        tried += 1; name = f"{key}{n+1}.png"
        try:
            open(f"{D}/{name}","wb").write(get(src)); got += 1
        except Exception as e:
            L.append(f"  {name}: 取れない {e}"); continue
        lic = (info.get("extmetadata",{}).get("LicenseShortName") or {}).get("value","")
        man[name] = {"title": p.get("title"), "page": info.get("descriptionurl"), "src": src, "license": lic}
        L.append(f"{name} | {p.get('title')} | {lic}"); n += 1
    if n == 0: L.append(f"{key}: 候補なし")
json.dump(man, open(f"{D}/_manifest.json","w"), ensure_ascii=False, indent=1)
L += [f"対象 {tried} 枚 / 取得 {got} 枚", "```", "**読むだけ。LLM 不使用（$0／回）。**"]
open(OUT,"w").write("\n".join(L)+"\n")
PYEOF
echo "t625 / $(basename "$OUT")"
