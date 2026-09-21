#!/bin/bash
# **pipeline-heartbeat の「いま」の判定とコスト実額を読む。測るだけ。費用 $0。**
#
# ## exit 2 は落ちているのではない（先に確定させておく）
#
# x118 の表で `ai.openclaw.pipeline-heartbeat` が `last exit code = 2` だったが、
# **これは異常終了ではない。** 2026-09-20 の `x90` のレポートで確定している。
#
#   overall = CRIT
#        OK    login / chrome_cdp / comment_posts_24h / …
#     ** CRIT  grok_trending_fire       no fire >24h
#     ** INFO  cost_24h_usd             $0.021
#
# **`overall=CRIT` のとき 2 を返す**という設計で、コスト集計はその中で出ている。
#
# ## それでも読みに行く理由
#
# **上のレポートは 2026-09-20 のもので、「いま」ではない**（最上位ルール 11）。
# `heartbeat.json` に `cost_24h_usd` は載っていないので、クラウドからは読めない。
#
# **返信の量を増やすかどうかの判断材料が、この 1 つの数字。**
# 推定（1 件 $0.003 × picks）ではなく、**Mac 側の自己計測**を取りに行く。
#
# ## 何を出すか
#
#   ① **最後の判定 JSON を 1 本**（CRIT / WARN / INFO を全部 並べる）
#   ② **`cost_24h_usd` の実額**（これが目的）
#   ③ その JSON がいつのものか（**古ければ「いま」ではない**）
#   ④ `exit 2` を打っている箇所（設計どおりかの裏取り）
#
# ## やらないこと
#
# **直さない。ジョブを戻さない。設定を変えない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/pipeline-heartbeat-now.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(xoxb-)[A-Za-z0-9-]+#\1<MASKED>#g' \
         -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
         -e 's#("ts":")[0-9.]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

LOG=""
for c in "$L/pipeline-heartbeat.log" "$L/pipeline-heartbeat.stdout.log" "$L/heartbeat.log"; do
  [ -f "$c" ] && LOG="$c" && break
done

{
echo "# pipeline-heartbeat の「いま」（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **\`exit 2\` は落ちているのではない。** \`overall=CRIT\` のとき 2 を返す設計"
echo "> （2026-09-20 の x90 で確定済み）。**だがその数字は「いま」ではない。**"
echo ">"
echo "> **返信の量を増やすかの判断材料は \`cost_24h_usd\` の実額 1 つ。**"
echo "> 推定（1 件 \$0.003 × picks）ではなく、Mac 側の自己計測を取りに行く。"

echo
echo "## 1. ログはどれか。**いつのものか**"
echo
echo '```'
if [ -n "$LOG" ]; then
  # **macOS は `stat -f`**（最上位ルール 14）
  echo "  $LOG"
  echo "  mtime : $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$LOG" 2>/dev/null)"
  echo "  いま  : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  行数  : $(wc -l < "$LOG" | tr -d ' ')"
else
  echo "  **pipeline-heartbeat のログが見つからない。** logs/ の候補:"
  ls -1 "$L" 2>/dev/null | grep -i 'heartbeat\|pipeline' | sed 's/^/    /' || echo "    （無し）"
fi
echo '```'
echo
echo "**mtime が数時間 古ければ、そこで止まっている。** その場合 \$0.021 も「いま」ではない。"

if [ -n "$LOG" ]; then
echo
echo "## 2. 最後の判定（**CRIT / WARN / INFO を全部**）"
echo
echo '```'
grep -o '{"ok":true,"overall":.*' "$LOG" 2>/dev/null | tail -1 | "$NODE_BIN" -e '
let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{
  const t=s.trim();
  if(!t){ console.log("  判定 JSON が 1 本も無い"); return; }
  let j; try{ j=JSON.parse(t); }catch(e){
    // **行が切れていることがある。** そのときは読めた範囲を出す
    console.log("  JSON が読めない（行が切れている可能性）: "+e.message);
    console.log("  raw(先頭 300): "+t.slice(0,300)); return;
  }
  console.log("  overall = "+j.overall);
  const mark=(l)=> l==="OK" ? "     OK  " : "  ** "+l.padEnd(4);
  for(const r of (j.results||[])){
    console.log(mark(r.level)+" "+String(r.name).padEnd(26)+" "+(r.detail||"")
      + (r.healable?"  （自動復旧できる）":""));
  }
  // **目的の数字を名指しで、もう一度 出す**
  const c=(j.results||[]).find(r=>/cost/.test(r.name||""));
  console.log("");
  console.log("  ===> cost_24h_usd = " + (c ? c.detail : "**出ていない**"));
});' 2>&1 | clean
echo '```'

echo
echo "## 3. コストの実額（**ここが目的**）"
echo
echo "**推定ではなく Mac 側の自己計測。** 過去の値と並べて、動いているかを見る。"
echo
echo '```'
echo "  --- ログに出た cost_24h_usd を新しい順に 8 件 ---"
grep -o 'cost_24h_usd[^,}]*' "$LOG" 2>/dev/null | tail -8 | sed 's/^/    /' || echo "    （無し）"
echo
echo "  --- 判定 JSON が何本あるか（＝何回 走ったか）---"
n="$(grep -c '"overall"' "$LOG" 2>/dev/null | head -1)"
case "$n" in ''|*[!0-9]*) n=0 ;; esac
echo "    $n 本"
echo '```'
echo
echo "**参考（\`docs/recurring-job-costs.md\` の実測）**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 2026-09-20 の \`cost_24h_usd\` | **\$0.021/日**（≒ \$0.63/月） |"
echo "| 生成 1 件（2026-09-06 実測） | **\$0.003** |"
echo "| 上限（**安全弁であって実績ではない**） | \$0.048/日・\$1.44/月 |"

echo
echo "## 4. \`exit 2\` はどこで打たれているか（裏取り）"
echo
echo '```'
for f in "$S/pipeline-heartbeat.sh" "$S/pipeline-heartbeat.js" "$S/pipeline-health.js"; do
  [ -f "$f" ] || continue
  echo "  ===== $(basename "$f") ====="
  grep -n -B2 -A2 'exit(2)\|exit 2\|process.exit(2)' "$f" 2>/dev/null | cut -c1-160 | sed 's/^/    /'
  echo
done
echo '```'
echo
echo "**\`overall===\"CRIT\"\` のときだけ 2 なら、2 は正常な報告。** 直すものではない。"
fi

echo
echo "## 5. 読み方"
echo
echo "| 出方 | 意味 |"
echo "| --- | --- |"
echo "| \`cost_24h_usd\` が出ていて mtime が新しい | **測れている。** この実額で量の増減を判断できる |"
echo "| \`cost_24h_usd\` が出ていない | 集計が壊れている。**先に直す** |"
echo "| mtime が古い | ジョブが止まっている。数字は「いま」ではない |"
echo "| CRIT が \`grok_trending_fire\` だけ | **戻していない LLM ジョブが鳴っているだけ**（設計どおり） |"
echo "| CRIT が他にもある | そちらを見る |"

echo
echo "## 6. 費用"
echo
echo "**ログとソースを読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "pipeline-heartbeat のいまとコスト実額 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
