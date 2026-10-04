#!/usr/bin/env python3
"""月ごとの検索データを JSON で丸ごと出す。読むだけ・LLM 不使用・$0。

アクセス分析ページ（scripts/access-analysis/build.py）の元データ。
GSC の認証と取得は weekly-blog-report.py の関数をそのまま使う（gcloud の SA は Mac にしか無い）。

    python3.11 scripts/gsc-dump.py --month 2026-09 --out /tmp/gsc-2026-09.json

窓はカレンダー月でそろえる。
  pages_cur   : 対象月          pages_prev : その前の月
  pages_90d / pq_90d / queries_90d / dates_90d : 対象月を含む直近 3 か月
GSC は確定まで 2〜3 日かかるので、**翌月 4 日以降に走らせる。**
"""
import argparse, calendar, datetime, importlib.util, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def month_range(y, m):
    return datetime.date(y, m, 1), datetime.date(y, m, calendar.monthrange(y, m)[1])


def shift(y, m, k):
    i = y * 12 + (m - 1) + k
    return i // 12, i % 12 + 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--month", required=True, help="YYYY-MM")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    y, m = map(int, a.month.split("-"))

    spec = importlib.util.spec_from_file_location("wbr", os.path.join(HERE, "weekly-blog-report.py"))
    w = importlib.util.module_from_spec(spec); spec.loader.exec_module(w)

    cur = month_range(y, m)
    prev = month_range(*shift(y, m, -1))
    q90 = (month_range(*shift(y, m, -2))[0], cur[1])
    win = {
        "pages_cur": (["page"], *cur),
        "pages_prev": (["page"], *prev),
        "pages_90d": (["page"], *q90),
        "pq_90d": (["page", "query"], *q90),
        "queries_90d": (["query"], *q90),
        "dates_90d": (["date"], *q90),
    }
    tok = w.gsc_token()
    out = {"month": a.month, "generated": datetime.datetime.now().isoformat(timespec="seconds"),
           "windows": {}, "data": {}}
    for k, (dims, s, e) in win.items():
        rows = w.gsc_rows(tok, dims, s, e, 25000)
        out["windows"][k] = [str(s), str(e)]
        out["data"][k] = [{"keys": r["keys"], "c": int(r["clicks"]), "i": int(r["impressions"]),
                           "p": round(float(r["position"]), 2)} for r in rows]
        print(f"| `{k}` | {s} 〜 {e} | **{len(rows)}** 行 |")
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    json.load(open(a.out, encoding="utf-8"))  # 書いたものを読み直す（最上位ルール 13）


if __name__ == "__main__":
    sys.exit(main())
