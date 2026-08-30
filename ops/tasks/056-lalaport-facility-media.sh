#!/bin/bash
# ららぽーと記事の「全20施設を1軒ずつ」の節に貼る、X の実投稿と YouTube を確定させる。
#
# 現状、①〜⑳ の節は**仕様表だけ**で、X も動画も入っていない。
# 著名な施設から順に、**個人ユーザーの投稿**と**訪問動画**を足して情報量と独自性を上げる。
#
# クラウド側の検索で**実在まで確認済みの ID** だけを渡している。
#   X       … cdn.syndication.twimg.com で本文・表示名・日付を取る
#   YouTube … oEmbed でタイトルと投稿者を照合する（施設名が一致しないものは使わない）
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
import json, sys, urllib.parse, urllib.request

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(u, t=30):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

# 施設, 動画ID, メモ
VIDEOS = [
    ("① TOKYO-BAY", "oSO1EPxwhPE", "新・北館グランドオープン初日"),
    ("① TOKYO-BAY", "dCWTVd1U_kw", "日本最大のフードコートで昼食"),
    ("① TOKYO-BAY", "3z9iAiT6dsY", "館内を歩く（4K）"),
    ("② 甲子園",     "nkC4qEWTs5M", "甲子園阪神パーク閉園後、跡地にららぽーと甲子園"),
    ("② 甲子園",     "ViD7VtYbGyc", "子連れファミリー向けの案内"),
    ("⑨ 富士見",     "D_2epodYW-o", "チームラボに行ってみた"),
    ("⑨ 富士見",     "ugp0kO3XWOg", "クロススポーツパーク"),
    ("⑪ EXPOCITY",  "aLFC92CY5Hg", "太陽の塔とエキスポシティ"),
    ("⑪ EXPOCITY",  "qRn8lbE8HgQ", "日本最大級の商業施設に初潜入"),
    ("⑰ 福岡",       "D6DOhJUDO1E", "ららぽーと福岡 徹底散策"),
    ("⑰ 福岡",       "pXa0mKxiokc", "νガンダム立像"),
    ("⑰ 福岡",       "OBf6xyEf6f4", "動く実物大の立像"),
    ("⑰ 福岡",       "ON05Rec2l6c", "SIDE-F に集う"),
]

# 施設, 投稿ID, メモ
TWEETS = [
    ("② 甲子園",    "1968852697651495145", "現ららぽーと甲子園の地にあった阪神パーク（レオポン）"),
    ("⑰ 福岡",      "1481469681055973376", "開業前の実物大νガンダムを見に行った（個人）"),
    ("⑪ EXPOCITY", "1970041551423483922", "観覧車の中の LOVOT に話しかけていた（個人）"),
    ("① TOKYO-BAY","2043164338505306509", "North Gate がリリイベ会場として名前が出始めた（個人）"),
    ("⑨ 富士見",    "2012663972038853005", "2026年に新規オープンする2店舗"),
]

out = ["# ららぽーと 各施設の節に貼る X と YouTube（056）", "",
       "**ここに出た本文・表示名・日付だけを記事に貼る。検索結果の抜粋は使わない。**",
       "**YouTube はタイトルと投稿者が施設と一致するものだけ使う。**",
       "**宣伝ではなく体験の投稿を優先すること。**", ""]

out += ["## YouTube（oEmbed で照合）", ""]
for fac, vid, memo in VIDEOS:
    u = ("https://www.youtube.com/oembed?format=json&url="
         + urllib.parse.quote(f"https://www.youtube.com/watch?v={vid}", safe=""))
    try:
        j = json.loads(get(u))
    except Exception as e:
        out.append(f"- `{vid}` **{fac}** — 取得できず（{type(e).__name__}）。**使わないこと**")
        continue
    out += [f"- `{vid}` **{fac}**（メモ: {memo}）",
            f"    - title  : {j.get('title','')}",
            f"    - author : {j.get('author_name','')}"]
out.append("")

out += ["## X（syndication API で本文確定）", ""]
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

open(f"{RDIR}/lalaport-facility-media.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1500])
PYEOF
