#!/bin/bash
# ららぽーと記事に足りない「一次の声」を取る。
#
# 現状: X の実投稿 2 件・YouTube 0 本。**スキルの必須要件 8 に対して弱い。**
# 20 施設のうち上位（売上・面積で目立つもの）を中心に、
#   - X の実投稿（syndication API で本文・投稿者・日付を確定）
#   - YouTube の動画（oEmbed でタイトルと投稿者を照合）
# を集める。**照合できなかったものは候補に載せない。**
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

RDIR="${OPS_REPORT_DIR:-/tmp}"
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }

"$PY" - "$RDIR" <<'PYEOF'
import json, re, sys, time, urllib.parse, urllib.request

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}
def get(url, timeout=30):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")

TARGETS = [
  ("tokyobay",  "ららぽーとTOKYO-BAY 北館"),
  ("expocity",  "ららぽーとEXPOCITY"),
  ("fujimi",    "ららぽーと富士見"),
  ("toyosu",    "ららぽーと豊洲 リニューアル"),
  ("lazona",    "ラゾーナ川崎プラザ フードコート"),
  ("yokohama",  "ららぽーと横浜 リニューアル"),
  ("fukuoka",   "ららぽーと福岡"),
  ("anjo",      "ららぽーと安城"),
  ("kadoma",    "ららぽーと門真"),
  ("ebina",     "ららぽーと海老名"),
]

out = ["# ららぽーと記事の X / YouTube 候補", "",
       "**すべて実在を確認したものだけ。** X は syndication API、YouTube は oEmbed で照合した。", ""]

# ---- X ----
def tweet(tid):
    try:
        d = json.loads(get(f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token=a"))
    except Exception:
        return None
    t = (d.get("text") or "").strip(); u = d.get("user") or {}
    if not t or not u.get("screen_name"): return None
    return dict(id=tid, text=t, name=u.get("name"), handle=u.get("screen_name"),
                created=(d.get("created_at") or "")[:10])

def find_status(q):
    ids, seen = [], set()
    for engine in ("https://html.duckduckgo.com/html/?q=",
                   "https://lite.duckduckgo.com/lite/?q=",
                   "https://www.bing.com/search?q="):
        try: html = get(engine + urllib.parse.quote(q))
        except Exception: continue
        for m in re.findall(r"(?:x|twitter)\.com/[^/\s\"']+/status/(\d{15,25})",
                            urllib.parse.unquote(html)):
            if m not in seen: seen.add(m); ids.append(m)
        if ids: break
        time.sleep(4)
    return ids

out += ["## X の実投稿", ""]
for key, q in TARGETS:
    out.append(f"### {key} — `{q}`")
    got = 0
    for tid in find_status(f"site:x.com {q}")[:6]:
        t = tweet(tid)
        if not t: continue
        got += 1
        out += [f"- `https://x.com/{t['handle']}/status/{t['id']}` / {t['name']} (@{t['handle']}) / {t['created']}",
                "  ```", "  " + t["text"].replace("\n", "\n  ")[:400], "  ```"]
        if got >= 2: break
        time.sleep(1)
    if got == 0: out.append("- 見つからなかった")
    out.append("")
    time.sleep(6)

# ---- YouTube ----
def yt_search(q):
    try:
        html = get("https://www.youtube.com/results?search_query=" + urllib.parse.quote(q))
    except Exception:
        return []
    ids, seen = [], set()
    for m in re.findall(r'"videoId":"([A-Za-z0-9_-]{11})"', html):
        if m not in seen: seen.add(m); ids.append(m)
    return ids[:5]

def oembed(vid):
    try:
        return json.loads(get("https://www.youtube.com/oembed?format=json&url="
                              + urllib.parse.quote(f"https://www.youtube.com/watch?v={vid}", safe="")))
    except Exception:
        return None

out += ["## YouTube（oEmbed で題名と投稿者を確認）", "",
        "| キー | videoId | タイトル | 投稿者 |", "| --- | --- | --- | --- |"]
for key, q in TARGETS:
    for vid in yt_search(q):
        d = oembed(vid)
        if not d: continue
        out.append(f"| `{key}` | `{vid}` | {d.get('title','')[:70]} | {d.get('author_name','')[:30]} |")
        time.sleep(1)
    time.sleep(3)

open(f"{RDIR}/lalaport-voices.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("lalaport-voices.md を書き出した")
PYEOF
echo "reports/lalaport-voices.md"
