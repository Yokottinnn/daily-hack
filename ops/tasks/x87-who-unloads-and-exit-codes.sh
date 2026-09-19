#!/bin/bash
# **誰がジョブを外しているか ＋ 終了コード 5 と 2 の中身。測るだけ。費用 $0。**
#
# ## 1 つ目: 外している主体を特定する
#
# x86 で**原因の候補が 3 つ 消えた。**
#
#   launchctl print-disabled : 12 本 すべて **enabled**
#   plist の Disabled キー   : 12 本 すべて **(無し)**
#   置き場所                 : 12 本 すべて `~/Library/LaunchAgents`
#
# **ログイン時に載る条件は満たしている。** なのに 2 回（9/12・9/20）とも
# `ai.openclaw.*` がほぼ全滅し、**`com.dailyhack.*` は無傷で残った。**
#
# ログインしていなければ両方 載らないはずなので、**誰かが `ai.openclaw.*` だけを
# 外している**線が濃い。**2 回 とも tab-guard だけが生き残っている**のも引っかかる。
#
# **外している主体が tab-guard なら、載せ直しても また外される。**
# 自動で載せ直す仕組みを入れる前に、ここを確かめる（ルール 15）。
#
# ## 2 つ目: 終了コード 5 と 2
#
#   comment-warmup     最後の終了コード **5**
#   pipeline-heartbeat 最後の終了コード **2**
#   tab-guard          最後の終了コード **1**
#
# **載っていることと、走って落ちていることは別の問題。** 混ぜない。
#
# ## やらないこと
#
# **直さない。外さない。載せ直さない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/who-unloads.md"

hide() {
  sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g' \
         -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){1,}/<伏せ・ハンドル列>/g'
}
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 誰がジョブを外しているか ＋ 終了コード 5 と 2"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x86 で候補が 3 つ 消えた（disable されていない／plist 正常／置き場所も正しい）。"
echo "> **2 回 とも \`ai.openclaw.*\` だけが全滅し、\`com.dailyhack.*\` は無傷。**"
echo "> **2 回 とも tab-guard だけが生き残っている。**"
echo
echo "**測るだけ。載せ直しの仕組みは、ここが分かってから入れる。**"

# ═══════════ 1. 外す操作を書いているのは誰か ═══════════
echo
echo "## 1. \`bootout\` / \`unload\` を書いているスクリプト（**全部 洗う**）"
echo
echo '```'
echo "  --- scripts/ で launchctl を外す操作を書いている箇所 ---"
grep -rln -E 'launchctl[[:space:]]+(bootout|unload|remove|disable)' "$S" 2>/dev/null \
  | grep -v '\.bak' | head -12 | while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  echo "    ══ $(basename "$f")（$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)）"
  grep -n -E 'launchctl[[:space:]]+(bootout|unload|remove|disable)' "$f" 2>/dev/null \
    | head -5 | cut -c1-175 | sed 's/^/      /' | clean
done
echo
echo "  --- 見つからなければここは空。その場合は別の主体を疑う ---"
echo '```'

# ═══════════ 2. tab-guard の実物 ═══════════
echo
echo "## 2. tab-guard は何をしているか"
echo
echo '```'
TG=""
for c in tab-guard.js tab-guard.cjs tab-guard.sh; do
  [ -f "$S/$c" ] && TG="$S/$c" && break
done
if [ -z "$TG" ]; then
  echo "  **tab-guard の実体が scripts/ に無い。**"
  ls -1 "$S" 2>/dev/null | grep -i 'tab' | sed 's/^/    候補: /'
  echo
  echo "  --- plist が何を実行しているか ---"
  P="$HOME/Library/LaunchAgents/ai.openclaw.tab-guard.plist"
  [ -f "$P" ] && /usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$P" 2>/dev/null | head -8 | sed 's/^/    /'
else
  echo "  $TG（$(wc -l < "$TG" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$TG" 2>/dev/null)）"
  echo
  echo "  --- 止める・外す系の操作 ---"
  grep -n -E 'launchctl|bootout|unload|halt|停止|止め|kill|disable' "$TG" 2>/dev/null \
    | head -20 | cut -c1-185 | sed 's/^/    /' | clean
  echo
  echo "  --- ループの名前を列挙している箇所（対象を持っているか） ---"
  grep -n -E 'ai\.openclaw|comment-warmup|hashtag-follow|JOBS|LOOPS' "$TG" 2>/dev/null \
    | head -12 | cut -c1-185 | sed 's/^/    /' | clean
fi
echo '```'
echo
echo "**tab-guard が \`ai.openclaw.*\` の名前を持っていて \`bootout\` を呼ぶなら、それが犯人。**"
echo "持っていなければ、**載せ直しの仕組みを入れても安全**という根拠になる。"

# ═══════════ 3. tab-guard のログ ═══════════
echo
echo "## 3. tab-guard のログ（**外した記録が無いか**）"
echo
echo '```'
for f in tab-guard.log tab-guard.out tab-guard-err.log; do
  P="$L/$f"; [ -f "$P" ] || { echo "  $f: **無い**"; continue; }
  printf '  %-22s %9s bytes / 最終更新 %s\n' "$f" "$(wc -c < "$P" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
done
echo
echo "  --- 9/19〜9/20 の行（止まった前後） ---"
for f in tab-guard.log tab-guard.out tab-guard-err.log; do
  P="$L/$f"; [ -f "$P" ] || continue
  R="$(grep -E '2026-09-(19|20)' "$P" 2>/dev/null | tail -12)"
  [ -n "$R" ] || continue
  echo "    ══ $f"
  printf '%s\n' "$R" | cut -c1-185 | sed 's/^/      /' | clean
done
echo
echo "  --- 外した・止めたと書いている行（全期間） ---"
grep -hE 'bootout|unload|外し|停止|halt' "$L"/tab-guard*.log "$L"/tab-guard*.out 2>/dev/null \
  | tail -10 | cut -c1-185 | sed 's/^/    /' | clean
echo '```'

# ═══════════ 4. 終了コード 5 と 2 ═══════════
echo
echo "## 4. 終了コード 5 と 2 の中身"
echo
echo '```'
echo "  --- comment-warmup（終了コード 5） ---"
for f in comment-warmup-err.log comment-warmup.out comment-warmup.log; do
  P="$L/$f"; [ -f "$P" ] || continue
  echo "    ══ $f（最終更新 $(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)）"
  tail -8 "$P" 2>/dev/null | cut -c1-185 | sed 's/^/      /' | clean
  echo
done
echo "  --- pipeline-heartbeat（終了コード 2） ---"
for f in pipeline-heartbeat.err pipeline-heartbeat.out pipeline-heartbeat.log; do
  P="$L/$f"; [ -f "$P" ] || continue
  echo "    ══ $f（最終更新 $(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)）"
  tail -8 "$P" 2>/dev/null | cut -c1-185 | sed 's/^/      /' | clean
  echo
done
echo '```'
echo
echo "**終了コードは「最後に走ったときの結果」。** 載っているかとは別物。"
echo "毎回 落ちているなら、載っていても仕事をしていない。"

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**ソースとログを読むだけ。LLM を呼ばない。外しも載せもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44"
echo "（\`MAX_PICKS\` は 4 のまま）。フォロー・アンフォロー系は \$0（DOM 操作のみ）。"
} > "$OUT" 2>&1

echo "外している主体と終了コード / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
