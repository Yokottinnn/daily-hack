#!/usr/bin/env python3
"""週次ブログレポート。PV・訪問・流入経路・検索順位を 1 本にまとめる。

## なぜ作り直したか

2026-08-31 に Slack へ出たレポートには、**`${ALL_VISITS}` が展開されないまま**
載っていた。

    • CF visits（全パス）: *${ALL_VISITS}* / requests ${ALL_REQ}

Cloudflare の数字が出ておらず、**PV が測れていなかった。** しかもエラーにならず、
レポートは毎週きれいに届き続けていた。**沈黙して腐る**構造だった。

利用者の指示（2026-09-06）:
「レポートの内容が浅いので、もっと包括的に pv やユーザー数、流入経路、
 SEO順位などを報告して」

## この 1 本で出すもの

| 節 | 出どころ |
| --- | --- |
| サマリー（visits・実ブラウザ・日本から・検索クリック、いずれも前週比） | CF Zone Analytics ＋ GSC |
| 流入経路 | **取れない**（下記） |
| 人気ページ TOP15 | CF Zone Analytics |
| 検索順位 TOP10（順位の高い順） | GSC |
| 惜しい記事（6〜20 位） | GSC |
| 伸びた記事・落ちた記事（前週比） | GSC |
| 当たり語 TOP20 | GSC |
| デバイス・国・ブラウザ | CF Zone Analytics |

## 設計方針

**どれか 1 つが失敗しても、残りは必ず出す。** 前のレポートは Cloudflare が
取れないことを誰にも伝えられなかった。**取れなかった節には理由を書く。**

## 使い方

    python3 scripts/weekly-blog-report.py                  # 標準出力に Markdown
    python3 scripts/weekly-blog-report.py --out report.md
    python3 scripts/weekly-blog-report.py --slack          # Slack へ投稿
    python3 scripts/weekly-blog-report.py --days 7 --gsc-days 28

## 必要なもの

| | 取り方 |
| --- | --- |
| GSC | `gcloud auth print-access-token --account=<SA>`（`seo-rankings.py` と同じ） |
| Cloudflare | API トークン。`CF_API_TOKEN` 環境変数 → `~/.config/daily-hack/cf-token` → `~/openclaw/config/.env` の順に探す |
| Slack | `~/openclaw/config/.env` の `OPENCLAW_BOT_TOKEN` |

**Web Analytics（RUM）は使わない**（2026-09-27 に一本化）。
このブログの RUM データは **1 件も存在しなかった** — `BaseLayout.astro` の
ビーコン token がアカウントに無いサイトを指しており、引くと PV 0 が返る。
**Zone Analytics（エッジ側の集計）に寄せた。** 違いは 2 つ。

- **visits は読者数ではない。** ボットとクローラを含む（9 月は 94% がボット）。
  ブラウザの内訳から「実ブラウザ」と「日本から」を別に出す
- **リファラが取れない。** 無料プランで拒否されるので、流入経路は GSC 側で見る

**GSC API も Cloudflare API も無料。LLM を呼ばないため API クレジットは消費しない。**
$0/回・$0/日・$0/月。
"""
import argparse
import contextlib
import datetime
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
SITE = "https://daily-hack.fieldbeside.com/"
HOST = "daily-hack.fieldbeside.com"
ZONE_NAME = "fieldbeside.com"
# **Web Analytics（RUM）は使わない。** 2026-09-27 に一本化した。
#
# 調べたら、**このブログの RUM データは 1 件も存在しなかった。**
#
#   アカウントの RUM サイト : 1 件だけ（zone=fieldbeside.com / tag 73990e57…）
#   BaseLayout のビーコン    : 0dc312c5…  ← **アカウントに存在しない**
#   その token で引く        : PV 0
#   73990e57… で引く         : PV 100 / **`/posts/…` は 0 件**
#
# つまり「記事ページの PV が 0」は集計の不具合ではなく、**そもそも取れていなかった。**
# 同じ 9 月を Zone Analytics で引くと visits 13,778 で、**100 倍 以上 食い違う。**
#
# **Zone Analytics に寄せる。** エッジ側の集計なのでビーコンに依存しない。
# ただし 2 点 違いがある。
#
#   1. **visits は読者数ではない。** ボットとクローラを含む。
#      9 月は 13,778 のうち **94% がボット**（Unknown 11,189 / BingBot 1,197）。
#      **国とブラウザの内訳から「実ブラウザ」と「日本から」を別に出す。**
#   2. **リファラが取れない。** clientRefererHost / clientRequestReferer は
#      無料プランで `does not have access to the field` になる。
#      **流入経路は GSC 側で見る。**
#
# **1 クエリ 1 日まで**（zone あたりの制限）なので日ごとにループする。
CF_GRAPHQL = "https://api.cloudflare.com/client/v4/graphql"
SLACK_CHANNEL = "C0B4CJHH797"  # #fun_reward-hack_blog
STATE = os.path.expanduser("~/.config/daily-hack/weekly-report-state.json")

GSC_ENDPOINT = (
    "https://searchconsole.googleapis.com/webmasters/v3/sites/"
    f"{urllib.parse.quote(SITE, safe='')}/searchAnalytics/query"
)


# ────────────────────────── 共通 ──────────────────────────

class Section:
    """1 つの節。失敗しても本文を止めず、理由を残す。"""

    def __init__(self, title):
        self.title = title
        self.lines = []
        self.error = None

    def fail(self, why):
        self.error = str(why)[:400]

    def render(self):
        out = [f"## {self.title}", ""]
        if self.error:
            out.append(f"⚠️ **取れなかった。** {self.error}")
        elif not self.lines:
            out.append("該当なし。")
        else:
            out.extend(self.lines)
        out.append("")
        return out


# ── IPv6 しか引けない環境で落ちるのを避ける ────────────────
#
# 2026-09-06、Mac から Cloudflare だけに届かなかった。
#
#   <urlopen error [Errno 65] No route to host>
#
# **GSC には同じスクリプトで届いていた。** macOS は AAAA を先に試すので、
# IPv6 の経路が無いホストでこれが出る。**IPv4 に落として一度だけ やり直す。**

_ORIG_GETADDRINFO = socket.getaddrinfo


def _ipv4_only(*args, **kwargs):
    res = _ORIG_GETADDRINFO(*args, **kwargs)
    v4 = [r for r in res if r[0] == socket.AF_INET]
    return v4 or res


@contextlib.contextmanager
def force_ipv4():
    socket.getaddrinfo = _ipv4_only
    try:
        yield
    finally:
        socket.getaddrinfo = _ORIG_GETADDRINFO


def _is_unreachable(e):
    """経路が無い系のエラーか。IPv4 で試し直す価値があるものだけ拾う。"""
    err = getattr(e, "reason", e)
    return isinstance(err, OSError) and err.errno in (
        socket.EAI_NONAME if hasattr(socket, "EAI_NONAME") else -2,
        65,   # EHOSTUNREACH (macOS)
        51,   # ENETUNREACH (macOS)
        113,  # EHOSTUNREACH (Linux)
        101,  # ENETUNREACH (Linux)
    )


def retry_ipv4(fn):
    """まず素のまま試し、経路が無ければ IPv4 だけで一度やり直す。"""
    try:
        return fn()
    except (urllib.error.URLError, OSError) as e:
        if not _is_unreachable(e):
            raise
        with force_ipv4():
            return fn()


def post_json(url, payload, headers, timeout=60):
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode(), method="POST",
        headers={"Content-Type": "application/json", **headers})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read() or b"{}")


# ────────────────────────── GSC ──────────────────────────

def find_gcloud():
    """launchd 経由だと PATH が最小限になり Homebrew の gcloud が見つからない。
    `seo-rankings.py` と同じ理由で実パスを自分で探す。"""
    env = os.environ.get("GCLOUD_BIN")
    if env and os.access(env, os.X_OK):
        return env
    found = shutil.which("gcloud")
    if found:
        return found
    for c in ("/opt/homebrew/bin/gcloud", "/usr/local/bin/gcloud",
              "/opt/homebrew/share/google-cloud-sdk/bin/gcloud",
              os.path.expanduser("~/google-cloud-sdk/bin/gcloud")):
        if os.access(c, os.X_OK):
            return c
    return None


def gsc_token():
    gcloud = find_gcloud()
    if not gcloud:
        raise RuntimeError("gcloud が見つからない。GCLOUD_BIN を設定するか PATH を通すこと")
    # gcloud は Python 3.9 では起動しない（2026-08-22 に実機で確認）。
    # launchd 経由だと 3.9 を拾うので、動かしている 3.11 を明示的に渡す。
    env = dict(os.environ)
    if sys.version_info >= (3, 10):
        env["CLOUDSDK_PYTHON"] = sys.executable
    r = subprocess.run(
        [gcloud, "auth", "print-access-token", f"--account={SA}",
         "--scopes=https://www.googleapis.com/auth/webmasters"],
        capture_output=True, text=True, env=env)
    if r.returncode != 0:
        # **トークンは絶対に出さない。** 出すのは gcloud のエラーだけ。
        err = (r.stderr or "").strip().replace("\n", " ")[:400]
        raise RuntimeError(f"gcloud の認証に失敗（rc={r.returncode}）: {err}")
    tok = r.stdout.strip()
    if not tok:
        raise RuntimeError("gcloud がトークンを返さなかった（rc=0）")
    return tok


def gsc_rows(token, dimensions, start, end, limit):
    if isinstance(dimensions, str):
        dimensions = [dimensions]
    try:
        res = post_json(GSC_ENDPOINT, {
            "startDate": str(start), "endDate": str(end),
            "dimensions": dimensions, "rowLimit": limit, "type": "web",
        }, {"Authorization": f"Bearer {token}"})
    except urllib.error.HTTPError as e:
        detail = (e.read() or b"").decode(errors="replace")[:300]
        raise RuntimeError(f"GSC API status={e.code}: {detail}")
    return res.get("rows", [])


def gsc_totals(rows):
    clicks = sum(r["clicks"] for r in rows)
    impr = sum(r["impressions"] for r in rows)
    pos = (sum(r["position"] * r["impressions"] for r in rows) / impr) if impr else 0.0
    return {"clicks": int(clicks), "impressions": int(impr),
            "ctr": (clicks / impr * 100) if impr else 0.0, "position": pos}


# ─────────────────────── Cloudflare ───────────────────────

def cf_token():
    tok = os.environ.get("CF_API_TOKEN") or os.environ.get("CLOUDFLARE_API_TOKEN")
    if tok:
        return tok.strip()
    p = os.path.expanduser("~/.config/daily-hack/cf-token")
    if os.path.exists(p):
        with open(p) as f:
            v = f.read().strip()
        if v:
            return v
    env = os.path.expanduser("~/openclaw/config/.env")
    if os.path.exists(env):
        with open(env) as f:
            for line in f:
                for key in ("CLOUDFLARE_API_TOKEN=", "CF_API_TOKEN="):
                    if line.startswith(key):
                        return line.split("=", 1)[1].strip().strip('"').strip("'")
    raise RuntimeError(
        "Cloudflare の API トークンが見つからない。"
        "CF_API_TOKEN 環境変数 / ~/.config/daily-hack/cf-token / "
        "~/openclaw/config/.env の CLOUDFLARE_API_TOKEN のどれかに置くこと")


def cf_zone_id(token):
    """ゾーン ID を取る。**当て推量しない。** 取れなければ例外を投げる。"""
    def _call():
        req = urllib.request.Request(
            "https://api.cloudflare.com/client/v4/zones?name="
            + urllib.parse.quote(ZONE_NAME),
            headers={"Authorization": f"Bearer {token}"})
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read() or b"{}")

    d = retry_ipv4(_call)
    zones = d.get("result") or []
    if not zones:
        raise RuntimeError(f"Cloudflare がゾーンを返さなかった（{ZONE_NAME} / 権限を確認）")
    return zones[0]["id"]


# 次元だけ差し替えて使う。**1 クエリ 1 日まで**なので呼ぶ側でループする。
CF_ZONE_QUERY = """
query($zoneTag: String!, $start: Time!, $end: Time!, $host: String!) {
  viewer {
    zones(filter: { zoneTag: $zoneTag }) {
      rows: httpRequestsAdaptiveGroups(
        limit: 5000, orderBy: [sum_visits_DESC],
        filter: {
          datetime_geq: $start, datetime_leq: $end,
          clientRequestHTTPHost: $host, edgeResponseStatus: 200,
          requestSource: "eyeball"
        }
      ) { sum { visits } count dimensions { DIMENSION } }
    }
  }
}
"""

# **User-Agent に名前が載っていないものは、ほぼ自動化。**
# `Unknown` を除かないと、9 月なら 11,189 visits をそのまま読者数に数えてしまう。
BOT_UA = re.compile(r"bot|crawl|spider|slurp|Unknown|HeadlessChrome", re.I)


def _cf_day(token, zone, day, dim):
    """1 日ぶん・1 次元を引く。**エラーはそのまま投げる**（黙って 0 にしない）。"""
    nxt = day + datetime.timedelta(days=1)
    res = retry_ipv4(lambda: post_json(CF_GRAPHQL, {
        "query": CF_ZONE_QUERY.replace("DIMENSION", dim),
        "variables": {"zoneTag": zone, "host": HOST,
                      "start": f"{day}T00:00:00Z", "end": f"{nxt}T00:00:00Z"},
    }, {"Authorization": f"Bearer {token}"}, timeout=90))
    if res.get("errors"):
        msgs = "; ".join(e.get("message", "?") for e in res["errors"])[:300]
        raise RuntimeError(f"Cloudflare GraphQL エラー（{day} / {dim}）: {msgs}")
    zones = (res.get("data") or {}).get("viewer", {}).get("zones") or []
    if not zones:
        raise RuntimeError("Cloudflare がゾーンを返さなかった（権限を確認）")
    return zones[0].get("rows") or []


ARCHIVE_BRANCH = "ops/pv-archive"


def _repo_root():
    """このスクリプトが置かれているリポジトリの根。**当て推量しない。**"""
    d = os.path.dirname(os.path.abspath(__file__))
    for _ in range(4):
        if os.path.isdir(os.path.join(d, ".git")):
            return d
        d = os.path.dirname(d)
    return None


def cf_from_archive(start, end):
    """`ops/pv-archive` に積んである日次 JSON から組み立てる。

    **Mac の Cloudflare トークンには Zone Analytics の権限が無い**
    （2026-09-27 に t197 で判明）。

        Actor '…' does not have permission
        'com.cloudflare.api.account.zone.analytics.read' for zone …

    一方、**GitHub Actions のトークンには在る。** そちらが毎日
    `pv-archive` ワークフローで前日ぶんを積んでいるので、ここはそれを読む。
    **権限を足さなくて済むうえ、週次と月次が同じ数字になる。**

    期間が 1 日でも欠けていたら **None を返す**（欠けたまま合算して
    「少なく出た」ことに気づけない状態を作らない）。
    """
    root = _repo_root()
    if not root:
        raise RuntimeError("リポジトリの根が見つからない")
    subprocess.run(["git", "-C", root, "fetch", "-q", "origin", ARCHIVE_BRANCH],
                   capture_output=True, timeout=120)
    months, day = {}, start
    while day <= end:
        m = f"{day:%Y-%m}"
        if m not in months:
            r = subprocess.run(
                ["git", "-C", root, "show", f"origin/{ARCHIVE_BRANCH}:data/{m}.json"],
                capture_output=True, timeout=60)
            try:
                months[m] = json.loads(r.stdout or b"{}")
            except Exception:
                months[m] = {}
        day += datetime.timedelta(days=1)

    acc = {"path": {}, "country": {}, "device": {}, "browser": {}}
    visits = requests_ = human = jp = 0
    missing = []
    day = start
    while day <= end:
        rec = months.get(f"{day:%Y-%m}", {}).get(str(day))
        if not rec:
            missing.append(str(day))
            day += datetime.timedelta(days=1)
            continue
        visits += int(rec.get("visits") or 0)
        requests_ += int(rec.get("requests") or 0)
        human += int(rec.get("human") or 0)
        jp += int(rec.get("jp") or 0)
        for t in rec.get("top") or []:
            c = acc["path"].setdefault(t["path"], [0, 0])
            c[0] += int(t.get("v") or 0); c[1] += int(t.get("r") or 0)
        for k, dst in (("countries", "country"), ("browsers", "browser")):
            for t in rec.get(k) or []:
                c = acc[dst].setdefault(t["k"], [0, 0])
                c[0] += int(t.get("v") or 0)
        day += datetime.timedelta(days=1)

    if missing:
        # **黙って少なく出さない。** 欠けているなら使わない
        raise RuntimeError(
            f"アーカイブに {len(missing)} 日 欠けている（{', '.join(missing[:5])}…）。"
            f"`pv-archive` ワークフローを確認すること")

    def rows_of(dim, key):
        return [{"sum": {"visits": v}, "count": c, "dimensions": {key: k}}
                for k, (v, c) in sorted(acc[dim].items(), key=lambda x: -x[1][0])]

    return {
        "total": [{"count": requests_, "sum": {"visits": visits}}],
        "human": human, "jp": jp, "truncated": [], "source": "アーカイブ",
        "byPath": rows_of("path", "requestPath"),
        "byCountry": rows_of("country", "countryName"),
        "byDevice": rows_of("device", "deviceType"),
        "byBrowser": rows_of("browser", "browser"),
        "byReferer": [],
    }


def cf_fetch(token, zone, start, end):
    """期間ぶんを日ごとに引いて合算する。

    **返す形は RUM 版と同じ**にしてある（`total` / `byPath` / `byCountry` /
    `byDevice`）。呼び出し側の描画を変えずに済ませるため。
    `byReferer` は **Zone Analytics では取れない**ので常に空。
    """
    acc = {"clientRequestPath": {}, "clientCountryName": {}, "clientDeviceType": {},
           "userAgentBrowser": {}}
    visits = requests_ = 0
    truncated = []
    day = start
    while day <= end:
        for dim in acc:
            rows = _cf_day(token, zone, day, dim)
            if len(rows) >= 5000:
                truncated.append(f"{day}/{dim}")
            for r in rows:
                k = (r.get("dimensions") or {}).get(dim) or "(不明)"
                v = int((r.get("sum") or {}).get("visits") or 0)
                c = int(r.get("count") or 0)
                cur = acc[dim].setdefault(k, [0, 0])
                cur[0] += v
                cur[1] += c
                if dim == "clientRequestPath":
                    visits += v
                    requests_ += c
        day += datetime.timedelta(days=1)

    def rows_of(dim, key):
        return [{"sum": {"visits": v}, "count": c, "dimensions": {key: k}}
                for k, (v, c) in sorted(acc[dim].items(), key=lambda x: -x[1][0])]

    human = sum(v for k, (v, _) in acc["userAgentBrowser"].items() if not BOT_UA.search(k))
    jp = acc["clientCountryName"].get("JP", [0, 0])[0]
    return {
        # **`count` は requests であって PV ではない。** 呼ぶ側でそう表示する
        "total": [{"count": requests_, "sum": {"visits": visits}}],
        "human": human,
        "jp": jp,
        "truncated": truncated,
        "byPath": rows_of("clientRequestPath", "requestPath"),
        "byCountry": rows_of("clientCountryName", "countryName"),
        "byDevice": rows_of("clientDeviceType", "deviceType"),
        "byBrowser": rows_of("userAgentBrowser", "browser"),
        "byReferer": [],   # **取れない。** 無料プランで拒否される
    }


def load_state():
    try:
        with open(STATE) as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(state):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def delta(now, before, unit="", pct=False):
    """前回比を「+12（+8%）」の形で返す。前回が無ければ空文字。"""
    if before is None:
        return ""
    d = now - before
    if d == 0:
        return "±0"
    sign = "+" if d > 0 else ""
    if pct and before:
        return f"{sign}{d:.0f}{unit}（{sign}{d / before * 100:.0f}%）"
    return f"{sign}{d:.0f}{unit}"


# ────────────────────────── 本体 ──────────────────────────

def build(args):
    today = datetime.date.today()
    # Cloudflare は当日ぶんも入るが、直近日は欠けるので前日までを見る
    cf_end = today - datetime.timedelta(days=1)
    cf_start = cf_end - datetime.timedelta(days=args.days - 1)
    # GSC は確定まで 2〜3 日かかる。直近日を含めると順位が過小に出る
    gsc_end = today - datetime.timedelta(days=3)
    gsc_start = gsc_end - datetime.timedelta(days=args.gsc_days - 1)

    state = load_state()
    prev = state.get("last", {})
    now = {}

    L = [f"# Daily Hack 週次レポート（{today}）", ""]
    L.append(f"- アクセス: **{cf_start} 〜 {cf_end}**（{args.days} 日・Cloudflare Zone Analytics）")
    L.append(f"- 検索: **{gsc_start} 〜 {gsc_end}**（{args.gsc_days} 日・Search Console）")
    L.append("  ※ GSC は確定まで 2〜3 日かかるため直近 3 日を除いている")
    L.append("")

    # ── Cloudflare ──
    cf = None
    cf_err = None
    try:
        # **まずアーカイブを読む。** Mac のトークンには Zone Analytics の権限が無い
        # （t197 で判明）。GitHub Actions が毎日 `ops/pv-archive` へ積んでいる。
        try:
            cf = cf_from_archive(cf_start, cf_end)
        except Exception as arch_err:
            # 権限のあるトークンなら API でも取れる。**両方 失敗したら両方 報告する**
            try:
                tok = cf_token()
                cf = cf_fetch(tok, cf_zone_id(tok), cf_start, cf_end)
                cf["source"] = "Cloudflare API"
            except Exception as api_err:
                raise RuntimeError(f"アーカイブ: {arch_err} ／ API: {api_err}")
    except Exception as e:
        cf_err = e

    # ── GSC ──
    pages = queries = pairs = devices = None
    gsc_err = None
    try:
        gtok = gsc_token()
        pages = gsc_rows(gtok, "page", gsc_start, gsc_end, 500)
        queries = gsc_rows(gtok, "query", gsc_start, gsc_end, 100)
        pairs = gsc_rows(gtok, ["page", "query"], gsc_start, gsc_end, 5000)
        devices = gsc_rows(gtok, "device", gsc_start, gsc_end, 10)
    except Exception as e:
        gsc_err = e

    # ── サマリー ──
    s = Section("サマリー")
    if cf:
        s.lines.append(f"> 出どころ: **{cf.get('source', 'Cloudflare API')}**")
    s.lines.append("> **visits は読者数ではない。** ボットとクローラを含む。")
    s.lines.append("> **読者に近いのは「実ブラウザ」の行。**"
                   " 検索から来た実訪問は下の「検索クリック」を見る。")
    s.lines.append("")
    s.lines.append("| 指標 | 今回 | 前回比 |")
    s.lines.append("| --- | --- | --- |")
    if cf:
        t = (cf["total"] or [{}])[0]
        req = int(t.get("count") or 0)
        vis = int((t.get("sum") or {}).get("visits") or 0)
        human, jp = cf["human"], cf["jp"]
        now["pv"], now["visits"] = req, vis
        now["human"], now["jp"] = human, jp
        s.lines.append(f"| visits（**ボット込み**） | {vis:,} | {delta(vis, prev.get('visits'), pct=True)} |")
        s.lines.append(f"| requests | {req:,} | {delta(req, prev.get('pv'), pct=True)} |")
        s.lines.append(f"| **実ブラウザ visits** | **{human:,}** | {delta(human, prev.get('human'), pct=True)} |")
        s.lines.append(f"| **日本からの visits** | **{jp:,}** | {delta(jp, prev.get('jp'), pct=True)} |")
    else:
        s.lines.append(f"| visits | ⚠️ 取得失敗 | {str(cf_err)[:120]} |")
        s.lines.append("| 実ブラウザ visits | ⚠️ 取得失敗 | 同上 |")
    if pages is not None:
        g = gsc_totals(pages)
        now.update({"clicks": g["clicks"], "impressions": g["impressions"],
                    "position": round(g["position"], 2)})
        s.lines.append(f"| 検索クリック | {g['clicks']:,} | {delta(g['clicks'], prev.get('clicks'), pct=True)} |")
        s.lines.append(f"| 検索表示 | {g['impressions']:,} | {delta(g['impressions'], prev.get('impressions'), pct=True)} |")
        s.lines.append(f"| 検索 CTR | {g['ctr']:.1f}% | |")
        pd = prev.get("position")
        arrow = ""
        if pd:
            diff = g["position"] - pd
            # 順位は数字が小さいほど良い。矢印だけだと逆に読めるので言葉で書く。
            if abs(diff) < 0.05:
                arrow = "±0"
            else:
                arrow = (f"**改善 {abs(diff):.1f}**" if diff < 0 else f"悪化 {diff:.1f}")
        s.lines.append(f"| 平均掲載順位 | {g['position']:.1f} 位 | {arrow} |")
        s.lines.append(f"| 検索に出た記事数 | {len(pages)} | |")
    else:
        s.lines.append(f"| 検索指標 | ⚠️ 取得失敗 | {str(gsc_err)[:120]} |")
    L += s.render()

    # ── 流入経路 ──
    # **Zone Analytics ではリファラが取れない。**
    # clientRefererHost / clientRequestReferer はどちらも無料プランで
    # `does not have access to the field` になる（2026-09-27 に実測）。
    # **「取れない」と書く。** 空の表を出すと壊れているのか 0 なのか区別がつかない。
    s = Section("流入経路")
    s.lines.append("**Cloudflare では取れない。** リファラの次元（`clientRefererHost` /")
    s.lines.append("`clientRequestReferer`）は無料プランで拒否される。")
    s.lines.append("")
    s.lines.append("**検索からの流入は下の「検索クリック」と「検索順位 TOP10」を見ること。**")
    L += s.render()

    # ── 人気ページ ──
    s = Section(f"人気ページ TOP{args.top_pages}（visits 順・**ボット込み**）")
    if not cf:
        s.fail(cf_err)
    else:
        rows = [r for r in (cf.get("byPath") or [])
                if ((r.get("dimensions") or {}).get("requestPath") or "").startswith("/posts/")]
        prev_pages = (state.get("pages") or {})
        page_now = {}
        if not rows:
            # **0 なら 0 と言う。** 見出しだけ出して表が空だと、壊れているのか
            # 本当に無いのかが読む側から区別できない（2026-09-18 に実際にそう見えた）。
            s.lines.append("**記事ページ（`/posts/…`）の PV は 0。**"
                           " この期間に開かれたのは、トップ・検索・固定ページだけ。")
        else:
            s.lines.append("| # | visits | requests | 前回比 | ページ |")
            s.lines.append("| --- | --- | --- | --- | --- |")
            for i, r in enumerate(rows[:args.top_pages], 1):
                p = (r.get("dimensions") or {})["requestPath"]
                # **`count` は requests、`sum.visits` が visits。** 名前に引きずられない
                req = int(r.get("count") or 0)
                vis = int((r.get("sum") or {}).get("visits") or 0)
                page_now[p] = vis
                s.lines.append(
                    f"| {i} | {vis:,} | {req:,} | {delta(vis, prev_pages.get(p))} | `{p}` |")
        state["pages"] = page_now
    L += s.render()

    # ── 検索順位 ──
    s = Section(f"検索順位 TOP{args.top}（順位の高い順・表示 {args.min_impressions} 回以上）")
    kept = []
    if pages is None:
        s.fail(gsc_err)
    else:
        kept = [r for r in pages if r["impressions"] >= args.min_impressions]
        kept.sort(key=lambda r: r["position"])
        s.lines.append("| # | 平均順位 | 表示 | クリック | CTR | ページ |")
        s.lines.append("| --- | --- | --- | --- | --- | --- |")
        for i, r in enumerate(kept[:args.top], 1):
            page = r["keys"][0].replace(SITE.rstrip("/"), "")
            s.lines.append(f"| {i} | **{r['position']:.1f} 位** | {int(r['impressions'])} | "
                           f"{int(r['clicks'])} | {r['ctr'] * 100:.1f}% | `{page}` |")
    L += s.render()

    # ── 順位帯 ──
    s = Section("順位帯ごとの記事数")
    if pages is None:
        s.fail(gsc_err)
    else:
        def bucket(p):
            return ("1〜3 位" if p < 3.5 else "4〜10 位" if p < 10.5
                    else "11〜20 位" if p < 20.5 else "21 位以下")
        s.lines.append("| 順位帯 | 記事数 | 表示合計 |")
        s.lines.append("| --- | --- | --- |")
        for name in ("1〜3 位", "4〜10 位", "11〜20 位", "21 位以下"):
            sel = [r for r in kept if bucket(r["position"]) == name]
            s.lines.append(f"| {name} | {len(sel)} | {int(sum(r['impressions'] for r in sel))} |")
    L += s.render()

    # ── 惜しい記事 ──
    s = Section("惜しい記事（6〜20 位・表示 5 回以上＝あと一歩で 1 ページ目）")
    if pages is None:
        s.fail(gsc_err)
    else:
        near = [r for r in kept if 5.5 <= r["position"] <= 20.5 and r["impressions"] >= 5]
        if near:
            s.lines.append("| 平均順位 | 表示 | クリック | ページ |")
            s.lines.append("| --- | --- | --- | --- |")
            for r in near:
                page = r["keys"][0].replace(SITE.rstrip("/"), "")
                s.lines.append(f"| {r['position']:.1f} 位 | {int(r['impressions'])} | "
                               f"{int(r['clicks'])} | `{page}` |")
    L += s.render()

    # ── 伸びた・落ちた ──
    s = Section("順位が動いた記事（前回比）")
    if pages is None:
        s.fail(gsc_err)
    else:
        before = state.get("positions") or {}
        pos_now = {}
        moved = []
        for r in kept:
            page = r["keys"][0].replace(SITE.rstrip("/"), "")
            pos_now[page] = round(r["position"], 2)
            if page in before:
                d = r["position"] - before[page]
                if abs(d) >= 1.0:
                    moved.append((d, page, before[page], r["position"]))
        state["positions"] = pos_now
        if not before:
            s.lines.append("前回の記録が無い。次回から比較できる。")
        elif moved:
            moved.sort(key=lambda x: x[0])
            s.lines.append("| 動き | 前回 | 今回 | ページ |")
            s.lines.append("| --- | --- | --- | --- |")
            for d, page, b, a in moved[:15]:
                mark = f"**↑ {abs(d):.1f}**" if d < 0 else f"↓ {d:.1f}"
                s.lines.append(f"| {mark} | {b:.1f} 位 | {a:.1f} 位 | `{page}` |")
        else:
            s.lines.append("1 位以上 動いた記事は無い。")
    L += s.render()

    # ── 当たり語 ──
    s = Section(f"当たり語 TOP{args.top_queries}（表示の多い順）")
    if queries is None:
        s.fail(gsc_err)
    else:
        s.lines.append("| 語 | 表示 | クリック | 平均順位 |")
        s.lines.append("| --- | --- | --- | --- |")
        for r in sorted(queries, key=lambda r: -r["impressions"])[:args.top_queries]:
            s.lines.append(f"| {r['keys'][0]} | {int(r['impressions'])} | "
                           f"{int(r['clicks'])} | {r['position']:.1f} 位 |")
        if pairs:
            s.lines.append("")
            s.lines.append("※ 表示回数の少ない語は GSC 側が匿名化するため出てこない")
    L += s.render()

    # ── デバイス・国 ──
    s = Section("デバイスと国")
    if not cf and devices is None:
        s.fail(cf_err or gsc_err)
    else:
        if cf:
            dev = cf.get("byDevice") or []
            if dev:
                total = sum(int((r.get("sum") or {}).get("visits") or 0) for r in dev) or 1
                s.lines.append("| デバイス | 訪問 | 比率 |")
                s.lines.append("| --- | --- | --- |")
                for r in dev:
                    v = int((r.get("sum") or {}).get("visits") or 0)
                    name = (r.get("dimensions") or {}).get("deviceType") or "(不明)"
                    s.lines.append(f"| {name} | {v:,} | {v / total * 100:.0f}% |")
                s.lines.append("")
            ctry = cf.get("byCountry") or []
            if ctry:
                s.lines.append("| 国 | 訪問 |")
                s.lines.append("| --- | --- |")
                for r in ctry[:8]:
                    v = int((r.get("sum") or {}).get("visits") or 0)
                    s.lines.append(f"| {(r.get('dimensions') or {}).get('countryName') or '(不明)'} | {v:,} |")
                s.lines.append("")
            # **ブラウザの内訳を必ず出す。** ここを見ないと、上の数字の何割が
            # ボットなのかが読む側から分からない。
            br = cf.get("byBrowser") or []
            if br:
                s.lines.append("| UA | 訪問 | |")
                s.lines.append("| --- | --- | --- |")
                for r in br[:12]:
                    v = int((r.get("sum") or {}).get("visits") or 0)
                    k = (r.get("dimensions") or {}).get("browser") or "(不明)"
                    s.lines.append(f"| {k} | {v:,} | {'**ボット扱い**' if BOT_UA.search(k) else '実ブラウザ'} |")
        elif devices:
            s.lines.append("Cloudflare が取れなかったので GSC のデバイス別で代用する。")
            s.lines.append("")
            s.lines.append("| デバイス | 表示 | クリック |")
            s.lines.append("| --- | --- | --- |")
            for r in devices:
                s.lines.append(f"| {r['keys'][0]} | {int(r['impressions'])} | {int(r['clicks'])} |")
    L += s.render()

    # ── 取れなかったものを最後にもう一度出す ──
    if cf_err or gsc_err:
        L.append("## ⚠️ 取れなかったもの")
        L.append("")
        if cf_err:
            L.append(f"- **Cloudflare**: {str(cf_err)[:300]}")
        if gsc_err:
            L.append(f"- **Search Console**: {str(gsc_err)[:300]}")
        L.append("")
        L.append("**数字が出ていないまま気づかない状態を作らない**ための節。")
        L.append("")

    L.append("---")
    L.append("出典: Cloudflare Zone Analytics ／ Google Search Console。"
             "LLM 不使用のため API クレジットは消費しない（$0/回・$0/日・$0/月）。")

    if now:
        state["last"] = now
        state["last_at"] = str(today)
        save_state(state)

    return "\n".join(L), bool(cf_err or gsc_err)


# Slack に出す節と、その節で出す表の行数の上限。
# **見出しの前方一致で拾う。** 節名に TOP15 / TOP20 のような可変の数字が入るため。
# None は「全部出す」。ここに無い節は Slack には出さない（Markdown 版には全部ある）。
SLACK_SECTIONS = (
    ("サマリー", None),
    ("流入経路", 8),
    ("人気ページ", 5),
    ("検索順位", 5),
    ("惜しい記事", 5),
    ("順位が動いた記事", 6),
    ("当たり語", 5),
    ("⚠️ 取れなかったもの", None),
)


def _slack_limit(section):
    """その節を Slack に出すか、出すなら表を何行までにするか。"""
    for prefix, limit in SLACK_SECTIONS:
        if section.startswith(prefix):
            return True, limit
    return False, 0


def to_slack(md, has_error):
    """Slack は表を描けない。節ごとに行数を絞って箇条書きに落とす。"""
    head = "🚨 " if has_error else "📊 "
    md = md.replace("**", "*")  # Slack の強調は * 1 つ
    keep = []
    section = None
    show = False
    limit = None
    rows = 0
    for line in md.split("\n"):
        if line.startswith("# "):
            keep.append(f"*{line[2:].strip()}*")
            continue
        if line.startswith("## "):
            section = line[3:].strip()
            show, limit = _slack_limit(section)
            rows = 0
            if show:
                keep.append(f"\n*■ {section}*")
            continue
        if not show or not line.strip():
            continue
        if line.startswith("| --- "):
            continue
        if line.startswith("|"):
            cells = [c.strip() for c in line.strip("|").split("|")]
            cells = [c for c in cells if c]
            rows += 1
            if rows == 1:
                # 表の見出し行。項目名が分からないと数字が読めないので残す
                keep.append("_" + " / ".join(cells) + "_")
                continue
            if limit is not None and rows > limit + 1:
                if rows == limit + 2:
                    keep.append(f"…ほか（全文は Markdown 版に）")
                continue
            keep.append("• " + " / ".join(cells))
        else:
            # 1 つの節に表が 2 つ以上 入ることがある（デバイス・国・ブラウザ）。
            # 表と表のあいだの小見出しで数え直さないと、2 つ目が頭から削られる。
            rows = 0
            keep.append(line)
    text = head + "\n".join(keep)
    if len(text) > 3500:
        text = text[:3480] + "\n…（以下省略）"
    return text


def slack_post(text, channel):
    env = os.path.expanduser("~/openclaw/config/.env")
    token = os.environ.get("OPENCLAW_BOT_TOKEN")
    if not token and os.path.exists(env):
        with open(env) as f:
            for line in f:
                if line.startswith("OPENCLAW_BOT_TOKEN="):
                    token = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break
    if not token:
        print("OPENCLAW_BOT_TOKEN が見つからず Slack 送信をスキップ", file=sys.stderr)
        return False
    res = post_json("https://slack.com/api/chat.postMessage",
                    {"channel": channel, "text": text},
                    {"Authorization": f"Bearer {token}"})
    if not res.get("ok"):
        print(f"Slack 送信に失敗: {res.get('error')}", file=sys.stderr)
        return False
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=7, help="アクセスの集計日数")
    ap.add_argument("--gsc-days", type=int, default=28, help="検索の集計日数")
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--top-pages", type=int, default=15)
    ap.add_argument("--top-queries", type=int, default=20)
    ap.add_argument("--min-impressions", type=int, default=1)
    ap.add_argument("--out")
    ap.add_argument("--slack", action="store_true")
    ap.add_argument("--channel", default=SLACK_CHANNEL)
    args = ap.parse_args()

    md, has_error = build(args)

    if args.out:
        with open(args.out, "w") as f:
            f.write(md + "\n")
        print(f"書いた: {args.out}", file=sys.stderr)
    else:
        print(md)

    if args.slack:
        slack_post(to_slack(md, has_error), args.channel)

    # **取れなかったものがあれば非 0 で落とす。** 静かに腐らせない。
    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main())
