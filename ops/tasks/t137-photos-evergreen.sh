#!/bin/bash
# **長く生きる記事の「文字だけの節」に入れる写真の候補を取る（t137）。**
#
# `check-article-ux.py` の「1 セクション 1 ビジュアル」が 51 記事・111 節 残っている。
# **表で埋められる節と、写真でないと意味がない節がある。**
# ここで取るのは後者。**実物の写真が要る節**だけを選んだ。
#
# | 記事 | 節 | 何の写真か |
# | --- | --- | --- |
# | 湾岸の花火・祭り | 江東花火大会 | **荒川・砂町水辺公園**（隅田川の写真で代用しない） |
# | 湾岸マネー | 給付・生活コスト | **江東区／中央区／港区の街** |
# | 湾岸サウナ | 施設 | **豊洲・有明のサウナ施設** |
#
# **候補を 480px のサムネイルにして持ち帰る。** 採否はクラウド側で**目で見て**決める
# （blog-article スキル「候補は『見て選ぶ』」。2026-08-22 に 1 件目を無条件に採って
# **19 世紀の木版画**を表紙にした前科がある）。
#
# **ライセンス表記を必ず一緒に出す。** 出典が書けない画像は使わない。
# **判断はしない。** **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t137-photos-evergreen.md"
DIR="$RDIR/photos-evergreen"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, io, json, sys, time, urllib.parse, urllib.request
from PIL import Image

OUT, DIR = sys.argv[1], sys.argv[2]
BUDGET = 235.0
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"}

# (キー, 何の写真か, コモンズの検索語)
WANT = [
    ("arakawa",   "荒川・砂町水辺公園（江東花火大会）", "Arakawa river Koto Tokyo"),
    ("sunamachi", "砂町",                               "Sunamachi Koto Tokyo"),
    ("kotoku",    "江東区の街",                         "Koto City Tokyo streetscape"),
    ("chuoku",    "中央区（月島・勝どき）",             "Tsukishima Kachidoki Tokyo"),
    ("minatoku",  "港区（台場・芝浦）",                 "Shibaura Minato Tokyo waterfront"),
    ("toyosu",    "豊洲の街",                           "Toyosu Koto Tokyo"),
    ("ariake",    "有明",                               "Ariake Koto Tokyo"),
    ("harumi",    "晴海",                               "Harumi Chuo Tokyo"),
]

def getb(u, t=20, tries=3):
    last = None
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
                return r.read()
        except Exception as e:
            last = e
            time.sleep(1.2 * (i + 1))
    raise last

L = ["# 写真の候補（長く生きる記事・t137）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**480px のサムネイルで持ち帰っている。** 採否はクラウド側で目で見て決める。",
     "**ライセンス表記をそのまま出す。** 出典が書けない画像は使わない。", ""]
man = {"_note": "写真の候補。**採用したものだけ本採用でフル解像度を取り直す。** "
                "取得日 " + dt.date.today().isoformat() + "（ops/tasks/t137-photos-evergreen.sh）。"}
t0 = time.time()

for key, what, term in WANT:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。**"); break
    L += [f"### {what}", f"  - 検索語: `{term}`", ""]
    q = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": f"filetype:bitmap {term}", "gsrnamespace": "6", "gsrlimit": "6",
        "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": "480"})
    try:
        d = json.loads(getb(f"https://commons.wikimedia.org/w/api.php?{q}").decode("utf-8", "replace"))
    except Exception as e:
        L += [f"  - ✗ 検索が失敗（{type(e).__name__}）", ""]; continue
    pages = (d.get("query") or {}).get("pages") or {}
    n = 0
    for _, pg in sorted(pages.items(), key=lambda kv: kv[1].get("index", 99)):
        if n >= 4 or time.time() - t0 > BUDGET:
            break
        ii = (pg.get("imageinfo") or [None])[0]
        if not ii:
            continue
        w, h = ii.get("width", 0), ii.get("height", 0)
        # **横長で、そこそこ大きいものだけ。** 縦長は記事の図版に使いにくい
        if w < 900 or h == 0 or w / h < 1.2:
            continue
        em = ii.get("extmetadata") or {}
        lic = (em.get("LicenseShortName") or {}).get("value") or "表記なし"
        artist = (em.get("Artist") or {}).get("value") or ""
        artist = __import__("re").sub(r"<[^>]+>", "", artist)[:40]
        title = pg.get("title", "?")
        try:
            blob = getb(ii["thumburl"])
            im = Image.open(io.BytesIO(blob)); im.load()
            name = f"{key}-{n+1}"
            im.convert("RGB").save(f"{DIR}/{name}.jpg", "JPEG", quality=80)
            L.append(f"  - ✅ `{name}.jpg` / 原寸 {w}x{h} / **{lic}** / {artist}")
            L.append(f"        ← {title}")
            man.setdefault(key, []).append({
                "what": what, "thumb": f"{name}.jpg", "commons_title": title,
                "page": "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_")),
                "license": lic, "artist": artist, "px": f"{w}x{h}", "full_url": ii["url"]})
            n += 1
        except Exception as e:
            L.append(f"  - ✗ {type(e).__name__}")
    if n == 0:
        L.append("  - **使えそうなものが無かった。**")
    L.append("")

open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
    json.dumps(man, ensure_ascii=False, indent=2))
json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:26]))
PYEOF
