#!/bin/bash
# **放送大学の「在籍ルール」を公式ページの実物から取る。**
#
# 利用者の指摘（2026-09-20・下書きフィードバック）:
#   「学生としての証書は10年くらい使えるっていうのをみたけど、それは本当？
#     ちゃんと調べて。1年間だけの短いスパンで見ないで」
#
# 参照元の X 投稿（t093 で取得）も **「月450円で10年間、大学生になれる」** と言っており、
# 引用元は **「10年間＋休学でさらに4年、14年間54,000円」** と書いている。
# **この 2 つの数字の根拠を公式で確かめる。**
#
# 拾うのは 在学期間・休学・学生証の有効期限・学割証・入学料。
# **t092 と違って「円」だけでは足りない**ので、年・期・在学・休学・学生証も拾う。
#
# **判断はしない。** 採否はクラウド側。
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t094-ouj-enrollment.md"
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
 ("学生の種類", "https://www.ouj.ac.jp/gakubu/about/type/"),
 ("学費", "https://www.ouj.ac.jp/admission/gakubu/tuition/"),
 ("FAQ 出願・入学", "https://www.ouj.ac.jp/help/faq/01/"),
 ("FAQ 履修・単位", "https://www.ouj.ac.jp/help/faq/03/"),
 ("FAQ 在学・異動", "https://www.ouj.ac.jp/help/faq/05/"),
 ("在学生の方へ", "https://www.ouj.ac.jp/for-students/"),
 ("卒業したい方", "https://www.ouj.ac.jp/reasons-to-choose-us/qualification/bachelor/"),
 ("科目だけ履修", "https://www.ouj.ac.jp/reasons-to-choose-us/school-credits-freely/"),
 ("入学資格", "https://www.ouj.ac.jp/admission/gakubu/requirement/"),
 ("入学の流れ", "https://www.ouj.ac.jp/admission/gakubu/flow/"),
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

KEY = re.compile(r"在学|在籍|休学|退学|除籍|学生証|有効期限|学割証|入学料|授業料|[0-9][0-9,]*\s*円|最長|[0-9]+\s*年間|[0-9]+\s*年次|[0-9]+\s*学期")

L = ["# 放送大学の在籍ルール（t094・公式ページの実物）", "",
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
        if len(ln) > 200 or not KEY.search(ln):
            continue
        ctx = (lines[i-1][:60] + " ／ " if i and len(lines[i-1]) <= 60 else "") + ln
        if ctx not in seen:
            seen.add(ctx); hits.append(ctx)
    L.append(f"取れた行: {len(lines)} 行中 **{len(hits)} 行**が該当")
    L.append("")
    if hits:
        L.append("```")
        L += hits[:40]
        L.append("```")
    else:
        L.append("（該当する行が無い。JS で描画している可能性）")
    L.append("")

open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")
print("\n".join(L[:30]))
PYEOF
exit 0
