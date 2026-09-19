#!/bin/bash
# **再起動でジョブが外れる理由を読む。測るだけ。費用 $0。**
#
# ## なぜ（2 回 起きている）
#
#   2026-09-12  載っているのは 7 本だけ。X を触るループは 1 本も無い
#   2026-09-20  Mac 復帰後、`ai.openclaw.*` が **1 本**（tab-guard）だけ
#
# **`~/Library/LaunchAgents` に置いた plist は、本来ログイン時に自動で載る。**
# 載らないなら理由がある。**推測で plist を書き換える前に、実物を読む。**
#
# ## 疑うところ（上から順に）
#
#   1. **`launchctl print-disabled`** に入っていないか
#      `launchctl disable` は**再起動をまたいで残る**。一度 disable されると
#      plist が在ってもログイン時に載らない
#   2. plist の **`Disabled` キー**が true になっていないか
#   3. plist の置き場所（`~/Library/LaunchAgents` に在るか）
#   4. **`RunAtLoad`** の有無（載った直後に 1 回 走るか）
#   5. 前回 落ちたときの終了コード（`launchctl list` の 2 列目）
#
# ## やらないこと
#
# **直さない。enable しない。plist を書き換えない。LLM を呼ばない（$0）。**
set -uo pipefail

LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/why-jobs-drop.md"
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

{
echo "# 再起動でジョブが外れる理由"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **2 回 起きている。** 2026-09-12 と 2026-09-20。"
echo "> どちらも \`ai.openclaw.*\` がほぼ全滅し、手で載せ直している。"
echo ">"
echo "> \`~/Library/LaunchAgents\` の plist は**本来ログイン時に自動で載る。**"
echo "> 載らないなら理由がある。**推測で書き換える前に実物を読む。**"
echo
echo "**測るだけ。直さない。**"

# ═══════════ 1. disable されていないか ═══════════
echo
echo "## 1. \`launchctl disable\` されていないか（**再起動をまたいで残る**）"
echo
echo '```'
DIS="$(launchctl print-disabled "gui/${UID_NUM}" 2>/dev/null || true)"
if [ -z "$DIS" ]; then
  echo "  **print-disabled が読めない。**（この macOS では使えないかもしれない）"
else
  N="$(printf '%s\n' "$DIS" | grep -c '=> *\(true\|disabled\)' || echo 0)"
  echo "  無効にされている合計: $N 件"
  echo
  echo "  --- ai.openclaw / com.dailyhack のうち無効なもの ---"
  printf '%s\n' "$DIS" | grep -E '(ai\.openclaw|com\.dailyhack)' \
    | grep -E '=> *(true|disabled)' | head -20 | sed 's/^/    /' | clean
  echo
  echo "  --- 対象 12 本 の状態 ---"
  for j in $WANT; do
    ST="$(printf '%s\n' "$DIS" | grep -F "ai.openclaw.$j" | head -1 | sed 's/^[[:space:]]*//')"
    printf '    %-30s %s\n' "$j" "${ST:-（一覧に無い＝無効化されていない）}"
  done
fi
echo '```'
echo
echo "**\`=> true\` や \`disabled\` が付いていれば、それが原因。**"
echo "その場合は \`launchctl enable gui/<uid>/<label>\` が要る（**このタスクではやらない**）。"

# ═══════════ 2. plist の中身 ═══════════
echo
echo "## 2. plist の \`Disabled\` と \`RunAtLoad\`"
echo
echo '```'
printf '    %-30s %-10s %-10s %s\n' "ジョブ" "Disabled" "RunAtLoad" "置き場所"
for j in $WANT; do
  P="$LA/ai.openclaw.$j.plist"
  if [ ! -f "$P" ]; then
    printf '    %-30s %-10s %-10s %s\n' "$j" "-" "-" "**plist が無い**"
    continue
  fi
  DIS_K="$(/usr/libexec/PlistBuddy -c 'Print :Disabled' "$P" 2>/dev/null || echo '(無し)')"
  RAL="$(/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' "$P" 2>/dev/null || echo '(無し)')"
  printf '    %-30s %-10s %-10s %s\n' "$j" "$DIS_K" "$RAL" "LaunchAgents"
done
echo '```'
echo
echo "**\`Disabled = true\` なら、それだけで載らない。**"
echo "**\`RunAtLoad\` が無いものは、載っても次の定時まで走らない**（これは正常）。"

# ═══════════ 3. いまの状態と前回の終了コード ═══════════
echo
echo "## 3. いまの状態（**\`launchctl list\` を 1 回だけ取る**）"
echo
echo '```'
LC="$(launchctl list 2>/dev/null || true)"
printf '    %-30s %-10s %s\n' "ジョブ" "PID" "最後の終了コード"
for j in $WANT; do
  ROW="$(printf '%s\n' "$LC" | awk -v l="ai.openclaw.$j" '$3==l {print $1 "  " $2}')"
  printf '    %-30s %s\n' "$j" "${ROW:-**載っていない**}"
done
echo
echo "  ai.openclaw.* の合計: $(printf '%s\n' "$LC" | awk '{print $3}' | grep -c '^ai\.openclaw\.' || echo 0) 本"
echo '```'
echo
echo "**最後の終了コードが 0 以外のものは、走って落ちている。**"
echo "載っていないこととは別の問題なので、混ぜない。"

# ═══════════ 4. 置き場所の確認 ═══════════
echo
echo "## 4. plist の置き場所と更新日"
echo
echo '```'
echo "  $LA"
ls -1t "$LA" 2>/dev/null | grep -E '^ai\.openclaw\.' | head -16 | while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  printf '    %-46s %s\n' "$f" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$LA/$f" 2>/dev/null)"
done
echo
echo "  --- ここ以外に置かれていないか（LaunchDaemons など） ---"
for d in "$HOME/Library/LaunchDaemons" /Library/LaunchAgents /Library/LaunchDaemons; do
  [ -d "$d" ] || continue
  C="$(ls -1 "$d" 2>/dev/null | grep -cE '^(ai\.openclaw|com\.dailyhack)\.' || echo 0)"
  printf '    %-34s %s 件\n' "$d" "$C"
done
echo '```'

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**読むだけ。LLM を呼ばない。enable も bootstrap もしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**直す場合も \$0**（launchd の設定のみ。LLM を呼ばない）。"
} > "$OUT" 2>&1

echo "再起動で外れる理由 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
