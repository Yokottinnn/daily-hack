#!/bin/bash
# **採用した写真だけ、本番用の解像度で取り直す（t145）。LLM 不使用・$0。**
#
# t137 の候補 22 枚を**コンタクトシートにして目で見て**、6 枚に絞った。
# **落としたもの**の例（記録として残す）:
#
#   harumi-1  → **銀座の不二家の夜景。晴海ではない**（場所違い）
#   arakawa-2 → 窓の桟が写り込んでいる
#   sunamachi-3/4 → 信用金庫の建物。商店街の記事に合わない
#
# **1600px の長辺**で取り直し、**出典・ライセンス・作者**を `_manifest.json` に残す。
# 記事に入れるのはクラウド側（このタスクは取るだけ・**判断しない**）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t145-chosen-photos.md"
DIR="$RDIR/chosen-photos"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, io, json, sys, urllib.parse, urllib.request
from PIL import Image

OUT, DIR = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"}
API = "https://commons.wikimedia.org/w/api.php"

# (保存名, コモンズのファイル名, 何に使うか)
WANT = [
    ("arakawa-kakoubashi", "File:荒川右岸終点より荒川河口橋の眺め - panoramio.jpg", "荒川河川敷（江東花火大会）"),
    ("sunamachi-ginza",    "File:Sunamachi ginza shopping street koto tokyo 2009.JPG", "砂町銀座商店街（江東区の街）"),
    ("kachidoki-canal",    "File:Kachidoki canals (32924622428).jpg", "勝どきの運河（中央区の街）"),
    ("rainbow-bridge",     "File:Rainbow Bridge-2.jpg", "レインボーブリッジ（港区）"),
    ("toyosu-gururi",      "File:Toyosu Gururi Park, at Toyosu, Koto, Tokyo (2019-01-01) 02.jpg", "豊洲ぐるり公園"),
    ("harumi-skyline",     "File:Harumi from Rainbow Bridge090505.JPG", "晴海の湾岸スカイライン"),
]

def api(params):
    q = urllib.parse.urlencode({**params, "format": "json", "formatversion": "2"})
    req = urllib.request.Request(f"{API}?{q}", headers=UA)
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.load(r)

lines = [
    "# 採用した写真（t145・**$0**）", "",
    f"生成: **{dt.datetime.now().astimezone():%Y-%m-%dT%H:%M:%S%z}**", "",
    "**長辺 1600px。** 出典・ライセンス・作者は `_manifest.json` に入れてある。", "",
]
man = {"_note": f"本番採用分。取得日 {dt.date.today()}（ops/tasks/t145-fetch-chosen-photos.sh）。", "items": []}

for name, title, use in WANT:
    try:
        d = api({"action": "query", "titles": title, "prop": "imageinfo",
                 "iiprop": "url|extmetadata", "iiurlwidth": "1600"})
        pg = d["query"]["pages"][0]
        ii = pg["imageinfo"][0]
        ex = ii.get("extmetadata", {})
        lic = ex.get("LicenseShortName", {}).get("value", "?")
        art = ex.get("Artist", {}).get("value", "?")
        import re
        art = re.sub(r"<[^>]+>", "", art).strip()
        url = ii.get("thumburl") or ii["url"]
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=40) as r:
            raw = r.read()
        im = Image.open(io.BytesIO(raw)).convert("RGB")
        im.save(f"{DIR}/{name}.jpg", "JPEG", quality=86, optimize=True)
        man["items"].append({"file": f"{name}.jpg", "use": use, "commons_title": title,
                             "page": f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(title.replace(' ', '_'))}",
                             "license": lic, "artist": art, "px": f"{im.width}x{im.height}"})
        lines.append(f"- ✅ `{name}.jpg` / {im.width}x{im.height} / **{lic}** / {art}")
        lines.append(f"      ← {use}")
    except Exception as e:
        lines.append(f"- ⚠️ `{name}` 取れなかった: {type(e).__name__}: {e}")

with open(f"{DIR}/_manifest.json", "w") as f:
    json.dump(man, f, ensure_ascii=False, indent=1)
# **自分で parse して確かめる**（最上位ルール 13）
json.load(open(f"{DIR}/_manifest.json"))
lines += ["", f"**{len(man['items'])} 枚 取れた。** `_manifest.json` も書いた。"]
open(OUT, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
PYEOF
