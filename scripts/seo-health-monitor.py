#!/usr/bin/env python3
"""
seo-health-monitor.py — ブログの SEO 健康診断を実行し Slack に通知する。

2026-08-08 追加。背景:
  サイトマップが 2026-06-05 以降 Google に取得されず、その間に公開した記事
  (163 URL) が丸ごと未発見のまま 2 ヶ月放置された。当時の weekly-pv-report は
  Cloudflare の PV しか見ておらず、しかも SLACK_WEBHOOK_URL 未設定で Slack
  ステップが毎回 skip されていたため、誰も気づけなかった。
  → 「サイトマップ鮮度」を最優先で監視し、異常時は必ず鳴らす。

チェック項目:
  1. サイトマップ最終取得日 (STALE_DAYS 日以上前なら 🚨)
  2. sitemap 登録 URL 数 と 実 URL 数 の乖離 (🚨)
  3. GSC 直近7日 vs 前7日 の クリック/表示/CTR/平均順位
  4. インデックス未登録・未認識の記事数 (前回スナップショットと比較)
  5. 表示回数 上位ページ

Usage:
  python3.11 scripts/seo-health-monitor.py            # 通知あり
  python3.11 scripts/seo-health-monitor.py --dry-run  # 標準出力のみ
  python3.11 scripts/seo-health-monitor.py --no-index # インデックス全走査を省略(高速)
"""
import json, sys, re, os, time, datetime, urllib.request, urllib.parse, pathlib

SITE = "https://daily-hack.fieldbeside.com/"
SITEMAP_URL = "https://daily-hack.fieldbeside.com/sitemap-0.xml"
SA_KEY = os.path.expanduser("~/.config/daily-hack/gsc-bot-key.json")
ENV_FILE = os.path.expanduser("~/openclaw/config/.env")
SLACK_CHANNEL = "C0A5FKU7T5M"
JORDAN = "<@U0A5V22PVTQ>"
STATE = pathlib.Path(os.path.expanduser("~/.config/daily-hack/seo-health-state.json"))

STALE_DAYS = 7          # サイトマップ最終取得がこの日数より古いと警報
URL_GAP_PCT = 5.0       # 登録 URL 数と実 URL 数の乖離許容率
INDEX_SCAN_BUDGET_SEC = 300   # インデックス走査の時間予算（超えたら打ち切って通知）

DRY = "--dry-run" in sys.argv
SKIP_INDEX = "--no-index" in sys.argv

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/130 Safari/537.36")


def fetch_text(url):
    """Cloudflare は Python の既定 UA を 403 で弾くのでブラウザ UA を名乗る。"""
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode()


def gsc_token(scope="https://www.googleapis.com/auth/webmasters.readonly"):
    from google.oauth2 import service_account
    import google.auth.transport.requests as gart
    c = service_account.Credentials.from_service_account_file(SA_KEY, scopes=[scope])
    c.refresh(gart.Request())
    return c.token


def api(url, token, body=None, method=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, method=method or ("POST" if body is not None else "GET"),
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return {"_error": e.code, "_body": e.read().decode()[:200]}


def sa_query(token, body):
    u = ("https://searchconsole.googleapis.com/webmasters/v3/sites/"
         + urllib.parse.quote(SITE, safe="") + "/searchAnalytics/query")
    return api(u, token, body)


def main():
    token = gsc_token()
    today = datetime.date.today()
    alerts, warns, lines = [], [], []

    # ---- 1. サイトマップ鮮度（最重要） ----
    sm = api("https://searchconsole.googleapis.com/webmasters/v3/sites/"
             + urllib.parse.quote(SITE, safe="") + "/sitemaps", token)
    live_urls = len(re.findall(r"<loc>", fetch_text(SITEMAP_URL)))
    sm_lines = []
    for m in sm.get("sitemap", []):
        name = m["path"].rsplit("/", 1)[-1]
        dl = (m.get("lastDownloaded") or "")[:10]
        submitted = int((m.get("contents") or [{}])[0].get("submitted") or 0)
        age = None
        if dl:
            age = (today - datetime.date.fromisoformat(dl)).days
            if age > STALE_DAYS:
                alerts.append(f"サイトマップ `{name}` が *{age}日* 取得されていない（最終 {dl}）")
        else:
            alerts.append(f"サイトマップ `{name}` が一度も取得されていない")
        # sitemap-index.xml は子サイトマップを指すだけで <loc> にページ URL を持たない。
        # GSC 側の集計も遅れて追随するため、URL 数の乖離判定は実体サイトマップだけに適用する。
        if "index" not in name:
            gap = abs(submitted - live_urls) / max(live_urls, 1) * 100
            if submitted and gap > URL_GAP_PCT:
                alerts.append(f"`{name}` の登録URL数 {submitted} が実際の {live_urls} と乖離（{gap:.0f}%）")
        sm_lines.append(f"  {name}: 最終取得 {dl or '—'}"
                        + (f"（{age}日前）" if age is not None else "")
                        + f" / 登録 {submitted} 件")
    lines.append("*サイトマップ*\n" + "\n".join(sm_lines) + f"\n  実URL数: {live_urls} 件")

    # ---- 2. GSC 直近7日 vs 前7日 ----
    def window(d0, d1):
        return str(today - datetime.timedelta(days=d0)), str(today - datetime.timedelta(days=d1))

    def totals(a, b):
        r = sa_query(token, {"startDate": a, "endDate": b, "dimensions": [], "dataState": "all"})
        row = (r.get("rows") or [{}])[0]
        return dict(clicks=row.get("clicks", 0), imp=row.get("impressions", 0),
                    ctr=row.get("ctr", 0) * 100, pos=row.get("position", 0))

    cur = totals(*window(10, 4))    # GSC は約3日遅延するので 4 日前まで
    prv = totals(*window(17, 11))

    def delta(c, p, unit="", inv=False):
        d = c - p
        mark = "→" if abs(d) < 1e-9 else ("↑" if (d > 0) != inv else "↓")
        return f"{c:,.1f}{unit} ({mark}{abs(d):,.1f})" if isinstance(c, float) else f"{c}{unit}"

    lines.append(
        "*Search Console（直近7日 / 前7日比）*\n"
        f"  クリック {cur['clicks']:.0f} ({cur['clicks']-prv['clicks']:+.0f})\n"
        f"  表示回数 {cur['imp']:.0f} ({cur['imp']-prv['imp']:+.0f})\n"
        f"  CTR {cur['ctr']:.2f}% ({cur['ctr']-prv['ctr']:+.2f}pt)\n"
        f"  平均順位 {cur['pos']:.1f} ({prv['pos']-cur['pos']:+.1f} 改善)"
    )
    if prv["imp"] > 20 and cur["imp"] < prv["imp"] * 0.6:
        alerts.append(f"表示回数が前週比 {(1-cur['imp']/prv['imp'])*100:.0f}% 減（{prv['imp']:.0f}→{cur['imp']:.0f}）")

    # ---- 3. 表示回数 上位ページ ----
    a, b = window(10, 4)
    tp = sa_query(token, {"startDate": a, "endDate": b, "dimensions": ["page"],
                          "rowLimit": 5, "dataState": "all"})
    if tp.get("rows"):
        top = "\n".join(
            f"  {r['impressions']:>4.0f}imp {r['clicks']:>2.0f}clk 順位{r['position']:>5.1f}  "
            + r["keys"][0].replace("https://daily-hack.fieldbeside.com", "")
            for r in tp["rows"])
        lines.append("*表示上位ページ*\n" + top)

    # ---- 4. インデックス状況 ----
    prev = json.loads(STATE.read_text()) if STATE.exists() else {}
    idx_summary = {}
    next_offset = prev.get("scan_offset", 0)
    if not SKIP_INDEX:
        wtok = gsc_token("https://www.googleapis.com/auth/webmasters")
        posts = [u for u in re.findall(
            r"<loc>([^<]+)</loc>",
            fetch_text(SITEMAP_URL)) if "/posts/" in u]
        # 走査がハングすると「警報が二度と鳴らない」= 今回直している失敗と同じになる。
        # 時間予算を超えたら打ち切り、途中結果 + 打ち切った旨を必ず通知する。
        # 全件は時間予算に収まらないので、前回の続きから順繰りに走査する。
        # 毎回同じ先頭N本だけを見て後半を永久に見落とす、という事態を防ぐ。
        offset = prev.get("scan_offset", 0) % max(len(posts), 1)
        posts = posts[offset:] + posts[:offset]
        scan_start = time.monotonic()
        scanned = 0
        for u in posts:
            if time.monotonic() - scan_start > INDEX_SCAN_BUDGET_SEC:
                break
            r = api("https://searchconsole.googleapis.com/v1/urlInspection/index:inspect", wtok,
                    {"inspectionUrl": u, "siteUrl": SITE, "languageCode": "ja"})
            cov = (r.get("inspectionResult", {}).get("indexStatusResult", {})
                    .get("coverageState", "ERR"))
            idx_summary[cov] = idx_summary.get(cov, 0) + 1
            scanned += 1
        bad = sum(v for k, v in idx_summary.items() if "登録されました" not in k)
        next_offset = (offset + scanned) % max(len(posts), 1)
        note = f"（全{len(posts)}本中 {scanned}本を順繰り走査。次回は{next_offset}番目から）"
        lines.append(f"*インデックス* {note}\n" + "\n".join(f"  {v:>3}本  {k}" for k, v in
                     sorted(idx_summary.items(), key=lambda x: -x[1])))
        # 走査本数は毎回変わるので、絶対数ではなく「未登録率」で比較する。
        # （4本走査で2本 と 40本走査で5本 を単純比較すると誤警報になる）
        rate = bad / max(scanned, 1)
        prate = prev.get("index_bad_rate")
        if prate is not None and scanned >= 10 and rate > prate + 0.10:
            warns.append(f"未インデックス率が {prate*100:.0f}% → {rate*100:.0f}% に悪化")

    # ---- 通知 ----
    head = "🚨 *SEO health — 異常あり*" if alerts else ("⚠️ *SEO health — 要確認*" if warns else "✅ *SEO health — 正常*")
    body = [head, f"_{SITE}  {today}_", ""]
    if alerts:
        body.append("*🚨 対処が必要*\n" + "\n".join(f"  • {a}" for a in alerts) + "\n")
    if warns:
        body.append("*⚠️ 注意*\n" + "\n".join(f"  • {w}" for w in warns) + "\n")
    body += lines
    if alerts:
        body.append(f"\n{JORDAN} 対処が必要です")
    msg = "\n".join(body)

    print(msg)
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps({
        "date": str(today), "clicks": cur["clicks"], "imp": cur["imp"],
        "index_bad": sum(v for k, v in idx_summary.items() if "登録されました" not in k) if idx_summary else prev.get("index_bad"),
        "scan_offset": next_offset if idx_summary else prev.get("scan_offset", 0),
        "index_bad_rate": (round(bad / max(scanned, 1), 3) if idx_summary and scanned >= 10
                           else prev.get("index_bad_rate")),
    }, ensure_ascii=False, indent=1))

    if DRY:
        print("\n[dry-run] Slack へは送信していません")
        return

    tok = ""
    for line in open(ENV_FILE):
        if line.startswith("OPENCLAW_BOT_TOKEN="):
            tok = line.split("=", 1)[1].strip().strip('"')
    if not tok:
        print("OPENCLAW_BOT_TOKEN が見つからず Slack 送信をスキップ", file=sys.stderr)
        sys.exit(1)
    req = urllib.request.Request(
        "https://slack.com/api/chat.postMessage",
        data=json.dumps({"channel": SLACK_CHANNEL, "text": msg}).encode(),
        headers={"Authorization": "Bearer " + tok,
                 "Content-Type": "application/json; charset=utf-8"})
    with urllib.request.urlopen(req, timeout=30) as r:
        res = json.loads(r.read())
    print("Slack:", "OK" if res.get("ok") else res)
    if not res.get("ok"):
        sys.exit(1)


def notify_failure(err):
    """監視自体がコケた時に沈黙しないための最後の砦。"""
    tok = ""
    try:
        for line in open(ENV_FILE):
            if line.startswith("OPENCLAW_BOT_TOKEN="):
                tok = line.split("=", 1)[1].strip().strip('"')
        if not tok or DRY:
            return
        msg = f"🚨 *SEO health モニタ自体が失敗しました*\n```{err}```\n{JORDAN} 確認してください"
        req = urllib.request.Request(
            "https://slack.com/api/chat.postMessage",
            data=json.dumps({"channel": SLACK_CHANNEL, "text": msg}).encode(),
            headers={"Authorization": "Bearer " + tok,
                     "Content-Type": "application/json; charset=utf-8"})
        urllib.request.urlopen(req, timeout=30).read()
    except Exception:
        pass


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        import traceback
        tb = traceback.format_exc()[-800:]
        print(tb, file=sys.stderr)
        notify_failure(tb)
        sys.exit(1)
