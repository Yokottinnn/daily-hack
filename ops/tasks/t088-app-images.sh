#!/bin/bash
# **歩いてポイ活の 21 アプリについて、App Store の公式素材を取る。**
#
# ## 利用者の指摘（2026-09-18・下書きフィードバック）
#
#   「サービスのアプリ画面がない。App storeとか公式とかXから取得してきて、
#     全サービスでちゃんとサンプル画像として追加して。
#     アプリの画面がないとサービスのイメージがわかないからマストでやってね」
#   「アプリの紹介が1つもないのはNG。他のセクションもふくめて21個のアプリは全て紹介して」
#
# ## なぜ Mac に投げるか
#
# クラウドセッションは `itunes.apple.com` に **CONNECT 403** で届かない
# （2026-09-18 に実測）。**取ってくるところだけ** Mac にやらせる。
#
# ## 使うのは iTunes Search API（Apple の公開 API）
#
#   https://itunes.apple.com/search?term=<語>&country=jp&entity=software
#
# **スクレイプしない。** 返ってくるのは Apple が配信している公式の素材で、
# `trackName`（正式名）/ `sellerName`（提供元）/ `trackViewUrl`（App Store）/
# `artworkUrl512`（アイコン）/ `screenshotUrls`（掲載スクリーンショット）。
#
# **1 件目を無条件に採らない。** 候補を 3 件まで出して、**選ぶのはこちら**
# （blog-article スキル「候補は見て選ぶ」）。画像もキーごとに 3 候補ぶん落とす。
#
# ## 落とすもの
#
#   reports/appshots/<key>-<n>-icon.jpg     アイコン
#   reports/appshots/<key>-<n>-shot1.jpg    スクリーンショット 1 枚目
#   reports/appshots/_apps.json             名前・提供元・App Store URL の台帳
#
# **リサイズしない。** Mac に PIL がある保証が無い（ルール 14）。
# 縮小と切り抜きはクラウド側でやる（Pillow がある）。
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t088-app-images.md"
DIR="$RDIR/appshots"
mkdir -p "$DIR"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
LIST="$REPO/ops/data/walk-poikatsu-apps.json"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

if [ ! -f "$LIST" ]; then
  echo "🚨 \`$LIST\` が無い。クローンが main に追いついていない可能性。" | tee "$OUT"
  exit 0
fi

"$PY" - "$OUT" "$DIR" "$LIST" <<'PYEOF'
import contextlib, datetime as dt, json, shutil, socket, subprocess, sys, time
import urllib.error, urllib.parse, urllib.request

OUT, DIR, LIST = sys.argv[1], sys.argv[2], sys.argv[3]
BUDGET = 220.0

_ORIG = socket.getaddrinfo
def _v4(host, port, family=0, type=0, proto=0, flags=0):
    return _ORIG(host, port, socket.AF_INET, type, proto, flags)

@contextlib.contextmanager
def force_ipv4():
    socket.getaddrinfo = _v4
    try:
        yield
    finally:
        socket.getaddrinfo = _ORIG

def _unreachable(e):
    err = getattr(e, "reason", e)
    return isinstance(err, OSError) and err.errno in (-2, 65, 51, 113, 101)

def retry_ipv4(fn):
    try:
        return fn()
    except (urllib.error.URLError, OSError) as e:
        if not _unreachable(e):
            raise
        with force_ipv4():
            return fn()

UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"}

def get(url, binary=False):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=40) as r:
        b = r.read()
    return b if binary else json.loads(b)

SIPS = shutil.which("sips")   # macOS 標準。PIL があるとは限らない（ルール 14）

def shrink(path):
    """**640px に縮めて JPEG にする。** App Store の PNG は 1〜2MB あり、
    そのまま 40 枚 載せると 60MB を超えてブランチに置けない。
    `sips` は macOS に必ず入っている。無ければ縮めずにそのまま置く。"""
    if not SIPS:
        return
    subprocess.run([SIPS, "-Z", "640", "-s", "format", "jpeg", path, "--out", path],
                   capture_output=True)

apps = json.load(open(LIST, encoding="utf-8"))
L = ["# 歩いてポイ活 21 アプリの App Store 素材（t088）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**",
     f"対象: **{len(apps)} 件**", ""]

ledger, t0, done = {}, time.time(), 0
for a in apps:
    if time.time() - t0 > BUDGET:
        break
    done += 1
    key, label, term = a["key"], a["label"], a["term"]
    url = ("https://itunes.apple.com/search?"
           + urllib.parse.urlencode({"term": term, "country": "jp",
                                     "entity": "software", "limit": 3, "lang": "ja_jp"}))
    L.append(f"### `{key}` — {label}")
    L.append("")
    try:
        d = retry_ipv4(lambda u=url: get(u))
    except Exception as e:
        L += [f"❌ 検索で落ちた: {type(e).__name__}: {str(e)[:120]}", ""]
        continue
    results = d.get("results") or []
    if not results:
        L += ["❌ **App Store に該当なし。**（検索語を変えるか、公式サイトから取る）", ""]
        continue

    L += ["| # | 正式名 | 提供元 | App Store |", "| --- | --- | --- | --- |"]
    cand = []
    for n, r in enumerate(results, 1):
        name = (r.get("trackName") or "")[:60]
        seller = (r.get("sellerName") or "")[:40]
        view = r.get("trackViewUrl") or ""
        L.append(f"| {n} | {name} | {seller} | {view} |")
        shots = r.get("screenshotUrls") or r.get("ipadScreenshotUrls") or []
        got = []
        # **画像は上位 2 候補ぶんだけ。** 3 件目まで落とすと枚数が倍になる
        if n <= 2:
            for tag, src in (("icon", r.get("artworkUrl512") or r.get("artworkUrl100")),
                             ("shot1", shots[0] if shots else None)):
                if not src:
                    continue
                try:
                    b = retry_ipv4(lambda s=src: get(s, binary=True))
                except Exception:
                    continue
                fn = f"{key}-{n}-{tag}.jpg"
                open(f"{DIR}/{fn}", "wb").write(b)
                shrink(f"{DIR}/{fn}")
                got.append(fn)
        cand.append({"n": n, "name": name, "seller": seller, "view": view,
                     "files": got, "shots": len(shots)})
    L.append("")
    ledger[key] = {"label": label, "cat": a["cat"], "candidates": cand}

json.dump(ledger, open(f"{DIR}/_apps.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=2)

total_mb = sum(__import__("os").path.getsize(f"{DIR}/{f}")
               for f in __import__("os").listdir(DIR) if f.endswith(".jpg")) / 1e6
L += ["", "## まとめ", "",
      f"- 調べた: **{done} 件 / {len(apps)} 件**",
      f"- 画像の合計: **{total_mb:.1f} MB**（sips {'あり' if SIPS else '**無し＝縮小していない**'}）",
      f"- 台帳: `reports/appshots/_apps.json`",
      f"- 画像: `reports/appshots/<key>-<候補番号>-icon.jpg` / `-shot1.jpg`", ""]
if done < len(apps):
    L.append(f"⚠️ **{len(apps) - done} 件 が未取得。** 打ち切り。残りは次のタスクで。")
L += ["", "**1 件目を無条件に採らない。** 正式名と提供元が対象と一致する候補を",
      "クラウド側が目で見て選ぶ（blog-article スキル「候補は見て選ぶ」）。", ""]

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:40]))
PYEOF
exit 0
