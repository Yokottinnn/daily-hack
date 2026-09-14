#!/bin/bash
# **大磯プリンス記事 1 本の PV と検索流入を、一次情報から取る。**（t074 の作り直し）
#
# ## t074 がなぜ全滅したか
#
#   UnboundLocalError: cannot access local variable 'L'
#
# 関数の中で `L += [...]` と書いた。**代入なので L がローカル扱いになり、
# 先に読んだ時点で落ちる。** `L.append()` は落ちないので気づきにくい。
# `python3 -m py_compile` は通る（構文としては正しい）。**実行しないと出ない。**
# 直し方: 各関数の先頭に `global L` を置く。
#
# 利用者の質問（2026-09-14）:
#   「この記事の pv とか SEO からの検索流入数など全て調べて教えて」
#   https://daily-hack.fieldbeside.com/posts/oiso-prince-spgr-guide-2026/
#
# ## 取る先は 2 つ。役割が違う
#
#   - **Cloudflare Web Analytics** = PV（全流入。検索も SNS も直接も含む）
#     **保持は実質 30 日**（t064 で 90 日が 0 だった）。それより前は出ない
#   - **GSC** = Google 検索からの流入だけ。クリック / 表示 / 順位 / 検索語
#     16 か月 遡れるが、**クリックは延べであってユニークユーザーではない**
#
# ## 出すもの
#
#   CF: この記事の PV・訪問（7 / 30 日）、日別、参照元、デバイス、国
#   GSC: この記事の全期間 合計、検索語 別、月別、デバイス 別、国 別、日別（直近 30 日）
#
# **秘密は出さない。** IPv4 で叩く（Mac は IPv6 の経路が無いことがある）。
# **`timeout` は使わない**（macOS に無い・ルール 14）。API を叩くだけで数十秒。
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの確認タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t075-oiso-traffic.md"
mkdir -p "$RDIR"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い" | tee "$OUT"; exit 1; }

TOK_FILE="$HOME/.config/daily-hack/cf-token"

"$PY" - "$OUT" "$TOK_FILE" <<'PYEOF'
import contextlib, datetime as dt, json, os, shutil, socket, subprocess, sys
import urllib.parse, urllib.request, urllib.error

OUT, TOK_FILE = sys.argv[1], sys.argv[2]
PATH = "/posts/oiso-prince-spgr-guide-2026/"
SITE = "https://daily-hack.fieldbeside.com/"
PAGE = SITE.rstrip("/") + PATH
SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"

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

L = ["# 大磯プリンス記事のアクセス（t075）", "",
     f"対象: `{PATH}`", "",
     f"生成: **{dt.datetime.now().astimezone().isoformat(timespec='seconds')}**", ""]

# ============ 1. Cloudflare Web Analytics（PV） ============
L += ["## 1. PV（Cloudflare Web Analytics・全流入）", ""]

def cf_block():
    global L
    if not os.path.exists(TOK_FILE):
        L.append("⚠️ `~/.config/daily-hack/cf-token` が無い。PV は取れなかった。")
        return
    tok = open(TOK_FILE).read().strip()

    def gql(q, v):
        body = json.dumps({"query": q, "variables": v}).encode()
        req = urllib.request.Request(
            "https://api.cloudflare.com/client/v4/graphql", data=body, method="POST",
            headers={"Content-Type": "application/json", "Authorization": "Bearer " + tok})
        return json.loads(urllib.request.urlopen(req, timeout=60).read())

    def rest(url):
        req = urllib.request.Request(url, headers={"Authorization": "Bearer " + tok})
        return json.loads(urllib.request.urlopen(req, timeout=40).read())

    try:
        acc = (retry_ipv4(lambda: rest(
            "https://api.cloudflare.com/client/v4/accounts?per_page=5"))
            .get("result") or [{}])[0].get("id")
    except Exception as e:
        L.append(f"⚠️ アカウント取得で落ちた: {type(e).__name__}: {str(e)[:200]}")
        return
    if not acc:
        L.append("⚠️ アカウントが取れなかった。")
        return

    end = dt.date.today() - dt.timedelta(days=1)

    def group(dims_gql, days, limit=1000):
        """requestPath を含めて集計し、対象パスだけをこちら側で抜く。
        **フィルタのキー名を当てにいかない。** 間違えると全部エラーになる。"""
        start = end - dt.timedelta(days=days - 1)
        q = """
        query($a: String!, $s: Time!, $e: Time!, $n: Int!) {
          viewer { accounts(filter: {accountTag: $a}) {
            g: rumPageloadEventsAdaptiveGroups(
              limit: $n, filter: { datetime_geq: $s, datetime_leq: $e }
            ) { count sum { visits } dimensions { %s } }
          } }
        }""" % dims_gql
        d = retry_ipv4(lambda: gql(q, {"a": acc, "s": f"{start}T00:00:00Z",
                                       "e": f"{end}T23:59:59Z", "n": limit}))
        if d.get("errors"):
            raise RuntimeError(json.dumps(d["errors"], ensure_ascii=False)[:200])
        a = ((d.get("data") or {}).get("viewer", {}).get("accounts") or [{}])[0]
        return (a.get("g") or []), start

    # 合計（7 / 30 / 90 日）
    L += ["### 合計", "", "| 期間 | この記事の PV | 訪問 | サイト全体の PV | 記事の占める割合 |",
          "| --- | --- | --- | --- | --- |"]
    for days in (7, 30, 90):
        try:
            rows, start = group("requestPath", days)
        except Exception as e:
            L.append(f"| {days} 日 | — | — | **エラー** | {str(e)[:80]} |")
            continue
        mine = [r for r in rows if r["dimensions"]["requestPath"] == PATH]
        pv = sum(r["count"] for r in mine)
        vis = sum((r.get("sum") or {}).get("visits", 0) for r in mine)
        total = sum(r["count"] for r in rows)
        share = f"{pv / total * 100:.1f}%" if total else "—"
        L.append(f"| {days} 日（{start}〜{end}） | **{pv}** | {vis} | {total} | {share} |")
    L.append("")
    L += ["**90 日が 0 なら、それは「来ていない」ではなく「保持が切れている」。**",
          "Cloudflare Web Analytics の保持は実質 30 日（t064 で実測）。", ""]

    # 日別（30 日）
    try:
        rows, start = group("date requestPath", 30, limit=5000)
        mine = sorted([r for r in rows if r["dimensions"]["requestPath"] == PATH],
                      key=lambda r: r["dimensions"]["date"])
        if mine:
            L += ["### 日別（直近 30 日・PV があった日だけ）", "",
                  "| 日 | PV | 訪問 |", "| --- | --- | --- |"]
            for r in mine:
                L.append(f"| {r['dimensions']['date']} | {r['count']} | "
                         f"{(r.get('sum') or {}).get('visits', 0)} |")
            L.append("")
        else:
            L += ["### 日別（直近 30 日）", "",
                  "**PV のあった日は 1 日も無い。**", ""]
    except Exception as e:
        L += [f"⚠️ 日別で落ちた: {str(e)[:200]}", ""]

    # 参照元・デバイス・国（30 日）
    for label, dims, key in (("参照元", "refererHost requestPath", "refererHost"),
                             ("デバイス", "deviceType requestPath", "deviceType"),
                             ("国", "countryName requestPath", "countryName")):
        try:
            rows, _ = group(dims, 30, limit=5000)
            mine = [r for r in rows if r["dimensions"]["requestPath"] == PATH]
            if not mine:
                L += [f"### {label}（30 日）", "", "データなし。", ""]
                continue
            mine.sort(key=lambda r: -r["count"])
            L += [f"### {label}（30 日）", "", f"| {label} | PV |", "| --- | --- |"]
            for r in mine[:15]:
                v = r["dimensions"].get(key) or "(なし)"
                L.append(f"| {v} | {r['count']} |")
            L.append("")
        except Exception as e:
            L += [f"### {label}（30 日）", "", f"⚠️ 落ちた: {str(e)[:150]}", ""]

try:
    cf_block()
except Exception as e:
    L.append(f"⚠️ **Cloudflare 全体で落ちた。** {type(e).__name__}: {str(e)[:250]}")

# ============ 2. GSC（検索流入） ============
L += ["", "## 2. Google 検索からの流入（GSC）", ""]

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

def gsc_block():
    global L
    g = find_gcloud()
    if not g:
        L.append("⚠️ gcloud が見つからない。検索流入は取れなかった。")
        return
    env = dict(os.environ); env["CLOUDSDK_PYTHON"] = sys.executable

    def get_token():
        r = subprocess.run([g, "auth", "print-access-token", f"--account={SA}",
                            "--scopes=https://www.googleapis.com/auth/webmasters"],
                           capture_output=True, text=True, env=env)
        if r.returncode != 0:
            # **トークンは絶対に出さない。** 出すのは gcloud のエラーだけ。
            raise RuntimeError("gcloud 認証失敗 rc=%d: %s"
                               % (r.returncode,
                                  (r.stderr or "").strip().replace("\n", " ")[:250]))
        t = r.stdout.strip()
        if not t:
            raise RuntimeError("gcloud がトークンを返さなかった（rc=0）")
        return t

    try:
        tok = retry_ipv4(get_token)
    except Exception as e:
        L.append(f"⚠️ **認証で落ちた。** {type(e).__name__}: {str(e)[:250]}")
        return

    url = ("https://searchconsole.googleapis.com/webmasters/v3/sites/"
           + urllib.parse.quote(SITE, safe="") + "/searchAnalytics/query")

    def q(dims, start, end, limit=1000):
        body = json.dumps({
            "startDate": str(start), "endDate": str(end), "dimensions": dims,
            "rowLimit": limit, "type": "web",
            "dimensionFilterGroups": [{"filters": [
                {"dimension": "page", "operator": "equals", "expression": PAGE}]}],
        }).encode()
        req = urllib.request.Request(url, data=body, method="POST",
            headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
        return json.loads(urllib.request.urlopen(req, timeout=60).read()).get("rows", [])

    today = dt.date.today()
    end = today - dt.timedelta(days=2)      # 直近 2 日は未確定なので外す
    start = today - dt.timedelta(days=480)  # GSC の保持は 16 か月
    L += [f"対象期間: **{start} 〜 {end}**", ""]

    try:
        tot = retry_ipv4(lambda: q([], start, end))
    except Exception as e:
        L.append(f"⚠️ **取得で落ちた。** {type(e).__name__}: {str(e)[:250]}")
        return

    if not tot:
        L += ["**全期間でクリックも表示も 0。** 検索結果にまだ 1 度も出ていない。", ""]
    else:
        r = tot[0]
        L += ["### 合計（全期間）", "", "| 項目 | 値 |", "| --- | --- |",
              f"| クリック（**延べ**） | **{r.get('clicks',0):.0f}** |",
              f"| 表示回数 | {r.get('impressions',0):.0f} |",
              f"| CTR | {r.get('ctr',0)*100:.2f}% |",
              f"| 平均掲載順位 | {r.get('position',0):.1f} |", ""]

    # 検索語
    try:
        rows = retry_ipv4(lambda: q(["query"], start, end))
        rows.sort(key=lambda x: (-x.get("impressions", 0), -x.get("clicks", 0)))
        L += [f"### この記事が出た検索語（全期間・{len(rows)} 語）", ""]
        if rows:
            L += ["| 検索語 | クリック | 表示 | CTR | 平均順位 |",
                  "| --- | --- | --- | --- | --- |"]
            for x in rows[:40]:
                L.append(f"| {x['keys'][0]} | {x.get('clicks',0):.0f} | "
                         f"{x.get('impressions',0):.0f} | {x.get('ctr',0)*100:.1f}% | "
                         f"{x.get('position',0):.1f} |")
        else:
            L.append("1 語も無い。")
        L.append("")
    except Exception as e:
        L += [f"⚠️ 検索語で落ちた: {str(e)[:200]}", ""]

    # 月別
    try:
        rows = retry_ipv4(lambda: q(["date"], start, end, limit=5000))
        by_m = {}
        for x in rows:
            m = x["keys"][0][:7]
            a = by_m.setdefault(m, [0, 0, 0.0, 0])
            a[0] += x.get("clicks", 0); a[1] += x.get("impressions", 0)
            a[2] += x.get("position", 0) * max(x.get("impressions", 0), 1)
            a[3] += max(x.get("impressions", 0), 1)
        L += ["### 月別の推移", ""]
        if by_m:
            L += ["| 月 | クリック | 表示 | 平均順位 |", "| --- | --- | --- | --- |"]
            for m in sorted(by_m):
                c, i, ps, pw = by_m[m]
                L.append(f"| {m} | {c:.0f} | {i:.0f} | {ps/pw:.1f} |")
            days = sorted(x["keys"][0] for x in rows)
            L += ["", f"**データのある日: {len(days)} 日（{days[0]} 〜 {days[-1]}）**", ""]
        else:
            L += ["データのある日が 1 日も無い。", ""]
    except Exception as e:
        L += [f"⚠️ 月別で落ちた: {str(e)[:200]}", ""]

    # デバイス・国
    for label, dim in (("デバイス", "device"), ("国", "country")):
        try:
            rows = retry_ipv4(lambda d=dim: q([d], start, end))
            rows.sort(key=lambda x: -x.get("impressions", 0))
            L += [f"### {label} 別", ""]
            if rows:
                L += ["| " + label + " | クリック | 表示 | 平均順位 |",
                      "| --- | --- | --- | --- |"]
                for x in rows[:10]:
                    L.append(f"| {x['keys'][0]} | {x.get('clicks',0):.0f} | "
                             f"{x.get('impressions',0):.0f} | {x.get('position',0):.1f} |")
            else:
                L.append("データなし。")
            L.append("")
        except Exception as e:
            L += [f"⚠️ {label} で落ちた: {str(e)[:150]}", ""]

    # 直近 28 日 vs その前
    try:
        r1 = retry_ipv4(lambda: q([], end - dt.timedelta(days=27), end))
        r2 = retry_ipv4(lambda: q([], end - dt.timedelta(days=55),
                                  end - dt.timedelta(days=28)))
        def one(rs):
            if not rs:
                return (0, 0, 0.0)
            x = rs[0]
            return (x.get("clicks", 0), x.get("impressions", 0), x.get("position", 0))
        c1, i1, p1 = one(r1); c2, i2, p2 = one(r2)
        L += ["### 直近 28 日 と その前 28 日", "",
              "| 期間 | クリック | 表示 | 平均順位 |", "| --- | --- | --- | --- |",
              f"| 直近 28 日 | {c1:.0f} | {i1:.0f} | {p1:.1f} |",
              f"| その前 28 日 | {c2:.0f} | {i2:.0f} | {p2:.1f} |", ""]
    except Exception as e:
        L += [f"⚠️ 期間比較で落ちた: {str(e)[:200]}", ""]

try:
    gsc_block()
except Exception as e:
    L.append(f"⚠️ **GSC 全体で落ちた。** {type(e).__name__}: {str(e)[:250]}")

# ============ 3. インデックス状況（URL 検査 API） ============
L += ["", "## 3. インデックス状況（GSC URL 検査 API）", ""]

def inspect_block():
    global L
    g = find_gcloud()
    if not g:
        L.append("⚠️ gcloud が無いので検査できなかった。")
        return
    env = dict(os.environ); env["CLOUDSDK_PYTHON"] = sys.executable
    r = subprocess.run([g, "auth", "print-access-token", f"--account={SA}",
                        "--scopes=https://www.googleapis.com/auth/webmasters.readonly"],
                       capture_output=True, text=True, env=env)
    if r.returncode != 0:
        L.append("⚠️ 認証失敗 rc=%d: %s"
                 % (r.returncode, (r.stderr or "").strip().replace("\n", " ")[:200]))
        return
    tok = r.stdout.strip()
    body = json.dumps({"inspectionUrl": PAGE, "siteUrl": SITE,
                       "languageCode": "ja-JP"}).encode()
    req = urllib.request.Request(
        "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect",
        data=body, method="POST",
        headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    d = retry_ipv4(lambda: json.loads(urllib.request.urlopen(req, timeout=60).read()))
    idx = ((d.get("inspectionResult") or {}).get("indexStatusResult") or {})
    L += ["| 項目 | 値 |", "| --- | --- |",
          f"| verdict | **{idx.get('verdict','—')}** |",
          f"| 登録状態 | **{idx.get('coverageState','—')}** |",
          f"| 最終クロール | {idx.get('lastCrawlTime','—')} |",
          f"| robots | {idx.get('robotsTxtState','—')} |",
          f"| 取得結果 | {idx.get('pageFetchState','—')} |",
          f"| Google の canonical | `{idx.get('googleCanonical','—')}` |",
          f"| こちらの canonical | `{idx.get('userCanonical','—')}` |",
          f"| クロール端末 | {idx.get('crawledAs','—')} |",
          f"| 参照元 | {', '.join(idx.get('referringUrls') or []) or '—'} |", ""]

try:
    inspect_block()
except Exception as e:
    L.append(f"⚠️ **URL 検査で落ちた。** {type(e).__name__}: {str(e)[:250]}")

L += ["", "## 読むときの注意", "",
      "- **PV（CF）と クリック（GSC）は別物。** PV は全流入、クリックは Google 検索だけ",
      "- **クリックは延べ。** 同じ人が 3 回 来れば 3。ユニークユーザーは どちらも出せない",
      "- **CF の保持は実質 30 日。** 公開（2026-05-20）当時の PV はもう残っていない",
      "- **GSC は 16 か月 遡れる。** 公開直後からの検索流入はこちらで分かる", ""]

open(OUT, "w").write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF
exit 0
