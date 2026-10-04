#!/bin/bash
# **検索候補（Google のオートコンプリート）を取る（t209）。読むだけ・LLM 不使用・$0。**
#
# 利用者の指示（2026-10-04）:「最新のトレンドを分析して探して、直近で作ったら面白そうな記事のタイトルと骨子を10個」
# 記事案を推測で並べないために、いま実際に打たれている語を取る。
# あわせて Google トレンドの日本の急上昇ワード（RSS）を読む。
#
# suggestqueries.google.com（hl=ja・gl=jp）。1 語あたり 1 回・合計 27 回。90 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t209-search-suggest.md"
mkdir -p "$RDIR"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 && PY="$c" && break
done
{
  echo "# 検索候補（t209・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"
[ -n "$PY" ] || { echo "⚠️ python が無い" >> "$OUT"; cat "$OUT"; exit 0; }

PROBE="${TMPDIR:-/tmp}/t209-probe.py"
cat > "$PROBE" <<'PY'
import json, time, urllib.parse, urllib.request
SEEDS = {
  "季節（11〜12月）": ["11月 東京 イベント", "12月 東京 イベント", "イルミネーション 2026", "クリスマスマーケット 2026", "年末年始 2026", "冬休み 2026", "紅葉 2026"],
  "お金・制度": ["年末調整 2026", "冬のボーナス 2026", "電気代 冬 2026", "値上げ 11月", "値上げ 12月", "ふるさと納税 おすすめ 2026", "新nisa 2027", "ブラックフライデー 2026"],
  "ポイ活・決済": ["paypay 11月", "paypay 12月", "楽天 11月 キャンペーン", "ポイ活 2026 おすすめ", "クレカ 改悪 2027"],
  "新しい場所": ["2026年 オープン 東京", "11月 オープン 東京", "12月 オープン 東京", "豊洲 オープン", "有明 オープン", "晴海 オープン", "高輪ゲートウェイ"],
}
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
asked = got = 0
for slug, seeds in SEEDS.items():
    print(f"## `{slug}`\n")
    for q in seeds:
        asked += 1
        url = "https://suggestqueries.google.com/complete/search?" + urllib.parse.urlencode(
            {"client": "firefox", "hl": "ja", "gl": "jp", "q": q})
        try:
            raw = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=10).read()
            sug = json.loads(raw.decode("utf-8", "replace"))[1]
            got += 1
            print(f"- **{q}** → " + (" ／ ".join(sug) if sug else "（候補なし）"))
        except Exception as e:
            print(f"- **{q}** → ⚠️ 取れない: {type(e).__name__} {str(e)[:120]}")
        time.sleep(0.6)
    print("")
print("## Google トレンド 急上昇（日本・RSS）\n")
try:
    import re as _re, html as _h
    raw = urllib.request.urlopen(urllib.request.Request("https://trends.google.co.jp/trending/rss?geo=JP", headers={"User-Agent": UA}), timeout=15).read().decode("utf-8", "replace")
    items = _re.findall(r"<item>(.*?)</item>", raw, _re.S)
    for it in items[:40]:
        t = _re.search(r"<title>(.*?)</title>", it, _re.S); tr = _re.search(r"<ht:approx_traffic>(.*?)</ht:approx_traffic>", it)
        nt = _re.search(r"<ht:news_item_title>(.*?)</ht:news_item_title>", it, _re.S)
        print(f"- **{_h.unescape(t.group(1).strip()) if t else '?'}**（{tr.group(1) if tr else '?'}）" + (f" — {_h.unescape(nt.group(1).strip())[:80]}" if nt else ""))
    print(f"\n（{len(items)} 件中 上位 40）\n")
except Exception as e:
    print(f"⚠️ 取れない: {type(e).__name__} {str(e)[:120]}\n")
print(f"---\n\n**対象 {asked} 語 / 取れた {got} 語**")
PY

run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
RES="${TMPDIR:-/tmp}/t209-res.md"
run_limited 90 "$PY" "$PROBE" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$PROBE" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
