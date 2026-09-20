#!/bin/bash
# **湾岸イベント記事のロゴを取る（t123）。**
#
# 最上位ルール 17「記事には基本的にすべてロゴを入れて作る」。
# 残っていた記事のうち、ブランドが並んでいるのは
# `wangan-august-events-2026` だけ（ららぽーとガイドは 175 本 すべて三井、
# 湾岸タワーのリンクは報道・行政＝出典であってブランドではない）。
#
# **og:image は使わない。** t118/t120 で 20 件 弱が別ブランドだった
# （テナント・ポータル・運営会社・宣伝バナー）。ここでは
#   A) コモンズの検索（t121/t122 で実績あり）
#   B) 公式サイトの **ロゴらしい img と apple-touch-icon だけ**を候補として並べる
# の 2 通りで取り、**採否はクラウド側で目で見て決める。**
#
# **商標であり自由ライセンスではない。** ライセンス表記をそのまま出す。
# **判断はしない。** **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t123-wangan-logos.md"
DIR="$RDIR/logos-wangan"
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
BUDGET = 240.0
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"}

# A) コモンズを検索する
SEARCH = [
    ("lalaport",  "ららぽーと",         "LaLaport logo"),
    ("bigsight",  "東京ビッグサイト",   "Tokyo Big Sight logo"),
    ("yoshimoto", "吉本興業",           "Yoshimoto Kogyo logo"),
    ("sumitomo",  "住友不動産",         "Sumitomo Realty Development logo"),
    ("livedoor",  "livedoor",           "Livedoor logo"),
]
# B) 公式サイトから「ロゴらしいもの」だけ拾う
SITES = [
    ("manyo",       "東京豊洲 万葉倶楽部", "https://tokyo-toyosu.manyo.co.jp/"),
    ("senkyaku",    "豊洲 千客万来",       "https://toyosu-senkyakubanrai.jp/"),
    ("toyosupit",   "豊洲PIT",             "https://toyosu.pia-pit.jp/"),
    ("ariakeg",     "有明ガーデン",        "https://www.ariakegardens.com/"),
    ("toyshow",     "東京おもちゃショー",  "https://www.toys.or.jp/toyshow/"),
    ("toyotaarena", "TOYOTA ARENA TOKYO",  "https://www.toyota-arena-tokyo.jp/"),
]

def getb(u, t=20):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

def gets(u, t=20):
    return getb(u, t).decode("utf-8", "replace")

L = ["# 湾岸イベント記事のロゴ候補（t123）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**og:image は使っていない。** A) はコモンズの検索、",
     "B) は公式サイトの **ロゴらしい img と apple-touch-icon だけ**。",
     "**採否はクラウド側で目で見て決める。**", ""]
man = {"_note": "識別目的で使うロゴ。**商標であり自由ライセンスではない。**"
                "取得日 " + dt.date.today().isoformat() + "（ops/tasks/t123-wangan-logos.sh）。"}
t0 = time.time()

def save(blob, name, src, page, lic, brand, key):
    global L
    try:
        im = Image.open(io.BytesIO(blob)); im.load()
    except Exception as e:
        L.append(f"  - ✗ 開けない（{type(e).__name__}）"); return False
    w, h = im.size
    if w < 80 or h < 16 or (h and w / h > 14):
        L.append(f"  - ✗ {w}x{h}（形が合わない）"); return False
    im.convert("RGBA").save(f"{DIR}/{name}.png", "PNG", optimize=True)
    L.append(f"  - ✅ `{name}.png` / {w}x{h} / **{lic}**")
    man.setdefault(key, []).append({"brand": brand, "file": f"{name}.png", "source": src,
                                    "page": page, "license_note": lic,
                                    "width": w, "height": h})
    return True

L += ["## A) コモンズの検索", ""]
for key, brand, term in SEARCH:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。**"); break
    L += [f"### {brand}", ""]
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
        u = ii.get("thumburl") or ii["url"]
        try:
            if save(getb(u), f"{key}-{n+1}", u,
                    "https://commons.wikimedia.org/wiki/" +
                    urllib.parse.quote(title.replace(" ", "_")), lic, brand, key):
                n += 1
                L.append(f"        ← {title}")
        except Exception as e:
            L.append(f"  - ✗ {type(e).__name__}")
    if n == 0:
        L.append("  - **使えるものが無かった。**")
    L.append("")

IMG = re.compile(r"<img\b[^>]*>", re.I)
ATTR = re.compile(r'(src|data-src|srcset|alt|class|id)\s*=\s*["\']([^"\']*)["\']', re.I)
TOUCH = re.compile(r'<link\b[^>]*rel=["\'][^"\']*apple-touch-icon[^"\']*["\'][^>]*>', re.I)
HREF = re.compile(r'href\s*=\s*["\']([^"\']+)["\']', re.I)

L += ["## B) 公式サイト（ロゴらしいものだけ）", ""]
for key, brand, url in SITES:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。**"); break
    L += [f"### {brand}", f"  - 取得元: {url}", ""]
    try:
        html = gets(url, 18)
    except Exception as e:
        L += [f"  - ✗ ページが開けない（{type(e).__name__}）", ""]; continue

    cands = []
    for tag in IMG.findall(html)[:400]:
        a = {k.lower(): v for k, v in ATTR.findall(tag)}
        s = a.get("src") or a.get("data-src") or (a.get("srcset", "").split()[:1] or [""])[0]
        if not s or s.startswith("data:"):
            continue
        blob = " ".join([s, a.get("alt", ""), a.get("class", ""), a.get("id", "")]).lower()
        # **ロゴと書いてあるものだけ。** og:image は見ない
        if "logo" in blob or "ロゴ" in blob:
            cands.append((urllib.parse.urljoin(url, s), a.get("alt", "")[:40]))
    for tag in TOUCH.findall(html)[:3]:
        m = HREF.search(tag)
        if m:
            cands.append((urllib.parse.urljoin(url, m.group(1)), "apple-touch-icon"))

    # 重複を消す（順番は保つ）
    seen, uniq = set(), []
    for u, alt in cands:
        if u not in seen:
            seen.add(u); uniq.append((u, alt))

    if not uniq:
        # **「取れない」で終わらせない。** 何が在ったのかを出す（推測でやり直さないため）
        L.append("  - **`logo` を含む img が無い。** ページ内の img を先頭 12 件 出す:")
        for tag in IMG.findall(html)[:12]:
            L.append(f"    - `{tag[:150]}`")
        L.append("")
        continue

    n = 0
    for u, alt in uniq:
        if n >= 3 or time.time() - t0 > BUDGET:
            break
        L.append(f"  - 候補: `{u[:110]}` / alt=`{alt}`")
        try:
            if save(getb(u, 15), f"{key}-{n+1}", u, url,
                    "公式サイトのロゴ画像（商標）", brand, key):
                n += 1
        except Exception as e:
            L.append(f"    - ✗ {type(e).__name__}")
    L.append("")

open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
    json.dumps(man, ensure_ascii=False, indent=2))
json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
