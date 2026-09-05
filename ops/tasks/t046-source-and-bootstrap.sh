#!/bin/bash
# **候補の供給源を調べる ＋ アンフォローの bootstrap 失敗を切り分ける。費用 $0。**
#
# ## t045 で分かったこと
#
# ### (A) フィルタは悪くない。**候補の 4 割がゴミ**
#
# 弾かれた相手のフォロワー数:
#
#   20 件  0 人  ┐
#    4 件  1 人  │ **28 件（76%）が 0〜9 人の空アカウント**  ← 正しく弾いている
#    3 件  2 人  │
#    1 件  9 人  ┘
#    9 件  26,000〜103,000 人（上限超え）
#
# 上限を上げても増えるのは 1 日 9 件ほど。**直すべきは供給源。**
# どのアカウントのフォロワーを見るか、どのハッシュタグを引くかが質を決めている。
#
# ### (B) アンフォロー 6 本は enable では直らない
#
#   Bootstrap failed: 5: Input/output error
#
# `launchctl disable` ではなかった。**推測で次を打たず、plist の実体を見る。**
# EIO は「同じ Label が既に登録されている」「plist が壊れている」「Label と
# ファイル名が食い違う」あたりで出る。**どれかを実物で確かめる。**
#
# ## 出すもの（すべて無料・LLM を呼ばない）
#
#   1. 競合フォロワーの**取得元アカウント一覧**（誰のフォロワーを見ているか）
#   2. ハッシュタグの**検索語一覧**
#   3. 1 回あたり何件 スクレイプする設定か
#   4. 失敗する 6 本の plist: `plutil -lint` / **Label の実値** / `launchctl print` の出力
#
# ## やらないこと
#
# **フォローしない。アンフォローしない。投稿しない。書き換えない。LLM も呼ばない。**
#
# **ハンドルは伏せない**（取得元の設定は運用判断に必要。相手の個人情報ではない）。
# ただし API キーは値を出さない。
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/source-and-bootstrap.md"
UID_N="$(id -u)"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }

FAILED="ai.openclaw.follow-watchdog
ai.openclaw.unfollow-daily
ai.openclaw.unfollow-evening
ai.openclaw.unfollow-cleanup-morning
ai.openclaw.unfollow-cleanup-evening
ai.openclaw.revenge-unfollow"

{
echo "# 候補の供給源と bootstrap 失敗の切り分け（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> **フィルタは悪くない。候補の 4 割がゴミ。**"
echo "> 弾かれた 37 件のうち **28 件がフォロワー 0〜9 人**の空アカウントだった。"
echo "> 上限を上げても増えるのは 1 日 9 件ほど。**直すべきは供給源。**"
echo "> **書き換えない。フォローもアンフォローもしない。**"

echo
echo "## 1. 競合フォロワーの取得元（**誰のフォロワーを見ているか**）"
echo
for f in "$W"/data/follower-target-config.json "$W"/data/competitor*.json "$W"/data/target*.json; do
  [ -f "$f" ] || continue
  echo "### \`$(basename "$f")\` — 更新 $(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
  echo
  echo '```json'
  head -c 1800 "$f" 2>/dev/null | mask
  echo
  echo '```'
  echo
done

echo
echo "## 2. 取得元とスクレイプ数（スクリプトの実体）"
echo
for s in "$W"/scripts/competitor-follower-follow.js "$W"/scripts/hashtag-follow.js; do
  [ -f "$s" ] || continue
  echo "### \`$(basename "$s")\`"
  echo
  echo '```javascript'
  grep -nE 'SCRAPE|TARGET|COMPETITOR|HASHTAG|TAGS|QUERY|SEARCH|const .*=.*\[|https://x\.com|twitter\.com' "$s" 2>/dev/null \
    | head -25 | cut -c1-190 | mask
  echo '```'
  echo
done

echo
echo "## 3. ハッシュタグの検索語"
echo
echo '```'
grep -ohE '#[^"'"'"' ,\]]{2,20}' "$W"/scripts/hashtag-follow.js "$W"/data/*.json 2>/dev/null \
  | sort | uniq -c | sort -rn | head -25 | mask || echo "（見つからない）"
echo '```'

echo
echo "## 4. bootstrap が失敗する 6 本の実体"
for j in $FAILED; do
  P="$LA/$j.plist"
  echo
  echo "### \`${j#ai.openclaw.}\`"
  if [ ! -f "$P" ]; then echo; echo "- **plist が無い**"; continue; fi
  echo
  echo "- サイズ $(wc -c < "$P" | tr -d ' ') B / 更新 $(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null) / 権限 $(stat -f '%Sp %Su' "$P" 2>/dev/null)"
  lint="$(plutil -lint "$P" 2>&1 | tail -1)"
  echo "- \`plutil -lint\`: $(printf '%s' "$lint" | mask)"
  lbl="$(plutil -extract Label raw -o - "$P" 2>/dev/null || echo '（読めない）')"
  echo "- plist 内の Label: \`$(printf '%s' "$lbl" | mask)\`"
  if [ "$lbl" != "$j" ]; then
    echo "- ⚠️ **ファイル名と Label が食い違っている**（ファイル: \`$j\`）"
  fi
  if launchctl list 2>/dev/null | grep -qF "$lbl"; then
    echo "- ⚠️ **その Label は既に登録されている**"
  fi
  echo
  echo "\`launchctl print\` の出力:"
  echo '```'
  launchctl print "gui/$UID_N/$lbl" 2>&1 | head -12 | cut -c1-150 | mask
  echo '```'
done

echo
echo "## 5. 同じ Label が別ファイルにも無いか"
echo
echo '```'
for j in $FAILED; do
  n=$(grep -rl "$j" "$LA" 2>/dev/null | wc -l | tr -d ' ')
  printf '%-40s %s ファイル\n' "${j#ai.openclaw.}" "$n"
  [ "$n" -gt 1 ] && grep -rl "$j" "$LA" 2>/dev/null | sed 's/^/    /'
done
echo '```'

echo
echo "---"
echo
echo "**何も変えていない（\$0）。** 次はここの実体を見てから、供給源と bootstrap を直す。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**供給源と bootstrap を調べた（変更なし・\$0）** / $(basename "$OUT")"
