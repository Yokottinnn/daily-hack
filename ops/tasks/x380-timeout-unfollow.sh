#!/bin/bash
# **外す処理が止まったままにならないよう、時間切れを入れる（x380）。$0。**
# x379: reply-followers-cleanup は unfollow-handle を時間切れなしで呼び、unfollow-handle が止まると親子とも 15 時間止まった。外す予定が 664 人分たまっていた。
# ① reply-followers-cleanup.js の execSync 2 か所に timeout: 120000 ② unfollow-handle.js の先頭に「2 分で必ず終わる」と「押す前に空くまで待つ（unfollow・最大 150 秒）」
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/x380-timeout-unfollow.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 外す処理に時間切れを入れる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
RF="$S/reply-followers-cleanup.js"; UH="$S/unfollow-handle.js"
cp -p "$RF" "$RF.bak-x380"; cp -p "$UH" "$UH.bak-x380"
"$NODE_BIN" -e '
const fs=require("fs");const p=process.argv[1];let s=fs.readFileSync(p,"utf8");
const before=(s.match(/maxBuffer: 8 \* 1024 \* 1024 \}\)/g)||[]).length;
s=s.replace(/\{ encoding: "utf8", maxBuffer: 8 \* 1024 \* 1024 \}\)/g,"{ encoding: \"utf8\", maxBuffer: 8 * 1024 * 1024, timeout: 120000 })");
fs.writeFileSync(p,s);console.log("reply-followers-cleanup.js: execSync に時間切れ "+before+" か所");' "$RF"
if grep -q 'x380:' "$UH"; then echo "unfollow-handle.js: もう入っている"; else
"$NODE_BIN" -e '
const fs=require("fs");const p=process.argv[1];const L=fs.readFileSync(p,"utf8").split("\n");
const snip="/* x380: 2 分で必ず終わる（止まったまま親を巻き込まない）。押す前に空くまで待つ（30 分 6 回・2 分おき） */ setTimeout(()=>{console.log(JSON.stringify({ok:false,step:\"timeout\",error:\"2 分で打ち切った（x380）\"}));process.exit(2)},120000).unref(); { const _r=require(\"child_process\").spawnSync(process.execPath,[require(\"os\").homedir()+\"/.openclaw/workspace/lib/x-action-pacer.cjs\",\"until\",\"unfollow\",\"100\"],{stdio:[\"ignore\",\"ignore\",\"inherit\"]}); if(_r.status===3){console.log(JSON.stringify({ok:false,step:\"paced\",error:\"間隔待ちで空かなかった\"}));process.exit(1);} }";
let i=0;if(L[0]&&L[0].startsWith("#!"))i=1;for(let k=i;k<Math.min(L.length,i+40);k++){if(/^\s*["\x27]use strict["\x27];?\s*$/.test(L[k])){i=k+1;break}}
L.splice(i,0,snip);fs.writeFileSync(p,L.join("\n"));console.log("unfollow-handle.js: 入れた");' "$UH"
fi
for f in "$RF" "$UH"; do if "$NODE_BIN" --check "$f" 2>/dev/null; then echo "$(basename "$f"): 構文 OK"; else cp -p "$f.bak-x380" "$f"; echo "$(basename "$f"): **構文が壊れたので元に戻した**"; fi; done
grep -c 'timeout: 120000' "$RF" | head -1 | sed 's/^/reply-followers-cleanup.js の時間切れ: /'
echo '```'
echo "**押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x380 / $(basename "$OUT")"
