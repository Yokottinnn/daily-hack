#!/usr/bin/env python3
"""Weekly PV レポート: GA4 Data API → Slack Incoming Webhook 投稿

必要な環境変数:
  GA4_PROPERTY_ID            GA4 プロパティID（数値。例: 1234567890）
                             GA4 → 管理 → プロパティ設定 → 「プロパティID」
  GA4_SERVICE_ACCOUNT_JSON   Google Cloud Service Account の JSON 秘密鍵（中身を丸ごと文字列で）
                             Service Account に GA4 プロパティへの「閲覧者」権限を付与しておくこと
  SLACK_WEBHOOK_URL          Slack Incoming Webhook URL（https://hooks.slack.com/services/...）

依存:
  pip install google-analytics-data
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from urllib import request
from urllib.error import HTTPError, URLError

try:
    from google.analytics.data_v1beta import BetaAnalyticsDataClient
    from google.analytics.data_v1beta.types import (
        DateRange,
        Dimension,
        Metric,
        OrderBy,
        RunReportRequest,
    )
    from google.oauth2 import service_account
except ImportError as e:
    sys.stderr.write(f"ERROR: missing dependency: {e}\nhint: pip install google-analytics-data\n")
    sys.exit(2)


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        sys.stderr.write(f"ERROR: env {name} is missing\n")
        sys.exit(1)
    return value


def make_client(sa_json: str) -> BetaAnalyticsDataClient:
    info = json.loads(sa_json)
    credentials = service_account.Credentials.from_service_account_info(
        info,
        scopes=["https://www.googleapis.com/auth/analytics.readonly"],
    )
    return BetaAnalyticsDataClient(credentials=credentials)


def query_ga4(
    client: BetaAnalyticsDataClient,
    property_id: str,
    start_date: str,
    end_date: str,
) -> dict:
    """直近7日間 (UTC) のサマリ + パス別 / 国別 / 流入元別を一気に取得"""
    prop = f"properties/{property_id}"
    date_range = DateRange(start_date=start_date, end_date=end_date)

    totals = client.run_report(
        RunReportRequest(
            property=prop,
            date_ranges=[date_range],
            metrics=[
                Metric(name="screenPageViews"),
                Metric(name="activeUsers"),
                Metric(name="sessions"),
            ],
        )
    )
    by_path = client.run_report(
        RunReportRequest(
            property=prop,
            date_ranges=[date_range],
            dimensions=[Dimension(name="pagePath")],
            metrics=[Metric(name="screenPageViews")],
            order_bys=[OrderBy(metric=OrderBy.MetricOrderBy(metric_name="screenPageViews"), desc=True)],
            limit=10,
        )
    )
    by_country = client.run_report(
        RunReportRequest(
            property=prop,
            date_ranges=[date_range],
            dimensions=[Dimension(name="country")],
            metrics=[Metric(name="screenPageViews")],
            order_bys=[OrderBy(metric=OrderBy.MetricOrderBy(metric_name="screenPageViews"), desc=True)],
            limit=5,
        )
    )
    by_source = client.run_report(
        RunReportRequest(
            property=prop,
            date_ranges=[date_range],
            dimensions=[Dimension(name="sessionSource")],
            metrics=[Metric(name="screenPageViews")],
            order_bys=[OrderBy(metric=OrderBy.MetricOrderBy(metric_name="screenPageViews"), desc=True)],
            limit=5,
        )
    )
    return {
        "totals": totals,
        "by_path": by_path,
        "by_country": by_country,
        "by_source": by_source,
    }


def fmt_rows(response, dim_idx: int = 0, metric_idx: int = 0) -> list[tuple[str, int]]:
    rows = []
    for r in getattr(response, "rows", []) or []:
        label = r.dimension_values[dim_idx].value if r.dimension_values else "(none)"
        value = int(r.metric_values[metric_idx].value or 0)
        rows.append((label, value))
    return rows


def fmt_section(title: str, rows: list[tuple[str, int]], emoji: str = "📊") -> str:
    if not rows:
        return f"{emoji} *{title}*\n(データなし)"
    lines = [f"{emoji} *{title}*"]
    for label, count in rows:
        lines.append(f"  • `{count:>5,}` {label}")
    return "\n".join(lines)


def build_slack_text(reports: dict, start_date: str, end_date: str) -> str:
    totals = reports["totals"]
    total_pv = 0
    total_users = 0
    total_sessions = 0
    if getattr(totals, "rows", None):
        row = totals.rows[0]
        total_pv = int(row.metric_values[0].value or 0)
        total_users = int(row.metric_values[1].value or 0)
        total_sessions = int(row.metric_values[2].value or 0)

    paths = fmt_rows(reports["by_path"])
    countries = fmt_rows(reports["by_country"])
    sources = fmt_rows(reports["by_source"])

    header = (
        ":bar_chart: *Daily Hack Weekly PV レポート（GA4）*\n"
        f"対象期間: `{start_date}` 〜 `{end_date}`\n"
        f"*ページビュー*: `{total_pv:,}` ／ *アクティブユーザー*: `{total_users:,}` ／ *セッション*: `{total_sessions:,}`\n"
    )
    parts = [
        header,
        fmt_section("人気 TOP 10 ページ", paths, "📄"),
        fmt_section("国別 TOP 5", countries, "🌐"),
        fmt_section("流入元 TOP 5", sources, "🔗"),
        "_GA4 Data API より取得。出典: analytics.google.com_",
    ]
    return "\n\n".join(parts)


def post_to_slack_webhook(webhook_url: str, text: str) -> dict:
    headers = {"Content-Type": "application/json; charset=utf-8"}
    body = json.dumps({"text": text}).encode("utf-8")
    req = request.Request(webhook_url, data=body, headers=headers, method="POST")
    try:
        with request.urlopen(req, timeout=30) as resp:
            text_resp = resp.read().decode("utf-8", errors="replace")
            return {"status": resp.status, "body": text_resp, "ok": resp.status == 200 and text_resp.strip() == "ok"}
    except HTTPError as e:
        return {"status": e.code, "body": e.read().decode("utf-8", errors="replace"), "ok": False}
    except URLError as e:
        return {"status": None, "body": str(e), "ok": False}


def main() -> int:
    property_id = env("GA4_PROPERTY_ID")
    sa_json = env("GA4_SERVICE_ACCOUNT_JSON")
    webhook_url = env("SLACK_WEBHOOK_URL")

    today_utc = datetime.now(timezone.utc).date()
    end_date = (today_utc - timedelta(days=1)).isoformat()  # yesterday
    start_date = (today_utc - timedelta(days=7)).isoformat()

    sys.stderr.write(f"querying GA4 property={property_id} {start_date} -> {end_date}\n")
    client = make_client(sa_json)
    reports = query_ga4(client, property_id, start_date, end_date)

    text = build_slack_text(reports, start_date, end_date)
    sys.stdout.write(text + "\n")

    result = post_to_slack_webhook(webhook_url, text)
    if not result.get("ok"):
        sys.stderr.write(f"Slack webhook post failed: {json.dumps(result, ensure_ascii=False)}\n")
        return 1
    sys.stderr.write("posted to Slack webhook\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
