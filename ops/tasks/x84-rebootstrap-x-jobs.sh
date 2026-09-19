#!/bin/bash
# **再起動で外れた X のループを載せ直す。費用 $0（LLM 不使用）。**
#
# ## なぜ（2026-09-20 00:54 JST の heartbeat）
#
#   x_jobs: loaded 0 / expected 8 / halted true
#   missing: comment-warmup, competitor-follower-follow, hashtag-follow,
#            badge-followback, reply-followback-check, reply-followers-cleanup,
#            incoming-reply-watcher, pipeline-heartbeat
#   載っているのは 7 本（tab-guard / listener / ops-heartbeat / ops-poller /
#                        rc-keeper / weekly-blog-report / openclaw.heartbeat）
#   last_reply: 2026-09-19 05:06 JST（19 時間 前・stale）
#   auth: ok  cdp: healthy
#
# **Mac が 11:21 JST に落ち、00:20 JST に戻ったが、LaunchAgents が載り直していない。**
# 認証も CDP も生きているので、**載せれば動く。**
#
# **番人（daily-supervisor）も外れている**ため、放っておいても自動では戻らない。
#
# ## やること
#
# 本来 載っているべき 12 本 のうち、**載っていないものだけ** `bootstrap` する。
#
#   badge-followback  caffeinate  comment-warmup  competitor-follower-follow
#   daily-supervisor  hashtag-follow  incoming-reply-watcher  mutual-prune
#   pipeline-heartbeat  reply-followback-check  reply-followers-cleanup  tab-guard
#
# ## 守ること（ルール 13）
#
#   - `load` ではなく **`bootout` → `bootstrap`**（macOS で `load` は deprecated）
#   - **`launchctl list` は 1 回だけ取る。** 1 本ずつ呼ぶと取りこぼす
#   - **`rc=0` を証拠にしない。** 載せた後にもう一度 一覧を取って照合する
#   - plist が無いものは**作らない**。名前を挙げて報告する
#
# ## やらないこと
#
# **kickstart しない**（いま走らせると LLM 代が発生する。承認を取ってから別途）。
# **plist の中身を書き換えない。設定も上限も触らない。**
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/rebootstrap-x-jobs.md"
UID_NUM="$(id -u)"

WANT="badge-followback caffeinate comment-warmup competitor-follower-follow
daily-supervisor hashtag-follow incoming-reply-watcher mutual-prune
pipeline-heartbeat reply-followback-check reply-followers-cleanup tab-guard"

hide() {
  sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g' \
         -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){1,}/<伏せ・ハンドル列>/g'
}
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

# **1 回だけ取る**（ルール 13）
LC_BEFORE="$(launchctl list 2>/dev/null || true)"
loaded_before() { printf '%s\n' "$LC_BEFORE" | awk '{print $3}' | grep -qxF "ai.openclaw.$1"; }

{
echo "# 再起動で外れた X のループを載せ直す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 2026-09-20 00:54 JST の heartbeat: **\`x_jobs loaded 0 / expected 8\`**。"
echo "> Mac が 11:21 JST に落ち、00:20 JST に戻ったが **LaunchAgents が載り直していない。**"
echo "> **認証も CDP も生きている**ので、載せれば動く。"
echo
echo "**\`kickstart\` はしない**（いま走らせると LLM 代が発生する）。**載せるだけ。**"

# ═══════════ 1. 載せる前 ═══════════
echo
echo "## 1. 載せる前"
echo
echo '```'
NEED=""
for j in $WANT; do
  P="$LA/ai.openclaw.$j.plist"
  if loaded_before "$j"; then
    printf '  %-32s 載っている\n' "$j"
  elif [ ! -f "$P" ]; then
    printf '  %-32s **plist が無い**（作らない）\n' "$j"
  else
    printf '  %-32s **載っていない → 載せる**\n' "$j"
    NEED="$NEED $j"
  fi
done
echo
echo "  ai.openclaw.* の合計: $(printf '%s\n' "$LC_BEFORE" | awk '{print $3}' | grep -c '^ai\.openclaw\.' || echo 0) 本"
echo '```'

# ═══════════ 2. 載せる ═══════════
echo
echo "## 2. 載せる（\`bootout\` → \`bootstrap\`）"
echo
echo '```'
if [ -z "${NEED// /}" ]; then
  echo "  載せるものが無い。"
else
  for j in $NEED; do
    P="$LA/ai.openclaw.$j.plist"
    launchctl bootout "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
    R="$(launchctl bootstrap "gui/${UID_NUM}" "$P" 2>&1)"; RC=$?
    if [ -n "$R" ]; then
      printf '  %-32s rc=%s  %s\n' "$j" "$RC" "$(printf '%s' "$R" | head -1 | cut -c1-70)"
    else
      printf '  %-32s rc=%s\n' "$j" "$RC"
    fi
  done
  echo
  echo "  **rc は載った証拠にならない**（最上位ルール 13）。下で一覧を取り直して確かめる。"
fi
echo '```'

# ═══════════ 3. 載ったかを一覧で確かめる ═══════════
echo
echo "## 3. 結果（**\`launchctl list\` を取り直す**）"
echo
echo '```'
sleep 2
LC_AFTER="$(launchctl list 2>/dev/null || true)"
OK=0; NG=0; MISSING=""
for j in $WANT; do
  P="$LA/ai.openclaw.$j.plist"
  [ -f "$P" ] || continue
  if printf '%s\n' "$LC_AFTER" | awk '{print $3}' | grep -qxF "ai.openclaw.$j"; then
    OK=$((OK + 1))
    printf '  ✅ %-30s %s\n' "$j" "$(printf '%s\n' "$LC_AFTER" | awk -v l="ai.openclaw.$j" '$3==l {print "PID=" $1 " 最後の終了コード=" $2}')"
  else
    NG=$((NG + 1)); MISSING="$MISSING $j"
    printf '  ❌ %-30s **載らなかった**\n' "$j"
  fi
done
echo
echo "  載った: $OK 本 / 載らなかった: $NG 本"
[ -n "${MISSING// /}" ] && echo "  載らなかったもの:$MISSING"
echo
echo "  ai.openclaw.* の合計: $(printf '%s\n' "$LC_AFTER" | awk '{print $3}' | grep -c '^ai\.openclaw\.' || echo 0) 本"
echo '```'

# ═══════════ 4. この後どうなるか ═══════════
echo
echo "## 4. この後どうなるか"
echo
echo '```'
echo "  comment-warmup          12 / 16 / 19 / 22 時 に発火（1 回 4 件）"
echo "  competitor-follower     11:30 / 18:30"
echo "  hashtag-follow          10:15 / 17:xx"
echo "  mutual-prune             6 / 18 時（x80 で StartCalendarInterval に変更済み）"
echo "  daily-supervisor         5 / 17 時（今日 走っていないジョブを kickstart する）"
echo
echo "  **次の発火を待てば自然に戻る。** いま走らせたい場合は kickstart になるが、"
echo "  **返信の生成は LLM 代が出る**ので、承認を取ってから別のタスクで行う。"
echo '```'

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**載せるだけ。LLM を呼ばない。投稿もフォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**載った後に動き出す分**の実額（\`docs/recurring-job-costs.md\`）:"
echo "返信ループ 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 **\$1.44**"
echo "（\`MAX_PICKS\` は 4 のまま）。フォロー・アンフォロー系は **\$0**（DOM 操作のみ）。"
echo "**これは元々 想定していた額で、今回の作業で増えるものではない。**"
} > "$OUT" 2>&1

echo "X のループを載せ直す / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
