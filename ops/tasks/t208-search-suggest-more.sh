#!/bin/bash
# **検索候補（Google のオートコンプリート）を取る（t208）。読むだけ・LLM 不使用・$0。**
#
# 利用者の指示（2026-10-04）:「残りの 4〜10 位の記事も同じように直す」
# 表示 7 回以上で、時期が過ぎていない 15 記事ぶん。GSC は表示の少ない語を伏せる（t205 で 15%）。
# **題名を推測の語で直さないために、実際に打たれている語を検索候補から取る。**
#
# suggestqueries.google.com（hl=ja・gl=jp）。1 語あたり 1 回・合計 51 回。150 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t208-search-suggest.md"
mkdir -p "$RDIR"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 && PY="$c" && break
done
{
  echo "# 検索候補（t208・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"
[ -n "$PY" ] || { echo "⚠️ python が無い" >> "$OUT"; cat "$OUT"; exit 0; }

PROBE="${TMPDIR:-/tmp}/t208-probe.py"
cat > "$PROBE" <<'PY'
import json, time, urllib.parse, urllib.request
SEEDS = {
  "wangan-supermarkets-2026": ["晴海 スーパー", "勝どき スーパー", "月島 スーパー", "豊洲 スーパー", "湾岸 スーパー"],
  "wangan-tower-construction-map-2026": ["湾岸 タワマン 建設予定", "晴海 タワマン 建設", "豊洲 タワマン 建設中", "月島 タワマン 建設"],
  "mobility-cost-per-km-2026": ["luup 料金", "シェアサイクル 料金 比較", "luup タクシー 比較", "luup 高い"],
  "point-exchange-route-2026": ["ポイント交換 レート", "マイル 交換 レート", "ポイント マイル 交換 おすすめ"],
  "sauna-openings-2026": ["サウナ 新店 2026", "サウナ オープン 2026 東京", "サウナ 新規オープン"],
  "tokyo-discount-supermarket-2026": ["格安スーパー 東京", "都内 安いスーパー", "安いスーパー ランキング"],
  "cheap-sim-comparison-2026": ["格安sim 比較", "格安sim おすすめ", "楽天モバイル ahamo 比較"],
  "electricity-gas-savings-2026": ["電気 ガス 節約", "新電力 おすすめ", "電気代 安い会社"],
  "harumi-flag-koukai-2026": ["晴海フラッグ 後悔", "晴海フラッグ 住み心地", "晴海フラッグ デメリット"],
  "ikea-toyosu-2026": ["ikea 豊洲", "イケア 豊洲", "ikea 豊洲 何がある"],
  "morning-500-2026": ["モーニング チェーン", "モーニング 安い チェーン", "モーニング 何時まで"],
  "qr-payment-comparison-2026": ["paypay 楽天ペイ d払い 比較", "qr決済 比較", "qr決済 おすすめ"],
  "cheap-sim-speed-cost-2026": ["格安sim 速度 比較", "格安sim 速い", "格安sim 遅い"],
  "point-kaiaku-timeline-2026": ["ポイント 改悪 2026", "paypay 改悪", "dポイント 改悪", "vポイント 改悪"],
  "walk-poikatsu-2026": ["歩いて ポイ活", "歩数 ポイント アプリ", "ポイ活 歩く アプリ おすすめ"],
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
RES="${TMPDIR:-/tmp}/t208-res.md"
run_limited 150 "$PY" "$PROBE" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$PROBE" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
