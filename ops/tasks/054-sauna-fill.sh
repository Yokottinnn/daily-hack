#!/bin/bash
# サウナ記事で残っている穴を埋める。
#   ① 料金が未確認の6施設（SHIAGARU・SAUNA汽汽・蒸薪・水宴・海賊サウナ・門仲SAUNAS LO）
#   ② 写真が無い9施設
#
# 044 は「検索エンジンを Mac から叩く」設計で全滅した。今回は**クラウド側の WebSearch で
# 公式ページの場所を確定させてある**ので、Mac 側は取得だけをする。
#
# **一覧ページの先頭画像はバナーであることが多い。** 052 と同じく帯状の画像を弾く。
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
WT="${TMPDIR:-/tmp}/dh-sauna4-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p sauna

"$PY" - "$RDIR" <<'PYEOF'
import io, re, sys, urllib.parse, urllib.request
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

JP = re.compile(r"[ぁ-んァ-ヶ一-龠]")
def text_lines(html, limit=110):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&quot;", '"'), ("&#039;", "'"), ("&yen;", "¥")):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or len(l) > 140 or l in seen: continue
        if not (JP.search(l) or re.search(r"\d", l)): continue
        seen.add(l); out.append(l)
    return out[:limit]

BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn|sns|banner|bnr"
                 r"|campaign|ticket|coupon|kv|main_?visual|top_?img", re.I)

def photos(html, base, key, want=3):
    got, lines, seen = 0, [], set()
    cs = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
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
        im.save(f"sauna/{name}.jpg", quality=92)
        im.resize((480, max(1, int(h * 480 / w)))).save(f"sauna/thumb-{name}.jpg", quality=72)
        lines.append(f"- 写真 `sauna/{name}.jpg` {w}x{h} ← {full[:110]}")
    return lines or ["- **写真が取れなかった。**"]

# key, 表示名, 見るページ（複数）, 何が欲しいか
TARGETS = [
    ("logout",   "④ 荒木町サウナ Logout",   ["https://sauna-logout.com/", "https://sauna-logout.com/price/"], "写真"),
    ("shiagaru", "⑥ SHIAGARU SAUNA 神田×秋葉原",
     ["https://shiagaru-sauna.com/tokyo-kanda-akihabara", "https://shiagaru-sauna.com/"], "料金と写真"),
    ("kiki",     "⑦ SAUNA汽汽 -キキ-",
     ["https://sauna-kiki.jp/price/", "https://sauna-kiki.jp/", "https://sauna-kiki.jp/news/post-355/"], "料金と写真"),
    ("jyoshin",  "⑧ サウナ蒸薪",
     ["https://www.sauna-jyoshin.com/", "https://www.sauna-jyoshin.com/facility"], "料金と写真"),
    ("okaeri",   "⑨ おかえりサウナ板橋",
     ["https://onsen.nifty.com/itabashi-onsen/onsen024792/"], "写真"),
    ("mainichi", "⑩ 毎日サウナ東京 幕張店",
     ["https://www.supersento.com/kanto/chiba/maisa_tokyo.html"], "写真"),
    ("koganeyu", "⑫ 黄金湯 新宿",
     ["https://www.1010.or.jp/map/item/item-cnt-331"], "写真"),
    ("suien",    "⑭ 水宴 -suien-",
     ["https://furosauna.com/2026/06/22/085837988/"], "料金と写真"),
    ("kaizoku",  "⑯ 海賊サウナ＆カプセルホテル",
     ["https://camp-fire.jp/projects/909144/view",
      "https://www.supersento.com/kanto/kanagawa/kaizoku-sauna.html"], "料金と写真"),
    ("monnaka",  "⑰ 門仲SAUNAS LO",
     ["https://lo.saunas-saunas.com/monnaka/", "https://lo.saunas-saunas.com/monnaka/price/"], "料金と写真"),
]

out = ["# サウナ記事の穴埋め（054）", "",
       "**推測値は書かない。取れなかったものは「取れなかった」と残す。**",
       "**写真はバナーでないことを目で見てから使うこと。**", ""]

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

open(f"{RDIR}/sauna-fill.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1200])
PYEOF

BR="claude/sauna-material4"
git -C "$WT" checkout -q -B "$BR" 2>/dev/null
git -C "$WT" add -f sauna >/dev/null 2>&1
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "chore: サウナ記事の穴埋め素材（054）" >/dev/null 2>&1 \
  && git -C "$WT" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | tail -2
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/sauna-fill.md / branch $BR"
