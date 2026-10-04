#!/bin/bash
# **記事の一次情報の「いま」を読む（t207）。読むだけ・LLM 不使用・$0。**
#
# 9 月に検索で伸びた記事のうち 2 本は、中身の時期が過ぎている（2026-10-04 時点）。
#   ふるさと納税: 題名が「9月30日までにやる5ステップ」のまま
#   ドローンショー: 3 公演とも 9/22 で終了
# 花火（10/24 開催）もチケットの残りが変わっている可能性がある。
# **直す前に、公式がいま何と書いているかを読む。** 推測で書き換えない（最上位ルール 20）。
#
# 各ページの本文テキスト（先頭 5,000 字）と、日付・チケット・改正に関わるリンクを出す。120 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t207-official-now.md"
mkdir -p "$RDIR"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 && PY="$c" && break
done
{
  echo "# 一次情報のいま（t207・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"
[ -n "$PY" ] || { echo "⚠️ python が無い" >> "$OUT"; cat "$OUT"; exit 0; }

PROBE="${TMPDIR:-/tmp}/t207-probe.py"
cat > "$PROBE" <<'PY'
import html, re, urllib.request
URLS = [
  "https://www.soumu.go.jp/menu_news/s-news/01zeimu04_02000144.html",
  "https://www.soumu.go.jp/main_sosiki/jichi_zeisei/czaisei/czaisei_seido/furusato/topics/",
  "https://tokyo-hanabi-festival.com/ticket/",
  "https://tokyo-hanabi-festival.com/",
  "https://www.city.chuo.lg.jp/a0013/r8tokyohanabifestival.html",
  "https://odaibadrone.com/",
  "https://www.tokyo-odaiba.net/",
]
KEY = re.compile(r"ドローン|drone|チケット|ticket|販売|完売|残|改正|告示|基準|地場産品|10月|11月|12月|2027", re.I)
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
ok = 0
for u in URLS:
    print(f"## {u}\n")
    try:
        r = urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": UA, "Accept-Language": "ja"}), timeout=15)
        raw = r.read()
        enc = r.headers.get_content_charset() or ("shift_jis" if b"Shift_JIS" in raw[:2000] else "utf-8")
        h = raw.decode(enc, "replace")
        ok += 1
        t = re.search(r"<title[^>]*>(.*?)</title>", h, re.S | re.I)
        print(f"- status **{r.status}** / {len(raw)} bytes / title: {html.unescape(t.group(1).strip()) if t else '—'}\n")
        links = []
        for href, txt in re.findall(r'<a [^>]*href="([^"]+)"[^>]*>(.*?)</a>', h, re.S | re.I):
            txt = re.sub(r"<[^>]+>", "", html.unescape(txt)).strip()
            if txt and (KEY.search(txt) or KEY.search(href)):
                links.append(f"{txt[:80]} → {href}")
        if links:
            print("**関係しそうなリンク**\n")
            for l in list(dict.fromkeys(links))[:30]:
                print(f"- {l}")
            print("")
        body = re.sub(r"(?is)<(script|style|noscript|svg)[^>]*>.*?</\1>", " ", h)
        body = re.sub(r"(?s)<[^>]+>", " ", body)
        body = re.sub(r"\s+", " ", html.unescape(body)).strip()
        print("```text\n" + body[:5000] + "\n```\n")
    except Exception as e:
        print(f"⚠️ 取れない: {type(e).__name__} {str(e)[:160]}\n")
print(f"---\n\n**対象 {len(URLS)} / 取れた {ok}**")
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
RES="${TMPDIR:-/tmp}/t207-res.md"
run_limited 120 "$PY" "$PROBE" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$PROBE" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
