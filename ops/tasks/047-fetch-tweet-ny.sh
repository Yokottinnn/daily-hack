#!/bin/bash
# 記事の題材にしたい X 投稿を取る（2093813441941119116）。
#
# クラウドセッションは x.com に到達できないため、syndication API で本文を確定させる。
# note_tweet（長文）の可能性があるので fxtwitter でも取り、長いほうを採る。
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

RDIR="${OPS_REPORT_DIR:-/tmp}"
TID="2093813441941119116"
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do [ -x "$c" ] && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "python3.11 が無い"; exit 1; }

"$PY" - "$RDIR" "$TID" <<'PYEOF'
import json, sys, urllib.request

RDIR, TID = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}
def get(u, t=30):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

out = [f"# X 投稿 {TID}", ""]
best = ""
try:
    d = json.loads(get(f"https://cdn.syndication.twimg.com/tweet-result?id={TID}&lang=ja&token=a"))
    u = d.get("user") or {}
    txt = (d.get("text") or "").strip()
    best = txt
    out += ["## syndication API", "",
            f"- 投稿者: {u.get('name','')} (@{u.get('screen_name','')})",
            f"- 日付: {(d.get('created_at') or '')[:10]}", "", "```", txt, "```", ""]
    media = d.get("mediaDetails") or d.get("photos") or []
    if media:
        out += ["### 画像", ""]
        for m in media:
            url = m.get("media_url_https") or m.get("url") or ""
            if url: out.append(f"- {url}")
        out.append("")
except Exception as e:
    out += ["## syndication API", "", f"取得できず: {type(e).__name__} {e}", ""]

try:
    d2 = json.loads(get(f"https://api.fxtwitter.com/i/status/{TID}"))
    t2 = ((d2.get("tweet") or {}).get("text") or "").strip()
    out += ["## fxtwitter（長文の全文が取れる場合がある）", "", "```", t2, "```", ""]
    if len(t2) > len(best): best = t2
except Exception as e:
    out += ["## fxtwitter", "", f"取得できず: {type(e).__name__} {e}", ""]

out += ["## 採用する本文（長いほう）", "", "```", best, "```", ""]
open(f"{RDIR}/tweet-ny.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("tweet-ny.md を書き出した / 本文", len(best), "字")
PYEOF
echo "reports/tweet-ny.md"
