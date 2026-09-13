#!/bin/bash
# **いま comment-warmup を走らせて、x67 と x68 が効いたかを確かめる。**
# **費用: 生成 最大 4 件 = 最大 $0.012（承認済み）。**
#
# ## なぜ待たないか（最上位ルール 9）
#
# 定時は 22:00 JST。**手で起動すれば いま 確かめられる。**
# 「次の周回で分かります」と書いて終えない。
#
# ## 何を確かめるか（**rc=0 は証拠にならない・ルール 13**）
#
# | 見るもの | 効いていれば |
# | --- | --- |
# | `/tmp/orch-adskip.json` | `ad_skipped` に 1 以上（x68） |
# | `reply-followers.json` | `followers_at_follow` に数字（x67） |
# | `comment-orchestrator.log` | `gen failed ... 見送る` が減り、`enqueue` が増える |
# | キューの `x_tweet_id` | **実際に出た証拠**（ルール 11） |
#
# ## 費用（**かかる。承認済み**）
#
# | | 金額 |
# | --- | --- |
# | この 1 回 | 生成 最大 4 件 × $0.003 = **最大 $0.012** |
# | 1 日あたり（定常） | $0.048（上限）／ 実績ベースでは これまで $0.027 |
# | 1 か月あたり（定常） | **$1.44**（上限）／ x68 適用前の実績は 約 $0.81 |
#
# **この起動は定時の 1 回を前倒しするものではなく、1 回 増える。**
# よって今日の実費は **最大 $0.012 だけ上振れする。**
#
# ## ルール 15 を守る
#
# **待つのは最大 165 秒。** それで終わらなければ「起動した」ところまでを報告し、
# 結果は次のタスクで見る。**heartbeat を止めない。**
#
# ## やらないこと
#
# **設定を変えない。上限を触らない。`timeout` を使わない**（ルール 14）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/kickstart-and-verify.md"
NODE_BIN="/usr/local/bin/node"
LABEL="ai.openclaw.comment-warmup"
OL="$L/comment-orchestrator.log"
RF="$D/reply-followers.json"
WAIT_MAX=165

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# いま走らせて、x67 と x68 が効いたかを確かめる"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 定時は 22:00 JST。**手で起動すれば いま 確かめられる**（最上位ルール 9）。"
echo "> **費用: 生成 最大 4 件 = 最大 \$0.012。承認済み。**"

# ═══════════ 0. 走らせる前の状態 ═══════════
echo
echo "## 0. 走らせる前"
echo
echo '```'
LC="$(launchctl list 2>/dev/null || true)"          # **1 回だけ取る**（ルール 13）
if echo "$LC" | awk '{print $3}' | grep -qxF "$LABEL"; then
  echo "  $LABEL: **載っている**"
else
  echo "  $LABEL: **載っていない。起動できない。**"
fi
BEFORE_LINES="$(wc -l < "$OL" 2>/dev/null | tr -d ' ' || echo 0)"
echo "  comment-orchestrator.log: $BEFORE_LINES 行"
if [ -f /tmp/orch-adskip.json ]; then
  echo "  /tmp/orch-adskip.json: $(cat /tmp/orch-adskip.json 2>/dev/null | cut -c1-160)"
else
  echo "  /tmp/orch-adskip.json: **まだ無い**"
fi
if [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const rows=Object.entries(j).map(([k,v])=>(v&&typeof v==="object"?{handle:k,...v}:{handle:k}));
console.log("  reply-followers.json: "+rows.length+" 件 / followers_at_follow を持つ "
  + rows.filter(r=>r.followers_at_follow!==undefined).length+" 件");
' "$RF" 2>&1 | clean
fi
echo '```'

# ═══════════ 1. 走らせる ═══════════
echo
echo "## 1. 走らせる"
echo
echo '```'
if ! echo "$LC" | awk '{print $3}' | grep -qxF "$LABEL"; then
  echo "  **載っていないので起動しない。**"
else
  KS="$(launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>&1)"; KRC=$?
  [ -n "$KS" ] && echo "$KS" | sed 's/^/  /'
  echo "  kickstart を打った（rc=$KRC）"
  echo "  **rc は起動の合図であって、出た証拠ではない。** 下で状態を見る。"
  echo
  echo "  --- 終わるまで待つ（最大 ${WAIT_MAX} 秒） ---"
  w=0; done_seen=0
  while [ "$w" -lt "$WAIT_MAX" ]; do
    if [ -f "$OL" ] && tail -40 "$OL" 2>/dev/null | grep -q 'orchestrator done'; then
      NOW_LINES="$(wc -l < "$OL" 2>/dev/null | tr -d ' ' || echo 0)"
      if [ "$NOW_LINES" -gt "$BEFORE_LINES" ]; then done_seen=1; break; fi
    fi
    sleep 5; w=$((w + 5))
  done
  if [ "$done_seen" = "1" ]; then
    echo "  **終わった**（${w} 秒）"
  else
    echo "  **${WAIT_MAX} 秒 では終わらなかった。** 起動はしている。結果は次のタスクで見る"
  fi
fi
echo '```'

# ═══════════ 2. 何が起きたか ═══════════
echo
echo "## 2. この回のログ（**実物**）"
echo
echo '```'
if [ -f "$OL" ]; then
  AFTER_LINES="$(wc -l < "$OL" 2>/dev/null | tr -d ' ' || echo 0)"
  ADDED=$((AFTER_LINES - BEFORE_LINES))
  echo "  増えた行: $ADDED 行"
  echo
  if [ "$ADDED" -gt 0 ]; then
    tail -n "$ADDED" "$OL" 2>/dev/null | cut -c1-190 | sed 's/^/    /' | clean
  else
    echo "    **1 行 も増えていない。** まだ走っていないか、途中"
  fi
fi
echo '```'

# ═══════════ 3. x68 は効いたか ═══════════
echo
echo "## 3. x68（広告を選ぶ前に弾く）"
echo
echo '```'
if [ -f /tmp/orch-adskip.json ]; then
  cat /tmp/orch-adskip.json 2>/dev/null | cut -c1-200 | sed 's/^/  /'
  echo
  "$NODE_BIN" -e '
const fs=require("fs");
try {
  const j=JSON.parse(fs.readFileSync("/tmp/orch-adskip.json","utf8"));
  console.log("  候補 "+j.considered+" 件 → 広告で飛ばした "+j.ad_skipped+" 件 → 選んだ "+j.picked+" 件");
  console.log(j.ad_skipped > 0
    ? "  → **効いている。** 広告が picked の枠を使わずに落ちた"
    : "  → 飛ばした数は 0。**この回の候補に広告が無かっただけかもしれない。** 次の回も見る");
} catch (e) { console.log("  読めない: " + e.message); }
' 2>&1 | clean
else
  echo "  **/tmp/orch-adskip.json が無い。** この回はまだ選ぶところまで来ていない"
fi
echo '```'

# ═══════════ 4. x67 / x64 は効いたか ═══════════
echo
echo "## 4. x67 / x64（フォロワー数の記録）"
echo
echo '```'
if [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const rows=Object.entries(j).map(([k,v])=>(v&&typeof v==="object"?{handle:k,...v}:{handle:k}));
const has=rows.filter(r=>r.followers_at_follow!==undefined);
console.log("  全体 "+rows.length+" 件 / followers_at_follow を持つ **"+has.length+" 件**");
if (has.length) {
  for (const r of has.slice(-6)) {
    console.log("    "+(r.followed_at||"").slice(0,19)+"  followers="+r.followers_at_follow
      +"  following="+r.following_at_follow+"  ["+String(r.source||"").split(":")[0]+"]");
  }
  console.log("  → **効いている。**");
} else {
  console.log("  → まだ 0 件。**この回は新しくフォローしなかった可能性**");
  console.log("     （既にフォロー済みの相手ばかりだと skipped になる）");
}
' "$RF" 2>&1 | clean
fi
echo '```'

# ═══════════ 5. 実際に出たか（一次情報） ═══════════
echo
echo "## 5. 実際に出たか（**キューの \`x_tweet_id\`**・ルール 11）"
echo
echo '```'
Q="$D/post_queue.json"
if [ -f "$Q" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const q=(j.queue||[]).filter(x=>x.id&&String(x.id).startsWith("comment-"));
const today=new Date().toISOString().slice(0,10).replace(/-/g,"");
const t=q.filter(x=>String(x.id).indexOf("comment-"+today)===0);
console.log("  今日の comment- エントリ: "+t.length+" 件");
const posted=t.filter(x=>x.x_tweet_id||x.tweet_id);
console.log("  そのうち **x_tweet_id を持つ（＝出た）: "+posted.length+" 件**");
for (const x of posted.slice(-6)) console.log("    "+x.id+"  "+(x.x_tweet_id||x.tweet_id));
' "$Q" 2>&1 | clean
else
  echo "  **$Q が無い。**"
fi
echo '```'

# ═══════════ 6. 費用 ═══════════
echo
echo "## 6. 費用"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| **この 1 回**（生成 最大 4 件 × \$0.003） | **最大 \$0.012** |"
echo "| 1 日あたり（定常・上限） | \$0.048 |"
echo "| 1 か月あたり（定常・上限） | **\$1.44** |"
echo
echo "**この起動は定時の 1 回を前倒しするものではなく、1 回 増える。**"
echo "今日の実費は **最大 \$0.012 上振れする。**"
echo "単価は実測（2026-09-06・全文生成・Haiku 4.5）。"
echo "**入口で落ちた分は \$0**（LLM を呼んでいない）ので、実費はこれより下がる。"
} > "$OUT" 2>&1

echo "手動起動と確認 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
