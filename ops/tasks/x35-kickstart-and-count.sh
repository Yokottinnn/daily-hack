#!/bin/bash
# **定時を待たず、いま返信を出す。そして実数を数える。**
# **費用: LLM 最大 4 回・約 $0.012（実測単価 $0.003/件）。**
#
# ## なぜ今すぐ走らせるか
#
# 最上位ルール 9:
#
#   > 「次の定時実行を待つ」は、ほぼ全部 やらなくていい待ち
#   > `launchctl kickstart -k` で即座に走らせられる
#
# 定時は 12:00 / 16:00 / 19:00 / 22:00。**次まで最大 4 時間 待つことになる。**
# 悪循環を断った直後なので、**本当に返信が出るかを今すぐ確かめる。**
#
# ## やること
#
#   1. 前提を確認（CDP 健全 / comment-warmup がロード済み / 鍵が無い）
#      → **どれか欠けていたら走らせない**（無駄に LLM を呼ばない）
#   2. **走らせる前の実投稿数**をキューから数える（x_tweet_id ＝ 一次情報）
#   3. `launchctl kickstart -k` で comment-warmup を即実行
#   4. 3 分 待つ（この処理は実績上 3 分かかる）
#   5. **走らせた後の実投稿数**を数え、差分と URL を出す
#
# ## コスト（最上位ルール 2-B）
#
#   単価: Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok（claude-api スキルの料金表）
#   実測: **$0.003/件**
#
#   | | 1 回 | 1 日 | 1 か月 |
#   | --- | --- | --- | --- |
#   | **この タスク**（最大 4 件） | **約 $0.012** | 一度きり | **$0** |
#   | 返信の定常運用（実測 3〜5 件/日） | $0.003 | $0.009〜0.015 | 約 $0.27〜0.45 |
#
# **前提が欠けていれば 1 回も呼ばずに終わる（$0）。**
#
# **フォロー・アンフォローはしない。Chrome を kill しない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/kickstart-and-count.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$W/data/post_queue.json"
UID_NUM="$(id -u)"
LOCK=/tmp/x-login-in-progress

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }

count_posted() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  console.log((q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")
    &&(e.x_tweet_id||e.tweet_id)).length);
}catch(e){ console.log(-1); }
' "$QJSON" 2>/dev/null || echo -1
}

{
echo "# 定時を待たず、いま返信を出す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 最上位ルール 9: **「次の定時実行を待つ」は、ほぼ全部 やらなくていい待ち。**"
echo "> 定時は 12:00 / 16:00 / 19:00 / 22:00 で、**次まで最大 4 時間。**"
echo "> 悪循環を断った直後なので、**本当に出るかを今すぐ確かめる。**"

# ═══════════ 1. 前提 ═══════════
echo
echo "## 1. 前提（**欠けていたら走らせない**）"
echo
echo '```'
OK=1
if cdp_ok; then echo "  CDP            : 健全"
else echo "  CDP            : **落ちている** → 走らせない"; OK=0; fi

if launchctl list 2>/dev/null | grep -qF 'ai.openclaw.comment-warmup'; then
  echo "  comment-warmup : ロード済み"
else
  echo "  comment-warmup : **未ロード** → 走らせない"; OK=0
fi

if [ -f "$LOCK" ]; then echo "  login ロック   : **有る** → 走らせない"; OK=0
else echo "  login ロック   : 無い（正常）"; fi

AI_N=$(launchctl list 2>/dev/null | awk '{print $3}' | grep -c '^ai\.openclaw\.' || true)
AI_N=$(printf '%s' "${AI_N:-0}" | tr -dc '0-9'); [ -z "$AI_N" ] && AI_N=0
echo "  ai.openclaw.*  : ${AI_N} 本$( [ "$AI_N" -le 1 ] && echo '（**tab-guard の halt 署名**）' )"
echo '```'

if [ "$OK" != "1" ]; then
  echo
  echo "**前提が欠けている。LLM を 1 回も呼ばずに終わる（\$0）。**"
  echo "上の欄で **落ちている / 未ロード / 有る** になっているものを先に直す。"
  exit 0
fi

# ═══════════ 1-B. 番人を載せ直す ═══════════
echo
echo "## 1-B. 番人（\`x-loop-guardian\`）を載せ直す"
echo
echo "\`x28\` は「**ロードした**」と出したが \`番人: 0 本\` だった。**理由まで出す。**"
echo "番人が居ないと、15 分ごとの自己修復が動かない。"
echo
echo '```'
GLBL="ai.openclaw.x-loop-guardian"
GP="$HOME/Library/LaunchAgents/$GLBL.plist"
GSH="$S/x-loop-guardian.sh"
if launchctl list 2>/dev/null | grep -qF "$GLBL"; then
  echo "  既にロード済み。触らない。"
elif [ ! -f "$GSH" ]; then
  echo "  **番人スクリプトが無い: $GSH**（x28 が置けていない）"
elif [ ! -f "$GP" ]; then
  echo "  **plist が無い: $GP**"
else
  echo "  plist: $(plutil -lint "$GP" 2>&1 | head -1)"
  echo "  --- launchctl print の言い分 ---"
  launchctl print "gui/${UID_NUM}/$GLBL" 2>&1 | head -5 | sed 's/^/    /' | clean
  echo "  --- enable → bootstrap ---"
  launchctl enable "gui/${UID_NUM}/$GLBL" 2>&1 | head -2 | sed 's/^/    /' | clean
  launchctl bootstrap "gui/${UID_NUM}" "$GP" 2>&1 | head -3 | sed 's/^/    /' | clean
  echo "  --- load -w も試す ---"
  launchctl load -w "$GP" 2>&1 | head -3 | sed 's/^/    /' | clean
  echo
  echo "  **載ったか: $(launchctl list 2>/dev/null | grep -cF "$GLBL" || true) 本**"
fi
echo '```'

# ═══════════ 2. 走らせる前 ═══════════
echo
echo "## 2. 走らせる前の実投稿数（**キューの \`x_tweet_id\`**）"
echo
echo '```'
BEFORE="$(count_posted)"
echo "  投稿済み 累計: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then echo; echo "  **キューが読めない。何もしない。**"; exit 1; fi
"$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
const t=new Date(Date.now()+9*3600*1000).toISOString().slice(0,10);
const today=rows.filter(e=>{const d=new Date(e.posted_at||e.created_at||0);
  return !isNaN(d) && new Date(d.getTime()+9*3600*1000).toISOString().slice(0,10)===t;});
console.log("  今日（JST）出た数: "+today.length+" 件");
const last=rows[rows.length-1];
if(last) console.log("  最後の 1 件: "+(last.posted_at||last.created_at));
' "$QJSON" 2>&1 | clean
echo '```'

# ═══════════ 3. 即実行 ═══════════
echo
echo "## 3. \`kickstart -k\` で即実行"
echo
echo "**最大 4 件・約 \$0.012。** 候補が無ければ \$0 で終わる。"
echo
echo '```'
launchctl kickstart -k "gui/${UID_NUM}/ai.openclaw.comment-warmup" 2>&1 | head -3 | sed 's/^/  /' | clean
echo "  (rc=$?)"
echo
echo "  --- 3 分 待つ（この処理は実績上 3 分かかる） ---"
for i in 60 120 180; do
  sleep 60
  N="$(count_posted)"
  printf '    %3s 秒後: 累計 %s 件\n' "$i" "$N"
done
echo '```'

# ═══════════ 4. 結果 ═══════════
echo
echo "## 4. 実際に出たか（**一次情報**）"
echo
echo '```'
AFTER="$(count_posted)"
DIFF=$(( AFTER - BEFORE ))
echo "  走らせる前: ${BEFORE} 件"
echo "  走らせた後: ${AFTER} 件"
echo "  **今回 出た数: ${DIFF} 件**"
echo
if [ "$DIFF" -gt 0 ]; then
  echo "  --- 出た返信 ---"
  "$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const n=Number(process.argv[2]);
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
rows.slice(-n).forEach(e=>{
  console.log("  "+(e.posted_at||e.created_at));
  console.log("  https://x.com/heng_ji31590/status/"+(e.x_tweet_id||e.tweet_id));
  console.log("  "+String(e.text||"").replace(/\n/g,"\n  "));
  console.log("");
});
' "$QJSON" "$DIFF" 2>&1 | clean
else
  echo "  **出ていない。** 下のログで理由を見る。"
fi
echo '```'

echo
echo "### \`comment-warmup.log\` の今回の行"
echo
echo '```'
tail -30 "$W/logs/comment-warmup.log" 2>/dev/null | cut -c1-175 | sed 's/^/  /' | clean
echo '```'

echo
echo "### 実費（この実行ぶん）"
echo
echo '```'
if [ -f "$W/logs/llm-usage.log" ]; then
  echo "  --- llm-usage.log の末尾（x31 で記録を入れた） ---"
  tail -6 "$W/logs/llm-usage.log" 2>/dev/null | sed 's/^/    /'
else
  echo "  llm-usage.log がまだ無い（x31 の記録が入っていないか、まだ生成していない）"
fi
echo '```'

echo
echo "---"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo "1 件 **\$0.003 は実測**。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（最大 4 件・一度きり） | 約 **\$0.012** | — | **\$0** |"
echo "| 返信の定常運用（**実測** 3〜5 件/日） | \$0.003 | \$0.009〜0.015 | 約 **\$0.27〜0.45** |"
echo "| フォロー・アンフォロー（DOM 操作） | \$0 | \$0 | **\$0** |"
echo
echo "**フォロー・アンフォローはしていない。Chrome も kill していない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
D="$(grep -m1 -oE '\*\*今回 出た数: -?[0-9]+ 件\*\*' "$OUT" 2>/dev/null || echo '')"
P="$(grep -m1 -oE '前提が欠けている' "$OUT" 2>/dev/null || echo '')"
echo "**$(date '+%H:%M') 定時を待たず即実行（最大 \$0.012）** / ${P:-$D} / $(basename "$OUT")"
