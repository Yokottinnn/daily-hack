#!/bin/bash
# IKEA豊洲の記事に使う素材を取る。**2026-09-03 オープンの新店**なので一次情報が薄い。
#
# 取るものは 4 つ。
#   A) 写真 … 公式店舗ページ＋プレスリリース2本（PR TIMES）
#   B) 店舗一覧 … 「商業施設内店舗 5 店舗目」の残り 4 つを特定する。
#      検索では 5 つ全部を列挙している記事が見つからなかった。**公式の一覧で確定させる**
#   C) YouTube … 「IKEA豊洲」で検索し、**oEmbed で題名と投稿者を照合**してから出す
#   D) ツイート … クラウド側の検索で拾った候補 5 件を syndication API で実在確認
#
# **写真もツイートも動画も、目で見るまで採用しない。**
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-ikea-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p ikea

"$PY" - "$RDIR" <<'PYEOF'
import io, json, re, sys, time, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}


def get(u, t=40):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")


def getb(u, t=40):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()


out = ["# IKEA豊洲の記事の素材（069）", "",
       "**2026-09-03 オープンの新店**。一次情報が薄いので、公式・プレスリリース・",
       "YouTube・X を横断して集める。", "",
       "**写真もツイートも動画も、目で見るまで採用しないこと。**", ""]

# ---- A) 写真 ---------------------------------------------------------------
BAD = re.compile(r"logo|icon|favicon|sprite|arrow|btn|sns|share|line_|twitter|insta"
                 r"|placeholder|noimage|spacer|blank", re.I)

SOURCES = [
    ("store", "IKEA豊洲 公式店舗ページ", "https://www.ikea.com/jp/ja/stores/toyosu/"),
    ("pr424", "プレスリリース（9/3オープン告知・424）",
     "https://prtimes.jp/main/html/rd/p/000000424.000065734.html"),
    ("pr414", "プレスリリース（9/3オープン告知・414）",
     "https://prtimes.jp/main/html/rd/p/000000414.000065734.html"),
    ("news1", "IKEA ニュースルーム（オープン日発表）",
     "https://www.ikea.com/jp/ja/newsroom/corporate-news/20260723-toyosu-opening-day-pub4c569400/"),
    ("news2", "IKEA ニュースルーム（初秋オープン発表）",
     "https://www.ikea.com/jp/ja/newsroom/corporate-news/20260331-toyosu-pubcd58d2c0/"),
    ("shibuya", "IKEA渋谷 公式店舗ページ", "https://www.ikea.com/jp/ja/stores/shibuya/"),
]

out += ["## A) 写真", ""]
seen, n = set(), 0
for key, label, url in SOURCES:
    out.append(f"  ### {label}")
    out.append(f"  `{url}`")
    try:
        html = get(url)
    except Exception as e:
        out.append(f"    - 取得できず（{type(e).__name__}）")
        time.sleep(1)
        continue
    cands = []
    m = re.search(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)', html, re.I)
    if m:
        cands.append(m.group(1))
    cands += re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
    for s in re.findall(r'srcset=["\']([^"\']+)["\']', html, re.I):
        cands.append(s.split(",")[-1].strip().split(" ")[0])
    cands += [x[1] for x in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
    got = 0
    for c in cands:
        if got >= 8:
            break
        if not re.search(r"\.(jpe?g|png|webp)(\?|$)", c, re.I) or BAD.search(c):
            continue
        full = urllib.parse.urljoin(url, c)
        if full in seen:
            continue
        seen.add(full)
        try:
            im = Image.open(io.BytesIO(getb(full))).convert("RGB")
        except Exception:
            continue
        if im.width < 500 or im.height < 320:
            continue
        px = im.resize((16, 16)).getdata()
        avg = sum(sum(p) for p in px) / (16 * 16 * 3)
        if avg < 26 or avg > 249:
            continue
        n += 1
        got += 1
        im.save(f"ikea/{key}-{got}.jpg", quality=92)
        im.resize((480, max(1, int(im.height * 480 / im.width)))).save(
            f"ikea/thumb-{key}-{got}.jpg", quality=74)
        big = "**大**" if im.width >= 900 else "小"
        out.append(f"    - `ikea/{key}-{got}.jpg` {im.width}x{im.height} {big}")
        out.append(f"      {full[:115]}")
    if got == 0:
        out.append("    - 使えそうな画像なし")
    out.append("")
    time.sleep(1)
out.append("")

# ---- B) 店舗一覧（商業施設内店舗を確定させる） -----------------------------
out += ["## B) 店舗一覧", "",
        "「IKEA豊洲は**商業施設内店舗の5店舗目**」と各社が書いているが、",
        "**残り4つを列挙している記事が見つからない。** 公式の一覧で確定させる。", ""]
for u in ("https://www.ikea.com/jp/ja/stores/",
          "https://www.ikea.com/jp/ja/this-is-ikea/about-us/about-ikea-japan-pub3c09f721/"):
    out.append(f"  ### `{u}`")
    try:
        h = get(u)
    except Exception as e:
        out.append(f"    - 取得できず（{type(e).__name__}）")
        time.sleep(1)
        continue
    # 店舗ページへのリンクを拾う
    slugs = sorted(set(re.findall(r'/jp/ja/stores/([a-z0-9\-]+)/', h)))
    out.append(f"    - 店舗スラッグ {len(slugs)} 件: {', '.join(slugs)}")
    # 本文から店舗数の記述を拾う
    txt = re.sub(r"(?is)<(script|style)[^>]*>.*?</\1>", " ", h)
    txt = re.sub(r"(?s)<[^>]+>", " ", txt)
    txt = re.sub(r"\s+", " ", txt)
    for m in re.finditer(r"[^。]{0,60}店舗[^。]{0,60}。", txt):
        s2 = m.group(0).strip()
        if re.search(r"\d", s2) and len(s2) < 160:
            out.append(f"    - 本文: {s2}")
    out.append("")
    time.sleep(1)

# ---- C) YouTube ------------------------------------------------------------
out += ["## C) YouTube", "",
        "**oEmbed で題名と投稿者を照合してから使う。** 検索結果の題名は当てにしない。", ""]


def yt_search(q, want=8):
    try:
        h = get("https://www.youtube.com/results?search_query=" + urllib.parse.quote(q)
                + "&sp=CAI%253D")  # 新しい順
    except Exception as e:
        return [], f"検索できず（{type(e).__name__}）"
    ids, seen_id = [], set()
    for m in re.finditer(r'"videoId":"([A-Za-z0-9_\-]{11})"', h):
        v = m.group(1)
        if v in seen_id:
            continue
        seen_id.add(v)
        ids.append(v)
        if len(ids) >= want:
            break
    return ids, None


for q in ("IKEA豊洲", "IKEA豊洲 店内", "イケア豊洲 オープン"):
    out.append(f"  ### 検索語 `{q}`")
    ids, err = yt_search(q)
    if err:
        out.append(f"    - {err}")
        time.sleep(2)
        continue
    if not ids:
        out.append("    - 動画が見つからなかった")
        time.sleep(2)
        continue
    for v in ids:
        try:
            d = json.loads(get("https://www.youtube.com/oembed?format=json&url="
                               + urllib.parse.quote(f"https://www.youtube.com/watch?v={v}", safe="")))
            out.append(f"    - `{v}` ／ **{d.get('title','?')}** ／ {d.get('author_name','?')}")
        except Exception:
            out.append(f"    - `{v}` ／ oEmbed が取れない（非公開・削除の可能性）")
        time.sleep(1)
    out.append("")
    time.sleep(2)

# ---- D) ツイートの実在確認 -------------------------------------------------
TWEETS = [
    ("2095845219145281668", "利用者が挙げた投稿（@azzzzzzusa）。中身は未確認"),
    ("2094764715297628277", "オリコンニュース／IKEA豊洲 9/3オープン・約600点"),
    ("2080234122883330111", "LifTe 北欧の暮らし／9/3オープン・プレオープンデー"),
    ("1858773844636692681", "IKEA渋谷のレストランがドリンクバーになった（@cune_cune_）"),
    ("2038837434839158792", "南砂一丁目（@minamisuna1）。中身は未確認"),
]
out += ["## D) ツイートの実在確認", "",
        "**埋め込む前に、本文・投稿者・日付が想定と合うかを目で見ること。**", ""]
for tid, memo in TWEETS:
    u = f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token=a"
    try:
        d = json.loads(get(u, t=25))
        txt = re.sub(r"\s+", " ", (d.get("text") or ""))[:220]
        au = (d.get("user") or {})
        photos = [p.get("url") for p in (d.get("photos") or []) if p.get("url")]
        out.append(f"  - `{tid}` ✅ **@{au.get('screen_name','?')}**"
                   f"（{au.get('name','?')}）／{(d.get('created_at') or '')[:10]}"
                   f"／画像{len(photos)}枚")
        out.append(f"    想定: {memo}")
        out.append(f"    実際: {txt}")
    except Exception as e:
        out.append(f"  - `{tid}` ❌ 取れず（{type(e).__name__}）／想定: {memo}")
    time.sleep(1)

open(f"{RDIR}/ikea-toyosu.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:2000])
PYEOF

BR="claude/ikea-toyosu"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f ikea >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: IKEA豊洲の記事の素材（069）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/ikea-toyosu.md / branch $BR"
