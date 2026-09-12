#!/bin/bash
# **記事が実際に Google にインデックスされているかを、GSC の URL 検査 API で確かめる。**
#
# ## なぜ要るか
#
# ページ側のシグナルは全部 正しいことをビルド後の HTML で確認済み。
#
#   canonical … 自己参照で正しい      meta robots … 無し（noindex なし）
#   sitemap  … 507 URL 中に載っている  robots.txt … Allow: /
#   構造化データ … WebSite / Article / BreadcrumbList の 3 本
#   内部リンク … 67 ページから被リンク（トップ・カテゴリ2つ・RSS を含む）
#
# **だが「正しく出している」と「拾われている」は別。** Google が実際に
# インデックスしたかは GSC でしか分からない。当て推量で「されています」と言わない。
#
# ## 何を見るか
#
# URL 検査 API（`urlInspection/index:inspect`）で、記事 5 本の
# `coverageState` / `indexingState` / `lastCrawlTime` / `robotsTxtState` を出す。
#
#   verdict           PASS / NEUTRAL / FAIL
#   coverageState     「送信して登録されました」「検出 - インデックス未登録」など
#   lastCrawlTime     **これが無ければ、そもそも来ていない**
#
# 新しい記事だけでなく既存の当たり記事も見る。**全部 未登録なら site 全体の問題、
# 新しいものだけ未登録なら単に時間の問題**、と切り分けられる。
#
# 出力は `$OPS_REPORT_DIR`。**トークンは絶対に出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの確認タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t071-index-status.md"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import contextlib, json, os, shutil, socket, subprocess, sys
import urllib.request, urllib.error

OUT = sys.argv[1]
SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
SITE = "https://daily-hack.fieldbeside.com/"
API = "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect"

# **Mac は AAAA を引けても IPv6 経路が無いことがある**（t064 で実測）。
_ORIG = socket.getaddrinfo
def _v4(host, port, family=0, type=0, proto=0, flags=0):
    return _ORIG(host, port, socket.AF_INET, type, proto, flags)

@contextlib.contextmanager
def force_ipv4():
    socket.getaddrinfo = _v4
    try: yield
    finally: socket.getaddrinfo = _ORIG

def _unreachable(e):
    err = getattr(e, "reason", e)
    return isinstance(err, OSError) and err.errno in (-2, 65, 51, 113, 101)

def retry_ipv4(fn):
    try:
        return fn()
    except (urllib.error.URLError, OSError, subprocess.SubprocessError) as e:
        if not _unreachable(e): raise
        with force_ipv4(): return fn()

def find_gcloud():
    if os.environ.get("GCLOUD_BIN") and os.access(os.environ["GCLOUD_BIN"], os.X_OK):
        return os.environ["GCLOUD_BIN"]
    if shutil.which("gcloud"): return shutil.which("gcloud")
    for c in ("/opt/homebrew/bin/gcloud", "/usr/local/bin/gcloud",
              "/opt/homebrew/share/google-cloud-sdk/bin/gcloud",
              os.path.expanduser("~/google-cloud-sdk/bin/gcloud")):
        if os.access(c, os.X_OK): return c
    return None

def token():
    g = find_gcloud()
    if not g: raise RuntimeError("gcloud が見つからない")
    env = dict(os.environ); env["CLOUDSDK_PYTHON"] = sys.executable
    r = subprocess.run([g, "auth", "print-access-token", f"--account={SA}",
                        "--scopes=https://www.googleapis.com/auth/webmasters.readonly"],
                       capture_output=True, text=True, env=env)
    if r.returncode != 0:
        # **トークンは絶対に出さない。** 出すのは gcloud のエラーだけ。
        raise RuntimeError("gcloud 認証失敗 rc=%d: %s"
                           % (r.returncode, (r.stderr or "").strip().replace("\n", " ")[:300]))
    t = r.stdout.strip()
    if not t: raise RuntimeError("gcloud がトークンを返さなかった（rc=0）")
    return t

def inspect(tok, url):
    body = json.dumps({"inspectionUrl": url, "siteUrl": SITE}).encode()
    req = urllib.request.Request(API, data=body, headers={
        "Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())

URLS = [
    ("今回の記事",       SITE + "posts/tokyo-discount-supermarket-2026/"),
    ("直近の別記事",     SITE + "posts/ikea-toyosu-2026/"),
    ("当たっている記事", SITE + "posts/lalaport-guide-2026/"),
    ("湾岸スーパー",     SITE + "posts/wangan-supermarkets-2026/"),
    ("トップ",           SITE),
]

L = ["# インデックス状況（t071 / GSC URL 検査 API）", ""]

def bail(msg):
    L.append(msg); open(OUT, "w").write("\n".join(L) + "\n"); print("\n".join(L)); raise SystemExit(1)

try:
    tok = retry_ipv4(token)
except Exception as e:
    bail(f"⚠️ **認証で落ちた。** {type(e).__name__}: {str(e)[:300]}")

L += ["| ページ | verdict | 登録状態 | 最終クロール | robots | canonical(Google) |",
      "| --- | --- | --- | --- | --- | --- |"]
detail = []
for label, u in URLS:
    try:
        d = retry_ipv4(lambda u=u: inspect(tok, u))
    except Exception as e:
        L.append(f"| {label} | — | **取得失敗** {type(e).__name__} {str(e)[:60]} | — | — | — |")
        continue
    r = (d.get("inspectionResult") or {}).get("indexStatusResult") or {}
    L.append("| {} | {} | {} | {} | {} | {} |".format(
        label, r.get("verdict", "?"), r.get("coverageState", "?"),
        (r.get("lastCrawlTime") or "**無し**")[:19],
        r.get("robotsTxtState", "?"), (r.get("googleCanonical") or "?").replace(SITE, "/")))
    detail.append((label, u, r))

L.append("")
L.append("## 読み方")
L.append("")
L.append("- **`lastCrawlTime` が無い＝そもそも来ていない。** サイトマップに載っていても、クロール順が回ってきていないだけのことがある")
L.append("- `coverageState` が「検出 - インデックス未登録」なら、**知ってはいるが載せていない**")
L.append("- `googleCanonical` が自分と違うなら、**別ページの重複扱いにされている**")
L.append("")
L.append("## 生データ（各ページ）")
for label, u, r in detail:
    L.append("")
    L.append(f"### {label}")
    L.append(f"`{u}`")
    L.append("")
    L.append("```json")
    L.append(json.dumps(r, ensure_ascii=False, indent=2))
    L.append("```")

open(OUT, "w").write("\n".join(L) + "\n")
print("\n".join(L[:40]))
print(f"... 全文は {OUT}")
PYEOF
exit 0
