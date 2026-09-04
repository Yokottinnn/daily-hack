#!/bin/bash
# 063 の続き。**残り 10 施設**の写真を Wikimedia Commons から探す。
#
# 063 で分かったこと。
#   - **経路 A（公式ページ）は使えない。** page1〜4 が全施設で同じ URL を返した
#     （`mitsui-shopping-park.com/ec/medias/...` ＝ EC の共有素材）。og:image だけが
#     施設ごとに違ったが、それも 4 施設しか取れなかった。**今回は A をやらない。**
#   - **経路 B（Commons）は当たり。** ファイル名が施設名で、ライセンスも明記されている。
#     ただし検索語 1 本だと外す（沼津＝富士急バス／湘南平塚＝自転車の空気入れ）。
#     **今回は施設ごとに検索語を 3 本投げて、上位 4 枚まで拾う。**
#
# もう 1 つやること: **既存 8 枚の出典を突き止める。**
#   `public/images/lalaport-guide-2026/photos/` の tokyobay/toyosu/yokohama/fujimi/
#   expocity/fukuoka/kashiwa/anjo は記事公開時から入っているが、`_manifest.json` が
#   無く**ライセンスも作者も記録が無い**。図版として本文に出すには出典が要る。
#   Commons の候補と **dHash（8x8 の差分ハッシュ）**を突き合わせて、一致すれば
#   そのファイルが出典だと分かる。ハミング距離 <= 8 を候補として報告する。
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-lala3-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p lala3

"$PY" - "$RDIR" <<'PYEOF'
import io, json, os, re, sys, time, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "daily-hack-ops/1.0 (blog article research; contact via github.com/Yokottinnn/daily-hack)"}
API = "https://commons.wikimedia.org/w/api.php"


def get(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()


def dhash(im, s=8):
    """8x8 の差分ハッシュ。写真が同じかどうかの判定に使う。"""
    g = im.convert("L").resize((s + 1, s), Image.LANCZOS)
    px = list(g.getdata())
    bits = 0
    for y in range(s):
        row = px[y * (s + 1):(y + 1) * (s + 1)]
        for x in range(s):
            bits = (bits << 1) | (1 if row[x] < row[x + 1] else 0)
    return bits


def dist(a, b):
    return bin(a ^ b).count("1")


def save(im, name):
    if im.width > 1600:
        im.thumbnail((1600, 1600))
    im.save(f"lala3/{name}.jpg", quality=88)
    im.resize((480, max(1, int(im.height * 480 / im.width)))).save(
        f"lala3/thumb-{name}.jpg", quality=72)


# ---- 既存写真のハッシュ（出典の突き合わせ用） --------------------------------
EXIST_DIR = "public/images/lalaport-guide-2026/photos"
exist = {}
for f in sorted(os.listdir(EXIST_DIR)) if os.path.isdir(EXIST_DIR) else []:
    if not f.endswith(".jpg") or f.startswith("fac-"):
        continue
    try:
        exist[f] = dhash(Image.open(os.path.join(EXIST_DIR, f)))
    except Exception:
        pass


def commons(terms, key, want=4):
    """検索語を複数投げて、重複を除いて上位 want 枚まで落とす。"""
    lines, seen, got = [], set(), 0
    for term in terms:
        if got >= want:
            break
        try:
            q = urllib.parse.urlencode({
                "action": "query", "format": "json", "generator": "search",
                "gsrsearch": f'filetype:bitmap {term}', "gsrnamespace": "6", "gsrlimit": "8",
                "prop": "imageinfo", "iiprop": "url|extmetadata", "iiurlwidth": "1200",
            })
            data = json.loads(get(f"{API}?{q}").decode("utf-8", "replace"))
        except Exception as e:
            lines.append(f"    - 検索 `{term}` に失敗（{type(e).__name__}）")
            continue
        pages = (data.get("query") or {}).get("pages") or {}
        for _, p in sorted(pages.items(), key=lambda kv: kv[1].get("index", 99)):
            if got >= want:
                break
            title = p.get("title", "")
            if title in seen:
                continue
            seen.add(title)
            ii = (p.get("imageinfo") or [{}])[0]
            url = ii.get("thumburl") or ii.get("url")
            if not url:
                continue
            meta = ii.get("extmetadata") or {}
            lic = (meta.get("LicenseShortName") or {}).get("value", "?")
            art = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "?"))[:60]
            if re.search(r"non-?free|fair ?use|all rights reserved", lic, re.I):
                continue
            try:
                im = Image.open(io.BytesIO(get(url))).convert("RGB")
            except Exception:
                continue
            if im.width < 640 or not (1.0 <= im.width / im.height <= 2.4):
                continue
            got += 1
            save(im, f"{key}-cc{got}")
            h = dhash(im)
            same = [f"{f}(距離{dist(h, e)})" for f, e in exist.items() if dist(h, e) <= 8]
            hit = f" ／**既存 {', '.join(same)} と一致**" if same else ""
            lines.append(f"    - `lala3/{key}-cc{got}.jpg` {im.width}x{im.height}"
                         f" ／ライセンス **{lic}** ／作者 {art} ／{title}"
                         f" ／検索語 `{term}`{hit}")
        time.sleep(1)
    return lines or ["    - Commons に使える写真が見つからなかった。"]


# 残り 10 施設。検索語は「日本語表記」「英語表記」「別名・地名」の 3 本を用意する。
FACILITIES = [
    ("tokyobay",  "① TOKYO-BAY", ['"ららぽーとTOKYO-BAY"', '"LaLaport TOKYO-BAY"', '"ららぽーと船橋"']),
    ("toyosu",    "③ 豊洲",      ['"ららぽーと豊洲"', '"LaLaport Toyosu"', '"Urban Dock LaLaport"']),
    ("yokohama",  "⑤ 横浜",      ['"ららぽーと横浜"', '"LaLaport Yokohama"', '"Lalaport-Yokohama"']),
    ("iwata",     "⑥ 磐田",      ['"ららぽーと磐田"', '"LaLaport Iwata"', '"Lalaport Iwata Shizuoka"']),
    ("fujimi",    "⑨ 富士見",    ['"ららぽーと富士見"', '"LaLaport Fujimi"', '"Lalaport Fujimi Saitama"']),
    ("expocity",  "⑪ EXPOCITY",  ['"ららぽーとEXPOCITY"', '"LaLaport EXPOCITY"', '"EXPOCITY Suita"']),
    ("fukuoka",   "⑰ 福岡",      ['"ららぽーと福岡"', '"LaLaport Fukuoka"', '"Lalaport Fukuoka gundam"']),
    ("sakai",     "⑱ 堺",        ['"ららぽーと堺"', '"LaLaport Sakai"', '"Lalaport Sakai Osaka"']),
    ("kadoma",    "⑲ 門真",      ['"ららぽーと門真"', '"LaLaport Kadoma"', '"Mitsui Outlet Park Osaka Kadoma"']),
    ("anjo",      "⑳ 安城",      ['"ららぽーと安城"', '"LaLaport Anjo"', '"Lalaport Anjo Aichi"']),
]

out = ["# ららぽーと 残り10施設の写真（064）", "",
       "063 で 10 施設は決まった。**残りはこの 10 施設**。",
       "公式ページ経路は 063 で全滅（全施設が同じ EC 共有素材を返した）ため、**Commons だけを見る**。",
       "検索語は施設ごとに 3 本投げて、重複を除いて上位 4 枚まで拾う。", "",
       "**必ず目で見てから使うこと。** 063 では沼津の 1 位が富士急バス、",
       "湘南平塚の 1 位が自転車の空気入れだった。", "",
       f"既存写真 {len(exist)} 枚のハッシュと突き合わせている。",
       "「**既存 xxx.jpg と一致**」と出たものは、その既存写真の出典がこのファイルということ。", ""]

for key, label, terms in FACILITIES:
    out += [f"## {key} — {label}", ""] + commons(terms, key) + [""]

open(f"{RDIR}/lalaport-photos-rest.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1800])
PYEOF

BR="claude/lalaport-photos3"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f lala3 >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: ららぽーと残り10施設の写真候補（064）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/lalaport-photos-rest.md / branch $BR"
