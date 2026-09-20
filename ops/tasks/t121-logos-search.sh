#!/bin/bash
# **og:image が別物だったブランドを、コモンズの検索で取り直す（t121）。**
#
# t116/t117 の結果を目で見たら、**og:image が取引先カルーセルや製品の
# スクリーンショットだった**ものが 14 件 あった。実際に混入していたもの:
#
#   Azure → **Nestlé のロゴ** / Lucidchart → **HYUNDAI のロゴ**
#   Notion・Spotify・Figma・GitHub・JetBrains・Visual Studio・Tableau → 宣伝画像
#   富士急・京都近美・国立国際 → 建物やコースターの写真
#
# **ファイル名を決め打ちしたのが敗因。** t116 は `File:Figma-logo.svg` のように
# 推測した題名を引いていて、外れると og:image に落ちていた。
# **今回は検索してから引く**（`generator=search`）。
#
# **SVG は Pillow で開けない。** MediaWiki の `iiurlwidth` で **PNG に変換させて**取る。
#
# **商標であり自由ライセンスではない。** ライセンス表記をそのまま出す。
#
# **判断はしない。** 採否はクラウド側。**目で見て選ぶ。**
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t121-logos-search.md"
DIR="$RDIR/logos-search"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, io, json, re, sys, time, urllib.parse, urllib.request
from PIL import Image

OUT, DIR = sys.argv[1], sys.argv[2]
BUDGET = 250.0
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"}
# (key, 表示名, コモンズでの検索語)
WANT = [
    ("azure",       "Microsoft Azure",  "Microsoft Azure logo"),
    ("lucid",       "Lucidchart",       "Lucidchart logo"),
    ("notion",      "Notion",           "Notion app logo"),
    ("spotify",     "Spotify",          "Spotify logo"),
    ("figma",       "Figma",            "Figma logo"),
    ("github",      "GitHub",           "GitHub logo"),
    ("jetbrains",   "JetBrains",        "JetBrains logo"),
    ("visualstudio","Visual Studio",    "Visual Studio logo"),
    ("tableau",     "Tableau",          "Tableau software logo"),
    ("fujiq",       "富士急ハイランド",   "Fuji-Q Highland logo"),
    ("momak",       "京都国立近代美術館", "National Museum of Modern Art Kyoto logo"),
    ("nmao",        "国立国際美術館",     "National Museum of Art Osaka logo"),
    ("nmwa",        "国立西洋美術館",     "National Museum of Western Art logo"),
    ("willer",      "WILLER",           "Willer Express logo"),
    ("autodesk",    "Autodesk",         "Autodesk logo"),
    ("unreal",      "Unreal Engine",    "Unreal Engine logo"),
    ("microsoft",   "Microsoft",        "Microsoft logo"),
    ("amazon",      "Amazon",           "Amazon logo"),
]

def gets(u, t=20):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

def getb(u, t=20):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

L = ["# og:image が別物だったブランドの取り直し（t121）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**ファイル名を決め打ちせず、コモンズを検索してから引く。**",
     "**SVG は `iiurlwidth` で PNG に変換させて取る**（Pillow が SVG を開けないため）。",
     "**ライセンス表記をそのまま出す。** 採否はクラウド側で**目で見て**決める。", ""]
man = {"_note": "識別目的で使うロゴ。**商標であり自由ライセンスではない。**"
                "取得日 " + dt.date.today().isoformat() + "（ops/tasks/t121-logos-search.sh）。"}
t0 = time.time()

for key, brand, term in WANT:
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** {brand} 以降は次のタスクで。"); break
    L.append(f"## {brand}")
    L.append("")
    L.append(f"検索語 `{term}`")
    L.append("")
    q = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": f"filetype:bitmap|drawing {term}", "gsrnamespace": "6", "gsrlimit": "6",
        "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": "600"})
    try:
        d = json.loads(gets(f"https://commons.wikimedia.org/w/api.php?{q}"))
    except Exception as e:
        L += [f"❌ {type(e).__name__}", ""]; continue
    pages = (d.get("query") or {}).get("pages") or {}
    if not pages:
        L += ["（検索に 1 件も当たらなかった）", ""]; continue
    n = 0
    for _, pg in sorted(pages.items(), key=lambda kv: kv[1].get("index", 99)):
        if n >= 2 or time.time() - t0 > BUDGET:
            break
        ii = (pg.get("imageinfo") or [None])[0]
        if not ii:
            continue
        em = ii.get("extmetadata") or {}
        lic = (em.get("LicenseShortName") or {}).get("value") or "表記なし"
        title = pg.get("title", "?")
        # **`thumburl` は PNG に変換されたもの。** SVG でもこれなら開ける
        url = ii.get("thumburl") or ii["url"]
        try:
            blob = getb(url)
            im = Image.open(io.BytesIO(blob)); im.load()
        except Exception as e:
            L.append(f"  - ✗ `{title[:50]}`: {type(e).__name__}"); continue
        w, h = im.size
        if w < 100 or h < 16 or (h and w / h > 14):
            L.append(f"  - ✗ `{title[:50]}`: {w}x{h}（形が合わない）"); continue
        n += 1
        name = f"{key}-{n}"
        im.convert("RGBA").save(f"{DIR}/{name}.png", "PNG", optimize=True)
        L.append(f"  - ✅ `{name}.png` / {w}x{h} / **{lic}**")
        L.append(f"        ← {title}")
        man.setdefault(key, []).append({
            "brand": brand, "file": f"{name}.png", "source": url,
            "page": "https://commons.wikimedia.org/wiki/" +
                    urllib.parse.quote(title.replace(" ", "_")),
            "license_note": lic, "width": w, "height": h})
    if n == 0:
        L.append("  - **使えるものが無かった。**")
    L.append("")

open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
    json.dumps(man, ensure_ascii=False, indent=2))
json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
