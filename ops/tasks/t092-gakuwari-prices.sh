#!/bin/bash
# **学割の料金を、各社の公式ページの実物から取る。**
#
# 記事「大人こそ放送大学で学割」を書くための裏取り。
# **二次情報だと数字が割れている**（Spotify は 980→480 と 1,080→580 の両方が出てくる）。
# まとめサイトを根拠にしない（blog-article スキル §3）ので、公式の本文を読む。
#
# ## なぜ Mac に投げるか
#
# クラウドセッションは外へ出られない（CONNECT 403）。**取ってくるところだけ** Mac にやらせる。
#
# ## やること
#
# 公式ページの HTML からタグを落とし、**「円」を含む行の周辺だけ**を抜き出す。
# 全文を載せると公開リポジトリが重くなるうえ、読むのも大変になる。
#
# **判断はしない。** 数字を拾うのはこのタスク、採否はクラウド側。
#
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t092-gakuwari-prices.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import contextlib, datetime as dt, html, re, socket, sys, time
import urllib.error, urllib.request

OUT = sys.argv[1]
BUDGET = 200.0

TARGETS = [
 ("放送大学 学費",      "https://www.ouj.ac.jp/admission/gakubu/tuition/"),
 ("放送大学 学生の種類", "https://www.ouj.ac.jp/gakubu/about/type/"),
 ("Prime Student",     "https://www.amazon.co.jp/primestudent"),
 ("Spotify 学割",      "https://www.spotify.com/jp-ja/student/"),
 ("YouTube Premium 学割","https://support.google.com/youtube/answer/9158808?hl=ja"),
 ("Adobe 学生・教職員版","https://www.adobe.com/jp/creativecloud/buy/students.html"),
 ("Adobe 購入資格",     "https://www.adobe.com/jp/creativecloud/roc/offer-terms/student-eligibility.html"),
 ("Microsoft 365",     "https://www.microsoft.com/ja-jp/microsoft-365/buy/compare-all-microsoft-365-products"),
 ("TOHOシネマズ 料金",  "https://www.tohotheater.jp/service/price.html"),
]

_ORIG = socket.getaddrinfo
def _v4(h, p, family=0, type=0, proto=0, flags=0):
    return _ORIG(h, p, socket.AF_INET, type, proto, flags)

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

UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      "Accept-Language": "ja,en;q=0.8"}

def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=40) as r:
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
    lines = [re.sub(r"\s+", " ", x).strip() for x in h.split("\n")]
    return [x for x in lines if x]

L = ["# 学割の料金（t092・公式ページの実物）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", "",
     "**まとめサイトではなく公式の本文から拾った行。** 採否はクラウド側で判断する。", ""]

t0, done = time.time(), 0
for name, url in TARGETS:
    if time.time() - t0 > BUDGET:
        L.append(f"⚠️ **打ち切り。** 残り {len(TARGETS) - done} 件は次のタスクで。")
        break
    done += 1
    L += [f"## {name}", "", f"`{url}`", ""]
    try:
        body = retry_ipv4(lambda u=url: fetch(u))
    except urllib.error.HTTPError as e:
        L += [f"❌ HTTP {e.code}", ""]
        continue
    except Exception as e:
        L += [f"❌ {type(e).__name__}: {str(e)[:140]}", ""]
        continue
    lines = textify(body)
    # **「円」を含む行と、その直前の行**（見出しや項目名が前の行にあることが多い）
    hits, seen = [], set()
    for i, ln in enumerate(lines):
        if len(ln) > 120 or not re.search(r"[0-9][0-9,]*\s*円", ln):
            continue
        ctx = (lines[i-1][:60] + " ／ " if i and len(lines[i-1]) <= 60 else "") + ln
        if ctx not in seen:
            seen.add(ctx); hits.append(ctx)
    L.append(f"取れた行: {len(lines)} 行中 **{len(hits)} 行**に金額")
    L.append("")
    if hits:
        L.append("```")
        L += hits[:28]
        L.append("```")
    else:
        L.append("（金額を含む行が無い。JS で描画している可能性）")
    L.append("")

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
exit 0
