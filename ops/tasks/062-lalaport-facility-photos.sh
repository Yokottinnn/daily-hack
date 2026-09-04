#!/bin/bash
# ららぽーと記事の「全20施設を1軒ずつ」の節には**写真が1枚も無い**（記事全体でも7枚）。
# 三井ショッピングパークの各施設ページから、施設写真を取ってくる。
#
# **一覧ページの先頭画像はバナーであることが多い。** 052/054/055 と同じく、
# ファイル名にバナー系の語が入るものと、帯状（縦横比が極端）のものを弾く。
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-lala-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p lala

"$PY" - "$RDIR" <<'PYEOF'
import io, re, sys, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

def getb(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner|bnr"
                 r"|campaign|coupon|kv|main_?visual|top_?img|avatar|common|nav|header|footer", re.I)

def photos(html, base, key, want=3):
    got, lines, seen = 0, [], set()
    cs = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
    cs += re.findall(r'<img[^>]+data-original=["\']([^"\']+)["\']', html, re.I)
    cs += re.findall(r'<source[^>]+srcset=["\']([^"\',\s]+)', html, re.I)
    cs += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
    for c in cs:
        if got >= want: break
        if not re.search(r"\.(jpe?g|png|webp)(\?|$)", c, re.I) or BAD.search(c): continue
        full = urllib.parse.urljoin(base, c)
        if full in seen: continue
        seen.add(full)
        try:
            im = Image.open(io.BytesIO(getb(full))).convert("RGB")
        except Exception:
            continue
        w, h = im.size
        if w < 640 or h < 360 or not (1.1 <= w / h <= 2.2): continue
        got += 1
        name = f"{key}-{got}"
        if w > 1600:
            im.thumbnail((1600, 1600))
        im.save(f"lala/{name}.jpg", quality=88)
        im.resize((480, max(1, int(im.height * 480 / im.width)))).save(
            f"lala/thumb-{name}.jpg", quality=72)
        lines.append(f"- 写真 `lala/{name}.jpg` {w}x{h} ← {full[:115]}")
    return lines or ["- **写真が取れなかった。**"]

BASE = "https://mitsui-shopping-park.com/"
FACILITIES = [
    ("tokyobay",  "① TOKYO-BAY",           "lalaport/tokyo-bay/"),
    ("koshien",   "② 甲子園",               "lalaport/koshien/"),
    ("toyosu",    "③ 豊洲",                 "lalaport/toyosu/"),
    ("kashiwa",   "④ 柏の葉",               "lalaport/kashiwa/"),
    ("yokohama",  "⑤ 横浜",                 "lalaport/yokohama/"),
    ("iwata",     "⑥ 磐田",                 "lalaport/iwata/"),
    ("shinmisato","⑦ 新三郷",               "lalaport/shinmisato/"),
    ("izumi",     "⑧ 和泉",                 "lalaport/izumi/"),
    ("fujimi",    "⑨ 富士見",               "lalaport/fujimi/"),
    ("ebina",     "⑩ 海老名",               "lalaport/ebina/"),
    ("expocity",  "⑪ EXPOCITY",            "lalaport/expocity/"),
    ("tachikawa", "⑫ 立川立飛",             "lalaport/tachikawa/"),
    ("hiratsuka", "⑬ 湘南平塚",             "lalaport/hiratsuka/"),
    ("minato",    "⑭ 名古屋みなとアクルス", "lalaport/minatoaquls/"),
    ("numazu",    "⑮ 沼津",                 "lalaport/numazu/"),
    ("togo",      "⑯ 愛知東郷",             "lalaport/togo/"),
    ("fukuoka",   "⑰ 福岡",                 "lalaport/fukuoka/"),
    ("sakai",     "⑱ 堺",                   "lalaport/sakai/"),
    ("kadoma",    "⑲ 門真",                 "lalaport/kadoma/"),
    ("anjo",      "⑳ 安城",                 "lalaport/anjo/"),
    ("lazona",    "ラゾーナ川崎プラザ",      "lazona-kawasaki/"),
]

out = ["# ららぽーと 全施設の写真（062）", "",
       "**節に写真が1枚も無いので、公式の施設ページから取る。**",
       "**バナー・ロゴ・共通素材は弾いてある。それでも目で見てから使うこと。**", ""]

for key, label, path in FACILITIES:
    url = BASE + path
    out += [f"## {key} — {label}", ""]
    try:
        html = get(url)
    except Exception as e:
        out += [f"- `{url}` 取得できず（{type(e).__name__}: {e}）", ""]
        continue
    out += [f"- ページ `{url}`"] + photos(html, url, key) + [""]

open(f"{RDIR}/lalaport-photos.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1500])
PYEOF

BR="claude/lalaport-photos"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f lala >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: ららぽーと全施設の写真（062）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/lalaport-photos.md / branch $BR"
