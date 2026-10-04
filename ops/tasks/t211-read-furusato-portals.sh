#!/bin/bash
# **ふるさと納税サイト比較の一次情報を読む（t211）。読むだけ・LLM 不使用・$0。**
#
# 利用者が選んだ記事案 #2「ふるさと納税サイト比較2026」。掲載自治体数・決済・特典を推測で書かないために、
# 各ポータルの公式トップと、ポータル契約数の調査記事を読む。150 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t211-read-furusato-portals.md"
mkdir -p "$RDIR"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 && PY="$c" && break
done
{
  echo "# 一次情報のいま（t211・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"
[ -n "$PY" ] || { echo "⚠️ python が無い" >> "$OUT"; cat "$OUT"; exit 0; }

PROBE="${TMPDIR:-/tmp}/t207-probe.py"
cat > "$PROBE" <<'PY'
import html, re, urllib.request
URLS = [
  "https://www.furusato-tax.jp/",
  "https://www.satofull.jp/",
  "https://furunavi.jp/",
  "https://event.rakuten.co.jp/furusato/",
  "https://furusato.ana.co.jp/",
  "https://furusato.wowma.jp/",
  "https://shopping.yahoo.co.jp/furusato/",
  "https://www.commercepick.com/archives/21652",
]
KEY = re.compile(r"自治体|返礼品|件|決済|ポイント|マイル|特典|キャンペーン|掲載", re.I)
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
        print("```text\n" + body[:7000] + "\n```\n")
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
