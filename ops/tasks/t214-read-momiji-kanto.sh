#!/bin/bash
# **紅葉 2026 の記事の一次情報を読む（t214）。読むだけ・LLM 不使用・$0。**
#
# 利用者が選んだ記事案 #1「紅葉2026 関東・東京の見頃予想」。見頃の日付・名所を推測で書かないために、
# t210 の続き。関東・甲信と東京都の名所ごとの見頃予想（tenki.jp）と、ジョルダンの関東・東京ページを読む。150 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t214-read-momiji-kanto.md"
mkdir -p "$RDIR"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 && PY="$c" && break
done
{
  echo "# 一次情報のいま（t214・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"
[ -n "$PY" ] || { echo "⚠️ python が無い" >> "$OUT"; cat "$OUT"; exit 0; }

PROBE="${TMPDIR:-/tmp}/t207-probe.py"
cat > "$PROBE" <<'PY'
import html, re, urllib.request
URLS = [
  "https://tenki.jp/kouyou/3/",
  "https://tenki.jp/kouyou/3/16/",
  "https://sp.jorudan.co.jp/leaf/tokyo.html",
  "https://sp.jorudan.co.jp/leaf/area_kto.html",
]
KEY = re.compile(r"見頃|紅葉|関東|東京|予想|11月|12月|ライトアップ", re.I)
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
        print("```text\n" + body[:12000] + "\n```\n")
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
run_limited 150 "$PY" "$PROBE" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$PROBE" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
