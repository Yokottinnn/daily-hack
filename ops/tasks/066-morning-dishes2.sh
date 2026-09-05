#!/bin/bash
# 065 の取り直し。**メニュー写真が 18 枚中 3 枚しか使えなかった。**
#
# 使えたのは 松屋（ソーセージエッグW定食）／吉野家（塩さば牛小鉢定食・塩さば特朝定食）だけ。
# 外したものと、その理由。
#
#   マクドナルド … 月見バーガー・ビッグマック（**朝マックではない**）
#   すき家       … 牛丼・うな丼（**朝食ではない**）
#   ドトール     … カフェラテ・タピオカ（**モーニングセットではない**）
#   モスバーガー … ポテト＋アイスティー／**コーヒーチケットの販促バナー**
#   サンマルク   … **ミニオンのコラボ意匠**（051 のポケモンと同じ失敗）
#   コメダ       … いちごのケーキ（**モーニングではない**）
#   なか卯       … **真っ黒の壊れた画像**
#   上島珈琲店   … コーヒー豆の陳列棚／アイスコーヒー
#
# **原因は起点と、たどるリンク。** 一般のメニュー一覧から入ったので、
# `/menu/burger/` `/menu/in/gyudon/` `hotdrink.html` のような**朝と無関係の
# 品目ページ**に降りていた。
#
# 今回は 3 つ変える。
#   1) 起点を**モーニングのページに固定する**
#   2) たどるリンクを**朝の品目に絞る**（morning / asa / 朝 を含むものだけ）
#   3) 1 チェーンあたり**最大 5 枚**を大きい順に保存する（2 枚だと選べない）
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-morning5-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p m5

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


BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner|bnr"
                 r"|campaign|ticket|coupon|news|share|line_|twitter|insta", re.I)
# **コラボ意匠を弾く。** 051 でポケモン、065 でミニオンを掴んでいる。
COLLAB = re.compile(r"minion|pokemon|pikachu|collab|chara|tieup|sanrio|disney", re.I)


def title_of(html):
    for pat in (r'<h1[^>]*>(.*?)</h1>', r'<title[^>]*>(.*?)</title>'):
        m = re.search(pat, html, re.I | re.S)
        if m:
            t = re.sub(r"<[^>]+>", "", m.group(1))
            t = re.sub(r"\s+", " ", t).strip()
            if t:
                return t[:80]
    return "(品名なし)"


def collect(html, base, seen):
    """1 ページから料理写真の候補を集める。**保存はまだしない。**"""
    got = []
    cs = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
    cs += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
    for c in cs[:60]:
        if not re.search(r"\.(jpe?g|png|webp)(\?|$)", c, re.I):
            continue
        if BAD.search(c) or COLLAB.search(c):
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
        if w < 420 or h < 280 or not (0.75 <= w / h <= 2.1):
            continue
        # **真っ黒・真っ白は壊れた画像**。065 のなか卯がこれだった。
        ex = im.resize((16, 16)).getdata()
        avg = sum(sum(p) for p in ex) / (16 * 16 * 3)
        if avg < 26 or avg > 249:
            continue
        got.append((w * h, im, full))
    return got


# key, 表示名, **モーニングのページ**, 朝の品目リンクの目印
CHAINS = [
    ("stmarc",   "① サンマルクカフェ", "https://www.saint-marc-hd.com/saintmarccafe/news/1318/",
     ["morning", "asa", "1318"]),
    ("mcd",      "② マクドナルド", "https://www.mcdonalds.co.jp/menu/morning/",
     ["/morning/", "morning"]),
    ("mos",      "③ モスバーガー", "https://www.mos.jp/menu/category/?c_id=12",
     ["/menu/detail/", "c_id=12"]),
    ("komeda",   "④ コメダ珈琲店", "https://www.komeda.co.jp/menu/morning_komeda.html",
     ["morning"]),
    ("nakau",    "⑤ なか卯", "https://www.nakau.co.jp/jp/menu/category/6.html",
     ["/menu/detail/in/"]),
    ("matsuya",  "⑥ 松屋", "https://www.matsuyafoods.co.jp/matsuya/menu/morning/",
     ["/menu/morning/"]),
    ("yoshinoya", "⑦ 吉野家", "https://www.yoshinoya.com/menu/morningset/",
     ["/menu/morningset/"]),
    ("sukiya",   "⑧ すき家", "https://www.sukiya.jp/menu/in/morning/",
     ["morning", "/menu/in/morning"]),
    ("doutor",   "ドトール", "https://www.doutor.co.jp/dcs/menu/list/morning.html",
     ["morning", "/dcs/menu/detail"]),
    ("ueshima",  "上島珈琲店", "https://www.ueshima-coffee-ten.jp/menu/morning/",
     ["morning", "/menu/"]),
]

out = ["# モーニング記事：朝メニューの写真を取り直す（066）", "",
       "**065 は 18 枚中 3 枚しか使えなかった。** 一般のメニュー一覧から入ったため、",
       "月見バーガー・ビッグマック・牛丼・うな丼・タピオカ・ミニオンのコラボ意匠",
       "といった**朝と無関係の品目**に降りていた。", "",
       "今回は起点をモーニングのページに固定し、たどるリンクも朝に絞る。",
       "1 チェーンあたり**大きい順に最大 5 枚**。", "",
       "**それでも目で見ること。** 販促バナーとコラボ意匠は名前で弾ききれない。", ""]

for key, label, index, pats in CHAINS:
    out += [f"## {key} — {label}", "", f"  起点: {index}", ""]
    try:
        html = get(index)
    except Exception as e:
        out += [f"  - **取得できず**（{type(e).__name__}）", ""]
        time.sleep(1)
        continue

    seen = set()
    pool = [(a, im, u, title_of(html)) for a, im, u in collect(html, index, seen)]

    links, ls = [], set()
    for m in re.finditer(r'href=["\']([^"\']+)["\']', html, re.I):
        h = urllib.parse.urljoin(index, m.group(1)).split("#")[0]
        if h == index or h in ls or not any(p in h for p in pats):
            continue
        ls.add(h)
        links.append(h)
        if len(links) >= 6:
            break

    for lk in links:
        try:
            sub = get(lk)
        except Exception:
            continue
        t = title_of(sub)
        pool += [(a, im, u, t) for a, im, u in collect(sub, lk, seen)]
        time.sleep(1)

    pool.sort(key=lambda x: -x[0])
    if not pool:
        out += ["  - **朝メニューの写真が取れなかった。**", ""]
        time.sleep(1)
        continue

    for n, (_, im, url, t) in enumerate(pool[:5], 1):
        name = f"{key}-{n}"
        im.save(f"m5/{name}.jpg", quality=92)
        im.resize((480, max(1, int(im.height * 480 / im.width)))).save(
            f"m5/thumb-{name}.jpg", quality=74)
        big = "**大**" if im.width >= 900 else "小"
        out.append(f"  - `m5/{name}.jpg` {im.width}x{im.height} {big} ／ **{t}**")
        out.append(f"    {url[:110]}")
    out.append("")
    time.sleep(1)

open(f"{RDIR}/morning-dishes2.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1800])
PYEOF

BR="claude/morning-dishes2"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f m5 >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: 朝メニューの写真を取り直す（066）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/morning-dishes2.md / branch $BR"
