#!/bin/bash
# **累計でどこまで遡れるかを実測する。**
#
# 利用者の質問（2026-09-06）:「いままでのトータルのユニークユーザー数だと何人？」
#
# ## 先に断り
#
# **厳密なユニークユーザー数は出せない。** Cloudflare Web Analytics は
# 日をまたいだ同一人物の名寄せをしていない（ユーザー ID を持たない）ため、
# 期間を伸ばすと「延べ訪問数」になる。GSC も出るのはクリック数。
#
# **出せるのは 2 つ。**
#   - Cloudflare: 保持期間内の**延べ訪問数**（どこまで遡れるかを実測する）
#   - GSC: 全期間の**クリック / 表示**（16 か月遡れる）
#
# ## やること
#
#   30 / 90 / 180 / 365 日 で CF を引き、**どこで 0 になるか**を見る
#   → それが保持期間。手前の値が「取れる範囲での累計」
#   GSC は 16 か月と、月ごとの推移も出す
#
# **秘密は出さない。** IPv4 で叩く（IPv6 の経路が無い）。
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t064-lifetime.md"
mkdir -p "$RDIR"
TOK_FILE="$HOME/.config/daily-hack/cf-token"
[ -f "$TOK_FILE" ] || { echo "cf-token が無い" | tee "$OUT"; exit 1; }

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

echo "# 累計どこまで遡れるか（t064）" > "$OUT"

"$PY" - "$TOK_FILE" "$OUT" <<'PYEOF'
import datetime, json, socket, sys, urllib.request

tok = open(sys.argv[1]).read().strip()
OUT = sys.argv[2]
_o = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: [r for r in _o(*a, **k) if r[0] == socket.AF_INET] or _o(*a, **k)

def api(url):
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + tok})
    return json.loads(urllib.request.urlopen(req, timeout=40).read())

L = ["", "## Cloudflare（延べ訪問数。**ユニークユーザーではない**）", ""]
acc = (api("https://api.cloudflare.com/client/v4/accounts?per_page=5")
       .get("result") or [{}])[0].get("id")
if not acc:
    L.append("- アカウントが取れなかった")
else:
    q = """
    query($a: String!, $s: Time!, $e: Time!) {
      viewer { accounts(filter: {accountTag: $a}) {
        t: rumPageloadEventsAdaptiveGroups(
          limit: 1, filter: { datetime_geq: $s, datetime_leq: $e }
        ) { count sum { visits } }
      } }
    }"""
    end = datetime.date.today() - datetime.timedelta(days=1)
    L.append("| 期間 | ページビュー | 訪問（延べ） |")
    L.append("| --- | --- | --- |")
    for days in (7, 30, 90, 180, 365, 730):
        start = end - datetime.timedelta(days=days - 1)
        body = json.dumps({"query": q, "variables": {
            "a": acc, "s": f"{start}T00:00:00Z", "e": f"{end}T23:59:59Z"}}).encode()
        req = urllib.request.Request(
            "https://api.cloudflare.com/client/v4/graphql", data=body, method="POST",
            headers={"Content-Type": "application/json", "Authorization": "Bearer " + tok})
        try:
            d = json.loads(urllib.request.urlopen(req, timeout=60).read())
        except Exception as e:
            L.append(f"| {days} 日 | 失敗 | {type(e).__name__} |")
            continue
        if d.get("errors"):
            msg = json.dumps(d["errors"], ensure_ascii=False)[:120]
            L.append(f"| {days} 日 | — | **エラー**: {msg} |")
            continue
        a = ((d.get("data") or {}).get("viewer", {}).get("accounts") or [{}])[0]
        rows = a.get("t") or []
        if not rows:
            L.append(f"| {days} 日 | 0 | 0 |")
            continue
        r = rows[0]
        L.append(f"| {days} 日（{start}〜{end}） | {r.get('count')} | "
                 f"{(r.get('sum') or {}).get('visits')} |")

with open(OUT, "a") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF

# --- GSC は 16 か月遡れる ---------------------------------------
SCRIPT="${TMPDIR:-/tmp}/wbr.py"
git -C "$REPO" fetch -q origin main || true
git -C "$REPO" show origin/main:scripts/weekly-blog-report.py > "$SCRIPT" 2>/dev/null || true

{
  echo
  echo "## Google 検索（全期間・クリックは延べ）"
  echo '```'
} >> "$OUT"
"$PY" - "$OUT" <<'PYEOF' >> "$OUT" 2>&1
import datetime, json, os, shutil, socket, subprocess, sys, urllib.parse, urllib.request
_o = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: [r for r in _o(*a, **k) if r[0] == socket.AF_INET] or _o(*a, **k)

SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
SITE = "https://daily-hack.fieldbeside.com/"
g = shutil.which("gcloud") or "/opt/homebrew/bin/gcloud"
env = dict(os.environ); env["CLOUDSDK_PYTHON"] = sys.executable
r = subprocess.run([g, "auth", "print-access-token", f"--account={SA}",
                    "--scopes=https://www.googleapis.com/auth/webmasters"],
                   capture_output=True, text=True, env=env)
if r.returncode != 0:
    print("gcloud 失敗:", (r.stderr or "").strip().replace("\n", " ")[:200]); raise SystemExit
tok = r.stdout.strip()
url = ("https://searchconsole.googleapis.com/webmasters/v3/sites/"
       + urllib.parse.quote(SITE, safe="") + "/searchAnalytics/query")

def q(start, end, dims):
    body = json.dumps({"startDate": str(start), "endDate": str(end),
                       "dimensions": dims, "rowLimit": 500, "type": "web"}).encode()
    req = urllib.request.Request(url, data=body, method="POST",
        headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read()).get("rows", [])

end = datetime.date.today() - datetime.timedelta(days=3)
start = end - datetime.timedelta(days=16 * 30)
rows = q(start, end, [])
if rows:
    r0 = rows[0]
    print(f"全期間（{start} 〜 {end}）")
    print(f"  クリック合計: {int(r0['clicks'])}")
    print(f"  表示合計:     {int(r0['impressions'])}")
    print(f"  平均掲載順位: {r0['position']:.1f} 位")
else:
    print("行が返らなかった")

print()
print("月ごとの推移:")
for m in q(start, end, ["date"]):
    pass
by = {}
for row in q(start, end, ["date"]):
    ym = row["keys"][0][:7]
    a = by.setdefault(ym, [0, 0])
    a[0] += row["clicks"]; a[1] += row["impressions"]
for ym in sorted(by):
    c, i = by[ym]
    print(f"  {ym}  クリック {int(c):>5}   表示 {int(i):>6}")
PYEOF
echo '```' >> "$OUT"

echo "=== 結果 ==="
cat "$OUT"
exit 0
