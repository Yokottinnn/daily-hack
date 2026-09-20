#!/bin/bash
# **ac.jp メールで無料になるツールを、もっと拾う（t109）。**
#
# 利用者の指摘（2026-09-20・下書きフィードバック②）:
#   「もっと数ないの？わかる数だけ一覧でちゃんと記載して欲しい。」
#
# t104 で実額が取れたのは Figma と GitHub Copilot だけ。**候補そのものを増やす。**
# 作図・統計・数式・クラウド・ゲームエンジン・VPN。
#
# **料金ページは JS で描くものが多い**（ops-task-runner ルール 8）。
# 取れなければ「取れなかった」と分かる形で出す。**無いことの証明にはしない。**
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t109-more-edu-free.md"
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
    "https://www.overleaf.com/edu",
    "https://www.wolframalpha.com/pro/pricing/students",
    "https://www.lucidchart.com/pages/ja/pricing",
    "https://www.maxon.net/ja/education",
    "https://www.unrealengine.com/ja/students",
    "https://azure.microsoft.com/ja-jp/free/students/",
    "https://www.tableau.com/ja-jp/academic/students",
    "https://www.jetbrains.com/ja-jp/store/",
    "https://education.github.com/pack",
    "https://www.autodesk.com/jp/education/home",
]
WANT = re.compile(r"料金|価格|プラン|pricing|plans|Pro|Plus|Premium|学生|教育|student|education")
KEY = re.compile(r"学生|教育|無償|無料|free|年額|月額|年間|"
                 r"[0-9][0-9,]*\s*円|[$][0-9][0-9.,]*|/(mo|month|year|yr)")
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}

def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
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
        if urllib.parse.urlparse(u).netloc == urllib.parse.urlparse(base).netloc and u not in out:
            out[u] = text[:60]
    return out

L = ["# ac.jp で無料になるツール・追加候補（t109・公式ページの実物）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**アンカーテキストから辿った。** URL は推測していない。",
     "**取れなかったものは「読めなかった」であって「無い」ではない。**", ""]

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
    found.setdefault(seed, "（起点そのもの）")
L.append("")

# **学割の語が出たページを先に読む。** 起点そのものを優先。
order = sorted(found.items(), key=lambda kv: (kv[1] != "（起点そのもの）", kv[0]))
for i, (url, text) in enumerate(order[:16]):
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** 残り {len(order) - i} 本は次のタスクで。")
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
        L += hits[:26]
        L.append("```")
    else:
        L.append("（該当する行が無い。JS で描画している可能性）")
    L.append("")

if not found:
    L.append("**リンクが 1 本も取れなかった。**")

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:40]))
PYEOF
