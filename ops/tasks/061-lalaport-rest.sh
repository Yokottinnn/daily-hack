#!/bin/bash
# ららぽーと記事の**残りの施設**に貼る YouTube を確定させる。
#
# #300 / #305 で著名7施設（①②③⑤⑨⑪⑰）は入った。ここは残り13施設のうち、
# **素材が見つかった7施設**（⑩⑬⑭⑮⑯⑲⑳）を狙う。
#
# **見つからなかった6施設**（④柏の葉・⑥磐田・⑦新三郷・⑧和泉・⑫立川立飛・⑱堺）は
# **素材が無いまま出す。** 別の施設の動画で埋めない。
#
# oEmbed でタイトルと投稿者を照合する。**施設名が一致しないものは使わない。**
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
    ("⑩ 海老名",   "Q0qRR5doAbQ", "ららえびチャンネル"),
    ("⑬ 湘南平塚", "4aqYEMGenkg", "平塚市のららぽーと湘南平塚に行ってきた"),
    ("⑬ 湘南平塚", "4LGQpoXXvFI", "平塚駅からの道案内"),
    ("⑭ 名古屋みなとアクルス", "cQKFgd_K3jQ", "うんこミュージアム誕生へ"),
    ("⑭ 名古屋みなとアクルス", "RCLlSzq7yGM", "館内を歩く 2025年5月度"),
    ("⑮ 沼津",     "bmV8IsBoFa4", "開業から半年、人口・商店街への影響は？"),
    ("⑮ 沼津",     "moURPNvZtpQ", "ららぽーと沼津を歩く2024"),
    ("⑯ 愛知東郷", "5B6if7z4rS0", "館内を歩く 2025年3月度"),
    ("⑲ 門真",     "rZlrsDxcPw0", "パナの街に賑わいはよみがえるのか（関西テレビ）"),
    ("⑲ 門真",     "KQIxiF5N_Wk", "オープン初日 全フロア歩く"),
    ("⑳ 安城",     "Qe1EYYY-zrg", "商業施設では日本一の遊具を園児が体験"),
    ("⑳ 安城",     "yX_c-zvpX50", "ららぽーと安城を歩く 215店舗"),
]

out = ["# ららぽーと 残りの施設に貼る YouTube（061）", "",
       "**タイトルと投稿者が施設と一致するものだけ使う。**",
       "**素材が見つからなかった6施設**（④柏の葉・⑥磐田・⑦新三郷・⑧和泉・⑫立川立飛・⑱堺）は",
       "**素材が無いまま出す。別の施設の動画で埋めない。**", ""]

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

open(f"{RDIR}/lalaport-rest.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out))
PYEOF
