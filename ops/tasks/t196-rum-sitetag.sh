#!/bin/bash
# **週次レポートの PV が 100 しか出ない理由を測る（t196）。読むだけ・LLM 不使用・$0。**
#
# ## 何が食い違っているか（2026-09-27 に発覚）
#
# 同じ 9 月の同じサイトについて、2 つの経路が **100 倍 違う数字**を出している。
#
#   Zone Analytics（GitHub Actions / weekly-pv-report）  visits **13,778**
#   Web Analytics（Mac / weekly-blog-report.py）         PV     **100**
#
# しかも Web Analytics 側は **記事ページ（/posts/…）の PV が 0**、
# 流入が **直接 100%**、デバイスが **desktop 100%**、国が **JP 60 / CN 40**。
# 実在のブログの数字には見えない。**どちらが正しいかを決めずに、原因を測る。**
#
# ## 疑っているところ
#
# `weekly-blog-report.py` の `cf_site_tag()` は **site_tag を推測している。**
# `ruleset.zone_name` が HOST に一致しなければ **`sites[0]`（先頭）**を採る。
# アカウントに別サイトがあると、**黙って別サイトの数字を出す。**
#
# 正解はリポジトリに在る。`src/layouts/BaseLayout.astro` のビーコン:
#
#   data-cf-beacon='{"token": "0dc312c59cff43f58507d2b4f669dd82"}'
#
# **この token が Web Analytics の site_tag そのもの。** 推測は要らない。
#
# ## 出すもの
#
#   ① アカウントの RUM サイト一覧（zone_name / hostname / tag が一致するか）
#   ② `cf_site_tag()` が選ぶ tag は、ビーコンの tag と一致するか
#   ③ **ビーコンの tag で 9/1〜9/26 を引き直した数字**（これが本当の PV）
#
# ## 秘密は出さない
#
# ビーコンの token は**公開 HTML に載っているので秘密ではない**。
# **それ以外のサイトの tag は先頭 8 文字だけ**にする。トークンは一切 出さない。
#
# **180 秒 で打ち切る**（最上位ルール 15）。API を読むだけ。

set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t196-rum-sitetag.md"
mkdir -p "$RDIR"

{
  echo "# Web Analytics の site_tag を測る（t196・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

[ -d "$REPO/.git" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true

SCRIPT="${TMPDIR:-/tmp}/t196-weekly-blog-report.py"
git -C "$REPO" show origin/main:scripts/weekly-blog-report.py > "$SCRIPT" 2>/dev/null || {
  echo "⚠️ **スクリプトを取り出せない**" >> "$OUT"; cat "$OUT"; exit 0; }
n=$(wc -c < "$SCRIPT" | tr -d ' ')
case "$n" in ''|*[!0-9]*) n=0 ;; esac
[ "$n" -ge 2000 ] || { echo "⚠️ **スクリプトが小さすぎる**（$n bytes）" >> "$OUT"; cat "$OUT"; exit 0; }

# ビーコンの token を**リポジトリから読む**（当て推量しない）
BEACON="$(git -C "$REPO" show origin/main:src/layouts/BaseLayout.astro 2>/dev/null \
  | grep -o 'data-cf-beacon=.*token".*:.*"[0-9a-f]\{32\}"' | grep -o '[0-9a-f]\{32\}' | head -1)"
[ -n "$BEACON" ] || { echo "⚠️ **BaseLayout.astro からビーコンの token を読めなかった**" >> "$OUT"; cat "$OUT"; exit 0; }
echo "- ビーコンの site_tag（公開 HTML に載っている）: \`$BEACON\`" >> "$OUT"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "⚠️ **Python 3.10 以上が無い**" >> "$OUT"; cat "$OUT"; exit 0; }
echo "- python: \`$PY\` / スクリプト **$n bytes**" >> "$OUT"
echo "" >> "$OUT"

PROBE="${TMPDIR:-/tmp}/t196-probe.py"
cat > "$PROBE" <<'PY'
import importlib.util, json, os, sys, urllib.request

beacon = sys.argv[1]
spec = importlib.util.spec_from_file_location("wbr", sys.argv[2])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def mask(t):
    return (t[:8] + "…") if t else "(空)"

out = []
tok = m.cf_token()
if not tok:
    print("⚠️ **Cloudflare のトークンが見つからない。** 経路を確認すること。")
    raise SystemExit(0)
out.append(f"- トークン: **在る**（桁数 {len(tok)}）")
acct = m.cf_account_id(tok)
out.append(f"- account: **{'取れた' if acct else '取れない'}**")
if not acct:
    print("\n".join(out)); raise SystemExit(0)

# --- ① RUM サイト一覧 ---
req = urllib.request.Request(
    f"https://api.cloudflare.com/client/v4/accounts/{acct}/rum/site_info/list?per_page=50",
    headers={"Authorization": f"Bearer {tok}"})
with urllib.request.urlopen(req, timeout=30) as r:
    sites = (json.loads(r.read() or b"{}").get("result") or [])

out += ["", "## ① アカウントの RUM サイト一覧", "",
        f"**{len(sites)} 件。**", "",
        "| # | zone_name | host | tag | ビーコンと一致 |",
        "| --- | --- | --- | --- | --- |"]
for i, s in enumerate(sites, 1):
    rs = s.get("ruleset") or {}
    tag = s.get("site_tag") or ""
    hit = "**← これ**" if tag == beacon else ""
    shown = tag if tag == beacon else mask(tag)
    out.append(f"| {i} | `{rs.get('zone_name') or '(空)'}` | `{rs.get('host') or s.get('site_name') or '(空)'}` | `{shown}` | {hit} |")

# --- ② cf_site_tag() が選ぶもの ---
picked = m.cf_site_tag(tok, acct)
same = (picked == beacon)
out += ["", "## ② `cf_site_tag()` が選ぶ tag", "",
        f"- 選んだ: `{picked if same else mask(picked)}`",
        f"- ビーコンと一致: **{'はい' if same else 'いいえ'}**"]
if not same:
    out.append("")
    out.append("**これが原因。** 別サイトの数字を、このブログの PV として報告していた。")

# --- ③ ビーコンの tag で引き直す ---
start, end = "2026-09-01", "2026-09-26"
out += ["", f"## ③ ビーコンの tag で引き直す（{start} 〜 {end}）", ""]
for label, tag in (("ビーコンの tag", beacon), ("いま選ばれている tag", picked)):
    if tag is None:
        continue
    try:
        d = m.cf_fetch(tok, acct, start, end, site_tag=tag)
    except Exception as e:
        out.append(f"- {label}: ⚠️ {type(e).__name__}: {str(e)[:160]}")
        continue
    tot = (d.get("total") or [{}])[0]
    pv = int(tot.get("count") or 0)
    vis = int((tot.get("sum") or {}).get("visits") or 0)
    paths = d.get("byPath") or []
    posts = [p for p in paths if str((p.get("dimensions") or {}).get("requestPath") or "").startswith("/posts/")]
    out.append(f"- **{label}**: PV **{pv:,}** / 訪問 **{vis:,}** / パス {len(paths)} 件"
               f"（うち `/posts/…` **{len(posts)} 件**）")
    for p in sorted(posts, key=lambda x: -int(x.get("count") or 0))[:5]:
        out.append(f"    - `{(p.get('dimensions') or {}).get('requestPath')}` … {int(p.get('count') or 0):,}")
    if tag == picked and picked != beacon:
        out.append("    ↑ **これが週次レポートに出ていた数字。**")

print("\n".join(out))
PY

run_limited() {  # $1=秒 …残り=コマンド
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 3
  done
  wait "$pid" 2>/dev/null
}

RES="${TMPDIR:-/tmp}/t196-result.md"
run_limited 150 "$PY" "$PROBE" "$BEACON" "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"
echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$PROBE" "$RES"

{
  echo ""
  echo "---"
  echo ""
  echo "> **\`rc=0\` は数字が出た証拠ではない**（最上位ルール 13）。"
  echo "> **上の ② が「いいえ」なら、過去の週次レポートの PV は全部 別サイトの数字。**"
  echo ""
  echo "LLM 不使用。Cloudflare API は無料枠。**\$0/回・\$0/日・\$0/月。**"
} >> "$OUT"

cat "$OUT"
