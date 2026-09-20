#!/bin/bash
# **国立美術館 6 館の観覧料を公式から取る（t101）。**
#
# 利用者の指摘（2026-09-20・下書きフィードバック）:
#   「具体的にどれだけ安くなるかのきんがくのビフォーアフターがほしい」
#
# キャンパスメンバーズで「所蔵作品展が無料」と書いているが、
# **いくらが無料になるのかを書いていない。** 館ごとに違うので 6 館ぶん取る。
#
# **さらに 2026-09-19 に観覧料の改定が発表されている。**
# 一般が 1,000 円へ統一され、大学生は 500 円になるという内容で、
# 実施時期が館ごとにずれる。**二次情報しか見ていないので公式で確かめる。**
#
# URL は推測せず、各館のトップからアンカーテキストで辿る。
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t101-museum-fees.md"
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
BUDGET = 230.0
SEEDS = [
    "https://www.artmuseums.go.jp/",
    "https://www.momat.go.jp/",
    "https://www.nmwa.go.jp/jp/",
    "https://www.momak.go.jp/Japanese/guide/hoursAdmission.html",
    "https://www.nmao.go.jp/",
    "https://www.nfaj.go.jp/",
]
WANT = re.compile(r"観覧料|料金|チケット|利用案内|ご利用|入館|改定|値上げ|キャンパスメンバーズ")
KEY = re.compile(r"観覧料|料金|大学生|一般|高校生|無料|割引|団体|改定|キャンパスメンバーズ|"
                 r"[0-9][0-9,]*\s*円")
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

L = ["# 国立美術館 6 館の観覧料（t101・公式ページの実物）", "",
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

for i, (url, text) in enumerate(sorted(found.items())[:10]):
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
