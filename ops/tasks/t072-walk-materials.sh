#!/bin/bash
# **「歩いてポイ活 2026」の素材を取る。YouTube・X・写真をまとめて。**
#
# クラウドセッションは egress が塞がれているので、外から取るものは全部ここで取る。
#
#   A) YouTube … 検索結果から videoId を拾い、**oEmbed で題名と投稿者を照合する**
#                 （スクレイプした題名は文字化けするので信じない。スキル §2 の実例）
#   B) X ……… DuckDuckGo の HTML 版で `x.com/*/status/*` を拾い、
#                 **cdn.syndication で本文・投稿者・日付を確定させる**
#   C) 写真 …… Wikimedia Commons から歩行・歩数計・スマホの写真を候補として落とす
#
# **採用はしない。候補を出すだけ。** 題名と本文を見てから選ぶ。
#
# 出力: `$OPS_REPORT_DIR/t072-walk-materials.md` と `$OPS_REPORT_DIR/walk-photos/`
# **秘密は出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの取得タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
DEST="$RDIR/walk-photos"
OUT="$RDIR/t072-walk-materials.md"
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
L = ["# 歩いてポイ活 2026 の素材候補（t072）", "",
     "**採用していない。候補を出しただけ。**", ""]

def get(url, binary=False, timeout=30, headers=None):
    req = urllib.request.Request(url, headers=headers or UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read() if binary else r.read().decode("utf-8", "replace")

# ── A) YouTube ────────────────────────────────────────────────
L.append("## A) YouTube 候補（oEmbed で題名を照合済み）")
L.append("")
YT_Q = [
    "ANA Pocket 検証 マイル",
    "JAL Wellness Travel 歩いてマイル",
    "歩いてポイ活 アプリ 比較",
    "トリマ ポイ活 検証",
    "BitWalk ビットウォーク 歩いて ビットコイン",
    "HEALTHREE ヘルスリー 始め方",
]
seen_v = set()
for q in YT_Q:
    L.append(f"### 「{q}」")
    try:
        html = get("https://www.youtube.com/results?search_query=" + urllib.parse.quote(q))
    except Exception as e:
        L.append(f"- ❌ 検索失敗 {type(e).__name__}: {str(e)[:120]}")
        L.append("")
        continue
    ids = []
    for m in re.finditer(r'"videoId":"([A-Za-z0-9_-]{11})"', html):
        v = m.group(1)
        if v not in seen_v and v not in ids:
            ids.append(v)
        if len(ids) >= 5:
            break
    if not ids:
        L.append("- 候補が取れなかった")
        L.append("")
        continue
    for v in ids:
        seen_v.add(v)
        try:
            d = json.loads(get("https://www.youtube.com/oembed?format=json&url="
                               + urllib.parse.quote(f"https://www.youtube.com/watch?v={v}", safe="")))
            L.append(f"- ✅ `{v}` … **{d.get('title','?')}** ／ {d.get('author_name','?')}")
        except Exception as e:
            L.append(f"- ❌ `{v}` … oEmbed で取れない（{type(e).__name__}）＝非公開か削除済み")
        time.sleep(0.3)
    L.append("")

# ── B) X ──────────────────────────────────────────────────────
L.append("## B) X の実投稿候補（syndication で本文を確定済み）")
L.append("")
X_Q = [
    "ANA Pocket マイル 貯まった",
    "JAL Wellness Travel マイル 歩いて",
    "トリマ 交換 ポイ活",
    "BitWalk ビットコイン 歩いて",
    "歩いてポイ活 アプリ おすすめ",
    "ヘルスリー HEALTHREE 歩いて",
]
seen_t = set()
for q in X_Q:
    L.append(f"### 「{q}」")
    ids = []
    for engine in ("https://html.duckduckgo.com/html/?q=",
                   "https://lite.duckduckgo.com/lite/?q="):
        if len(ids) >= 4:
            break
        try:
            html = get(engine + urllib.parse.quote(f"site:x.com {q}"))
        except Exception as e:
            L.append(f"- 検索失敗（{engine.split('/')[2]}）: {type(e).__name__}")
            continue
        for m in re.finditer(r'(?:x|twitter)\.com(?:%2F|/)[A-Za-z0-9_]{1,15}(?:%2F|/)status(?:%2F|/)(\d{15,25})', html):
            t = m.group(1)
            if t not in seen_t and t not in ids:
                ids.append(t)
            if len(ids) >= 4:
                break
        time.sleep(0.5)
    if not ids:
        L.append("- 候補が取れなかった")
        L.append("")
        continue
    for t in ids:
        seen_t.add(t)
        try:
            d = json.loads(get(f"https://cdn.syndication.twimg.com/tweet-result?id={t}&lang=ja&token=a"))
            u = d.get("user") or {}
            txt = (d.get("text") or "").replace("\n", " ")
            L.append(f"- ✅ `{t}` … **@{u.get('screen_name','?')}（{u.get('name','?')}）** "
                     f"／ {(d.get('created_at') or '?')[:10]}")
            L.append(f"  - 本文: {txt[:220]}")
        except Exception as e:
            L.append(f"- ❌ `{t}` … 取れない（{type(e).__name__}）＝削除済みか非公開")
        time.sleep(0.4)
    L.append("")

# ── C) 写真 ───────────────────────────────────────────────────
L.append("## C) Wikimedia Commons の写真候補")
L.append("")
API = "https://commons.wikimedia.org/w/api.php"
NG = re.compile(r"\.svg$|logo|icon|diagram|chart|map|coat of arms|painting|engraving", re.I)
PH_Q = [
    ("walking", "people walking city street Japan"),
    ("smartphone", "person using smartphone walking"),
    ("pedometer", "pedometer step counter"),
    ("smartwatch", "smartwatch fitness tracker wrist"),
    ("commute", "Tokyo commuters walking station"),
    ("running", "jogging park morning"),
]
man = []
for key, q in PH_Q:
    got = 0
    try:
        u = (API + "?action=query&format=json&generator=search&gsrnamespace=6"
             "&gsrlimit=12&gsrsearch=" + urllib.parse.quote(q)
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
        if w < 900 or h < 500 or w / max(h, 1) > 3.0:
            continue
        meta = ii.get("extmetadata") or {}
        lic = (meta.get("LicenseShortName") or {}).get("value", "?")
        art = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "?"))[:60]
        url = ii.get("thumburl") or ii.get("url")
        try:
            b = get(url, binary=True, timeout=30)
        except Exception:
            continue
        if len(b) < 30000:
            continue
        got += 1
        name = f"{key}-{got}.jpg"
        with open(os.path.join(DEST, name), "wb") as f:
            f.write(b)
        page = "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(title)
        man.append({"file": name, "title": title, "lic": lic, "artist": art,
                    "page": page, "size": f"{w}x{h}"})
        L.append(f"- ✅ `{name}` … {title} / {lic} / {art} / {w}x{h}")
    time.sleep(0.3)

with open(os.path.join(DEST, "_sources.json"), "w") as f:
    json.dump(man, f, ensure_ascii=False, indent=2)

L += ["", f"## 合計：写真 {len(man)} 枚"]
with open(OUT, "w") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L[:60]))
print(f"... 全文は {OUT}")
PYEOF

echo "=== 落とした写真 ==="
ls -la "$DEST" 2>/dev/null | head -30
exit 0
