#!/bin/bash
# **フォローのフィルタを緩める。フォロワー増の最優先対応。費用 $0（LLM を呼ばない）。**
#
# ## 何が起きていたか（t035 の実測）
#
#   competitor-follower-follow  02:33Z → === end: 0/10 OK ===
#   hashtag-follow              01:18Z → === end: 1/5 OK ===
#
# **ジョブは動いている。フィルタが全部 弾いていた。** 今日フォローできたのは 1 人。
#
# ## 根拠（t038 で読んだ実物）
#
# `follow-handle.js:32-34`
#
#     if (clean.length >= 10) {
#       const digits = (clean.match(/\d/g) || []).length;
#       if (digits / clean.length >= 0.4) return true;
#
# `kankan1014` は 10 文字・数字 4 個 → **0.4 ちょうどで境界にヒット**。
# **名前＋4 桁数字という、日本語アカウントで最も多い形が丸ごと落ちていた。**
#
# 本当にランダムな `FC0yvmH8niM8TnY`（0.20）や `bJCLtICrZA93414`（0.33）は
# **この行では引っかかっていない。** 下の「大小文字混在＋母音が少ない」判定で捕まっている。
# **だから 0.4 → 0.6 に上げても、スパムは今までどおり弾ける。**
#
# ## 変えるもの
#
#   :34  数字比率        >= 0.4   → >= 0.6    kankan1014 を通す
#   :74  フォロワー上限  10000    → 50000     10.3 万で弾いた例あり
#   :82  ratio           < 0.3    → < 0.15    0.19 で弾いた例あり
#   :48  bio 文字数      < 25     → < 15      X の bio で 25 字は高い
#   plist COMPETITOR_FOLLOW_DAILY_CAP  10 → 30
#   plist FORCE_RUN                    なし → 1（**日曜・月曜の休みを外す**）
#
# `HASHTAG_FOLLOW_DAILY_CAP` は既に 90。詰まっているのは上限ではなく
# 候補の取得数（1 回 5 件）なので、**上げても効かない。触らない。**
#
# **ratio 0.3 は利用者自身の指示だった**（`:78` に「2026-05-25 改定 user 指示」）。
# 承認済みだが、過去の判断を覆す変更なのでここに残す。
#
# ## 安全側の作り
#
#   1. **必ずバックアップを取る**（日時つき）
#   2. 置換は**読んだ実物の文字列に完全一致**するときだけ。1 つでも当たらなければ中止
#   3. 置換後に `node --check`。**構文が壊れたら自動で巻き戻す**
#   4. 差分を出す
#
# **1 日の上限は毀さない。** X のスパム判定を食らうと復旧に時間がかかり、急ぐほど遅くなる。
#
# **フォローしない（次回の定時実行から効く）。投稿しない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
FH="$W/scripts/follow-handle.js"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/loosen-follow-filters.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BAK="$FH.bak-$STAMP"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }

{
echo "# フォローのフィルタを緩める（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> **ジョブは動いていた。フィルタが全部 弾いていた。** 今日フォローできたのは 1 人。"
echo "> **バックアップ → 置換 → \`node --check\` → 失敗なら自動で巻き戻し。**"
echo "> **LLM を呼ばない。フォローもしない**（次回の定時実行から効く）。"

echo
echo "## 1. バックアップ"
echo
[ -f "$FH" ] || { echo "- **\`follow-handle.js\` が無い。中止。**"; exit 1; }
cp -p "$FH" "$BAK" || { echo "- **バックアップに失敗。中止。**"; exit 1; }
echo "- \`$(basename "$BAK")\` を作成（$(wc -l < "$BAK" | tr -d ' ') 行）"

echo
echo "## 2. 置換（**実物に完全一致するときだけ**）"
echo
NG=0
apply() { # apply <説明> <before> <after>
  local label="$1" before="$2" after="$3"
  if ! grep -qF "$before" "$FH"; then
    echo "- ❌ **$label**: 一致しない → \`$before\`"
    NG=1; return
  fi
  local tmp="$FH.tmp.$$"
  "$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1], b=process.argv[2], a=process.argv[3];
const s=fs.readFileSync(p,"utf8");
fs.writeFileSync(process.argv[4], s.split(b).join(a));
' "$FH" "$before" "$after" "$tmp" 2>/dev/null && mv "$tmp" "$FH" \
    && echo "- ✅ **$label**: \`$before\` → \`$after\`" \
    || { echo "- ❌ **$label**: 置換に失敗"; rm -f "$tmp"; NG=1; }
}

apply "ランダム判定の数字比率（kankan1014 を通す）" \
      'if (digits / clean.length >= 0.4) return true;' \
      'if (digits / clean.length >= 0.6) return true;'

apply "フォロワー数の上限" \
      'follower_count > 10000) {' \
      'follower_count > 50000) {'

apply "上限のメッセージ" \
      'need ${minFollowers}-10000' \
      'need ${minFollowers}-50000'

apply "ratio のしきい値（2026-05-25 の user 指示を承認のうえ変更）" \
      'if (ratio < 0.3) {' \
      'if (ratio < 0.15) {'

apply "bio の最低文字数" \
      'if (stripped.length < 25) return true;' \
      'if (stripped.length < 15) return true;'

echo
echo "## 3. 構文チェック"
echo
if [ "$NG" = "1" ]; then
  cp -p "$BAK" "$FH"
  echo "- **当たらない置換があった。全部 巻き戻した。**"
  echo "- 変更なし。**フィルタは元のまま。**"
  exit 1
fi
if "$NODE_BIN" --check "$FH" 2>/dev/null; then
  echo "- ✅ \`node --check\` 通過"
else
  cp -p "$BAK" "$FH"
  echo "- ❌ **構文が壊れた。巻き戻した。変更なし。**"
  exit 1
fi

echo
echo "## 4. 差分"
echo
echo '```diff'
diff -u "$BAK" "$FH" 2>/dev/null | sed -n '1,60p' | mask || true
echo '```'

echo
echo "## 5. plist（日次上限と、日曜・月曜の休み）"
echo
P="$LA/ai.openclaw.competitor-follower-follow.plist"
if [ -f "$P" ]; then
  cp -p "$P" "$P.bak-$STAMP"
  /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:COMPETITOR_FOLLOW_DAILY_CAP 30" "$P" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:COMPETITOR_FOLLOW_DAILY_CAP string 30" "$P" 2>/dev/null
  /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:FORCE_RUN string 1" "$P" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:FORCE_RUN 1" "$P" 2>/dev/null
  echo "### \`competitor-follower-follow\`"
  echo '```'
  /usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$P" 2>/dev/null | mask
  echo '```'
else
  echo "- competitor の plist が無い"
fi

P2="$LA/ai.openclaw.hashtag-follow.plist"
if [ -f "$P2" ]; then
  cp -p "$P2" "$P2.bak-$STAMP"
  # **上限は触らない**（既に 90 で、詰まりは候補の取得数）。日曜・月曜の休みだけ外す
  /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:FORCE_RUN string 1" "$P2" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:FORCE_RUN 1" "$P2" 2>/dev/null
  echo
  echo "### \`hashtag-follow\`（**上限は触らない**。詰まりは候補の取得数）"
  echo '```'
  /usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$P2" 2>/dev/null | mask
  echo '```'
fi

echo
echo "### plist を読み直す"
echo
echo '```'
for j in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  launchctl bootout "gui/$(id -u)/$j" 2>/dev/null || true
  if launchctl bootstrap "gui/$(id -u)" "$LA/$j.plist" 2>/dev/null; then
    echo "$j: 読み直した"
  else
    echo "$j: **bootstrap に失敗**"
  fi
done
sleep 2
launchctl list 2>/dev/null | grep -E 'competitor-follower-follow|hashtag-follow' | mask || echo "（一覧に出ない）"
echo '```'

echo
echo "## 6. 停止していた badge-followback を戻す"
echo
echo "8/28-29 に実際にフォロバを返していた実績がある。**止める理由が無い。**"
echo
echo '```'
BP="$LA/ai.openclaw.badge-followback.plist"
if [ -f "$BP" ]; then
  launchctl bootstrap "gui/$(id -u)" "$BP" 2>/dev/null \
    && echo "badge-followback: ロードした" \
    || echo "badge-followback: **bootstrap に失敗**（既にロード済みの可能性）"
  launchctl list 2>/dev/null | grep -F 'badge-followback' | mask || echo "（一覧に出ない）"
else
  echo "badge-followback の plist が無い"
fi
echo '```'

echo
echo "---"
echo
echo "## まとめ"
echo
echo "| | 変更前 | 変更後 |"
echo "| --- | --- | --- |"
echo "| 数字比率（ランダム判定） | >= 0.4 | **>= 0.6** |"
echo "| フォロワー上限 | 10,000 | **50,000** |"
echo "| ratio | < 0.3 で skip | **< 0.15 で skip** |"
echo "| bio 最低文字数 | 25 | **15** |"
echo "| competitor 日次上限 | 10 | **30** |"
echo "| 日曜・月曜 | **休み** | **稼働**（FORCE_RUN=1） |"
echo "| badge-followback | 停止 | **稼働** |"
echo
echo "**1 日の上限は残してある。** 巻き戻しは \`$(basename "$BAK")\` から。"
echo "**LLM を呼んでいない（\$0）。フォローもしていない**（次回の定時実行から効く）。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'node --check\` 通過' "$OUT" 2>/dev/null; then echo "**フィルタを緩めた（\$0）** / $(basename "$OUT")"
else echo "**変更せず巻き戻した** / $(basename "$OUT")"; fi
