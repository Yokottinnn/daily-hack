#!/bin/bash
# **Cloudflare には繋がった。だが数字が 0 で返ってきた。siteTag を確かめる。**
#
# ## t061 で分かったこと
#
#   - **トークンは有効**: "This API Token is valid and active" / status: active
#   - **Cloudflare には到達している**: curl -4 も既定も http=400（認証なしなので正しい）
#   - **IPv4 フォールバックは効いた**: CF から数字が返った
#   - **ただし ページビュー 0 / 訪問 0**（クエリはエラー無しで空を返した）
#   - **今度は GSC が落ちた**: oauth2.googleapis.com に Errno 65
#     → **ホスト依存ではなく、Mac のネットワークが時々 落ちている**
#
# GSC は 28 日でクリック 37。週なら 10〜30 訪問はあるはずで、**0 はおかしい。**
# エラー無しで空が返るのは、**siteTag が違って 1 件も一致していない**ときの形。
#
# `CF_SITE_TAG` はビーコンの token（BaseLayout.astro:106）から取ったが、
# **それが Web Analytics の site_tag と同じである保証を確かめていない。**
#
# ## やること
#
#   1. アカウントの一覧（**id はマスク**。名前と件数を見る）
#   2. **Web Analytics のサイト一覧** → 本当の site_tag と host
#   3. siteTag で絞らずに RUM を引いて、**素の合計**が出るかを見る
#   4. GSC をもう一度（ネットワークが戻っていれば通る）
#
# **秘密は出さない。** トークンの値は表示しない。
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t062-rum-sitetag.md"
mkdir -p "$RDIR"
TOK_FILE="$HOME/.config/daily-hack/cf-token"
[ -f "$TOK_FILE" ] || { echo "cf-token が無い" | tee "$OUT"; exit 1; }
TOK="$(cat "$TOK_FILE")"

# **IPv4 で叩く。** t061 で IPv6 の経路が無いと分かっている
CF() { curl -4 -s --max-time 30 -H "Authorization: Bearer $TOK" "$@"; }

echo "# Web Analytics の siteTag を確かめる（t062）" > "$OUT"

{
  echo
  echo "## 1) アカウント一覧（id はマスク）"
  echo '```'
  CF "https://api.cloudflare.com/client/v4/accounts?per_page=10" \
    | python3 -c "
import json,sys
d=json.load(sys.stdin)
for a in (d.get('result') or []):
    i=a.get('id','')
    print(f\"name={a.get('name')} id={i[:6]}…{i[-4:]}\")
print('success:', d.get('success'), 'errors:', d.get('errors'))
" 2>&1
  echo '```'
} >> "$OUT"

ACC="$(CF "https://api.cloudflare.com/client/v4/accounts?per_page=10" \
       | python3 -c "import json,sys;r=json.load(sys.stdin).get('result') or [];print(r[0]['id'] if r else '')" 2>/dev/null)"

{
  echo
  echo "## 2) Web Analytics のサイト一覧（本当の site_tag）"
  echo '```'
  if [ -n "$ACC" ]; then
    CF "https://api.cloudflare.com/client/v4/accounts/$ACC/rum/site_info/list?per_page=20" \
      | python3 -c "
import json,sys
d=json.load(sys.stdin)
res=d.get('result')
if not d.get('success'):
    print('失敗:', json.dumps(d.get('errors'), ensure_ascii=False)[:300]); raise SystemExit
for s in (res or []):
    print(f\"site_tag={s.get('site_tag')}  host={(s.get('ruleset') or {}).get('zone_name') or s.get('site_token','')[:8]}  auto={s.get('auto_install')}\")
print('件数:', len(res or []))
" 2>&1
  else
    echo "(アカウントが取れなかった)"
  fi
  echo '```'
} >> "$OUT"

{
  echo
  echo "## 3) siteTag で絞らずに RUM を引く（素の合計）"
  echo '```'
  if [ -n "$ACC" ]; then
    END="$(date -u -v-1d +%F 2>/dev/null || date -u -d '-1 day' +%F)"
    START="$(date -u -v-7d +%F 2>/dev/null || date -u -d '-7 days' +%F)"
    echo "期間: ${START} 〜 ${END}"
    python3 - "$ACC" "$START" "$END" "$TOK" <<'PYEOF' 2>&1
import json, sys, urllib.request, socket
acc, start, end, tok = sys.argv[1:5]
_o = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: [r for r in _o(*a, **k) if r[0] == socket.AF_INET] or _o(*a, **k)
q = """
query($a: String!, $s: Time!, $e: Time!) {
  viewer { accounts(filter: {accountTag: $a}) {
    byTag: rumPageloadEventsAdaptiveGroups(
      limit: 20, orderBy: [count_DESC],
      filter: { datetime_geq: $s, datetime_leq: $e }
    ) { count sum { visits } dimensions { siteTag } }
  } }
}"""
body = json.dumps({"query": q, "variables": {"a": acc, "s": start+"T00:00:00Z", "e": end+"T23:59:59Z"}}).encode()
req = urllib.request.Request("https://api.cloudflare.com/client/v4/graphql", data=body, method="POST",
                             headers={"Content-Type": "application/json", "Authorization": "Bearer " + tok})
try:
    d = json.loads(urllib.request.urlopen(req, timeout=60).read())
except Exception as e:
    print("失敗:", type(e).__name__, e); raise SystemExit
if d.get("errors"):
    print("GraphQL エラー:", json.dumps(d["errors"], ensure_ascii=False)[:400]); raise SystemExit
accs = (d.get("data") or {}).get("viewer", {}).get("accounts") or []
rows = (accs[0].get("byTag") if accs else []) or []
if not rows:
    print("**siteTag で絞らなくても 0 件。** このアカウントに RUM のデータが無い")
for r in rows:
    t = (r.get("dimensions") or {}).get("siteTag")
    print(f"siteTag={t}  pv={r.get('count')}  visits={(r.get('sum') or {}).get('visits')}")
PYEOF
  fi
  echo '```'
} >> "$OUT"

{
  echo
  echo "## 4) GSC をもう一度（t061 ではネットワークで落ちた）"
  echo '```'
  curl -4 -s -o /dev/null -w 'oauth2.googleapis.com http=%{http_code} time=%{time_total}s\n' \
    --max-time 20 https://oauth2.googleapis.com/ 2>&1
  echo '```'
} >> "$OUT"

echo "=== 結果 ==="
cat "$OUT"
exit 0
