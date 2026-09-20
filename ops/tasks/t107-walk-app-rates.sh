#!/bin/bash
# **歩いてポイ活 20 アプリの「いくら貯まるか」を、提供元の説明文から取る（t107）。**
#
# 利用者の指摘（2026-09-20・下書きフィードバック）:
#   「各アプリがどれくらい稼げるかがちゃんと記載されていない。
#     すべてのサービスでどれくらい稼げるかをちゃんとリサーチして」
#
# 記事の仕様表には 正式名・提供元・費用・入手先 しか無く、
# **レートが書いてあるのは JAL / ANA / トリマ の 3 本だけ。**
#
# ## なぜ iTunes Lookup API か
#
# 各社の料率ページは JS で描くものが多い（ops-task-runner ルール 8）。
# **App Store の `description` は提供元が自分で書いた文**で、
# 「◯歩で◯ポイント」「◯コイン＝◯円」がそのまま書かれていることが多い。
# 静的な JSON で返るので確実に読める。
#
#   https://itunes.apple.com/jp/lookup?id=<ID>
#
# ID は記事本文の App Store リンクから取った（推測していない）。
# 楽天ヘルスケアだけリンクが無いので、日本語名で検索する。
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t107-walk-app-rates.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import datetime as dt, json, re, sys, time, urllib.error, urllib.parse, urllib.request

OUT = sys.argv[1]
BUDGET = 240.0
UA = {"User-Agent": "daily-hack-ops/1.0 (https://daily-hack.fieldbeside.com/)"}

APPS = [
    ("JAL Wellness & Travel", "1498726068"),
    ("ANA Pocket", "1598209192"),
    ("トリマ", "1502193377"),
    ("dヘルスケア", "1585068047"),
    ("アルコイン", "1449250359"),
    ("エブリポイント", "6743367643"),
    ("ポイすら", "6738946565"),
    ("楽天シニア", "1451690957"),
    ("Coke ON", "1088184021"),
    ("スギサポwalk+", "6737874561"),
    ("RenoBody", "879464961"),
    ("aruku&", "1165290449"),
    ("BitWalk", "1634543016"),
    ("HEALTHREE", "6449821527"),
    ("STEPN", "1598112424"),
    ("ステラウォーク", "1599065744"),
    ("Sweatcoin", "971023427"),
    ("住友生命 Vitality", "1352961017"),
    ("kencom", "1034656740"),
]
SEARCH = ["楽天ヘルスケア"]

# **レートが書いてある行だけを抜く。** 説明文は数千字あるので全部は載せない。
RATE = re.compile(r"[0-9０-９,]{2,}\s*(歩|ポイント|pt|P|コイン|マイル|円|スタンプ|スター|回|%)"
                  r"|1\s*日|1\s*か月|毎日|達成|交換|レート|還元|上限|抽選|付与")

def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8", "replace"))

def emit(name, r):
    # **`L += ...` を書くと L がローカル扱いになる**（t074 で 1 周 無駄にした）。
    global L
    L.append(f"- 正式名: {r.get('trackName','?')}")
    L.append(f"- 提供元: {r.get('sellerName','?')}")
    L.append(f"- 価格: {r.get('formattedPrice','?')}")
    L.append(f"- 更新: {(r.get('currentVersionReleaseDate') or '?')[:10]}")
    L.append(f"- 評価: {r.get('averageUserRating','?')}（{r.get('userRatingCount','?')} 件）")
    desc = (r.get("description") or "").replace("　", " ")
    hits, seen = [], set()
    for ln in desc.split("\n"):
        ln = re.sub(r"\s+", " ", ln).strip()
        if not ln or len(ln) > 160 or not RATE.search(ln):
            continue
        if ln not in seen:
            seen.add(ln); hits.append(ln)
    L.append(f"- 説明文から拾った行: **{len(hits)} 行**")
    L.append("")
    if hits:
        L.append("```")
        L += hits[:22]
        L.append("```")
    else:
        L.append("（レートらしい行が説明文に無い）")
    L.append("")

L = ["# 歩いてポイ活 20 アプリのレート（t107・提供元の説明文）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**App Store の description は提供元が書いた文。** 採否はクラウド側で判断する。", ""]

t0 = time.time()
for name, aid in APPS:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。** 残りは次のタスクで。")
        break
    L += [f"## {name}", "", f"`id={aid}`", ""]
    try:
        d = fetch(f"https://itunes.apple.com/jp/lookup?id={aid}")
    except Exception as e:
        L += [f"❌ {type(e).__name__}: {str(e)[:140]}", ""]
        continue
    res = d.get("results") or []
    if not res:
        L += ["❌ 該当なし（ID が変わったか、配信が終わった）", ""]
        continue
    emit(name, res[0])

for term in SEARCH:
    if time.time() - t0 > BUDGET:
        break
    L += [f"## {term}（検索）", ""]
    try:
        q = urllib.parse.urlencode({"term": term, "country": "jp",
                                    "entity": "software", "limit": "3"})
        d = fetch(f"https://itunes.apple.com/search?{q}")
    except Exception as e:
        L += [f"❌ {type(e).__name__}: {str(e)[:140]}", ""]
        continue
    for r in (d.get("results") or [])[:3]:
        L.append(f"### 候補: {r.get('trackName','?')} (`id={r.get('trackId','?')}`)")
        L.append("")
        emit(term, r)

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:40]))
PYEOF
