#!/bin/bash
# **フォロー返しの上限の決め方を読み、x296 で走らせた回の結果を読む。x296 のレポートに出たハンドルを伏せ直す。費用 $0。**
# x296: 認証済みフォロワー 210 人中 43 人をフォロー返ししていない。badge-followback は 1 日 1 回（00:50）で、
# 1 回 8〜13 件しか返さないのに、新しい候補は 1 日 21〜30 件 → 積み残しが増えている。上限の変数名を先に読む（推測で書かない）。
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/followback-cap-read.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/"handles":\[[^\]]*\]/"handles":["<伏せ>"]/g'; }
# x296 のレポートは handles 配列が伏せられていなかった。伏せ直す（公開リポジトリに載るため）
R6="${OPS_REPORT_DIR:-/tmp}/verified-followback-check.md"
[ -f "$R6" ] && { hide < "$R6" > "$R6.tmp.md" && mv "$R6.tmp.md" "$R6"; }
{
echo "# フォロー返しの上限と、前倒しの 1 回の結果（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## run-badge-followback.sh"
echo '```bash'
grep -v -i "token\|secret\|pass" "$S/run-badge-followback.sh" 2>/dev/null | head -60
echo '```'
echo
echo "## 本体（上限・間隔・認証の判定の行）"
B="$(grep -oE "[A-Za-z0-9_./-]*badge[-_]followback[A-Za-z0-9_.-]*\.js" "$S/run-badge-followback.sh" 2>/dev/null | head -1)"
[ -n "$B" ] && case "$B" in /*) ;; *) B="$S/$(basename "$B")";; esac
echo "本体: ${B:-見つからない}"
echo '```javascript'
[ -n "$B" ] && grep -n -E "process\.env\.|MAX|LIMIT|CAP|sleep|wait|verified|slice\(" "$B" | head -50
echo '```'
echo
echo "## 前倒しの回（10/15 夜〜）"
echo '```'
grep -E "2026-10-15T1[5-9]|scanned=|\"ok\"" "$W/logs/badge-followback.log" | tail -25 | hide
echo '```'
echo
echo "**読むだけ。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "フォロー返しの上限の決め方を読んだ / $(basename "$OUT")"
