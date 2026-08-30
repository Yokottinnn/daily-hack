#!/bin/bash
# 500円モーニング記事に貼る YouTube を確定させる。
#
# この記事は **YouTube が 0 本**。X も 4 件だけで、1 チェーン 1 節の①〜⑧に映像が無い。
# oEmbed でタイトルと投稿者を照合する。**チェーン名が一致しないものは使わない。**
#
# **業態違いに注意。** 052 で「サンマルク」を拾ったら**ベーカリーレストラン側**で、
# サンマルク**カフェ**のモーニングではなかった。今回も同じ罠がある。
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

VIDEOS = [
    ("横断・導入", "FHbCPcKv3pA", "モーニングブーム再到来。各社が朝に注力するワケ（TBS）"),
    ("横断・導入", "xppiy8rmkQc", "ロイホ・コメダ・ドトールほか各社のモーニング"),
    ("横断・値段", "ocd38yBGI5k", "牛丼屋の朝食が400円以下でコスパ最強"),
    ("横断・値段", "1CpHGYDlNEM", "牛丼三社（吉野家・松屋・すき家）の朝定食比較"),
    ("① サンマルクカフェ", "MNwH_A4e_MQ", "最高の朝ごはんを探して サンマルクカフェ"),
    ("① サンマルクカフェ", "POSQG2QtcTM", "サンマルクカフェ モーニングセット"),
    ("② マクドナルド", "m4eMSseD8cU", "朝マックを全種類食べる"),
    ("③ モスバーガー", "3OcrFktC8v0", "モスバーガーモーニング 朝モス"),
    ("③ モスバーガー", "87zsZFyJkuA", "モスバーガーで朝食（9番街レトロ）"),
    ("④ コメダ珈琲店", "hq1qpXFeUyc", "コメダのモーニング全種類食い＆裏技"),
    ("④ コメダ珈琲店", "No3dB6xpTjU", "念願のモーニングを食べに行ってみたら最高だった"),
    ("⑧ すき家", "FAJmAo2CrnY", "牛まぜのっけを限界まで美味しくする"),
]

out = ["# 500円モーニング記事に貼る YouTube（058）", "",
       "**タイトルと投稿者がチェーンと一致するものだけ使う。**",
       "**業態違いに注意**（サンマルク＝ベーカリーレストラン／サンマルク**カフェ**は別）。",
       "**公式チャンネルの宣伝より、実際に食べている動画を優先すること。**", ""]

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

open(f"{RDIR}/morning-videos.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out))
PYEOF
