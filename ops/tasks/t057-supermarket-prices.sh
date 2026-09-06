#!/bin/bash
# **価格の材料と、業務スーパーの写真を取り直す。**
#
# ## t056 で何が起きたか
#
# **D) 価格は 8 ページ中 5 ページが 404 / 403 で全滅した。**
# `https://ok-corporation.jp/products/` のような URL を**当て推量で組み立てた**のが原因。
# CLAUDE.md が禁じている踏み方をこちらがやった。
#
# **業務スーパーの写真も 0 枚**だった（トップページの img から候補が 1 件も出ない）。
#
# ## 今回の直し方
#
# **URL を書かない。トップページから「リンクを辿って」見つける。**
#
#   トップページを取る → a[href] を全部見る
#     → チラシ / 特売 / 商品 / product / chirashi / bargain / online を含むものを拾う
#     → そのページを取って、価格らしき記述と画像を拾う
#
# 検索で実在を確認できた URL だけは直接指定する（業務スーパー）。
#
# 出力は `$OPS_REPORT_DIR`。**秘密は出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
DEST="$RDIR/supermarket"
mkdir -p "$DEST"
OUT="$RDIR/t057-supermarket-prices.md"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

"$PY" - "$DEST" "$OUT" <<'PYEOF'
import os, re, sys, urllib.parse, urllib.request

DEST, OUT = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"}
L = ["# 価格の材料と業務スーパーの写真（t057）", ""]

def get(url, binary=False, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read() if binary else r.read().decode("utf-8", "replace")

def strip_tags(html):
    t = re.sub(r"<script.*?</script>|<style.*?</style>", " ", html, flags=re.S | re.I)
    t = re.sub(r"<[^>]+>", " ", t)
    return re.sub(r"\s+", " ", t)

YEN = re.compile(r"(?:￥|¥)\s?([0-9,]{2,7})|([0-9,]{2,7})\s?円")

def dump_prices(label, url, limit=30):
    L.append(""); L.append(f"#### {label} — {url}")
    try:
        html = get(url)
    except Exception as e:
        L.append(f"- 取得失敗: {type(e).__name__} {e}")
        return
    text = strip_tags(html)
    hits = []
    for m in YEN.finditer(text):
        val = m.group(1) or m.group(2)
        s0, e0 = max(0, m.start() - 70), min(len(text), m.end() + 15)
        hits.append(f"{val}円 … {text[s0:e0].strip()}")
    if hits:
        L.append(f"- 価格らしき記載 {len(hits)} 件。先頭 {min(limit,len(hits))} 件:")
        for h in hits[:limit]:
            L.append(f"  - {h}")
    else:
        L.append("- 価格の記載は拾えなかった")

# ── 1) 検索で実在を確認できた URL（業務スーパー）────────────
L.append("## 1) 業務スーパー（URL を検索で確認済み）")
for label, u in [
    ("商品紹介",       "https://www.gyomusuper.jp/product/index.php"),
    ("全商品一覧",     "https://www.gyomusuper.jp/product/search.php"),
    ("特売情報",       "https://www.gyomusuper.jp/saiyasune.php"),
    ("オンライン全商品", "https://www.gyomusuper.jp/onlineshop/products/list"),
]:
    dump_prices(label, u)

# ── 2) トップページからリンクを辿って探す ────────────────
# **URL を当て推量で組み立てない。** これが t056 の失敗の原因だった。
L.append(""); L.append("## 2) トップページからリンクを辿って見つけたページ")
WANT = re.compile(r"chirashi|bargain|tokubai|sale|product|item|goods|online|shop|"
                  r"チラシ|特売|商品|価格|セール", re.I)
SKIP = re.compile(r"recruit|company|ir/|privacy|contact|news/|faq|store|shop/list|"
                  r"\.pdf$|\.jpg$|\.png$|facebook|twitter|x\.com|instagram|youtube", re.I)
TOPS = [
    ("ok",        "https://ok-corporation.jp/"),
    ("lopia",     "https://lopia.jp/"),
    ("trial",     "https://www.trial-net.co.jp/"),
    ("maibasket", "https://www.mybasket.co.jp/"),
    ("hanamasa",  "https://hanamasa.co.jp/"),
    ("donki",     "https://www.donki.com/"),
]
for key, top in TOPS:
    L.append(""); L.append(f"### {key} — {top}")
    try:
        html = get(top)
    except Exception as e:
        L.append(f"- トップページが取れない: {type(e).__name__} {e}")
        continue
    seen, links = set(), []
    for m in re.finditer(r'<a[^>]+href=["\']([^"\']+)', html, re.I):
        u = urllib.parse.urljoin(top, m.group(1)).split("#")[0]
        if u in seen or not u.startswith("http"):
            continue
        if urllib.parse.urlparse(u).netloc != urllib.parse.urlparse(top).netloc:
            continue
        if SKIP.search(u) or not WANT.search(u):
            continue
        seen.add(u); links.append(u)
    L.append(f"- 候補リンク {len(links)} 件。上位 4 件を見る")
    for u in links[:4]:
        dump_prices("→", u, limit=15)

# ── 3) 業務スーパーの写真を取り直す ──────────────────────
# t056 はトップページの img から候補 0 件だった。商品ページから拾う。
L.append(""); L.append("## 3) 業務スーパーの写真（取り直し）")
BAD = re.compile(r"logo|icon|favicon|sprite|placeholder|noimage|arrow|btn|sns|share", re.I)
n = 0
for src in ("https://www.gyomusuper.jp/product/index.php",
            "https://www.gyomusuper.jp/",
            "https://www.gyomusuper.jp/saiyasune.php"):
    if n >= 6:
        break
    try:
        html = get(src)
    except Exception as e:
        L.append(f"- {src} … 取得失敗 {type(e).__name__}")
        continue
    cands = []
    for m in re.finditer(r'<img[^>]+(?:src|data-src)=["\']([^"\']+)', html, re.I):
        cands.append(m.group(1))
    for m in re.finditer(r'url\(["\']?([^)"\']+\.(?:jpg|jpeg|png|webp))', html, re.I):
        cands.append(m.group(1))
    for m in re.finditer(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)', html, re.I):
        cands.append(m.group(1))
    for c in cands:
        if n >= 6:
            break
        u = urllib.parse.urljoin(src, c)
        if BAD.search(u):
            continue
        try:
            b = get(u, binary=True, timeout=25)
        except Exception:
            continue
        if len(b) < 15000:
            continue
        ext = ".png" if b[:4] == b"\x89PNG" else ".webp" if b[8:12] == b"WEBP" else ".jpg"
        n += 1
        p = os.path.join(DEST, f"gyomu-{n}{ext}")
        with open(p, "wb") as f:
            f.write(b)
        L.append(f"- `{os.path.basename(p)}` … {len(b)//1024} KB … {u}")
if n == 0:
    L.append("- **やはり 1 枚も取れなかった。** 業務スーパーの写真は別の手段が要る")

with open(OUT, "w") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L[:80]))
print(f"... 全文は {OUT}")
PYEOF
exit 0
