#!/bin/bash
# **相互フォローの「そっと外す」（mutual-prune）が動いているかと、いま外せそうな相互が何人いるかを見る。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > 相互フォローでこっそりフォローを外せそうな人はいる？
#   > 定期的にフォローを外すように指示していたつもりだけどちゃんと動いてる？
#
# 「定期的に外す」は 2 本ある:
#   - **mutual-prune**（相互でも 休眠 30 日 か 格下 なら外す・6 時と 18 時・1 回 8 件まで）← 9/13〜
#   - **follow-balance**（片思いから外して比率を保つ・11:45 と 18:45）← x217〜x221 で見た
# ここでは mutual-prune を見る。
#
#   ① launchd に載っているか・runs・最後の終了コード・定時
#   ② ログ: 実行ごとの「外した件数 / 候補 / 見送りの理由」を日付順に（直近 14 回）
#   ③ mutual-prune-state.json: 日ごとに何件 外したか
#   ④ **DRY_RUN で 1 回 判定だけ走らせる**（外さない）: いま外せそうな相互が何人いて、理由は何か
#      上限は MAX_UNFOLLOW=20 で数え、4 分で打ち切る
#
# **外さない。フォローしない。設定を変えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
# 他人のハンドルはレポートに出さない。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs/mutual-prune.log"
ST="$W/data/mutual-prune-state.json"
LABEL="ai.openclaw.mutual-prune"
UIDN="$(id -u)"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/mutual-prune-health.md"
DRYLOG="$W/.x222-dry-$(date '+%Y%m%d-%H%M%S').log"

mask() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#"/[A-Za-z0-9_]{2,15}"#"/<伏せ>"#g; s#x\.com/[A-Za-z0-9_]{2,15}#x.com/<伏せ>#g'; }

descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    local victims p
    victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

{
echo "# 相互フォローのそっと外す（mutual-prune）は動いているか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **外さない。フォローしない。設定を変えない（\$0／回・\$0／日・\$0／月）。**"
echo
echo "## ① launchd"
echo
echo '```'
pr="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
if [ -n "$pr" ]; then
  printf '  載っている  state=%s runs=%s last_exit=%s\n' \
    "$(printf '%s' "$pr" | awk -F'= ' '/^\tstate =/{print $2; exit}')" \
    "$(printf '%s' "$pr" | awk -F'= ' '/^\truns =/{print $2; exit}')" \
    "$(printf '%s' "$pr" | awk -F'= ' '/last exit code =/{print $2; exit}')"
else
  PL="$HOME/Library/LaunchAgents/$LABEL.plist"
  if [ -f "$PL" ]; then echo "  **載っていない**（plist は在る）"; elif [ -f "$PL.disabled" ]; then echo "  止めてある（.disabled）"; else echo "  **plist が無い**"; fi
fi
plutil -p "$HOME/Library/LaunchAgents/$LABEL.plist" 2>/dev/null | grep -E '"Hour"|"Minute"|MAX_UNFOLLOW|INACTIVE_DAYS|RATIO|ABS_MIN|GRACE_DAYS|DRY_RUN' | sed 's/^/  /'
printf '  本体: %s\n' "$([ -f "$S/mutual-prune.js" ] && echo "在る（$(wc -l < "$S/mutual-prune.js" | tr -d ' ') 行）" || echo '**無い**')"
echo '```'
echo
echo "## ② 実行ごとの結果（直近 14 回）"
echo
echo '```'
if [ -f "$L" ]; then
  printf '  ログ: %s bytes・更新 %s\n\n' "$(wc -c < "$L" | tr -d ' ')" "$(stat -f '%Sm' -t '%m/%d %H:%M' "$L" 2>/dev/null)"
  awk '!s[$0]++' "$L" | grep -E 'mutual-prune start|外した|候補|見送り|done|=== ' | tail -40 | cut -c1-200 | mask | sed 's/^/  /'
else
  echo "  **ログが無い**"
fi
echo '```'
echo
echo "## ③ 外した記録（mutual-prune-state.json）"
echo
echo '```'
if [ -f "$ST" ]; then
  node -e '
    const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const by = {}, why = {};
    for (const v of Object.values(j)) {
      if (!v || !v.unfollowed_at) continue;
      const d = new Date(new Date(v.unfollowed_at).getTime() + 9 * 3600e3).toISOString().slice(0, 10);
      by[d] = (by[d] || 0) + 1;
      const w = String(v.why || "?").replace(/[0-9]+/g, "N"); why[w] = (why[w] || 0) + 1;
    }
    const days = Object.keys(by).sort();
    console.log("  合計 " + Object.values(by).reduce((a, b) => a + b, 0) + " 件");
    for (const d of days) console.log("  " + d + "  " + by[d] + " 件");
    console.log("\n  理由の内訳:"); for (const [w, n] of Object.entries(why).sort((a, b) => b[1] - a[1])) console.log("    " + n + " 件  " + w);
  ' "$ST" 2>&1
else
  echo "  **無い**"
fi
echo '```'
echo
echo "## ④ いま外せそうな相互（DRY_RUN・外さない）"
echo
echo '```'
if [ -f "$S/mutual-prune.js" ]; then
  T0="$(date +%s)"
  ( cd "$W" && DRY_RUN=1 MAX_UNFOLLOW=20 run_limited 240 "$DRYLOG" node "$S/mutual-prune.js" ); RC=$?
  printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
  [ "$RC" = "124" ] && echo "  （4 分で打ち切った。ここまでの判定を出す）"
  echo
  # DRY の判定はログファイルにも出る。今回の start 以降を見る
  ln="$(grep -n 'mutual-prune start (dry=true' "$L" 2>/dev/null | tail -1 | cut -d: -f1)"
  if [ -n "$ln" ]; then
    RUN="$(tail -n +"$ln" "$L" | awk '!s[$0]++')"
  else
    RUN="$(awk '!s[$0]++' "$DRYLOG")"
  fi
  printf '%s\n' "$RUN" | grep -E 'start|相互|候補|外す|見送|休眠|格下|猶予|読めない|===' | tail -50 | cut -c1-200 | mask | sed 's/^/  /'
  echo
  printf '  外す候補（✂ や「外す」の行）: %s 件\n' "$(printf '%s\n' "$RUN" | grep -c -E '✂|→ 外す|外す候補:' | head -1)"
else
  echo "  **mutual-prune.js が無い**"
fi
echo '```'
rm -f "$DRYLOG"
echo
echo "**外していない。フォローしていない。設定を変えていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
if grep -aq '## ④' "$OUT" 2>/dev/null; then echo "mutual-prune の稼働と候補を読んだ / $(basename "$OUT")"; else echo "**読めていない** / $(basename "$OUT")"; fi
