#!/bin/bash
# **各スーパーのタイムセール・特売情報を、公式の告知から取る（t112）。**
#
# 利用者の指摘（2026-09-20・下書きフィードバック）:
#   「各スーパーのタイムセールの情報とかSNSとかで告知されているものを取得してきて、
#     タイムリーな情報をちゃんと取得して載せて。」
#
# 取るものは 2 つ。
#   A) 公式サイトのチラシ・特売・キャンペーンのページ
#   B) 公式 X アカウントの直近の投稿（syndication API・t106 と同じ口）
#
# **X の ID は推測しない。** 公式サイトから辿れた X のリンクだけを使う。
# 見つからなければ「見つからなかった」と書く（ops-task-runner ルール 8）。
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t112-super-timesale.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import datetime as dt, html, json, re, sys, time, urllib.error, urllib.parse, urllib.request

OUT = sys.argv[1]
BUDGET = 250.0
SEEDS = [
    ("オーケー",       "https://ok-corporation.jp/"),
    ("ロピア",         "https://lopia.jp/"),
    ("トライアル",     "https://www.trial-net.co.jp/"),
    ("西友",           "https://www.seiyu.co.jp/"),
    ("肉のハナマサ",   "https://hanamasa.co.jp/"),
    ("まいばすけっと", "https://www.mybasket.co.jp/"),
    ("業務スーパー",   "https://www.gyomusuper.jp/"),
]
WANT = re.compile(r"チラシ|特売|セール|キャンペーン|お買い得|value|おすすめ|今週|本日|タイムセール")
KEY = re.compile(r"チラシ|特売|セール|キャンペーン|お買い得|タイムセール|"
                 r"[0-9][0-9,]*\s*円|[0-9]+\s*%\s*(引|OFF|オフ)|"
                 r"[0-9]{1,2}\s*[/月]\s*[0-9]{1,2}|毎週|毎月|限定")
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}

def fetch(url, t=22):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=t) as r:
        raw = r.read()
    for enc in ("utf-8", "cp932", "euc-jp"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", "replace")

def textify(h):
    h = re.sub(r"<(script|style|noscript)[^>]*>.*?</\1>", " ", h, flags=re.S | re.I)
    h = re.sub(r"<[^>]+>", "\n", h)
    h = html.unescape(h)
    return [x for x in (re.sub(r"\s+", " ", y).strip() for y in h.split("\n")) if x]

def hits_of(page):
    lines = textify(page)
    hits, seen = [], set()
    for j, ln in enumerate(lines):
        if len(ln) > 170 or not KEY.search(ln):
            continue
        ctx = (lines[j-1][:46] + " ／ " if j and len(lines[j-1]) <= 46 else "") + ln
        if ctx not in seen:
            seen.add(ctx); hits.append(ctx)
    return len(lines), hits

def links(base, body):
    out = {}
    for m in re.finditer(r'<a\s[^>]*href="([^"]+)"[^>]*>(.*?)</a>', body, re.S | re.I):
        text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html.unescape(m.group(2)))).strip()
        if not text or not WANT.search(text):
            continue
        u = urllib.parse.urljoin(base, html.unescape(m.group(1)))
        if urllib.parse.urlparse(u).netloc == urllib.parse.urlparse(base).netloc and u not in out:
            out[u] = text[:46]
    return out

def x_handles(body):
    """**公式サイトから辿れた X のリンクだけ。** ID は推測しない。"""
    hs = []
    for m in re.finditer(r'https?://(?:www\.)?(?:twitter|x)\.com/([A-Za-z0-9_]{2,15})', body):
        h = m.group(1)
        if h.lower() in ("share", "intent", "home", "search", "i", "hashtag") or h in hs:
            continue
        hs.append(h)
    return hs[:2]

L = ["# 各スーパーのタイムセール・特売（t112・公式の告知）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**X の ID は推測していない。** 公式サイトから辿れたリンクだけを使った。",
     "**取れなかったものは「読めなかった」であって「無い」ではない。**", ""]

t0 = time.time()
for name, seed in SEEDS:
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** {name} 以降は次のタスクで。")
        break
    L.append(f"## {name}")
    L.append("")
    try:
        body = fetch(seed)
    except Exception as e:
        L += [f"❌ 起点 `{seed}`: {type(e).__name__}", ""]
        continue

    hs = x_handles(body)
    L.append(f"公式サイトから辿れた X: {', '.join('@'+h for h in hs) if hs else '**見つからなかった**'}")
    L.append("")

    got = links(seed, body)
    L.append(f"チラシ・特売らしいリンク **{len(got)} 本**")
    L.append("")
    pages = [(seed, "（起点そのもの）")] + list(got.items())[:2]
    for u, txt in pages:
        if time.time() - t0 > BUDGET:
            break
        L.append(f"### {txt}")
        L.append("")
        L.append(f"`{u}`")
        L.append("")
        try:
            page = body if u == seed else fetch(u)
        except urllib.error.HTTPError as e:
            L += [f"❌ HTTP {e.code}", ""]
            continue
        except Exception as e:
            L += [f"❌ {type(e).__name__}", ""]
            continue
        n, hits = hits_of(page)
        L.append(f"取れた行: {n} 行中 **{len(hits)} 行**が該当")
        L.append("")
        if hits:
            L += ["```"] + hits[:18] + ["```"]
        else:
            L.append("（該当する行が無い。JS で描画している可能性）")
        L.append("")

    # **公式 X の直近投稿。** ID は上で辿れたものだけ。
    for h in hs:
        if time.time() - t0 > BUDGET:
            break
        L.append(f"### @{h} の直近")
        L.append("")
        try:
            u = f"https://syndication.twitter.com/srv/timeline-profile/screen-name/{h}"
            page = fetch(u, 20)
            m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', page, re.S)
            texts = []
            if m:
                for t in re.findall(r'"full_text":"(.*?)","', m.group(1)):
                    t = t.encode().decode("unicode_escape", "replace")
                    if KEY.search(t):
                        texts.append(re.sub(r"\s+", " ", t)[:180])
            if texts:
                L += ["```"] + texts[:8] + ["```", ""]
            else:
                L += ["（特売に関する投稿が拾えなかった）", ""]
        except Exception as e:
            L += [f"❌ {type(e).__name__}: {str(e)[:110]}", ""]

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
