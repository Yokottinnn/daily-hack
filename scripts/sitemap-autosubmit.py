#!/usr/bin/env python3
"""
sitemap-autosubmit.py — サイトマップの変化を検知して Google Search Console に自動再送信する。

2026-08-08 追加。背景:
  サイトマップは build のたびに再生成・配信されるが、Google がいつ取りに来るかは
  向こう任せだった。実際に 2026-06-05 以降 2ヶ月取得されず、その間に公開した
  163 URL が「Google が存在を知らない」まま放置された。
  週次の seo-health-monitor はこれを「検知」できるが「予防」はできない。
  → 本スクリプトが予防を担当する。

なぜ GitHub Actions ではなく launchd なのか:
  - .github/workflows/ の変更には gh トークンの workflow スコープが必要で、
    現状それが無い（2026-08-08 時点）
  - デプロイ元が CI / OpenClaw / 手動 のどれであっても等しくカバーできる
  - Slack トークンと GSC SA キーが home-mac に既にあり Secret 複製が不要

挙動:
  - サイトマップ本文のハッシュが前回と変われば = 新記事が出た → GSC に再送信
  - 変化が無ければ何もしない（Slack も鳴らさない。ノイズを出さないため）
  - 送信失敗・取得失敗は必ず Slack に鳴らす

Usage:
  python3.11 scripts/sitemap-autosubmit.py
  python3.11 scripts/sitemap-autosubmit.py --dry-run
  python3.11 scripts/sitemap-autosubmit.py --force   # 変化が無くても送信
"""
import json, sys, re, os, hashlib, datetime, urllib.request, urllib.parse, pathlib

SITE = "https://daily-hack.fieldbeside.com/"
SITEMAPS = [
    "https://daily-hack.fieldbeside.com/sitemap-index.xml",
    "https://daily-hack.fieldbeside.com/sitemap-0.xml",
]
WATCH = "https://daily-hack.fieldbeside.com/sitemap-0.xml"   # 変化検知の対象（実体）
SA_KEY = os.path.expanduser("~/.config/daily-hack/gsc-bot-key.json")
ENV_FILE = os.path.expanduser("~/openclaw/config/.env")
SLACK_CHANNEL = "C0A5FKU7T5M"
JORDAN = "<@U0A5V22PVTQ>"
STATE = pathlib.Path(os.path.expanduser("~/.config/daily-hack/sitemap-autosubmit-state.json"))

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/130 Safari/537.36")

DRY = "--dry-run" in sys.argv
FORCE = "--force" in sys.argv


def slack(text):
    if DRY:
        print("[dry-run] Slack:", text.split("\n")[0])
        return
    tok = ""
    for line in open(ENV_FILE):
        if line.startswith("OPENCLAW_BOT_TOKEN="):
            tok = line.split("=", 1)[1].strip().strip('"')
    if not tok:
        print("OPENCLAW_BOT_TOKEN が無いため Slack 送信不可", file=sys.stderr)
        return
    req = urllib.request.Request(
        "https://slack.com/api/chat.postMessage",
        data=json.dumps({"channel": SLACK_CHANNEL, "text": text}).encode(),
        headers={"Authorization": "Bearer " + tok,
                 "Content-Type": "application/json; charset=utf-8"})
    urllib.request.urlopen(req, timeout=30).read()


def fetch(url):
    """Cloudflare は Python の既定 UA を 403 で弾くのでブラウザ UA を名乗る。"""
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode()


def main():
    body = fetch(WATCH)
    digest = hashlib.sha256(body.encode()).hexdigest()[:16]
    urls = re.findall(r"<loc>([^<]+)</loc>", body)
    posts = [u for u in urls if "/posts/" in u]

    prev = json.loads(STATE.read_text()) if STATE.exists() else {}
    if prev.get("digest") == digest and not FORCE:
        print(f"変化なし（URL {len(urls)}件 / digest {digest}）— 何もしない")
        return

    added = sorted(set(posts) - set(prev.get("posts", [])))
    removed = sorted(set(prev.get("posts", [])) - set(posts))

    from google.oauth2 import service_account
    import google.auth.transport.requests as gart
    creds = service_account.Credentials.from_service_account_file(
        SA_KEY, scopes=["https://www.googleapis.com/auth/webmasters"])
    creds.refresh(gart.Request())

    results = []
    for sm in SITEMAPS:
        u = ("https://searchconsole.googleapis.com/webmasters/v3/sites/"
             + urllib.parse.quote(SITE, safe="") + "/sitemaps/" + urllib.parse.quote(sm, safe=""))
        req = urllib.request.Request(
            u, method="PUT",
            headers={"Authorization": "Bearer " + creds.token, "Content-Length": "0"})
        name = sm.rsplit("/", 1)[-1]
        if DRY:
            results.append((name, "dry-run"))
            continue
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                results.append((name, f"OK {r.status}"))
        except urllib.error.HTTPError as e:
            results.append((name, f"NG {e.code}"))

    ok = all(r[1].startswith(("OK", "dry")) for r in results)
    head = "🔄 *サイトマップ自動再送信*" if ok else "🚨 *サイトマップ再送信に失敗*"
    msg = [head, f"URL {len(urls)}件（記事 {len(posts)}本）"]
    if added:
        msg.append("*新規:*\n" + "\n".join("  • " + a.replace(SITE, "/") for a in added[:10])
                   + (f"\n  ほか{len(added)-10}件" if len(added) > 10 else ""))
    if removed:
        msg.append(f"*削除: {len(removed)}件*")
    msg.append(" / ".join(f"{n}: {s}" for n, s in results))
    if not ok:
        msg.append(f"{JORDAN} 確認してください")
    text = "\n".join(msg)
    print(text)
    slack(text)

    if not DRY:
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(
            {"digest": digest, "posts": posts, "at": str(datetime.datetime.now())[:19]},
            ensure_ascii=False))
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        tb = traceback.format_exc()[-800:]
        print(tb, file=sys.stderr)
        try:
            slack(f"🚨 *sitemap-autosubmit が失敗*\n```{tb}```\n{JORDAN} 確認してください")
        except Exception:
            pass
        sys.exit(1)
