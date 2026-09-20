#!/bin/bash
# **`MAX_PICKS_PER_FIRE` を 4 → 6 にする。承認済み。月額 約 $0.63 → 約 $0.95（推定）。**
#
# ## なぜ（x99 で分かったこと）
#
# 9/08 → 9/20 で増えた 48 人 の内訳は、
#
#   こちらが先にフォローした人        27 人  (56%)
#   **こちらは何もしていないのに来た人  21 人  (44%)**
#
# **21 人 は、こちらが一切フォローせずに向こうから来ている。**
# 返信がタイムラインに出ていることの効果で、**フォロー施策ではない。**
#
# `comment-orchestrator` は「フォロー返し 21.9%」で評価していたが、
# **直接の返しは 2 人 だけ。本当の価値は 21 人 を連れてきた露出のほう。**
# ここは一度も測っていなかった。
#
# ## 費用（最上位ルール 2-B）
#
#   いま   1 件 $0.003 × 1 日 4 回 × 4 picks  → 実測 **$0.021/日**・**約 $0.63/月**
#   あと   1 件 $0.003 × 1 日 4 回 × 6 picks  → **推定 $0.032/日**・**約 $0.95/月**
#
# **推定の前提**: 1 件あたりの実測 $0.003（2026-09-06・全文生成）と、
# 通過率が実績どおりであること。入口で弾かれた分は $0 なので、実額は下がる側に振れる。
# **上限（$0.048/日・$1.44/月）は安全弁であって実績ではない。**
#
# ## 上限に当たらないか
#
#   6 picks × 1 日 4 回 = **24 件/日**
#   `REPLY_FOLLOW_DAILY_CAP` は **30** なので、当たらない。
#
# ## 危ないこと（2026-08-15 の再発を避ける）
#
# **`MAX_PICKS_PER_FIRE=8`（32 件/日）で動いていて差し戻された前例がある。**
# **6 はその手前。** 8 には戻さない。
#
# ## 証拠の取り方（最上位ルール 13）
#
#   変わった  : PlistBuddy で**読み直して 6 になっているか**
#   効いた    : bootout → bootstrap 後に **launchctl list に出るか**
#   **`rc=0` は証拠にしない。**
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
LABEL="ai.openclaw.comment-warmup"
P="$LA/$LABEL.plist"
OUT="${OPS_REPORT_DIR:-/tmp}/max-picks-6.md"
UID_NUM="$(id -u)"
STAMP="$(date '+%Y%m%d-%H%M%S')"

pb() { /usr/libexec/PlistBuddy -c "$1" "$P" 2>/dev/null; }
loaded_p() { launchctl list 2>/dev/null | awk -v l="$LABEL" '$3==l {f=1} END {exit !f}'; }

{
echo "# \`MAX_PICKS_PER_FIRE\` を 4 → 6 にする"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x99 で、増えた 48 人 のうち **21 人（44%）が「こちらが一切フォローせずに来た人」**"
echo "> だと分かった。**返信が人目に触れていることの効果**で、フォロー施策ではない。"
echo ">"
echo "> \`comment-orchestrator\` の直接のフォロー返しは **2 人 だけ**。"
echo "> **本当の価値は 21 人 を連れてきた露出のほうにある。**"
echo
echo "**利用者の承認済み。** 月額 約 \$0.63 → 約 \$0.95（推定）。"

# ═══════════ 0. 変える前 ═══════════
echo
echo "## 0. 変える前"
echo
echo '```'
GO=1
if [ ! -f "$P" ]; then
  echo "  **plist が無い: $P**"
  GO=0
else
  echo "  plist 更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  echo
  echo "  --- EnvironmentVariables ---"
  pb 'Print :EnvironmentVariables' | head -16 | sed 's/^/    /'
  echo
  CUR="$(pb 'Print :EnvironmentVariables:MAX_PICKS_PER_FIRE')"
  CAP="$(pb 'Print :EnvironmentVariables:REPLY_FOLLOW_DAILY_CAP')"
  echo "    いまの MAX_PICKS_PER_FIRE      : ${CUR:-（無し）}"
  echo "    いまの REPLY_FOLLOW_DAILY_CAP  : ${CAP:-（無し）}"
  echo
  # **想定と違う値なら触らない。** 知らないうちに誰かが変えている可能性がある
  if [ "${CUR:-}" != "4" ]; then
    echo "    **4 ではない。想定と違うので触らない。**"
    echo "    4 から 6 にする前提で承認を得ているため、別の値から動かすのは越権。"
    GO=0
  fi
  if [ -n "${CAP:-}" ] && [ "$CAP" -lt 24 ] 2>/dev/null; then
    echo "    **警告: 6 picks × 1 日 4 回 = 24 件/日 が CAP($CAP) を超える。**"
    echo "    そのまま上げると CAP 側で頭打ちになり、費用だけ増えて効果が出ない。"
    GO=0
  fi
fi
echo '```'

# ═══════════ 1. 変える ═══════════
echo
echo "## 1. 変える（**退避してから**）"
echo
echo '```'
if [ "$GO" = "0" ]; then
  echo "  **前提が揃っていないので変えない。**"
else
  cp "$P" "$P.bak-$STAMP" 2>/dev/null && echo "  退避: $(basename "$P").bak-$STAMP"
  pb "Set :EnvironmentVariables:MAX_PICKS_PER_FIRE 6" >/dev/null 2>&1
  echo "  Set を打った（**rc は証拠にならない**）"
  echo
  echo "  --- **証拠: 読み直す** ---"
  NEW="$(pb 'Print :EnvironmentVariables:MAX_PICKS_PER_FIRE')"
  if [ "${NEW:-}" = "6" ]; then
    echo "    **6 になった**"
  else
    echo "    **6 になっていない（いま「${NEW:-無し}」）。戻す。**"
    cp "$P.bak-$STAMP" "$P" 2>/dev/null && echo "    退避から戻した"
    GO=0
  fi
  echo
  echo "  --- plist が壊れていないか ---"
  if plutil -lint "$P" >/dev/null 2>&1; then
    echo "    plutil -lint: **OK**"
  else
    echo "    **plist が壊れた。戻す。**"
    cp "$P.bak-$STAMP" "$P" 2>/dev/null && echo "    退避から戻した"
    GO=0
  fi
fi
echo '```'

# ═══════════ 2. 効かせる ═══════════
echo
echo "## 2. 効かせる（**載せ直さないと古い値のまま**）"
echo
echo '```'
if [ "$GO" = "0" ]; then
  echo "  **変えていないので載せ直さない。**"
else
  echo "  bootout → bootstrap"
  launchctl bootout "gui/$UID_NUM/$LABEL" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$UID_NUM" "$P" 2>&1 | head -3 | sed 's/^/    /'
  echo
  echo "  --- **証拠: launchctl list に出るか** ---"
  ROW="$(launchctl list 2>/dev/null | awk -v l="$LABEL" '$3==l {print "PID=" $1 "  最後の終了コード=" $2}')"
  if [ -n "$ROW" ]; then
    echo "    **載っている** — $ROW"
  else
    echo "    **載っていない。** 退避から戻して載せ直す。"
    cp "$P.bak-$STAMP" "$P" 2>/dev/null
    launchctl bootstrap "gui/$UID_NUM" "$P" >/dev/null 2>&1 || true
    launchctl list 2>/dev/null | awk -v l="$LABEL" '$3==l {print "    戻したあと: PID=" $1 "  終了コード=" $2}'
  fi
fi
echo '```'

# ═══════════ 3. 次の発火 ═══════════
echo
echo "## 3. いつから効くか"
echo
echo '```'
if [ -f "$P" ]; then
  pb 'Print :StartCalendarInterval' | tr -d '\n' | sed -E 's/  +/ /g' | cut -c1-200 | sed 's/^/    予定: /'
  echo
fi
echo "    **次の定時から 6 件 になる。** いま走らせると二重に打つので kickstart はしない。"
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用（**増額である。伏せない**）"
echo
echo "| | いま（実測） | あと（推定） |"
echo "| --- | --- | --- |"
echo "| 1 回あたり | **\$0.003** | **\$0.003**（変わらない） |"
echo "| 1 日あたり | **\$0.021** | **約 \$0.032** |"
echo "| 1 か月あたり | **約 \$0.63** | **約 \$0.95** |"
echo
echo "**推定の前提**: 1 件 \$0.003（2026-09-06 の実測・全文生成）× 1 日 4 回 × 6 picks。"
echo "通過率は実績どおりとし、**入口で弾かれた分は \$0** なので実額は下がる側に振れる。"
echo
echo "**上限（\$0.048/日・\$1.44/月）は安全弁であって実績ではない。**"
echo "**8 picks（32 件/日）には戻さない** — 2026-08-15 に差し戻された水準。"
} > "$OUT" 2>&1

echo "MAX_PICKS 4→6 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
