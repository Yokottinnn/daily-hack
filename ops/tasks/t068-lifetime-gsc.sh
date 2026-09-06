#!/bin/bash
# **累計の数字を GSC 全期間から取る。t067 の作り直し。**
#
# ## t067 がなぜ落ちたか
#
#   weekly-blog-report.py が無い: /Users/ny/projects/anta-baka-x/blog/scripts/
#
# パスは合っている。**Mac 側のクローンが main に追いついていない**だけ。
# `weekly-blog-report.py` は今日マージしたばかりで、まだ pull されていない。
#
# ## 直し方
#
# **リポジトリのファイルに依存しない。** 認証も API 呼び出しも IPv4 の回避も
# このタスクの中に書く。**当て推量ではなく、`weekly-blog-report.py` から写した実装。**
#
# ## 前提（t064 で確認済み）
#
# Cloudflare は累計を答えられない。13 週 2 日が API の上限で、90 日で 0 が返る＝
# **保持は実質 30 日**。累計を出せる可能性があるのは GSC だけ。
#
# **クリックは延べであってユニークユーザー数ではない。** そこは混ぜない。
#
# 出力は `$OPS_REPORT_DIR`。**トークンは絶対に出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの確認タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t068-lifetime-gsc.md"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

"$PY" - "$OUT" <<'PYEOF'
import contextlib, datetime as dt, json, os, shutil, socket, subprocess, sys
import urllib.request, urllib.error

OUT = sys.argv[1]
SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
SITE = "https://daily-hack.fieldbeside.com/"
API = "https://searchconsole.googleapis.com/webmasters/v3/sites/{}/searchAnalytics/query"

_ORIG = socket.getaddrinfo

def _ipv4_only(host, port, family=0, type=0, proto=0, flags=0):
    return _ORIG(host, port, socket.AF_INET, type, proto, flags)

@contextlib.contextmanager
def force_ipv4():
    socket.getaddrinfo = _ipv4_only
    try:
        yield
    finally:
        socket.getaddrinfo = _ORIG

def _unreachable(e):
    err = getattr(e, "reason", e)
    return isinstance(err, OSError) and err.errno in (-2, 65, 51, 113, 101)

def retry_ipv4(fn):
    """まず素のまま試し、経路が無ければ IPv4 だけでやり直す。
    **Mac は AAAA を引けても IPv6 経路が無いことがある。**"""
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

def token():
    g = find_gcloud()
    if not g:
        raise RuntimeError("gcloud が見つからない")
    env = dict(os.environ)
    env["CLOUDSDK_PYTHON"] = sys.executable
    r = subprocess.run([g, "auth", "print-access-token", f"--account={SA}",
                        "--scopes=https://www.googleapis.com/auth/webmasters"],
                       capture_output=True, text=True, env=env)
    if r.returncode != 0:
        # **トークンは絶対に出さない。** 出すのは gcloud のエラーだけ。
        raise RuntimeError("gcloud 認証失敗 rc=%d: %s"
                           % (r.returncode, (r.stderr or "").strip().replace("\n", " ")[:300]))
    t = r.stdout.strip()
    if not t:
        raise RuntimeError("gcloud がトークンを返さなかった（rc=0）")
    return t

def query(tok, dims, start, end, limit=5000):
    body = json.dumps({"startDate": start, "endDate": end,
                       "dimensions": dims, "rowLimit": limit}).encode()
    req = urllib.request.Request(
        API.format(urllib.request.quote(SITE, safe="")), data=body,
        headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read()).get("rows", [])

L = ["# 累計の数字（t068 / GSC 全期間）", ""]
today = dt.date.today()
start = (today - dt.timedelta(days=480)).isoformat()   # GSC の保持は 16 か月
end = (today - dt.timedelta(days=2)).isoformat()       # 確定していない直近 2 日は外す
L += [f"対象: **{start} 〜 {end}**（GSC の保持上限 16 か月）", ""]

def bail(msg):
    L.append(msg)
    open(OUT, "w").write("\n".join(L) + "\n")
    print("\n".join(L))
    raise SystemExit(1)

try:
    tok = retry_ipv4(token)
except Exception as e:
    bail(f"⚠️ **認証で落ちた。** {type(e).__name__}: {str(e)[:300]}")

try:
    pages = retry_ipv4(lambda: query(tok, ["page"], start, end))
    queries = retry_ipv4(lambda: query(tok, ["query"], start, end))
    dates = retry_ipv4(lambda: query(tok, ["date"], start, end))
except Exception as e:
    bail(f"⚠️ **取得で落ちた。** {type(e).__name__}: {str(e)[:300]}")

clicks = sum(r.get("clicks", 0) for r in pages)
imps = sum(r.get("impressions", 0) for r in pages)

L += ["## 合計", "", "| 項目 | 値 |", "| --- | --- |",
      f"| クリック（**延べ**） | **{clicks:,.0f}** |",
      f"| 表示回数 | {imps:,.0f} |",
      f"| CTR | {(clicks / imps * 100 if imps else 0):.2f}% |",
      f"| クリックのあった記事 | {sum(1 for r in pages if r.get('clicks', 0) > 0)} 本 |",
      f"| 表示のあった記事 | {len(pages)} 本 |",
      f"| クリックのあった検索語 | {sum(1 for r in queries if r.get('clicks', 0) > 0)} 語 |",
      f"| データのある日数 | {len(dates)} 日 |", ""]

if dates:
    ds = sorted(r["keys"][0] for r in dates)
    L += [f"**実際にデータがあるのは {ds[0]} 〜 {ds[-1]}。** ここが計測の開始日と見てよい。", ""]

L += ["## 注意", "",
      "**クリックは延べで、ユニークユーザー数ではない。** 同じ人が 3 回 来れば 3 と数える。",
      "GSC はユニークユーザーを出さない指標なので、**「累計何人」は GSC からは出ない。**",
      "Cloudflare も保持が実質 30 日なので出ない（t064）。",
      "**累計のユニークユーザーを知りたいなら、別の計測を入れるしかない。**", ""]

L += ["## クリック上位 15 本", "", "| 記事 | クリック | 表示 | 平均順位 |", "| --- | --- | --- | --- |"]
for r in sorted(pages, key=lambda x: -x.get("clicks", 0))[:15]:
    u = r["keys"][0].replace("https://daily-hack.fieldbeside.com", "")
    L.append(f"| `{u}` | {r.get('clicks',0):.0f} | {r.get('impressions',0):.0f} | {r.get('position',0):.1f} |")
L.append("")

L += ["## クリック上位 15 語", "", "| 検索語 | クリック | 表示 | 平均順位 |", "| --- | --- | --- | --- |"]
for r in sorted(queries, key=lambda x: -x.get("clicks", 0))[:15]:
    L.append(f"| {r['keys'][0]} | {r.get('clicks',0):.0f} | {r.get('impressions',0):.0f} | {r.get('position',0):.1f} |")

open(OUT, "w").write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF
exit 0
