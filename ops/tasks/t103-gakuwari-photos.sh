#!/bin/bash
# **記事の各節に入れる写真を取る（t103）。**
#
# t096 で 5 テーマ 15 枚 取れたが、使えたのは 3 テーマぶん。
#   - design: 検索が 0 件（`designer working laptop` は Commons に無い）
#   - train : 3 枚とも 1280x359 の線スキャン写真。**タイルに切ると帯にしかならない**
#   - cinema: 1934 年のモノクロと、天井だけの写真
# **細長すぎるものを弾く条件**（w/h の上限 2.2）を足し、検索語を変えて取り直す。
#
# t095 は 6 テーマすべてで「条件に合う画像が無かった」を返した。
# **どの段階で落ちたのかがレポートから分からない**ので、今回は
# **1 件ごとに落ちた理由を書き出す。** 条件も緩める（横長判定・最小幅）。
#
# 検索語も日本語と英語の両方を試す。Commons は説明文が英語のことが多いが、
# 日本の題材（新幹線・書店）は日本語のほうが当たる。
#
# **1 件目を無条件に採らない。** 選ぶのはクラウド側。
# **リサイズしない**（Mac に PIL がある保証が無い・最上位ルール 14）。
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t103-gakuwari-photos.md"
DIR="$RDIR/gakuwari-photos"
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
    ("macbook",  ["MacBook Air laptop", "MacBook laptop computer"]),
    ("ipad",     ["iPad tablet", "iPad Pro tablet"]),
    ("applestore", ["Apple Store interior", "Apple Store shop"]),
    ("park",     ["amusement park roller coaster", "theme park"]),
    ("gym",      ["fitness gym interior", "gym equipment room"]),
    ("karaoke",  ["karaoke room", "karaoke box interior"]),
]

def api(params):
    q = urllib.parse.urlencode({**params, "format": "json", "formatversion": "2"})
    req = urllib.request.Request(f"{API}?{q}", headers=UA)
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode("utf-8", "replace"))

def plain(v):
    return re.sub(r"<[^>]+>", " ", v or "").strip()

L = ["# 記事に入れる写真の候補（t103）", "",
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
