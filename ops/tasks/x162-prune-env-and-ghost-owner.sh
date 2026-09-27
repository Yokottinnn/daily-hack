#!/bin/bash
# **実装前の最後の確認。3 点だけ読む。費用 $0。**
#
# ## ここまでで分かっていること
#
#   プロフィール   following 251 / followers 288（`x160`）
#   フォロー側     11:30 と 18:30 に撃つ・`COMPETITOR_FOLLOW_DAILY_CAP=30`・`FORCE_RUN=1`
#   アンフォロー   9 本中 6 本が載っていない。載っている 2 本もほぼ外していない
#   `mutual-prune` **相互だけが対象**と明記されている（`x161`）
#
#       // **相互だけを対象にする。** 片思いは既存の別ジョブの担当。
#       const mutual = [...following].filter((h) => lowerFollowers.has(h.toLowerCase()));
#
# **19 件のゴースト（片思い）は「別ジョブの担当」で、その別ジョブが載っていない。**
#
# ## 実装前に、これだけ確かめる
#
#   ① `mutual-prune` の plist の環境変数（**`DRY_RUN=1` が立っていないか**・`MAX_UNFOLLOW`）
#   ② `mutual-prune.js` の 1〜119 行（定数・`scrapeList`・`readProfile`。**写して使う**）
#   ③ **片思いを外す口がどこかに在るか**（在れば載せ直すだけで済む）
#
# **推測で新規に書くより、動いている実装を写すほうが確実。**
#
# ## やらないこと
#
# **フォローしない。アンフォローしない。設定も変えない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/prune-env-ghost.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

{
echo "# 実装前の最後の確認（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** これを最後にして実装に入る。"

echo
echo "## 1. \`mutual-prune\` はどう起動されているか"
echo
echo "**\`DRY_RUN=1\` が立っていれば、何をしても 1 件も外れない。**"
echo
echo '```'
P="$LA/ai.openclaw.mutual-prune.plist"
if [ -f "$P" ]; then
  /usr/libexec/PlistBuddy -c "Print" "$P" 2>/dev/null | clean | sed 's/^/  /'
else
  echo "  **plist が無い: $(basename "$P")**"
  ls -1 "$LA" 2>/dev/null | grep -i prune | sed 's/^/    /'
fi
echo '```'
echo
echo "直近のログの先頭行（**start 行に dry と max が出る**）:"
echo
echo '```'
grep -h "mutual-prune start" "$L/mutual-prune.log" 2>/dev/null | tail -5 | cut -c1-200 | clean | sed 's/^/  /'
echo
echo "  --- 直近の結果行 ---"
grep -h -E "外す候補|DRY_RUN|相互フォロー:|フォロー中:|フォロワー:" "$L/mutual-prune.log" 2>/dev/null | tail -20 | cut -c1-200 | clean | sed 's/^/  /'
echo '```'

echo
echo "## 2. \`mutual-prune.js\` の 1〜119 行（**写して使う部品**）"
echo
echo '```javascript'
if [ -f "$S/mutual-prune.js" ]; then
  sed -n '1,119p' "$S/mutual-prune.js" 2>/dev/null | cat -n | cut -c1-220 | clean | sed 's/^/  /'
else
  echo "  **mutual-prune.js が無い**"
fi
echo '```'

echo
echo "## 3. 片思いを外す口は在るか"
echo
echo "**在れば載せ直すだけで済む。** 無ければ書く。"
echo
echo '```'
echo "  --- unfollow を実際に押しているスクリプト ---"
grep -l -E 'confirmationSheetConfirm|-unfollow\$|unfollow' "$S"/*.js 2>/dev/null | sed 's|.*/|  |' || echo "  （無い）"
echo
echo "  --- 片思い / not following back を扱っていそうな箇所 ---"
grep -n -E '片思い|one[- ]?way|not.*follow.*back|notFollowingBack|ghost' "$S"/*.js 2>/dev/null | head -25 | cut -c1-200 | clean | sed 's|.*/scripts/|  |'
echo '```'
echo
for f in "$S/auto-detect-and-unfollow-inactive.js" "$S/unfollow-handle.js" "$S/revenge-unfollow.js"; do
  [ -f "$f" ] || continue
  echo "### \`$(basename "$f")\`（$(wc -l < "$f" | tr -d ' ') 行・更新 $(stat -f '%m-%d %H:%M' "$f" 2>/dev/null || stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)）"
  echo
  echo '```javascript'
  grep -n -E 'DRY|MAX|CAP|mutual|followers\.has|following|候補|candidates' "$f" 2>/dev/null | head -20 | cut -c1-200 | clean | sed 's/^/  /'
  echo '```'
  echo
done

echo
echo "---"
echo
echo "## 実装の方針（**この後すぐ書く**）"
echo
echo "決まっている基準（2026-09-27）。"
echo
echo "| | |"
echo "| --- | --- |"
echo "| 外す順 | ① 返していない相手 → ② 休眠 → ③ 大きいアカウント |"
echo "| 守る | 反応をくれた人 ／ フォローから 7 日未満 |"
echo "| 目標 | **1 日のアンフォロー数 ≧ 1 日のフォロー数** |"
echo
echo "フォロー側は **11:30 と 18:30 に撃ち、\`COMPETITOR_FOLLOW_DAILY_CAP=30\`**。"
echo "**追いつくには 1 日 30 件 以上 外せる必要がある。** いまの \`MAX_UNFOLLOW=8\` では足りない。"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'mutual-prune.js の 1' "$OUT" 2>/dev/null; then
  echo "実装前の確認を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
