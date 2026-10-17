#!/bin/bash
# **感謝祭の記事に足す「7 商品の買い比べ」の表のメーカーロゴを、名前で探して候補を取る（x316）。費用 $0。**
#
# 最上位ルール 17: ブランド名を並べたら左にロゴ。表に Anker・ソニー・パナソニック・任天堂・象印・SwitchBot が並ぶ
# （Apple は hoso-daigaku-gakuwari-2026/logos/apple.png が在る）。
# クラウドからは Commons の API が 429 で弾かれるので Mac で取る。
#
#   ① Commons のファイル検索（名前空間 6）で「<名前> logo」の上位を引く
#   ② imageinfo の thumburl（幅 600・SVG も PNG にして返る）を取る。ライセンスと説明ページも残す
#
# **採否はクラウド側で目で見て決める。** 商標であり自由ライセンスではない。取得元を必ず残す。
# **秘密は出さない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/x316-brand-logos.md"
DIR="$RDIR/x316-logos"
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
API = "https://commons.wikimedia.org/w/api.php"
BRANDS = [("anker", "Anker"), ("sony", "Sony"), ("panasonic", "Panasonic"),
          ("nintendo", "Nintendo"), ("zojirushi", "Zojirushi"), ("switchbot", "SwitchBot")]
t0 = time.time()

def api(params):
    params = dict(params, format="json")
    u = API + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=25) as r:
        return json.loads(r.read().decode("utf-8"))

L = ["# 7 商品のメーカーロゴを名前で探す（x316）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**商標であり自由ライセンスではない。** 採否はクラウド側で目で見て決める。", ""]
man = {}
for key, q in BRANDS:
    if time.time() - t0 > 200: L.append("- **時間切れ。ここで止める。**"); break
    L += [f"## {q}", "", "```"]
    try:
        s = api({"action": "query", "list": "search", "srsearch": f"{q} logo", "srnamespace": 6, "srlimit": 6})
        titles = [x["title"] for x in s.get("query", {}).get("search", [])]
        L.append(f"  検索の上位: {len(titles)} 件")
        n = 0
        for t in titles:
            if n >= 4: break
            ii = api({"action": "query", "titles": t, "prop": "imageinfo", "iiprop": "url|mime|size|extmetadata", "iiurlwidth": 600})
            pg = next(iter(ii.get("query", {}).get("pages", {}).values()), {})
            info = (pg.get("imageinfo") or [{}])[0]
            src = info.get("thumburl") or info.get("url")
            if not src: continue
            meta = info.get("extmetadata", {})
            lic = (meta.get("LicenseShortName") or {}).get("value", "")
            n += 1
            name = f"{key}-{n}.png"
            with urllib.request.urlopen(urllib.request.Request(src, headers=UA), timeout=25) as r:
                blob = r.read()
            open(f"{DIR}/{name}", "wb").write(blob)
            man[name] = {"brand": q, "title": t, "page": info.get("descriptionurl"), "src": src,
                         "orig": info.get("url"), "mime": info.get("mime"), "license": lic,
                         "fetched": dt.date.today().isoformat(), "task": "ops/tasks/x316-product-brand-logos.sh"}
            L.append(f"  {name:16s} {len(blob):7d} bytes  {info.get('mime')}  [{lic}]  {t}")
            time.sleep(1.0)
        L.append(f"  対象 {min(len(titles),4)} / 取れた {n}")
    except Exception as e:
        L.append(f"  **失敗**: {type(e).__name__}: {str(e)[:200]}")
    L += ["```", ""]
    time.sleep(1.5)
# 楽天市場（日本版）のロゴ。記事の rakutenichiba.png は台湾版「樂天市場」だった（2026-10-17 に利用者が X の画像で指摘）。
# ① App Store に提供元が登録したアプリのアイコン（trackName と sellerName を必ず出す）
# ② 楽天市場トップの img / link / meta から logo を含む参照を丸ごと出し、svg/png は取る
L += ["## 楽天市場（日本版）", "", "```"]
try:
    u = "https://itunes.apple.com/jp/search?" + urllib.parse.urlencode({"term": "楽天市場", "entity": "software", "country": "jp", "limit": 5})
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=25) as r:
        res = json.loads(r.read().decode("utf-8")).get("results", [])
    for i, x in enumerate(res[:3], 1):
        L.append(f"  app {i}: id={x.get('trackId')} {x.get('trackName')} / {x.get('sellerName')}")
        art = x.get("artworkUrl512")
        if art:
            with urllib.request.urlopen(urllib.request.Request(art, headers=UA), timeout=25) as r:
                blob = r.read()
            name = f"rakuten-app-{i}.png"; open(f"{DIR}/{name}", "wb").write(blob)
            man[name] = {"brand": x.get("trackName"), "seller": x.get("sellerName"), "src": art,
                         "page": x.get("trackViewUrl"), "fetched": dt.date.today().isoformat(), "task": "ops/tasks/x316-product-brand-logos.sh"}
except Exception as e:
    L.append(f"  App Store **失敗**: {type(e).__name__}: {str(e)[:200]}")
try:
    import re
    req = urllib.request.Request("https://www.rakuten.co.jp/", headers={**UA, "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"})
    with urllib.request.urlopen(req, timeout=25) as r:
        page = r.read().decode("utf-8", "replace")
    refs = sorted(set(re.findall(r'(?:src|href|content)="([^"]*?(?:logo|Logo|LOGO)[^"]*?)"', page)))
    L.append(f"  トップ {len(page)} bytes / logo を含む参照 {len(refs)} 件")
    n = 0
    for ref in refs[:15]:
        L.append(f"    {ref[:160]}")
        full = urllib.parse.urljoin("https://www.rakuten.co.jp/", ref)
        if n < 6 and re.search(r"\.(svg|png)(\?|$)", full):
            try:
                with urllib.request.urlopen(urllib.request.Request(full, headers=UA), timeout=20) as r:
                    blob = r.read()
                n += 1
                ext = "svg" if blob[:400].lstrip()[:4] == b"<svg" or full.split("?")[0].endswith(".svg") else "png"
                name = f"rakuten-top-{n}.{ext}"; open(f"{DIR}/{name}", "wb").write(blob)
                man[name] = {"brand": "楽天市場", "src": full, "page": "https://www.rakuten.co.jp/", "fetched": dt.date.today().isoformat(), "task": "ops/tasks/x316-product-brand-logos.sh"}
            except Exception as e:
                L.append(f"      取れない: {type(e).__name__}")
except Exception as e:
    L.append(f"  トップ **失敗**: {type(e).__name__}: {str(e)[:200]}")
L += ["```", ""]
json.dump(man, open(f"{DIR}/_manifest.json", "w"), ensure_ascii=False, indent=2)
L.append(f"取れた画像: **{len(man)} 枚**（`reports/x316-logos/`）。**LLM を呼んでいない（$0／回・$0／日・$0／月）。**")
open(OUT, "w").write("\n".join(L) + "\n")
print(f"x316: ロゴ候補 {len(man)} 枚 / {OUT.split('/')[-1]}")
PYEOF
