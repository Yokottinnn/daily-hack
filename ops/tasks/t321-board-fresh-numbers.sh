#!/bin/bash
# **作戦室の数字を今すぐ取り直し、毎朝の取得が止まっていた原因を調べる（t321）。**
# 利用者（2026-10-19）「数字が更新されていないよ。Xのフォロワーの数とか全然最新じゃないし。マジで雑な仕事するなよ。これ最優先で取り組め」
#
# 作戦室の元データ（Search Console・A8・X）は 10/12 のまま止まっていた。
# t319（10/18）で com.dailyhack.board-weekly を毎日 6:40 にして「載った」は確認したが、
# 10/18・10/19 の 6:40 に reports/board/ が一度も更新されていない。
#
#   ① board-weekly の実行記録（launchctl print の runs・last exit code・program）と plist・ログの末尾
#   ② X の数字を今すぐ読む（x-numbers.js・読むだけ）→ reports/board/x-numbers.json
#   ③ board-weekly を今すぐ走らせる（kickstart。待たずに返る。結果は次の heartbeat で push される）
#
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**
# 共有の Chrome は、自分で開いたタブだけ閉じる。何も押さない（3M のタブ切り替えだけ）・投稿しない。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t321-board-fresh.md"
mkdir -p "$RDIR/board"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
W="$HOME/.openclaw/workspace"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || echo /usr/local/bin/node)"
LABEL=com.dailyhack.board-weekly
P="$HOME/Library/LaunchAgents/$LABEL.plist"
{ echo "# 作戦室の数字の取り直し（t321・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"

# ① 実行記録
{
  echo "## ① board-weekly の実行記録"; echo; echo '```text'
  launchctl print "gui/$(id -u)/$LABEL" 2>&1 | grep -E "state|runs|last exit|program|arguments|path =|stdout|stderr" | head -20
  echo '```'; echo
  echo "### plist"; echo; echo '```text'
  if [ -f "$P" ]; then plutil -p "$P" 2>&1 | head -40; else echo "plist が無い: $P"; fi
  echo '```'; echo
} >> "$OUT"
for k in StandardOutPath StandardErrorPath; do
  LP="$(plutil -extract "$k" raw "$P" 2>/dev/null || true)"
  if [ -n "$LP" ] && [ -f "$LP" ]; then
    { echo "### $k の末尾（$LP・更新 $(stat -f '%Sm' "$LP" 2>/dev/null)）"; echo; echo '```text'; tail -25 "$LP"; echo '```'; echo; } >> "$OUT"
  else echo "- $k: ファイルが無い（${LP:-未設定}）" >> "$OUT"; fi
done
{ echo "### 書き出し先 reports/board の更新日時"; echo; echo '```text'; ls -la "$HOME/.openclaw/ops-heartbeat-wt/reports/board/" 2>&1 | head -15; echo '```'; echo; } >> "$OUT"

# ② X の数字
git -C "$REPO" fetch -q origin main 2>/dev/null; git -C "$REPO" show origin/main:scripts/strategy-board/x-numbers.js > "$W/.x-numbers.js"
[ -s "$W/.x-numbers.js" ] || echo "- ⚠️ x-numbers.js を origin/main から取れなかった" >> "$OUT"
( cd "$W" && "$NODE_BIN" "$W/.x-numbers.js" "$RDIR/board/x-numbers.json" > "$W/.x-numbers.log" 2>&1 & echo $! > "$W/.x-numbers.pid" )
XPID="$(cat "$W/.x-numbers.pid")"; t0=$(date +%s)
while kill -0 "$XPID" 2>/dev/null; do [ $(( $(date +%s) - t0 )) -ge 150 ] && { kill "$XPID" 2>/dev/null; echo "- ⚠️ x-numbers が 150 秒で終わらなかった" >> "$OUT"; break; }; sleep 3; done
{ echo "## ② X の数字（いま読んだもの）"; echo; echo '```json'; cat "$RDIR/board/x-numbers.json" 2>/dev/null || tail -5 "$W/.x-numbers.log"; echo; echo '```'; echo; } >> "$OUT"

# ③ board-weekly を今すぐ走らせる（待たない。終わったら heartbeat が reports/board を push する）
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  launchctl kickstart "gui/$(id -u)/$LABEL" >/dev/null 2>&1; echo "## ③ board-weekly を kickstart した（rc=$?）。結果は次の heartbeat で reports/board/mac-weekly-status.json に出る" >> "$OUT"
else
  echo "## ③ board-weekly が載っていない。plist から載せ直す" >> "$OUT"
  launchctl bootstrap "gui/$(id -u)" "$P" >/dev/null 2>&1; echo "- bootstrap rc=$?" >> "$OUT"
  launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1 && { launchctl kickstart "gui/$(id -u)/$LABEL" >/dev/null 2>&1; echo "- 載った。kickstart rc=$?" >> "$OUT"; } || echo "- まだ載っていない" >> "$OUT"
fi
cat "$OUT"
