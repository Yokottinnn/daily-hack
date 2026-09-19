#!/bin/bash
# **表紙のタイル用に、学割で使えるものの写真を Wikimedia Commons から取る。**
#
# 利用者の指摘（2026-09-20・下書きフィードバック）:
#   「表紙の画像がダサすぎる。学割でできるものを調べて、6分割タイルにして
#     背景画像に使って。他の記事見ればわかるよね」
#   「画像の選科履修生みたいな囲んでいるところはいらない。冗長」
#
# blog-article スキルの標準形は **全面タイル ＋ 透過オーバーレイ**
# （`scripts/gen-mosaic-hero.py`）。**6 枚そろわないと合成しない。**
#
# ## なぜ Mac に投げるか
#
# クラウドは upload.wikimedia.org に出られない。**取ってくるところだけ** Mac にやらせる。
#
# ## 落とすもの
#
#   reports/gakuwari-tiles/<key>-<n>.jpg   候補（各テーマ 3 枚まで）
#   reports/gakuwari-tiles/_tiles.json     題名・ライセンス・作者・元ページの台帳
#
# **1 件目を無条件に採らない。** 選ぶのはクラウド側（スキル「候補は見て選ぶ」）。
# **リサイズしない。** Mac に PIL がある保証が無い（最上位ルール 14）。
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t095-gakuwari-tiles.md"
DIR="$RDIR/gakuwari-tiles"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, json, re, sys, time, urllib.parse, urllib.request, urllib.error

OUT, DIR = sys.argv[1], sys.argv[2]
BUDGET = 220.0
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "daily-hack-ops/1.0 (https://daily-hack.fieldbeside.com/)"}

# **学割が実際に効くもの**を 6 テーマ。タイルは別々の題材にする（スキル）。
THEMES = [
    ("cinema",  "movie theater auditorium seats"),
    ("design",  "graphic design work laptop desk"),
    ("music",   "headphones listening music person"),
    ("train",   "Shinkansen N700S station platform"),
    ("museum",  "art museum gallery visitors exhibition"),
    ("books",   "bookstore bookshelves interior"),
]

def api(params):
    q = urllib.parse.urlencode({**params, "format": "json", "formatversion": "2"})
    req = urllib.request.Request(f"{API}?{q}", headers=UA)
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode("utf-8", "replace"))

def plain(v):
    return re.sub(r"<[^>]+>", "", v or "").strip()

L = ["# 表紙タイルの候補（t095・Wikimedia Commons）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**1 件目を無条件に採らない。** 目で見て選ぶ。", ""]
ledger, t0 = {}, time.time()

for key, term in THEMES:
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** `{key}` 以降は次のタスクで。")
        break
    L += [f"## {key}", "", f"検索語: `{term}`", ""]
    try:
        d = api({"action": "query", "generator": "search", "gsrsearch": term,
                 "gsrnamespace": "6", "gsrlimit": "10", "prop": "imageinfo",
                 "iiprop": "url|size|extmetadata", "iiurlwidth": "900"})
    except Exception as e:
        L += [f"❌ {type(e).__name__}: {str(e)[:140]}", ""]
        continue
    pages = (d.get("query") or {}).get("pages") or []
    n = 0
    for p in pages:
        if n >= 3:
            break
        ii = (p.get("imageinfo") or [{}])[0]
        meta = ii.get("extmetadata") or {}
        lic = plain((meta.get("LicenseShortName") or {}).get("value"))
        # **非フリーは弾く。**
        if not lic or "fair use" in lic.lower() or "non-free" in lic.lower():
            continue
        w, h = ii.get("width") or 0, ii.get("height") or 0
        if w < 900 or w <= h:          # 横長で使えるものだけ（1600x900 に切る）
            continue
        url = ii.get("thumburl") or ii.get("url")
        if not url or not re.search(r"\.(jpe?g|png)$", url, re.I):
            continue
        n += 1
        name = f"{key}-{n}.jpg"
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=40) as r:
                open(f"{DIR}/{name}", "wb").write(r.read())
        except Exception as e:
            L.append(f"- {name}: ❌ {type(e).__name__}")
            continue
        ledger[name] = {
            "title": p.get("title"), "lic": lic,
            "artist": plain((meta.get("Artist") or {}).get("value"))[:80],
            "page": f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(p.get('title',''))}",
            "size": [w, h],
        }
        L.append(f"- `{name}` {w}x{h} / {lic} / {ledger[name]['artist'] or '作者不明'}")
        L.append(f"  - {ledger[name]['page']}")
    if n == 0:
        L.append("（条件に合う画像が無かった。検索語を変えて取り直す）")
    L.append("")

open(f"{DIR}/_tiles.json", "w", encoding="utf-8").write(
    json.dumps(ledger, ensure_ascii=False, indent=1))
L += ["", f"**取れた枚数: {len(ledger)}**（6 テーマ × 最大 3）"]
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:40]))
PYEOF
