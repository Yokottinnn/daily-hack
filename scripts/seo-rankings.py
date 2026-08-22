#!/usr/bin/env python3
"""GSC の掲載順位を「順位の高い順」で出す。

`top-articles.py` は GSC の既定順（クリック降順）で出すため、
**クリックが 0 でも 1〜5 位に入っている記事が一覧の下に埋もれる。**
週次レポートが拾っていた「惜しい記事（6〜20 位）」も同じで、
**上位に付けている記事は条件から外れて構造的に見えなかった。**

このスクリプトは順位そのものを主役にする。

    python3 scripts/seo-rankings.py                 # 標準出力に Markdown
    python3 scripts/seo-rankings.py --out report.md # ファイルに書く
    python3 scripts/seo-rankings.py --days 28 --min-impressions 3

記事ごとの「当たり語」も出す。**記事単位の平均順位は語ごとの順位を混ぜた値**なので、
どの語で上位に出ているかは記事の平均順位からは分からない。page×query を 1 リクエストで
取って記事ごとに並べ直している。表示回数が少ない語は GSC 側が匿名化して返さないため、
表示の少ない記事では語が 1 つも出ないことがある。

GSC API は無料。LLM を呼ばないため API クレジットは消費しない。
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
ENDPOINT = (
    "https://searchconsole.googleapis.com/webmasters/v3/sites/"
    f"{urllib.parse.quote(SITE, safe='')}/searchAnalytics/query"
)


def find_gcloud():
    """launchd 経由だと PATH が最小限（/usr/bin:/bin:/usr/sbin:/sbin）になり、
    Homebrew や Cloud SDK の gcloud が見つからない。実パスを自分で探す。"""
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


def imp_token():
    gcloud = find_gcloud()
    if not gcloud:
        raise SystemExit(
            "gcloud が見つからない。PATH=" + os.environ.get("PATH", "")[:200]
            + " / GCLOUD_BIN を設定するか実パスを通すこと")
    # gcloud は Python 3.9 では起動しない（2026-08-22 に実機で確認）。
    #   ERROR: gcloud failed to load. You are running gcloud with Python 3.9,
    #   which is no longer supported by gcloud.
    # launchd 経由だと gcloud が拾うのはシステムの 3.9 なので、
    # **このスクリプトを動かしている 3.11 を明示的に渡す。**
    env = dict(os.environ)
    if sys.version_info >= (3, 10):
        env["CLOUDSDK_PYTHON"] = sys.executable
    r = subprocess.run(
        [gcloud, "auth", "print-access-token", f"--account={SA}",
         "--scopes=https://www.googleapis.com/auth/webmasters"],
        capture_output=True, text=True, env=env)
    if r.returncode != 0:
        # **トークンは絶対に出さない。** 出すのは gcloud のエラーだけ。
        err = (r.stderr or "").strip().replace("\n", " ")[:600]
        raise SystemExit(f"gcloud の認証に失敗（{gcloud} / rc={r.returncode}）: {err}")
    tok = r.stdout.strip()
    if not tok:
        raise SystemExit(f"gcloud がトークンを返さなかった（{gcloud} / rc=0）")
    return tok


def query(token, body):
    req = urllib.request.Request(
        ENDPOINT, data=json.dumps(body).encode(), method="POST",
        headers={"Authorization": f"Bearer {token}",
                 "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        detail = (e.read() or b"").decode(errors="replace")[:300]
        raise SystemExit(f"GSC API エラー status={e.code}: {detail}")


def rows_for(token, dimensions, start, end, limit):
    if isinstance(dimensions, str):
        dimensions = [dimensions]
    res = query(token, {
        "startDate": str(start), "endDate": str(end),
        "dimensions": dimensions, "rowLimit": limit, "type": "web",
    })
    return res.get("rows", [])


def bucket(pos):
    if pos < 3.5:
        return "1〜3 位"
    if pos < 10.5:
        return "4〜10 位"
    if pos < 20.5:
        return "11〜20 位"
    return "21 位以下"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=28)
    ap.add_argument("--min-impressions", type=int, default=1,
                    help="この表示回数に満たない行は順位が不安定なので除く")
    ap.add_argument("--top", type=int, default=10)
    ap.add_argument("--article-queries", type=int, default=10,
                    help="当たり語を出す記事の数（表示の多い順）")
    ap.add_argument("--queries-per-article", type=int, default=15)
    ap.add_argument("--out")
    args = ap.parse_args()

    # GSC のデータ確定には 2〜3 日かかる。直近日を含めると順位が過小に出る。
    end = datetime.date.today() - datetime.timedelta(days=3)
    start = end - datetime.timedelta(days=args.days - 1)

    token = imp_token()
    pages = rows_for(token, "page", start, end, 500)
    queries = rows_for(token, "query", start, end, 100)
    # 記事ごとの当たり語。page×query は 1 リクエストで全記事ぶん取れる。
    pairs = rows_for(token, ["page", "query"], start, end, 5000)

    kept = [r for r in pages if r["impressions"] >= args.min_impressions]
    kept.sort(key=lambda r: r["position"])

    total_clicks = sum(r["clicks"] for r in pages)
    total_impr = sum(r["impressions"] for r in pages)
    avg_pos = (sum(r["position"] * r["impressions"] for r in pages) / total_impr
               if total_impr else 0.0)

    L = []
    L.append(f"# 掲載順位レポート（{start} 〜 {end}・{args.days} 日）")
    L.append("")
    L.append(f"出典: Google Search Console / {SITE}")
    L.append(f"直近 3 日はデータ未確定のため除外している。")
    L.append("")
    L.append("| 全体 | 値 |")
    L.append("| --- | --- |")
    L.append(f"| クリック | {int(total_clicks)} |")
    L.append(f"| 表示 | {int(total_impr)} |")
    ctr = (total_clicks / total_impr * 100) if total_impr else 0.0
    L.append(f"| CTR | {ctr:.1f}% |")
    L.append(f"| 平均掲載順位（表示で加重） | {avg_pos:.1f} 位 |")
    L.append(f"| 検索に出た記事数 | {len(pages)} |")
    L.append("")

    L.append(f"## 順位が高い記事 TOP{args.top}（表示 {args.min_impressions} 回以上）")
    L.append("")
    if not kept:
        L.append("該当なし。")
    else:
        L.append("| # | 平均順位 | 表示 | クリック | CTR | ページ |")
        L.append("| --- | --- | --- | --- | --- | --- |")
        for i, r in enumerate(kept[:args.top], 1):
            page = r["keys"][0].replace(SITE.rstrip("/"), "")
            L.append(f"| {i} | **{r['position']:.1f} 位** | {int(r['impressions'])} | "
                     f"{int(r['clicks'])} | {r['ctr']*100:.1f}% | `{page}` |")
    L.append("")

    L.append("## 順位帯ごとの記事数")
    L.append("")
    L.append("| 順位帯 | 記事数 | 表示合計 |")
    L.append("| --- | --- | --- |")
    for name in ("1〜3 位", "4〜10 位", "11〜20 位", "21 位以下"):
        sel = [r for r in kept if bucket(r["position"]) == name]
        L.append(f"| {name} | {len(sel)} | {int(sum(r['impressions'] for r in sel))} |")
    L.append("")

    near = [r for r in kept if 5.5 <= r["position"] <= 20.5 and r["impressions"] >= 5]
    L.append("## 惜しい記事（6〜20 位・表示 5 回以上）")
    L.append("")
    if not near:
        L.append("該当なし。")
    else:
        L.append("| 平均順位 | 表示 | クリック | ページ |")
        L.append("| --- | --- | --- | --- |")
        for r in near:
            page = r["keys"][0].replace(SITE.rstrip("/"), "")
            L.append(f"| {r['position']:.1f} 位 | {int(r['impressions'])} | "
                     f"{int(r['clicks'])} | `{page}` |")
    L.append("")

    L.append("## 順位が高いクエリ TOP15（表示 1 回以上）")
    L.append("")
    qk = sorted((r for r in queries if r["impressions"] >= 1),
                key=lambda r: r["position"])[:15]
    if not qk:
        L.append("該当なし。")
    else:
        L.append("| 平均順位 | 表示 | クリック | クエリ |")
        L.append("| --- | --- | --- | --- |")
        for r in qk:
            L.append(f"| {r['position']:.1f} 位 | {int(r['impressions'])} | "
                     f"{int(r['clicks'])} | {r['keys'][0]} |")
    L.append("")

    L.append("## 記事ごとの当たり語（表示の多い記事から）")
    L.append("")
    L.append("**「この記事はどの語で上位に出ているか」を見るための表。**")
    L.append("記事単位の平均順位は語ごとの順位を混ぜた値なので、")
    L.append("どの語で勝っているかは記事の平均順位からは分からない。")
    L.append("")
    by_page = {}
    for r in pairs:
        by_page.setdefault(r["keys"][0], []).append(r)
    ranked_pages = sorted(kept, key=lambda r: -r["impressions"])[:args.article_queries]
    for pr in ranked_pages:
        url = pr["keys"][0]
        page = url.replace(SITE.rstrip("/"), "")
        qs = sorted(by_page.get(url, []), key=lambda r: r["position"])
        L.append(f"### `{page}`")
        L.append("")
        L.append(f"記事全体: 平均 {pr['position']:.1f} 位 / 表示 {int(pr['impressions'])} / "
                 f"クリック {int(pr['clicks'])}")
        L.append("")
        if not qs:
            L.append("クエリ単位の記録なし（表示が少なく GSC が語を出していない）。")
            L.append("")
            continue
        L.append("| 平均順位 | 表示 | クリック | クエリ |")
        L.append("| --- | --- | --- | --- |")
        for r in qs[:args.queries_per_article]:
            L.append(f"| {r['position']:.1f} 位 | {int(r['impressions'])} | "
                     f"{int(r['clicks'])} | {r['keys'][1]} |")
        if len(qs) > args.queries_per_article:
            L.append(f"| … | | | 他 {len(qs) - args.queries_per_article} 語 |")
        L.append("")

    L.append("## 全記事（順位の高い順）")
    L.append("")
    L.append("| 平均順位 | 表示 | クリック | ページ |")
    L.append("| --- | --- | --- | --- |")
    for r in kept:
        page = r["keys"][0].replace(SITE.rstrip("/"), "")
        L.append(f"| {r['position']:.1f} 位 | {int(r['impressions'])} | "
                 f"{int(r['clicks'])} | `{page}` |")
    L.append("")

    text = "\n".join(L)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"書き出した: {args.out}（{len(kept)} 記事）")
    else:
        print(text)


if __name__ == "__main__":
    sys.exit(main())
