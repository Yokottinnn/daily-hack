#!/bin/bash
# **累計の数字を取り直す。t064 は Cloudflare で頭打ち、GSC は接続で落ちた。**
#
# ## t064 で分かったこと
#
# Cloudflare は**累計を答えられない。**
#
#   7 日 …… 10 訪問／30 日 …… 40 訪問／90 日 …… **0**
#   180 日以上 …… `cannot request a time range wider than 13w2d`
#
# 13 週 2 日（約 93 日）が API の上限で、しかも 90 日で 0 が返る＝
# **Web Analytics の保持は実質 30 日**。累計はここからは出ない。
#
# GSC は `oauth2.googleapis.com` に繋がらずに落ちた。
# **Mac は AAAA を引けても IPv6 経路が無いことがある**（2026-09-06 に実測）。
# `weekly-blog-report.py` はこれを `retry_ipv4()` で回避している。同じ手を使う。
#
# ## 何を出すか
#
# GSC の**全期間（16 か月＝API の上限）**。クリック・表示回数・記事数。
# **クリックは延べで、ユニークユーザー数ではない。** そこは混ぜない。
#
# 出力は `$OPS_REPORT_DIR`。**トークンは絶対に出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの確認タスク）

set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t067-lifetime-gsc.md"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

[ -f "$REPO/scripts/weekly-blog-report.py" ] || {
  echo "weekly-blog-report.py が無い: $REPO/scripts/"; exit 1; }

"$PY" - "$REPO" "$OUT" <<'PYEOF'
import datetime as dt, importlib.util, sys

REPO, OUT = sys.argv[1], sys.argv[2]

# **既存の実装を使い回す。** 認証も IPv4 フォールバックもここに入っている。
spec = importlib.util.spec_from_file_location("wbr", REPO + "/scripts/weekly-blog-report.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

L = ["# 累計の数字（t067 / GSC 全期間）", ""]

today = dt.date.today()
# GSC が持っているのは 16 か月。それより前は API 側に無い。
start = (today - dt.timedelta(days=480)).isoformat()
end = (today - dt.timedelta(days=2)).isoformat()      # 確定していない直近 2 日は外す
L.append(f"対象: **{start} 〜 {end}**（GSC の保持上限 16 か月）")
L.append("")

try:
    tok = m.retry_ipv4(lambda: m.gsc_token())
except Exception as e:
    L.append(f"⚠️ **認証で落ちた。** {type(e).__name__}: {str(e)[:300]}")
    open(OUT, "w").write("\n".join(L) + "\n"); print("\n".join(L)); raise SystemExit(1)

def rows(dims, limit=5000):
    return m.retry_ipv4(lambda: m.gsc_rows(tok, dims, start, end, limit))

try:
    pages = rows(["page"])
    queries = rows(["query"])
    dates = rows(["date"])
except Exception as e:
    L.append(f"⚠️ **取得で落ちた。** {type(e).__name__}: {str(e)[:300]}")
    open(OUT, "w").write("\n".join(L) + "\n"); print("\n".join(L)); raise SystemExit(1)

clicks = sum(r.get("clicks", 0) for r in pages)
imps = sum(r.get("impressions", 0) for r in pages)

L += ["## 合計", "",
      "| 項目 | 値 |", "| --- | --- |",
      f"| クリック（**延べ**） | **{clicks:,.0f}** |",
      f"| 表示回数 | {imps:,.0f} |",
      f"| CTR | {(clicks/imps*100 if imps else 0):.2f}% |",
      f"| クリックのあった記事 | {sum(1 for r in pages if r.get('clicks',0)>0)} 本 |",
      f"| 表示のあった記事 | {len(pages)} 本 |",
      f"| クリックのあった検索語 | {sum(1 for r in queries if r.get('clicks',0)>0)} 語 |",
      f"| データのある日数 | {len(dates)} 日 |",
      ""]

if dates:
    ds = sorted(r["keys"][0] for r in dates)
    L.append(f"**実際にデータがあるのは {ds[0]} 〜 {ds[-1]}。** ここが計測の開始日と見てよい。")
    L.append("")

L += ["## 注意", "",
      "**クリックは延べで、ユニークユーザー数ではない。** 同じ人が 3 回 来れば 3 と数える。",
      "GSC はユニークユーザーを出さない指標なので、**「累計何人」は GSC からは出ない。**",
      "Cloudflare も保持が実質 30 日なので出ない（t064）。",
      "**累計のユニークユーザーを知りたいなら、別の計測を入れる必要がある。**", ""]

L += ["## クリック上位 15 本", "", "| 記事 | クリック | 表示 | 平均順位 |", "| --- | --- | --- | --- |"]
for r in sorted(pages, key=lambda x: -x.get("clicks", 0))[:15]:
    u = r["keys"][0].replace("https://daily-hack.fieldbeside.com", "")
    L.append(f"| `{u}` | {r.get('clicks',0):.0f} | {r.get('impressions',0):.0f} | {r.get('position',0):.1f} |")
L.append("")

L += ["## クリック上位 15 語", "", "| 検索語 | クリック | 表示 | 平均順位 |", "| --- | --- | --- | --- |"]
for r in sorted(queries, key=lambda x: -x.get("clicks", 0))[:15]:
    L.append(f"| {r['keys'][0]} | {r.get('clicks',0):.0f} | {r.get('impressions',0):.0f} | {r.get('position',0):.1f} |")

open(OUT, "w").write("\n".join(L) + "\n")
print("\n".join(L))
PYEOF
exit 0
