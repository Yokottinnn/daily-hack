#!/bin/bash
# **未ロード 60 件 を「畳むもの」と「戻すもの」に仕分ける材料を出す。測るだけ。費用 $0。**
#
# ## なぜ
#
# `heartbeat.json` が読めるようになった結果、`unloaded_count` が **60** だと分かった。
# `ops-watchdog.yml` は **0 件より多ければ鳴る**設計なので、このままだと
# **30 分ごとに鳴り続け、本当の異常がその中に埋もれる。**
#
# しかも 60 件 の中に、**いま困っているジョブ本体**が入っている。
#
#   ai.openclaw.follower-snapshot     → フォロワー記録が **9/8 で止まっている**原因
#   ai.openclaw.grok-trending-daily   → pipeline-heartbeat の **CRIT（grok_trending_fire）**
#   ai.openclaw.trend-daily           → **WARN（trend_posts_24h = 0）**
#   ai.openclaw.unfollow-cleanup-*    → **WARN（unfollow_cleanup_morning_fire）**
#   ai.openclaw.x-loop-guardian       → **これ自体が載っていない**（9/12 に作った番人）
#
# ## 仕分けの基準（**推測で決めない。実物で決める**）
#
#   a) **実行ファイルが在るか**。消えていれば、もう畳んでよい
#   b) **最後に動いた形跡**（ログの更新日）。何か月も無ければ畳む候補
#   c) **意図的に止めたもの**（`poll-approvals` は 2026-08-15 の事故で止めたまま）
#
# `.plist` のまま載っていないのは「意図せず落ちた」印。
# **畳むなら `.disabled` にリネームする**のがこのリポジトリの作法。
#
# ## やらないこと
#
# **リネームしない。載せ直さない。消さない。LLM を呼ばない（$0）。**
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
W="$HOME/.openclaw/workspace"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/classify-unloaded.md"

hide() {
  sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g' \
         -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){1,}/<伏せ・ハンドル列>/g'
}
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(xox[bp]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

# **いま載っているものを 1 回だけ取る。** 60 回 launchctl を呼ばない
LOADED="$(launchctl list 2>/dev/null | awk '{print $3}')"

{
echo "# 未ロード 60 件 の仕分け材料"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`unloaded_count\` が **60**。\`ops-watchdog\` は 0 件より多ければ鳴るので、"
echo "> このままだと **30 分ごとに鳴り続け、本当の異常が埋もれる。**"
echo ">"
echo "> しかも 60 件 の中に、**いま困っているジョブ本体**が入っている。"
echo
echo "**測るだけ。リネームも載せ直しもしない。**"

# ═══════════ 1. 全件の表 ═══════════
echo
echo "## 1. 全件（**実行ファイルの有無 ＋ 最後に動いた形跡**）"
echo
echo '```'
printf '  %-38s %-4s %-10s %-13s %s\n' "ラベル" "実体" "予定" "最後のログ" "実行するもの"
echo "  ------------------------------------------------------------------------------------------"
for P in "$LA"/ai.openclaw.*.plist; do
  [ -f "$P" ] || continue
  LABEL="$(basename "$P" .plist)"
  # 載っているものは対象外
  printf '%s\n' "$LOADED" | grep -qxF "$LABEL" && continue
  SHORT="${LABEL#ai.openclaw.}"

  # 実行するもの（ProgramArguments の中で、最初に見つかる実在しうるパス）
  PROG="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$P" 2>/dev/null \
          | grep -oE '/[A-Za-z0-9_./-]+' | grep -vE '^/bin/|^/usr/bin/|^/usr/local/bin/node$' | head -1)"
  if [ -z "$PROG" ]; then
    PROG="$(/usr/libexec/PlistBuddy -c 'Print :Program' "$P" 2>/dev/null | head -1)"
  fi
  if [ -n "$PROG" ] && [ -e "$PROG" ]; then EXISTS="在"; elif [ -n "$PROG" ]; then EXISTS="**無**"; else EXISTS="?"; fi

  # 予定の形
  if /usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$P" >/dev/null 2>&1; then
    SCHED="定時"
  elif /usr/libexec/PlistBuddy -c 'Print :StartInterval' "$P" >/dev/null 2>&1; then
    SCHED="$(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$P" 2>/dev/null)秒"
  else
    SCHED="起動時のみ"
  fi

  # 最後に動いた形跡（ログの更新日）
  LOGDATE="(ログ無し)"
  for c in "$L/$SHORT.log" "$L/$SHORT.out" "$L/$SHORT-err.log" "$L/$SHORT.err"; do
    [ -f "$c" ] || continue
    D="$(stat -f '%Sm' -t '%Y-%m-%d' "$c" 2>/dev/null)"
    [ -n "$D" ] && LOGDATE="$D" && break
  done

  printf '  %-38s %-4s %-10s %-13s %s\n' "$SHORT" "$EXISTS" "$SCHED" "$LOGDATE" "$(basename "${PROG:-?}")"
done
echo '```'
echo
echo "**\`実体\` が \`**無**\` のものは、指しているファイルがもう無い。畳んでよい候補。**"
echo "**\`最後のログ\` が何か月も前のものも同じ。** ただし \`起動時のみ\` のものは"
echo "ログを残さないことがあるので、それだけで決めない。"

# ═══════════ 2. いま困っている 6 本 ═══════════
echo
echo "## 2. **いま困っている 6 本**を個別に見る"
echo
echo '```'
for SHORT in follower-snapshot grok-trending-daily trend-daily \
             unfollow-cleanup-morning unfollow-cleanup-evening x-loop-guardian; do
  P="$LA/ai.openclaw.$SHORT.plist"
  echo "  ══ $SHORT"
  if [ ! -f "$P" ]; then
    echo "    **plist が無い。**"
    echo
    continue
  fi
  echo "    plist 更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  /usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$P" 2>/dev/null \
    | grep -oE '/[A-Za-z0-9_./-]+' | head -3 | while IFS= read -r p || [ -n "$p" ]; do
    [ -n "$p" ] || continue
    if [ -e "$p" ]; then echo "    在  $p"; else echo "    **無**  $p"; fi
  done
  /usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$P" 2>/dev/null \
    | tr -d '\n' | sed -E 's/  +/ /g' | cut -c1-150 | sed 's/^/    予定: /'
  echo
  for c in "$L/$SHORT.log" "$L/$SHORT.out"; do
    [ -f "$c" ] || continue
    echo "    --- $(basename "$c")（$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$c" 2>/dev/null)）末尾 3 行"
    tail -3 "$c" 2>/dev/null | cut -c1-165 | sed 's/^/      /' | clean
  done
  echo
done
echo '```'

# ═══════════ 3. フォロワー記録が止まった日 ═══════════
echo
echo "## 3. フォロワー記録は**いつ止まったか**"
echo
echo '```'
FS="$L/follower-snapshot.log"
if [ -f "$FS" ]; then
  echo "  $FS"
  echo "  大きさ $(wc -c < "$FS" | tr -d ' ') bytes / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$FS" 2>/dev/null)"
  echo
  echo "  --- 日付ごとの最後の値（heartbeat と同じ取り方）---"
  grep -oE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][^}]*"count_today":[0-9]+' "$FS" 2>/dev/null \
    | sed -E 's/^([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]).*"count_today":([0-9]+)$/\1 \2/' \
    | awk '{ last[$1] = $2 } END { for (d in last) print d, last[d] }' \
    | sort | tail -12 | sed 's/^/    /'
  echo
  echo "  --- 末尾 5 行（**止まり方を見る**）---"
  tail -5 "$FS" 2>/dev/null | cut -c1-165 | sed 's/^/    /' | clean
else
  echo "  **$FS が無い。** logs/ の候補:"
  ls -1 "$L" 2>/dev/null | grep -i follower | head -8 | sed 's/^/    /'
fi
echo '```'
echo
echo "**\`heartbeat\` の \`followers.now\` はこのログの最後の日の値。**"
echo "止まっていれば、**古い数字が「いま」として出続ける。**"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**plist とログを読むだけ。LLM を呼ばない。リネームも載せ直しもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**畳む・載せ直す場合も \$0**（launchd の操作のみ）。"
echo "ただし \`grok-trending-daily\` と \`trend-daily\` は**戻すと LLM を呼ぶ**ので、"
echo "戻す前に 1 回あたり・1 日あたり・1 か月あたりを出して確認を取る（最上位ルール 2-B）。"
echo
echo "いま動いている返信ループの実額は、pipeline-heartbeat の実測で **\$0.021/日**"
echo "（1 か月 約 \$0.63）。上限は \$0.048/日・\$1.44/月 で、**これは実績ではなく安全弁。**"
} > "$OUT" 2>&1

echo "未ロード 60 件 の仕分け / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
