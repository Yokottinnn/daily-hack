#!/bin/bash
# **スーパー 4 社の公式 X の直近投稿を取り直す（t114）。**
#
# t112 は X アカウントを 4 つ 特定できたが、**直近投稿は 4 件とも HTTP 429**
# （Too Many Requests）で取れなかった。**間隔を空けずに 4 連続で叩いたのが原因。**
#
#   オーケー @OK_EDLP / ロピア @lopia_official
#   トライアル @TRIALCOMPANY / 西友 @seiyu_japan
#
# **この 4 つは t112 が公式サイトから辿ったもの。** ここでも推測はしていない。
# 肉のハナマサは公式サイトに X のリンクが無かったので対象外。
#
# 1 件ごとに 20 秒 空ける（4 件で最大 80 秒）。**5 分 以内に収まる**（最上位ルール 15）。
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t114-super-x-timelines.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import datetime as dt, json, re, sys, time, urllib.error, urllib.request

OUT = sys.argv[1]
# t112 が**公式サイトから辿った**ハンドルだけ。推測で足さない。
HANDLES = [
    ("オーケー",   "OK_EDLP"),
    ("ロピア",     "lopia_official"),
    ("トライアル", "TRIALCOMPANY"),
    ("西友",       "seiyu_japan"),
]
GAP = 20.0
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}
KEY = re.compile(r"セール|特売|チラシ|割引|お買い得|クーポン|キャンペーン|"
                 r"[0-9][0-9,]*\s*円|[0-9]+\s*%\s*(引|OFF|オフ)|限定|本日|今週|ポイント")

def get(url, t=25):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

L = ["# スーパー 4 社の公式 X の直近投稿（t114）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**ハンドルは t112 が公式サイトから辿ったもの。** 推測で足していない。",
     "**429 で取れなかったものは「読めなかった」であって「無い」ではない。**", ""]

for i, (name, h) in enumerate(HANDLES):
    if i:
        time.sleep(GAP)          # **間隔を空ける。** t112 の 429 はこれが無かったため
    L.append(f"## {name}（@{h}）")
    L.append("")
    url = f"https://syndication.twitter.com/srv/timeline-profile/screen-name/{h}"
    try:
        page = get(url)
    except urllib.error.HTTPError as e:
        L += [f"❌ HTTP {e.code}"
              + ("（レート制限。次の周回で取り直す）" if e.code == 429 else ""), ""]
        continue
    except Exception as e:
        L += [f"❌ {type(e).__name__}: {str(e)[:120]}", ""]
        continue

    m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', page, re.S)
    if not m:
        L += ["（`__NEXT_DATA__` が無い。ページの作りが変わった可能性）", ""]
        continue

    # **JSON として読む。** 正規表現で抜くと改行やエスケープで壊れる。
    hits = []
    try:
        data = json.loads(m.group(1))
        stack = [data]
        seen = set()
        while stack:
            o = stack.pop()
            if isinstance(o, dict):
                t = o.get("full_text") or o.get("text")
                idv = o.get("id_str") or o.get("rest_id")
                if isinstance(t, str) and idv and idv not in seen:
                    seen.add(idv)
                    hits.append((idv, o.get("created_at", "?"), re.sub(r"\s+", " ", t)))
                stack.extend(o.values())
            elif isinstance(o, list):
                stack.extend(o)
    except Exception as e:
        L += [f"❌ JSON として読めなかった: {type(e).__name__}", ""]
        continue

    L.append(f"拾えた投稿 **{len(hits)} 件**")
    L.append("")
    rel = [x for x in hits if KEY.search(x[2])]
    L.append(f"うち特売・セールに関係するもの **{len(rel)} 件**")
    L.append("")
    for idv, when, t in rel[:8]:
        L += [f"- `{idv}` / {when}", "", "```", t[:300], "```", ""]
    if not rel:
        L.append("（特売に関する投稿が無かった。直近が新店告知などの可能性）")
        L.append("")

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
