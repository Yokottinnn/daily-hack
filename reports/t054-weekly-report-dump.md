# 週次ブログレポートの実体（t054 / 読み取りのみ）

## launchd の登録状況
```
-	0	com.apple.pluginkit.pkreporter
-	0	com.microsoft.SyncReporter
-	0	com.apple.DiagnosticsReporter
-	0	com.apple.loginwindow.LWWeeklyMessageTracer
-	-9	com.apple.ReportCrash
-	0	com.dailyhack.weekly-blog-report
```

## plist: `/Users/ny/Library/LaunchAgents/com.dailyhack.weekly-blog-report.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.dailyhack.weekly-blog-report</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/python3.11</string>
    <string>/Users/ny/scripts/weekly-blog-report.py</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <key>StartCalendarInterval</key>
  <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>8</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>/Users/ny/Library/Logs/weekly-blog-report.log</string>
  <key>StandardErrorPath</key><string>/Users/ny/Library/Logs/weekly-blog-report.err</string>
</dict>
</plist>
```

## 呼ばれているスクリプト

### `/Users/ny/scripts/weekly-blog-report.py`
```
#!/usr/bin/env python3.11
"""週次ブログ分析レポート（統合版 / home-mac 一本化）

データ源:
  - GSC Search Analytics : サービスアカウント鍵から直接トークン発行（gcloud非依存）
  - Cloudflare PV        : GitHub Actions `weekly-pv-report` を dispatch し stdout を読む
                           （CF zone-analytics トークンは GHA secret ***MASKED***
  - 出力                 : Slack #fun_reward-hack-blog（OpenClaw bot）

毎週月曜 08:00 JST に launchd `com.dailyhack.weekly-blog-report` で実行。
手動: ssh home-mac 'python3.11 ~/scripts/weekly-blog-report.py'
"""
import os, sys, json, subprocess, urllib.parse, urllib.request, datetime, time

# ---- config ----
SA_KEY = os.path.expanduser("~/.config/daily-hack/gsc-bot-key.json")
SITE   = "https://daily-hack.fieldbeside.com/"
CH     = "C0B4CJHH797"  # #fun_reward-hack-blog
ENV    = os.path.expanduser("~/openclaw/config/.env")
REPO   = "Yokottinnn/daily-hack"
GSC_SCOPE = ["https://www.googleapis.com/auth/webmasters.readonly"]

def load_env(path):
    env = {}
    with open(path) as f:
        for line in f:
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    return env

# ---------- GSC ----------
def gsc_token():
    from google.oauth2 import service_account
    from google.auth.transport.requests import Request
    creds = service_account.Credentials.from_service_account_file(SA_KEY, scopes=GSC_SCOPE)
    creds.refresh(Request())
    return creds.token

def gsc_query(tok, days, dims, limit=25, offset_end=2):
    end = datetime.date.today() - datetime.timedelta(days=offset_end)  # GSC lags ~2d
    start = end - datetime.timedelta(days=days - 1)
    body = {"startDate": str(start), "endDate": str(end), "dimensions": dims, "rowLimit": limit}
    url = ("https://searchconsole.googleapis.com/webmasters/v3/sites/"
           + urllib.parse.quote(SITE, safe="") + "/searchAnalytics/query")
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read()).get("rows", []), start, end

def gsc_data():
    tok = gsc_token()
    out = {}
    for d in (7, 28, 90):
        rows, s, e = gsc_query(tok, d, [], 1)
        r = rows[0] if rows else {}
        out[f"t{d}"] = dict(start=str(s), end=str(e), clicks=r.get("clicks", 0),
            impr=r.get("impressions", 0), ctr=round(r.get("ctr", 0)*100, 1),
            pos=round(r.get("position", 0), 1))
    rows, _, _ = gsc_query(tok, 28, ["page"], 200)
    out["oshii"] = sorted(
        [r for r in rows if r["impressions"] >= 5 and 6 <= r["position"] <= 20.5],
        key=lambda r: -r["impressions"])[:6]
    for r in out["oshii"]:
        r["page"] = r["keys"][0].replace(SITE, "/")
    return out

# ---------- Cloudflare PV via GHA ----------
def cf_data(days=28):
    """GHA weekly-pv-report を dispatch → stdout の STDOUT_TOTALS / STDOUT_TOP を読む。"""
    subprocess.run(["gh", "workflow", "run", "weekly-pv-report.yml", "-R", REPO,
                    "-f", f"days={days}"], check=True, capture_output=True, timeout=60)
    time.sleep(22)
    rid = subprocess.run(["gh", "run", "list", "-R", REPO,
        "--workflow=weekly-pv-report.yml", "--limit", "1",
        "--json", "databaseId", "-q", ".[0].databaseId"],
        capture_output=True, text=True, timeout=60).stdout.strip()
    subprocess.run(["gh", "run", "watch", rid, "-R", REPO, "--exit-status"],
                   capture_output=True, timeout=300)
    log = subprocess.run(["gh", "run", "view", rid, "-R", REPO, "--log"],
                         capture_output=True, text=True, timeout=120).stdout
    totals, top, cap = {}, [], False
    for line in log.splitlines():
        if "STDOUT_TOTALS" in line:
            for kv in line.split("STDOUT_TOTALS", 1)[1].split():
                if "=" in kv:
                    k, v = kv.split("=", 1)
                    totals[k] = v
        elif "STDOUT_TOP_START" in line: cap = True
        elif "STDOUT_TOP_END" in line:   cap = False
        elif cap and "/posts/" in line:
            parts = line.split("/posts/", 1)[1].split("\t") if "\t" in line else None
            # log lines are prefixed; extract "visits\trequests\t/posts/..."
            seg = line.rstrip()
            idx = seg.find("/posts/")
            head = seg[:idx].split()
            if head:
                try:
                    visits = int(head[-2]); path = seg[idx:]
                    top.append((visits, path))
                except (ValueError, IndexError):
                    pass
    top = top[:10]
    return totals, top

# ---------- compose + post ----------
def build_msg(g, cf_totals, cf_top):
    today = datetime.date.today()
    t28, t90 = g["t28"], g["t90"]
    L = []
    L.append(f"📊 *Daily Hack ブログ 週次アクセス分析*（{today}）")
    L.append("")
    L.append("*■ サマリー（直近28日）*")
    if cf_totals:
        L.append(f"• CF visits（全パス）: *{cf_totals.get('visits','?')}* / requests {cf_totals.get('requests','?')}")
    L.append(f"• Google検索 表示: *{t28['impr']}* / クリック *{t28['clicks']}*（CTR{t28['ctr']}%・平均{t28['pos']}位）")
    L.append(f"• 90日累計: クリック{t90['clicks']} / 表示{t90['impr']}")
    L.append("")
    if cf_top:
        L.append("*■ 記事別 visits Top10（28日 / CF）*")
        for i, (v, p) in enumerate(cf_top, 1):
            name = p.replace("/posts/", "").rstrip("/")
            L.append(f"{i}. {name} … *{v}*")
        L.append("")
    if g["oshii"]:
        L.append("*■ SEOで\"惜しい\"記事（表示≥5・6〜20位＝あと一歩で1ページ目）*")
        for r in g["oshii"]:
            L.append(f"• {r['page']} … 表示{r['impressions']}・平均{round(r['position'],1)}位")
        L.append("")
    L.append("💡 *示唆*: CF visits ≫ 検索表示 なら流入はX/SNS主導。惜しい記事はタイトル/内部リンク強化でSEOクリック獲得を狙う。")
    L.append("")
    L.append("🤖 by ハッカー子（GSC=SAキー直 / CF=GHA / home-mac統合）")
    return "\n".join(L)

def main():
    g = gsc_data()
    try:
        cf_totals, cf_top = cf_data(28)
    except Exception as e:
        cf_totals, cf_top = {}, []
        print(f"[warn] CF fetch failed: {e}", file=sys.stderr)
    msg = build_msg(g, cf_totals, cf_top)
    print(msg)
    if "--dry-run" in sys.argv:
        return
    env = load_env(ENV)
    from slack_sdk import WebClient
    WebClient(token=***MASKED***"OPENCLAW_BOT_TOKEN"]).chat_postMessage(
        channel=CH, text=msg, unfurl_links=False)
    print("\n[posted to Slack]")

if __name__ == "__main__":
    main()
```

## 直近のログ（末尾 40 行ずつ）

### `/Users/ny/Library/Logs/weekly-blog-report.log`
```
📊 *Daily Hack ブログ 週次アクセス分析*（2026-08-24）

*■ サマリー（直近28日）*
• CF visits（全パス）: *${ALL_VISITS}* / requests ${ALL_REQ}
• Google検索 表示: *497* / クリック *28*（CTR5.6%・平均9.3位）
• 90日累計: クリック41 / 表示692

*■ SEOで"惜しい"記事（表示≥5・6〜20位＝あと一歩で1ページ目）*
• /posts/lalaport-guide-2026/ … 表示347・平均7.7位
• /posts/wangan-tower-construction-map-2026/ … 表示15・平均6.9位
• /posts/wangan-supermarkets-2026/ … 表示15・平均6.2位
• /posts/outlet-mall-guide-2026/ … 表示13・平均9.8位
• /posts/wangan-august-events-2026/ … 表示13・平均7.4位
• /author/ … 表示6・平均9.3位

💡 *示唆*: CF visits ≫ 検索表示 なら流入はX/SNS主導。惜しい記事はタイトル/内部リンク強化でSEOクリック獲得を狙う。

🤖 by ハッカー子（GSC=SAキー直 / CF=GHA / home-mac統合）

[posted to Slack]
📊 *Daily Hack ブログ 週次アクセス分析*（2026-08-31）

*■ サマリー（直近28日）*
• CF visits（全パス）: *${ALL_VISITS}* / requests ${ALL_REQ}
• Google検索 表示: *628* / クリック *32*（CTR5.1%・平均9.1位）
• 90日累計: クリック42 / 表示840

*■ SEOで"惜しい"記事（表示≥5・6〜20位＝あと一歩で1ページ目）*
• /posts/lalaport-guide-2026/ … 表示439・平均7.8位
• /posts/wangan-tower-construction-map-2026/ … 表示25・平均6.6位
• /posts/wangan-august-events-2026/ … 表示20・平均7.2位
• /posts/outlet-mall-guide-2026/ … 表示19・平均8.6位
• /posts/budget-overseas-resorts-2026/ … 表示18・平均7.8位
• /posts/wangan-supermarkets-2026/ … 表示18・平均6.1位

💡 *示唆*: CF visits ≫ 検索表示 なら流入はX/SNS主導。惜しい記事はタイトル/内部リンク強化でSEOクリック獲得を狙う。

🤖 by ハッカー子（GSC=SAキー直 / CF=GHA / home-mac統合）

[posted to Slack]
```
