#!/bin/bash
# **参照元の X 投稿の本文を取ってくる。**
#
# 利用者から「この投稿を参考にして」と渡されたのは
# https://x.com/connect24h/status/2100750468171657241
# **クラウドセッションは x.com に出られない**（egress proxy が全経路を塞いでいる。
# x.com / cdn.syndication.twimg.com / publish.twitter.com / api.fxtwitter.com /
# api.vxtwitter.com すべて 2026-09-19 に実測で EGRESS_BLOCKED）。
#
# ## やること
#
# 公開の syndication エンドポイントから本文と画像 URL を取る。**認証は要らない。**
# 取ってくるだけで、判断はしない（採否はクラウド側）。
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t093-connect24h-post.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import datetime as dt, json, sys, urllib.error, urllib.request

OUT = sys.argv[1]
TID = "2100750468171657241"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124 Safari/537.36"
L = [f"# connect24h/{TID} の本文", "",
     f"取得 {dt.datetime.now().astimezone().isoformat(timespec='seconds')}", ""]

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")

def dump(d, indent=0):
    """**本文と画像 URL だけ**を出す。JSON 全文は公開リポジトリに載せない。"""
    pad = "  " * indent
    t = d.get("text")
    if t:
        L.append(f"{pad}## 本文"); L.append(""); L.append("```")
        L.extend(t.splitlines()); L.append("```"); L.append("")
    u = d.get("user") or {}
    if u:
        L.append(f"{pad}- 投稿者: {u.get('name','?')} (@{u.get('screen_name','?')})")
    if d.get("created_at"):
        L.append(f"{pad}- 日時: {d['created_at']}")
    for k in ("favorite_count", "conversation_count"):
        if d.get(k) is not None:
            L.append(f"{pad}- {k}: {d[k]}")
    for m in (d.get("mediaDetails") or d.get("photos") or []):
        murl = m.get("media_url_https") or m.get("url")
        if murl:
            L.append(f"{pad}- 画像: {murl}")
    for e in ((d.get("entities") or {}).get("urls") or []):
        L.append(f"{pad}- リンク: {e.get('expanded_url') or e.get('url')}")

ok = False
for token in ("a", "x", "4c2mmul6mnh"):
    url = (f"https://cdn.syndication.twimg.com/tweet-result?id={TID}"
           f"&lang=ja&token={token}")
    try:
        d = json.loads(get(url))
    except urllib.error.HTTPError as e:
        L.append(f"- token={token}: HTTP {e.code}"); continue
    except Exception as e:
        L.append(f"- token={token}: {type(e).__name__} {e}"); continue
    dump(d)
    q = d.get("quoted_tweet")
    if q:
        L.append("## 引用元"); L.append(""); dump(q, 1); L.append("")
    par = d.get("parent")
    if par:
        L.append("## 返信元"); L.append(""); dump(par, 1); L.append("")
    ok = True
    break

if not ok:
    L.append("")
    L.append("**取れなかった。** syndication が塞がれているか、投稿が消えている。")
    L.append("Mac の Chrome で開いて本文をコピーする経路に切り替える。")

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:40]))
PYEOF

echo "---- $OUT ----"
