#!/bin/bash
# ① サウナ記事で料金が埋まっていない施設を、検索で場所を確かめた公式ページから取る。
# ② ららぽーと記事に入れる X の実投稿を、syndication API で本文ごと確認する。
#
# 044 は「検索エンジンを Mac 側から叩く」設計で全滅した（DOCTYPE の w3.org しか拾えなかった）。
# 今回は**クラウド側の WebSearch で URL を先に確定させてある**ので、ここでは取得だけをする。
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
import json, re, sys, urllib.request

RDIR = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

def get(u, t=35):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

JP = re.compile(r"[ぁ-んァ-ヶ一-龠]")
PRICE = re.compile(r"円|料金|税込|税抜|平日|土日|祝|分|時間|営業|定休|レディース|女性|男性")

def digest(html, limit=90):
    h = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", html)
    h = re.sub(r"(?s)<[^>]+>", "\n", h)
    for a, b in (("&nbsp;", " "), ("&amp;", "&"), ("&quot;", '"'), ("&#039;", "'"), ("&yen;", "¥")):
        h = h.replace(a, b)
    out, seen = [], set()
    for l in (x.strip() for x in h.split("\n")):
        if not l or l in seen or len(l) > 160 or len(l) < 2:
            continue
        if not (JP.search(l) and PRICE.search(l)):
            continue
        seen.add(l); out.append(l)
    return out[:limit]

# ---------- ① サウナ：料金が埋まっていない施設の公式 ----------
SAUNA = [
    ("shiagaru", "SHIAGARU SAUNA 神田×秋葉原", [
        "https://shiagaru-sauna.com/tokyo-kanda-akihabara"]),
    ("jyoshin", "サウナ蒸薪（埼玉・北本）", [
        "https://www.sauna-jyoshin.com/price", "https://www.sauna-jyoshin.com/"]),
    ("kohaku", "sauna KOHAKU（千葉・柏）", [
        "https://sauna-kohaku.com/price/", "https://sauna-kohaku.com/"]),
    ("spaeas", "横浜天然温泉 SPA EAS", [
        "https://spa-eas.com/price/", "https://spa-eas.com/information/177/"]),
    ("kaizoku", "海賊サウナ＆カプセルホテル（小田原）", [
        "https://camp-fire.jp/projects/909144/view"]),
]

out = ["# サウナの料金（公式）と ららぽーとの X 投稿", "",
       "**推測値は書かない。取れなかったものは「取れなかった」と残す。**", "",
       "## ① サウナ：料金未確認の施設", ""]

for key, label, pages in SAUNA:
    out += [f"### {key} — {label}", ""]
    for p in pages:
        try:
            html = get(p)
        except Exception as e:
            out.append(f"- `{p}` 取得できず（{type(e).__name__}: {e}）")
            continue
        d = digest(html)
        if d:
            out += [f"#### `{p}`", "", "```"] + d + ["```", ""]
        else:
            out.append(f"- `{p}` 料金らしい記述が拾えなかった（JS 描画の可能性）")
    out.append("")

# ---------- ② ららぽーと：X の実投稿 ----------
# クラウド側の検索で「実在すること」まで確認済みの ID。本文はここで取って確定させる。
TWEETS = [
    ("2048718801722904826", "TOKYO-BAY フードコートが TBS で特集・北館リニューアル後の混雑"),
    ("1993285517245661385", "TOKYO-BAY のフードエリア リニューアル後に行った体験"),
    ("1831308774528975161", "ららぽーと横浜のフードコート"),
    ("2081597719945318768", "ららぽーと豊洲のフードコートで昼食"),
    ("2012747254998675893", "ラゾーナ川崎の閉店ラッシュ（住民の声）"),
    ("2079805226895188458", "ラゾーナ川崎プラザが過去最大級のリニューアル"),
    ("2023910335447790009", "ラゾーナ川崎プラザの休館"),
    ("1973646139191861501", "資さんうどんが TOKYO-BAY 北館フードコートに初出店"),
]

out += ["", "## ② ららぽーと：X の実投稿（syndication API で本文確定）", "",
        "**ここに出た本文・表示名・日付だけを記事に貼る。検索結果の抜粋は使わない。**", ""]

for tid, memo in TWEETS:
    out += [f"### `{tid}` — {memo}", ""]
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
        name = usr.get("name", "")
        handle = usr.get("screen_name", "")
        created = j.get("created_at") or (j.get("tweet") or {}).get("created_at", "")
        if not t:
            out.append(f"- `{u.split('?')[0]}` 本文が空だった")
            continue
        out += ["```", f"name   : {name}", f"handle : @{handle}",
                f"date   : {created}", "text   :", t, "```", ""]
        ok = True
        break
    if not ok:
        out += ["**取得できなかった。この投稿は記事に貼らないこと。**", ""]

open(f"{RDIR}/sauna-prices-lalaport-x.md", "w", encoding="utf-8").write("\n".join(out))
print("\n".join(out)[:1200])
PYEOF
