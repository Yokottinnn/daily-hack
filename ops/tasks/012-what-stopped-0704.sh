#!/bin/bash
# 2026-07-04 に何を止めたのかを特定する。
#
# 手がかり:
#   - x-follower-cron（能動フォロー）の最終記録が 2026-07-04 23:54 JST
#   - follower-target-monitor.plist が .bak.20260704-v7 にリネームされている
#   - フォロワーは 7/04 時点で 161、8/22 で 207（49 日で +46）
#
# **同じ日に複数を止めている以上、意図的な操作だった可能性が高い。**
# 理由が分からないまま戻すと、止めた理由を踏み直す。まず何が起きたかを見る。
#
# **読み取りのみ。何もロードしない。何も戻さない。**
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
# シェル履歴は特に危険なので、launchctl / plist に関係する行だけに絞り、
# 20 字以上の連続英数字は伏せる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/what-stopped-0704.md"
mask() { sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g'; }

{
echo "# 2026-07-04 に何が止まったか（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"

echo
echo "## 1. 7/04 前後に更新されたファイル"
echo
echo "### LaunchAgents（7/03〜7/06 に触られたもの）"
find "$LA" -maxdepth 1 -newermt '2026-07-03' ! -newermt '2026-07-06' 2>/dev/null \
  | while read -r f; do
      echo "- $(basename "$f")  $(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null)"
    done
echo "（該当なしなら空）"

echo
echo "### workspace の scripts / data / state（7/03〜7/06・上位 25 件）"
for d in scripts data state config; do
  find "$W/$d" -maxdepth 1 -type f -newermt '2026-07-03' ! -newermt '2026-07-06' 2>/dev/null \
    | head -25 | while read -r f; do
        echo "- $d/$(basename "$f")  $(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null)"
      done
done
echo "（該当なしなら空）"

echo
echo "## 2. 無効化された痕跡（.bak / .disabled / .old）全部"
for d in "$LA" "$W/scripts" "$W/data" "$W/config"; do
  [ -d "$d" ] || continue
  ls -1 "$d" 2>/dev/null | grep -E '\.(bak|disabled|old|off)' | while read -r n; do
    echo "- ${d/#$HOME/~}/$n  $(date -r "$d/$n" '+%Y-%m-%d %H:%M' 2>/dev/null)"
  done
done
echo "（該当なしなら空）"

echo
echo "## 3. シェル履歴のうち launchctl / plist に関する行のみ"
echo
echo "> **絞り込んで出している。** 履歴全体には秘密が入りうるため、"
echo "> launchctl・plist・unload・disable を含む行だけを、値を伏せて出す。"
for H in "$HOME/.zsh_history" "$HOME/.bash_history"; do
  [ -f "$H" ] || continue
  echo
  echo "### $(basename "$H")（該当行の末尾 25 件）"
  grep -aiE 'launchctl|\.plist|bootout|unload|disable' "$H" 2>/dev/null \
    | grep -aiE 'follower|unfollow|chainif|warmup|monitor|x-follower' \
    | tail -25 | mask | cut -c1-140
done

echo
echo "## 4. workspace が git 管理なら、7/04 前後のコミット"
if [ -d "$W/.git" ]; then
  git -C "$W" log --since=2026-07-01 --until=2026-07-08 \
    --pretty='- %ad %s' --date=short 2>/dev/null | mask | cut -c1-140 | head -20
  echo "（該当なしなら空）"
else
  echo "（workspace は git 管理ではない）"
fi

echo
echo "## 5. その頃のログに残る停止理由"
echo
for L in "$W"/logs/*x-follower* "$W"/logs/*follower-target* "$W"/logs/*follower*; do
  [ -f "$L" ] || continue
  echo "### $(basename "$L")  $(wc -l < "$L" | tr -d ' ') 行  更新=$(date -r "$L" '+%Y-%m-%d %H:%M' 2>/dev/null)"
  echo "7/01〜7/08 の行:"
  grep -aE '2026-07-0[1-8]' "$L" 2>/dev/null | tail -12 | mask | cut -c1-140
  echo "最終 3 行:"
  tail -3 "$L" 2>/dev/null | mask | cut -c1-140
done

echo
echo "## 6. 7/04 に何を書き残しているか（memory / notes）"
for M in "$HOME/.claude/projects"/*openclaw*/memory "$W/memory" "$W/notes"; do
  [ -d "$M" ] || continue
  echo "### ${M/#$HOME/~}"
  grep -rlaiE '2026-07-04|7/04|7月4日' "$M" 2>/dev/null | head -5 | while read -r f; do
    echo "- $(basename "$f")"
    grep -haiE -A2 '2026-07-04|7/04|7月4日' "$f" 2>/dev/null | head -8 | mask | cut -c1-140 | sed 's/^/    /'
  done
done
} > "$OUT" 2>&1

echo "書き出した: $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
