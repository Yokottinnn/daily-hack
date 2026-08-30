#!/bin/bash
# サウナ記事の最後の穴を埋める。054 で埋まらなかったところだけを狙う。
#
# 054 で分かったこと:
#   - SHIAGARU と SAUNA汽汽 は**金額が予約カレンダー側にしか出ない**
#   - 荒木町Logout・おかえりサウナ板橋・黄金湯新宿 は**公式から写真が取れなかった**
#
# ここでは経路を変える。**プレスリリース（PR TIMES）は金額も写真も載せている。**
# 会社が自分で出した一次情報なので、出典を書けば使える。
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-sauna5-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p sauna2

"$PY" - "$RDIR" <<'PYEOF'
import io, re, sys, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(u, t=40):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

def getb(u, t=40):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

JP = re.compile(r"[ぁ-んァ-ヶ一-龠]")
def text_lines(html, limit=170):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&quot;", '"'), ("&#039;", "'"), ("&yen;", "¥")):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or len(l) > 150 or l in seen: continue
        if not (JP.search(l) or re.search(r"\d", l)): continue
        seen.add(l); out.append(l)
    return out[:limit]

BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner|bnr"
                 r"|campaign|ticket|coupon|kv|main_?visual|top_?img|avatar|profile", re.I)

def photos(html, base, key, want=4):
    got, lines, seen = 0, [], set()
    cs = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
    cs += re.findall(r'<img[^>]+data-original=["\']([^"\']+)["\']', html, re.I)
    cs += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
    for c in cs:
        if got >= want: break
        if not re.search(r"\.(jpe?g|png|webp)(\?|$)", c, re.I) or BAD.search(c): continue
        full = urllib.parse.urljoin(base, c)
        if full in seen: continue
        seen.add(full)
        try:
            im = Image.open(io.BytesIO(getb(full))).convert("RGB")
        except Exception:
            continue
        w, h = im.size
        if w < 640 or h < 380 or not (1.0 <= w / h <= 2.2): continue
        got += 1
        name = f"{key}-{got}"
        im.save(f"sauna2/{name}.jpg", quality=92)
        im.resize((480, max(1, int(h * 480 / w)))).save(f"sauna2/thumb-{name}.jpg", quality=72)
        lines.append(f"- 写真 `sauna2/{name}.jpg` {w}x{h} ← {full[:120]}")
    return lines or ["- **写真が取れなかった。**"]

# key, 表示名, ページ, 欲しいもの
TARGETS = [
    ("shiagaru", "⑥ SHIAGARU SAUNA 神田×秋葉原",
     ["https://prtimes.jp/main/html/rd/p/000000030.000060052.html"], "料金"),
    ("kiki", "⑦ SAUNA汽汽 -キキ-",
     ["https://www.makuake.com/project/sauna_kiki/", "https://sauna-kiki.jp/price/"], "料金"),
    ("monnaka", "⑰ 門仲SAUNAS LO",
     ["https://prtimes.jp/main/html/rd/p/000000017.000070556.html"], "料金と写真"),
    ("logout", "④ 荒木町サウナ Logout",
     ["https://prtimes.jp/main/html/rd/p/000000001.000178901.html"], "写真"),
    ("koganeyu", "⑫ 黄金湯 新宿",
     ["https://prtimes.jp/main/html/rd/p/000000011.000169331.html"], "写真"),
    ("okaeri", "⑨ おかえりサウナ板橋",
     ["https://furosauna.com/2026/03/09/112734883/",
      "https://itabashi-times.com/archives/okaeri-sauna.html"], "写真"),
]

out = ["# サウナ記事の最後の穴埋め（055）", "",
       "**054 で埋まらなかったところだけを、経路を変えて狙う。**",
       "プレスリリース（PR TIMES）は**会社が自分で出した一次情報**で、金額も写真も載せている。",
       "**推測値は書かない。写真は目で見てから使う。**", ""]

for key, label, pages, want in TARGETS:
    out += [f"## {key} — {label}（欲しいのは {want}）", ""]
    for p in pages:
        try:
            html = get(p)
        except Exception as e:
            out.append(f"- `{p}` 取得できず（{type(e).__name__}: {e}）")
            continue
        out += [f"### `{p}`", "", "```"] + text_lines(html) + ["```", ""]
        out += photos(html, p, key) + [""]
    out.append("")

open(f"{RDIR}/sauna-last.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1200])
PYEOF

BR="claude/sauna-material5"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f sauna2 >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: サウナ記事の最後の穴埋め素材（055）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/sauna-last.md / branch $BR"
