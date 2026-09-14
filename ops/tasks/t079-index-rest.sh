#!/bin/bash
# **全 74 本のうち 55〜74 本目を調べる。**（t076 の続き）
#
# **t076 は 34 本で 246 秒 かかって打ち切られた。** 1 本あたり約 7 秒。
# 240 秒 の枠に収まるのは 30 本 程度なので、**残り 40 本を 20 本ずつに分ける**
# （最上位ルール 15「1 タスクは 5 分 以内」）。
#
# t075 で、大磯プリンス記事が「クロール済み - インデックス未登録」だと分かった。
# **この 1 本だけの問題なのか、サイト全体の問題なのかで打ち手が変わる。**
#
#   1 本だけ      → その記事をてこ入れする
#   何本もある    → サイト側（内部リンク・サイトマップ・品質評価）の問題
#
# ## やること
#
# GSC の URL 検査 API を全 74 本に対して 1 回ずつ叩き、`coverageState` を集計する。
#
# **時間の上限を自分で持つ。** 240 秒 を超えたら、そこで打ち切って
# 「何本 調べたか」を書く（最上位ルール 15。`timeout` は macOS に無いので使わない）。
#
# **URL の一覧はこのファイルに焼き込む。** Mac のクローンが main に追いついて
# いないことがあるため、リポジトリを読みにいかない（t067 が これで落ちた）。
#
# **トークンは絶対に出さない。** 出力は公開リポジトリに載る。
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの確認タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t079-index-rest.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import contextlib, datetime as dt, json, os, shutil, socket, subprocess, sys, time
import urllib.error, urllib.request

OUT = sys.argv[1]
SITE = "https://daily-hack.fieldbeside.com/"
SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
BUDGET = 240.0

PATHS = """/posts/qr-payment-comparison-2026/
/posts/rakuten-bank-referral/
/posts/rakuten-marathon-guide-2026/
/posts/sauna-openings-2026/
/posts/summer-cospa-travel-2026/
/posts/summer-electricity-saving-2026/
/posts/summer-travel-timesale-2026/
/posts/tokyo-bay-hanabi-2026/
/posts/tokyo-discount-supermarket-2026/
/posts/video-subscription-cost-per-view-2026/
/posts/visa-touch-30-cashback-2026-jun/
/posts/walk-poikatsu-2026/
/posts/wangan-august-events-2026/
/posts/wangan-festivals-2026/
/posts/wangan-money-guide-2026/
/posts/wangan-sauna-2026/
/posts/wangan-saving-spots-2026/
/posts/wangan-supermarkets-2026/
/posts/wangan-tower-construction-map-2026/
/posts/yodobashi-vs-amazon-rakuten-2026/""".strip().splitlines()

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

L = ["# インデックス状況 55〜74 本目（t079）", "",
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

open(OUT, "w").write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF
exit 0
