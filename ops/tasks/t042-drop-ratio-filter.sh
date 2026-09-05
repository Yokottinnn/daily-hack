#!/bin/bash
# **ratio フィルタを外して、すぐ走らせる。費用 $0。**
#
# ## t041 の実測（緩和は効いている）
#
#   competitor  09:02:51 ✅ / 09:05:37 ✅      緩和前は 0/10 だった
#   hashtag     08:04 === end: 1/3 OK === / 09:01 === end: 1/1 OK ===
#   今日のフォロー実績  1 件 → 5 件
#   random-looking handle の誤判定  → 消えた
#
# ## だが ratio がまだ最大の障壁
#
#   ratio=0.01 (fw=160/fr=28000)     ratio=0.08 (fw=25/fr=325)
#   ratio=0.01 (fw=325/fr=28000)     ratio=0.08 (fw=25/fr=326)
#   ratio=0.01 (fw=333/fr=26000)     ratio=0.11 (fw=255/fr=2353)
#   ratio=0.03 (fw=1071/fr=40000)    ratio=0.19 (fw=222/fr=1148)
#
# 利用者の判断（2026-09-05）: **ratio を完全に外す。**
#
# **8 件中 4 件はフォロワー 2.6〜4 万の大型アカ**（ratio 0.01〜0.03）で、
# これは元のフィルタが狙って除外していた層。外すと日次枠をここに使う。
# **だから環境変数で戻せる形にする。** 量を見てから絞り直せるように。
#
# ## やり方
#
#   if (ratio < 0.15) {   →   if (ratio < Number(process.env.FOLLOW_MIN_RATIO || "0")) {
#
# 既定 0 なので `ratio < 0` は成立せず、**実質 無効**。
# 戻したくなったら plist に `FOLLOW_MIN_RATIO=0.15` を足すだけ。**コードを触らない。**
#
# ## 安全側の作り
#
#   1. バックアップ（日時つき）
#   2. 実物に完全一致するときだけ置換。外れたら中止
#   3. `node --check`。壊れたら自動で巻き戻す
#   4. **そのまま kickstart して結果まで出す**（定時を待たない・最上位ルール 9）
#
# **投稿しない。LLM も呼ばない（フォローは Playwright の DOM 操作のみ）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
FH="$W/scripts/follow-handle.js"
OUT="${OPS_REPORT_DIR:-/tmp}/drop-ratio-filter.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UID_N="$(id -u)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BAK="$FH.bak-$STAMP"
BUDGET=200
CL="$W/logs/competitor-follower-follow.log"
HL="$W/logs/hashtag-follow.log"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# ratio フィルタを外して即実行（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> **緩和は効いている。** 今日のフォローは 1 件 → 5 件、誤判定は消えた。"
echo "> **残る最大の障壁が ratio。** 利用者の判断で完全に外す。"
echo "> **環境変数で戻せる形にする**（\`FOLLOW_MIN_RATIO\`）。**定時を待たず kickstart する。**"

echo
echo "## 1. バックアップと置換"
echo
[ -f "$FH" ] || { echo "- **\`follow-handle.js\` が無い。中止。**"; exit 1; }
cp -p "$FH" "$BAK" || { echo "- **バックアップに失敗。中止。**"; exit 1; }
echo "- \`$(basename "$BAK")\` を作成"

BEFORE='if (ratio < 0.15) {'
AFTER='if (ratio < Number(process.env.FOLLOW_MIN_RATIO || "0")) {'
if ! grep -qF "$BEFORE" "$FH"; then
  echo "- ❌ **一致しない**: \`$BEFORE\`"
  echo "- 現在の該当行:"
  echo '```javascript'
  grep -nE 'if \(ratio <' "$FH" 2>/dev/null | mask
  echo '```'
  echo "- **中止。変更なし。**"
  exit 1
fi
TMP="$FH.tmp.$$"
"$NODE_BIN" -e '
const fs=require("fs");
const s=fs.readFileSync(process.argv[1],"utf8");
fs.writeFileSync(process.argv[4], s.split(process.argv[2]).join(process.argv[3]));
' "$FH" "$BEFORE" "$AFTER" "$TMP" && mv "$TMP" "$FH" \
  && echo "- ✅ 置換: \`$BEFORE\` → \`$AFTER\`" \
  || { rm -f "$TMP"; cp -p "$BAK" "$FH"; echo "- ❌ 置換に失敗。巻き戻した。"; exit 1; }

if "$NODE_BIN" --check "$FH" 2>/dev/null; then
  echo "- ✅ \`node --check\` 通過"
else
  cp -p "$BAK" "$FH"
  echo "- ❌ **構文が壊れた。巻き戻した。変更なし。**"
  exit 1
fi
echo
echo '```diff'
diff -u "$BAK" "$FH" 2>/dev/null | sed -n '1,25p' | mask || true
echo '```'
echo
echo "**既定は 0 なので \`ratio < 0\` は成立せず、実質 無効。**"
echo "戻すときは plist に \`FOLLOW_MIN_RATIO=0.15\` を足すだけ。**コードは触らない。**"

echo
echo "## 2. 即実行（定時を待たない）"
echo
CB=$( [ -f "$CL" ] && wc -l < "$CL" | tr -d ' ' || echo 0 )
HB=$( [ -f "$HL" ] && wc -l < "$HL" | tr -d ' ' || echo 0 )
echo '```'
for j in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  launchctl kickstart -k "gui/$UID_N/$j" >/dev/null 2>&1 \
    && echo "$j: kickstart した" || echo "$j: **kickstart に失敗**"
done
echo '```'
echo
START=$(date +%s)
while :; do
  [ $(( $(date +%s) - START )) -ge "$BUDGET" ] && break
  cd=$( [ -f "$CL" ] && tail -n +$((CB+1)) "$CL" 2>/dev/null | grep -c '=== end:' || echo 0 )
  hd=$( [ -f "$HL" ] && tail -n +$((HB+1)) "$HL" 2>/dev/null | grep -c '=== end:' || echo 0 )
  [ "$cd" -ge 1 ] && [ "$hd" -ge 1 ] && break
  sleep 10
done
echo "- 見張った時間: **$(( $(date +%s) - START )) 秒**"

for pair in "competitor:$CL:$CB" "hashtag:$HL:$HB"; do
  name="${pair%%:*}"; rest="${pair#*:}"; log="${rest%%:*}"; base="${rest##*:}"
  echo
  echo "### ${name}"
  [ -f "$log" ] || { echo; echo "- ログが無い"; continue; }
  NEW="$(tail -n +$((base+1)) "$log" 2>/dev/null)"
  echo
  echo '```'
  printf '%s\n' "$NEW" | grep -E '=== end:' | mask || echo "（まだ終わっていない）"
  echo '```'
  echo
  echo "**通ったもの**"
  echo
  echo '```'
  printf '%s\n' "$NEW" | grep -E ': ✅' | hide | mask || echo "（なし）"
  echo '```'
  echo
  echo "**弾いた理由**"
  echo
  echo '```'
  printf '%s\n' "$NEW" | grep -oE '❌ [^:(]*' | sed 's/ *$//' | sort | uniq -c | sort -rn | head -10 | mask || echo "（なし）"
  echo '```'
  echo
  echo "**ratio でまだ弾いていないか**（外したので 0 件のはず）"
  echo
  echo '```'
  printf '%s\n' "$NEW" | grep -cE 'follower>>following exclusion' | sed 's/^/ratio で弾いた件数: /'
  echo '```'
done

echo
echo "## 3. 当日のフォロー実績"
echo
echo '```'
TODAY="$(date +%Y-%m-%d)"
for f in "$W"/data/reply-followers.json "$W"/data/followed.json; do
  [ -f "$f" ] || continue
  echo "$(basename "$f"): 今日 $(grep -o "\"$TODAY" "$f" 2>/dev/null | wc -l | tr -d ' ') 件 / 更新 $(stat -f '%Sm' -t '%H:%M' "$f" 2>/dev/null)"
done
echo '```'

echo
echo "---"
echo
echo "**基準線: 今朝は競合 0/10・ハッシュタグ 1/5 ＝ 合計 1 人。緩和後は 5 件。**"
echo "巻き戻しは \`$(basename "$BAK")\` から。**投稿していない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**ratio を外して即実行した（\$0）** / $(basename "$OUT")"
