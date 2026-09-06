#!/bin/bash
# **まいばすけっととロピア（日本の店舗）の写真を取り直す。検索語が悪かった。**
#
# ## t058 で何が起きたか
#
# 38 枚 取れて、**大半は当たりだった。**
#
#   ok-1..4      … OK Hiyoshi / Isehara / Kita-yamata / Kohoku store（CC BY-SA 4.0）
#   trial-4      … **TRIAL SEIYU Hanakoganei 202604**（記事の核になる 1 枚）
#   gyomu-1..4   … Gyomu Super Fukaebashi / Fuse / Hanada
#   hanamasa-3,4 … **meat prices at Hanamasa**（値札が写っている・CC0）
#   donki-2..4   … 六本木 / 阿倍野 / 国際通り
#
# **外れたのは 2 つ。**
#
#   maibasket-1..4 … **全部 NBA**。"My Basket" が basketball に化けた
#   donki-1        … **バレエ「ドン・キホーテ」の舞台写真**
#   lopia-1,2      … 台湾（Lalaport Taichung / IKEA Taichung）。日本の店ではない
#
# ## 直し方
#
# **英語の一般名詞に化ける語を使わない。** 日本語の表記と、
# 施設名・地名を付けた語で引く。**そのうえで題名を目で見て選ぶ。**
#
# 出力: `$OPS_REPORT_DIR/photos2/` と `_sources.json`
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
DEST="$RDIR/photos2"
OUT="$RDIR/t059-photos2.md"
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
L = ["# まいばすけっと・ロピアの写真（t059 / 検索語を直した）", "",
     "**採用していない。候補を落としただけ。**", ""]
manifest = []

def get(url, binary=False, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read() if binary else r.read().decode("utf-8", "replace")

# **英語の一般名詞に化ける語を避ける。** 日本語表記と地名で引く。
CHAINS = [
    ("maibasket", ["まいばすけっと", "Maibasketto", "まいばすけっと 店舗",
                   "Aeon Maibasketto", "My Basket Aeon store Japan"]),
    ("lopia",     ["ロピア 店舗", "Lopia Japan store", "ロピア 川崎",
                   "Lopia supermarket Kanagawa"]),
    # トライアル西友は当たっているが、もう少し欲しい
    ("trial",     ["トライアル 店舗", "TRIAL SEIYU", "西友 店舗", "Seiyu supermarket Tokyo"]),
]

API = "https://commons.wikimedia.org/w/api.php"
# **明らかに別物の語を弾く。** NBA・バレエで踏んだ。
NG = re.compile(r"basketball|NBA|ballet|ballerina|theat|opera|dunk|Thunder|"
                r"logo|\.svg$", re.I)

for key, queries in CHAINS:
    L.append(""); L.append(f"## {key}")
    got = 0
    for q in queries:
        if got >= 6:
            break
        try:
            u = (API + "?action=query&format=json&generator=search&gsrnamespace=6"
                 "&gsrlimit=15&gsrsearch=" + urllib.parse.quote(q)
                 + "&prop=imageinfo&iiprop=url|size|extmetadata&iiurlwidth=1600")
            d = json.loads(get(u))
        except Exception as e:
            L.append(f"- 「{q}」検索失敗: {type(e).__name__}")
            continue
        pages = ((d.get("query") or {}).get("pages") or {})
        L.append(f"- 「{q}」… {len(pages)} 件")
        for _, p in pages.items():
            if got >= 6:
                break
            title = p.get("title", "")
            if NG.search(title):
                L.append(f"  - ✗ {title} … 別物として弾いた")
                continue
            ii = (p.get("imageinfo") or [{}])[0]
            w, h = ii.get("width", 0), ii.get("height", 0)
            if w < 800 or h < 450 or w / max(h, 1) > 3.5:
                continue
            meta = ii.get("extmetadata") or {}
            lic = (meta.get("LicenseShortName") or {}).get("value", "?")
            art = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "?"))[:60]
            url = ii.get("thumburl") or ii.get("url")
            try:
                b = get(url, binary=True, timeout=30)
            except Exception:
                continue
            if len(b) < 25000:
                continue
            ext = ".png" if b[:4] == b"\x89PNG" else ".jpg"
            got += 1
            name = f"{key}-{got}{ext}"
            with open(os.path.join(DEST, name), "wb") as f:
                f.write(b)
            page = f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(title)}"
            manifest.append({"file": name, "src": url, "page": page,
                             "title": title, "license": lic, "artist": art,
                             "size": f"{w}x{h}"})
            L.append(f"  - ✓ `{name}` … {title} / {lic} / {art} / {w}x{h}")
    if got == 0:
        L.append("- **1 枚も取れなかった**")

with open(os.path.join(DEST, "_sources.json"), "w") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)

L.append(""); L.append(f"## 合計 {len(manifest)} 枚")
with open(OUT, "w") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF

echo "=== 落とした画像 ==="
ls -la "$DEST" 2>/dev/null | head -40
exit 0
