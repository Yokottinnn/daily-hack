#!/bin/bash
# 056 の続き。**③ 豊洲と ⑤ 横浜**の節にも動画を入れる。
#
# どちらも著名（豊洲は売上5位・効率2位、横浜は面積2位で3か年リニューアル中）なのに、
# 自分の節には動画が無い。056 では候補が集まらなかった 2 施設。
#
# YouTube は oEmbed でタイトルと投稿者を照合する。**施設名が一致しないものは使わない。**
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

VIDEOS = [
    ("③ 豊洲",  "ikQntFgH_Ns", "キッザニア東京に初めて行ってきた"),
    ("③ 豊洲",  "LfroADW7DEQ", "オジさんぽ アーバンドック ららぽーと豊洲編"),
    ("③ 豊洲",  "YYoeGgFr_KE", "アーバンドック ららぽーと豊洲を歩く"),
    ("⑤ 横浜",  "sIW4DfMelL8", "JR鴨居駅からのアクセス"),
    ("⑤ 横浜",  "rRuErXmF5X0", "地域情報動画サイト 街ログ"),
    ("⑤ 横浜",  "P7Vwdj0j53I", "日本初の Apple Premium Partner C smart ららぽーと横浜店"),
]

out = ["# ③豊洲・⑤横浜 の節に貼る YouTube（057）", "",
       "**タイトルと投稿者が施設と一致するものだけ使う。**",
       "**一致しないものは記事に貼らないこと。**", ""]

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

open(f"{RDIR}/lalaport-toyosu-yokohama.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out))
PYEOF
