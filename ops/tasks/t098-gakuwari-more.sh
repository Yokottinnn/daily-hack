#!/bin/bash
# **学割の一覧を増やすための裏取り（t098）。**
#
# 利用者の指摘（2026-09-20・下書きフィードバック）:
#   「この一覧が浅すぎる。もっと大量にあるはずだから、ちゃんと調べて。
#     特に大人になっても使えるってなったらけっこうおいしいぞみたいなやつを
#     カテゴリ別に調べきって」
#
# **とくに確かめたいのは 2 つ。**
#   ① 国立科学博物館の大学パートナーシップに **放送大学が入っているか**
#      （国立美術館のほうは加入済みと公式に書いてある。科博は入会校一覧に
#        見あたらないが、**無いことを断定する前に一覧の実物を見る**）
#   ② 東京インターカレッジコープ（大学生協）の **加入条件と出資金**
#
# 拾うのは 放送大学・加入・対象・年齢・出資金・円。**判断はしない。**
# **秘密は出さない。** LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t098-gakuwari-more.md"
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
 ("科博 大学パートナーシップ 入会校一覧", "https://www.kahaku.go.jp/learning/university/partnership/enroll.php"),
 ("科博 大学パートナーシップ 特典", "https://www.kahaku.go.jp/learning/university/partnership/benefit.php"),
 ("東京インカレ 加入対象校", "https://tic-coop.com/school/"),
 ("東京インカレ 加入案内", "https://tic-coop.com/coop/join.php"),
 ("東京インカレ コープとは", "https://tic-coop.com/coop/"),
 ("TDR カレッジパスポート", "https://www.tokyodisneyresort.jp/dream/event/college2026.html"),
 ("日経電子版 学生キャンペーン", "https://www.nikkei.com/promotion/campaign/student/"),
 ("放送大学 証明書発行", "https://www.ouj.ac.jp/about/certificate/"),
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

KEY = re.compile(r"放送大学|加入|入会|対象|年齢|学生証|出資金|割引|無料|[0-9][0-9,]*\s*円|[0-9]+\s*%|[0-9]+\s*割")

L = ["# 学割の裏取り・2 巡目（t098・公式ページの実物）", "",
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
