#!/bin/bash
# **「同じ商品」の値段が、各社の公表物から取れるかを実際に見に行く。**
#
# ## なぜ要るか
#
# 記事の「同じものがいくらか」という節が、**実際には同じものを比較していない。**
# 番組が測ったのは各社の看板商品（くるみパン／カツ丼／野菜詰め放題）で、別々の品目。
# 2026-09-08 のレビューで「これは大問題」と指摘された。
#
# ## 方針
#
# **まとめサイトや個人ブログは根拠にしない。** 各社が自分で出している
# チラシ・オンラインストア・特売ページだけを見る。
#
#   西友       … 公式チラシ（seiyu.co.jp/flyer/chirashi/）
#   業務スーパー … 最安値ページ ＋ オンラインショップ
#   ドン・キホーテ … WEBチラシ（donki.com/chirashi/）
#   肉のハナマサ … チラシ
#
# **URL は検索で実在を確認したものだけを直接指定し、それ以外はトップから辿る。**
# t056 で URL を当て推量して 8 ページ中 5 ページが 404 になった。同じ踏み方をしない。
#
# ## 何が分かればよいか
#
# **2 社以上に共通して出てくるナショナルブランド商品**（コカ・コーラ／カップヌードル／
# 明治ブルガリアヨーグルト など）。同じ型番が並べば、それが「同じもの」の比較になる。
# **無ければ「無かった」と書く。** 見つからないことも結論として使う。
#
# 出力は `$OPS_REPORT_DIR`。**秘密は出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの調査タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t070-same-sku.md"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import json, re, sys, urllib.parse, urllib.request

OUT = sys.argv[1]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"}
L = ["# 同じ商品の値段が取れるか（t070）", "",
     "**採用していない。取れるかどうかを見に行っただけ。**", ""]

def get(url, timeout=30):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")

def text_of(html):
    t = re.sub(r"<script.*?</script>|<style.*?</style>", " ", html, flags=re.S | re.I)
    t = re.sub(r"<[^>]+>", " ", t)
    return re.sub(r"\s+", " ", t)

# **ナショナルブランド＝どの店でも同じ型番で売っているもの。**
# ここに引っかかれば「同じもの」の比較ができる。
NB = [("コカ・コーラ", r"コカ・?コーラ"), ("カップヌードル", r"カップヌードル"),
      ("ブルガリアヨーグルト", r"ブルガリア"), ("サッポロ一番", r"サッポロ一番"),
      ("キューピーマヨネーズ", r"キユーピー|キューピー"), ("味の素", r"味の素"),
      ("ヤクルト", r"ヤクルト"), ("明治おいしい牛乳", r"おいしい牛乳"),
      ("森永", r"森永"), ("日清", r"日清"), ("サントリー", r"サントリー"),
      ("アサヒ", r"アサヒ"), ("キリン", r"キリン"), ("伊藤園", r"伊藤園")]
YEN = re.compile(r"(?:￥|¥)\s?([0-9,]{2,7})|([0-9,]{2,7})\s?円")

SITES = [
    ("西友 チラシ",         "https://www.seiyu.co.jp/flyer/chirashi/"),
    ("西友 トップ",         "https://www.seiyu.co.jp/"),
    ("業務スーパー 最安値",  "https://www.gyomusuper.jp/saiyasune.php"),
    ("業務スーパー 商品",    "https://www.gyomusuper.jp/product/index.php"),
    ("ドンキ WEBチラシ",    "https://www.donki.com/chirashi/"),
    ("ドンキ 商品情報",      "https://www.donki.com/products/"),
    ("ハナマサ トップ",      "https://hanamasa.co.jp/"),
    ("オーケー トップ",      "https://ok-corporation.jp/"),
]

found = {}
for label, url in SITES:
    L.append(f"## {label}")
    L.append(f"`{url}`")
    try:
        html = get(url)
    except Exception as e:
        L.append(f"- ❌ 取得失敗 {type(e).__name__}: {str(e)[:140]}")
        L.append("")
        continue
    t = text_of(html)
    L.append(f"- 取得できた（本文 {len(t):,} 字）")

    hits = []
    for name, pat in NB:
        for m in re.finditer(pat, t):
            s0, e0 = max(0, m.start() - 40), min(len(t), m.end() + 60)
            around = t[s0:e0]
            price = YEN.search(around)
            if price:
                val = price.group(1) or price.group(2)
                hits.append((name, val, around.strip()))
                found.setdefault(name, []).append((label, val))
                break
    if hits:
        L.append(f"- **ナショナルブランドの値段つき記載 {len(hits)} 件**")
        for name, val, around in hits[:12]:
            L.append(f"  - {name} … **{val}円** … `{around[:110]}`")
    else:
        # 値段そのものが拾えたかは別に見る（チラシが画像だけのことがある）
        n = len(YEN.findall(t))
        L.append(f"- ナショナルブランドの値段つき記載は 0 件（ページ内の価格らしき記載は {n} 件）")
        if n == 0:
            L.append("  - **価格が 1 件も無い＝チラシが画像だけの可能性が高い**")
    L.append("")

L.append("## 2 社以上に出てきた商品")
L.append("")
multi = {k: v for k, v in found.items() if len({x[0].split()[0] for x in v}) >= 2}
if multi:
    L.append("| 商品 | 店と値段 |")
    L.append("| --- | --- |")
    for k, v in multi.items():
        L.append(f"| {k} | " + " ／ ".join(f"{a} {b}円" for a, b in v) + " |")
    L.append("")
    L.append("**これが「同じもの」の比較に使える。**")
else:
    L.append("**1 件も無かった。** 公表物からは同じ商品の横並びは作れない。")
    L.append("その場合は、節の題を実際の中身に合わせて直すのが正しい。")

with open(OUT, "w") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF
exit 0
