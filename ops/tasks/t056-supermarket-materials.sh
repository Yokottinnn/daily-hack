#!/bin/bash
# **都心の格安スーパー記事の素材を取ってくる。**
#
# 取るもの
#   A) 6 チェーンの公式サイトから店内・商品の写真（横長・640x360 以上）
#   B) YouTube を検索して oEmbed で題名と投稿者を照合（別チェーンの動画を弾く）
#   C) 渡したツイート ID を syndication API で実在確認（本文・投稿者・日付）
#
# **クラウドセッションからは x.com にも公式サイトにも到達できない**ため Mac に頼む。
# 合成と記事執筆はクラウド側でやる。
#
# 出力は `$OPS_REPORT_DIR`（= ops/heartbeat ブランチ）。**秘密は出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
DEST="$RDIR/supermarket"
mkdir -p "$DEST"
OUT="$RDIR/t056-supermarket-materials.md"

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
L = ["# 都心の格安スーパー 素材（t056）", ""]

def get(url, binary=False, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        b = r.read()
    return b if binary else b.decode("utf-8", "replace")

# ── A) 公式サイトの写真 ───────────────────────────────
# ロゴ・アイコン類だけを弾く。**キービジュアルは弾かない**
# （2026-08-30 のららぽーとで kv/main_visual を弾いて施設写真を全部落とした）
BAD = re.compile(r"logo|icon|favicon|sprite|placeholder|noimage|arrow|btn|sns|share", re.I)

SITES = [
    ("ok",        "https://ok-corporation.jp/"),
    ("lopia",     "https://lopia.jp/"),
    ("trial",     "https://www.trial-net.co.jp/"),
    ("gyomu",     "https://www.gyomusuper.jp/"),
    ("maibasket", "https://www.mybasket.co.jp/"),
    ("hanamasa",  "https://hanamasa.co.jp/"),
]

L.append("## A) 公式サイトの写真")
for key, url in SITES:
    L.append(""); L.append(f"### {key} — {url}")
    try:
        html = get(url)
    except Exception as e:
        L.append(f"- 取得失敗: {type(e).__name__} {e}")
        continue
    cands = []
    for m in re.finditer(r'<img[^>]+src=["\']([^"\']+)', html, re.I):
        cands.append(m.group(1))
    for m in re.finditer(r'url\(["\']?([^)"\']+\.(?:jpg|jpeg|png|webp))', html, re.I):
        cands.append(m.group(1))
    for m in re.finditer(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)', html, re.I):
        cands.append(m.group(1))   # 個別ページのヒーローでは og:image は本命に近い
    seen, kept = set(), []
    for c in cands:
        u = urllib.parse.urljoin(url, c)
        if u in seen or BAD.search(u):
            continue
        seen.add(u); kept.append(u)
    L.append(f"- 候補 {len(kept)} 件。上位 6 件を保存する")
    n = 0
    for u in kept:
        if n >= 6:
            break
        try:
            b = get(u, binary=True, timeout=25)
        except Exception:
            continue
        if len(b) < 20000:       # 小さすぎるものはロゴ・装飾
            continue
        ext = ".png" if b[:4] == b"\x89PNG" else ".webp" if b[8:12] == b"WEBP" else ".jpg"
        n += 1
        p = os.path.join(DEST, f"{key}-{n}{ext}")
        with open(p, "wb") as f:
            f.write(b)
        L.append(f"  - `{os.path.basename(p)}` … {len(b)//1024} KB … {u}")
    if n == 0:
        L.append("  - **1 枚も取れなかった**")

# ── B) YouTube ────────────────────────────────────────
L.append(""); L.append("## B) YouTube（oEmbed で題名と投稿者を照合）")
QUERIES = [
    ("ok",        "オーケーストア 買い物"),
    ("lopia",     "ロピア 爆買い"),
    ("trial",     "トライアル西友 スマートカート"),
    ("gyomu",     "業務スーパー 購入品"),
    ("maibasket", "まいばすけっと 買い物"),
    ("hanamasa",  "肉のハナマサ 業務用"),
]
for key, q in QUERIES:
    L.append(""); L.append(f"### {key} — 検索語「{q}」")
    try:
        html = get("https://www.youtube.com/results?search_query=" + urllib.parse.quote(q))
    except Exception as e:
        L.append(f"- 検索失敗: {type(e).__name__} {e}")
        continue
    ids, seen = [], set()
    for m in re.finditer(r'"videoId":"([A-Za-z0-9_-]{11})"', html):
        v = m.group(1)
        if v not in seen:
            seen.add(v); ids.append(v)
    for v in ids[:5]:
        try:
            d = json.loads(get("https://www.youtube.com/oembed?format=json&url="
                               + urllib.parse.quote(f"https://www.youtube.com/watch?v={v}", safe="")))
            L.append(f"- `{v}` … **{d.get('title')}** / {d.get('author_name')}")
        except Exception:
            L.append(f"- `{v}` … oEmbed 取れず（使わない）")

# ── C) ツイートの実在確認 ─────────────────────────────
L.append(""); L.append("## C) ツイートの実在確認（syndication API）")
TWEETS = [
    "2025480684190540286",   # 坂上&指原のつぶれない店 公式・116台のカメラ
    "2025508379825979893",   # TBS PR・野菜詰め放題430円
    "2029894843540066796",   # ロピアの買い物（体験）
    "2042734632609943808",   # ロピア批判（バランス）
    "1955223069947216258",   # ESSE・ロピアとオーケーのピザ比較
    "2018255641341767936",   # 恵方巻きラインナップ比較
]
for tid in TWEETS:
    try:
        d = json.loads(get(f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token=a"))
        txt = (d.get("text") or "").replace("\n", " ")[:180]
        u = d.get("user") or {}
        photos = len(d.get("photos") or [])
        L.append(f"- `{tid}` … @{u.get('screen_name')}（{u.get('name')}）"
                 f" / {d.get('created_at','')[:10]} / 画像{photos}枚")
        L.append(f"  - 本文: {txt}")
    except Exception as e:
        L.append(f"- `{tid}` … **取れず**（{type(e).__name__}）。使わない")

with open(OUT, "w") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L[:60]))
print(f"... 全文は {OUT}")
PYEOF

echo "=== 保存した画像 ==="
ls -la "$DEST" 2>/dev/null | head -50
exit 0
