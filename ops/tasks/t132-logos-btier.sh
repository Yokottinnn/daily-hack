#!/bin/bash
# **B 区分（QR決済・EC・証券・ふるさと納税）のロゴを取る（t132）。**
#
# docs/logo-inventory.md は**リンクのドメイン数**で数えていたが、
# **B 区分の記事はブランド名が見出しに出ていて、リンクが無い**ものが多い。
# 実際に見たら、QR決済は PayPay / 楽天ペイ / d払い、EC はヨドバシ / Amazon / 楽天市場、
# NISA は SBI 証券 / 楽天証券 が**見出しで並んでいた。** 棚卸しの数字より多い。
#
# 取り方の土台は t126 / t128 / t130 と同じ
# （3 回 試す・percent-encode・**SVG はそのまま持ち帰る**・UA で再試行）。
# ラスタライズはクラウド側の `scripts/svg-to-png.mjs`。
#
# **判断はしない。** 採否はクラウド側で目で見て決める。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t132-logos-btier.md"
DIR="$RDIR/logos-btier"
mkdir -p "$DIR"

{
  echo "## 0) Mac に何が在るか（SVG 変換まわり）"
  echo ""
  for c in qlmanage rsvg-convert inkscape magick convert sips node npx; do
    p="$(command -v "$c" 2>/dev/null || true)"
    if [ -n "$p" ]; then echo "  - \`$c\` … 在る（\`$p\`）"; else echo "  - \`$c\` … **無い**"; fi
  done
  echo ""
} > "$DIR/_env.md"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import cairosvg" 2>/dev/null && echo "  - \`cairosvg\` … 在る" >> "$DIR/_env.md" \
  || echo "  - \`cairosvg\` … **無い**" >> "$DIR/_env.md"

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, io, json, re, sys, time, urllib.parse, urllib.request
from PIL import Image

OUT, DIR = sys.argv[1], sys.argv[2]
BUDGET = 235.0
UA_BOT = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"}
UA_BROWSER = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36",
              "Accept": "text/html,application/xhtml+xml,image/avif,image/webp,*/*;q=0.8",
              "Accept-Language": "ja,en;q=0.8"}

SEARCH = [
    ("paypay",   "PayPay",       "PayPay logo"),
    ("amazon",   "Amazon.co.jp", "Amazon logo"),
    ("rakutenec","楽天市場",     "Rakuten Ichiba logo"),
    ("sbisec",   "SBI証券",      "SBI Securities logo"),
]
APPS = []   # **この回はアプリを取らない**
SITES = [
    ("rakutenpay", "楽天ペイ",       "https://pay.rakuten.co.jp/"),
    ("dbarai",     "d払い",          "https://service.smt.docomo.ne.jp/keitai_payment/"),
    ("aupay",      "au PAY",         "https://aupay.wallet.auone.jp/"),
    ("yodobashi",  "ヨドバシ.com",   "https://www.yodobashi.com/"),
    ("rakutensec", "楽天証券",       "https://www.rakuten-sec.co.jp/"),
    ("monex",      "マネックス証券", "https://www.monex.co.jp/"),
    ("satofuru",   "さとふる",       "https://www.satofull.jp/"),
    ("furunavi",   "ふるなび",       "https://furunavi.jp/"),
]

def enc(u):
    """**URL に日本語が入っていても落ちないようにする。**（t123 の UnicodeEncodeError）"""
    p = urllib.parse.urlsplit(u)
    return urllib.parse.urlunsplit((
        p.scheme, p.netloc,
        urllib.parse.quote(p.path, safe="/%:@"),
        urllib.parse.quote(p.query, safe="=&?/%:@+"),
        p.fragment))

def getb(u, t=18, tries=3, browser=False):
    """**1 回の失敗で諦めない。**（t123 はコモンズが 5 件 とも URLError だった）"""
    last = None
    for i in range(tries):
        for hdr in ([UA_BROWSER] if browser else [UA_BOT, UA_BROWSER]):
            try:
                req = urllib.request.Request(enc(u), headers=hdr)
                with urllib.request.urlopen(req, timeout=t) as r:
                    return r.read()
            except Exception as e:
                last = e
        time.sleep(1.5 * (i + 1))
    raise last

def gets(u, **kw):
    return getb(u, **kw).decode("utf-8", "replace")

L = ["# B 区分のロゴ候補（t132）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**SVG は変換せずそのまま持ち帰る。** ラスタライズはクラウド側で Chromium が行う。",
     "**採否はクラウド側で目で見て決める。**", ""]
try:
    L += [open(f"{DIR}/_env.md", encoding="utf-8").read()]
except Exception:
    pass
man = {"_note": "識別目的で使うロゴ。**商標であり自由ライセンスではない。**"
                "取得日 " + dt.date.today().isoformat() + "（ops/tasks/t128-logos-btier.sh）。"}
t0 = time.time()

def save(blob, name, src, page, lic, brand, key):
    global L
    head = blob[:400].lstrip()
    if head[:4] == b"<svg" or b"<svg" in head[:200]:
        # **SVG はそのまま置く。** Pillow では開けない
        open(f"{DIR}/{name}.svg", "wb").write(blob)
        L.append(f"  - 📄 `{name}.svg` / {len(blob)} bytes（**SVG のまま持ち帰る**）")
        man.setdefault(key, []).append({"brand": brand, "file": f"{name}.svg", "source": src,
                                        "page": page, "license_note": lic, "format": "svg"})
        return True
    try:
        im = Image.open(io.BytesIO(blob)); im.load()
    except Exception as e:
        L.append(f"  - ✗ 開けない（{type(e).__name__}）"); return False
    w, h = im.size
    if w < 80 or h < 16 or (h and w / h > 14):
        L.append(f"  - ✗ {w}x{h}（形が合わない）"); return False
    im.convert("RGBA").save(f"{DIR}/{name}.png", "PNG", optimize=True)
    L.append(f"  - ✅ `{name}.png` / {w}x{h} / **{lic}**")
    man.setdefault(key, []).append({"brand": brand, "file": f"{name}.png", "source": src,
                                    "page": page, "license_note": lic, "width": w, "height": h})
    return True

L += ["## A0) App Store（ID を直に指定）", ""]
for key, brand, appid in APPS:
    L += [f"### {brand}（id {appid}）", ""]
    try:
        d = json.loads(gets(f"https://itunes.apple.com/jp/lookup?id={appid}"))
        rs = d.get("results") or []
        if not rs:
            L += ["  - ✗ 見つからない", ""]; continue
        r = rs[0]
        # **名前を必ず出す。** ID 取り違えをここで気づけるようにする
        L.append(f"  - ストア上の名前: **{(r.get('trackName') or '?')[:48]}**")
        L.append(f"  - 提供元: **{(r.get('sellerName') or '?')[:40]}**")
        u = r.get("artworkUrl512") or r.get("artworkUrl100")
        save(getb(u), f"{key}-app", u, r.get("trackViewUrl", ""),
             "App Store の登録アイコン（商標）", brand, key)
    except Exception as e:
        L.append(f"  - ✗ {type(e).__name__}")
    L.append("")

L += ["## A) コモンズの検索（3 回 まで試す）", ""]
for key, brand, term in SEARCH:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。**"); break
    L += [f"### {brand}", ""]
    q = urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": f"filetype:bitmap|drawing {term}", "gsrnamespace": "6", "gsrlimit": "5",
        "prop": "imageinfo", "iiprop": "url|size|extmetadata", "iiurlwidth": "600"})
    try:
        d = json.loads(gets(f"https://commons.wikimedia.org/w/api.php?{q}"))
    except Exception as e:
        L += [f"  - ✗ 3 回 とも失敗（{type(e).__name__}: {str(e)[:70]}）", ""]; continue
    pages = (d.get("query") or {}).get("pages") or {}
    n = 0
    for _, pg in sorted(pages.items(), key=lambda kv: kv[1].get("index", 99)):
        if n >= 2 or time.time() - t0 > BUDGET:
            break
        ii = (pg.get("imageinfo") or [None])[0]
        if not ii:
            continue
        em = ii.get("extmetadata") or {}
        lic = (em.get("LicenseShortName") or {}).get("value") or "表記なし"
        title = pg.get("title", "?")
        u = ii.get("thumburl") or ii["url"]
        try:
            if save(getb(u), f"{key}-{n+1}", u,
                    "https://commons.wikimedia.org/wiki/" +
                    urllib.parse.quote(title.replace(" ", "_")), lic, brand, key):
                n += 1
                L.append(f"        ← {title}")
        except Exception as e:
            L.append(f"  - ✗ {type(e).__name__}")
    if n == 0:
        L.append("  - **使えるものが無かった。**")
    L.append("")

IMG = re.compile(r"<img\b[^>]*>", re.I)
ATTR = re.compile(r'(src|data-src|srcset|alt|class|id)\s*=\s*["\']([^"\']*)["\']', re.I)
TOUCH = re.compile(r'<link\b[^>]*rel=["\'][^"\']*apple-touch-icon[^"\']*["\'][^>]*>', re.I)
HREF = re.compile(r'href\s*=\s*["\']([^"\']+)["\']', re.I)
# **別の会場・別のブランドを掴まない**（t123 は Shibuya PIT ZERO と Sendai PIT を拾った）
DENY = re.compile(r"shibuya|sendai|umeda|kanazawa|zepp|banner|campaign|sponsor|partner", re.I)

L += ["## B) 公式サイト（SVG も持ち帰る）", ""]
for key, brand, url in SITES:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。**"); break
    L += [f"### {brand}", f"  - 取得元: {url}", ""]
    try:
        html = gets(url)
    except Exception as e:
        L += [f"  - ✗ ページが開けない（{type(e).__name__}）", ""]; continue

    cands = []
    for tag in IMG.findall(html)[:400]:
        a = {k.lower(): v for k, v in ATTR.findall(tag)}
        s = a.get("src") or a.get("data-src") or (a.get("srcset", "").split()[:1] or [""])[0]
        if not s or s.startswith("data:"):
            continue
        blob = " ".join([s, a.get("alt", ""), a.get("class", ""), a.get("id", "")]).lower()
        if ("logo" in blob or "ロゴ" in blob) and not DENY.search(blob):
            cands.append((urllib.parse.urljoin(url, s), a.get("alt", "")[:40]))
    for tag in TOUCH.findall(html)[:3]:
        m = HREF.search(tag)
        if m:
            cands.append((urllib.parse.urljoin(url, m.group(1)), "apple-touch-icon"))

    seen, uniq = set(), []
    for u, alt in cands:
        if u not in seen:
            seen.add(u); uniq.append((u, alt))

    if not uniq:
        L.append("  - **`logo` を含む img が無い。** ページ内の img を先頭 12 件 出す:")
        for tag in IMG.findall(html)[:12]:
            L.append(f"    - `{tag[:150]}`")
        L.append("")
        continue

    n = 0
    for u, alt in uniq:
        if n >= 4 or time.time() - t0 > BUDGET:
            break
        L.append(f"  - 候補: `{u[:110]}` / alt=`{alt}`")
        try:
            if save(getb(u, 15), f"{key}-{n+1}", u, url,
                    "公式サイトのロゴ画像（商標）", brand, key):
                n += 1
        except Exception as e:
            L.append(f"    - ✗ {type(e).__name__}")
    L.append("")

open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
    json.dumps(man, ensure_ascii=False, indent=2))
json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
