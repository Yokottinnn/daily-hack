#!/bin/bash
# PARADISE 大手町の一次情報を取る。**ドメインを間違えていたのが原因だった。**
#
# 035 と 036 は `paradise-tokyo.com` に当たって 3 ページとも URLError で落ちた。
# 正しくは **`paradise-otemachi.com`**。検索で判明した。
#
# 記事はこの 1 件があるために「男性専用は 8 か 9 か」を確定できずにいる。
# 公式で男女の別・レディースデー・料金・25階/26階の構成を確認する。
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

RDIR="${OPS_REPORT_DIR:-/tmp}"
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }

"$PY" - "$RDIR" <<'PYEOF'
import re, sys, time, urllib.request

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}
def get(u, t=30):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

JP = re.compile(r"[ぁ-んァ-ヶ一-龠]")
def lines(html, limit=140):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;"," "),("&amp;","&"),("&quot;",'"'),("&#039;","'"),("&yen;","¥")):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or l in seen or len(l) > 160 or len(l) < 2: continue
        if not JP.search(l): continue
        seen.add(l); out.append(l)
    return out[:limit]

PAGES = [
  "https://paradise-otemachi.com/",
  "https://paradise-otemachi.com/facility_spa.html",
  "https://paradise-otemachi.com/price.html",
  "https://paradise-otemachi.com/contents/2026/01/open/",
  "https://paradise-otemachi.com/faq.html",
]
out = ["# PARADISE 大手町 一次情報（公式 paradise-otemachi.com）", "",
       "**035/036 は `paradise-tokyo.com` に当たっていた。ドメイン違いが原因。**", "",
       "見るところ: 男女の別 / レディースデー / 料金 / 25階・26階の構成 / 水着の要否", ""]
for p in PAGES:
    try:
        html = get(p)
    except Exception as e:
        out += [f"## `{p}`", "", f"取得できず: {type(e).__name__} {e}", ""]
        continue
    out += [f"## `{p}`", "", "```"] + lines(html) + ["```", ""]
    time.sleep(2)

open(f"{RDIR}/paradise-official.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("paradise-official.md を書き出した")
PYEOF
echo "reports/paradise-official.md"
