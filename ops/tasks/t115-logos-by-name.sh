#!/bin/bash
# **業務スーパーとトライアルのロゴを、名前で探して取る（t115）。**
#
# 利用者の指摘（2026-09-20）:
#   「取れないわけないだろ。ちゃんとロゴの名前で調べて取得してきて。」
#
# t111/t113 は**トップページの img を漁るだけ**だったので取れなかった。
# **探し方が悪い。** 調べ直したら、公式の配布物と百科事典のファイルが在った。
#
#   A) トライアル … **公式のメディアキットがロゴ ZIP を配布している**
#                   https://trial-holdings.inc/news/media/
#   B) 両方 … **ウィキペディア日本語版のファイルページ**（MediaWiki API で実体 URL と
#             ライセンスが取れる）。`ファイル:Gyomu Super Logo.png` ほか
#   C) 業務スーパー … **なぜ 0 件だったのかを見る。** トップの img / meta / link を
#             丸ごと出す。**推測でやり直さない**
#
# **商標であり自由ライセンスではない。** 識別目的の利用を前提に、
# 取得元とライセンス表記を必ず残す。
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t115-logos-by-name.md"
DIR="$RDIR/super-logos2"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, html, io, json, re, sys, time, urllib.error, urllib.parse, urllib.request, zipfile
from PIL import Image

OUT, DIR = sys.argv[1], sys.argv[2]
BUDGET = 250.0
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; contact via github.com/Yokottinnn/daily-hack)",
      "Accept-Language": "ja,en;q=0.8"}

def getb(u, t=25):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

def gets(u, t=25):
    return getb(u, t).decode("utf-8", "replace")

L = ["# 業務スーパー・トライアルのロゴを名前で探す（t115）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**t111/t113 はトップの img を漁るだけで取れなかった。** 探し方を変えた。",
     "**商標であり自由ライセンスではない。** 取得元とライセンスを必ず残す。", ""]
man = {"_note": "識別目的で使うロゴ。**商標であり自由ライセンスではない。**改変せず、"
                f"そのまま置くこと。取得日 {dt.date.today().isoformat()}"
                "（ops/tasks/t115-logos-by-name.sh）。"}
t0 = time.time()

def save(blob, name, src, page, lic, brand):
    try:
        im = Image.open(io.BytesIO(blob)); im.load()
    except Exception as e:
        L.append(f"  - ✗ `{name}`: 画像として開けない（{type(e).__name__}）")
        return False
    w, h = im.size
    if w < 100 or h < 16:
        L.append(f"  - ✗ `{name}`: {w}x{h}（小さすぎる）")
        return False
    im = im.convert("RGBA")
    im.save(f"{DIR}/{name}.png", "PNG", optimize=True)
    L.append(f"  - ✅ `{name}.png` / {w}x{h} / ライセンス表記: **{lic}**")
    L.append(f"        ← `{src[:110]}`")
    man.setdefault(brand, []).append({"file": f"{name}.png", "source": src, "page": page,
                                      "license_note": lic, "width": w, "height": h})
    return True

# ── A) トライアル公式メディアキット ───────────────────────────
L += ["## A) トライアル公式メディアキット", ""]
MK = "https://trial-holdings.inc/news/media/"
L.append(f"`{MK}`")
L.append("")
try:
    page = gets(MK)
    zips, imgs = [], []
    for m in re.finditer(r'href="([^"]+\.zip)"', page, re.I):
        zips.append(urllib.parse.urljoin(MK, html.unescape(m.group(1))))
    for m in re.finditer(r'<img[^>]+src="([^"]+)"', page, re.I):
        u = urllib.parse.urljoin(MK, html.unescape(m.group(1)))
        if re.search(r'logo|mark', u, re.I):
            imgs.append(u)
    L.append(f"ZIP **{len(zips)} 本** / ロゴらしい img **{len(imgs)} 件**")
    L.append("")
    n = 0
    for z in zips[:4]:
        if time.time() - t0 > BUDGET: break
        L.append(f"- ZIP `{z[:100]}`")
        try:
            zf = zipfile.ZipFile(io.BytesIO(getb(z, 40)))
        except Exception as e:
            L.append(f"  - ✗ 展開できない（{type(e).__name__}）"); continue
        for nm in zf.namelist():
            if time.time() - t0 > BUDGET: break
            if not re.search(r'\.(png|jpg|jpeg)$', nm, re.I): continue
            if nm.startswith("__MACOSX"): continue
            n += 1
            save(zf.read(nm), f"trial-kit-{n}", z + "!" + nm, MK,
                 "公式メディアキットの配布物（商標）", "trial")
            if n >= 4: break
    for i, u in enumerate(imgs[:3]):
        if time.time() - t0 > BUDGET: break
        try:
            save(getb(u), f"trial-mk-{i+1}", u, MK, "公式サイト（商標）", "trial")
        except Exception as e:
            L.append(f"  - ✗ `{u[:90]}`: {type(e).__name__}")
except Exception as e:
    L.append(f"❌ {type(e).__name__}: {str(e)[:140]}")
L.append("")

# ── B) ウィキペディア／コモンズのファイルページ ──────────────
L += ["## B) 百科事典のファイルページ（MediaWiki API）", "",
      "**ライセンス表記もそのまま出す。** 自由ライセンスでないものは、その旨が分かる。", ""]
WIKI = [
    ("ja.wikipedia.org", "ファイル:Gyomu Super Logo.png", "gyomu"),
    ("commons.wikimedia.org", "File:Gyomu Super Logo.png", "gyomu"),
    ("ja.wikipedia.org", "ファイル:Trial Company Logo.png", "trial"),
    ("commons.wikimedia.org", "File:トライアルカンパニー ロゴ.png", "trial"),
    ("ja.wikipedia.org", "ファイル:トライアルカンパニー ロゴ.png", "trial"),
]
k = {}
for hostname, title, brand in WIKI:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。**"); break
    q = urllib.parse.urlencode({
        "action": "query", "format": "json", "titles": title,
        "prop": "imageinfo", "iiprop": "url|size|extmetadata"})
    api = f"https://{hostname}/w/api.php?{q}"
    L.append(f"### `{title}` @ {hostname}")
    L.append("")
    try:
        d = json.loads(gets(api))
    except Exception as e:
        L += [f"❌ {type(e).__name__}", ""]; continue
    pages = (d.get("query") or {}).get("pages") or {}
    got = False
    for _, pg in pages.items():
        ii = (pg.get("imageinfo") or [None])[0]
        if not ii:
            L.append("（このサイトにこのファイルは無い）"); continue
        got = True
        em = ii.get("extmetadata") or {}
        lic = (em.get("LicenseShortName") or {}).get("value") or "表記なし"
        art = re.sub(r"<[^>]+>", "", (em.get("Artist") or {}).get("value") or "")[:60]
        L.append(f"実体 `{ii['url'][:110]}` / {ii.get('width')}x{ii.get('height')}")
        L.append(f"ライセンス表記: **{lic}** / 作者表記: {art or '—'}")
        L.append("")
        k[brand] = k.get(brand, 0) + 1
        try:
            save(getb(ii["url"]), f"{brand}-wiki-{k[brand]}", ii["url"],
                 f"https://{hostname}/wiki/" + urllib.parse.quote(title.replace(" ", "_")),
                 lic, brand)
        except Exception as e:
            L.append(f"  - ✗ 取得できない（{type(e).__name__}）")
    if not got:
        L.append("（imageinfo が無い）")
    L.append("")

# ── C) 業務スーパー公式が 0 件だった理由を見る ─────────────────
L += ["## C) `gyomusuper.jp` に何が載っているのか（0 件だった理由）", "",
      "**推測でやり直さない。** img / meta / link を丸ごと出す。", ""]
for u in ["https://www.gyomusuper.jp/", "https://www.gyomusuper.jp/sitepolicy.php"]:
    if time.time() - t0 > BUDGET: break
    L.append(f"### `{u}`")
    L.append("")
    try:
        page = gets(u)
    except Exception as e:
        L += [f"❌ {type(e).__name__}: {str(e)[:120]}", ""]; continue
    imgs = re.findall(r'<img[^>]+>', page, re.I)
    metas = re.findall(r'<meta[^>]+(?:og:image|twitter:image)[^>]*>', page, re.I)
    links = re.findall(r'<link[^>]+rel="[^"]*icon[^"]*"[^>]*>', page, re.I)
    svgs = re.findall(r'[\'"]([^\'"]+\.svg)[\'"]', page, re.I)
    L.append(f"HTML {len(page)} 字 / img {len(imgs)} 件 / og:image {len(metas)} 件 / "
             f"icon link {len(links)} 件 / svg 参照 {len(svgs)} 件")
    L.append("")
    L.append("```")
    for x in (metas + links)[:6]:
        L.append(re.sub(r"\s+", " ", x)[:190])
    for x in imgs[:12]:
        L.append(re.sub(r"\s+", " ", x)[:190])
    for x in svgs[:8]:
        L.append("svg: " + x[:170])
    L.append("```")
    L.append("")

open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
    json.dumps(man, ensure_ascii=False, indent=2))
json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:40]))
PYEOF
