#!/bin/bash
# 058 と同じ巡回で走らせる。500円モーニング記事に貼る X の実投稿を確定させる。
#
# 記事にまだ X が無いチェーン（マクドナルド・すき家）を狙う。
# **すき家の金額は公式から取れず、記事の値段の表には入れていない。**
# 利用者の投稿を貼るときは「公式の表示ではない」と分かる書き方にすること。
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
    ("② マクドナルド", "1725824106665578689", "モバイルオーダーと朝10時台の締切の話"),
    ("② マクドナルド", "2054777614100046002", "朝マックにビッグマックも売ってほしい"),
    ("⑧ すき家",       "2043861052358860830", "まぜのっけ朝食 330円・〜11時まで"),
    ("⑧ すき家",       "1903804148522660112", "まぜのっけ朝食 290円（2025年3月時点）"),
]

out = ["# 500円モーニング記事の X 追加分（059）", "",
       "**ここに出た本文・表示名・日付だけを記事に貼る。**",
       "**すき家の金額は公式から取れていない。**利用者の投稿の金額を、",
       "記事の値段の表に混ぜないこと。貼るなら「利用者の投稿であって公式の表示ではない」と分かる形で。", ""]

for fac, tid, memo in TWEETS:
    out += [f"### `{tid}` — {fac}（メモ: {memo}）", ""]
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

open(f"{RDIR}/morning-tweets2.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1200])
PYEOF
