#!/bin/bash
# **学割の裏取り・3 巡目（t100）。まだ確かめられていない 3 つを取る。**
#
# ① **国立科学博物館の大学パートナーシップに放送大学が入っているか**
#    t098 で入会校一覧を直接 取りに行ったが、**JS で描画されていて中身が読めなかった。**
#    記事に「使えない」と書く前に確かめる必要がある（推測で断定しない）。
#    今回は入口ページからリンクを辿り、別の URL を探す。
#
# ② **国際学生証（ISIC）** — 大学生協の事業内容に入っていた。海外・国内の割引が付く。
#
# ③ **劇場の U25 系** — 年齢条件かどうかを確かめる。大人の学生が使えるかが変わる。
#
# URL は推測せず、**入口ページのアンカーテキストから辿る**（t099 と同じやり方）。
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t100-gakuwari-rest.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import datetime as dt, html, re, sys, time, urllib.error, urllib.parse, urllib.request

OUT = sys.argv[1]
BUDGET = 220.0
SEEDS = [
    "https://www.kahaku.go.jp/learning/university/partnership/",
    "https://www.kahaku.go.jp/gakushu/daigaku/",
    "https://www.isicjapan.jp/",
    "https://www.nntt.jac.go.jp/",
]
WANT = re.compile(r"入会校|加入校|大学パートナーシップ|特典|学割|学生|割引|U25|U-25|料金|ISIC")
KEY = re.compile(r"放送大学|入会校|加入校|特典|学割|学生|割引|無料|年齢|U25|U-25|ISIC|"
                 r"[0-9][0-9,]*\s*円|[0-9]+\s*%|[0-9]+\s*歳")
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}

def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=35) as r:
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

def links(base, body):
    out = {}
    for m in re.finditer(r'<a\s[^>]*href="([^"]+)"[^>]*>(.*?)</a>', body, re.S | re.I):
        text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html.unescape(m.group(2)))).strip()
        if not text or not WANT.search(text):
            continue
        u = urllib.parse.urljoin(base, html.unescape(m.group(1)))
        host = urllib.parse.urlparse(base).netloc
        if urllib.parse.urlparse(u).netloc == host and u not in out:
            out[u] = text[:60]
    return out

L = ["# 学割の裏取り・3 巡目（t100）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**アンカーテキストから辿った。** URL は推測していない。", ""]

t0, found = time.time(), {}
for seed in SEEDS:
    try:
        body = fetch(seed)
    except Exception as e:
        L.append(f"- 起点 `{seed}`: ❌ {type(e).__name__}")
        continue
    got = links(seed, body)
    L.append(f"- 起点 `{seed}` から **{len(got)} 本**")
    found.update(got)
L.append("")

for i, (url, text) in enumerate(sorted(found.items())[:8]):
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** 残り {len(found) - i} 本は次のタスクで。")
        break
    L += [f"## {text}", "", f"`{url}`", ""]
    try:
        page = fetch(url)
    except urllib.error.HTTPError as e:
        L += [f"❌ HTTP {e.code}", ""]
        continue
    except Exception as e:
        L += [f"❌ {type(e).__name__}: {str(e)[:140]}", ""]
        continue
    lines = textify(page)
    hits, seen = [], set()
    for j, ln in enumerate(lines):
        if len(ln) > 200 or not KEY.search(ln):
            continue
        ctx = (lines[j-1][:60] + " ／ " if j and len(lines[j-1]) <= 60 else "") + ln
        if ctx not in seen:
            seen.add(ctx); hits.append(ctx)
    L.append(f"取れた行: {len(lines)} 行中 **{len(hits)} 行**が該当")
    L.append("")
    if hits:
        L.append("```")
        L += hits[:30]
        L.append("```")
    else:
        L.append("（該当する行が無い。JS で描画している可能性）")
    L.append("")

if not found:
    L.append("**リンクが 1 本も取れなかった。** 起点のページの作りが変わった可能性がある。")

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:40]))
PYEOF
