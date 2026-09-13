#!/bin/bash
# **21:06 に起動した回の結果を読む。走らせない。費用 $0。**
#
# ## x70 の待ち判定が間違っていた（**私のバグ**）
#
#   if tail -40 "$OL" | grep -q 'orchestrator done'; then ... done_seen=1
#
# **直前の周回（19:03）の `orchestrator done` が tail に残っていた。**
# 行数が 1 行 増えた（起動の行）だけで「終わった（5 秒）」と判定した。
#
#   [2026-09-13T21:06:29] === comment orchestrator start (max_picks=4, ...) ===
#   増えた行: 1 行        ← **起動しただけ**
#
# 起動そのものは成功している。**処理は 3 分 前後かかる。**
# このタスクは**もう終わっているはずの結果を読むだけ。**
#
# ## 今度は「開始より後に完了が在るか」で見る
#
# 最後の `orchestrator start` の行番号と、最後の `orchestrator done` の行番号を比べる。
# **done が start より後なら、その回は終わっている。**
#
# ## 確かめるもの（ルール 13・状態で見る）
#
#   /tmp/orch-adskip.json   ad_skipped に 1 以上 → x68 が効いた
#   reply-followers.json    followers_at_follow に数字 → x67 / x64 が効いた
#   キューの x_tweet_id     実際に出た証拠（ルール 11）
#
# ## やらないこと
#
# **起動しない。設定を変えない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/kickstart-result.md"
NODE_BIN="/usr/local/bin/node"
OL="$L/comment-orchestrator.log"
RF="$D/reply-followers.json"
Q="$D/post_queue.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 21:06 に起動した回の結果"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **x70 の待ち判定が間違っていた。** 直前の周回の \`orchestrator done\` が"
echo "> \`tail -40\` に残っていたため、起動直後を「終わった」と判定した。"
echo ">"
echo "> **起動は成功している。** これは結果を読むだけのタスク。"

# ═══════════ 1. その回は終わったか ═══════════
echo
echo "## 1. その回は終わったか（**開始より後に完了が在るか**で見る）"
echo
echo '```'
if [ ! -f "$OL" ]; then
  echo "  **$OL が無い。**"
else
  S_LINE="$(grep -n 'comment orchestrator start' "$OL" 2>/dev/null | tail -1 | cut -d: -f1)"
  D_LINE="$(grep -n 'orchestrator done' "$OL" 2>/dev/null | tail -1 | cut -d: -f1)"
  echo "  最後の start: ${S_LINE:-無し} 行目"
  echo "  最後の done : ${D_LINE:-無し} 行目"
  if [ -n "$S_LINE" ] && [ -n "$D_LINE" ] && [ "$D_LINE" -gt "$S_LINE" ]; then
    echo "  → **終わっている**（done が start より後）"
  else
    echo "  → **まだ終わっていない**（done が start より前）"
  fi
  echo
  echo "  --- 最後の start 以降の全行（**実物**） ---"
  if [ -n "$S_LINE" ]; then
    awk -v s="$S_LINE" 'NR>=s' "$OL" 2>/dev/null | cut -c1-190 | sed 's/^/    /' | clean
  fi
fi
echo '```'

# ═══════════ 2. x68 は効いたか ═══════════
echo
echo "## 2. x68（広告を選ぶ前に弾く）"
echo
echo '```'
if [ -f /tmp/orch-adskip.json ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
try {
  const j=JSON.parse(fs.readFileSync("/tmp/orch-adskip.json","utf8"));
  console.log("  " + JSON.stringify(j));
  console.log("");
  console.log("  候補 "+j.considered+" 件 → 広告で飛ばした "+j.ad_skipped+" 件 → 選んだ "+j.picked+" 件");
  console.log(j.ad_skipped > 0
    ? "  → **効いている。** 広告が picked の枠を使わずに落ちた"
    : "  → 飛ばした数は 0。**この回の候補に広告が無かっただけかもしれない。**\n     判定そのものが動いた証拠は、このファイルが在ること自体");
} catch (e) { console.log("  読めない: " + e.message); }
' 2>&1 | clean
else
  echo "  **/tmp/orch-adskip.json が無い。**"
  echo "  選ぶところまで来ていない（候補 0 件 / 全員 cooldown / 途中で落ちた のいずれか）"
fi
echo '```'

# ═══════════ 3. x67 / x64 は効いたか ═══════════
echo
echo "## 3. x67 / x64（フォロワー数の記録）"
echo
echo '```'
if [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const rows=Object.entries(j).map(([k,v])=>(v&&typeof v==="object"?{handle:k,...v}:{handle:k}));
const has=rows.filter(r=>r.followers_at_follow!==undefined);
console.log("  全体 "+rows.length+" 件 / followers_at_follow を持つ **"+has.length+" 件**");
const today=new Date().toISOString().slice(0,10);
const t=rows.filter(r=>(r.followed_at||"").startsWith(today));
console.log("  今日フォローした件数: "+t.length+" 件");
console.log("");
if (has.length) {
  console.log("  --- 直近 6 件 ---");
  for (const r of has.slice(-6)) {
    console.log("    "+(r.followed_at||"").slice(0,19)+"  followers="+r.followers_at_follow
      +"  following="+r.following_at_follow+"  ["+String(r.source||"").split(":")[0]+"]");
  }
  console.log("  → **効いている。**");
} else {
  console.log("  → まだ 0 件。**新しくフォローした相手が居なければ入らない。**");
  console.log("     今日の分は既に 9 件 フォロー済みで、返信先が重なると skipped になる");
  console.log("     次に入る機会: 明日 10:15（hashtag）/ 11:30（competitor）/ 次の返信の周回");
}
' "$RF" 2>&1 | clean
fi
echo '```'

# ═══════════ 4. 実際に出たか ═══════════
echo
echo "## 4. 実際に出たか（**キューの \`x_tweet_id\`**・ルール 11）"
echo
echo '```'
if [ -f "$Q" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const q=(j.queue||[]).filter(x=>x.id&&String(x.id).startsWith("comment-"));
const today=new Date().toISOString().slice(0,10).replace(/-/g,"");
const t=q.filter(x=>String(x.id).indexOf("comment-"+today)===0);
const posted=t.filter(x=>x.x_tweet_id||x.tweet_id);
console.log("  今日の comment- エントリ: "+t.length+" 件");
console.log("  そのうち **x_tweet_id を持つ（＝出た）: "+posted.length+" 件**");
console.log("");
for (const x of posted.slice(-8)) console.log("    "+x.id+"  "+(x.x_tweet_id||x.tweet_id));
const pending=t.filter(x=>!(x.x_tweet_id||x.tweet_id));
if (pending.length) {
  console.log("");
  console.log("  まだ出ていない: "+pending.length+" 件");
  for (const x of pending.slice(-5)) console.log("    "+x.id+"  status="+(x.status||"?"));
}
' "$Q" 2>&1 | clean
else
  echo "  **$Q が無い。**"
fi
echo '```'

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**このタスクは読むだけ。LLM を呼ばない。起動もしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**21:06 の回そのもの**は生成した件数 × \$0.003（最大 \$0.012）。"
echo "定常は 1 日 上限 \$0.048 ／ 1 か月 上限 **\$1.44**（x68 適用前の実績は \$0.027 ／ 約 \$0.81）。"
} > "$OUT" 2>&1

echo "21:06 の回の結果 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
