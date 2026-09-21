#!/bin/bash
# **東京湾大華火祭（10/24）の「いま」を公式から取る（t147）。LLM 不使用・$0。**
#
# 記事 `wangan-festivals-2026` は **2026-06-10 公開**で、この節がこう書いてある。
#
#   チケット発売: **7月（上旬）発売予定**
#   料金: **5,000〜10,000円の予定**
#
# **いまは 9 月下旬。** 抽選も発売も終わっているはずで、**予定のまま置いてあるのは誤り。**
# 利用者からも「抽選なども終わってもっと情報が出ているはず／内容が浅い」と指摘された。
#
# ## 取るもの
#
#   1. 公式サイトの**本文テキスト**（チケット・観覧エリア・お知らせ・FAQ）
#   2. **公式内のリンクのうち、チケット／抽選／観覧／会場／当日 を含むもの**
#      → 次に見るべきページをこちらで判断できるようにする
#   3. 中央区の公式（区民優先枠の告知が出る先）
#
# **判断はしない。取ってくるだけ。** 記事への反映はクラウド側でやる。
# **要約もしない。** 元の文をそのまま持ち帰る（数字を丸めると裏取りにならない）。
#
# **5 分 以内**（最上位ルール 15）。180 秒 を超えたら残りを「時間切れ」と書いて止まる。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t147-tokyowan-hanabi.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import datetime as dt, html, re, sys, time, urllib.parse, urllib.request

OUT = sys.argv[1]
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"}
T0 = time.monotonic()
BUDGET = 180.0

def fetch(url, timeout=20):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
        enc = "utf-8"
        m = re.search(rb'charset=["\']?([\w-]+)', raw[:3000], re.I)
        if m:
            enc = m.group(1).decode("ascii", "ignore")
        return raw.decode(enc, "replace"), r.geturl()

def text_of(h):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", h)
    h = re.sub(r"(?i)<br\s*/?>", "\n", h)
    h = re.sub(r"(?i)</(p|div|li|tr|h[1-6]|section)>", "\n", h)
    h = re.sub(r"<[^>]+>", " ", h)
    h = html.unescape(h)
    h = re.sub(r"[ \t　]+", " ", h)
    h = re.sub(r"\n\s*\n+", "\n", h)
    return h.strip()

SEEDS = [
    ("公式トップ", "https://tokyo-hanabi-festival.com/"),
    ("中央区（区民枠の告知先）", "https://www.city.chuo.lg.jp/"),
]
KEY = re.compile(r"チケット|抽選|申込|観覧|会場|当日|販売|席|料金|中止|延期|荒天")

lines = ["# 東京湾大華火祭の「いま」（t147・**$0**）", "",
         f"生成: **{dt.datetime.now().astimezone():%Y-%m-%dT%H:%M:%S%z}**", "",
         "**要約していない。公式の本文をそのまま持ち帰っている。**",
         "**判断はクラウド側でやる。**", ""]

seen = set()
queue = list(SEEDS)
depth2 = []

for label, url in queue:
    if time.monotonic() - T0 > BUDGET:
        lines += [f"## {label}", "", "- ⏱️ **時間切れで見ていない**", ""]
        continue
    lines += [f"## {label}", "", f"`{url}`", ""]
    try:
        h, real = fetch(url)
    except Exception as e:
        lines += [f"- ⚠️ **開けない**: {type(e).__name__}: {e}", ""]
        continue
    seen.add(real)
    body = text_of(h)
    lines += ["```text", body[:2500], "```", ""]
    # **次に見るべきページを出す。** 推測でURLを組み立てないため
    found = []
    for m in re.finditer(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', h, re.S | re.I):
        href, anchor = m.group(1), re.sub(r"<[^>]+>", "", m.group(2)).strip()
        if not anchor or not KEY.search(anchor):
            continue
        u = urllib.parse.urljoin(real, href)
        if u in seen or u.startswith("mailto:"):
            continue
        seen.add(u)
        found.append((anchor[:40], u))
    if found:
        lines += ["**関係しそうなリンク**", ""]
        for a, u in found[:14]:
            lines.append(f"- `{a}` → {u[:120]}")
        lines.append("")
        # 公式サイト内のものだけ、本文も 1 階層 取る
        host = urllib.parse.urlparse(real).netloc
        for a, u in found:
            if urllib.parse.urlparse(u).netloc == host:
                depth2.append((f"{label} / {a}", u))
    else:
        lines += ["- **該当するリンクが出てこない**（JS で描いている可能性）", ""]

lines += ["---", "", "# 1 階層 下のページ", ""]
n = 0
for label, url in depth2:
    if n >= 6 or time.monotonic() - T0 > BUDGET:
        lines += [f"- ⏱️ 残り {len(depth2) - n} 件 は**時間切れで見ていない**", ""]
        break
    n += 1
    lines += [f"## {label}", "", f"`{url}`", ""]
    try:
        h, real = fetch(url)
        lines += ["```text", text_of(h)[:2000], "```", ""]
    except Exception as e:
        lines += [f"- ⚠️ **開けない**: {type(e).__name__}: {e}", ""]

lines += [f"**経過 {time.monotonic() - T0:.0f} 秒。**"]
open(OUT, "w").write("\n".join(lines) + "\n")
print("\n".join(lines)[:4000])
PYEOF
