#!/bin/bash
# x394（2026-10-31・読むだけ・$0）: 利用者が「比率の調整が止まる原因」「競合のフォロワー取得」「ハッシュタグの条件」を直すと選んだ。
# 直す前に、3 本のコードの該当部分と今日のログを読む。**何も書き換えない・押さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/x394-read-follow-jobs.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x|twitter)\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1.com/<伏せ>#g'; }
TODAY="$(TZ=Asia/Tokyo date +%Y-%m-%d)"
{
echo "# フォロー 3 本の中身（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
for J in follow-balance competitor-follower-follow hashtag-follow; do
  F="$S/$J.js"
  echo; echo "## $J"; echo '```'
  if [ ! -f "$F" ]; then echo "無い: $F"; ls "$S" | grep -i "$J" ; echo '```'; continue; fi
  echo "行数 $(wc -l < "$F" | tr -d ' ')  更新 $(date -r "$F" '+%m-%d %H:%M')"
  echo "--- plist の環境変数"
  P="$HOME/Library/LaunchAgents/ai.openclaw.$J.plist"
  [ -f "$P" ] && plutil -extract EnvironmentVariables json -o - "$P" 2>/dev/null | head -c 800 | hide; echo
  echo "--- 自分のハンドル・フォロワー一覧・検索・条件まわりの行（前後 3 行）"
  grep -nE 'x238|自分のハンドル|myHandle|selfHandle|AppTabBar_Profile|/followers|verified_followers|UserCell|scrape|search\?q|f=user|hashtag|HASHTAG|min.?follow|max.?follow|out of range|inactive|last post|cap|CAP|TARGET|targets' "$F" | head -60 | cut -c1-200 | hide
  echo '```'
  echo "### 今日のログ（最初の 40 行）"; echo '```'
  grep -h "$TODAY" "$L/$J.log" 2>/dev/null | head -40 | cut -c1-220 | hide
  echo '```'
done
echo; echo "## 自分のハンドルを読む部分（follow-balance の x238 前後 25 行）"; echo '```'
n="$(grep -n 'x238' "$S/follow-balance.js" 2>/dev/null | head -1 | cut -d: -f1)"
[ -n "$n" ] && sed -n "$((n>25?n-25:1)),$((n+10))p" "$S/follow-balance.js" | cut -c1-200 | hide
echo '```'
echo; echo "## 競合のフォロワーを読む部分（scraped の前 40 行）"; echo '```'
n="$(grep -n 'scraped' "$S/competitor-follower-follow.js" 2>/dev/null | head -1 | cut -d: -f1)"
[ -n "$n" ] && sed -n "$((n>40?n-40:1)),$((n+3))p" "$S/competitor-follower-follow.js" | cut -c1-200 | hide
echo '```'
echo; echo "## ハッシュタグの候補の集め方（out of range の前 40 行）"; echo '```'
n="$(grep -n 'out of range' "$S/hashtag-follow.js" 2>/dev/null | head -1 | cut -d: -f1)"
[ -n "$n" ] && sed -n "$((n>40?n-40:1)),$((n+5))p" "$S/hashtag-follow.js" | cut -c1-200 | hide
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
