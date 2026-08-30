#!/bin/bash
# **犯人は `tab-guard.js` らしい。裏を取る。読むだけ。**
#
# ## t013 で分かったこと
#
#   - **再起動ではない。** uptime 20 日、最後の再起動は 8/10
#   - `tab-guard.js:66` が **`ai.openclaw.*` を全部なめて、tab-guard 自身だけ除外**している
#
#       for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do
#         case "$p" in *tab-guard*) continue;; ...
#
#   - **生き残っていたのがちょうど `ai.openclaw.tab-guard` だけ**で、
#     `com.dailyhack.*`（別の接頭辞）は無傷。**パターンが完全に一致する。**
#
# ## だから確かめること
#
#   1. `tab-guard.js` は**どういう条件で**落とすのか（60〜90 行を出す）
#   2. **いつ発火したか**（ログ）
#   3. **`t012` で戻した 3 件は、まだ生きているか**
#      → 同じ条件が続いていれば**また落とされているはず**
#
# **これが分かるまで、残り 11 件を戻してはいけない。**
# 非常ブレーキが正しく効いているのに、それを無理に外すことになる。
#
# **何も変更しない。読むだけ。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/tab-guard-evidence.md"
TG="$W/scripts/tab-guard.js"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$1" || true; }

{
echo "# tab-guard が犯人かを確かめる（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> **再起動ではない**（uptime 20 日）。何かが能動的に落とした。"
echo "> \`tab-guard.js\` が \`ai.openclaw.*\` を全部なめ、**自分だけ除外**している。"
echo "> 生き残ったのがちょうど \`ai.openclaw.tab-guard\` だけ＝**パターンが一致**。"

echo
echo "## 1. どういう条件で落とすのか"
echo
echo '```javascript'
sed -n '40,95p' "$TG" 2>/dev/null | mask | cut -c1-170
echo '```'

echo
echo "## 2. しきい値らしきもの"
echo
echo '```javascript'
grep -nE 'MAX|THRESHOLD|LIMIT|tabs?\.length|>\s*[0-9]{1,3}|process\.env\.[A-Z_]+' "$TG" 2>/dev/null \
  | head -14 | cut -c1-150 | mask
echo '```'

echo
echo "## 3. いつ発火したか（ログ）"
echo
for f in "$HOME/.openclaw/logs/tab-guard.out.log" "$HOME/.openclaw/logs/tab-guard.err.log" \
         "$W/logs/tab-guard.log" "$W/logs/tab-guard.out.log"; do
  [ -f "$f" ] || continue
  echo "### \`$(basename "$f")\`（更新: $(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)）"
  echo '```'
  tail -25 "$f" 2>/dev/null | hide | mask | cut -c1-170
  echo '```'
  echo
done
ls "$HOME/.openclaw/logs"/tab*guard* "$W/logs"/tab*guard* >/dev/null 2>&1 || echo "（tab-guard のログが見つからない）"

echo
echo "## 4. **戻した 3 件は、まだ生きているか**"
echo
echo "> 同じ条件が続いていれば、\`t012\` で戻した 3 件も**また落とされているはず。**"
echo
for L in ai.openclaw.comment-warmup ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  c="$(loaded "$L")"
  if [ "$c" = "0" ]; then
    echo "- \`$L\`: **落ちている（ロード=0）** ← また落とされた"
  else
    echo "- \`$L\`: 生きている（ロード=$c）"
  fi
done
echo
echo "### いま載っているもの（全体）"
echo '```'
launchctl list 2>/dev/null | awk 'NR==1 || /dailyhack|openclaw/ {print}' | head -20 | mask
echo '```'

echo
echo "## 5. tab-guard 自身の状態"
echo
echo "- ロード: **$(loaded ai.openclaw.tab-guard)** 件"
echo '```'
plutil -p "$HOME/Library/LaunchAgents/ai.openclaw.tab-guard.plist" 2>/dev/null \
  | grep -aE 'StartInterval|RunAtLoad|KeepAlive|ProgramArguments|=>' | head -12 | mask
echo '```'

echo
echo "## 6. 判断の材料"
echo
echo "**結論は書かない。** 上の 1〜5 から、人が次のどれかを選ぶこと。"
echo
echo "- (A) **tab-guard が正しく作動した**（Chrome のタブ過多などの実害があった）"
echo "  → 戻すのではなく、**先に発火条件のほうを解消する。**"
echo "  無理に戻しても、また落とされるだけで消耗する"
echo "- (B) **tab-guard が過剰に反応した**（しきい値が厳しすぎる／誤検知）"
echo "  → しきい値を見直してから戻す"
echo "- (C) **落とす対象が広すぎる**（返信・フォローまで巻き込む必要は無いのでは）"
echo "  → 除外リストに本線を足すことを検討する"
echo "- (D) 判断できない → **戻さない。**さらに証拠を集める"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'また落とされた' "$OUT" 2>/dev/null; then
  echo "🚨 **戻した3件がまた落とされている。tab-guard が繰り返し発火** / $(basename "$OUT")"
else
  echo "3件は生存。tab-guard の条件を報告に出した / $(basename "$OUT")"
fi
