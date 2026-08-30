#!/bin/bash
# 049 の続き。**値段が JS 描画で取れなかった**チェーンを埋める。
#
# 049 で分かったこと:
#   - 提供時間は取れた（コメダ11:00 / すき家4:00-11:00 / 松屋5:00-11:00 /
#     吉野家4:00-11:00 / なか卯4:00-11:00 / マック10:30）
#   - **値段は落ちた。** 松屋は「530円」だけ出て品名が消え、なか卯と吉野家は
#     「円(税込)」と単位だけが出た。抜き出しの絞り込みが「定食」を含んでいなかったのと、
#     価格が JS で後から入るページがあるため。
#
# ここでやること:
#   ① 絞り込みをやめて、朝メニューのページを**素のテキストのまま**落とす
#   ② 公式の朝メニュー index から**品目ページの URL を発見して**たどる（当て推量の URL は作らない）
#   ③ JSON-LD（構造化データ）に価格があれば拾う
#   ④ 049 で写真が取れなかったチェーンの写真を取り直す
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-morning2-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p morning

"$PY" - "$RDIR" <<'PYEOF'
import io, json, re, sys, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

JP = re.compile(r"[ぁ-んァ-ヶ一-龠]")

def text_lines(html, limit=220):
    """絞り込みをしない。日本語を含む行をそのまま順番に出す。"""
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&quot;", '"'),
                 ("&#039;", "'"), ("&yen;", "¥"), ("&hellip;", "…")):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or len(l) > 130 or l in seen:
            continue
        if not (JP.search(l) or re.search(r"\d", l)):
            continue
        seen.add(l); out.append(l)
    return out[:limit]

def jsonld_prices(html):
    """構造化データに価格があれば拾う。"""
    hits = []
    for m in re.finditer(r'(?is)<script[^>]+application/ld\+json[^>]*>(.*?)</script>', html):
        try:
            data = json.loads(m.group(1).strip())
        except Exception:
            continue
        stack = [data]
        while stack:
            n = stack.pop()
            if isinstance(n, dict):
                nm = n.get("name")
                offer = n.get("offers")
                pr = None
                if isinstance(offer, dict):
                    pr = offer.get("price")
                elif isinstance(offer, list) and offer:
                    pr = (offer[0] or {}).get("price")
                pr = pr or n.get("price")
                if nm and pr:
                    hits.append(f"{nm} = {pr}")
                stack += [v for v in n.values() if isinstance(v, (dict, list))]
            elif isinstance(n, list):
                stack += [v for v in n if isinstance(v, (dict, list))]
    return hits[:80]

def discover(html, base, pats, limit=10):
    """公式ページの中から品目ページのリンクを発見する。URL は組み立てない。"""
    found, seen = [], set()
    for m in re.finditer(r'href=["\']([^"\']+)["\']', html, re.I):
        h = urllib.parse.urljoin(base, m.group(1))
        if not h.startswith(base.split("/")[0] + "//" + urllib.parse.urlparse(base).netloc):
            continue
        if h in seen or not any(p in h for p in pats):
            continue
        seen.add(h); found.append(h)
        if len(found) >= limit:
            break
    return found

BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner|bnr", re.I)

def grab_photo(html, base, key):
    cs = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
    cs += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
    for c in cs:
        if not re.search(r"\.(jpe?g|png|webp)(\?|$)", c, re.I) or BAD.search(c):
            continue
        full = urllib.parse.urljoin(base, c)
        try:
            im = Image.open(io.BytesIO(urllib.request.urlopen(
                urllib.request.Request(full, headers=UA), timeout=30).read())).convert("RGB")
        except Exception:
            continue
        w, h = im.size
        if w < 600 or h < 340 or w / h < 1.1:
            continue
        im.save(f"morning/{key}.jpg", quality=92)
        im.resize((480, max(1, int(h * 480 / w)))).save(f"morning/thumb-{key}.jpg", quality=72)
        return f"- 写真 `morning/{key}.jpg` {w}x{h} ← {full[:110]}"
    return "- **写真が取れなかった。**"

# key, 表示名, index ページ, 品目ページを見分ける文字列, 写真が要るか
TARGETS = [
    ("matsuya",  "松屋",         "https://www.matsuyafoods.co.jp/matsuya/menu/morning/",
     ["/menu/morning/"], True),
    ("nakau",    "なか卯",       "https://www.nakau.co.jp/jp/menu/category/6.html",
     ["/menu/detail/"], True),
    ("yoshinoya","吉野家",       "https://www.yoshinoya.com/menu/morningset/",
     ["/menu/morningset/"], False),
    ("sukiya",   "すき家",       "https://www.sukiya.jp/menu/in/morning/",
     ["/menu/in/morning/"], False),
    ("mcd",      "マクドナルド", "https://www.mcdonalds.co.jp/menu/morning/",
     ["/menu/morning/"], False),
    ("doutor",   "ドトールコーヒー", "https://www.doutor.co.jp/dcs/menu/",
     ["morning", "asa", "breakfast", "set"], True),
    ("hoshino",  "星乃珈琲店",   "https://www.hoshinocoffee.com/",
     ["menu", "morning"], True),
    ("stmarc",   "サンマルクカフェ", "https://www.saint-marc-hd.com/saintmarccafe/news/1318/",
     ["saintmarccafe", "morning"], True),
    ("mos",      "モスバーガー", "https://www.mos.jp/menu/category/?c_id=12",
     ["menu", "c_id=12"], True),
    ("gusto",    "ガスト",       "https://www.skylark.co.jp/gusto/menu/menu_category.html?cid=390",
     ["menu_detail", "cid=390", "cid=400"], True),
]

out = ["# 500円モーニング：値段の取り直し（049 の続き）", "",
       "**049 では提供時間は取れたが、値段が JS 描画で落ちた。**ここでは絞り込みをやめて",
       "素のテキストを出し、公式ページの中から品目ページのリンクを**発見して**たどっている。",
       "**URL を当て推量で組み立てていない。**", "",
       "**値段と提供時間が公式で確認できなかったチェーンは記事に載せないこと。**", ""]

for key, label, index, pats, want_photo in TARGETS:
    out += [f"## {key} — {label}", ""]
    try:
        html = get(index)
    except Exception as e:
        out += [f"- `{index}` 取得できず（{type(e).__name__}: {e}）", ""]
        continue

    out += [f"### index `{index}`", "", "```"] + text_lines(html) + ["```", ""]

    ld = jsonld_prices(html)
    if ld:
        out += ["#### 構造化データ（JSON-LD）の価格", "", "```"] + ld + ["```", ""]

    if want_photo:
        out += [grab_photo(html, index, key), ""]

    links = discover(html, index, pats)
    if not links:
        out += ["- 品目ページのリンクが見つからなかった", ""]
    for L in links[:6]:
        try:
            sub = get(L)
        except Exception as e:
            out.append(f"- `{L[:110]}` 取得できず（{type(e).__name__}）")
            continue
        out += [f"### 品目 `{L[:115]}`", "", "```"] + text_lines(sub, 70) + ["```", ""]
        sld = jsonld_prices(sub)
        if sld:
            out += ["```"] + sld + ["```", ""]
    out.append("")

open(f"{RDIR}/morning-prices.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1500])
PYEOF

# 取れた写真を専用ブランチへ置く（記事側から取り出せるように）
BR="claude/morning-material2"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f morning >/dev/null 2>&1
git -C "$WT" -c user.name=openclaw -c user.email=ops@daily-hack.local \
  commit -q -m "chore: 500円モーニングの素材（051）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "$BR" 2>&1 | tail -2

git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
