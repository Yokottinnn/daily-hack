#!/usr/bin/env python3
"""GSC Search Analytics + Cloudflare GraphQL Analytics で
   過去30日の上位記事をランキング。GSC SAは impersonation で叩く。"""
import json, subprocess, urllib.request, urllib.parse, sys, os, datetime

SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
SITE = "https://daily-hack.fieldbeside.com/"
DAYS = 30

def imp_token(scopes):
    r = subprocess.run(
        ["gcloud", "auth", "print-access-token",
         f"--impersonate-service-account={SA}",
         f"--scopes={','.join(scopes)}"],
        capture_output=True, text=True, check=True)
    return r.stdout.strip()

def api_post(url, token, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read() or b"{}")
        except Exception: return e.code, {"raw": str(e)}

def main():
    end = datetime.date.today()
    start = end - datetime.timedelta(days=DAYS)
    print(f"=== GSC Search Analytics 過去{DAYS}日 ({start} 〜 {end}) ===")
    tok = imp_token(["https://www.googleapis.com/auth/webmasters"])
    code, res = api_post(
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{urllib.parse.quote(SITE, safe='')}/searchAnalytics/query",
        tok, body={
            "startDate": str(start), "endDate": str(end),
            "dimensions": ["page"], "rowLimit": 25, "type": "web"
        })
    print(f"status={code}")
    rows = (res or {}).get("rows", [])
    if not rows:
        print("→ クリック・表示の記録なし（インデックス済み記事はあるが Google 検索結果からの実流入はまだ）")
    else:
        print(f"\n{'順':>3} {'クリック':>7} {'表示':>7} {'CTR':>6} {'平均順位':>7}  ページ")
        for i, r in enumerate(rows, 1):
            page = r["keys"][0].replace(SITE.rstrip("/"), "")
            print(f"{i:>3} {int(r['clicks']):>7} {int(r['impressions']):>7} {r['ctr']*100:>5.1f}% {r['position']:>7.1f}  {page}")

    print(f"\n=== 同期間 上位検索クエリ ===")
    code, res = api_post(
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{urllib.parse.quote(SITE, safe='')}/searchAnalytics/query",
        tok, body={
            "startDate": str(start), "endDate": str(end),
            "dimensions": ["query"], "rowLimit": 15, "type": "web"
        })
    rows = (res or {}).get("rows", [])
    if not rows:
        print("→ クエリ記録なし")
    else:
        for i, r in enumerate(rows, 1):
            print(f"{i:>3} clicks={int(r['clicks']):>4} impr={int(r['impressions']):>4} pos={r['position']:>5.1f}  \"{r['keys'][0]}\"")

if __name__ == "__main__":
    main()
