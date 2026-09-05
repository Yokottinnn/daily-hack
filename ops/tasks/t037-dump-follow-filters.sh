#!/bin/bash
# **フォローのフィルタを実物で読む。数字をいじる前に。費用 $0。**
#
# ## 分かっていること（t035 の実測）
#
#   competitor-follower-follow  02:33Z → === end: 0/10 OK ===
#   hashtag-follow              01:18Z → === end: 1/5 OK ===
#
# **ジョブは動いている。フィルタが全部 弾いている。** 今日フォローできたのは 1 人。
#
# 弾いた理由の実物:
#   ❌ random-looking handle (likely throwaway/spam): kankan1014   ← **誤判定**
#   ❌ follower count out of range (103000, need 100-10000)
#   ❌ follower>>following exclusion: ratio=0.19 (need 0.3)
#   ❌ low-density bio (空 or テンプレキーワードのみ)
#   ❌ inactive (last post 152d ago)
#
# 「kankan1014」は**名前＋数字のごく普通の日本語ハンドル**。ここが誤判定だと、
# 良い相手を大量に取りこぼす。**フォロワー増の最大の詰まりどころ。**
#
# ## 出すもの（すべて無料・LLM を呼ばない）
#
#   1. 2 つのジョブが**実際に叩いているスクリプト**（plist の ProgramArguments 全文）
#   2. そのスクリプトの**フィルタ判定部分を丸ごと**（file:line つき）
#   3. **ランダム判定の正規表現**（kankan1014 が弾かれる理由）
#   4. **数字の定数**（フォロワー数の範囲・ratio・1 回あたりの候補数・日次上限）
#   5. その定数が**環境変数で外から変えられるか**（plist を直すだけで済むか）
#
# 5 が分かれば、**スクリプトを書き換えずに plist だけで調整できる**かが決まる。
#
# ## やらないこと
#
# **フォローしない。投稿しない。ジョブを触らない。書き換えない。LLM も呼ばない。**
#
# **API キーは値を出さない。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-filters.md"
LA="$HOME/Library/LaunchAgents"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

JOBS="ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow"

{
echo "# フォローのフィルタ実物（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> **ジョブは動いている。フィルタが全部 弾いている。** 今日フォローできたのは 1 人。"
echo "> \`kankan1014\` を「ランダムなハンドル」と誤判定していた。**ここが最大の詰まりどころ。**"
echo "> **書き換えない。フォローしない。ジョブも触らない。**"

for j in $JOBS; do
  P="$LA/$j.plist"
  echo
  echo "## \`$j\`"
  [ -f "$P" ] || { echo; echo "- **plist が無い**"; continue; }

  echo
  echo "### 叩いているもの（plist の ProgramArguments）"
  echo
  echo '```'
  awk '/<key>ProgramArguments<\/key>/,/<\/array>/' "$P" 2>/dev/null | grep -oE '<string>[^<]*</string>' \
    | sed -E 's#</?string>##g' | mask
  echo '```'
  echo
  echo "### 環境変数（**plist だけで調整できるか**）"
  echo
  echo '```'
  awk '/<key>EnvironmentVariables<\/key>/,/<\/dict>/' "$P" 2>/dev/null \
    | grep -oE '<(key|string)>[^<]*</(key|string)>' | sed -E 's#</?(key|string)>##g' \
    | paste - - 2>/dev/null | mask || echo "（EnvironmentVariables なし）"
  echo '```'

  # 実際のスクリプトを特定して中身を読む
  S="$(awk '/<key>ProgramArguments<\/key>/,/<\/array>/' "$P" 2>/dev/null | grep -oE '<string>[^<]*</string>' \
      | sed -E 's#</?string>##g' | grep -E '\.(js|cjs|mjs|sh)$' | head -1)"
  if [ -z "$S" ] || [ ! -f "$S" ]; then
    echo
    echo "- **スクリプトを特定できない**（候補: ${S:-なし}）"
    continue
  fi
  echo
  echo "### \`$(basename "$S")\` — $(wc -l < "$S" | tr -d ' ') 行"
  echo
  echo "#### 数字の定数（範囲・ratio・件数・上限）"
  echo
  echo '```javascript'
  grep -nE '(MIN|MAX|LIMIT|CAP|RANGE|RATIO|THRESHOLD|PER_(RUN|FIRE|DAY)|DAILY)[A-Z_]*\s*=|process\.env\.[A-Z_]+' "$S" 2>/dev/null \
    | head -30 | cut -c1-180 | mask
  echo '```'
  echo
  echo "#### ランダム判定（\`kankan1014\` が弾かれる理由）"
  echo
  echo '```javascript'
  grep -nE 'random.?looking|throwaway|spam|/\^?\[a-z\]|test\(|handle' "$S" 2>/dev/null \
    | head -25 | cut -c1-180 | mask
  echo '```'
  echo
  echo "#### 弾く判定の本体（ログの文言から逆引き）"
  echo
  echo '```javascript'
  grep -nE 'out of range|exclusion|low-density|inactive|ratio|❌' "$S" 2>/dev/null \
    | head -25 | cut -c1-180 | hide | mask
  echo '```'
done

echo
echo "---"
echo
echo "**何も変えていない（\$0）。** 次はここの数字だけを、根拠を持って動かす。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**フィルタの実物を出した（変更なし・\$0）** / $(basename "$OUT")"
