#!/bin/bash
# **20 アプリ全部の「いくら稼げるか」を、提供元の公式ページから取る（t110）。**
#
# 利用者の指摘（2026-09-20）:
#   「各アプリがどれくらい稼げるかがちゃんと記載されていない。
#     すべてのサービスでどれくらい稼げるかをちゃんとリサーチして。」
#
# t107 は App Store の説明文だけだった。**円に換算できるのは 7 件どまり。**
# 残りは抽選型・暗号資産型・ゲーム型で、**交換レートと上限**が分からないと円にできない。
# そこを公式のヘルプ・交換ページから取る。
#
# **JS で描くページは取れない**（ops-task-runner ルール 8）。
# 取れなければ「読めなかった」と分かる形で出す。**「無い」とは書かない。**
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t110-walk-earning-rates.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import datetime as dt, html, re, sys, time, urllib.error, urllib.parse, urllib.request

OUT = sys.argv[1]
BUDGET = 230.0
# **1 アプリ 1 起点。** 交換レート・上限・当選内容が書いてありそうなページを選ぶ。
SEEDS = [
    ("トリマ",          "https://www.trip-mile.com/faq"),
    ("ANA Pocket",      "https://www.ana.co.jp/ja/jp/guide/ana-pocket/"),
    ("JAL Wellness",    "https://www.jal.co.jp/jp/ja/jalmile/wellness/"),
    ("アルコイン",       "https://arucoin.jp/"),
    ("エブリポイント",   "https://every-point.jp/"),
    ("ポイすら",         "https://poisura.com/"),
    ("スギサポwalk",     "https://www.sugi-net.jp/sugisapo/walk/"),
    ("RenoBody",        "https://www.renobody.jp/"),
    ("aruku&",          "https://www.arukuto.jp/"),
    ("BitWalk",         "https://bitwalk.jp/"),
    ("ステラウォーク",   "https://stellarwalk.jp/"),
    ("Sweatcoin",       "https://sweatco.in/"),
    ("HEALTHREE",       "https://healthree.io/"),
    ("Vitality",        "https://vitality.sumitomolife.co.jp/"),
]
WANT = re.compile(r"交換|レート|ポイント|マイル|還元|上限|よくある|FAQ|ヘルプ|特典|使い方|貯め")
KEY = re.compile(r"[0-9][0-9,]*\s*(円|ポイント|マイル|pt|P|コイン|スタンプ|スター|マナ|歩)|"
                 r"交換|レート|上限|1日|1か月|月間|当選|抽選|還元")
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}

def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=25) as r:
        raw = r.read()
    for enc in ("utf-8", "cp932", "euc-jp"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", "replace")

def textify(h):
    h = re.sub(r"<(script|style|noscript)[^>]*>.*?</\1>", " ", h, flags=re.S | re.I)
    h = re.sub(r"<[^>]+>", "\n", h)
    h = html.unescape(h)
    return [x for x in (re.sub(r"\s+", " ", y).strip() for y in h.split("\n")) if x]

def links(base, body):
    out = {}
    for m in re.finditer(r'<a\s[^>]*href="([^"]+)"[^>]*>(.*?)</a>', body, re.S | re.I):
        text = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", html.unescape(m.group(2)))).strip()
        if not text or not WANT.search(text):
            continue
        u = urllib.parse.urljoin(base, html.unescape(m.group(1)))
        if urllib.parse.urlparse(u).netloc == urllib.parse.urlparse(base).netloc and u not in out:
            out[u] = text[:50]
    return out

def dump(label, url, note=""):
    # **`L.append` しかしなくても、関数内で L に代入があると全部ローカル扱いになる。**
    # t074・t107 で 2 回 踏んだので明示する（ops-task-runner ルール 6 の smoke test で検出）。
    global L
    L.append(f"### {label}{note}")
    L.append("")
    L.append(f"`{url}`")
    L.append("")
    try:
        page = fetch(url)
    except urllib.error.HTTPError as e:
        L += [f"❌ HTTP {e.code}", ""]
        return None
    except Exception as e:
        L += [f"❌ {type(e).__name__}: {str(e)[:120]}", ""]
        return None
    lines = textify(page)
    hits, seen = [], set()
    for j, ln in enumerate(lines):
        if len(ln) > 180 or not KEY.search(ln):
            continue
        ctx = (lines[j-1][:50] + " ／ " if j and len(lines[j-1]) <= 50 else "") + ln
        if ctx not in seen:
            seen.add(ctx); hits.append(ctx)
    L.append(f"取れた行: {len(lines)} 行中 **{len(hits)} 行**が該当")
    L.append("")
    if hits:
        L += ["```"] + hits[:22] + ["```"]
    else:
        L.append("（該当する行が無い。JS で描画している可能性）")
    L.append("")
    return page

L = ["# 20 アプリの「いくら稼げるか」・公式ページの実物（t110）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**交換レート・上限・当選内容を探している。** URL は推測していない。",
     "**取れなかったものは「読めなかった」であって「無い」ではない。**", ""]

t0 = time.time()
for name, seed in SEEDS:
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** {name} 以降は次のタスクで。")
        break
    L.append(f"## {name}")
    L.append("")
    body = dump("起点", seed)
    if not body:
        continue
    # **交換・FAQ へ 1 本だけ辿る。** 深追いすると 5 分を超える（最上位ルール 15）。
    got = links(seed, body)
    L.append(f"辿れるリンク **{len(got)} 本**")
    L.append("")
    for u, txt in list(got.items())[:2]:
        if time.time() - t0 > BUDGET:
            break
        dump(txt, u, "")

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
