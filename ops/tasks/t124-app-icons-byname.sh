#!/bin/bash
# **アプリのアイコンを「名前で検索して」取る（t124）。**
#
# t122 で ID 直指定をやったら、**6 件 中 3 件 が「見つからない」、
# 1 件 は別アプリだった**（楽天シニアのつもりが `Sing to You`）。
# ID を手で書くのが間違いの元なので、**検索 API で引き当てる。**
#
#   https://itunes.apple.com/search?term=<名前>&country=jp&entity=software
#
# **`trackName` / `sellerName` / `bundleId` を必ず出す。**
# 同名の別アプリを掴んでいないか、クラウド側が目で見て判断できるようにする。
# **判断はしない。** 採否はクラウド側で決める。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t124-app-icons.md"
DIR="$RDIR/app-icons"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, io, json, sys, time, urllib.parse, urllib.request
from PIL import Image

OUT, DIR = sys.argv[1], sys.argv[2]
BUDGET = 240.0
UA = {"User-Agent": "daily-hack-ops/1.0 (blog editorial use; github.com/Yokottinnn/daily-hack)"}

# (ファイル名, 記事上の表記, 検索語)
APPS = [
    ("torima",        "トリマ",                "トリマ 移動でマイルが貯まる"),
    ("arucoin",       "アルコイン",            "アルコイン 歩数"),
    ("sugisapo",      "スギサポwalk+",         "スギサポwalk"),
    ("rakutensenior", "楽天シニア",            "楽天シニア"),
    ("anapocket",     "ANA Pocket",            "ANA Pocket"),
    ("jalwellness",   "JAL Wellness & Travel", "JAL Wellness Travel"),
    ("bitwalk",       "BitWalk",               "BitWalk ビットウォーク"),
    ("healthree",     "HEALTHREE",             "HEALTHREE ヘルスリー"),
    ("poisura",       "ポイすら",              "ポイすら"),
    ("stellawalk",    "ステラウォーク",        "ステラウォーク"),
    ("stepn",         "STEPN",                 "STEPN"),
    ("sweatcoin",     "Sweatcoin",             "Sweatcoin"),
]

def gets(u, t=20):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read().decode("utf-8", "replace")

def getb(u, t=20):
    with urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=t) as r:
        return r.read()

L = ["# アプリのアイコン（名前で検索・t124）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**ID を手で書かず、検索 API で引き当てている。**",
     "`trackName` / `sellerName` / `bundleId` を必ず出す。**同名の別アプリを掴んで",
     "いないかは、クラウド側が目で見て判断する。**", ""]
man = {"_note": "識別目的で使うアプリアイコン。**商標であり自由ライセンスではない。**"
                "取得日 " + dt.date.today().isoformat() + "（ops/tasks/t124-app-icons-byname.sh）。"}
t0 = time.time()

for key, brand, term in APPS:
    if time.time() - t0 > BUDGET:
        L.append("⚠️ **打ち切り。**"); break
    L += [f"### {brand}", f"  - 検索語: `{term}`", ""]
    q = urllib.parse.urlencode({"term": term, "country": "jp",
                                "entity": "software", "limit": "3"})
    try:
        d = json.loads(gets(f"https://itunes.apple.com/search?{q}"))
    except Exception as e:
        L += [f"  - ✗ 検索が失敗（{type(e).__name__}）", ""]; continue
    rs = d.get("results") or []
    if not rs:
        L += ["  - ✗ **1 件 も出てこない。** 検索語を変える必要がある", ""]; continue

    # **上位 3 件 を全部 出す。** 1 件 目が正解とは限らない
    for i, r in enumerate(rs, 1):
        L.append(f"  - {i}. **{(r.get('trackName') or '?')[:48]}** "
                 f"／ 提供元 **{(r.get('sellerName') or '?')[:32]}** "
                 f"／ `{r.get('bundleId','?')}` ／ id {r.get('trackId','?')}")
    r = rs[0]
    url = r.get("artworkUrl512") or r.get("artworkUrl100")
    if not url:
        L += ["  - ✗ artworkUrl が無い", ""]; continue
    try:
        blob = getb(url)
        im = Image.open(io.BytesIO(blob)); im.load()
        w, h = im.size
        if w < 96:
            L += [f"  - ✗ {w}x{h}（小さすぎる）", ""]; continue
        im.convert("RGBA").save(f"{DIR}/{key}.png", "PNG", optimize=True)
        L.append(f"  - ✅ `{key}.png` / {w}x{h}（**1 件 目を保存した**）")
        man[key] = {"brand": brand, "file": f"{key}.png", "source": url,
                    "page": r.get("trackViewUrl", ""),
                    "store_name": r.get("trackName", ""),
                    "seller": r.get("sellerName", ""),
                    "license_note": "App Store の登録アイコン（商標）",
                    "width": w, "height": h}
    except Exception as e:
        L.append(f"  - ✗ {type(e).__name__}")
    L.append("")

open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
    json.dumps(man, ensure_ascii=False, indent=2))
json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())
open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:24]))
PYEOF
