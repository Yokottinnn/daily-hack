#!/bin/bash
# 素材の 2 巡目。034/032 で埋まらなかったところを埋める。
#
# 分かったこと。
#  - X: 本文を確定できたのは 15 施設中 2 施設だけ（PARADISE / 高輪SAUNAS）。
#       DuckDuckGo への連続アクセスで絞られたと見て、間隔を空けて Bing も試す。
#  - YouTube: ID は取れたがタイトルが文字化けし、**対象施設の動画か確認できない。**
#       oEmbed で正しいタイトルと投稿者を取り、確認できたものだけ使う。
#  - 写真: 実写が取れたのは 3 施設（高輪 / 大井町 / BlueOcean）。残りの公式も当たる。
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
BRANCH="claude/sauna-material2"
WT="${TMPDIR:-/tmp}/dh-m2-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p tiles2

"$PY" - "$RDIR" <<'PYEOF'
import io, json, re, sys, time, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(url, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")

# ---------- (1) YouTube を oEmbed で確認 ----------
VIDS = {
  "paradise":  ["dq7wjtVeW-k", "KS_wUzvdyNg"],
  "takanawa":  ["nfMMu7p6Fas", "GS_Xebs6pTc"],
  "logout":    ["ycl2Od6sLg0"],
  "oimachi":   ["ya0eS3zP8rI", "N-5u-eMmuF0"],
  "mushimaki": ["1ajS68oQgGM"],
  "okaeri":    ["DBd_MUCJIJo"],
  "makuhari":  ["gNtxaP2v6_g", "3dGYy2QrdcI"],
  "blueocean": ["2wokj0M2nNs"],
  "koganeyu":  ["zZ3zGHbLVU0", "qGriOMgZKyY", "B4Li60IPwA4"],
  "kohaku":    ["M3GA5ultlg4"],
  "suien":     ["6K_LrbhB4ck"],
  "spaeas":    ["Hc_zaiUgpUg", "ItLpakuX44o"],
  "kaizoku":   ["v8KMez9ssNw", "M1NHFK1h3QA"],
  "monnaka":   ["EjikwlS7I8M", "4pExbGCZt-E"],
}
out = ["# YouTube の確認（oEmbed）", "",
       "**タイトルと投稿者が取れたものだけが使える候補。** 対象施設と関係ない動画は使わない。", "",
       "| キー | videoId | タイトル | 投稿者 |", "| --- | --- | --- | --- |"]
for key, ids in VIDS.items():
    for vid in ids:
        try:
            d = json.loads(get("https://www.youtube.com/oembed?format=json&url="
                               + urllib.parse.quote(f"https://www.youtube.com/watch?v={vid}", safe="")))
            out.append(f"| `{key}` | `{vid}` | {d.get('title','')[:70]} | {d.get('author_name','')[:30]} |")
        except Exception as e:
            out.append(f"| `{key}` | `{vid}` | 取得できず（{type(e).__name__}） | — |")
        time.sleep(1)
out.append("")

# ---------- (2) X をもう一度 ----------
NEED = [
  ("oimachi",   "サウナメッツァ大井町"),
  ("koganeyu",  "黄金湯 新宿"),
  ("blueocean", "BlueOcean 新横浜 サウナ"),
  ("makuhari",  "毎日サウナ東京 幕張"),
  ("monnaka",   "門仲SAUNAS"),
  ("suien",     "水宴 麻布十番"),
  ("spaeas",    "SPA EAS 横浜"),
  ("kaizoku",   "海賊サウナ 小田原"),
  ("kohaku",    "sauna KOHAKU 柏"),
  ("shiagaru",  "SHIAGARU SAUNA 神田"),
  ("okaeri",    "おかえりサウナ 板橋"),
  ("logout",    "荒木町 Logout サウナ"),
  ("mushimaki", "サウナ蒸薪"),
]
def tweet(tid):
    try:
        d = json.loads(get(f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token=a"))
    except Exception:
        return None
    t = (d.get("text") or "").strip(); u = d.get("user") or {}
    if not t or not u.get("screen_name"): return None
    return {"id": tid, "text": t, "name": u.get("name"), "handle": u.get("screen_name"),
            "created": (d.get("created_at") or "")[:10]}

def find_status(q):
    ids, seen = [], set()
    for engine in ("https://html.duckduckgo.com/html/?q=", "https://lite.duckduckgo.com/lite/?q=",
                   "https://www.bing.com/search?q="):
        try:
            html = get(engine + urllib.parse.quote(q))
        except Exception:
            continue
        for m in re.findall(r"(?:x|twitter)\.com/[^/\s\"']+/status/(\d{15,25})", urllib.parse.unquote(html)):
            if m not in seen:
                seen.add(m); ids.append(m)
        if ids: break
        time.sleep(4)
    return ids

out += ["# X の実投稿（2 巡目）", ""]
for key, q in NEED:
    out.append(f"## {key} — `{q}`")
    got = 0
    for tid in find_status(f"site:x.com {q}")[:6]:
        t = tweet(tid)
        if not t: continue
        got += 1
        out += [f"- `https://x.com/{t['handle']}/status/{t['id']}` / {t['name']} (@{t['handle']}) / {t['created']}",
                "  ```", "  " + t["text"].replace("\n", "\n  ")[:500], "  ```"]
        if got >= 2: break
        time.sleep(1)
    if got == 0:
        out.append("- 見つからなかった")
    out.append("")
    time.sleep(6)

open(f"{RDIR}/sauna-material2.md", "w", encoding="utf-8").write("\n".join(out) + "\n")

# ---------- (3) 残りの施設写真 ----------
SITES = [
  ("paradise",  ["https://paradise-tokyo.com/otemachi/", "https://spaworks.jp/article/7704"]),
  ("makuhari",  ["https://sauna-tokyo.jp/makuhari/", "https://sauna-tokyo.jp/"]),
  ("koganeyu",  ["https://koganeyu.com/shinjuku/", "https://koganeyu.com/"]),
  ("monnaka",   ["https://lo.saunas-saunas.com/monnaka/"]),
  ("spaeas",    ["https://www.spa-eas.com/"]),
  ("kaizoku",   ["https://kaizoku-sauna.com/"]),
  ("suien",     ["https://suien-sauna.com/"]),
  ("kohaku",    ["https://sauna-kohaku.com/"]),
]
BAD = re.compile(r"logo|icon|favicon|sprite|banner|ogp|og-|placeholder|noimage|footer|header|arrow|btn", re.I)
log = ["", "# 追加の施設写真", "", "| キー | 保存名 | 大きさ | 元 |", "| --- | --- | --- | --- |"]
for key, pages in SITES:
    urls, seen = [], set()
    for p in pages:
        try: html = get(p)
        except Exception: continue
        c = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
        c += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
        for u in c:
            if not re.search(r"\.(jpe?g|png|webp)(\?|$)", u, re.I): continue
            if BAD.search(u): continue
            full = urllib.parse.urljoin(p, u)
            if full not in seen: seen.add(full); urls.append(full)
    n = 0
    for u in urls:
        if n >= 2: break
        try:
            im = Image.open(io.BytesIO(urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=30).read())).convert("RGB")
        except Exception: continue
        w, h = im.size
        if w < 640 or h < 360 or w/h < 1.1: continue
        n += 1
        im.save(f"tiles2/{key}-{n}.jpg", quality=92)
        im.resize((480, max(1, int(h*480/w)))).save(f"tiles2/thumb-{key}-{n}.jpg", quality=72)
        log.append(f"| `{key}` | `{key}-{n}.jpg` | {w}x{h} | {u[:80]} |")
    if n == 0: log.append(f"| `{key}` | — | — | 見つからず |")
open(f"{RDIR}/sauna-material2.md", "a", encoding="utf-8").write("\n".join(log) + "\n")
print("\n".join(log[3:]))
PYEOF

git -C "$WT" add -A tiles2 2>/dev/null
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "wip: 施設写真の 2 巡目（レビュー用）" 2>/dev/null || true
git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" 2>/dev/null || true
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/sauna-material2.md を書き出した"
