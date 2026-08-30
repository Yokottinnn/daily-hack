#!/bin/bash
# サウナ記事の穴を埋める素材を取る（044）。**公式 URL を先に探してから当たる。**
#
# 現状の穴（2026-08-30 時点、17 施設中）。
#   写真なし 9 / 料金 未確認 10 / 営業時間の記載 2 施設だけ
#
# 035・036 は公式 URL を決め打ちして 6 件が URLError / HTTPError で落ちた。
# **今回は検索でドメインを見つけてから取りに行く。** 見つからなければ「見つからず」と書く。
# まとめサイトは出典にしない（探すためだけに使う）。
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
BRANCH="claude/sauna-gaps"
WT="${TMPDIR:-/tmp}/dh-gaps-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p gaps

"$PY" - "$RDIR" <<'PYEOF'
import io, re, sys, time, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(url, timeout=30):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")

JP = re.compile(r"[ぁ-んァ-ヶ一-龠]")
KEY = re.compile(r"料金|入館|入浴|営業時間|定休|受付|男性|女性|男女|レディース|サウナ室|水風呂|"
                 r"ロウリュ|外気浴|℃|度|円|分|時")

def digest(html, limit=90):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;"," "),("&amp;","&"),("&quot;",'"'),("&#039;","'"),("&yen;","¥")):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or l in seen or len(l) > 140 or len(l) < 3: continue
        if not (JP.search(l) and KEY.search(l)): continue
        seen.add(l); out.append(l)
    return out[:limit]

# 施設名 → 検索語。**公式のドメインは決め打ちしない。**
NEED = [
  ("araki",     "荒木町サウナ Logout",        "荒木町サウナ Logout 四谷三丁目 料金"),
  ("shiagaru",  "SHIAGARU SAUNA 神田×秋葉原", "SHIAGARU SAUNA 神田 秋葉原 料金 公式"),
  ("kiki",      "SAUNA汽汽",                 "SAUNA汽汽 中目黒 料金 公式"),
  ("mushimaki", "サウナ蒸薪",                 "サウナ蒸薪 北本 料金 公式"),
  ("okaeri",    "おかえりサウナ板橋",           "おかえりサウナ板橋 料金 公式"),
  ("makuhari",  "毎日サウナ東京 幕張店",         "毎日サウナ東京 幕張店 料金 営業時間 公式"),
  ("koganeyu",  "黄金湯 新宿",                "黄金湯 新宿 料金 営業時間 公式"),
  ("suien",     "水宴 -suien-",              "水宴 麻布十番 サウナ 料金 公式"),
  ("kaizoku",   "海賊サウナ＆カプセルホテル",     "海賊サウナ 小田原 料金 公式"),
  ("spaeas",    "横浜天然温泉 SPA EAS",       "SPA EAS 横浜 入館料 営業時間"),
  ("kohaku",    "sauna KOHAKU",              "sauna KOHAKU 柏 料金 公式"),
  ("monnaka",   "門仲SAUNAS LO",             "門仲SAUNAS LO 料金 公式"),
]

# 公式でないと分かっているドメインは候補から外す
DENY = re.compile(r"(sauna-ikitai|onsen\.nifty|tabelog|jalan|rurubu|retty|hotpepper|instagram|"
                  r"twitter|x\.com|facebook|youtube|note\.com|ameblo|hatena|prtimes|"
                  r"supersento|spaworks|timeout|asoview|goguynet|keizai\.biz)", re.I)

def find_official(q):
    urls, seen = [], set()
    for engine in ("https://html.duckduckgo.com/html/?q=",
                   "https://lite.duckduckgo.com/lite/?q=",
                   "https://www.bing.com/search?q="):
        try:
            html = get(engine + urllib.parse.quote(q))
        except Exception:
            continue
        raw = urllib.parse.unquote(html)
        for m in re.findall(r'https?://([a-z0-9.-]+\.[a-z]{2,})(/[^\s"\'<>]*)?', raw, re.I):
            host, path = m[0], m[1] or "/"
            if DENY.search(host) or "duckduckgo" in host or "bing" in host or "microsoft" in host:
                continue
            u = f"https://{host}{path}"
            if u in seen: continue
            seen.add(u); urls.append(u)
        if urls: break
        time.sleep(4)
    return urls[:6]

BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner", re.I)
out = ["# サウナ記事の穴埋め素材（公式 URL を検索で見つけてから取得）", "",
       "**「見つからず」と書いてあるものは、推測で埋めないこと。**", ""]

for key, label, q in NEED:
    out += [f"## {key} — {label}", "", f"検索語: `{q}`", ""]
    cands = find_official(q)
    if not cands:
        out += ["- **検索でドメインが見つからなかった。**", ""]
        time.sleep(5); continue
    got = 0; nimg = 0
    for u in cands:
        if got >= 2: break
        try:
            html = get(u)
        except Exception as e:
            out.append(f"- `{u[:90]}` 取得できず（{type(e).__name__}）")
            continue
        d = digest(html)
        if not d:
            out.append(f"- `{u[:90]}` 日本語の料金/営業の記述が拾えなかった（JS 描画の可能性）")
            continue
        got += 1
        out += [f"### `{u[:110]}`", "", "```"] + d + ["```", ""]
        # 写真も 1 枚だけ
        if nimg < 1:
            cs = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
            cs += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
            for c in cs:
                if not re.search(r"\.(jpe?g|png|webp)(\?|$)", c, re.I) or BAD.search(c): continue
                full = urllib.parse.urljoin(u, c)
                try:
                    im = Image.open(io.BytesIO(urllib.request.urlopen(
                        urllib.request.Request(full, headers=UA), timeout=30).read())).convert("RGB")
                except Exception:
                    continue
                w, h = im.size
                if w < 640 or h < 360 or w / h < 1.1: continue
                nimg += 1
                im.save(f"gaps/{key}.jpg", quality=92)
                im.resize((480, max(1, int(h * 480 / w)))).save(f"gaps/thumb-{key}.jpg", quality=72)
                out.append(f"- 写真 `gaps/{key}.jpg` {w}x{h} ← {full[:100]}")
                break
        time.sleep(2)
    if got == 0:
        out.append("- **どの候補からも中身が取れなかった。**")
    out.append("")
    time.sleep(6)

open(f"{RDIR}/sauna-gaps.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("sauna-gaps.md を書き出した")
PYEOF

git -C "$WT" add -A gaps 2>/dev/null
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "wip: サウナ記事の穴埋め素材（レビュー用）" 2>/dev/null || true
git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" 2>/dev/null || true
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/sauna-gaps.md / branch $BRANCH"
