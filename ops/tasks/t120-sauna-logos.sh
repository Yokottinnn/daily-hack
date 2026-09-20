#!/bin/bash
# **サウナ記事の施設ロゴを取る（15 施設・t120）。**
#
# 最上位ルール 17（2026-09-20）:
#   「記事には基本的にすべてロゴを入れて作るように」
#
# **当たる順は 百科事典 → 公式のメディア/広報 → og:image。**
# `t111`/`065` は og:image から始めていて取りこぼした。**同じ作りにしない。**
#
# **商標であり自由ライセンスではない。** 識別目的の利用を前提に、
# 取得元とライセンス表記を必ず残す。ライセンス表記はレポートにそのまま出すので、
# **自由ライセンスでないものはそうと分かる**状態で採否を決められる。
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t120-sauna-logos.md"
DIR="$RDIR/sauna-logos"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF_INNER'
import datetime as dt, html, io, json, re, sys, time, urllib.error, urllib.parse, urllib.request
from PIL import Image

OUT, DIR = sys.argv[1], sys.argv[2]
BUDGET = 250.0
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)",
      "Accept-Language": "ja,en;q=0.8"}

def getb(u, t=20):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

def gets(u, t=20):
    return getb(u, t).decode("utf-8", "replace")

L = ["# サウナ記事の施設ロゴ候補（t120）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**当たる順は 百科事典 → 公式のメディア/広報 → og:image。**",
     "**og:image から始めない**（看板写真やバナーであることが多い）。",
     "**商標であり自由ライセンスではない。** 取得元とライセンス表記を必ず残す。", ""]
man = {"_note": "識別目的で使うロゴ。**商標であり自由ライセンスではない。**改変せず、"
                "余白のみ切って置くこと。取得日 " + dt.date.today().isoformat() + "（" + "ops/tasks/t120-sauna-logos.sh" + "）。"}
t0 = time.time()

def save(blob, name, src, page, lic, brand, key):
    try:
        im = Image.open(io.BytesIO(blob)); im.load()
    except Exception as e:
        L.append(f"  - ✗ 画像として開けない（{type(e).__name__}） ← `{src[:80]}`"); return False
    w, h = im.size
    if w < 100 or h < 16:
        L.append(f"  - ✗ {w}x{h}（小さすぎる） ← `{src[:80]}`"); return False
    if h and w / h > 14:
        L.append(f"  - ✗ {w}x{h}（細長すぎる） ← `{src[:80]}`"); return False
    im.convert("RGBA").save(f"{DIR}/{name}.png", "PNG", optimize=True)
    L.append(f"  - ✅ `{name}.png` / {w}x{h} / **{lic}**")
    L.append(f"        ← `{src[:105]}`")
    man.setdefault(key, []).append({"brand": brand, "file": f"{name}.png", "source": src,
                                    "page": page, "license_note": lic,
                                    "width": w, "height": h})
    return True

def from_wiki(key, brand, titles):
    """**百科事典を先に見る。** ライセンス表記が一緒に取れるのが利点。"""
    got = 0
    for site, title in titles:
        if time.time() - t0 > BUDGET or got >= 1:
            break
        q = urllib.parse.urlencode({"action": "query", "format": "json", "titles": title,
                                    "prop": "imageinfo", "iiprop": "url|size|extmetadata"})
        try:
            d = json.loads(gets(f"https://{site}/w/api.php?{q}"))
        except Exception:
            continue
        for _, pg in ((d.get("query") or {}).get("pages") or {}).items():
            ii = (pg.get("imageinfo") or [None])[0]
            if not ii:
                continue
            em = ii.get("extmetadata") or {}
            lic = (em.get("LicenseShortName") or {}).get("value") or "表記なし"
            try:
                if save(getb(ii["url"]), f"{key}-wiki", ii["url"],
                        f"https://{site}/wiki/" + urllib.parse.quote(title.replace(" ", "_")),
                        lic, brand, key):
                    got += 1
            except Exception as e:
                L.append(f"  - ✗ 取得できない（{type(e).__name__}）")
    return got

def from_site(key, brand, url):
    """公式サイト。**メディア/広報ページを先に探し、無ければ og:image 等。**"""
    try:
        page = gets(url)
    except Exception as e:
        L.append(f"  - ✗ 起点が読めない（{type(e).__name__}）"); return 0
    # 広報・メディアキットらしいリンクを 1 本だけ辿る
    for m in re.finditer(r'<a\s[^>]*href="([^"]+)"[^>]*>(.*?)</a>', page, re.S | re.I):
        txt = re.sub(r"<[^>]+>", "", html.unescape(m.group(2)))
        if not re.search(r"media ?kit|press ?kit|brand|logo|広報|ロゴ|プレス", txt, re.I):
            continue
        u = urllib.parse.urljoin(url, html.unescape(m.group(1)))
        if urllib.parse.urlparse(u).netloc != urllib.parse.urlparse(url).netloc:
            continue
        try:
            page = page + gets(u)
            L.append(f"  - 広報ページも読んだ: `{u[:90]}`")
        except Exception:
            pass
        break
    cands = []
    for pat in (r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"',
                r'<link[^>]+rel="apple-touch-icon[^"]*"[^>]+href="([^"]+)"'):
        for m in re.finditer(pat, page, re.I):
            cands.append(urllib.parse.urljoin(url, html.unescape(m.group(1))))
    for m in re.finditer(r'<img[^>]+>', page, re.I):
        tag = m.group(0)
        if not re.search(r"logo", tag, re.I):
            continue
        sm = re.search(r'\s(?:data-)?src="([^"]+)"', tag)
        if sm:
            cands.append(urllib.parse.urljoin(url, html.unescape(sm.group(1))))
    seen, got = set(), 0
    for cu in cands:
        if got >= 1 or time.time() - t0 > BUDGET: break
        if cu in seen: continue
        seen.add(cu)
        try:
            if save(getb(cu), f"{key}-site", cu, url, "公式サイト（商標）", brand, key):
                got += 1
        except Exception as e:
            L.append(f"  - ✗ `{cu[:80]}`: {type(e).__name__}")
    return got

BRANDS = [
    ("myspa", "スパ＆ホテル 舞浜ユーラシア", "https://www.my-spa.jp/spa/", []),
    ("saunas_takanawa", "高輪SAUNAS", "https://saunas-saunas.com/takanawa", []),
    ("saunas_monnaka", "門仲SAUNAS LO", "https://lo.saunas-saunas.com/monnaka/", []),
    ("metsa_oimachi", "サウナメッツァ 大井町トラックス", "https://ryusenjinoyu.com/saunametsaoimachi/", []),
    ("spaworks", "竜泉寺の湯・スパメッツァ", "https://spaworks.jp/", []),
    ("kiki", "SAUNA汽汽", "https://sauna-kiki.jp/", []),
    ("mainichi", "毎日サウナ東京", "https://www.supersento.com/", []),
    ("kohaku", "sauna KOHAKU", "https://sauna-kohaku.com/", []),
    ("paradise", "パラダイス大手町", "https://paradise-otemachi.com/", []),
    ("shiagaru", "SHIAGARU SAUNA", "https://shiagaru-sauna.com/", []),
    ("suien", "水宴 -suien-", "https://furosauna.com/", []),
    ("spaeas", "横浜天然温泉 SPA EAS", "https://spa-eas.com/", []),
    ("logout", "荒木町サウナ Logout", "https://sauna-logout.com/", []),
    ("jyoshin", "サウナ蒸薪", "https://www.sauna-jyoshin.com/", []),
    ("newoman", "NEWoMan 高輪", "https://www.newoman.jp/takanawa/", []),
]

for key, brand, url, titles in BRANDS:
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** {brand} 以降は次のタスクで。"); break
    L.append(f"## {brand}")
    L.append("")
    n = from_wiki(key, brand, titles) if titles else 0
    if n == 0:
        n = from_site(key, brand, url)
    if n == 0:
        L.append("  - **取れなかった。** 次はメディアキット／プレスリリースを直接 当たる")
    L.append("")

open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
    json.dumps(man, ensure_ascii=False, indent=2))
json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))

PYEOF_INNER
