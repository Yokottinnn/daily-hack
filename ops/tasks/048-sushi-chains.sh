#!/bin/bash
# 回転寿司チェーンの記事素材を取る。**一次情報（各社 IR・公式）から。**
#
# 狙い: 国内店舗数と、海外を含めた総店舗数で **1 位が入れ替わる** という切り口。
#   国内 は はま寿司 が首位に迫るが、海外を含めると スシロー が上回る、と報じられている。
#   **まとめサイトを根拠にせず、各社の IR と公式の店舗一覧で数え直す。**
#
# 取るもの: 店舗数 / 売上 / 運営会社 / 公式の写真
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
BRANCH="claude/sushi-material"
WT="${TMPDIR:-/tmp}/dh-sushi-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p sushi

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
KEY = re.compile(r"店舗数|店舗|出店|国内|海外|売上|営業収益|客単価|決算|期末|拠点|チェーン|"
                 r"億円|百万円|店$|店、|店。|皿|円")
def digest(html, limit=110):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;"," "),("&amp;","&"),("&quot;",'"'),("&#039;","'"),("&yen;","¥")):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or l in seen or len(l) > 150 or len(l) < 3: continue
        if not (JP.search(l) and KEY.search(l)): continue
        seen.add(l); out.append(l)
    return out[:limit]

# key, 表示名, 運営会社, 見に行くページ（公式と IR）
CHAINS = [
 ("sushiro",  "スシロー",   "FOOD & LIFE COMPANIES",
  ["https://www.akindo-sushiro.co.jp/", "https://www.food-and-life.co.jp/",
   "https://www.food-and-life.co.jp/company/outline/"]),
 ("kura",     "くら寿司",   "くら寿司",
  ["https://www.kurasushi.co.jp/", "https://www.kurasushi.co.jp/company/outline.html",
   "https://www.kurasushi.co.jp/ir/"]),
 ("hama",     "はま寿司",   "ゼンショーホールディングス",
  ["https://www.hamazushi.com/", "https://www.zensho.co.jp/jp/company/group/",
   "https://www.zensho.co.jp/jp/ir/"]),
 ("kappa",    "かっぱ寿司", "カッパ・クリエイト（コロワイド）",
  ["https://www.kappasushi.jp/", "https://www.kappa-create.co.jp/",
   "https://www.kappa-create.co.jp/company/outline/"]),
 ("uobei",    "魚べい",     "元気寿司",
  ["https://www.uobei.com/", "https://www.genkisushi.co.jp/",
   "https://www.genkisushi.co.jp/company/"]),
 ("choushi",  "銚子丸",     "銚子丸",
  ["https://www.choushimaru.co.jp/", "https://www.choushimaru.co.jp/company/"]),
]

BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner|bnr", re.I)
out = ["# 回転寿司チェーンの素材（一次情報）", "",
       "**まとめサイトは使っていない。** 各社の公式サイトと会社概要／IR から取った。",
       "数字が拾えなかった項目は「見つからず」と書く。**推測で埋めないこと。**", ""]

for key, label, corp, pages in CHAINS:
    out += [f"## {key} — {label}（運営: {corp}）", ""]
    nimg = 0; got = 0
    for p in pages:
        try:
            html = get(p)
        except Exception as e:
            out.append(f"- `{p[:90]}` 取得できず（{type(e).__name__}）")
            continue
        d = digest(html)
        if d:
            got += 1
            out += [f"### `{p[:110]}`", "", "```"] + d + ["```", ""]
        else:
            out.append(f"- `{p[:90]}` 数字らしい記述が拾えなかった（JS 描画の可能性）")
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
                if w < 640 or h < 360 or w / h < 1.1: continue
                nimg += 1
                im.save(f"sushi/{key}.jpg", quality=92)
                im.resize((480, max(1, int(h * 480 / w)))).save(f"sushi/thumb-{key}.jpg", quality=72)
                out.append(f"- 写真 `sushi/{key}.jpg` {w}x{h} ← {full[:100]}")
                break
        time.sleep(2)
    if got == 0:
        out.append("- **どのページからも数字が取れなかった。**")
    if nimg == 0:
        out.append("- **写真が取れなかった。**")
    out.append("")
    time.sleep(4)

open(f"{RDIR}/sushi-chains.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("sushi-chains.md を書き出した")
PYEOF

git -C "$WT" add -A sushi 2>/dev/null
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "wip: 回転寿司チェーンの素材（レビュー用）" 2>/dev/null || true
git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" 2>/dev/null || true
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/sushi-chains.md / branch $BRANCH"
