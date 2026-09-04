#!/bin/bash
# 062 の取り直し。**062 は 63 枚すべてハズレだった。**
#
# 取れたのはイベント告知のチラシ、ショップの商品写真、テナントのロゴばかりで、
# **施設写真は 1 枚も無かった**（例: 柏の葉＝学校の集合写真／太陽光相談会のチラシ、
# 磐田＝エステの広告／パイ菓子、新三郷＝音楽教室のキャンペーン）。
#
# **原因は除外条件の作りすぎ。** `kv` `main_visual` `common` を弾いたが、
# **施設ページのキービジュアルこそが施設写真**だった。それを落として、
# 残ったイベント一覧の画像を拾っていた。
#
# 今回は 2 つの経路を同時に試す。
#   A) 施設ページの**キービジュアルを弾かない**。og:image も候補に入れる
#   B) **Wikimedia Commons** を施設名で検索する（ライセンスが明確で、記事の既存の
#      アイキャッチもここから取っている）
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-lala2-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p lala2

"$PY" - "$RDIR" <<'PYEOF'
import io, json, re, sys, time, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "daily-hack-ops/1.0 (blog article research; contact via github.com/Yokottinnn/daily-hack)"}

def get(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

def getb(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

def save(im, name):
    if im.width > 1600:
        im.thumbnail((1600, 1600))
    im.save(f"lala2/{name}.jpg", quality=88)
    im.resize((480, max(1, int(im.height * 480 / im.width)))).save(
        f"lala2/thumb-{name}.jpg", quality=72)

# 062 の反省: **キービジュアルを弾かない。** 落とすのはロゴ・アイコン類だけにする。
BAD = re.compile(r"logo|icon|favicon|sprite|placeholder|noimage|arrow|btn|sns", re.I)
# **イベント・ショップニュースは施設写真ではない。** URL の階層で落とす。
BAD_PATH = re.compile(r"/(event|shopnews|pickup|topics|openrenewal)/", re.I)

def hero(html, base, key):
    lines, seen = [], set()
    cands = []
    m = re.search(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)', html, re.I)
    if m:
        cands.append(("og:image", m.group(1)))
    for pat in (r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']',
                r'<source[^>]+srcset=["\']([^"\',\s]+)',
                r'url\(["\']?([^)"\']+)["\']?\)'):
        for c in re.findall(pat, html, re.I):
            cands.append(("page", c))
    got = 0
    for origin, c in cands:
        if got >= 4:
            break
        if not re.search(r"\.(jpe?g|png|webp)(\?|$)", c, re.I):
            continue
        if BAD.search(c) or BAD_PATH.search(c):
            continue
        full = urllib.parse.urljoin(base, c)
        if full in seen:
            continue
        seen.add(full)
        try:
            im = Image.open(io.BytesIO(getb(full))).convert("RGB")
        except Exception:
            continue
        w, h = im.size
        if w < 640 or h < 360 or not (1.1 <= w / h <= 2.4):
            continue
        got += 1
        save(im, f"{key}-page{got}")
        lines.append(f"    - `lala2/{key}-page{got}.jpg` {w}x{h}（{origin}） ← {full[:110]}")
    return lines or ["    - **公式ページからは取れなかった。**"]

API = "https://commons.wikimedia.org/w/api.php"

def commons(term, key):
    """Commons を施設名で検索して、上位の写真を落とす。ライセンスも一緒に記録する。"""
    lines = []
    try:
        q = urllib.parse.urlencode({
            "action": "query", "format": "json", "generator": "search",
            "gsrsearch": f'filetype:bitmap "{term}"', "gsrnamespace": "6", "gsrlimit": "6",
            "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": "1200",
        })
        data = json.loads(get(f"{API}?{q}"))
    except Exception as e:
        return [f"    - Commons 検索に失敗（{type(e).__name__}）"]
    pages = (data.get("query") or {}).get("pages") or {}
    got = 0
    for _, p in sorted(pages.items()):
        if got >= 3:
            break
        ii = (p.get("imageinfo") or [{}])[0]
        url = ii.get("thumburl") or ii.get("url")
        if not url:
            continue
        meta = ii.get("extmetadata") or {}
        lic = (meta.get("LicenseShortName") or {}).get("value", "?")
        art = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "?"))[:60]
        if re.search(r"non-?free|fair ?use", lic, re.I):
            continue
        try:
            im = Image.open(io.BytesIO(getb(url))).convert("RGB")
        except Exception:
            continue
        if im.width < 640 or not (1.0 <= im.width / im.height <= 2.4):
            continue
        got += 1
        save(im, f"{key}-cc{got}")
        lines.append(f"    - `lala2/{key}-cc{got}.jpg` {im.width}x{im.height}"
                     f" ／ライセンス **{lic}** ／作者 {art}"
                     f" ／{p.get('title','')}")
    return lines or ["    - Commons に使える写真が見つからなかった。"]

BASE = "https://mitsui-shopping-park.com/"
FACILITIES = [
    ("kashiwa",   "④ 柏の葉",   "lalaport/kashiwa/",     "ららぽーと柏の葉"),
    ("iwata",     "⑥ 磐田",     "lalaport/iwata/",       "ららぽーと磐田"),
    ("shinmisato","⑦ 新三郷",   "lalaport/shinmisato/",  "ららぽーと新三郷"),
    ("izumi",     "⑧ 和泉",     "lalaport/izumi/",       "ららぽーと和泉"),
    ("ebina",     "⑩ 海老名",   "lalaport/ebina/",       "ららぽーと海老名"),
    ("tachikawa", "⑫ 立川立飛", "lalaport/tachikawa/",   "ららぽーと立川立飛"),
    ("hiratsuka", "⑬ 湘南平塚", "lalaport/hiratsuka/",   "ららぽーと湘南平塚"),
    ("minato",    "⑭ 名古屋",   "lalaport/minatoaquls/", "ららぽーと名古屋みなとアクルス"),
    ("numazu",    "⑮ 沼津",     "lalaport/numazu/",      "ららぽーと沼津"),
    ("togo",      "⑯ 愛知東郷", "lalaport/togo/",        "ららぽーと愛知東郷"),
    ("sakai",     "⑱ 堺",       "lalaport/sakai/",       "ららぽーと堺"),
    ("kadoma",    "⑲ 門真",     "lalaport/kadoma/",      "ららぽーと門真"),
    ("koshien",   "② 甲子園",   "lalaport/koshien/",     "ららぽーと甲子園"),
]

out = ["# ららぽーと 施設写真の取り直し（063）", "",
       "**062 は 63 枚すべてハズレ**（イベントのチラシ・商品写真・テナントのロゴ）。",
       "原因は**キービジュアルを除外条件で弾いていた**こと。今回は 2 経路を試す。", "",
       "- **A) 公式ページ**: キービジュアルと og:image を候補に入れ、",
       "  代わりに `/event/` `/shopnews/` `/pickup/` `/topics/` `/openrenewal/` の階層を弾く",
       "- **B) Wikimedia Commons**: 施設名で検索。**ライセンスと作者を必ず記録する**", "",
       "**どちらも目で見てから使うこと。**", ""]

for key, label, path, term in FACILITIES:
    out += [f"## {key} — {label}", "", "  - A) 公式ページ"]
    try:
        out += hero(get(BASE + path), BASE + path, key)
    except Exception as e:
        out.append(f"    - `{BASE+path}` 取得できず（{type(e).__name__}）")
    out += ["  - B) Wikimedia Commons"] + commons(term, key) + [""]
    time.sleep(1)

open(f"{RDIR}/lalaport-photos-v2.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1500])
PYEOF

BR="claude/lalaport-photos2"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f lala2 >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: ららぽーと施設写真の取り直し（063）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/lalaport-photos-v2.md / branch $BR"
