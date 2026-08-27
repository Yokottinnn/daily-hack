#!/bin/bash
# お台場ドローンショー 2026 の公式サイトを取り切る。
#
# 032 では index の途中で切れて、6 つあるコンテンツのうち
# 「ソニック 35周年」しか拾えなかった。アクセスと会場も未取得。
# ここでは日本語の行だけを全部残し、画像も候補として持ち帰る。
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
BRANCH="claude/odaiba-drone-material"
WT="${TMPDIR:-/tmp}/dh-odaiba-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p odaiba

"$PY" - "$RDIR" <<'PYEOF'
import io, re, sys, time, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}
def get(url, timeout=40):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")

JP = re.compile(r"[ぁ-んァ-ヶ一-龠]")
def jp_lines(html):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&quot;", '"'), ("&#039;", "'"),
                 ("&thinsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&ldquo;", '"'), ("&rdquo;", '"')):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or l in seen:
            continue
        # 日本語を含む行、または数字だけの行（1,000+ / 30min / 8days のような数値カード）
        if JP.search(l) or re.fullmatch(r"[0-9,+]+(min|days|機)?", l):
            seen.add(l)
            # 多言語が 1 行に連なるので、最初の非日本語ブロック以降を落とす
            l = re.split(r"\s{2,}(?=[A-Z])", l)[0]
            out.append(l[:400])
    return out

PAGES = ["https://odaibadrone.com/",
         "https://odaibadrone.com/news/", "https://odaibadrone.com/about/",
         "https://odaibadrone.com/contents/", "https://odaibadrone.com/access/",
         "https://odaibadrone.com/en/"]

out = ["# お台場ドローンショー 2026 公式サイト（日本語の行だけ）", "",
       "**ここに無い値は「未確認」のまま。** 推測で埋めない。", ""]
imgs_seen = set()
BAD = re.compile(r"logo|icon|favicon|sprite|placeholder|noimage|arrow|btn|sns|share", re.I)
n = 0
for p in PAGES:
    try:
        html = get(p)
    except Exception as e:
        out += [f"## `{p}`", "", f"取得できず: {type(e).__name__} {e}", ""]
        continue
    out += [f"## `{p}`", "", "```"] + jp_lines(html)[:400] + ["```", ""]
    cands = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
    cands += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
    cands += re.findall(r'["\']([^"\']+\.(?:jpe?g|png|webp))["\']', html, re.I)
    for u in cands:
        if n >= 10: break
        if BAD.search(u): continue
        full = urllib.parse.urljoin(p, u)
        if full in imgs_seen: continue
        imgs_seen.add(full)
        try:
            im = Image.open(io.BytesIO(urllib.request.urlopen(
                urllib.request.Request(full, headers=UA), timeout=40).read())).convert("RGB")
        except Exception:
            continue
        w, h = im.size
        if w < 640 or h < 360 or w / h < 1.1: continue
        n += 1
        im.save(f"odaiba/cand-{n:02d}.jpg", quality=92)
        im.resize((480, max(1, int(h * 480 / w)))).save(f"odaiba/thumb-{n:02d}.jpg", quality=72)
        out.append(f"- 写真 `odaiba/cand-{n:02d}.jpg` {w}x{h} ← {full[:100]}")
    out.append("")
    time.sleep(2)

open(f"{RDIR}/odaiba-drone2.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print(f"odaiba-drone2.md / 写真 {n} 枚")
PYEOF

git -C "$WT" add -A odaiba 2>/dev/null
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "wip: お台場ドローンショーの素材（レビュー用）" 2>/dev/null || true
git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" 2>/dev/null || true
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/odaiba-drone2.md / branch $BRANCH"
