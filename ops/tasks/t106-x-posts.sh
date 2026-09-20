#!/bin/bash
# **記事に埋め込む X の実投稿を、syndication API で照合する（t106）。**
#
# 利用者の指摘（2026-09-20・下書きフィードバック）:
#   「学割で実際にこれを買いましたとかSNSで投稿されているものに関しては
#     すべて拾ってきて紹介して」
#
# 検索で見つけた 6 本の**本文・投稿者・日付を公式の口で確かめる。**
# blog-article スキル:「検索結果の抜粋を信じない」「実在する投稿だけ」。
#
# クラウドは x.com に出られない（全経路 EGRESS_BLOCKED・2026-09-19 に実測）。
#
# **判断はしない。** どれを載せるかはクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t106-x-posts.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import datetime as dt, json, sys, time, urllib.error, urllib.request

OUT = sys.argv[1]
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124 Safari/537.36"
IDS = [
    ("1853745685616857096", "放送大学に入ったほうがいい（Adobe/Apple/美術館/映画館）"),
    ("1769641957108924456", "Apple の学生教職員ページで UNiDAYS 認証・放送大学でも通った"),
    ("1615539908353089537", "Apple 学割の実額（Mac mini / MacBook Pro）"),
    ("1766036135741120542", "合格通知書で Apple 学割を申請できた"),
    ("1870431902152495496", "脱毛の学割のために放送大学に入った"),
    ("2023984237192351843", "快活クラブ・Apple・Amazon・Office・公共交通・Adobe"),
]
L = ["# 記事に埋め込む X 投稿の照合（t106）", "",
     f"取得 {dt.datetime.now().astimezone().isoformat(timespec='seconds')}", "",
     "**検索結果の抜粋ではなく syndication API の本文。** 採否はクラウド側。", ""]

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")

for tid, memo in IDS:
    L += [f"## {tid}", "", f"探していたもの: {memo}", ""]
    d = None
    for token in ("a", "x"):
        url = f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token={token}"
        try:
            d = json.loads(get(url))
            break
        except urllib.error.HTTPError as e:
            L.append(f"- token={token}: HTTP {e.code}")
        except Exception as e:
            L.append(f"- token={token}: {type(e).__name__} {str(e)[:120]}")
    if not d:
        L += ["", "**取れなかった。** 削除されたか、非公開になった可能性がある。", ""]
        continue
    u = d.get("user") or {}
    L.append(f"- 投稿者: {u.get('name','?')} (@{u.get('screen_name','?')})")
    L.append(f"- 日時: {d.get('created_at','?')}")
    L.append(f"- いいね: {d.get('favorite_count','?')}")
    t = d.get("text") or ""
    L += ["", "```"] + t.splitlines() + ["```", ""]
    time.sleep(1)

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:50]))
PYEOF

echo "---- $OUT ----"
