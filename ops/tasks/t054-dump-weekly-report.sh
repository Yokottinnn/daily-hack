#!/bin/bash
# **週次ブログレポートの実体を取ってくる。読むだけ。何も変えない。**
#
# ## t052 の焼き直し。t052 は自分のバグで何も残せなかった
#
# t052 はリポジトリの場所を `$(dirname "$0")/../..` で求めていた。
# **ランナーはタスクを `/tmp/ops-tasks/` にコピーして実行する**ため、
# `$0` はリポジトリの中を指さない。`cd /` してから `git add` して
# `fatal: not a git repository` で終わっていた。
#
# **正しい書き方は `$REPO` と `$OPS_REPORT_DIR` を使うこと。**
# push も要らない。`$OPS_REPORT_DIR` に書けばランナーが ops/heartbeat へ運ぶ。
#
# ## なぜこれが要るか
#
# 2026-08-31 に Slack へ出たレポートに `${ALL_VISITS}` が展開されないまま
# 載っていた。**Cloudflare の PV が数字になっていなかった。**
# 後継の `scripts/weekly-blog-report.py` は書いたが、
# **既存の実装を読まずに launchd を切り替えない**（当て推量で触らない）。
#
# ## やること（すべて読み取り）
#
# 1. `com.dailyhack.weekly-blog-report` の plist
# 2. それが呼んでいるスクリプトの中身
# 3. 直近のログ
#
# **秘密は出さない。** 出力は公開リポジトリに載る。
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t054-weekly-report-dump.md"
mkdir -p "$RDIR"
: > "$OUT"

mask() {
  sed -E \
    -e 's/xox[baprs]-[A-Za-z0-9-]+/***MASKED***/g' \
    -e 's/(BOT_TOKEN|API_KEY|APIKEY|SECRET|PASSWORD|PRIVATE_KEY|TOKEN)([=: ]+)[^ "'"'"',]+/\1\2***MASKED***/gI' \
    -e 's/-----BEGIN[^-]*PRIVATE KEY-----/***MASKED***/g'
}

{
  echo "# 週次ブログレポートの実体（t054 / 読み取りのみ）"
  echo
  echo "## launchd の登録状況"
  echo '```'
  launchctl list 2>/dev/null | grep -iE "weekly|report" || echo "(該当なし)"
  echo '```'
} >> "$OUT"

PLIST=""
for p in "$HOME"/Library/LaunchAgents/com.dailyhack.weekly-blog-report.plist \
         "$HOME"/Library/LaunchAgents/*weekly*.plist; do
  [ -f "$p" ] && PLIST="$p" && break
done

if [ -z "$PLIST" ]; then
  {
    echo
    echo "**plist が見つからない。** LaunchAgents の一覧:"
    echo '```'
    ls -1 "$HOME"/Library/LaunchAgents/ 2>/dev/null | head -80
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
  SCRIPTS=$(grep -rl 'ALL_VISITS' "$HOME/openclaw" "$HOME/projects" "$HOME/.openclaw" 2>/dev/null | head -5)
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
        mask < "$s" | head -400
        echo '```'
      else
        echo "(ファイルが無い)"
      fi
    } >> "$OUT"
  done
fi

{
  echo
  echo "## 直近のログ（末尾 40 行ずつ）"
} >> "$OUT"
found_log=0
for lg in "$HOME"/Library/Logs/*weekly*.log /tmp/*weekly*.log "$HOME"/openclaw/logs/*weekly*.log; do
  [ -f "$lg" ] || continue
  found_log=1
  {
    echo
    echo "### \`$lg\`"
    echo '```'
    tail -40 "$lg" | mask
    echo '```'
  } >> "$OUT"
done
[ "$found_log" = "0" ] && echo "(ログが見つからない)" >> "$OUT"

echo "書いた: $OUT"
wc -l "$OUT"
