#!/bin/bash
# (1) サウナの参考記事と施設写真を取り直す (2) お台場ドローンショーの素材を取る。
#
# クラウド側は全ホストで egress が塞がれているため、記事の取材も画像も Mac 経由。
#
# 031 で分かったこと。
#  - sed ベースの HTML 除去では複数行の <script> が落ちず、本文が JS に埋もれた
#  - og:image は SNS シェア用のブランド画像で、**ほとんどがロゴ／バナー**だった
#    （高輪SAUNAS だけ実写。大井町・門仲・黄金湯はロゴ、PARADISE は
#     SpaWorks サイトの汎用バナーで施設と無関係）
#
# ここでは Python で本文を抜き、公式ページ内の <img> と CSS の url() から
# **実写らしい大きい画像**を集める。採用は人が見てから決める。
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
BRANCH="claude/sauna-scrape-out"
WT="${TMPDIR:-/tmp}/dh-scr-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p tiles

"$PY" - "$RDIR" <<'PYEOF'
import io, os, re, sys, json, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(url, timeout=40):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()

def text_of(html):
    """複数行の script/style を落としてから本文だけ残す。"""
    h = html.decode("utf-8", "replace")
    h = re.sub(r"<(script|style|noscript)[^>]*>.*?</\1>", " ", h, flags=re.S | re.I)
    h = re.sub(r"<!--.*?-->", " ", h, flags=re.S)
    h = re.sub(r"<(br|/p|/div|/li|/h[1-6]|/tr)[^>]*>", "\n", h, flags=re.I)
    h = re.sub(r"<[^>]+>", " ", h)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", '"'), ("&#39;", "'")):
        h = h.replace(a, b)
    lines = [re.sub(r"[ \t　]+", " ", l).strip() for l in h.split("\n")]
    return "\n".join(l for l in lines if l)

# ---------- 参考記事 ----------
REFS = [
    "https://www.asoview.com/note/7948/",
    "https://www.timeout.jp/tokyo/ja/things-to-do/new-sauna-bathing-facilities-opening-in-2026",
    "https://onsen.nifty.com/rank/sauna/kanto/",
]
# お台場ドローンショー（新規記事の一次情報）
ODAIBA = [
    "https://odaibadrone.com/",
    "https://odaibadrone.com/ticket/",
    "https://odaibadrone.com/access/",
    "https://odaibadrone.com/faq/",
    "https://odaibadrone.com/schedule/",
]
out = ["# 参考記事の本文（Python 抽出）", ""]
for u in REFS:
    out += ["## " + u, "", "```"]
    try:
        out.append(text_of(get(u))[:9000])
    except Exception as e:
        out.append(f"取得できず: {e}")
    out += ["```", ""]
open(os.path.join(RDIR, "sauna-refs2.md"), "w", encoding="utf-8").write("\n".join(out))

# ---------- お台場ドローンショー ----------
od = ["# お台場ドローンショー 一次情報（公式サイト）", ""]
for u in ODAIBA:
    od += ["## " + u, "", "```"]
    try:
        od.append(text_of(get(u))[:9000])
    except Exception as e:
        od.append(f"取得できず: {e}")
    od += ["```", ""]
open(os.path.join(RDIR, "odaiba-drone.md"), "w", encoding="utf-8").write("\n".join(od))

# ---------- 施設の実写画像 ----------
SITES = [
    ("takanawa",  ["https://saunas-saunas.com/takanawa"]),
    ("oimachi",   ["https://ryusenjinoyu.com/saunametsaoimachi/"]),
    ("blueocean", ["http://k-scc.co.jp/sauna/", "http://k-scc.co.jp/sauna/facility/facility.html"]),
    ("monnaka",   ["https://lo.saunas-saunas.com/monnaka/"]),
    ("koganeyu",  ["https://koganeyu.com/"]),
    ("shibuya",   ["https://saunas-saunas.com/"]),
    ("odaiba",    ["https://odaibadrone.com/", "https://odaibadrone.com/about/"]),
]
BAD = re.compile(r"logo|icon|favicon|sprite|banner|ogp|og-|placeholder|noimage|footer|header", re.I)
log = ["# 施設の実写画像（ギャラリー走査）", "", "| キー | 保存名 | 大きさ | 元 URL |", "| --- | --- | --- | --- |"]

for key, pages in SITES:
    urls, seen = [], set()
    for p in pages:
        try:
            html = get(p).decode("utf-8", "replace")
        except Exception:
            continue
        cands = re.findall(r'<img[^>]+src=["\']([^"\']+)["\']', html, re.I)
        cands += re.findall(r'<img[^>]+data-src=["\']([^"\']+)["\']', html, re.I)
        cands += re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)
        for c in cands:
            u = c[1] if isinstance(c, tuple) else c
            if not re.search(r"\.(jpe?g|png|webp)(\?|$)", u, re.I):
                continue
            if BAD.search(u):
                continue
            full = urllib.parse.urljoin(p, u)
            if full in seen:
                continue
            seen.add(full)
            urls.append(full)
    n = 0
    for u in urls:
        if n >= 3:
            break
        try:
            data = get(u, timeout=30)
            im = Image.open(io.BytesIO(data)).convert("RGB")
        except Exception:
            continue
        w, h = im.size
        if w < 640 or h < 360 or w / h < 1.1:   # 横長の大きいものだけ
            continue
        n += 1
        name = f"{key}-{n}"
        im.save(f"tiles/{name}.jpg", quality=92)
        im.resize((480, max(1, int(h * 480 / w)))).save(f"tiles/thumb-{name}.jpg", quality=72)
        log.append(f"| `{key}` | `{name}.jpg` | {w}x{h} | {u[:90]} |")
    if n == 0:
        log.append(f"| `{key}` | — | — | 実写らしい画像を見つけられず |")

open(os.path.join(RDIR, "sauna-tiles2.md"), "w", encoding="utf-8").write("\n".join(log) + "\n")
print("\n".join(log[3:]))
PYEOF

git -C "$WT" add -A tiles 2>/dev/null
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "wip: 施設公式サイトの実写画像候補（レビュー用）

og:image はロゴ／バナーが多かったため、ページ内の img と CSS の url() から
横長で 640px 以上のものだけを集めた。採用は見てから決める。" \
  || { echo "画像が 1 枚も取れなかった"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }

git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" || { echo "push 失敗"; git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1; exit 1; }
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "push した: $BRANCH（tiles/ に候補、reports に sauna-refs2.md と sauna-tiles2.md）"
