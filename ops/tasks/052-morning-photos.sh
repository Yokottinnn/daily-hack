#!/bin/bash
# 051 の続き。**記事に貼れる料理の写真**と、まだ埋まっていない値段を取る。
#
# 049/051 で取れた写真 8 枚のうち、目で見て使えたのは 3 枚だけだった。
#   使える : コメダ（トースト＋珈琲）／すき家（まぜのっけ朝食）／上島珈琲店（モーニングセット）
#   使えない: マクドナルド（ポケモンのコラボ意匠）／サンマルク（別業態のコース料理）
#            吉野家（朝定食ではない別商品）／モス（コーヒーチケットの販促バナー）
#            サンマルク2（「あさマルクカフェ」の販促バナー。料理写真ではない）
#
# **一覧ページの先頭画像はバナーであることが多い。品目ページから取る。**
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-morning3-$$"
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

JP = re.compile(r"[ぁ-んァ-ヶ一-龠]")
def text_lines(html, limit=90):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&quot;", '"'), ("&#039;", "'"), ("&yen;", "¥")):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or len(l) > 130 or l in seen: continue
        if not (JP.search(l) or re.search(r"\d", l)): continue
        seen.add(l); out.append(l)
    return out[:limit]

# バナー・ロゴ・販促画像を弾く。ファイル名に「キャンペーン」系が入るものも落とす。
BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner|bnr"
                 r"|campaign|ticket|coupon|news|kv|main_?visual|top_?img", re.I)

def photos(html, base, key, want=2, seen=set()):
    got, lines = 0, []
    cs = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
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
        # 料理写真は横長すぎない。極端な帯はバナー。
        if w < 500 or h < 300 or not (0.9 <= w / h <= 2.0): continue
        got += 1
        name = f"{key}-{got}"
        im.save(f"morning/{name}.jpg", quality=92)
        im.resize((480, max(1, int(h * 480 / w)))).save(f"morning/thumb-{name}.jpg", quality=72)
        lines.append(f"- 写真 `morning/{name}.jpg` {w}x{h} ← {full[:110]}")
    return lines or ["- **写真が取れなかった。**"]

# key, 表示名, 起点, たどるリンクの目印
TARGETS = [
    ("matsuya",  "松屋 モーニング",       "https://www.matsuyafoods.co.jp/matsuya/menu/morning/", ["/menu/morning/"]),
    ("nakau",    "なか卯 朝食",           "https://www.nakau.co.jp/jp/menu/category/6.html",      ["/menu/detail/"]),
    ("yoshinoya","吉野家 朝食メニュー",   "https://www.yoshinoya.com/menu/morningset/",           ["/menu/morningset/"]),
    ("doutor",   "ドトール モーニング",   "https://www.doutor.co.jp/dcs/menu/list/morning.html",  ["/dcs/menu/"]),
    ("mos",      "モスバーガー 朝モス",   "https://www.mos.jp/menu/category/?c_id=12",            ["/menu/", "c_id=12"]),
    ("ueshima",  "上島珈琲店 モーニング", "https://www.ueshima-coffee-ten.jp/menu/morning/",      ["/menu/"]),
]

out = ["# 500円モーニング：料理写真と、残りの値段（052）", "",
       "**一覧ページの先頭画像はバナーであることが多い。品目ページから取っている。**",
       "取れた写真は必ず目で見てから使うこと。**バナー・販促画像は記事に貼らない。**", ""]

for key, label, index, pats in TARGETS:
    out += [f"## {key} — {label}", ""]
    try:
        html = get(index)
    except Exception as e:
        out += [f"- `{index}` 取得できず（{type(e).__name__}: {e}）", ""]
        continue
    out += [f"### index `{index}`", ""] + photos(html, index, f"{key}-idx", want=1) + [""]

    links, seen = [], set()
    for m in re.finditer(r'href=["\']([^"\']+)["\']', html, re.I):
        h = urllib.parse.urljoin(index, m.group(1))
        if "#" in h: h = h.split("#")[0]
        if h == index or h in seen: continue
        if not any(p in h for p in pats): continue
        seen.add(h); links.append(h)
        if len(links) >= 8: break

    if not links:
        out += ["- 品目ページのリンクが見つからなかった", ""]
    for L in links:
        try:
            sub = get(L)
        except Exception as e:
            out.append(f"- `{L[:110]}` 取得できず（{type(e).__name__}）")
            continue
        slug = re.sub(r"[^a-z0-9]+", "-", L.rsplit("/", 1)[-1].lower())[:24] or "item"
        out += [f"### 品目 `{L[:115]}`", "", "```"] + text_lines(sub, 40) + ["```", ""]
        out += photos(sub, L, f"{key}-{slug}", want=1) + [""]
    out.append("")

open(f"{RDIR}/morning-photos.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1200])
PYEOF

BR="claude/morning-material3"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f morning >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: 500円モーニングの料理写真（052）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/morning-photos.md / branch $BR"
