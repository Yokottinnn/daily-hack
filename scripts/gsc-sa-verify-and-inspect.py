#!/usr/bin/env python3
"""
A完了スクリプト + Bを一括実行:
1. SAをSite Verification API FILE method で Search Console 所有者として登録
2. Search Console にプロパティ追加
3. Sitemap 再送信
4. 主要URLを URL Inspection API でクロール/インデックス状態取得
5. 結果サマリ出力

前提: SAキーは org policy で不可なので gcloud user → SA impersonation を使用。
gcloud user が n-yokota@fieldbeside.com (Owner) で認証済みであること。
"""
import json, subprocess, urllib.request, urllib.parse, sys, time

SA = "gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
SITE = "https://daily-hack.fieldbeside.com/"
SITEMAP = "https://daily-hack.fieldbeside.com/sitemap-0.xml"
VERIFY_TOKEN = "google86266bfef8a3a4f6.html"  # FILE method token

def imp_token(scopes):
    """gcloud user → SA impersonation で access token を取得"""
    r = subprocess.run(
        ["gcloud", "auth", "print-access-token",
         f"--impersonate-service-account={SA}",
         f"--scopes={','.join(scopes)}"],
        capture_output=True, text=True, check=True)
    return r.stdout.strip()

def api(method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": f"Bearer {token}",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=40) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read() or b"{}")
        except Exception: return e.code, {"raw": str(e)}

def main():
    # 0. 検証ファイル配信確認（CFはPython UAをブロックするので curl で）
    print("=== 0. verification file 到達確認 ===")
    for i in range(20):
        r = subprocess.run(
            ["curl", "-sL", "-A", "Mozilla/5.0 daily-hack-check",
             SITE + VERIFY_TOKEN], capture_output=True, text=True, timeout=15)
        if "google-site-verification" in r.stdout:
            print(f"  OK {SITE+VERIFY_TOKEN}  body={r.stdout!r}")
            break
        print(f"  poll {i+1} 待機")
        time.sleep(15)
    else:
        print("  TIMEOUT — verification file が本番に出ていない"); sys.exit(2)

    # 1. SA verify (FILE method)
    print("\n=== 1. SA を Site Verification API で所有者登録 (FILE method) ===")
    tok_sv = imp_token(["https://www.googleapis.com/auth/siteverification"])
    code, res = api("POST",
        "https://www.googleapis.com/siteVerification/v1/webResource?verificationMethod=FILE",
        tok_sv, body={"site": {"type": "SITE", "identifier": SITE}})
    print(f"  status={code}  res={json.dumps(res, ensure_ascii=False)[:300]}")
    if code not in (200, 201):
        print("  verify失敗 — 既に登録済みなら問題なし、続行");

    # 2. Search Console プロパティに追加
    print("\n=== 2. Search Console プロパティ追加（SAの管理対象に） ===")
    tok_wm = imp_token(["https://www.googleapis.com/auth/webmasters"])
    code, res = api("PUT",
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{urllib.parse.quote(SITE, safe='')}",
        tok_wm)
    print(f"  sites.add status={code}")
    code, res = api("GET",
        "https://searchconsole.googleapis.com/webmasters/v3/sites", tok_wm)
    print(f"  sites.list status={code}")
    if isinstance(res, dict) and "siteEntry" in res:
        for s in res["siteEntry"]:
            print(f"    - {s.get('siteUrl')}  perm={s.get('permissionLevel')}")

    # 3. Sitemap 再送信
    print("\n=== 3. Sitemap 再送信 ===")
    code, res = api("PUT",
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{urllib.parse.quote(SITE, safe='')}/sitemaps/{urllib.parse.quote(SITEMAP, safe='')}",
        tok_wm)
    print(f"  submit status={code}")
    code, res = api("GET",
        f"https://searchconsole.googleapis.com/webmasters/v3/sites/{urllib.parse.quote(SITE, safe='')}/sitemaps",
        tok_wm)
    if isinstance(res, dict) and "sitemap" in res:
        for s in res["sitemap"][:3]:
            print(f"    {s.get('path')}  isPending={s.get('isPending')} lastSubmitted={s.get('lastSubmitted')} warnings={s.get('warnings')} errors={s.get('errors')} contents={[c.get('submitted') for c in s.get('contents',[])][:3]}")

    # 4. 主要URL × URL Inspection
    print("\n=== 4. 主要URLの実インデックス状態 (URL Inspection API) ===")
    urls = [
        "https://daily-hack.fieldbeside.com/",
        "https://daily-hack.fieldbeside.com/posts/matsuya-60th-cashless-2026-jun/",
        "https://daily-hack.fieldbeside.com/posts/wangan-supermarkets-2026/",
        "https://daily-hack.fieldbeside.com/posts/summer-cospa-travel-2026/",
        "https://daily-hack.fieldbeside.com/posts/internet-line-comparison-2026/",
        "https://daily-hack.fieldbeside.com/posts/credit-card-no-annual-fee-comparison-2026/",
        "https://daily-hack.fieldbeside.com/posts/best-online-banks-2026/",
        "https://daily-hack.fieldbeside.com/posts/cheap-sim-comparison-2026/",
        "https://daily-hack.fieldbeside.com/posts/furusato-tax-beginner-guide-2026/",
        "https://daily-hack.fieldbeside.com/posts/fixed-cost-reduction-guide-2026/",
    ]
    summary = []
    for u in urls:
        code, res = api("POST",
            "https://searchconsole.googleapis.com/v1/urlInspection/index:inspect",
            tok_wm, body={"inspectionUrl": u, "siteUrl": SITE})
        ir = (res or {}).get("inspectionResult", {})
        idx = ir.get("indexStatusResult", {}) if isinstance(ir, dict) else {}
        cov = idx.get("coverageState", "?")
        rob = idx.get("robotsTxtState", "?")
        verdict = idx.get("verdict", "?")
        last = idx.get("lastCrawlTime", "-")
        google_can = idx.get("googleCanonical", "-")
        print(f"  [{verdict:>10}|{cov:>30}|robots={rob}] last={last}  {u}")
        summary.append({"url": u, "verdict": verdict, "coverage": cov, "robots": rob, "lastCrawl": last})

    # 5. 集計
    print("\n=== 5. SUMMARY ===")
    indexed = [s for s in summary if "PASS" in (s["verdict"] or "")]
    not_indexed = [s for s in summary if "PASS" not in (s["verdict"] or "")]
    print(f"  Indexed (verdict=PASS): {len(indexed)} / {len(summary)}")
    print(f"  Not yet indexed: {len(not_indexed)}")

if __name__ == "__main__":
    main()
