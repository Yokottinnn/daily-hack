#!/bin/bash
# 「500円で食べられるモーニング」の素材を各チェーンの公式から取る。
#
# 起点: https://x.com/ny_ai2/status/2093813441941119116
#   「たった500円 コスパ最高なモーニング」（本文2行・中身は画像）
#   **投稿の中身は流用しない。題材だけ借りて公式で裏を取り直す。**
#
# 取るもの: モーニングの料金 / 提供時間 / 内容 / 公式写真
# **料金と提供時間が公式で確認できなかったチェーンは記事に載せない。**
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
BRANCH="claude/morning-material"
WT="${TMPDIR:-/tmp}/dh-morning-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p morning

"$PY" - "$RDIR" <<'PYEOF'
import io, re, sys, time, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}
def get(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

JP = re.compile(r"[ぁ-んァ-ヶ一-龠]")
KEY = re.compile(r"モーニング|朝食|朝定食|朝マック|時まで|：|:|\d時|円|税込|税抜|セット|"
                 r"トースト|ゆで卵|ドリンク|提供|平日|土日|全店|一部店舗")
def digest(html, limit=120):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;"," "),("&amp;","&"),("&quot;",'"'),("&#039;","'"),("&yen;","¥")):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or l in seen or len(l) > 150 or len(l) < 2: continue
        if not (JP.search(l) and KEY.search(l)): continue
        seen.add(l); out.append(l)
    return out[:limit]

CHAINS = [
 ("komeda",   "コメダ珈琲店",   ["https://www.komeda.co.jp/menu/morning.html",
                                "https://www.komeda.co.jp/menu/"]),
 ("hoshino",  "星乃珈琲店",     ["https://www.hoshinocoffee.com/menu/",
                                "https://www.hoshinocoffee.com/"]),
 ("doutor",   "ドトールコーヒー", ["https://www.doutor.co.jp/dcs/menu/morning/",
                                "https://www.doutor.co.jp/dcs/menu/"]),
 ("stmarc",   "サンマルクカフェ", ["https://www.saint-marc-hd.com/saintmarc/menu/",
                                "https://www.saint-marc-hd.com/saintmarc/"]),
 ("ueshima",  "上島珈琲店",     ["https://www.ueshima-coffee-ten.jp/menu/",
                                "https://www.ueshima-coffee-ten.jp/"]),
 ("sukiya",   "すき家",         ["https://www.sukiya.jp/menu/in/morning/",
                                "https://www.sukiya.jp/menu/"]),
 ("matsuya",  "松屋",           ["https://www.matsuyafoods.co.jp/matsuya/menu/morning/",
                                "https://www.matsuyafoods.co.jp/matsuya/menu/"]),
 ("yoshinoya","吉野家",         ["https://www.yoshinoya.com/menu/breakfast/",
                                "https://www.yoshinoya.com/menu/"]),
 ("nakau",    "なか卯",         ["https://www.nakau.co.jp/jp/menu/asa/",
                                "https://www.nakau.co.jp/jp/menu/"]),
 ("mcd",      "マクドナルド",    ["https://www.mcdonalds.co.jp/menu/breakfast/",
                                "https://www.mcdonalds.co.jp/menu/"]),
 ("gusto",    "ガスト",         ["https://www.skylark.co.jp/gusto/menu/morning/",
                                "https://www.skylark.co.jp/gusto/menu/"]),
 ("mos",      "モスバーガー",    ["https://www.mos.jp/menu/morning/",
                                "https://www.mos.jp/menu/"]),
]

BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner|bnr", re.I)
out = ["# 500円モーニングの素材（各チェーン公式）", "",
       "起点: `https://x.com/ny_ai2/status/2093813441941119116`（本文2行・中身は画像）",
       "**投稿の中身は流用しない。題材だけ借りて公式で裏を取り直す。**", "",
       "**料金と提供時間が公式で確認できなかったチェーンは記事に載せないこと。**", ""]

for key, label, pages in CHAINS:
    out += [f"## {key} — {label}", ""]
    got = 0; nimg = 0
    for p in pages:
        try:
            html = get(p)
        except Exception as e:
            out.append(f"- `{p[:95]}` 取得できず（{type(e).__name__}）")
            continue
        d = digest(html)
        if d:
            got += 1
            out += [f"### `{p[:115]}`", "", "```"] + d + ["```", ""]
        else:
            out.append(f"- `{p[:95]}` 該当する記述が拾えなかった（JS 描画の可能性）")
        if nimg < 1:
            cs = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
            cs += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
            for c in cs:
                if not re.search(r"\.(jpe?g|png|webp)(\?|$)", c, re.I) or BAD.search(c): continue
                full = urllib.parse.urljoin(p, c)
                try:
                    im = Image.open(io.BytesIO(urllib.request.urlopen(
                        urllib.request.Request(full, headers=UA), timeout=30).read())).convert("RGB")
                except Exception:
                    continue
                w, h = im.size
                if w < 600 or h < 340 or w / h < 1.1: continue
                nimg += 1
                im.save(f"morning/{key}.jpg", quality=92)
                im.resize((480, max(1, int(h * 480 / w)))).save(f"morning/thumb-{key}.jpg", quality=72)
                out.append(f"- 写真 `morning/{key}.jpg` {w}x{h} ← {full[:100]}")
                break
        time.sleep(2)
    if got == 0: out.append("- **どのページからも中身が取れなかった。**")
    if nimg == 0: out.append("- **写真が取れなかった。**")
    out.append("")
    time.sleep(4)

open(f"{RDIR}/morning-chains.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("morning-chains.md を書き出した")
PYEOF

git -C "$WT" add -A morning 2>/dev/null
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "wip: 500円モーニングの素材（レビュー用）" 2>/dev/null || true
git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" 2>/dev/null || true
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/morning-chains.md / branch $BRANCH"
