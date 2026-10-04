#!/bin/bash
# **検索候補（Google のオートコンプリート）を取る（t206）。読むだけ・LLM 不使用・$0。**
#
# 利用者の指示（2026-10-04）:「表示が伸びたのにクリック 0 の 4 記事を直す」「ららぽーと記事の順位を上げる」
# GSC は表示の少ない語を伏せるので、この 5 記事の検索語は 15% しか分からない（t205）。
# **題名を推測の語で直さないために、実際に打たれている語を検索候補から取る。**
#
# suggestqueries.google.com（hl=ja・gl=jp）。1 語あたり 1 回・合計 40 回ほど。90 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t206-search-suggest.md"
mkdir -p "$RDIR"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 && PY="$c" && break
done
{
  echo "# 検索候補（t206・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"
[ -n "$PY" ] || { echo "⚠️ python が無い" >> "$OUT"; cat "$OUT"; exit 0; }

PROBE="${TMPDIR:-/tmp}/t206-probe.py"
cat > "$PROBE" <<'PY'
import json, time, urllib.parse, urllib.request
SEEDS = {
  "furusato-tax-2026-reform-guide": ["ふるさと納税 2026", "ふるさと納税 改正", "ふるさと納税 10月", "ふるさと納税 10月以降", "ふるさと納税 改悪", "ふるさと納税 返礼品 なくなる", "ふるさと納税 いつまで"],
  "tokyo-bay-hanabi-2026": ["東京湾大華火祭", "東京湾大華火祭 2026", "東京湾 花火 2026", "東京湾 花火 10月", "東京湾大華火祭 チケット", "晴海 花火"],
  "odaiba-drone-show-2026": ["お台場 ドローンショー", "お台場 ドローンショー 2026", "ドローンショー 東京", "ドローンショー 10月", "ドローンショー 2026", "odaiba drone show"],
  "narita-haneda-overseas-direct-2026": ["羽田 直行便", "成田 直行便", "羽田 直行便 一覧", "成田 直行便 一覧", "羽田 国際線 就航都市", "成田 羽田 どっち 海外"],
  "lalaport-guide-2026": ["ららぽーと ランキング", "ららぽーと 売上", "ららぽーと 店舗数", "ららぽーと 大きさ", "ららぽーと 面積", "ららぽーと 一覧", "ららぽーと 何店舗", "ららぽーと 一番大きい", "ららぽーと 日本一"],
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
RES="${TMPDIR:-/tmp}/t206-res.md"
run_limited 90 "$PY" "$PROBE" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$PROBE" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
