#!/bin/bash
# 066 の残り。**サンマルクカフェ・モスバーガー・なか卯の3チェーンだけ写真が取れていない。**
#
#   サンマルクカフェ … お知らせページからは 1 枚も取れなかった。
#                     メニュー一覧から入るとミニオンのコラボ意匠を掴む（065）
#   モスバーガー     … 2 回とも**コーヒーチケットの販促バナー**しか取れていない
#   なか卯           … 公式 CDN が `Small.png` も `Big.png` も
#                     **真っ黒に赤い四角のプレースホルダ**を返す
#
# 3 つとも「一覧ページの img を舐める」やり方では届かない。**入り口を変える。**
#
#   1) **JSON-LD と og:image を見る。** 商品ページは Product 構造化データを
#      持っていることが多く、`image` に本物の URL が入っている
#   2) **リンクを深さ 2 まで追う。** 一覧 → カテゴリ → 品目、と 2 段になっている
#   3) **なか卯は商品ページの HTML を直接見る。** 一覧の CDN 画像は当てにしない
#   4) 拾えた候補は**弾かずに全部出す**。バナーかどうかは人が見て決める
#      （弾きすぎて本命を捨てたのが 062 の失敗）
#
# **これで取れなければ、その3チェーンは写真なしで確定させる。**
# 素材が無いことを記事に書くのは、無関係な画像を貼るより良い。
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-morning6-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p m6

"$PY" - "$RDIR" <<'PYEOF'
import io, json, re, sys, time, urllib.parse, urllib.request
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


def title_of(html):
    for pat in (r'<h1[^>]*>(.*?)</h1>', r'<title[^>]*>(.*?)</title>'):
        m = re.search(pat, html, re.I | re.S)
        if m:
            t = re.sub(r"<[^>]+>", "", m.group(1))
            t = re.sub(r"\s+", " ", t).strip()
            if t:
                return t[:70]
    return "(品名なし)"


def urls_in(html, base):
    """**弾かない。** JSON-LD → og:image → img/srcset → CSS の url() の順に集める。"""
    out = []
    for m in re.finditer(r'<script[^>]+application/ld\+json[^>]*>(.*?)</script>', html, re.I | re.S):
        try:
            data = json.loads(m.group(1))
        except Exception:
            continue
        stack = [data]
        while stack:
            v = stack.pop()
            if isinstance(v, dict):
                img = v.get("image")
                if isinstance(img, str):
                    out.append(("json-ld", img))
                elif isinstance(img, list):
                    out += [("json-ld", x) for x in img if isinstance(x, str)]
                elif isinstance(img, dict) and isinstance(img.get("url"), str):
                    out.append(("json-ld", img["url"]))
                stack += list(v.values())
            elif isinstance(v, list):
                stack += v
    m = re.search(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)', html, re.I)
    if m:
        out.append(("og:image", m.group(1)))
    for c in re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I):
        out.append(("img", c))
    for c in re.findall(r'srcset=["\']([^"\']+)["\']', html, re.I):
        out.append(("srcset", c.split(",")[-1].strip().split(" ")[0]))
    for _, c in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html):
        out.append(("css", c))
    return [(o, urllib.parse.urljoin(base, u)) for o, u in out]


def grab(cands, key, start_n, seen, out, src_title):
    n = start_n
    for origin, full in cands:
        if n >= start_n + 6:
            break
        if not re.search(r"\.(jpe?g|png|webp)(\?|$)", full, re.I):
            continue
        if full in seen:
            continue
        seen.add(full)
        try:
            im = Image.open(io.BytesIO(getb(full))).convert("RGB")
        except Exception:
            continue
        if im.width < 380 or im.height < 240:
            continue
        # **真っ黒・真っ白はプレースホルダ。** なか卯がこれだった。
        px = im.resize((16, 16)).getdata()
        avg = sum(sum(p) for p in px) / (16 * 16 * 3)
        if avg < 26 or avg > 249:
            out.append(f"    - （プレースホルダとして除外 avg={avg:.0f}） {full[:100]}")
            continue
        n += 1
        im.save(f"m6/{key}-{n}.jpg", quality=92)
        im.resize((480, max(1, int(im.height * 480 / im.width)))).save(
            f"m6/thumb-{key}-{n}.jpg", quality=74)
        big = "**大**" if im.width >= 900 else "小"
        out.append(f"    - `m6/{key}-{n}.jpg` {im.width}x{im.height} {big}（{origin}）"
                   f" ／ {src_title}")
        out.append(f"      {full[:110]}")
    return n


# key, 表示名, 起点をいくつか, たどるリンクの目印（深さ2まで）
CHAINS = [
    ("stmarc", "① サンマルクカフェ",
     ["https://www.saint-marc-hd.com/saintmarccafe/menu/saintmarccafe/",
      "https://www.saint-marc-hd.com/saintmarccafe/news/1318/"],
     ["morning", "asamaruku", "/menu/saintmarccafe/"]),
    ("mos", "③ モスバーガー",
     ["https://www.mos.jp/menu/category/?c_id=12"],
     ["/menu/detail/", "c_id=12", "/menu/"]),
    ("nakau", "⑤ なか卯",
     ["https://www.nakau.co.jp/jp/menu/category/6.html"],
     ["/menu/detail/in/", "/menu/detail/"]),
]

out = ["# モーニング記事：残り3チェーンの写真（067）", "",
       "**066 でも サンマルクカフェ・モスバーガー・なか卯 の3つは取れなかった。**", "",
       "- サンマルク … お知らせページからは0枚。一覧から入るとミニオンのコラボ意匠",
       "- モス … 2回とも**コーヒーチケットの販促バナー**",
       "- なか卯 … 公式CDNが `Small.png` も `Big.png` も**真っ黒のプレースホルダ**を返す", "",
       "今回は **JSON-LD と og:image を見て、リンクを深さ2まで追う。**",
       "**候補は弾かずに全部出す**（弾きすぎて本命を捨てたのが 062 の失敗）。", "",
       "**これで取れなければ、その3チェーンは写真なしで確定させる。**",
       "素材が無いことを記事に書くほうが、無関係な画像を貼るよりよい。", ""]

for key, label, starts, pats in CHAINS:
    out += [f"## {key} — {label}", ""]
    seen, n = set(), 0
    pages = []
    for st in starts:
        try:
            h = get(st)
        except Exception as e:
            out.append(f"  - 起点 `{st}` 取得できず（{type(e).__name__}）")
            continue
        pages.append((st, h))
        out.append(f"  起点 `{st}`")
        n = grab(urls_in(h, st), key, n, seen, out, title_of(h))
        time.sleep(1)

    # 深さ2: 起点 → 子 → 孫
    level = [(u, h) for u, h in pages]
    for depth in (1, 2):
        nxt, cnt = [], 0
        for base, h in level:
            for m in re.finditer(r'href=["\']([^"\']+)["\']', h, re.I):
                if cnt >= 6:
                    break
                lk = urllib.parse.urljoin(base, m.group(1)).split("#")[0]
                if lk in seen or not any(p in lk for p in pats):
                    continue
                seen.add(lk)
                try:
                    sh = get(lk)
                except Exception:
                    continue
                cnt += 1
                nxt.append((lk, sh))
                n = grab(urls_in(sh, lk), key, n, seen, out, title_of(sh))
                time.sleep(1)
        level = nxt
        if not level:
            break

    if n == 0:
        out.append("  - **1枚も取れなかった。写真なしで確定させること。**")
    out.append("")

open(f"{RDIR}/morning-last3.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1800])
PYEOF

BR="claude/morning-last3"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f m6 >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: 残り3チェーンの朝メニュー写真（067）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/morning-last3.md / branch $BR"
