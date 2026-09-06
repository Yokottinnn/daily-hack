#!/bin/bash
# **週次ブログレポートの実体を取ってくる。読むだけ。何も変えない。**
#
# ## なぜ
#
# 2026-08-31 に Slack `#fun_reward-hack_blog` へ出たレポートに、
# **`${ALL_VISITS}` と `${ALL_REQ}` が展開されないまま載っていた。**
#
#   • CF visits（全パス）: *${ALL_VISITS}* / requests ${ALL_REQ}
#
# つまり Cloudflare の PV は**数字が出ていない**。GSC の表示・クリックだけが
# 生きていて、レポートとして成立していない。
#
# 利用者から「レポートの内容が浅い。PV・ユーザー数・流入経路・SEO順位を
# もっと包括的に」と指示が出た。**直す前に実物を読む。**
# 当て推量でスクリプトを書き換えない（CLAUDE.md）。
#
# ## やること（すべて読み取り。変更・実行はしない）
#
# 1. launchd ジョブの定義と、それが呼んでいるスクリプトのパス
# 2. そのスクリプトの中身
# 3. 直近のログ
#
# **秘密は出さない。** トークン・鍵らしき行はマスクする。出力は公開リポジトリに載る。
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
OUT="/tmp/t052-weekly-report-dump.md"
: > "$OUT"

mask() {
  sed -E \
    -e 's/xox[baprs]-[A-Za-z0-9-]+/***MASKED***/g' \
    -e 's/(BOT_TOKEN|API_KEY|APIKEY|SECRET|PASSWORD|PRIVATE_KEY|TOKEN)([=: ]+)[^ "'"'"',]+/\1\2***MASKED***/gI' \
    -e 's/-----BEGIN[^-]*PRIVATE KEY-----/***MASKED***/g'
}

{
  echo "# 週次ブログレポートの実体（t052 / 読み取りのみ）"
  echo
  echo "## launchd ジョブ"
  echo '```'
  launchctl list 2>/dev/null | grep -iE "weekly|report|blog" || echo "(該当なし)"
  echo '```'
} >> "$OUT"

PLIST=""
for p in "$HOME"/Library/LaunchAgents/*weekly*.plist; do
  [ -f "$p" ] && PLIST="$p" && break
done

if [ -z "$PLIST" ]; then
  {
    echo
    echo "**plist が見つからない。** LaunchAgents の一覧:"
    echo '```'
    ls -1 "$HOME"/Library/LaunchAgents/ 2>/dev/null
    echo '```'
  } >> "$OUT"
else
  {
    echo
    echo "## plist: \`$PLIST\`"
    echo '```xml'
    mask < "$PLIST"
    echo '```'
  } >> "$OUT"
fi

SCRIPTS=""
if [ -n "$PLIST" ]; then
  SCRIPTS=$(grep -oE '<string>[^<]*\.(sh|py|mjs|js)</string>' "$PLIST" 2>/dev/null \
            | sed 's/<[^>]*>//g' | sort -u)
fi
if [ -z "$SCRIPTS" ]; then
  SCRIPTS=$(grep -rl 'ALL_VISITS' "$HOME/openclaw" "$HOME/projects" 2>/dev/null | head -5)
fi

{
  echo
  echo "## 呼ばれているスクリプト"
} >> "$OUT"

if [ -z "$SCRIPTS" ]; then
  {
    echo
    echo "**特定できなかった。** 週次レポートらしき語で探した結果:"
    echo '```'
    grep -rl "週次アクセス分析\|惜しい記事\|ALL_VISITS" \
      "$HOME/openclaw" "$HOME/projects" "$HOME/.openclaw" 2>/dev/null | head -20
    echo '```'
  } >> "$OUT"
else
  for s in $SCRIPTS; do
    {
      echo
      echo "### \`$s\`"
      if [ -f "$s" ]; then
        echo '```'
        mask < "$s"
        echo '```'
      else
        echo "(ファイルが無い)"
      fi
    } >> "$OUT"
  done
fi

{
  echo
  echo "## 直近のログ（末尾 60 行）"
} >> "$OUT"
for lg in "$HOME"/Library/Logs/*weekly*.log /tmp/*weekly*.log "$HOME"/openclaw/logs/*weekly*.log; do
  [ -f "$lg" ] || continue
  {
    echo
    echo "### \`$lg\`"
    echo '```'
    tail -60 "$lg" | mask
    echo '```'
  } >> "$OUT"
done

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
mkdir -p reports
cp "$OUT" reports/t052-weekly-report-dump.md
git add reports/t052-weekly-report-dump.md
git -c user.name="OpenClaw" -c user.email="ops@fieldbeside.com" \
  commit -q -m "ops(t052): 週次ブログレポートの実体を取ってくる" || true
git push -q origin HEAD:refs/heads/claude/t052-weekly-report-dump 2>&1 | tail -3

echo "=== 先頭 120 行 ==="
head -120 "$OUT"
