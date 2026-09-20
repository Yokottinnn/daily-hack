#!/bin/bash
# **弾いたロゴを取り直す ＋ 湾岸イベント記事のロゴを取る（t122）。**
#
# 最上位ルール 17「記事には基本的にすべてロゴを入れて作る」。
#
# t118/t120 で取れたものを目で見たら、**20 件 弱が使えなかった。**
#   - **アプリは og:image がストアの宣伝バナー**（トリマ・楽天シニア・Coke ON・アルコイン）
#   - **ポータルのロゴを掴んだ**（毎日サウナ→スーパー銭湯、水宴→フロサウナ）
#   - **テナントのロゴを掴んだ**（THE OUTLETS HIROSHIMA → ACE Bags & Luggage）
#   - 施設や人物の写真（Vitality・SAUNAS 高輪・SHIAGARU・汽汽・パラダイス・三井）
#
# **アプリは App Store の `artworkUrl512` を使う。** これは提供元が登録した
# 正方形のアイコンそのもので、宣伝バナーが混ざらない（t107 で実績あり）。
# 施設・企業は**コモンズを検索**する（t121 で実績あり）。
#
# **商標であり自由ライセンスではない。** ライセンス表記をそのまま出す。
# **判断はしない。** 採否はクラウド側で**目で見て**決める。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t122-logos-retry3.md"
DIR="$RDIR/logos-retry3"
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

# A) アプリ … App Store の artworkUrl512（提供元が登録した正方形アイコン）
APPS = [
    ("torima",        "トリマ",         "1441976566"),
    ("rakutensenior", "楽天シニア",     "1441035550"),
    ("cokeon",        "Coke ON",        "1088184021"),
    ("arucoin",       "アルコイン",     "1441780272"),
    ("sugi",          "スギサポwalk+",  "1441937070"),
    ("dhealth",       "dヘルスケア",    "1352137023"),
]
# B) 企業・施設 … コモンズを検索
SEARCH = [
    ("mitsui",     "三井不動産",             "Mitsui Fudosan logo"),
    ("vitality",   "住友生命",               "Sumitomo Life logo"),
    ("comiket",    "コミックマーケット",     "Comic Market logo"),
    ("tomica",     "トミカ",                 "Tomica logo"),
    ("toyota",     "トヨタ",                 "Toyota logo"),
    ("aeon",       "イオン",                 "AEON logo"),
    ("jal",        "日本航空",               "Japan Airlines logo"),
    ("ana",        "全日本空輸",             "All Nippon Airways logo"),
]

def getb(u, t=20):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

def gets(u, t=20):
    return getb(u, t).decode("utf-8", "replace")

L = ["# 弾いたロゴの取り直し ＋ 湾岸イベント（t122）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**アプリは App Store の `artworkUrl512`**（提供元が登録した正方形アイコン）。",
     "**企業・施設はコモンズの検索。** ライセンス表記をそのまま出す。",
     "**採否はクラウド側で目で見て決める。**", ""]
man = {"_note": "識別目的で使うロゴ。**商標であり自由ライセンスではない。**"
                "取得日 " + dt.date.today().isoformat() + "（ops/tasks/t122-logos-retry3.sh）。"}
t0 = time.time()

def save(blob, name, src, page, lic, brand, key):
    try:
        im = Image.open(io.BytesIO(blob)); im.load()
    except Exception as e:
        L.append(f"  - ✗ 開けない（{type(e).__name__}）"); return False
    w, h = im.size
    if w < 100 or h < 16 or (h and w / h > 14):
        L.append(f"  - ✗ {w}x{h}（形が合わない）"); return False
    im.convert("RGBA").save(f"{DIR}/{name}.png", "PNG", optimize=True)
    L.append(f"  - ✅ `{name}.png` / {w}x{h} / **{lic}**")
    man.setdefault(key, []).append({"brand": brand, "file": f"{name}.png", "source": src,
                                    "page": page, "license_note": lic,
                                    "width": w, "height": h})
    return True

L += ["## A) アプリ（App Store のアイコン）", ""]
for key, brand, appid in APPS:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。**"); break
    L.append(f"### {brand}（id {appid}）")
    L.append("")
    try:
        d = json.loads(gets(f"https://itunes.apple.com/jp/lookup?id={appid}"))
    except Exception as e:
        L += [f"  - ✗ {type(e).__name__}", ""]; continue
    rs = d.get("results") or []
    if not rs:
        L += ["  - ✗ 見つからない（ID が違う可能性）", ""]; continue
    r = rs[0]
    # **名前を必ず出す。** ID 取り違えをここで気づけるようにする（dヘルスケアで踏んだ）
    L.append(f"  - ストア上の名前: **{r.get('trackName','?')[:50]}**")
    url = r.get("artworkUrl512") or r.get("artworkUrl100")
    if not url:
        L += ["  - ✗ artworkUrl が無い", ""]; continue
    try:
        save(getb(url), f"{key}-app", url, r.get("trackViewUrl", ""),
             "App Store の登録アイコン（商標）", brand, key)
    except Exception as e:
        L.append(f"  - ✗ {type(e).__name__}")
    L.append("")

L += ["## B) 企業・施設（コモンズの検索）", ""]
for key, brand, term in SEARCH:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。**"); break
    L.append(f"### {brand}")
    L.append("")
    q = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": f"filetype:bitmap|drawing {term}", "gsrnamespace": "6", "gsrlimit": "5",
        "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": "600"})
    try:
        d = json.loads(gets(f"https://commons.wikimedia.org/w/api.php?{q}"))
    except Exception as e:
        L += [f"  - ✗ {type(e).__name__}", ""]; continue
    pages = (d.get("query") or {}).get("pages") or {}
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
        try:
            if save(getb(ii.get("thumburl") or ii["url"]), f"{key}-{n+1}",
                    ii.get("thumburl") or ii["url"],
                    "https://commons.wikimedia.org/wiki/" +
                    urllib.parse.quote(title.replace(" ", "_")), lic, brand, key):
                n += 1
                L.append(f"        ← {title}")
        except Exception as e:
            L.append(f"  - ✗ {type(e).__name__}")
    if n == 0:
        L.append("  - **使えるものが無かった。**")
    L.append("")

open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
    json.dumps(man, ensure_ascii=False, indent=2))
json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
