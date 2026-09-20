#!/bin/bash
# **競合フォロワー追跡の「種アカウント」設定がどこにあるかを読む。直さない。費用 $0。**
#
# ## なぜ（x93 で効き目が 6 倍 違うと分かった）
#
#   competitor-follower:himawari56757   mature 50   返り率 **26.0%**
#   competitor-follower:haiji_doctor    mature 24   返り率   20.8%
#   competitor-follower:okamiler_pn     mature 22   返り率   18.2%
#   competitor-follower:tokufree3       mature 37   返り率   16.2%
#   competitor-follower:POIKATSU_OTAKE  mature 30   返り率   10.0%
#   competitor-follower:money_yossy     mature 35   返り率    8.6%
#   competitor-follower:ukk_hx          mature 24   返り率  **4.2%**
#
# **下位 3 つ（ukk_hx / money_yossy / POIKATSU_OTAKE）で 99 件 フォローして、
# 返ってきたのは 7 人。** 同じ 99 件 を himawari56757 並み（26%）に回せば
# **約 26 人**で、差は **+19 人**。目標まで 36 人 なので、ここだけで半分 埋まる。
#
# **mature はどれも 22 件 以上**なので、1 件の増減では動かない数字。
#
# ## だから先に設定の実物を読む
#
# **種アカウントの一覧がどこにあり、どう順番に回しているか**を確かめる。
# 消す前に、**回し方（1 回 1 種か、全部 まとめてか）**を知らないと外し方を誤る。
# **推測でファイルを書き換えない**（最上位ルール 14）。
#
# ## やらないこと
#
# **消さない。書き換えない。フォローしない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/competitor-seeds.md"

hide() { sed -E -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){2,}/<伏せ・ハンドル列>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 競合フォロワー追跡の種アカウント設定"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x93 で、**種アカウントによって返り率が 6 倍 違う**と分かった。"
echo "> 下位 3 つ で 99 件 フォローして返りは 7 人。上位並みなら約 26 人で、**差は +19 人。**"
echo ">"
echo "> **消す前に、一覧の場所と回し方を実物で確かめる。**"
echo
echo "**読むだけ。書き換えない。**"

# ═══════════ 1. plist が何を実行しているか ═══════════
echo
echo "## 1. \`competitor-follower-follow\` は何を実行しているか"
echo
echo '```'
P="$LA/ai.openclaw.competitor-follower-follow.plist"
if [ -f "$P" ]; then
  echo "  plist 更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  echo
  echo "  --- ProgramArguments ---"
  /usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$P" 2>/dev/null | head -10 | sed 's/^/    /'
  echo
  echo "  --- EnvironmentVariables（CAP など）---"
  /usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables' "$P" 2>/dev/null \
    | head -14 | sed 's/^/    /' | clean
  echo
  echo "  --- 予定 ---"
  /usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$P" 2>/dev/null \
    | tr -d '\n' | sed -E 's/  +/ /g' | cut -c1-180 | sed 's/^/    /'
  echo
else
  echo "  **plist が無い。**"
fi
echo '```'

# ═══════════ 2. 種の一覧がどこにあるか ═══════════
echo
echo "## 2. **種アカウントの一覧はどこにあるか**"
echo
echo '```'
echo "  --- data/ の中で competitor / seed を名前に持つもの ---"
ls -1 "$D" 2>/dev/null | grep -i -E 'competitor|seed|target' | head -12 | while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  printf '    %-46s %s\n' "$f" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$D/$f" 2>/dev/null)"
done
echo
echo "  --- 実際に知っている種の名前でファイルを探す ---"
for h in himawari56757 tokufree3 money_yossy POIKATSU_OTAKE ukk_hx haiji_doctor okamiler_pn; do
  HIT="$(grep -rl -F "$h" "$D" "$S" 2>/dev/null | grep -v '\.bak' | grep -v 'reply-followers' | head -3 | tr '\n' ' ')"
  printf '    %-22s %s\n' "$h" "${HIT:-（見つからない）}"
done
echo '```'
echo
echo "**同じファイルが 7 件 すべてに出てくるなら、そこが一覧。**"
echo "散らばっているなら、回し方も別の場所にある。"

# ═══════════ 3. 一覧の中身 ═══════════
echo
echo "## 3. 一覧の中身と、**回し方**"
echo
echo '```'
SEEDF="$(grep -rl -F 'himawari56757' "$D" "$S" 2>/dev/null \
         | grep -v '\.bak' | grep -v 'reply-followers' | head -1)"
if [ -z "$SEEDF" ]; then
  echo "  **himawari56757 を含むファイルが見つからない。**"
  echo "  種は plist の環境変数か、スクリプト内に直書きされている可能性がある。"
  echo
  echo "  --- scripts/ で competitor を扱っていそうなもの ---"
  ls -1 "$S" 2>/dev/null | grep -i -E 'competitor|follow' | head -10 | sed 's/^/    /'
else
  echo "  一覧: $SEEDF"
  echo "  $(wc -l < "$SEEDF" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$SEEDF" 2>/dev/null)"
  echo
  case "$SEEDF" in
    *.json)
      echo "  --- 構造（キーと件数）---"
      /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) { console.log("    **読めない: " + e.message.slice(0,120) + "**"); process.exit(0); }
const show = (v, indent) => {
  if (Array.isArray(v)) return "配列 " + v.length + " 件";
  if (v && typeof v === "object") return "オブジェクト " + Object.keys(v).length + " キー";
  return JSON.stringify(v);
};
if (Array.isArray(j)) {
  console.log("    最上位: 配列 " + j.length + " 件");
  for (const x of j.slice(0, 12)) console.log("      " + JSON.stringify(x).slice(0, 150));
} else {
  for (const [k, v] of Object.entries(j)) console.log("    " + String(k).padEnd(24) + " " + show(v));
  for (const [k, v] of Object.entries(j)) {
    if (!Array.isArray(v)) continue;
    console.log("");
    console.log("    --- " + k + " の中身 ---");
    for (const x of v.slice(0, 14)) console.log("      " + JSON.stringify(x).slice(0, 150));
  }
}
' "$SEEDF" 2>&1 | clean
      ;;
    *)
      echo "  --- 先頭 30 行 ---"
      head -30 "$SEEDF" 2>/dev/null | cut -c1-175 | sed 's/^/    /' | clean
      ;;
  esac
fi
echo
echo "  --- 「次にどれを使うか」を決めている箇所 ---"
grep -rn -E 'rotat|next_seed|seed_index|cursor|shift\(\)|\[i *% ' "$S" 2>/dev/null \
  | grep -i -E 'competitor|follow' | grep -v '\.bak' | head -8 | cut -c1-175 | sed 's/^/    /' | clean
echo '```'

# ═══════════ 4. hashtag 側（伸びしろの確認） ═══════════
echo
echo "## 4. \`hashtag-follow\` は上限の**何 % しか使っていないか**"
echo
echo '```'
PH="$LA/ai.openclaw.hashtag-follow.plist"
if [ -f "$PH" ]; then
  echo "  --- EnvironmentVariables ---"
  /usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables' "$PH" 2>/dev/null \
    | head -14 | sed 's/^/    /' | clean
  echo
  echo "  --- 直近のログ（何件 拾って何件 打ったか）---"
  tail -12 "$W/logs/hashtag-follow.log" 2>/dev/null | cut -c1-175 | sed 's/^/    /' | clean
else
  echo "  **plist が無い。**"
fi
echo '```'
echo
echo "**x93 の実測では hashtag-follow は 1 日 最大 3 件**（上限 90）。"
echo "**上限ではなく候補の数で止まっている。** 上限を上げても増えない。"

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**設定ファイルとログを読むだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**種を入れ替える場合も \$0。** \`competitor-follower-follow\` は DOM 操作だけで"
echo "LLM を呼ばないため、**フォロー数を変えても API 費用は動かない。**"
echo "いまの実測は 1 回 \$0.003 ／ 1 日 \$0.021 ／ 1 か月 約 \$0.63（返信ループのぶん）。"
} > "$OUT" 2>&1

echo "競合の種アカウント設定 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
