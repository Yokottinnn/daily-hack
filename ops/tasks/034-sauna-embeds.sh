#!/bin/bash
# 15 施設ぶんの「X の実投稿」と「YouTube の動画」を集める。
#
# 記事に埋め込む素材。**実在するものだけを使う**ため、
# 検索で URL を見つけ → syndication API で本文・作者・日付を確定させる。
# URL を組み立てて作らない（存在しない埋め込みは再生できず必ずバレる）。
#
# クラウドからは x.com にも youtube.com にも到達できないので Mac で走らせる。
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
RDIR="${OPS_REPORT_DIR:-/tmp}"

PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }

"$PY" - "$RDIR" <<'PYEOF'
import json, re, sys, time, urllib.parse, urllib.request

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(url, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")

FACILITIES = [
    ("paradise",  "PARADISE 大手町 サウナ"),
    ("takanawa",  "高輪SAUNAS"),
    ("logout",    "荒木町サウナ Logout"),
    ("oimachi",   "サウナメッツァ大井町トラックス"),
    ("shiagaru",  "SHIAGARU SAUNA 神田 秋葉原"),
    ("mushimaki", "サウナ蒸薪 北本"),
    ("okaeri",    "おかえりサウナ板橋"),
    ("makuhari",  "毎日サウナ東京 幕張店"),
    ("blueocean", "サウナリゾート BlueOcean 新横浜"),
    ("koganeyu",  "黄金湯 新宿 サウナ"),
    ("kohaku",    "sauna KOHAKU 柏"),
    ("suien",     "水宴 麻布十番 サウナ"),
    ("spaeas",    "横浜天然温泉 SPA EAS サウナ"),
    ("kaizoku",   "海賊サウナ 小田原"),
    ("monnaka",   "門仲SAUNAS LO 門前仲町"),
]

def ddg(q, want):
    """DuckDuckGo の HTML 版から want にマッチする URL を集める。"""
    try:
        html = get("https://html.duckduckgo.com/html/?q=" + urllib.parse.quote(q))
    except Exception:
        return []
    raw = re.findall(r'uddg=([^&"]+)', html)
    out, seen = [], set()
    for r in raw:
        u = urllib.parse.unquote(r)
        if want in u and u not in seen:
            seen.add(u); out.append(u)
    return out

def tweet(tid):
    """syndication から本文・作者・日付を取る。ここが取れないものは使わない。"""
    try:
        d = json.loads(get(f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token=a"))
    except Exception:
        return None
    txt = (d.get("text") or "").strip()
    u = d.get("user") or {}
    if not txt or not u.get("screen_name"):
        return None
    return {"id": tid, "text": txt, "name": u.get("name"), "handle": u.get("screen_name"),
            "created": (d.get("created_at") or "")[:10]}

def youtube(q):
    try:
        html = get("https://www.youtube.com/results?search_query=" + urllib.parse.quote(q))
    except Exception:
        return []
    ids = re.findall(r'"videoId":"([A-Za-z0-9_-]{11})"', html)
    titles = re.findall(r'"title":\{"runs":\[\{"text":"(.*?)"\}\]', html)
    out, seen = [], set()
    for i, vid in enumerate(ids):
        if vid in seen: continue
        seen.add(vid)
        t = titles[i] if i < len(titles) else ""
        try: t = t.encode().decode("unicode_escape")
        except Exception: pass
        out.append((vid, t[:80]))
        if len(out) >= 3: break
    return out

lines = ["# 埋め込み素材（X の実投稿 / YouTube）", "",
         "**syndication で本文が取れたものだけ載せている。** 取れないものは使わないこと。", ""]
for key, q in FACILITIES:
    lines += [f"## {key} — 検索語 `{q}`", ""]
    # --- X ---
    urls = ddg(f"site:x.com {q}", "x.com")
    got = 0
    for u in urls:
        m = re.search(r"x\.com/([^/]+)/status/(\d+)", u)
        if not m: continue
        t = tweet(m.group(2))
        if not t: continue
        got += 1
        lines += [f"- X: `https://x.com/{t['handle']}/status/{t['id']}` / {t['name']} (@{t['handle']}) / {t['created']}",
                  "  ```", "  " + t["text"].replace("\n", "\n  ")[:600], "  ```"]
        if got >= 3: break
        time.sleep(1)
    if got == 0:
        lines.append("- X: 本文を確定できる投稿が見つからなかった")
    # --- YouTube ---
    vids = youtube(q + " サウナ")
    if vids:
        for vid, title in vids:
            lines.append(f"- YT: `{vid}` — {title}")
    else:
        lines.append("- YT: 見つからなかった")
    lines.append("")
    time.sleep(2)

open(f"{RDIR}/sauna-embeds.md", "w", encoding="utf-8").write("\n".join(lines) + "\n")
print(f"書き出した: reports/sauna-embeds.md（{len(lines)} 行）")
PYEOF
