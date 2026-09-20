#!/bin/bash
# **新しい 24 本のインデックス状況を測り直す（t131）。**
#
# **前に測ったのは t079（2026-09-15 01:27）で、もう 5 日 古い。**
# そのあいだに記事を直し、ロゴを 50 点 入れ、公開もしている。
# **「未インデックスが 9 本」という数字は、いまの状態の裏取りになっていない**
# （最上位ルール 11）。だから測り直す。
#
# ついでに**サイトマップを強制再送信する。**
# **注意: URL 検査 API は読み取り専用で、「インデックス登録をリクエスト」に
# 相当する公開 API は無い。** あのボタンは Search Console の画面にしかない。
# ここでできるのは「どれが入っていないかを確定させる」ことと「サイトマップを送る」ことまで。
#
# **トークンは絶対に出さない。** 出力は公開リポジトリに載る。
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t131-index-status.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import contextlib, datetime as dt, json, os, shutil, socket, subprocess, sys, time
import urllib.error, urllib.parse, urllib.request

OUT = sys.argv[1]
SITE = "https://daily-hack.fieldbeside.com/"
SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
BUDGET = 210.0

PATHS = """/posts/hoso-daigaku-gakuwari-2026/
/posts/walk-poikatsu-2026/
/posts/tokyo-discount-supermarket-2026/
/posts/ikea-toyosu-2026/
/posts/morning-500-2026/
/posts/odaiba-drone-show-2026/
/posts/sauna-openings-2026/
/posts/outlet-mall-guide-2026/
/posts/lalaport-guide-2026/
/posts/wangan-august-events-2026/
/posts/wangan-tower-construction-map-2026/
/posts/harumi-flag-koukai-2026/
/posts/budget-overseas-resorts-2026/
/posts/summer-electricity-saving-2026/
/posts/rakuten-marathon-guide-2026/
/posts/price-hike-2026-summer-defense/
/posts/paypay-card-gold-kaiaku-2026/
/posts/credit-card-campaign-2026-07/
/posts/yodobashi-vs-amazon-rakuten-2026/
/posts/narita-haneda-overseas-direct-2026/
/posts/tokyo-bay-hanabi-2026/
/posts/point-exchange-route-2026/
/posts/mortgage-refinance-breakeven-2026/
/posts/ideco-2026-reform-guide/""".strip().splitlines()

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
    except (urllib.error.URLError, OSError, subprocess.SubprocessError) as e:
        if not _unreachable(e):
            raise
        with force_ipv4():
            return fn()

def find_gcloud():
    env = os.environ.get("GCLOUD_BIN")
    if env and os.access(env, os.X_OK):
        return env
    if shutil.which("gcloud"):
        return shutil.which("gcloud")
    for c in ("/opt/homebrew/bin/gcloud", "/usr/local/bin/gcloud",
              "/opt/homebrew/share/google-cloud-sdk/bin/gcloud",
              os.path.expanduser("~/google-cloud-sdk/bin/gcloud")):
        if os.access(c, os.X_OK):
            return c
    return None

L = ["# インデックス状況（新しい 24 本・t131）", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**",
     f"対象: **{len(PATHS)} 本**（打ち切りは {BUDGET:.0f} 秒）", ""]

def bail(msg):
    L.append(msg)
    open(OUT, "w").write("\n".join(L) + "\n")
    print("\n".join(L))
    raise SystemExit(0)

g = find_gcloud()
if not g:
    bail("⚠️ gcloud が見つからない。")

env = dict(os.environ); env["CLOUDSDK_PYTHON"] = sys.executable

def get_token():
    r = subprocess.run([g, "auth", "print-access-token", f"--account={SA}",
                        "--scopes=https://www.googleapis.com/auth/webmasters.readonly"],
                       capture_output=True, text=True, env=env)
    if r.returncode != 0:
        # **トークンは絶対に出さない。** 出すのは gcloud のエラーだけ。
        raise RuntimeError("gcloud 認証失敗 rc=%d: %s"
                           % (r.returncode, (r.stderr or "").strip().replace("\n", " ")[:250]))
    t = r.stdout.strip()
    if not t:
        raise RuntimeError("gcloud がトークンを返さなかった（rc=0）")
    return t

try:
    tok = retry_ipv4(get_token)
except Exception as e:
    bail(f"⚠️ **認証で落ちた。** {type(e).__name__}: {str(e)[:250]}")

def inspect(path):
    body = json.dumps({"inspectionUrl": SITE.rstrip("/") + path,
                       "siteUrl": SITE, "languageCode": "ja-JP"}).encode()
    req = urllib.request.Request(
        "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect",
        data=body, method="POST",
        headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    d = json.loads(urllib.request.urlopen(req, timeout=45).read())
    return ((d.get("inspectionResult") or {}).get("indexStatusResult") or {})

t0 = time.time()
rows, errs, done = [], [], 0
for p in PATHS:
    if time.time() - t0 > BUDGET:
        break
    try:
        idx = retry_ipv4(lambda p=p: inspect(p))
        rows.append((p, idx.get("verdict", "—"), idx.get("coverageState", "—"),
                     (idx.get("lastCrawlTime") or "—")[:10],
                     idx.get("googleCanonical", "") or ""))
    except urllib.error.HTTPError as e:
        errs.append((p, f"HTTP {e.code}"))
    except Exception as e:
        errs.append((p, type(e).__name__))
    done += 1

took = time.time() - t0
L += [f"調べた: **{done} 本 / {len(PATHS)} 本**（{took:.0f} 秒）", ""]
if done < len(PATHS):
    L += [f"⚠️ **{len(PATHS) - done} 本 が未調査。** 打ち切り。残りは次のタスクで。", ""]

# 集計
agg = {}
for _, _, cov, _, _ in rows:
    agg[cov] = agg.get(cov, 0) + 1
L += ["## 登録状態の内訳", "", "| 状態 | 本数 |", "| --- | --- |"]
for k in sorted(agg, key=lambda x: -agg[x]):
    mark = "**" if "未登録" in k or "not indexed" in k.lower() else ""
    L.append(f"| {mark}{k}{mark} | {mark}{agg[k]}{mark} |")
L.append("")

bad = [r for r in rows if "未登録" in r[2] or "not indexed" in r[2].lower()]
L += [f"## インデックスに入っていない記事（{len(bad)} 本）", ""]
if bad:
    L += ["| 記事 | verdict | 状態 | 最終クロール |", "| --- | --- | --- | --- |"]
    for p, v, cov, crawl, _ in sorted(bad, key=lambda r: r[3]):
        L.append(f"| `{p}` | {v} | {cov} | {crawl} |")
else:
    L.append("**0 本。** 全部 入っている。")
L.append("")

# canonical が自分と違うもの（重複扱い）
dup = [r for r in rows if r[4] and r[4] != SITE.rstrip("/") + r[0]]
L += [f"## 別ページの重複扱いにされている記事（{len(dup)} 本）", ""]
if dup:
    L += ["| 記事 | Google の canonical |", "| --- | --- |"]
    for p, _, _, _, gc in dup:
        L.append(f"| `{p}` | `{gc.replace(SITE.rstrip('/'), '')}` |")
else:
    L.append("**0 本。**")
L.append("")

# クロールが古い順
crawled = [r for r in rows if r[3] != "—"]
never = [r for r in rows if r[3] == "—"]
L += [f"## 一度もクロールされていない記事（{len(never)} 本）", ""]
if never:
    L += ["| 記事 | 状態 |", "| --- | --- |"]
    for p, _, cov, _, _ in never:
        L.append(f"| `{p}` | {cov} |")
else:
    L.append("**0 本。**")
L.append("")

L += ["## 最終クロールが古い順（上位 20 本）", "",
      "| 記事 | 最終クロール | 状態 |", "| --- | --- | --- |"]
for p, _, cov, crawl, _ in sorted(crawled, key=lambda r: r[3])[:20]:
    L.append(f"| `{p}` | {crawl} | {cov} |")
L.append("")

if errs:
    L += [f"## 取れなかった {len(errs)} 本", "", "| 記事 | 理由 |", "| --- | --- |"]
    for p, why in errs:
        L.append(f"| `{p}` | {why} |")
    L.append("")

L += ["## 読み方", "",
      "- **「クロール済み - インデックス未登録」** = 見には来たが載せないと判断された。",
      "  内部リンクが弱い・内容が薄い・似た記事があるのどれかを疑う",
      "- **「検出 - インデックス未登録」** = まだ見にも来ていない。サイトマップとリンクの問題",
      "- **最終クロールが古い** = 更新されていないと見なされている。更新すると戻ってくることがある", ""]

# **サイトマップを強制再送信する。**
# URL 検査 API は読み取り専用なので、こちらから押せるのはここまで。
L += ["## サイトマップの再送信", ""]
try:
    tok2 = retry_ipv4(lambda: subprocess.run(
        [g, "auth", "print-access-token", f"--account={SA}",
         "--scopes=https://www.googleapis.com/auth/webmasters"],
        capture_output=True, text=True, env=env, check=True).stdout.strip())
    if not tok2:
        raise RuntimeError("トークンが空（rc=0）")
    sm = SITE + "sitemap-0.xml"
    url = ("https://www.googleapis.com/webmasters/v3/sites/"
           + urllib.parse.quote(SITE, safe="") + "/sitemaps/"
           + urllib.parse.quote(sm, safe=""))
    req = urllib.request.Request(url, method="PUT",
                                 headers={"Authorization": "Bearer " + tok2})
    code = retry_ipv4(lambda: urllib.request.urlopen(req, timeout=40).status)
    L.append(f"- `sitemap-0.xml` を送信した（HTTP {code}）")
except Exception as e:
    # **失敗を成功に見せない**（最上位ルール 13）
    L.append(f"- ✗ **送信できなかった。** {type(e).__name__}: {str(e)[:160]}")
L.append("")

open(OUT, "w").write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF
exit 0
