#!/bin/bash
# **カード 2 ブランドとメンズ脱毛 5 社のロゴを、名前で調べて取る（t146）。LLM 不使用・$0。**
#
# `credit-card-kaiaku-2026` の見出しに 5 ブランドが並んでいるのに、**ロゴが 1 つも無い**
# （最上位ルール 17）。うち 3 つはリポジトリに在ったので流用する。
#
#   三井住友カード → credit-card-campaign-2026-07/logos/smbccard.png
#   PayPayカード   → 同 paypaycard.png
#   楽天ペイ       → qr-payment-comparison-2026/logos/rakutenpay.png
#
# **足りないのは dカードとエポスカードの 2 つだけ。**
#
# ## 取り方（blog-article スキルの順）
#
#   1. **公式のメディアキット・広報ページ**
#   2. プレスリリース
#   3. **ウィキペディア／コモンズ**（MediaWiki API なら実体 URL とライセンスが同時に取れる）
#   4. og:image / apple-touch-icon / class・alt に logo ← **最後の手段**
#
# **取れなかったら、なぜ取れないかを出す。** ページの img / meta / link を
# ダンプして、次を推測で決めない（`t115` と同じ作り）。
#
# **d POINT のロゴを dカードのロゴとして出さない。** 別ブランドの流用は禁止
# （最上位ルール 17「運営会社のロゴを店舗ブランドのロゴとして出さない」と同じ根）。
#
# **SVG なら変換せずそのまま置く。** Mac には rsvg-convert も inkscape も無い
# （`docs/mac-environment.md`）。クラウド側で Chromium で PNG にする。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t146-dcard-epos-logos.md"
DIR="$RDIR/logos-card"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, json, re, sys, time, urllib.parse, urllib.request

OUT, DIR = sys.argv[1], sys.argv[2]
# **1 タスク 5 分 以内**（最上位ルール 15）。対象が 7 件あるので、時間で打ち切る
T0 = time.monotonic()
BUDGET = 210.0
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"}

def get(url, timeout=25):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read(), r.headers.get("Content-Type", ""), r.geturl()

lines = ["# dカード / エポスカードのロゴ（t146・**$0**）", "",
         f"生成: **{dt.datetime.now().astimezone():%Y-%m-%dT%H:%M:%S%z}**", "",
         "**値は無し。取得元とライセンスを必ず残す。**", ""]
man = {"_note": f"取得日 {dt.date.today()}（ops/tasks/t146-dcard-epos-logos.sh）。", "items": []}

# --- 1) コモンズを名前で引く（ライセンスが一緒に取れるので第一候補）-------------
COMMONS = "https://commons.wikimedia.org/w/api.php"
def commons_search(term, limit=6):
    q = urllib.parse.urlencode({
        "action": "query", "generator": "search",
        "gsrsearch": f"filetype:bitmap|drawing {term}", "gsrnamespace": "6",
        "gsrlimit": str(limit), "prop": "imageinfo",
        "iiprop": "url|extmetadata", "iiurlwidth": "600",
        "format": "json", "formatversion": "2"})
    try:
        raw, _, _ = get(f"{COMMONS}?{q}")
        return json.loads(raw).get("query", {}).get("pages", []) or []
    except Exception as e:
        lines.append(f"- コモンズ検索が失敗: `{term}` — {type(e).__name__}")
        return []

TARGETS = [
    ("dcard", "dカード", ["dcard docomo logo", "NTT Docomo dCARD"],
     "https://dcard.docomo.ne.jp/"),
    ("eposcard", "エポスカード", ["Epos Card logo", "エポスカード"],
     "https://www.eposcard.co.jp/"),
    # **メンズ脱毛の 5 社**（mens-hairremoval-comparison-2026・ロゴが 1 つも無い）
    ("mensrize", "メンズリゼ", ["Mens Rize clinic logo"], "https://www.mens-rize.com/"),
    ("sbcmens", "湘南美容クリニック", ["Shonan Beauty Clinic logo", "湘南美容外科"],
     "https://www.sbc-mens.net/"),
    ("gorilla", "ゴリラクリニック", ["Gorilla Clinic logo"], "https://gorilla.clinic/"),
    ("rinx", "RINX", ["RINX mens datsumou logo"], "https://mens-rinx.jp/"),
    ("menstbc", "メンズTBC", ["TBC group logo", "メンズTBC"], "https://www.tbc.co.jp/mens/"),
]

for key, jp, terms, site in TARGETS:
    if time.monotonic() - T0 > BUDGET:
        lines += [f"## {jp}", "", "- ⏱️ **時間切れで見ていない**（次のタスクで取る）", ""]
        continue
    lines += [f"## {jp}", ""]
    got = False
    for t in terms:
        for pg in commons_search(t):
            ii = (pg.get("imageinfo") or [{}])[0]
            title = pg.get("title", "")
            ex = ii.get("extmetadata", {})
            lic = ex.get("LicenseShortName", {}).get("value", "?")
            art = re.sub(r"<[^>]+>", "", ex.get("Artist", {}).get("value", "?")).strip()
            url = ii.get("thumburl") or ii.get("url")
            if not url:
                continue
            try:
                blob, ctype, real = get(url, 30)
            except Exception as e:
                lines.append(f"- ⚠️ `{title}` 取れない: {type(e).__name__}")
                continue
            ext = "svg" if blob[:400].lstrip()[:4] == b"<svg" else "png"
            name = f"{key}-commons-{len(man['items'])}.{ext}"
            open(f"{DIR}/{name}", "wb").write(blob)
            man["items"].append({"file": name, "brand": jp, "source": "commons",
                                 "commons_title": title, "license": lic, "artist": art,
                                 "page": f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(title.replace(' ', '_'))}"})
            lines.append(f"- ✅ `{name}` / **{lic}** / {art} ← {title}")
            got = True
        if got:
            break

    # --- 2) 公式ページの img / meta / link を**丸ごとダンプ**する -----------------
    #     取れても取れなくても出す。**推測で次を決めないため**（t115 と同じ）
    try:
        html, _, _ = get(site, 25)
        text = html.decode("utf-8", "replace")
        cands = []
        for m in re.finditer(r'<img[^>]+>', text[:400000]):
            tag = m.group(0)
            if re.search(r'logo|ロゴ', tag, re.I):
                src = (re.search(r'src="([^"]+)"', tag) or [None, ""])[1]
                alt = (re.search(r'alt="([^"]*)"', tag) or [None, ""])[1]
                if src:
                    cands.append((src, alt))
        og = (re.search(r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"', text) or [None, ""])[1]
        ati = (re.search(r'<link[^>]+apple-touch-icon[^>]*href="([^"]+)"', text) or [None, ""])[1]
        lines += ["", f"**公式（{site}）のダンプ**", ""]
        for src, alt in cands[:8]:
            lines.append(f"  - `{src[:110]}` alt=`{alt[:40]}`")
        if og:
            lines.append(f"  - og:image: `{og[:110]}`")
        if ati:
            lines.append(f"  - apple-touch-icon: `{ati[:110]}`")
        if not cands and not og and not ati:
            lines.append("  - **何も出てこない**（JS で描いている可能性）")
        # **候補の 1 件目だけ実体も取る。** 採否はクラウド側で目で見て決める
        for i, (src, _alt) in enumerate(cands[:3]):
            u = urllib.parse.urljoin(site, src)
            try:
                blob, ctype, _ = get(u, 25)
            except Exception:
                continue
            ext = "svg" if blob[:400].lstrip()[:4] == b"<svg" else \
                  ("png" if b"PNG" in blob[:8] else "jpg")
            name = f"{key}-site-{i}.{ext}"
            open(f"{DIR}/{name}", "wb").write(blob)
            man["items"].append({"file": name, "brand": jp, "source": "official",
                                 "page": site, "src": u, "license": "商標（識別目的で使用）"})
            lines.append(f"  - ⬇️ `{name}`（{len(blob)} bytes）← `{u[:100]}`")
    except Exception as e:
        lines.append(f"- ⚠️ 公式が開けない: {type(e).__name__}: {e}")
    lines.append("")

with open(f"{DIR}/_manifest.json", "w") as f:
    json.dump(man, f, ensure_ascii=False, indent=1)
json.load(open(f"{DIR}/_manifest.json"))   # **自分で parse して確かめる**（ルール 13）

lines += ["---", "", f"**{len(man['items'])} 件 持ち帰った。**",
          "**採否はクラウド側でコンタクトシートにして目で見て決める。**",
          "**別ブランド・認証マーク・宣伝画像が混ざる**ので、そのまま入れない。"]
open(OUT, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
PYEOF
