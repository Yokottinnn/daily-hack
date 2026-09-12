#!/bin/bash
# **返信が 16 件/日 に届かない理由を、掛け算で分解する。費用 $0。読むだけ。**
#
# ## 指摘（2026-09-08）
#
#   > また、返信が1日1件ペースでしか動いていない
#   > 約束では16件ペースで動くはずなので約束と違うよ
#
# そのとおり。**約束は 16 件/日。実績は 1 件/日。**
#
# ## 分かっていること（9/8 00:03 の実ログ）
#
#   [00:03:14] picked 4 / max 4 (from 23 candidates)
#   [00:03:16] gen failed (#1): 投資判断への助言は避けるべき      ← LLM 呼んだ後
#   [00:03:19] enqueue → 実投稿 1 件
#   [00:03:46] gen failed (#3): PR/アフィリなので LLM を呼ばずに見送る  ← $0
#   [00:03:47] gen failed (#4): hashtag のみで返信する対象がない   ← LLM 呼んだ後
#
# **1 回 × 4 件 × 通過率 25% = 1 件。** 観測と一致する。
#
# そして起動回数が落ちている。
#
#   08-27〜09-01   起動 4 回/日   ← 設計どおり
#   09-02          起動 1 回
#   09-06          起動 2 回
#   09-07          起動 1 回
#
# ## この タスクが測るもの
#
#   1. **plist の発火予定**（何時に何回のはずか）と、**実際の発火時刻**の差
#   2. 各回の `picked` / 実投稿 / skip の内訳（**直近 7 日・1 回ずつ**）
#   3. **skip 理由を「LLM を呼ぶ前」と「呼んだ後」に分ける**
#      → 呼んだ後の skip は**課金だけして 0 件**。ここが無駄
#   4. 候補数（`from N candidates`）の推移
#   5. 発火しなかった時間帯に何があったか（ジョブの rc・Chrome・ログ）
#
# ## 出さないもの
#
# **推測を書かない。** 数字と実際のログ行だけ。
#
# **投稿しない。返信しない。ジョブを触らない。Chrome を触らない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
LOG="$W/logs/comment-warmup.log"
OUT="${OPS_REPORT_DIR:-/tmp}/why-only-one-reply.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$W/data/post_queue.json"
P="$HOME/Library/LaunchAgents/ai.openclaw.comment-warmup.plist"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 返信が 16 件/日 に届かない理由"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 指摘: **「約束では 16 件ペースで動くはずなので約束と違うよ」**"
echo
echo "**16 件/日 は 3 つの掛け算。** どこが落ちているかを数字で出す。"
echo
echo "    1 日の起動回数 × 1 回の pick 数 × 生成の通過率 = 1 日の投稿数"

# ═══════════ 1. 起動回数 ═══════════
echo
echo "## 1. 起動回数（**設計 4 回/日**）"
echo
echo "### 1-a. plist は何時に発火する設定か"
echo
echo '```'
if [ -f "$P" ]; then
  plutil -p "$P" 2>/dev/null | sed -n '/StartCalendarInterval/,/^  }/p' | head -30 | sed 's/^/  /'
  echo
  echo "  StartInterval: $(plutil -extract StartInterval raw "$P" 2>/dev/null || echo '(なし)')"
  echo "  MAX_PICKS_PER_FIRE: $(plutil -extract EnvironmentVariables.MAX_PICKS_PER_FIRE raw "$P" 2>/dev/null || echo '(未設定)')"
  echo "  ロード状態: $(launchctl list 2>/dev/null | grep -F 'ai.openclaw.comment-warmup' | awk '{print "PID="$1" 最後のrc="$2}' || echo '**未ロード**')"
else
  echo "  **plist が無い: $P**"
fi
echo '```'

echo
echo "### 1-b. 実際の発火時刻（直近 10 日・**1 回ずつ**）"
echo
echo "**予定と実際の差がそのまま落ち幅。**"
echo
echo '```'
if [ -f "$LOG" ]; then
  grep -oE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}' "$LOG" 2>/dev/null | tr -d '[' | sort -u | tail -10 | while read -r d; do
    n=$(grep -c "^\[$d.*orchestrator start" "$LOG" 2>/dev/null || echo 0)
    printf '  %s  起動 %s 回   ' "$d" "$n"
    grep "^\[$d.*orchestrator start" "$LOG" 2>/dev/null \
      | grep -oE 'T[0-9]{2}:[0-9]{2}' | tr -d 'T' | tr '\n' ' '
    echo
  done
else
  echo "  **ログが無い: $LOG**"
fi
echo '```'
echo
echo "**予定 4 回に対して実際が 1〜2 回なら、そこで 1/4〜1/2 に落ちている。**"

# ═══════════ 2. 通過率 ═══════════
echo
echo "## 2. 生成の通過率（**4 件 拾って 何件 出るか**）"
echo
echo "### 2-a. 各回の picked と、その回の enqueue 数"
echo
echo '```'
if [ -f "$LOG" ]; then
  grep -E 'orchestrator start|picked [0-9]+|enqueue:|gen failed|orchestrator done' "$LOG" 2>/dev/null \
    | tail -70 | cut -c1-175 | sed 's/^/  /' | clean
else
  echo "  ログが無い"
fi
echo '```'

echo
echo "### 2-b. **skip 理由の内訳（直近 7 日）**"
echo
echo "**\`LLM を呼ばずに\` と書いてあるものは \$0。** それ以外は**課金して 0 件**。"
echo
echo '```'
if [ -f "$LOG" ]; then
  D7="$(grep -oE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}' "$LOG" | tr -d '[' | sort -u | tail -7 | tr '\n' '|' | sed 's/|$//')"
  TOTAL=$(grep -cE "^\[($D7).*gen failed" "$LOG" 2>/dev/null || echo 0)
  FREE=$(grep -E "^\[($D7).*gen failed" "$LOG" 2>/dev/null | grep -c 'LLM を呼ばずに' || echo 0)
  PAID=$((TOTAL - FREE))
  echo "  gen failed 合計         : ${TOTAL} 件"
  echo "  うち LLM を呼ばずに \$0  : ${FREE} 件"
  echo "  **うち課金して 0 件**   : ${PAID} 件  ← ここが無駄"
  echo
  echo "  --- 理由の内訳（多い順） ---"
  grep -E "^\[($D7).*gen failed" "$LOG" 2>/dev/null \
    | grep -oE '"error":"[^"]{0,60}' | sed 's/"error":"//' \
    | sed -E 's/(生成側が skip: ).*(投資|助言|金銭)/\1金銭助言まわり/' \
    | cut -c1-46 | sort | uniq -c | sort -rn | head -12 | sed 's/^/    /' | clean
  echo
  echo "  --- 成功（enqueue）した回数 ---"
  echo "    $(grep -cE "^\[($D7).*enqueue:" "$LOG" 2>/dev/null || echo 0) 件"
fi
echo '```'
echo
echo "**「hashtag のみ」「本文が短い」は LLM を呼ぶ前に落とせるはず。**"
echo "**そこを前段に移すと、件数を増やしながらコストが下がる。**"

# ═══════════ 3. 候補数 ═══════════
echo
echo "## 3. 候補数の推移（**検知は足りているか**）"
echo
echo '```'
if [ -f "$LOG" ]; then
  grep -oE '^\[[0-9-]{10}.*from [0-9]+ candidates' "$LOG" 2>/dev/null | tail -20 \
    | sed -E 's/^\[([0-9-]{10})T([0-9:]{5}).*picked ([0-9]+) \/ max ([0-9]+) \(from ([0-9]+).*/  \1 \2  候補 \5 件 → picked \3\/\4/' \
    | sed 's/^/  /'
fi
echo '```'
echo
echo "**候補が pick 数より多ければ、検知はボトルネックではない。**"

# ═══════════ 4. 実績 ═══════════
echo
echo "## 4. 実際に出た件数（**キューの \`x_tweet_id\` で数える**）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
let q; try{ q=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }
catch(e){ console.log("  キューが読めない"); process.exit(0); }
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
const by={};
rows.forEach(e=>{
  const d=new Date(String(e.posted_at||e.created_at||""));
  if(isNaN(d)) return;
  const k=new Date(d.getTime()+9*3600*1000).toISOString().slice(0,10);
  by[k]=(by[k]||0)+1;
});
console.log("  投稿済み 累計: "+rows.length+" 件");
console.log("");
console.log("  日付(JST)     実績   目標   達成率");
Object.keys(by).sort().slice(-10).forEach(d=>{
  const n=by[d];
  console.log("  "+d+"   "+String(n).padStart(3)+" 件   16 件   "+Math.round(n/16*100)+"%");
});
' "$QJSON" 2>&1 | clean
echo '```'

# ═══════════ 5. 発火しなかった時間 ═══════════
echo
echo "## 5. 発火しなかった時間帯に何があったか"
echo
echo '```'
echo "  --- comment-warmup の最後の rc ---"
launchctl list 2>/dev/null | grep -F 'ai.openclaw.comment-warmup' \
  | awk '{print "    PID="$1" 最後のrc="$2}' || echo "    **未ロード**"
echo
echo "  --- Chrome はいつから動いているか ---"
ps -eo pid,lstart,etime,comm 2>/dev/null | grep -i 'Google Chrome' | grep -v ' grep' \
  | head -3 | sed 's/^/    /'
echo
echo "  --- chrome-cdp-heal は止まっているか（2026-09-08 に停止した） ---"
launchctl list 2>/dev/null | grep -c 'chrome-cdp-heal' | sed 's/^/    ロード数: /'
echo
echo "  --- comment-warmup.log の末尾 15 行 ---"
tail -15 "$LOG" 2>/dev/null | cut -c1-175 | sed 's/^/    /' | clean
echo '```'

echo
echo "---"
echo
echo "## まとめ方"
echo
echo "**16 件/日 に届けるには、落ちている箇所を全部 直す必要がある。**"
echo
echo "| 要素 | 直し方 | コストへの影響 |"
echo "| --- | --- | --- |"
echo "| 起動回数 4 → 1 | 発火しない原因を直す | 増える（本来の設計） |"
echo "| 通過率 25% | **前段フィルタを強化** | **下がる**（無駄な LLM を減らす） |"
echo "| pick 数 | 増やす | 線形に増える |"
echo
echo "**投稿していない。ジョブも Chrome も触っていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
F="$(grep -m1 -oE '起動 [0-9]+ 回' "$OUT" 2>/dev/null || echo '起動回数 不明')"
P2="$(grep -m1 -oE '\*\*うち課金して 0 件\*\*   : [0-9]+ 件' "$OUT" 2>/dev/null | grep -oE '[0-9]+ 件' || echo '')"
echo "**$(date '+%H:%M') 16 件/日 に届かない理由を分解（\$0）** / 課金して 0 件だったもの $P2 / $(basename "$OUT")"
