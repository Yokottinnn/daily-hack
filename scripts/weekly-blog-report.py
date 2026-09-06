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
| サマリー（PV・訪問・検索クリック、いずれも前週比） | CF RUM ＋ GSC |
| 流入経路（検索／SNS／直接／その他の内訳＋リファラ TOP） | CF RUM |
| 人気ページ TOP15 | CF RUM |
| 検索順位 TOP10（順位の高い順） | GSC |
| 惜しい記事（6〜20 位） | GSC |
| 伸びた記事・落ちた記事（前週比） | GSC |
| 当たり語 TOP20 | GSC |
| デバイス・国 | CF RUM |

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

Cloudflare の Web Analytics は**サイトタグ**で絞る。ビーコンのトークンと同じ値で、
`src/layouts/BaseLayout.astro` に平文で入っている（公開情報なので秘密ではない）。

**GSC API も Cloudflare API も無料。LLM を呼ばないため API クレジットは消費しない。**
$0/回・$0/日・$0/月。
"""
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
SITE = "https://daily-hack.fieldbeside.com/"
HOST = "daily-hack.fieldbeside.com"
# Cloudflare Web Analytics のサイトタグ＝ビーコンの token。
# BaseLayout.astro に平文で入っており、ページを開けば誰でも読める公開値。
CF_SITE_TAG = "0dc312c59cff43f58507d2b4f669dd82"
CF_GRAPHQL = "https://api.cloudflare.com/client/v4/graphql"
SLACK_CHANNEL = "C0B4CJHH797"  # #fun_reward-hack_blog
STATE = os.path.expanduser("~/.config/daily-hack/weekly-report-state.json")

GSC_ENDPOINT = (
    "https://searchconsole.googleapis.com/webmasters/v3/sites/"
    f"{urllib.parse.quote(SITE, safe='')}/searchAnalytics/query"
)

# 検索エンジンと SNS のリファラ。ここに無いものは「その他サイト」に落ちる。
SEARCH_HOSTS = ("google.", "www.google.", "bing.", "www.bing.", "search.yahoo.",
                "duckduckgo.", "www.ecosia.", "yandex.", "baidu.")
SOCIAL_HOSTS = ("t.co", "x.com", "twitter.com", "www.facebook.com", "l.facebook.com",
                "m.facebook.com", "www.instagram.com", "l.instagram.com",
                "www.threads.net", "threads.net", "b.hatena.ne.jp", "note.com",
                "www.reddit.com", "out.reddit.com", "www.linkedin.com",
                "lm.facebook.com", "line.me", "www.pinterest.jp", "www.pinterest.com")


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


def cf_account_id(token):
    req = urllib.request.Request(
        "https://api.cloudflare.com/client/v4/accounts?per_page=5",
        headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read() or b"{}")
    res = data.get("result") or []
    if not res:
        raise RuntimeError("Cloudflare のアカウントが取れない（トークンの権限を確認）")
    return res[0]["id"]


CF_QUERY = """
query($account: String!, $siteTag: String!, $start: Time!, $end: Time!) {
  viewer {
    accounts(filter: { accountTag: $account }) {
      total: rumPageloadEventsAdaptiveGroups(
        limit: 1,
        filter: { siteTag: $siteTag, datetime_geq: $start, datetime_leq: $end }
      ) { count sum { visits } }

      byPath: rumPageloadEventsAdaptiveGroups(
        limit: 100, orderBy: [count_DESC],
        filter: { siteTag: $siteTag, datetime_geq: $start, datetime_leq: $end }
      ) { count sum { visits } dimensions { requestPath } }

      byReferer: rumPageloadEventsAdaptiveGroups(
        limit: 50, orderBy: [sum_visits_DESC],
        filter: { siteTag: $siteTag, datetime_geq: $start, datetime_leq: $end }
      ) { count sum { visits } dimensions { refererHost } }

      byCountry: rumPageloadEventsAdaptiveGroups(
        limit: 15, orderBy: [sum_visits_DESC],
        filter: { siteTag: $siteTag, datetime_geq: $start, datetime_leq: $end }
      ) { sum { visits } dimensions { countryName } }

      byDevice: rumPageloadEventsAdaptiveGroups(
        limit: 10, orderBy: [sum_visits_DESC],
        filter: { siteTag: $siteTag, datetime_geq: $start, datetime_leq: $end }
      ) { sum { visits } dimensions { deviceType } }
    }
  }
}
"""


def cf_fetch(token, account, start, end):
    res = post_json(CF_GRAPHQL, {
        "query": CF_QUERY,
        "variables": {"account": account, "siteTag": CF_SITE_TAG,
                      "start": f"{start}T00:00:00Z", "end": f"{end}T23:59:59Z"},
    }, {"Authorization": f"Bearer {token}"}, timeout=90)
    if res.get("errors"):
        msgs = "; ".join(e.get("message", "?") for e in res["errors"])[:300]
        raise RuntimeError(f"Cloudflare GraphQL エラー: {msgs}")
    accounts = (res.get("data") or {}).get("viewer", {}).get("accounts") or []
    if not accounts:
        raise RuntimeError("Cloudflare がアカウントを返さなかった（siteTag / 権限を確認）")
    return accounts[0]


def classify_referer(host):
    h = (host or "").lower()
    if not h or h in ("", "none", "(direct)"):
        return "直接・アプリ内"
    if any(h == s.rstrip(".") or h.startswith(s) for s in SEARCH_HOSTS):
        return "検索"
    if h in SOCIAL_HOSTS:
        return "SNS"
    if h.endswith(HOST):
        return "サイト内"
    return "その他サイト"


# ─────────────────────── 前週比の記憶 ───────────────────────

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
    L.append(f"- アクセス: **{cf_start} 〜 {cf_end}**（{args.days} 日・Cloudflare Web Analytics）")
    L.append(f"- 検索: **{gsc_start} 〜 {gsc_end}**（{args.gsc_days} 日・Search Console）")
    L.append("  ※ GSC は確定まで 2〜3 日かかるため直近 3 日を除いている")
    L.append("")

    # ── Cloudflare ──
    cf = None
    cf_err = None
    try:
        tok = cf_token()
        cf = cf_fetch(tok, cf_account_id(tok), cf_start, cf_end)
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
    s.lines.append("| 指標 | 今回 | 前回比 |")
    s.lines.append("| --- | --- | --- |")
    if cf:
        t = (cf["total"] or [{}])[0]
        pv = int(t.get("count") or 0)
        vis = int((t.get("sum") or {}).get("visits") or 0)
        now["pv"], now["visits"] = pv, vis
        s.lines.append(f"| **ページビュー** | {pv:,} | {delta(pv, prev.get('pv'), pct=True)} |")
        s.lines.append(f"| **訪問（ユニーク）** | {vis:,} | {delta(vis, prev.get('visits'), pct=True)} |")
    else:
        s.lines.append(f"| ページビュー | ⚠️ 取得失敗 | {str(cf_err)[:120]} |")
        s.lines.append("| 訪問（ユニーク） | ⚠️ 取得失敗 | 同上 |")
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
    s = Section("流入経路")
    if not cf:
        s.fail(cf_err)
    else:
        refs = cf.get("byReferer") or []
        groups = {}
        for r in refs:
            host = (r.get("dimensions") or {}).get("refererHost") or ""
            v = int((r.get("sum") or {}).get("visits") or 0)
            groups[classify_referer(host)] = groups.get(classify_referer(host), 0) + v
        total = sum(groups.values())
        if total:
            s.lines.append("| 経路 | 訪問 | 比率 |")
            s.lines.append("| --- | --- | --- |")
            for name, v in sorted(groups.items(), key=lambda x: -x[1]):
                s.lines.append(f"| {name} | {v:,} | {v / total * 100:.0f}% |")
            s.lines.append("")
            ext = [r for r in refs
                   if classify_referer((r.get("dimensions") or {}).get("refererHost"))
                   not in ("直接・アプリ内", "サイト内")]
            if ext:
                s.lines.append("**リファラ TOP10**")
                s.lines.append("")
                s.lines.append("| リファラ | 訪問 |")
                s.lines.append("| --- | --- |")
                for r in ext[:10]:
                    h = (r.get("dimensions") or {}).get("refererHost") or "(不明)"
                    s.lines.append(f"| `{h}` | {int((r.get('sum') or {}).get('visits') or 0):,} |")
    L += s.render()

    # ── 人気ページ ──
    s = Section(f"人気ページ TOP{args.top_pages}（ページビュー順）")
    if not cf:
        s.fail(cf_err)
    else:
        rows = [r for r in (cf.get("byPath") or [])
                if ((r.get("dimensions") or {}).get("requestPath") or "").startswith("/posts/")]
        prev_pages = (state.get("pages") or {})
        page_now = {}
        s.lines.append("| # | PV | 訪問 | 前回比 | ページ |")
        s.lines.append("| --- | --- | --- | --- | --- |")
        for i, r in enumerate(rows[:args.top_pages], 1):
            p = (r.get("dimensions") or {})["requestPath"]
            pv = int(r.get("count") or 0)
            vis = int((r.get("sum") or {}).get("visits") or 0)
            page_now[p] = pv
            s.lines.append(f"| {i} | {pv:,} | {vis:,} | {delta(pv, prev_pages.get(p))} | `{p}` |")
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
    L.append("出典: Cloudflare Web Analytics ／ Google Search Console。"
             "LLM 不使用のため API クレジットは消費しない（$0/回・$0/日・$0/月）。")

    if now:
        state["last"] = now
        state["last_at"] = str(today)
        save_state(state)

    return "\n".join(L), bool(cf_err or gsc_err)


def to_slack(md, has_error):
    """Slack は表を描けない。要点だけ抜いて短くする。"""
    head = "🚨 " if has_error else "📊 "
    md = md.replace("**", "*")  # Slack の強調は * 1 つ
    keep, section, kept_sections = [], None, {"サマリー", "流入経路", "⚠️ 取れなかったもの"}
    for line in md.split("\n"):
        if line.startswith("## "):
            section = line[3:].strip()
        if line.startswith("# "):
            keep.append(f"*{line[2:].strip()}*")
        elif section in kept_sections:
            if line.startswith("## "):
                keep.append(f"\n*■ {section}*")
            elif line.startswith("| --- "):
                continue
            elif line.startswith("|"):
                cells = [c.strip() for c in line.strip("|").split("|")]
                keep.append("• " + " / ".join(c for c in cells if c))
            elif line.strip():
                keep.append(line)
    return head + "\n".join(keep)[:3500]


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
