#!/bin/bash
# **業務スーパーのロゴを、利用者が指定した URL から取る（t119）。**
#
# 利用者の指摘（2026-09-20 17:31）:
#   「ロゴはこれ使って
#     https://play-lh.googleusercontent.com/05N6s2kPrcS7UA_YS7qHblsJ1Lzxo6C2MNat...」
#
# **クラウドからは googleusercontent に出られない**（403・実測）ので Mac に頼む。
# **URL は利用者が名指ししたものをそのまま使う。** 変えない。
#
# **商標であり自由ライセンスではない。** 識別目的で使う。取得元を残す。
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t119-gyomu-logo.md"
DIR="$RDIR/gyomu-logo"
mkdir -p "$DIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }
"$PY" -c "import PIL" 2>/dev/null || { echo "Pillow が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" "$DIR" <<'PYEOF'
import datetime as dt, io, json, sys, urllib.request
from PIL import Image

OUT, DIR = sys.argv[1], sys.argv[2]
URL = ("https://play-lh.googleusercontent.com/"
       "05N6s2kPrcS7UA_YS7qHblsJ1Lzxo6C2MNatbOFA0tW4SEykbqihG2U9FRYXvenZwv_bpXfeSp3vAJRKV_OA")
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/125.0 Safari/537.36"}

L = ["# 業務スーパーのロゴ（t119・利用者の指定 URL）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**URL は利用者が名指ししたものをそのまま使っている。**", "", f"`{URL}`", ""]

try:
    req = urllib.request.Request(URL, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        blob = r.read()
    im = Image.open(io.BytesIO(blob)); im.load()
    w, h = im.size
    im.convert("RGBA").save(f"{DIR}/gyomu.png", "PNG", optimize=True)
    L += [f"✅ `gyomu.png` / {w}x{h} / {im.mode}", ""]
    man = {"_note": "利用者が指定した URL から取得した業務スーパーのロゴ。"
                    "**商標であり自由ライセンスではない。**識別目的で使う。改変しない。"
                    "取得日 " + dt.date.today().isoformat() + "（ops/tasks/t119-gyomu-logo-given.sh）。",
           "gyomu": {"brand": "業務スーパー", "file": "gyomu.png", "source": URL,
                     "source_type": "利用者の指定（Google Play のアイコン）",
                     "width": w, "height": h}}
    open(f"{DIR}/_manifest.json", "w", encoding="utf-8").write(
        json.dumps(man, ensure_ascii=False, indent=2))
    json.loads(open(f"{DIR}/_manifest.json", encoding="utf-8").read())
except Exception as e:
    L += [f"❌ {type(e).__name__}: {str(e)[:200]}", "",
          "**取れなかった。** URL が変わったか、Mac からも弾かれている。"]

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF
