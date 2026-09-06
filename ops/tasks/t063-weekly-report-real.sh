#!/bin/bash
# **siteTag を直したので、本番の数字を取る。**
#
# ## t062 で原因が確定した
#
#   本当の site_tag : 73990e5796764bce8626e8706c08ce82（host=fieldbeside.com）
#   渡していた値     : 0dc312c59cff43f58507d2b4f669dd82（ビーコンの token）
#
# **ビーコンの token は siteTag ではなかった。** だからエラー無しで 0 件が返り続けた。
# 絞りを外して引いたら **7 日で pv=10 / visits=10** が出た。
# GSC の 28 日 37 クリック（週 9.3）と規模が一致する。
#
# ## 直したこと
#
# **固定値を書くのをやめ、実行時に `rum/site_info/list` へ聞く。**
# 取れなければ siteTag で絞らない。同じ罠を踏まないため。
#
# GSC は t061 でネットワークが落ちて取れなかった。t062 の時点で
# oauth2.googleapis.com は応答している（http=404 ＝ 到達している）。
#
# Slack には出さない。launchd も触らない。
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t063-weekly-report.md"
mkdir -p "$RDIR"

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

# 直近 7 日（週次）と 30 日（MAU）の 2 本 出す
"$PY" "$SCRIPT" --days 7  --out "${TMPDIR:-/tmp}/w7.md";  RC7=$?
"$PY" "$SCRIPT" --days 30 --out "${TMPDIR:-/tmp}/w30.md"; RC30=$?

{
  echo "# 本番の数字（t063 / siteTag 修正後）"
  echo
  echo "## 直近 30 日（MAU）"
  echo
  sed -n '/^## サマリー/,/^## 検索順位/p' "${TMPDIR:-/tmp}/w30.md" 2>/dev/null
  echo
  echo "## 直近 7 日（週次）— 全文"
  echo
  cat "${TMPDIR:-/tmp}/w7.md" 2>/dev/null
  echo
  echo "---"
  echo "t063: 7日=rc\`$RC7\` / 30日=rc\`$RC30\`"
} > "$OUT"

echo "=== 結果 ==="
cat "$OUT"
exit 0
