#!/bin/bash
# **詰まりを実測する ＋ ポーラー自体も番人の監視対象に入れる。費用 $0（LLM 不使用）。**
#
# ## 起きたこと（2026-09-13 02:34〜）
#
# `x44` は「目標 16 件に届くまで**最大 8 回 繰り返す**」ループに入った。
# 1 回 あたり orchestrator の実行 3 分 ＋ 待ち。**最大 24 分。**
#
# その間、**`x45` / `x46` / `x47` が 1 本も届かなかった。**
# レポートも「1 回目」で切れたまま 23 分 更新されなかった。
#
# ## 究極的な原因: 実行に制限時間が無かった
#
#   scripts/ops-run-tasks.sh:105
#   out="$(/bin/bash "$task_tmp/$t" 2>&1)"      ← timeout が無い
#
# タスクは**直列**で走り、`done/` の印は**タスクが終わってから**書く。
# だから**止まったタスクは印が付かず、次の周回でも同じところで止まる。**
# キュー全体が永久に進まない。
#
# **これはリポジトリ側で直した**（`OPS_TASK_TIMEOUT`、既定 900 秒）。
# `timeout` は macOS の素の状態には無いので、無ければ無いで動くようにしてある。
#
# ## このタスクがやること
#
#   1. **いま詰まっているかを実測する**（ロック・実行中プロセス・done の数）
#   2. **ポーラー系（`com.dailyhack.*`）も番人の監視対象に足す**
#      ポーラーが止まっていたら、タスクは 1 件も届かない。
#      **いちばん上流なのに、いままで誰も見ていなかった。**
#   3. 番人をその場で 1 回 走らせて、結果を出す
#
# ## やらないこと
#
# **走っているタスクを kill しない。** 途中で切ると中途半端な状態が残りうる。
# 制限時間は次の周回から効く。**しきい値を緩めない。Chrome を kill しない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/unjam-and-watch-poller.md"
UID_NUM="$(id -u)"
SUP="$S/daily-supervisor.sh"
STAMP="$(date '+%Y%m%d-%H%M%S')"
PATCH="$(mktemp -t supp).sh"
trap 'rm -f "$PATCH"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 詰まりを実測する ＋ ポーラー自体も見張る"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"

# ═══════════ 1. いま詰まっているか ═══════════
echo
echo "## 1. いま詰まっているか（**実測**）"
echo
echo '```'
echo "  --- 走っている ops 系プロセス ---"
ps -Ao pid,etime,command 2>/dev/null \
  | grep -iE 'ops-run-tasks|ops-heartbeat|x4[0-9]-|comment-orchestrator|trend-detect' \
  | grep -v grep | head -10 | cut -c1-190 | sed 's/^/    /' | clean || echo "    無し"
echo
echo "  --- ロックらしきもの ---"
for L in /tmp/ops-run-tasks.lock /tmp/.ops-run-tasks.lock "${TMPDIR:-/tmp}/ops-run-tasks.lock"; do
  [ -e "$L" ] && echo "    $L … 在る（$(stat -f '%Sm' -t '%H:%M:%S' "$L" 2>/dev/null)）"
done
ls -1 "${TMPDIR:-/tmp}" 2>/dev/null | grep -iE 'ops.*lock|lock.*ops' | head -5 | sed 's/^/    /'
echo
echo "  --- 取り出されたタスクの一時ファイル（新しい順 8 件） ---"
ls -lt "${TMPDIR:-/tmp}/ops-tasks" 2>/dev/null | head -9 | sed 's/^/    /' | clean
echo '```'

# ═══════════ 2. ポーラーは生きているか ═══════════
echo
echo "## 2. ポーラーは生きているか（**いちばん上流**）"
echo
echo "**ポーラーが止まっていたら、タスクは 1 件も届かない。**"
echo "いちばん上流なのに、いままで誰も見ていなかった。"
echo
echo '```'
SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"
[ -z "$SNAP" ] && { sleep 2; SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"; }
for L in com.dailyhack.ops-poller com.dailyhack.ops-heartbeat com.dailyhack.rc-keeper \
         ai.openclaw.daily-supervisor ai.openclaw.caffeinate ai.openclaw.mutual-prune; do
  if printf '%s\n' "$SNAP" | grep -qxF "$L"; then
    printf '  %-34s ロード済み\n' "$L"
  elif [ -f "$LA/$L.plist" ]; then
    printf '  %-34s **plist はあるが未ロード**\n' "$L"
    launchctl bootout "gui/${UID_NUM}/$L" >/dev/null 2>&1 || true
    launchctl enable "gui/${UID_NUM}/$L" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/${UID_NUM}" "$LA/$L.plist" >/dev/null 2>&1 || true
    sleep 2
    launchctl list 2>/dev/null | awk '{print $3}' | grep -qxF "$L" \
      && printf '  %-34s → **載せ直した**\n' "$L" \
      || printf '  %-34s → **載らない**\n' "$L"
  else
    printf '  %-34s plist 無し\n' "$L"
  fi
done
echo '```'

# ═══════════ 3. 番人にポーラーも見せる ═══════════
echo
echo "## 3. 番人の監視対象に \`com.dailyhack.*\` を足す"
echo
echo "番人は \`ai.openclaw.*\` の 9 本しか見ていなかった。"
echo "**タスクを運ぶポーラーが死んだら、番人の指示も届かない。**"
echo
echo '```'
if [ ! -f "$SUP" ]; then
  echo "  **$SUP が無い。** x47 がまだ走っていない。"
else
  if grep -q 'JOBS_UPSTREAM' "$SUP" 2>/dev/null; then
    echo "  既に入っている。何もしない。"
  else
    cp "$SUP" "$SUP.bak-$STAMP"
    # **sed で行を差し込まない。** awk で「その行の直後」に確実に入れる
    awk '
      /^JOBS_NOCDP=/ {
        print
        print ""
        print "# **上流。** これが死ぬとタスクも番人の指示も届かない（2026-09-13 に追加）。"
        print "# launchd のラベルが com.dailyhack.* なので、上の 2 つとは別扱いにする。"
        print "JOBS_UPSTREAM=\"com.dailyhack.ops-poller com.dailyhack.ops-heartbeat\""
        next
      }
      { print }
    ' "$SUP" > "$SUP.tmp" && mv "$SUP.tmp" "$SUP"

    # 前提を直す関数の最後に、上流を載せ直す処理を足す
    awk '
      /^  \[ "\$n" -gt 0 \] && \{ fixed=/ {
        print "  # 上流（ポーラー・heartbeat）が落ちていたら載せ直す"
        print "  local u m=0"
        print "  for u in $JOBS_UPSTREAM; do"
        print "    printf %s\\\\n \"$snap\" | grep -qxF \"$u\" && continue"
        print "    [ -f \"$LA/$u.plist\" ] || continue"
        print "    launchctl bootout \"gui/${UID_NUM}/$u\" >/dev/null 2>&1 || true"
        print "    launchctl enable \"gui/${UID_NUM}/$u\" >/dev/null 2>&1 || true"
        print "    launchctl bootstrap \"gui/${UID_NUM}\" \"$LA/$u.plist\" >/dev/null 2>&1 || true"
        print "    m=$((m+1))"
        print "  done"
        print "  [ \"$m\" -gt 0 ] && { fixed=\"$fixed upstream:$m\"; log \"  上流 ${m} 本を載せ直した\"; }"
      }
      { print }
    ' "$SUP" > "$SUP.tmp" && mv "$SUP.tmp" "$SUP"

    if bash -n "$SUP" 2>/dev/null; then
      echo "  bash -n: OK"
      echo "  --- 入った所 ---"
      grep -n 'JOBS_UPSTREAM\|upstream:' "$SUP" 2>/dev/null | head -5 | cut -c1-120 | sed 's/^/    /'
    else
      echo "  **構文エラーになった。戻す。**"
      cp "$SUP.bak-$STAMP" "$SUP"
      bash -n "$SUP" 2>&1 | head -3 | sed 's/^/    /'
    fi
  fi
fi
echo '```'

# ═══════════ 4. 番人を 1 回 走らせる ═══════════
echo
echo "## 4. 番人をその場で 1 回 走らせる"
echo
echo "**追い上げで \`comment-warmup\` が走ると返信の生成が起きる（最大 4 件・\$0.012）。**"
echo "他は LLM を呼ばないので \$0。"
echo
echo '```'
if [ -x "$SUP" ]; then
  ( cd "$W" && OPS_WS="$W" MAX_FIX=2 timeout 600 bash "$SUP" ) 2>&1 \
    | tail -35 | cut -c1-240 | sed 's/^/  /' | clean
else
  echo "  番人がまだ置かれていない。"
fi
echo '```'
echo
echo "### \`status.json\`"
echo
echo '```json'
cat "$W/data/job-stamps/status.json" 2>/dev/null | head -35 | sed 's/^/  /' | clean || echo "  （まだ無い）"
echo '```'

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 詰まりの実測・ポーラーの監視追加 | **\$0**（LLM 不使用） |"
echo "| 番人の追い上げ（\`comment-warmup\` を走らせた時のみ） | 1 回 最大 \$0.012 ／ 1 日 最大 \$0.024 ／ 1 か月 最大 \$0.72 |"
echo "| 定時の返信ループ（**推定**） | 1 回 \$0.003 ／ 1 日 約 \$0.19 ／ 1 か月 約 \$5.8 |"
echo
echo "推定の前提: Haiku 4.5・通過率 25%・生成 64 回/日。"
echo "追い上げの額は「定時が走らなかった日」だけ発生する上限で、実績ではない。"
} > "$OUT" 2>&1

echo "詰まりの実測とポーラー監視 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
