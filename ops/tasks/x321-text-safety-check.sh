#!/bin/bash
# **12:00 の告知が落ちた理由の 2 回目（x321）。投稿しない。費用 $0。**
#
# x320 で分かったこと: run-publish.sh は失敗時に child_stdout / child_stderr をログの 1 行に入れている。
# x319 はそれを 400 字で切っていた。**今回は JSON として読んで、child_stdout / child_stderr を全部出す。**
#   ① ログの thread-main-exec の行を parse して child_stdout・child_stderr を出す
#   ② lib/text-safety.js の検査（長さ・文字種・絵文字の扱い）を grep する
#   ③ キューに積んだ [1/2] の本文を、post-via-playwright と同じ decodeBase64Safe に通して結果を出す（送信はしない）
# **送信は一切しない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/text-safety-check.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 告知が落ちた理由・2 回目（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo
echo "## 1. ログの child_stdout / child_stderr"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const L=fs.readFileSync(process.argv[1],"utf8").split("\n").filter(l=>l.includes("thread-main-exec"));
if(!L.length){console.log("  行が無い");process.exit(0);}
for(const l of L){ try{ const j=JSON.parse(l.slice(l.indexOf("{")));
  console.log("  step="+j.step); console.log("  child_stdout="+(j.child_stdout||"(空)")); console.log("  child_stderr="+(j.child_stderr||"(空)"));
} catch(e){ console.log("  JSON として読めない: "+e.message+" / 末尾 600 字: "+l.slice(-600)); } }' "$W/logs/publish-prime-oneshot.log" 2>&1 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
echo
echo "## 2. lib/text-safety.js の検査"
echo
echo '```'
wc -l "$S/lib/text-safety.js" | sed 's/^/  /'
grep -nE 'reason|length|280|MAX|limit|emoji|surrogate|replace|\\u|test\(|return \{' "$S/lib/text-safety.js" | cut -c1-200 | head -60
echo '```'
echo
echo "## 3. キューの [1/2] の本文を同じ検査に通す（送信しない）"
echo
echo '```'
cd "$S" && "$NODE_BIN" -e '
const fs=require("fs");const {decodeBase64Safe,weightedLength}=require("./lib/text-safety");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||[]);
const e=rows.find(x=>x&&x.id==="blog-promo-20261018-prime-vs-rakuten"); if(!e){console.log("  エントリが無い");process.exit(0);}
(e.thread_chain||[]).forEach((c,i)=>{ const b64=Buffer.from(c.text,"utf8").toString("base64"); const r=decodeBase64Safe(b64);
  console.log("  ["+(i+1)+"/2] 文字 "+c.text.length+" / weightedLength "+weightedLength(c.text)+" / ok="+r.ok+" reason="+(r.reason||"-")+" details="+JSON.stringify(r.details||null).slice(0,300)); });' "$W/data/post_queue.json" 2>&1
echo '```'
echo
echo "**投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x321 / $(basename "$OUT")"
