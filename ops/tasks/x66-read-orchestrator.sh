#!/bin/bash
# **`comment-orchestrator.sh` の実物を読む。直さない。費用 $0。**
#
# ## x65 で 2 つ 分かった（2026-09-13 20:33 実測）
#
# ### 1. いちばん返りのいい供給元に、x64 が当たっていない
#
#   comment-orchestrator  135 件 / 返し **21.5%**   ← いちばん良い。**x64 未適用**
#   competitor-follower   168 件 / 返し 11.9%       ← x64 適用済み
#   hashtag-follow         39 件 / 返し 15.4%       ← x64 適用済み
#
# **返りのいい供給元だけフォロワー数を記録していない。** 直す場所を実物で見る。
#
# ### 2. 広告の判定が「選んだ後」に走っている
#
#   picked 16 件 → 広告 4 件・話題外 3 件 が **生成の直前に落ちる**
#
# 落ちること自体は正しい（$0）。だが **picked の枠を 7 つ 空振りさせている。**
# 選ぶループ（62 行目あたり）で同じ判定をすれば、枠が全部 実弾になる。
#
# ## 読むところ
#
#   - 候補を選ぶループ（`picked.length >= $MAX_PICKS` の前後）
#   - 返信きっかけのフォローを記録している箇所
#   - 入口判定をしている実体（`ng-filter-candidates.cjs` / `asuka-reply.cjs` のどちら側か）
#   - plist が渡している環境変数（`FORCE_RUN` / 各 cap の実値）
#
# ## やらないこと
#
# **書き換えない。投稿しない。フォローしない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（ファイルを読むだけ・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/read-orchestrator.md"
ORCH="$S/comment-orchestrator.sh"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# \`comment-orchestrator.sh\` の実物"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **いちばん返りのいい供給元（21.5%）に x64 が当たっていない。**"
echo "> **広告の判定が「選んだ後」に走っていて、picked の枠を 7 つ 空振りさせている。**"
echo
echo "**読むだけ。直さない。**"

# ═══════════ 1. 全文 ═══════════
echo
echo "## 1. 全文"
echo
echo '```'
if [ ! -f "$ORCH" ]; then
  echo "  **$ORCH が無い。**"
  ls -1 "$S" 2>/dev/null | grep -iE 'orchestr|warmup' | sed 's/^/    候補: /'
else
  echo "  $(wc -l < "$ORCH" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$ORCH" 2>/dev/null)"
fi
echo '```'
if [ -f "$ORCH" ]; then
  echo
  echo '```bash'
  cat "$ORCH" | clean
  echo '```'
fi

# ═══════════ 2. 入口判定の実体 ═══════════
echo
echo "## 2. 広告を弾いているのは誰か（**入口判定の実体**）"
echo
echo '```'
for f in ng-filter-candidates.cjs asuka-reply.cjs trend-detect.js; do
  for P in "$W/lib/$f" "$S/$f"; do
    [ -f "$P" ] || continue
    echo "  ══ $(basename "$P")（$(wc -l < "$P" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)）"
    echo "    $P"
    echo "    --- 「LLM を呼ばずに見送る」を出している箇所 ---"
    grep -nE 'LLM を呼ばずに見送る|target_skip|campaign_words|hashtags|domains' "$P" 2>/dev/null \
      | head -10 | cut -c1-190 | sed 's/^/      /' | clean
    echo
    break
  done
done
echo "  --- 判定の materialize（呼べる形か） ---"
grep -rnE 'module.exports|exports\.' "$W/lib/ng-filter-candidates.cjs" 2>/dev/null \
  | head -6 | cut -c1-190 | sed 's/^/    /' | clean
echo '```'
echo
echo "**選ぶループから呼べる形（\`module.exports\`）になっているかが分かれ目。**"
echo "なっていれば、選ぶ前に同じ判定を挟むだけで済む。"

# ═══════════ 3. plist が渡している環境変数 ═══════════
echo
echo "## 3. plist の環境変数（**上限の実値**）"
echo
echo '```'
for lbl in ai.openclaw.comment-warmup ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  P="$LA/$lbl.plist"; [ -f "$P" ] || { echo "  $lbl: **plist が無い**"; continue; }
  echo "  ══ $lbl"
  awk '/EnvironmentVariables/,/<\/dict>/' "$P" 2>/dev/null \
    | grep -oE '<key>[A-Za-z_]+</key>|<string>[^<]*</string>' \
    | sed 's/<[^>]*>//g' | paste - - 2>/dev/null | head -12 | sed 's/^/    /' | clean
  echo
done
echo '```'
echo
echo "**x65 のログでは競合刈り取りが \`1/30 OK\` と出ていた。**"
echo "既定は 10 なので、**plist が 30 を渡している**はず。ここで裏を取る。"
echo "日曜（\`getDay()===0\`）はスキップする実装なのに走っていたので、"
echo "**\`FORCE_RUN\` が渡っているかどうか**もここで分かる。"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**ファイルを読むだけ。LLM を呼ばない。フォローも投稿もしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**この後に控えている変更の費用**（判断材料として先に置く）"
echo
echo "| | 1 回あたり | 1 日あたり | 1 か月あたり |"
echo "| --- | --- | --- | --- |"
echo "| いまの実績（生成 9 件/日） | \$0.003 | **\$0.027** | **約 \$0.81** |"
echo "| 選ぶ前に広告を弾いた場合（生成 16 件/日・**上限に張り付く**） | \$0.003 | **\$0.048** | **\$1.44** |"
echo
echo "**増加は月 +\$0.63。** 単価は実測（2026-09-06・全文生成）、件数は 2026-09-13 のログ実測。"
} > "$OUT" 2>&1

echo "orchestrator の実物 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
