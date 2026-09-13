#!/bin/bash
# **t072 の取り直し。写真が全滅、X が 4 キーワードで 0 件だった。**
#
# ## t072 で何が起きたか
#
# **写真 14 枚のうち、使えるものが 1 枚も無かった。**
#
#   walking-1/2, pedometer-1/2, commute-1/2/3 … **`File:….pdf`＝スキャンした書籍のページ**
#   smartphone-1/2/3 …………………………… フィリピンの町の写真。歩数計とは無関係
#   running-1 ……………………………………… 三輪車を押す親子
#
# 除外条件が `\.svg$` しか無く、**PDF を弾いていなかった。**
# しかも縦長（1050x1562 など）ばかりで、1600x900 のタイルに使えない。
#
# **X は「トリマ」以降の 4 キーワードが全部 0 件。** DuckDuckGo の HTML 版が
# `site:x.com` を返さなくなっている。
#
# ## 直し方
#
#   写真 … **`.pdf` を弾く ＋ 横長だけ（w > h）＋ 1200px 以上**に絞る。
#           検索語も「日本の街を歩く人」「スマートウォッチ」など具体に変える
#   X …… **検索はこちら（クラウド側）で済ませた。** ID を直接 渡すので、
#           `cdn.syndication` で本文・投稿者・日付を確定させるだけでよい
#
# 出力: `$OPS_REPORT_DIR/t073-walk-materials2.md` と `$OPS_REPORT_DIR/walk-photos2/`
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの取得タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
DEST="$RDIR/walk-photos2"
OUT="$RDIR/t073-walk-materials2.md"
mkdir -p "$DEST"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

"$PY" - "$DEST" "$OUT" <<'PYEOF'
import json, os, re, sys, time, urllib.parse, urllib.request

DEST, OUT = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}
L = ["# 歩いてポイ活の素材（t073 / 取り直し）", "", "**採用していない。候補。**", ""]

def get(url, binary=False, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read() if binary else r.read().decode("utf-8", "replace")

# ── A) X（ID は確定済み。本文を取るだけ）─────────────────────
L.append("## A) X の投稿（本文を確定させる）")
L.append("")
TWEETS = [
    ("トリマ／交換できない",   "1953771611863363895"),
    ("トリマ／その後",         "1956536976016044450"),
    ("トリマ／同じ目にあった", "1954102507212280093"),
    ("BitWalk／CM の試算",     "1864687085464215895"),
    ("BitWalk／公式の不具合",  "2053712444628041884"),
    ("BitWalk／動画エラー",    "1943322023851364832"),
    ("HEAL3／交換レート変更",  "1932962387868721439"),
    ("HEAL3／無料で稼げる",    "1937717469248127110"),
    ("楽天ヘルスケア／公式",   "1939883200026927577"),
]
for label, tid in TWEETS:
    try:
        d = json.loads(get(f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token=a"))
        u = d.get("user") or {}
        txt = (d.get("text") or "").replace("\n", " ")
        L.append(f"### {label} — `{tid}`")
        L.append(f"- **@{u.get('screen_name','?')}（{u.get('name','?')}）** ／ {(d.get('created_at') or '?')[:10]}")
        L.append(f"- 本文: {txt[:400]}")
    except Exception as e:
        L.append(f"### {label} — `{tid}`")
        L.append(f"- ❌ **取れない**（{type(e).__name__}）＝削除済みか非公開。使わない")
    L.append("")
    time.sleep(0.4)

# ── B) 写真（PDF を弾き、横長だけ）────────────────────────────
L.append("## B) Commons の写真（横長・PDF 除外）")
L.append("")
API = "https://commons.wikimedia.org/w/api.php"
# **`.pdf` と `.svg` を必ず弾く。** t072 は 7 枚が書籍のスキャンだった。
NG = re.compile(r"\.(svg|pdf|tif|tiff|djvu|webm|ogv)$|logo|icon|diagram|chart|"
                r"\bmap\b|coat of arms|painting|engraving|woodcut|poster|"
                r"screenshot|graph", re.I)
PH_Q = [
    ("street",     "pedestrians walking Tokyo street daytime"),
    ("crossing",   "Shibuya crossing pedestrians"),
    ("smartwatch", "smartwatch on wrist fitness"),
    ("shoes",      "walking shoes sidewalk feet"),
    ("park",       "people walking park path"),
    ("phone",      "hand holding smartphone outdoors"),
    ("bitcoin",    "bitcoin physical coin"),
    ("airplane",   "airliner wing sky window"),
]
man = []
for key, q in PH_Q:
    got = 0
    try:
        u = (API + "?action=query&format=json&generator=search&gsrnamespace=6"
             "&gsrlimit=20&gsrsearch=" + urllib.parse.quote(q)
             + "&prop=imageinfo&iiprop=url|size|extmetadata&iiurlwidth=1600")
        d = json.loads(get(u))
    except Exception as e:
        L.append(f"- 「{q}」検索失敗: {type(e).__name__}")
        continue
    pages = ((d.get("query") or {}).get("pages") or {})
    for _, p in pages.items():
        if got >= 3:
            break
        title = p.get("title", "")
        if NG.search(title):
            continue
        ii = (p.get("imageinfo") or [{}])[0]
        w, h = ii.get("width", 0), ii.get("height", 0)
        # **横長だけ。** タイルは 1600x900 に切るので、縦長は使えない
        if w < 1200 or h < 600 or w <= h or w / max(h, 1) > 2.6:
            continue
        meta = ii.get("extmetadata") or {}
        lic = (meta.get("LicenseShortName") or {}).get("value", "?")
        art = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "?"))[:60]
        url = ii.get("thumburl") or ii.get("url")
        try:
            b = get(url, binary=True, timeout=30)
        except Exception:
            continue
        if len(b) < 40000 or b[:2] != b"\xff\xd8" and b[:4] != b"\x89PNG":
            continue
        got += 1
        name = f"{key}-{got}.jpg"
        with open(os.path.join(DEST, name), "wb") as f:
            f.write(b)
        page = "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(title)
        man.append({"file": name, "title": title, "lic": lic, "artist": art,
                    "page": page, "size": f"{w}x{h}"})
        L.append(f"- ✅ `{name}` … {title} / {lic} / {art} / **{w}x{h}**")
    if got == 0:
        L.append(f"- 「{q}」… 条件に合うものが無かった")
    time.sleep(0.3)

with open(os.path.join(DEST, "_sources.json"), "w") as f:
    json.dump(man, f, ensure_ascii=False, indent=2)

L += ["", f"## 写真 {len(man)} 枚（すべて横長・1200px 以上）"]
with open(OUT, "w") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF

echo "=== 落とした写真 ==="
ls -la "$DEST" 2>/dev/null | head -30
exit 0
