#!/bin/bash
# 500円モーニング記事に貼る X の実投稿を、syndication API で本文ごと確定させる。
#
# クラウド側の検索で**実在まで確認済みの ID** だけを渡している。
# **取れなかったものは記事に貼らない。**
#
# LLM を呼ばないため API クレジットは消費しない（$0/回・$0/日・$0/月）。
set -uo pipefail

RDIR="${OPS_REPORT_DIR:-/tmp}"
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11 /usr/bin/python3; do
  [ -x "$c" ] && { PY="$c"; break; }
done
[ -n "$PY" ] || { echo "python3 が無い"; exit 1; }

"$PY" - "$RDIR" <<'PYEOF'
import json, sys, urllib.request

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(u, t=30):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

TWEETS = [
    ("1905074336136085997", "なか卯の目玉焼き朝食の値上げに触れた投稿（利用者）"),
    ("1954726904755634686", "松屋の朝定食。ごはんおかわり無料が復活していた（利用者）"),
    ("1891672055038333368", "久しぶりの松屋で朝定食（利用者）"),
    ("1909497241926353118", "コメダのモーニング。11時までドリンクを頼むとパンがつく（利用者）"),
    ("2041326899625161211", "コメダのモーニングを食べてそのまま買い物へ（利用者）"),
    ("1828930565221056661", "なか卯のモーニング限定定食を紹介（BuzzFeed Japan）"),
    ("1789193494625718320", "松屋の牛皿エッグ定食530円。販売時間は5時から11時（進撃のグルメ）"),
    ("2092386667873403090", "コメダ公式：モーニングは毎朝開店から午前11時まで"),
]

out = ["# 500円モーニング：X の実投稿（053）", "",
       "**ここに出た本文・表示名・日付だけを記事に貼る。検索結果の抜粋は使わない。**",
       "**宣伝ではなく体験の投稿を優先すること。**", ""]

for tid, memo in TWEETS:
    out += [f"## `{tid}` — {memo}", ""]
    ok = False
    for u in (f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=ja&token=a",
              f"https://api.fxtwitter.com/i/status/{tid}"):
        try:
            j = json.loads(get(u))
        except Exception as e:
            out.append(f"- `{u.split('?')[0]}` 失敗（{type(e).__name__}）")
            continue
        t = j.get("text") or (j.get("tweet") or {}).get("text") or ""
        usr = j.get("user") or (j.get("tweet") or {}).get("author") or {}
        if not t:
            out.append(f"- `{u.split('?')[0]}` 本文が空だった")
            continue
        out += ["```",
                f"name   : {usr.get('name','')}",
                f"handle : @{usr.get('screen_name','')}",
                f"date   : {j.get('created_at') or (j.get('tweet') or {}).get('created_at','')}",
                "text   :", t, "```", ""]
        ok = True
        break
    if not ok:
        out += ["**取得できなかった。この投稿は記事に貼らないこと。**", ""]

open(f"{RDIR}/morning-tweets.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1200])
PYEOF
