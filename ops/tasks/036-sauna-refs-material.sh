#!/bin/bash
# 参考記事 3 本（asoview / TimeOut / ニフティ温泉）から取り込む材料を集める。
#
# 取りに行くもの。
#  (1) TimeOut に載っていて、こちらの 15 施設に入っていない首都圏の 2 件
#      - スパ＆ホテル 舞浜ユーラシア（千葉・舞浜／2026-01-15 リニューアル）
#      - SAUNA汽汽（東京・中目黒／2026 春 開業予定・男女一緒）
#      開業日・料金・男女・サウナの種類が公式で裏取れるかを見る。
#  (2) asoview 方式の「1 施設あたりの厚い仕様」。
#      営業時間・定休日・サウナの種類と温度・水風呂の温度を公式から拾う。
#  (3) PARADISE 大手町の男女。TimeOut は「男性限定エリア。今後レディースデー予定」と書く。
#      公式で確定できるか。
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
BRANCH="claude/sauna-refs-material"
WT="${TMPDIR:-/tmp}/dh-refs3-$$"
RDIR="${OPS_REPORT_DIR:-/tmp}"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い"; exit 1; }

git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }
git -C "$REPO" worktree add -f --detach "$WT" origin/main >/dev/null 2>&1 || { echo "worktree 失敗"; exit 1; }
cd "$WT" || exit 1
mkdir -p tiles3

"$PY" - "$RDIR" <<'PYEOF'
import io, re, sys, time, urllib.parse, urllib.request
from PIL import Image

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(url, timeout=30):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")

def text_of(html):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    h = urllib.parse.unquote(h)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&quot;", '"'), ("&#039;", "'"),
                 ("&lt;", "<"), ("&gt;", ">")):
        h = h.replace(a, b)
    lines = [l.strip() for l in h.split("\n")]
    return "\n".join([l for l in lines if l])

# 拾いたい語の周辺だけ残す
KEY = re.compile(r"(料金|入館|入浴|営業時間|定休|男性|女性|男女|レディース|サウナ室|水風呂|"
                 r"ロウリュ|オープン|開業|リニューアル|℃|度|円)")
def digest(t, limit=180):
    out = [l for l in t.split("\n") if KEY.search(l) and 4 <= len(l) <= 160]
    seen, uniq = set(), []
    for l in out:
        if l in seen: continue
        seen.add(l); uniq.append(l)
    return uniq[:limit]

SITES = [
  ("maihama-eurasia", "スパ＆ホテル 舞浜ユーラシア", [
      "https://www.my-spa.jp/", "https://www.my-spa.jp/price/", "https://www.my-spa.jp/spa/"]),
  ("sauna-kiki", "SAUNA汽汽（中目黒）", [
      "https://sauna-kiki.jp/", "https://www.saunaco.jp/"]),
  ("paradise", "PARADISE 大手町（男女の確定）", [
      "https://paradise-tokyo.com/otemachi/", "https://paradise-tokyo.com/otemachi/spa/",
      "https://paradise-tokyo.com/otemachi/price/"]),
  ("takanawa", "高輪SAUNAS（サウナ室・水風呂）", [
      "https://saunas-saunas.com/takanawa/", "https://saunas-saunas.com/takanawa/facility/"]),
  ("oimachi", "サウナメッツァ大井町（サウナ室・水風呂）", [
      "https://ryusenjinoyu.com/saunametsaoimachi/",
      "https://ryusenjinoyu.com/saunametsaoimachi/facility/"]),
  ("blueocean", "BlueOcean（サウナ室・水風呂）", [
      "http://k-scc.co.jp/sauna/", "http://k-scc.co.jp/sauna/price/price.html"]),
  ("koganeyu", "黄金湯 新宿（サウナ室・水風呂）", [
      "https://koganeyu.com/shinjuku/", "https://koganeyu.com/"]),
  ("spaeas", "SPA EAS（SAUNA IMMERSIA）", [
      "https://www.spa-eas.com/", "https://www.spa-eas.com/facility/"]),
  ("monnaka", "門仲SAUNAS LO", ["https://lo.saunas-saunas.com/monnaka/"]),
  ("kohaku", "sauna KOHAKU（レディースデー）", ["https://sauna-kohaku.com/"]),
]

out = ["# 参考記事から取り込む材料（公式サイトの生text）", "",
       "**ここに出ていない値は「未確認」のまま。** 推測で埋めない。", ""]
BAD = re.compile(r"logo|icon|favicon|sprite|ogp|og-|placeholder|noimage|arrow|btn", re.I)

for key, label, pages in SITES:
    out += [f"## {key} — {label}", ""]
    got_any = False
    for p in pages:
        try:
            html = get(p)
        except Exception as e:
            out.append(f"- `{p}` 取得できず（{type(e).__name__}）")
            continue
        got_any = True
        d = digest(text_of(html))
        out += [f"### `{p}`", "", "```"] + d + ["```", ""]
        # 写真も 1 枚だけ拾っておく（新規 2 施設のため）
        if key in ("maihama-eurasia", "sauna-kiki"):
            cands = re.findall(r'<img[^>]+(?:data-)?src=["\']([^"\']+)["\']', html, re.I)
            cands += [m[1] for m in re.findall(r'url\((["\']?)([^)"\']+)\1\)', html)]
            n = 0
            for u in cands:
                if n >= 2: break
                if not re.search(r"\.(jpe?g|png|webp)(\?|$)", u, re.I): continue
                if BAD.search(u): continue
                full = urllib.parse.urljoin(p, u)
                try:
                    im = Image.open(io.BytesIO(urllib.request.urlopen(
                        urllib.request.Request(full, headers=UA), timeout=30).read())).convert("RGB")
                except Exception:
                    continue
                w, h = im.size
                if w < 640 or h < 360 or w / h < 1.1: continue
                n += 1
                im.save(f"tiles3/{key}-{n}.jpg", quality=92)
                out.append(f"- 写真 `tiles3/{key}-{n}.jpg` {w}x{h} ← {full[:90]}")
            out.append("")
        time.sleep(2)
    if not got_any:
        out += ["- **どのページも取れなかった。**", ""]

open(f"{RDIR}/sauna-refs3.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("sauna-refs3.md を書き出した")
PYEOF

git -C "$WT" add -A tiles3 2>/dev/null
git -C "$WT" -c user.name="ops-heartbeat" -c user.email="noreply@fieldbeside.com" \
  commit -q -m "wip: 参考記事から取り込む材料（レビュー用）" 2>/dev/null || true
git -C "$WT" push -q --force origin "HEAD:refs/heads/$BRANCH" 2>/dev/null || true
git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1
echo "reports/sauna-refs3.md / branch $BRANCH"
