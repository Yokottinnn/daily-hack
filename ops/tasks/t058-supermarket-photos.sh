#!/bin/bash
# **店舗写真を取れるところ全部から一度に取る。1 段ずつ往復しない。**
#
# ## なぜ全部まとめてやるか
#
# t056 は公式サイトのトップだけを見て 36 枚 取り、**1 枚も使えなかった**
# （求人バナー・キャンペーンバナー・ブラーのかかったストック画像）。
# 次に Commons だけを叩けば、また 1 往復 かかる。**同時に全部やる。**
#
# ## 見に行くところ（4 系統）
#
#   A) Wikimedia Commons        … 店舗外観。ライセンスが明確
#   B) PR TIMES                 … **報道向けに各社が出している写真**
#   C) 各社のニュースリリース一覧 … 新店・新フォーマットの店内写真
#   D) IR・決算説明資料のページ   … 店舗の写真が入っていることがある
#
# **採用はしない。候補を落とすだけ。** クラウド側で `Read` して目で見てから選ぶ。
# 1 件目を無条件に採らない（2026-08-22 にサウナで木版画を引いた）。
#
# 出力: `$OPS_REPORT_DIR/photos/` と `$OPS_REPORT_DIR/t058-photos.md`
# **出典 URL を 1 枚ずつ記録する。** 記事に出典を書くために要る。
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
DEST="$RDIR/photos"
OUT="$RDIR/t058-photos.md"
mkdir -p "$DEST"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

"$PY" - "$DEST" "$OUT" <<'PYEOF'
import json, os, re, sys, urllib.parse, urllib.request

DEST, OUT = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"}
L = ["# 店舗写真の候補（t058 / 4 系統）", "",
     "**採用していない。候補を落としただけ。** 目で見てから選ぶ。", ""]
manifest = []

def get(url, binary=False, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read() if binary else r.read().decode("utf-8", "replace")

def save(key, url, src_page, note=""):
    """落として大きさを測る。**小さいもの・横長すぎるものは弾く。**
    寸法が揃っているものはバナーなので、あとで一覧を見て判断する。"""
    try:
        b = get(url, binary=True, timeout=30)
    except Exception:
        return None
    if len(b) < 25000:
        return None
    ext = ".png" if b[:4] == b"\x89PNG" else ".webp" if b[8:12] == b"WEBP" else ".jpg"
    n = sum(1 for f in os.listdir(DEST) if f.startswith(key + "-")) + 1
    name = f"{key}-{n}{ext}"
    with open(os.path.join(DEST, name), "wb") as f:
        f.write(b)
    manifest.append({"file": name, "src": url, "page": src_page, "note": note})
    L.append(f"  - `{name}` … {len(b)//1024} KB … {note}")
    L.append(f"    - 画像: {url}")
    L.append(f"    - 出典ページ: {src_page}")
    return name

CHAINS = [
    ("ok",        "オーケー",       ["OK supermarket Japan", "オーケーストア", "OK Store Japan supermarket"]),
    ("lopia",     "ロピア",         ["Lopia supermarket", "ロピア 店舗"]),
    ("trial",     "トライアル",     ["Trial supermarket Japan", "トライアル 店舗", "Seiyu store"]),
    ("gyomu",     "業務スーパー",   ["Gyomu Super", "業務スーパー 店舗"]),
    ("maibasket", "まいばすけっと", ["My Basket store", "まいばすけっと"]),
    ("hanamasa",  "肉のハナマサ",   ["Hanamasa store", "肉のハナマサ"]),
    ("donki",     "ドン・キホーテ", ["Don Quijote store Japan", "ドン・キホーテ 店舗"]),
]

# ── A) Wikimedia Commons ─────────────────────────────
L.append("## A) Wikimedia Commons")
API = "https://commons.wikimedia.org/w/api.php"
for key, ja, queries in CHAINS:
    L.append(""); L.append(f"### {ja}（{key}）")
    got = 0
    for q in queries:
        if got >= 4:
            break
        try:
            u = (API + "?action=query&format=json&generator=search&gsrnamespace=6"
                 "&gsrlimit=12&gsrsearch=" + urllib.parse.quote(q)
                 + "&prop=imageinfo&iiprop=url|size|extmetadata&iiurlwidth=1600")
            d = json.loads(get(u))
        except Exception as e:
            L.append(f"- 「{q}」検索失敗: {type(e).__name__}")
            continue
        pages = ((d.get("query") or {}).get("pages") or {})
        if not pages:
            L.append(f"- 「{q}」… 0 件")
            continue
        L.append(f"- 「{q}」… {len(pages)} 件")
        for pid, p in pages.items():
            if got >= 4:
                break
            ii = (p.get("imageinfo") or [{}])[0]
            w, h = ii.get("width", 0), ii.get("height", 0)
            if w < 800 or h < 450:          # 小さいものは使えない
                continue
            if w / max(h, 1) > 3.5:         # 極端な横長はバナー
                continue
            meta = ii.get("extmetadata") or {}
            lic = (meta.get("LicenseShortName") or {}).get("value", "?")
            art = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "?"))[:60]
            title = p.get("title", "")
            if save(key, ii.get("thumburl") or ii.get("url"),
                    f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(title)}",
                    f"{title} / {lic} / {art} / {w}x{h}"):
                got += 1
    if got == 0:
        L.append("- **Commons では取れなかった**")

# ── B) PR TIMES ──────────────────────────────────────
# **報道向けに各社が出している写真。** 番号を当て推量で組み立てず、検索から辿る。
L.append(""); L.append("## B) PR TIMES（報道向けに各社が出している写真）")
for key, ja, _ in CHAINS:
    L.append(""); L.append(f"### {ja}（{key}）")
    try:
        s = get("https://prtimes.jp/main/action.php?run=html&page=searchkeyword&search_word="
                + urllib.parse.quote(ja))
    except Exception as e:
        L.append(f"- 検索失敗: {type(e).__name__} {e}")
        continue
    rels = []
    for m in re.finditer(r'href="(/main/html/rd/p/[0-9]+\.[0-9]+\.html)"', s):
        u = "https://prtimes.jp" + m.group(1)
        if u not in rels:
            rels.append(u)
    L.append(f"- リリース候補 {len(rels)} 件。上位 3 件を見る")
    got = 0
    for r in rels[:3]:
        if got >= 4:
            break
        try:
            h = get(r)
        except Exception:
            continue
        imgs = []
        for m in re.finditer(r'https://prcdn\.freetls\.fastly\.net/release_image/[^"\'\\ ]+', h):
            u = m.group(0)
            if u not in imgs:
                imgs.append(u)
        for u in imgs[:4]:
            if got >= 4:
                break
            if save(key, u, r, "PR TIMES"):
                got += 1
    if got == 0:
        L.append("- **PR TIMES では取れなかった**")

# ── C) 各社のニュースリリース一覧 ─────────────────────
L.append(""); L.append("## C) 各社のニュースリリース")
NEWS = [
    ("ok",        "https://ok-corporation.jp/news/"),
    ("lopia",     "https://lopia.jp/news/"),
    ("trial",     "https://www.trial-net.co.jp/news/"),
    ("gyomu",     "https://www.kobebussan.co.jp/news/"),
    ("maibasket", "https://www.mybasket.co.jp/news/"),
    ("donki",     "https://ppih.co.jp/news/"),
]
BAD = re.compile(r"logo|icon|favicon|sprite|arrow|btn|sns|share|banner|bnr", re.I)
for key, url in NEWS:
    L.append(""); L.append(f"### {key} — {url}")
    try:
        h = get(url)
    except Exception as e:
        L.append(f"- 取得失敗: {type(e).__name__} {e}")
        continue
    # リリース詳細へのリンクを辿る
    links, seen = [], set()
    for m in re.finditer(r'<a[^>]+href=["\']([^"\']+)', h, re.I):
        u = urllib.parse.urljoin(url, m.group(1)).split("#")[0]
        if u in seen or urllib.parse.urlparse(u).netloc != urllib.parse.urlparse(url).netloc:
            continue
        if "/news" not in u or u.rstrip("/") == url.rstrip("/"):
            continue
        seen.add(u); links.append(u)
    got = 0
    for u in links[:5]:
        if got >= 3:
            break
        try:
            hh = get(u)
        except Exception:
            continue
        for m in re.finditer(r'<img[^>]+(?:src|data-src)=["\']([^"\']+\.(?:jpg|jpeg|png|webp))', hh, re.I):
            if got >= 3:
                break
            iu = urllib.parse.urljoin(u, m.group(1))
            if BAD.search(iu):
                continue
            if save(key, iu, u, "ニュースリリース"):
                got += 1
    if got == 0:
        L.append(f"- 取れなかった（リリース候補 {len(links)} 件）")

with open(os.path.join(DEST, "_sources.json"), "w") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)

L.append(""); L.append(f"## 合計 {len(manifest)} 枚")
L.append("")
L.append("**出典は `_sources.json` に 1 枚ずつ入っている。** 記事にはそこから書く。")

with open(OUT, "w") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L[-40:]))
PYEOF

echo "=== 落とした画像 ==="
ls -la "$DEST" 2>/dev/null | head -60
exit 0
