#!/bin/bash
# **復旧後に 1 回 走らせて、実際に出るかを確かめる。承認済み・最大 $0.012。**
#
# ## なぜ（2026-09-20 01:1x）
#
#   last_reply: 2026-09-19 05:06 JST（**19 時間 前**・stale）
#   x84 で 12/12 本 載せ直した。認証も CDP も生きている。
#
# **載ったことは「出る」証拠にならない**（最上位ルール 13）。
# 次の定時（12 時）を待たず、いま 1 回 走らせて確かめる（最上位ルール 9）。
#
# ## 完了判定は「開始より後に完了が在るか」で見る
#
# **x70 で間違えた。** `tail` に残った前回の `orchestrator done` を拾って
# 起動直後を「終わった」と判定した。**行番号で比べる。**
#
# ## 費用（**かかる。承認済み**）
#
# | | 金額 |
# | --- | --- |
# | この 1 回 | 生成 最大 4 件 × $0.003 = **最大 $0.012** |
# | 1 日（定常・上限） | $0.048 |
# | 1 か月（定常・上限） | **$1.44** |
#
# **定時の 1 回を前倒しするのではなく 1 回 増える。** 実費は最大 $0.012 上振れする。
# 入口で落ちた分は $0（LLM を呼んでいない）ので、実際はこれより下がる。
#
# ## やらないこと
#
# **設定を変えない。上限を触らない。`timeout` を使わない**（ルール 14）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/kickstart-after-recovery.md"
NODE_BIN="/usr/local/bin/node"
LABEL="ai.openclaw.comment-warmup"
OL="$L/comment-orchestrator.log"
Q="$D/post_queue.json"
WAIT_MAX=165

hide() {
  sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g' \
         -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){1,}/<伏せ・ハンドル列>/g'
}
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 復旧後に 1 回 走らせて、実際に出るかを確かめる"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x84 で 12/12 本 載せ直した。**だが載ったことは「出る」証拠にならない**（ルール 13）。"
echo "> 最後の返信は 2026-09-19 05:06 JST で **19 時間 前**。"
echo ">"
echo "> **費用: 生成 最大 4 件 = 最大 \$0.012。承認済み。**"

# ═══════════ 0. 走らせる前 ═══════════
echo
echo "## 0. 走らせる前"
echo
echo '```'
LC="$(launchctl list 2>/dev/null || true)"      # **1 回だけ取る**
if printf '%s\n' "$LC" | awk '{print $3}' | grep -qxF "$LABEL"; then
  echo "  $LABEL: **載っている**"
else
  echo "  $LABEL: **載っていない。起動できない。**"
fi
[ -f /tmp/x-login-in-progress ] && echo "  login ロック: **在る**" || echo "  login ロック: 無い"
if [ -f "$W/scripts/cdp-health.js" ]; then
  ( cd "$W/scripts" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ) \
    && echo "  CDP: 健全" || echo "  CDP: **落ちている**"
fi
S_BEFORE="$(grep -c 'comment orchestrator start' "$OL" 2>/dev/null || echo 0)"
D_BEFORE="$(grep -c 'orchestrator done' "$OL" 2>/dev/null || echo 0)"
echo "  ログ: start $S_BEFORE 回 / done $D_BEFORE 回"
echo '```'

# ═══════════ 1. 走らせる ═══════════
echo
echo "## 1. 走らせる"
echo
echo '```'
if ! printf '%s\n' "$LC" | awk '{print $3}' | grep -qxF "$LABEL"; then
  echo "  **載っていないので起動しない。**"
else
  KS="$(launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>&1)"; KRC=$?
  [ -n "$KS" ] && printf '%s\n' "$KS" | head -2 | sed 's/^/  /'
  echo "  kickstart rc=$KRC（**rc は出た証拠ではない**）"
  echo
  echo "  --- 終わるまで待つ（最大 ${WAIT_MAX} 秒） ---"
  w=0; fin=0
  while [ "$w" -lt "$WAIT_MAX" ]; do
    SL="$(grep -n 'comment orchestrator start' "$OL" 2>/dev/null | tail -1 | cut -d: -f1)"
    DL="$(grep -n 'orchestrator done' "$OL" 2>/dev/null | tail -1 | cut -d: -f1)"
    # **開始より後に完了が在るか**で見る（x70 の間違いを繰り返さない）
    if [ -n "$SL" ] && [ -n "$DL" ] && [ "$DL" -gt "$SL" ] \
       && [ "$(grep -c 'comment orchestrator start' "$OL" 2>/dev/null || echo 0)" -gt "$S_BEFORE" ]; then
      fin=1; break
    fi
    sleep 5; w=$((w + 5))
  done
  [ "$fin" = "1" ] && echo "  **終わった**（${w} 秒）" \
                   || echo "  **${WAIT_MAX} 秒 では終わらなかった。** 起動はしている"
fi
echo '```'

# ═══════════ 2. この回のログ ═══════════
echo
echo "## 2. この回のログ（**実物**）"
echo
echo '```'
SL="$(grep -n 'comment orchestrator start' "$OL" 2>/dev/null | tail -1 | cut -d: -f1)"
if [ -n "$SL" ]; then
  awk -v s="$SL" 'NR>=s' "$OL" 2>/dev/null | cut -c1-185 | sed 's/^/    /' | clean
else
  echo "    ログが読めない"
fi
echo '```'

# ═══════════ 3. 実際に出たか ═══════════
echo
echo "## 3. 実際に出たか（**キューの \`x_tweet_id\`**・ルール 11）"
echo
echo '```'
if [ -f "$Q" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const q = Array.isArray(j.queue) ? j.queue : [];
const now = new Date(Date.now() + 9 * 3600 * 1000);
const today = now.toISOString().slice(0, 10).replace(/-/g, "");
const mine = q.filter((x) => x && x.id && String(x.id).indexOf("comment-" + today) === 0);
const posted = mine.filter((x) => x.x_tweet_id || x.tweet_id);
console.log("  今日（JST " + today + "）の comment- エントリ: " + mine.length + " 件");
console.log("  そのうち **x_tweet_id を持つ（＝出た）: " + posted.length + " 件**");
console.log("");
for (const x of posted.slice(-6)) console.log("    " + x.id + "  https://x.com/heng_ji31590/status/" + (x.x_tweet_id || x.tweet_id));
const pend = mine.filter((x) => !(x.x_tweet_id || x.tweet_id));
if (pend.length) { console.log(""); console.log("  まだ出ていない: " + pend.length + " 件"); }
' "$Q" 2>&1 | clean
fi
echo
echo "  --- 広告を選ぶ前に弾いた数（x68） ---"
[ -f /tmp/orch-adskip.json ] && cat /tmp/orch-adskip.json 2>/dev/null | cut -c1-160 | sed 's/^/    /' \
  || echo "    /tmp/orch-adskip.json が無い"
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| **この 1 回**（生成 最大 4 件 × \$0.003） | **最大 \$0.012** |"
echo "| 1 日あたり（定常・上限） | \$0.048 |"
echo "| 1 か月あたり（定常・上限） | **\$1.44** |"
echo
echo "**定時の 1 回を前倒しするのではなく 1 回 増える。**"
echo "入口で落ちた分は \$0（LLM を呼んでいない）ので、実費はこれより下がる。"
} > "$OUT" 2>&1

echo "復旧後の 1 回 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
