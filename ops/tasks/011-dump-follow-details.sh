#!/bin/bash
# 007〜009 の中身を**レポートファイルに**書き直す。
#
# 007〜009 は標準出力に書いたため、heartbeat が末尾 300 字に切り詰めて
# 肝心の上限値・発火間隔が失われた。003 と同じく $OPS_REPORT_DIR に書く。
#
# 尻尾から分かった手がかりを 1 つ追う:
#   `x-follower-cron done (follow, exit: 0)` の最終記録が **2026-07-04 23:54 JST**。
#   同じ 7/04 に follower-target-monitor が .bak 化されている。
#   **7/04 に何かをまとめて止めた可能性がある。** そこを特定する。
#
# **ロードはしない。読み取りのみ。**
# **秘密を出力しないこと。** ハンドル名は出さず、20 字以上の英数字は伏せる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-details.md"
mask() { sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g'; }

{
echo "# フォロー施策の詳細（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"

echo
echo "## 0. 2026-07-04 に何が止まったか"
echo
echo "### その日付を名前に持つファイル（.bak / .disabled / .old）"
ls -1 "$LA" 2>/dev/null | grep -E '\.(bak|disabled|old)' | head -20
echo
echo "### LaunchAgents を更新日時の新しい順に（上位 20 件）"
ls -1lTt "$LA" 2>/dev/null | head -21 | awk '{print $6, $7, $9, $NF}' | cut -c1-90

echo
echo "## 1. x-follower（能動フォロー・7/04 が最後）"
echo
for n in x-follower-cron x-follower follower-cron; do
  echo "### 名前に $n を含むもの"
  echo "- scripts: $(ls -1 "$W/scripts" 2>/dev/null | grep -i "$n" | tr '\n' ' ')"
  echo "- 直下:    $(ls -1 "$HOME" 2>/dev/null | grep -i "$n" | tr '\n' ' ')"
  echo "- plist:   $(ls -1 "$LA" 2>/dev/null | grep -i "$n" | tr '\n' ' ')"
  echo "- logs:    $(ls -1 "$W/logs" 2>/dev/null | grep -i "$n" | tr '\n' ' ')"
  echo "- crontab: $(crontab -l 2>/dev/null | grep -ci "$n" || true) 行"
done
echo
echo "### crontab 全体（コメント除く・パスは出す・値は伏せる）"
crontab -l 2>/dev/null | grep -vE '^\s*#' | grep -v '^\s*$' | mask | cut -c1-140 | head -20
echo "（crontab が空なら launchd 側にある）"

echo
echo "### x-follower のスクリプト本体（見つかったもの）"
for S in "$W"/scripts/*x-follower* "$HOME"/*x-follower* "$W"/*x-follower*; do
  [ -f "$S" ] || continue
  echo
  echo "#### $S  $(wc -l < "$S" | tr -d ' ') 行"
  echo "先頭コメント:"
  head -15 "$S" 2>/dev/null | grep -E '^\s*(//|#|/\*|\*)' | head -6 | mask | cut -c1-120
  echo "上限・間隔:"
  grep -nE '(MAX|LIMIT|CAP|DAILY|PER_|_PER|INTERVAL|DELAY|SLEEP)[A-Za-z_]*[[:space:]]*[=:][[:space:]]*[0-9]' "$S" 2>/dev/null | mask | cut -c1-120 | head -10
done

echo
echo "### x-follower のログ（最終 5 行・いつ・何件打ったか）"
for L in "$W"/logs/*x-follower* "$HOME"/logs/*x-follower*; do
  [ -f "$L" ] || continue
  echo "#### $(basename "$L")  更新=$(date -r "$L" -u +%Y-%m-%dT%H:%MZ 2>/dev/null)  $(wc -l < "$L" | tr -d ' ') 行"
  tail -5 "$L" 2>/dev/null | mask | cut -c1-120
done

echo
echo "## 2. chainifier（ループ①・8/08 まで動いて no entries）"
S="$W/scripts/auto-thread-chainifier.js"
P="$LA/ai.openclaw.auto-thread-chainifier.plist"
if [ -f "$P" ]; then
  echo "- StartInterval: $(plutil -extract StartInterval raw "$P" 2>/dev/null || echo '無し')"
  echo "- StartCalendarInterval: $(plutil -extract StartCalendarInterval json "$P" 2>/dev/null | cut -c1-200 || echo '無し')"
fi
if [ -f "$S" ]; then
  echo "- 行数: $(wc -l < "$S" | tr -d ' ')"
  echo "- 上限・しきい値:"
  grep -nE '(MAX|LIMIT|CAP|PER_|_PER|DAILY|COOLDOWN|THRESHOLD|our_responses)[A-Za-z_]*[[:space:]]*[=:]' "$S" 2>/dev/null | mask | cut -c1-120 | head -15
  echo "- モデル: $(grep -oE 'claude-[a-z0-9.-]+' "$S" 2>/dev/null | sort -u | tr '\n' ' ')"
  echo "- env: $(grep -oE 'process\.env\.[A-Z_]+' "$S" 2>/dev/null | sort -u | tr '\n' ' ')"
  echo "- 「no entries to chainify」を出す条件（前後 4 行）:"
  grep -n -B4 'no entries to chainify' "$S" 2>/dev/null | mask | cut -c1-120 | head -12
fi

echo
echo "## 3. unfollow（ループ③・一度も動いていない）"
S="$W/scripts/auto_detect_and_unfollow_inactive.js"
if [ -f "$S" ]; then
  echo "- 行数: $(wc -l < "$S" | tr -d ' ')"
  echo "- 上限・待機日数:"
  grep -nE '(MAX|LIMIT|CAP|DAYS|HOURS|THRESHOLD|RATIO|DRY_RUN|PHASE)[A-Za-z_]*[[:space:]]*[=:]' "$S" 2>/dev/null | mask | cut -c1-120 | head -20
  echo "- 除外判定:"
  grep -nE 'whitelist|blacklist|skip|exclude|protect' "$S" 2>/dev/null | mask | cut -c1-120 | head -12
  echo "- env: $(grep -oE 'process\.env\.[A-Z_]+' "$S" 2>/dev/null | sort -u | tr '\n' ' ')"
  echo "- 実行方法（先頭コメント）:"
  head -20 "$S" 2>/dev/null | grep -E '^\s*(//|#|/\*|\*)' | head -8 | mask | cut -c1-120
else
  echo "- scripts/auto_detect_and_unfollow_inactive.js が無い"
fi
} > "$OUT" 2>&1

echo "書き出した: $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
