#!/bin/bash
# モスバーガーの朝モスを、諦めずに取り直す。**065〜067 の3回は探し方が悪かった。**
#
# 公式のメニュー一覧（`mos.jp/menu/category/?c_id=12`）だけを見ていたため、
# 出てくるのがブランド紹介・コーヒーチケットの販促バナー・ポテトとアイスティーばかりで
# 「朝モスの写真は公開されていない」と結論づけた。**間違い。**
#
#   - **プレスリリース**（PR TIMES）に商品写真と金額がある
#     朝の野菜バーガー 390円／ドリンクセット 540円（2026-03-18 リニューアル）
#   - **ネット注文サイト**（netorder.mos.co.jp）に品目ごとの写真がある
#
# スキルに「公式から取れないときはプレスリリースを見る」と書いてあるのに、
# それをやっていなかった。
#
# もう1つやること: **ツイートIDの実在確認。**
# 記事に埋め込む前に本文・投稿者・日付を突き合わせる。当て推量で埋め込まない。
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-mos-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p m7

"$PY" - "$RDIR" <<'PYEOF'
import io, json, re, sys, time, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}


def get(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")


def getb(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()


out = ["# モスの朝モスと、ツイートの実在確認（068）", "",
       "**065〜067 の3回は探し方が悪かった。** 公式のメニュー一覧だけを見ていたため、",
       "ブランド紹介・コーヒーチケットの販促バナー・ポテトとアイスティーしか取れず、",
       "「朝モスの写真は公開されていない」と誤って結論づけていた。", "",
       "スキルに**「公式から取れないときはプレスリリースを見る」**と書いてあるのに",
       "やっていなかった。今回はプレスリリースとネット注文サイトを見る。", ""]

# ---- A) モスの写真 ---------------------------------------------------------
BAD = re.compile(r"logo|icon|favicon|sprite|arrow|btn|sns|share|line_|twitter|insta"
                 r"|ticket|banner|bnr", re.I)

SOURCES = [
    ("pr", "プレスリリース（2026-03-18 朝モス リニューアル）",
     "https://prtimes.jp/main/html/rd/p/000000558.000075449.html"),
    ("net", "ネット注文（朝モス）", "https://netorder.mos.co.jp/pc/morning_menu"),
    ("netb", "ネット注文（朝モス バーガー類）", "https://netorder.mos.co.jp/pc/morning_burger_menu"),
    ("cat", "公式メニュー（朝モス）", "https://www.mos.jp/menu/category/?c_id=12"),
]

out += ["## A) モスバーガーの写真", ""]
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
    cands += [x[1] for x in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
    got = 0
    for c in cands:
        if got >= 6:
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
        if im.width < 380 or im.height < 240:
            continue
        px = im.resize((16, 16)).getdata()
        avg = sum(sum(p) for p in px) / (16 * 16 * 3)
        if avg < 26 or avg > 249:
            continue
        n += 1
        got += 1
        im.save(f"m7/mos-{n}.jpg", quality=92)
        im.resize((480, max(1, int(im.height * 480 / im.width)))).save(
            f"m7/thumb-mos-{n}.jpg", quality=74)
        big = "**大**" if im.width >= 900 else "小"
        out.append(f"    - `m7/mos-{n}.jpg` {im.width}x{im.height} {big}")
        out.append(f"      {full[:115]}")
    if got == 0:
        out.append("    - 使えそうな画像なし")
    out.append("")
    time.sleep(1)

if n == 0:
    out.append("  **1枚も取れなかった。**")
out.append("")

# ---- B) ツイートの実在確認 -------------------------------------------------
# **記事に埋め込む前に必ず通す。** 本文・投稿者・日付が想定と合うかを人が見る。
TWEETS = [
    ("2038738099795300833", "朝モス お得に／一部店舗では取り扱いなし"),
    ("1934755400160825745", "いつものなんでもない朝をちょっと特別に『朝モス』"),
    ("2043645420556214750", "明日は早起きして朝モスを食べる予定です"),
    ("1961202201411686730", "朝なのにもう暑い／朝モスで気分を切り替えて"),
]

out += ["## B) ツイートの実在確認", "",
        "**埋め込む前に、本文・投稿者・日付が想定と合うかを目で見ること。**", ""]
for tid, memo in TWEETS:
    u = f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token=a"
    try:
        d = json.loads(get(u, t=25))
        txt = re.sub(r"\s+", " ", (d.get("text") or ""))[:180]
        au = (d.get("user") or {})
        out.append(f"  - `{tid}` ✅ **@{au.get('screen_name','?')}**"
                   f"（{au.get('name','?')}）／{(d.get('created_at') or '')[:10]}")
        out.append(f"    想定: {memo}")
        out.append(f"    実際: {txt}")
    except Exception as e:
        out.append(f"  - `{tid}` ❌ 取れず（{type(e).__name__}）／想定: {memo}")
    time.sleep(1)

open(f"{RDIR}/mos-and-tweets.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1800])
PYEOF

BR="claude/mos-and-tweets"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f m7 >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: モスの朝モスとツイートの実在確認（068）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/mos-and-tweets.md / branch $BR"
