#!/bin/bash
# **IPv4 フォールバックを入れたので、週次レポートをもう一度 走らせる。**
#
# t060 の結果:
#   - トークンは読めた（53 バイト・-rw-------）
#   - **Cloudflare だけ `<urlopen error [Errno 65] No route to host>`**
#   - GSC は同じスクリプトで通っている
#
# Errno 65 は macOS の EHOSTUNREACH。**AAAA を先に引いて IPv6 の経路が無い**
# ときに出る。scripts/weekly-blog-report.py に「経路が無ければ IPv4 だけで
# 一度やり直す」処理を入れた。
#
# **切り分けも一緒に出す。** IPv4 でも駄目なら、原因がネットワークなのか
# トークンなのかを次の一手で迷わないように。
#
# Slack には出さない。launchd も触らない。**トークンの値は表示しない。**
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t061-weekly-report.md"
mkdir -p "$RDIR"

echo "# 週次レポート（t061 / IPv4 フォールバックあり）" > "$OUT"

# --- 切り分け（秘密は出さない） ---------------------------------
{
  echo
  echo "## 到達性の切り分け"
  echo '```'
  echo "-- DNS: api.cloudflare.com --"
  dscacheutil -q host -a name api.cloudflare.com 2>/dev/null | head -12 \
    || host api.cloudflare.com 2>&1 | head -6
  echo
  echo "-- IPv4 だけで叩く（認証なし。401 が返れば到達している）--"
  curl -4 -s -o /dev/null -w 'http=%{http_code} time=%{time_total}s\n' \
    --max-time 20 https://api.cloudflare.com/client/v4/user/tokens/verify 2>&1
  echo
  echo "-- 既定（IPv6 優先）で叩く --"
  curl -s -o /dev/null -w 'http=%{http_code} time=%{time_total}s\n' \
    --max-time 20 https://api.cloudflare.com/client/v4/user/tokens/verify 2>&1
  echo '```'
} >> "$OUT"

# --- トークンが有効かを Cloudflare 自身に聞く -------------------
TOK="$HOME/.config/daily-hack/cf-token"
{
  echo
  echo "## トークンの検証（Cloudflare の verify エンドポイント）"
  echo '```'
  if [ -f "$TOK" ]; then
    # **値は出さない。** 返ってくる JSON の status だけ見る
    curl -4 -s --max-time 20 https://api.cloudflare.com/client/v4/user/tokens/verify \
      -H "Authorization: Bearer $(cat "$TOK")" \
      | sed -E 's/"id":"[^"]*"/"id":"***"/g' | head -5
  else
    echo "(トークンのファイルが無い)"
  fi
  echo '```'
} >> "$OUT"

# --- レポート本体 -----------------------------------------------
[ -d "$REPO/.git" ] || { echo "リポジトリが無い"; exit 1; }
git -C "$REPO" fetch -q origin main || true
SCRIPT="${TMPDIR:-/tmp}/weekly-blog-report.py"
git -C "$REPO" show origin/main:scripts/weekly-blog-report.py > "$SCRIPT" || exit 1

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

BODY="${TMPDIR:-/tmp}/t061-body.md"
"$PY" "$SCRIPT" --out "$BODY"
RC=$?

{
  echo
  cat "$BODY" 2>/dev/null
  echo
  echo "---"
  echo "t061: 終了コード=\`$RC\`"
} >> "$OUT"

echo "=== 結果 ==="
cat "$OUT"
exit 0
