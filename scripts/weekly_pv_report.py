#!/usr/bin/env python3
"""Weekly PV レポート: Cloudflare Web Analytics → Slack 投稿

依存: 標準ライブラリのみ（urllib + json）。requests 不要。

必要な環境変数:
  CLOUDFLARE_API_TOKEN     CF API トークン（Account Analytics:Read スコープ）
  CLOUDFLARE_ACCOUNT_TAG   CF アカウント ID（ダッシュボード URL の /accounts/<tag> 部分）
  CLOUDFLARE_SITE_TAG      CF Web Analytics のサイト UUID（dash → Web Analytics → サイト詳細）
  SLACK_BOT_TOKEN          Slack Bot User OAuth Token（xoxb-...）
  SLACK_CHANNEL_ID         投稿先チャンネル ID（既定: C0B4CJHH797 = #fun_reward-hack-blog）

実行:
  python scripts/weekly_pv_report.py
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from urllib import request
from urllib.error import HTTPError, URLError

CF_GRAPHQL_URL = "https://api.cloudflare.com/client/v4/graphql"
SLACK_POSTMESSAGE_URL = "https://slack.com/api/chat.postMessage"
DEFAULT_CHANNEL = "C0B4CJHH797"  # #fun_reward-hack-blog


def env(name: str, required: bool = True) -> str:
    value = os.environ.get(name, "").strip()
    if required and not value:
        sys.stderr.write(f"ERROR: env {name} is missing\n")
        sys.exit(1)
    return value


def post_json(url: str, headers: dict, payload: dict, timeout: int = 30) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = request.Request(url, data=body, headers=headers, method="POST")
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except HTTPError as e:
        return {"_error": f"HTTP {e.code}", "_body": e.read().decode("utf-8", errors="replace")}
    except URLError as e:
        return {"_error": str(e)}


def query_cf_analytics(token: str, account_tag: str, site_tag: str, since: str, until: str) -> dict:
    """直近期間の rumPageloadEventsAdaptiveGroups から PV / UV を集計"""
    query = """
    query WeeklyReport($accountTag: string!, $siteTag: string!, $since: Time!, $until: Time!) {
      viewer {
        accounts(filter: {accountTag: $accountTag}) {
          totals: rumPageloadEventsAdaptiveGroups(
            limit: 1
            filter: {siteTag: $siteTag, date_geq: $since, date_lt: $until}
          ) {
            count
            sum { visits }
          }
          byPath: rumPageloadEventsAdaptiveGroups(
            limit: 30
            filter: {siteTag: $siteTag, date_geq: $since, date_lt: $until}
            orderBy: [count_DESC]
          ) {
            count
            sum { visits }
            dimensions { metric: requestPath }
          }
          byCountry: rumPageloadEventsAdaptiveGroups(
            limit: 10
            filter: {siteTag: $siteTag, date_geq: $since, date_lt: $until}
            orderBy: [count_DESC]
          ) {
            count
            dimensions { metric: countryName }
          }
          byReferer: rumPageloadEventsAdaptiveGroups(
            limit: 10
            filter: {siteTag: $siteTag, date_geq: $since, date_lt: $until}
            orderBy: [count_DESC]
          ) {
            count
            dimensions { metric: refererHost }
          }
        }
      }
    }
    """
    payload = {
        "query": query,
        "variables": {
            "accountTag": account_tag,
            "siteTag": site_tag,
            "since": since,
            "until": until,
        },
    }
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    return post_json(CF_GRAPHQL_URL, headers, payload)


def fmt_section(title: str, rows: list[tuple[str, int]], emoji: str = "📊") -> str:
    if not rows:
        return f"{emoji} *{title}*\n(データなし)"
    lines = [f"{emoji} *{title}*"]
    for label, count in rows:
        lines.append(f"  • `{count:>5,}` {label}")
    return "\n".join(lines)


def build_slack_text(data: dict, since_iso: str, until_iso: str) -> str:
    accounts = (((data.get("data") or {}).get("viewer") or {}).get("accounts") or [])
    if not accounts:
        return (
            ":warning: *Weekly PV レポート: データ取得失敗*\n"
            f"```{json.dumps(data, ensure_ascii=False, indent=2)[:1500]}```"
        )
    acc = accounts[0]

    totals = acc.get("totals") or []
    total_pv = sum(r.get("count", 0) for r in totals)
    total_visits = sum((r.get("sum") or {}).get("visits", 0) for r in totals)

    paths = [
        ((r.get("dimensions") or {}).get("metric") or "(unknown)", r.get("count", 0))
        for r in (acc.get("byPath") or [])
    ][:10]
    countries = [
        ((r.get("dimensions") or {}).get("metric") or "(unknown)", r.get("count", 0))
        for r in (acc.get("byCountry") or [])
    ][:5]
    referers = [
        ((r.get("dimensions") or {}).get("metric") or "(direct)", r.get("count", 0))
        for r in (acc.get("byReferer") or [])
    ][:5]

    header = (
        ":bar_chart: *Daily Hack Weekly PV レポート*\n"
        f"対象期間: `{since_iso}` 〜 `{until_iso}` (UTC)\n"
        f"*合計 PV*: `{total_pv:,}` ／ *総訪問*: `{total_visits:,}`\n"
    )
    parts = [
        header,
        fmt_section("人気 TOP 10 ページ (PV)", paths, "📄"),
        fmt_section("国別 TOP 5", countries, "🌐"),
        fmt_section("流入元 TOP 5", referers, "🔗"),
        "_Cloudflare Web Analytics 30日リテンション。出典: dash.cloudflare.com_",
    ]
    return "\n\n".join(parts)


def post_to_slack(token: str, channel: str, text: str) -> dict:
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json; charset=utf-8",
    }
    payload = {"channel": channel, "text": text, "unfurl_links": False, "mrkdwn": True}
    return post_json(SLACK_POSTMESSAGE_URL, headers, payload)


def main() -> int:
    cf_token = env("CLOUDFLARE_API_TOKEN")
    account_tag = env("CLOUDFLARE_ACCOUNT_TAG")
    site_tag = env("CLOUDFLARE_SITE_TAG")
    slack_token = env("SLACK_BOT_TOKEN")
    channel = os.environ.get("SLACK_CHANNEL_ID", DEFAULT_CHANNEL).strip() or DEFAULT_CHANNEL

    until = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    since = until - timedelta(days=7)
    since_iso = since.strftime("%Y-%m-%dT%H:%M:%SZ")
    until_iso = until.strftime("%Y-%m-%dT%H:%M:%SZ")

    sys.stderr.write(f"querying CF Analytics {since_iso} -> {until_iso}\n")
    data = query_cf_analytics(cf_token, account_tag, site_tag, since_iso, until_iso)

    text = build_slack_text(data, since_iso, until_iso)
    sys.stdout.write(text + "\n")

    result = post_to_slack(slack_token, channel, text)
    if not result.get("ok"):
        sys.stderr.write(f"Slack post failed: {json.dumps(result, ensure_ascii=False)}\n")
        return 1
    sys.stderr.write(f"posted to Slack: {result.get('ts')}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
