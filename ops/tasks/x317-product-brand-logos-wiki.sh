#!/bin/bash
# **x316 の取り直し。メーカーのロゴを、各社の Wikipedia 記事に載っているファイルから取る（x317）。費用 $0。**
#
# x316 は Commons の全文検索で引いたため、別会社（ドイツの Anker）や古い版（Sony make.believe）を掴み、
# 途中から 429 で止まった。**会社の記事そのものが使っているロゴのファイル**を引けば取り違えない。
#
#   ① en.wikipedia の会社の記事の images から、名前に logo を含むファイルを上位 3 件
#   ② imageinfo の thumburl（幅 600・SVG も PNG で返る）を取る。ライセンス・説明ページを残す
#   ③ SwitchBot は App Store の提供元アイコン（trackName / sellerName を出す）も取る
#   **1 回ごとに 4 秒 空ける**（429 対策）。429 が出たらそのブランドは飛ばして次へ
#
# **採否はクラウド側で目で見て決める。** 商標であり自由ライセンスではない。取得元を必ず残す。
# **秘密は出さない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/x317-brand-logos.md"
DIR="$RDIR/x317-logos"
rm -rf "$DIR"; mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,8))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.8 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, json, sys, time, urllib.parse, urllib.request
OUT, DIR = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; contact via github.com/Yokottinnn/daily-hack)"}
API = "https://en.wikipedia.org/w/api.php"
BRANDS = [("anker", "Anker Innovations"), ("sony", "Sony"), ("panasonic", "Panasonic"),
          ("nintendo", "Nintendo"), ("zojirushi", "Zojirushi"), ("switchbot", "SwitchBot")]
t0 = time.time()

def get(u):
    time.sleep(4)
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=25) as r:
        return r.read()

def api(params):
    return json.loads(get(API + "?" + urllib.parse.urlencode(dict(params, format="json"))).decode("utf-8"))

L = ["# メーカーロゴを各社の Wikipedia 記事から取る（x317）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**商標であり自由ライセンスではない。** 採否はクラウド側で目で見て決める。", ""]
man = {}
for key, page in BRANDS:
    if time.time() - t0 > 230: L.append("- **時間切れ。ここで止める。**"); break
    L += [f"## {page}", "", "```"]
    try:
        r = api({"action": "query", "titles": page, "prop": "images", "imlimit": 50, "redirects": 1})
        pg = next(iter(r.get("query", {}).get("pages", {}).values()), {})
        files = [x["title"] for x in pg.get("images", []) if "logo" in x["title"].lower()]
        L.append(f"  記事: {pg.get('title')} / logo を含むファイル {len(files)} 件")
        n = 0
        for t in files[:3]:
            ii = api({"action": "query", "titles": t, "prop": "imageinfo", "iiprop": "url|mime|extmetadata", "iiurlwidth": 600})
            p2 = next(iter(ii.get("query", {}).get("pages", {}).values()), {})
            info = (p2.get("imageinfo") or [{}])[0]
            src = info.get("thumburl") or info.get("url")
            if not src: continue
            lic = (info.get("extmetadata", {}).get("LicenseShortName") or {}).get("value", "")
            blob = get(src); n += 1
            name = f"{key}-{n}.png"; open(f"{DIR}/{name}", "wb").write(blob)
            man[name] = {"brand": page, "title": t, "page": info.get("descriptionurl"), "src": src, "orig": info.get("url"),
                         "license": lic, "fetched": dt.date.today().isoformat(), "task": "ops/tasks/x317-product-brand-logos-wiki.sh"}
            L.append(f"  {name:16s} {len(blob):7d} bytes  [{lic}]  {t}")
        L.append(f"  対象 {min(len(files),3)} / 取れた {n}")
    except Exception as e:
        L.append(f"  **失敗**: {type(e).__name__}: {str(e)[:200]}")
    L += ["```", ""]

L += ["## SwitchBot（App Store）", "", "```"]
try:
    u = "https://itunes.apple.com/jp/search?" + urllib.parse.urlencode({"term": "SwitchBot", "entity": "software", "country": "jp", "limit": 3})
    res = json.loads(get(u).decode("utf-8")).get("results", [])
    for i, x in enumerate(res[:3], 1):
        L.append(f"  app {i}: id={x.get('trackId')} {x.get('trackName')} / {x.get('sellerName')}")
        art = x.get("artworkUrl512")
        if art:
            name = f"switchbot-app-{i}.png"; open(f"{DIR}/{name}", "wb").write(get(art))
            man[name] = {"brand": x.get("trackName"), "seller": x.get("sellerName"), "src": art, "page": x.get("trackViewUrl"),
                         "fetched": dt.date.today().isoformat(), "task": "ops/tasks/x317-product-brand-logos-wiki.sh"}
except Exception as e:
    L.append(f"  **失敗**: {type(e).__name__}: {str(e)[:200]}")
L += ["```", ""]
json.dump(man, open(f"{DIR}/_manifest.json", "w"), ensure_ascii=False, indent=2)
L.append(f"取れた画像: **{len(man)} 枚**（`reports/x317-logos/`）。**LLM を呼んでいない（$0／回・$0／日・$0／月）。**")
open(OUT, "w").write("\n".join(L) + "\n")
print(f"x317: ロゴ候補 {len(man)} 枚 / {OUT.split('/')[-1]}")
PYEOF
