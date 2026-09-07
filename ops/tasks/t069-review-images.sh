#!/bin/bash
# **レビューで指定された差し替え画像を取ってくる。**
#
# 2026-09-06 のレビューで、記事の写真 2 箇所に「おかしい」と指摘が入り、
# **差し替え先の URL が名指しで指定された。**
#
#   ロピア   … 39mag.thankyu.co.jp の 1 枚（指定は 1 つだけ）
#   ハナマサ … 3 つ提示され、この中から選ぶ
#
# アイキャッチのモザイクに使っている**寿司の写真も差し替える**必要があるため、
# ロピアの店舗写真はそちらにも回す。
#
# **クラウドセッションからは外に出られない**（EGRESS_BLOCKED）。Mac から取る。
#
# 出力: `$OPS_REPORT_DIR/review-images/` と `_sources.json`
# **秘密は出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの取得タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
DEST="$RDIR/review-images"
OUT="$RDIR/t069-review-images.md"
mkdir -p "$DEST"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

"$PY" - "$DEST" "$OUT" <<'PYEOF'
import json, os, sys, urllib.request

DEST, OUT = sys.argv[1], sys.argv[2]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      "Referer": "https://www.google.com/"}

# **レビューで名指しされた URL。当て推量では 1 つも足していない。**
WANT = [
    ("lopia-store", "https://39mag.thankyu.co.jp/wp-content/uploads/2025/09/07172457/"
                    "e151310d-8dc0-4d04-8d88-041a6bc12272-1.jpg"),
    ("hanamasa-a",  "https://sugamo.or.jp/wp-content/uploads/2020/02/"
                    "IMG_1221-e1687842698585-500x500.jpg"),
    ("hanamasa-b",  "https://hanamasa.co.jp/assets_c/2010/11/"
                    "top_chirashi_image_101106-thumb-290xauto-208.jpg"),
    ("hanamasa-c",  "https://blog.sotetsu-re.co.jp/wp-content/uploads/2024/02/2-6.jpg"),
]

L = ["# レビューで指定された差し替え画像（t069）", "",
     "**採用していない。落としただけ。** 実物を見てから選ぶ。", ""]
man = []

for name, url in WANT:
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=40) as r:
            b = r.read()
            ctype = r.headers.get("Content-Type", "?")
    except Exception as e:
        L.append(f"- ❌ `{name}` … 取得失敗 {type(e).__name__}: {str(e)[:160]}")
        L.append(f"  - {url}")
        continue

    ext = ".png" if b[:4] == b"\x89PNG" else ".webp" if b[8:12] == b"WEBP" else ".jpg"
    path = os.path.join(DEST, name + ext)
    with open(path, "wb") as f:
        f.write(b)

    # 寸法も出す。**小さすぎる画像は記事の図版には使えない。**
    dim = "?"
    try:
        from PIL import Image
        with Image.open(path) as im:
            dim = f"{im.size[0]}x{im.size[1]}"
    except Exception:
        pass

    L.append(f"- ✅ `{os.path.basename(path)}` … {len(b)//1024} KB / {dim} / {ctype}")
    L.append(f"  - {url}")
    man.append({"file": os.path.basename(path), "src": url, "size": dim, "bytes": len(b)})

with open(os.path.join(DEST, "_sources.json"), "w") as f:
    json.dump(man, f, ensure_ascii=False, indent=2)

L += ["", f"## 取れた {len(man)} / {len(WANT)} 枚"]
if len(man) < len(WANT):
    L.append("**取れなかったものがある。** 上の失敗理由を見て、別の手を考える。")

with open(OUT, "w") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF

echo "=== 落とした画像 ==="
ls -la "$DEST" 2>/dev/null
exit 0
