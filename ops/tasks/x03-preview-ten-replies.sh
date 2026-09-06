#!/bin/bash
# **配線した全文生成で、返信案を 10 件 作って見せる。費用 約 $0.03（承認済み）。**
#
# ## 承認の記録
#
# 2026-09-06、利用者が「10 件で出す（約 $0.03）」を選択。
# **Haiku 4.5・10 回まで。**上限を超えたら止まる。日次・月次の反復コストは増えない。
#
# ## 何のためか
#
# `x02` で配線した `asuka-reply.cjs` が **実機で動くか**と、
# **文面がキャラとして成立しているか**を、投稿する前に確かめる。
#
# 9/2 に止めた理由は品質だった（『トンチンカン』『AI が自動で返信しているのが
# バレバレ』）。**同じ状態で再開しないために、人が読む。**
#
# ## やること
#
#   1. 候補を検知で取る（Playwright の DOM 取得のみ・**LLM 不使用＝$0**）
#   2. 入口フィルタ `ng-filter-candidates.cjs` を通す（$0）
#   3. **`comment-orchestrator.sh` と同じ形**で `asuka-reply.cjs` に渡す
#      （`{trend: <候補>, kind: "comment"}`）
#   4. 出口ゲート `tone-gate.cjs` を通す（$0）
#   5. **相手の投稿を全文つけて**、返信案と一緒に出す
#
# ## やらないこと
#
# **投稿しない。enqueue しない。フォローしない。`comment-warmup` を起動しない。**
# **11 回目の LLM を呼ばない。**
#
# **ハンドルは伏せる。** 相手の投稿は切らずに出す（判断に要る）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/preview-ten-replies.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
MAX_LLM=10
PICKS="/tmp/x03-picks.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# 返信案 10 件（配線後の実機・$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **投稿していない。enqueue もしていない。ジョブも起動していない。**"
echo "> 候補の取得は Playwright の DOM 取得のみ（**LLM 不使用＝\$0**）。"
echo "> **LLM は $MAX_LLM 回まで**（約 \$0.03 で必ず止まる）。相手の投稿は**全文**。"

echo
echo "## 0. 配線を確認する"
echo
echo '```'
grep -nE 'asuka-fill|asuka-reply|tone-gate|ng-filter' "$S/comment-orchestrator.sh" 2>/dev/null | clean
echo '```'
FILL=$(grep -c 'asuka-fill.js' "$S/comment-orchestrator.sh" 2>/dev/null || echo 0)
REPLY=$(grep -c 'asuka-reply.cjs' "$S/comment-orchestrator.sh" 2>/dev/null || echo 0)
echo
echo "- \`asuka-fill.js\`（旧）: **${FILL} 箇所** / \`asuka-reply.cjs\`（新）: **${REPLY} 箇所**"
if [ "$REPLY" -lt 1 ]; then
  echo
  echo "- **配線されていない。生成しない（\$0 のまま終わる）。**"
  exit 1
fi

echo
echo "## 1. 部品の点検（**呼ぶ前に**）"
echo
echo '```'
OKALL=1
for f in asuka-reply.cjs reply-relevance-check.cjs tone-gate.cjs ng-filter-candidates.cjs anthropic-client.js; do
  if [ -f "$S/$f" ] && "$NODE_BIN" --check "$S/$f" 2>/dev/null; then printf '  OK    %s\n' "$f"
  else printf '  **NG** %s\n' "$f"; OKALL=0; fi
done
for f in reply-style-prompt.json reply-relevance-rules.json reply-ng-rules.json reply-tone-rules.json; do
  if [ -f "$W/data/$f" ] && "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$W/data/$f" 2>/dev/null; then printf '  OK    data/%s\n' "$f"
  else printf '  **NG** data/%s\n' "$f"; OKALL=0; fi
done
echo '```'
[ "$OKALL" != "1" ] && { echo; echo "- **部品が欠けている。生成しない（\$0 のまま終わる）。**"; exit 1; }

echo
echo "## 2. 候補を取る（**LLM 不使用・\$0**）"
echo
echo '```'
DET="$S/trend-detect.js"
if [ ! -f "$DET" ]; then
  echo "  trend-detect.js が無い。scripts/ の候補:"
  ls "$S" | grep -iE 'trend|detect|pick' | head -10 | sed 's/^/    /'
else
  : > "$PICKS"
  for r in 1 2 3; do
    "$NODE_BIN" "$DET" > "/tmp/x03-det-$r.json" 2>/dev/null || true
    n="$("$NODE_BIN" -e '
try{const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const a=Array.isArray(d)?d:(d.trends||d.candidates||d.picks||[]);console.log(a.length)}catch(e){console.log(0)}' "/tmp/x03-det-$r.json")"
    echo "  検知 $r 周目 → $n 件"
  done
  "$NODE_BIN" -e '
const fs=require("fs");
let all=[];
for(const r of [1,2,3]){
  try{const d=JSON.parse(fs.readFileSync("/tmp/x03-det-"+r+".json","utf8"));
    const a=Array.isArray(d)?d:(d.trends||d.candidates||d.picks||[]);all=all.concat(a);}catch(e){}
}
const seen=new Set(), out=[];
for(const t of all){
  const txt=String(t&&t.text||"");
  if(txt.length<20) continue;
  const k=(t.tweet_url||txt).slice(0,80);
  if(seen.has(k)) continue; seen.add(k); out.push(t);
}
fs.writeFileSync(process.argv[1], JSON.stringify(out.slice(0,40),null,1));
console.log("  重複と短文を除いて "+Math.min(out.length,40)+" 件");
' "$PICKS" 2>&1 | clean
fi
echo '```'
[ -s "$PICKS" ] || { echo; echo "- **候補が取れない。生成しない（\$0 のまま終わる）。**"; exit 1; }

echo
echo "### 入口フィルタ \`ng-filter-candidates.cjs\`（\$0）"
echo
echo '```'
"$NODE_BIN" -e 'const a=require(process.argv[1]);console.log(JSON.stringify(a))' "$PICKS" \
  | "$NODE_BIN" "$S/ng-filter-candidates.cjs" > /tmp/x03-filtered.json 2>/dev/null || cp "$PICKS" /tmp/x03-filtered.json
"$NODE_BIN" -e '
const fs=require("fs");
let d=[]; try{ d=JSON.parse(fs.readFileSync("/tmp/x03-filtered.json","utf8")); }catch(e){}
const a=Array.isArray(d)?d:(d.candidates||d.trends||[]);
fs.writeFileSync("/tmp/x03-use.json", JSON.stringify(a,null,1));
console.log("  通過: "+a.length+" 件");
' 2>&1 | clean
echo '```'

echo
echo "## 3. 返信案（**LLM は $MAX_LLM 回まで**）"
echo
"$NODE_BIN" -e '
const fs=require("fs"), {execFileSync}=require("child_process");
const S=process.argv[1], MAX=Number(process.argv[2]);
let list=[]; try{ list=JSON.parse(fs.readFileSync("/tmp/x03-use.json","utf8")); }catch(e){}
const w=s=>{let n=0;for(const c of String(s||""))n+=c.codePointAt(0)<0x80?1:2;return n};
let used=0, ok=0, skipped=0;
const extra=[];
for(const t of list){
  if(used>=MAX) break;
  used++;
  let out="";
  try{
    out=execFileSync("/usr/local/bin/node",[S+"/asuka-reply.cjs"],{
      input:JSON.stringify({trend:t,kind:"comment"}),
      encoding:"utf8", maxBuffer:8*1024*1024,
      env:Object.assign({},process.env,{OPS_EXTRA_RECENT:JSON.stringify(extra)})
    });
  }catch(e){ out=(e.stdout||"")+""; if(!out) out=JSON.stringify({ok:false,error:String(e.message).slice(0,200)}); }
  // 出口ゲート
  let gated=out;
  try{
    gated=execFileSync("/usr/local/bin/node",[S+"/tone-gate.cjs"],{input:out,encoding:"utf8"});
  }catch(e){ /* ゲートが落ちたら素の出力を見る */ }
  let r=null; try{ r=JSON.parse(String(gated).trim().split("\n").pop()); }catch(e){}
  console.log("---");
  console.log("");
  if(r&&r.ok&&r.text){
    ok++;
    extra.push(r.text);
    console.log("### 案 "+ok);
  }else{
    skipped++;
    console.log("### 弾いた "+skipped);
  }
  console.log("");
  console.log("**相手の投稿**");
  console.log("");
  console.log("```text");
  console.log(String(t.text||"").trim());
  console.log("```");
  console.log("");
  if(r&&r.ok&&r.text){
    console.log("**返信案**");
    console.log("");
    console.log("> "+String(r.text).replace(/\n/g,"\n> "));
    console.log("");
    console.log("- "+[...String(r.text)].length+" 字 / "+w(r.text)+" weight（上限 280）");
    if(r.shared) console.log("- 共有した語: `"+(Array.isArray(r.shared)?r.shared.join(", "):r.shared)+"`");
    if(r.warns&&r.warns.length) console.log("- 注意: "+r.warns.join(" / "));
  }else{
    console.log("**返信しない**");
    console.log("");
    console.log("- 理由: `"+((r&&(r.reason||r.error))||"生成器が JSON を返さなかった")+"`");
  }
  console.log("");
}
console.log("---");
console.log("");
console.log("- LLM 呼び出し: **"+used+" / "+MAX+" 回**（約 $"+(used*0.003).toFixed(3)+"）");
console.log("- 返信する: **"+ok+" 件** / 返信しない: **"+skipped+" 件**");
' "$S" "$MAX_LLM" 2>&1 | clean

echo
echo "---"
echo
echo "**投稿していない。enqueue もしていない。\`comment-warmup\` も起動していない。**"
echo "**文面を読んでから起動する。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'LLM 呼び出し' "$OUT" 2>/dev/null; then
  echo "**返信案を出した（投稿なし・起動なし）** / $(basename "$OUT")"
else
  echo "**生成まで届いていない。レポートを読むこと** / $(basename "$OUT")"
fi
