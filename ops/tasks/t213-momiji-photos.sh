#!/bin/bash
# **紅葉 2026 の記事の写真候補を取る（t213）。読むだけ・LLM 不使用・$0。**
#
# 利用者が選んだ記事案 #1。表紙（6 枚タイル）と 1 名所 1 節の写真に使う。
# t103 の作りを写した（Commons API・ライセンス台帳つき・落ちた理由を 1 件ずつ書く・リサイズしない）。
# **1 件目を無条件に採らない。** 選ぶのはクラウド側で、目で見てから。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t213-momiji-photos.md"
DIR="$RDIR/momiji-photos"
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
BUDGET = 230.0
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "daily-hack-ops/1.0 (https://daily-hack.fieldbeside.com/)"}

THEMES = [
    ("jingu-gaien", ["Meiji Jingu Gaien ginkgo avenue", "Jingu Gaien Icho Namiki autumn"]),
    ("takao",       ["Mount Takao autumn leaves", "Takaosan autumn"]),
    ("showa-kinen", ["Showa Kinen Park autumn", "Showa Memorial Park ginkgo"]),
    ("rikugien",    ["Rikugien autumn", "Rikugien garden autumn leaves"]),
    ("nikko",       ["Irohazaka autumn", "Nikko autumn leaves"]),
    ("shinjuku-gyoen", ["Shinjuku Gyoen autumn", "Shinjuku Gyoen autumn leaves"]),
    ("kyu-furukawa", ["Kyu-Furukawa Gardens autumn", "Tonogayato Garden autumn"]),
]

def api(params):
    q = urllib.parse.urlencode({**params, "format": "json", "formatversion": "2"})
    req = urllib.request.Request(f"{API}?{q}", headers=UA)
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode("utf-8", "replace"))

def plain(v):
    return re.sub(r"<[^>]+>", " ", v or "").strip()

L = ["# 記事に入れる写真の候補（t213）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**落ちた理由も 1 件ずつ書く**（t095 は 0 枚で、理由が分からなかった）。", ""]
ledger, t0 = {}, time.time()

for key, terms in THEMES:
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** `{key}` 以降は次のタスクで。")
        break
    L += [f"## {key}", ""]
    got = 0
    for term in terms:
        if got >= 3 or time.time() - t0 > BUDGET:
            break
        L.append(f"検索語 `{term}`")
        try:
            d = api({"action": "query", "generator": "search", "gsrsearch": f"filetype:bitmap {term}",
                     "gsrnamespace": "6", "gsrlimit": "14", "prop": "imageinfo",
                     "iiprop": "url|size|extmetadata", "iiurlwidth": "1200"})
        except Exception as e:
            L += [f"- ❌ {type(e).__name__}: {str(e)[:140]}", ""]
            continue
        pages = (d.get("query") or {}).get("pages") or []
        L.append(f"- 検索ヒット **{len(pages)} 件**")
        for p in pages:
            if got >= 3:
                break
            title = p.get("title", "?")
            info = p.get("imageinfo") or []
            if not info:
                L.append(f"  - ✗ {title}: imageinfo が無い")
                continue
            ii = info[0]
            meta = ii.get("extmetadata") or {}
            lic = plain((meta.get("LicenseShortName") or {}).get("value"))
            w, h = ii.get("width") or 0, ii.get("height") or 0
            url = ii.get("thumburl") or ii.get("url") or ""
            if lic and re.search(r"fair use|non-free", lic, re.I):
                L.append(f"  - ✗ {title}: ライセンス {lic}")
                continue
            if w < 800:
                L.append(f"  - ✗ {title}: 幅 {w}px（800 未満）")
                continue
            if h and not (1.1 <= w / h <= 2.2):
                L.append(f"  - ✗ {title}: {w}x{h}（横長でない、または細長すぎる）")
                continue
            if not re.search(r"\.(jpe?g|png)(\?|$)", url, re.I):
                L.append(f"  - ✗ {title}: 拡張子が対象外 `{url[-40:]}`")
                continue
            got += 1
            name = f"{key}-{got}.jpg"
            try:
                req = urllib.request.Request(url, headers=UA)
                with urllib.request.urlopen(req, timeout=40) as r:
                    blob = r.read()
                open(f"{DIR}/{name}", "wb").write(blob)
            except Exception as e:
                got -= 1
                L.append(f"  - ✗ {title}: 取得失敗 {type(e).__name__}")
                continue
            ledger[name] = {"title": title, "lic": lic or "（表記なし）",
                            "artist": plain((meta.get("Artist") or {}).get("value"))[:80],
                            "page": "https://commons.wikimedia.org/wiki/"
                                    + urllib.parse.quote(title.replace(" ", "_")),
                            "size": [w, h], "bytes": len(blob)}
            L.append(f"  - ✅ `{name}` ← {title} / {w}x{h} / {lic} / "
                     f"{ledger[name]['artist'] or '作者不明'}")
        L.append("")
    if got == 0:
        L.append("**0 枚。** 検索語を変えて取り直す必要がある。")
    L.append("")

open(f"{DIR}/_tiles.json", "w", encoding="utf-8").write(
    json.dumps(ledger, ensure_ascii=False, indent=1))
L += ["", f"**取れた枚数: {len(ledger)}**"]
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:50]))
PYEOF
