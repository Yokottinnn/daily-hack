#!/bin/bash
# モーニング記事の追材。利用者から 2026-09-04 に来た指摘に対応するためのもの。
#
#   「表紙は各サービスチェーンのロゴを公式サイトから取得して」
#   「全てのサービス名のタイトルの横にサービスロゴを載せて。もれなく全て」
#   「各サービスで1個か2個ずつ、実際のメニューの紹介とメニューの画像を取得して添付して」
#   「画像が全体的に表示されていないので拡大を変えたりして」
#
# 取るものは 2 つ。**チェーンごとに分けて報告する。**
#
#   A) ロゴ  … ヘッダの `logo` 画像・`apple-touch-icon`・og:image を候補にする。
#              **PNG は透過を保ったまま保存する**（見出しの横に置くため）
#   B) メニュー … 052 と同じく**品目ページまで降りて**、品名と写真を組で取る。
#              一覧ページの先頭画像はバナーであることが多い（051 の失敗）
#
# **今回は大きい画像を優先する。** 記事の図版が小さくて眠いという指摘があったため、
# 幅 900px 以上を「大」として印をつけ、選ぶときの手がかりにする。
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-morning4-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p m4

"$PY" - "$RDIR" <<'PYEOF'
import io, re, sys, time, urllib.parse, urllib.request
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


def save(im, name, keep_alpha=False):
    """透過を保ちたいものは PNG、写真は JPG。**サムネも一緒に出す**（目視用）。"""
    if keep_alpha and im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        p = f"m4/{name}.png"
        im.save(p)
        bg = Image.new("RGB", im.size, (255, 255, 255))
        bg.paste(im, mask=im.split()[-1])
        flat = bg
    else:
        flat = im.convert("RGB")
        p = f"m4/{name}.jpg"
        flat.save(p, quality=92)
    w = 480
    flat.resize((w, max(1, int(flat.height * w / flat.width)))).convert("RGB").save(
        f"m4/thumb-{name}.jpg", quality=74)
    return p


# ---- A) ロゴ ---------------------------------------------------------------
# **ここでは logo を弾かない。logo こそが目的。**
LOGO_HINT = re.compile(r"logo|brand|apple-touch|touch-icon", re.I)


def logos(html, base, key, want=4):
    lines, seen, got = [], set(), 0
    cands = []
    for m in re.finditer(r'<link[^>]+rel=["\'][^"\']*(?:apple-touch-icon|icon)[^"\']*["\'][^>]*>', html, re.I):
        h = re.search(r'href=["\']([^"\']+)', m.group(0), re.I)
        if h:
            cands.append(("link-icon", h.group(1)))
    for m in re.finditer(r'<img[^>]+>', html, re.I):
        tag = m.group(0)
        src = re.search(r'(?:data-)?src=["\']([^"\']+)', tag, re.I)
        if not src:
            continue
        alt = re.search(r'alt=["\']([^"\']*)', tag, re.I)
        if LOGO_HINT.search(src.group(1)) or (alt and LOGO_HINT.search(alt.group(1))):
            cands.append(("img-logo", src.group(1)))
    m = re.search(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)', html, re.I)
    if m:
        cands.append(("og:image", m.group(1)))

    for origin, c in cands:
        if got >= want:
            break
        if not re.search(r"\.(png|jpe?g|svg|webp)(\?|$)", c, re.I):
            continue
        full = urllib.parse.urljoin(base, c)
        if full in seen:
            continue
        seen.add(full)
        if full.lower().split("?")[0].endswith(".svg"):
            # SVG は Pillow で開けない。**URL だけ報告して人に判断させる。**
            got += 1
            lines.append(f"    - **SVG**（保存していない・要手動）{full[:120]}")
            continue
        try:
            im = Image.open(io.BytesIO(getb(full)))
        except Exception:
            continue
        if im.width < 80 or im.height < 40:
            continue
        got += 1
        p = save(im, f"{key}-logo{got}", keep_alpha=True)
        lines.append(f"    - `{p}` {im.width}x{im.height} mode={im.mode}（{origin}） ← {full[:110]}")
    return lines or ["    - **ロゴが取れなかった。**"]


# ---- B) メニュー（品名 ＋ 写真） --------------------------------------------
BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner|bnr"
                 r"|campaign|ticket|coupon|news", re.I)


def title_of(html):
    for pat in (r'<h1[^>]*>(.*?)</h1>', r'<title[^>]*>(.*?)</title>'):
        m = re.search(pat, html, re.I | re.S)
        if m:
            t = re.sub(r"<[^>]+>", "", m.group(1))
            t = re.sub(r"\s+", " ", t).strip()
            if t:
                return t[:80]
    return "(品名が取れなかった)"


def dish(html, base, key, n, seen):
    """1 ページから料理写真を 1 枚だけ。**いちばん大きいものを選ぶ。**"""
    best = None
    cs = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
    cs += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
    for c in cs[:40]:
        if not re.search(r"\.(jpe?g|png|webp)(\?|$)", c, re.I) or BAD.search(c):
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
        if w < 400 or h < 260 or not (0.8 <= w / h <= 2.1):
            continue
        if best is None or w * h > best[0].width * best[0].height:
            best = (im, full)
    if best is None:
        return None
    im, full = best
    p = save(im, f"{key}-dish{n}")
    big = "**大**" if im.width >= 900 else "小"
    return f"`{p}` {im.width}x{im.height} {big} ← {full[:100]}"


# key, 表示名, トップ（ロゴ用）, モーニングの一覧, 品目ページの目印
CHAINS = [
    ("stmarc",   "① サンマルクカフェ", "https://www.saint-marc-hd.com/saintmarccafe/",
     "https://www.saint-marc-hd.com/saintmarccafe/menu/", ["/menu/"]),
    ("mcd",      "② マクドナルド", "https://www.mcdonalds.co.jp/",
     "https://www.mcdonalds.co.jp/menu/morning/", ["/products/", "/menu/"]),
    ("mos",      "③ モスバーガー", "https://www.mos.jp/",
     "https://www.mos.jp/menu/category/?c_id=12", ["/menu/detail/", "/menu/"]),
    ("komeda",   "④ コメダ珈琲店", "https://www.komeda.co.jp/",
     "https://www.komeda.co.jp/menu/morning_komeda.html", ["/menu/"]),
    ("nakau",    "⑤ なか卯", "https://www.nakau.co.jp/jp/",
     "https://www.nakau.co.jp/jp/menu/category/6.html", ["/menu/detail/"]),
    ("matsuya",  "⑥ 松屋", "https://www.matsuyafoods.co.jp/",
     "https://www.matsuyafoods.co.jp/matsuya/menu/morning/", ["/menu/morning/"]),
    ("yoshinoya", "⑦ 吉野家", "https://www.yoshinoya.com/",
     "https://www.yoshinoya.com/menu/morningset/", ["/menu/morningset/"]),
    ("sukiya",   "⑧ すき家", "https://www.sukiya.jp/",
     "https://www.sukiya.jp/menu/in/morning/", ["/menu/in/"]),
    ("doutor",   "ドトール", "https://www.doutor.co.jp/",
     "https://www.doutor.co.jp/dcs/menu/list/morning.html", ["/dcs/menu/"]),
    ("ueshima",  "上島珈琲店", "https://www.ueshima-coffee-ten.jp/",
     "https://www.ueshima-coffee-ten.jp/menu/morning/", ["/menu/"]),
]

out = ["# モーニング記事：チェーンのロゴと、メニューの写真（065）", "",
       "利用者の指摘（2026-09-04）に対応するための追材。", "",
       "- **A) ロゴ** … 見出しの横と表紙に置く。**PNG は透過のまま保存**している",
       "- **B) メニュー** … 品目ページまで降りて、**品名と写真を組で**取る",
       "",
       "**写真は必ず目で見てから使うこと。** 051 ではポケモンのコラボ意匠と、",
       "別業態（ベーカリーレストラン「サンマルク」）の料理を掴んでいた。",
       "", "幅 900px 以上のものに **大** と印をつけている。記事の図版が小さいという",
       "指摘があったため、大きいものを優先して選ぶこと。", ""]

for key, label, top, index, pats in CHAINS:
    out += [f"## {key} — {label}", "", "  - A) ロゴ"]
    try:
        out += logos(get(top), top, key)
    except Exception as e:
        out.append(f"    - `{top}` 取得できず（{type(e).__name__}）")

    out += ["  - B) メニュー"]
    try:
        html = get(index)
    except Exception as e:
        out += [f"    - `{index}` 取得できず（{type(e).__name__}）", ""]
        time.sleep(1)
        continue

    seen = set()
    links, ls = [], set()
    for m in re.finditer(r'href=["\']([^"\']+)["\']', html, re.I):
        h = urllib.parse.urljoin(index, m.group(1)).split("#")[0]
        if h == index or h in ls or not any(p in h for p in pats):
            continue
        ls.add(h)
        links.append(h)
        if len(links) >= 6:
            break

    n = 0
    for lk in links:
        if n >= 2:
            break
        try:
            sub = get(lk)
        except Exception:
            continue
        d = dish(sub, lk, key, n + 1, seen)
        if d:
            n += 1
            out.append(f"    - **{title_of(sub)}**")
            out.append(f"      {d}")
            out.append(f"      ページ: {lk[:110]}")
        time.sleep(1)
    if n == 0:
        # 品目ページから取れないときは一覧ページ自体から拾う（**バナーに注意**）
        d = dish(html, index, key, 1, seen)
        out.append(f"    - 一覧ページから: {d}" if d else "    - **メニュー写真が取れなかった。**")
    out.append("")
    time.sleep(1)

open(f"{RDIR}/morning-logos-menus.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1800])
PYEOF

BR="claude/morning-logos"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f m4 >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: モーニング記事のロゴとメニュー写真（065）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/morning-logos-menus.md / branch $BR"
