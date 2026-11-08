#!/bin/bash
# **大人のキッザニア（クリスマス版）の告知スレッドを、いま 1 回だけ出す（x438）。費用 $0。**
# 利用者（2026-11-08 チャット）:「キッザニアの方はコメントしたので、私の確認は特にいりません。コメントした修正を反映したら、そのまま投稿してください。今日この後すぐにやってください。」
POST_APPROVAL_QUOTE="コメントした修正を反映したら、そのまま投稿してください。今日この後すぐにやってください。"
POST_APPROVAL_AT="2026-11-08 17:2x JST（チャット）"
POST_SET_KEY="news-kidzania-adult"
#
# 文面は posts.json の news-kidzania-adult（[1/2] 重み 274・利用者がページで書き換えた「大人」の版／[2/2] 記事とイベントマップの紹介 208）。
# 画像は [1/2] に 3 枚: 2-point（まとめ）→ 1-official（公式キービジュアル）→ 3-price（公式の料金表）。出所は ALT に入れる。
# 作り: origin/main から取る → キューに auto_publish:false で積む → run-publish.sh をいま 1 回だけ走らせる → tweet_id を書き戻す。
# ALT で失敗して 1 本目が出なかったときだけ、ALT なしで 1 回だけ出し直す（11/4 の湾岸5 と同じ判断。x425 で直したが本番では未確認）。
# **二重投稿を防ぐ:** 同じ id がキューに在れば止める。**LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail
ID="x-news-20261108-kidzania-adult"
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
SLUG="kidzania-tokyo-adult-christmas-2026"
IMGDIR="$D/x-$SLUG"; SRCDIR="public/images/$SLUG/x"
ALTF="$D/.x438-kidzania-alts.json"; LOG="$W/logs/publish-kidzania-now.log"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x438-post-kidzania-now.md"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g; s/(Bearer )[A-Za-z0-9._-]{12,}/$1<伏せ>/g'; }
{
echo "# 大人のキッザニアをいま出す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## 1. 画像 3 枚を origin/main から取る"; echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null || true
mkdir -p "$IMGDIR"; CSV=""; N=0
for f in 2-point.jpg 1-official.jpg 3-price.jpg; do
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$IMGDIR/$f" 2>/dev/null && [ "$(wc -c < "$IMGDIR/$f" | tr -d ' ')" -ge 50000 ]; then
    printf '  %-16s %8s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"; CSV="${CSV:+$CSV,}$IMGDIR/$f"; N=$((N + 1))
  else printf '  %-16s **取れない**\n' "$f"; fi
done
printf '  対象 3 枚 / 取れた %s 枚\n' "$N"
echo '```'
[ "$N" = "3" ] || { echo "- **画像が揃わない。出さずに止まる。**"; exit 1; }
echo; echo "## 2. 文面を確かめて積む"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs"),{execFileSync}=require("child_process");
const [qp,id,csv,repo,altf]=process.argv.slice(1);
const show=p=>execFileSync("git",["-C",repo,"show","origin/main:"+p],{encoding:"utf8",maxBuffer:16*1024*1024});
const t=JSON.parse(show("scripts/image-review/posts.json"))["news-kidzania-adult"];
const w=s=>{let n=0;for(const c of s.replace(/https?:\/\/\S+/g,"#".repeat(23)))n+=c.codePointAt(0)<0x80?1:2;return n};
if(!Array.isArray(t)||t.length!==2){console.log("FAIL 文面が 2 本ではない");process.exit(1);}
if(!t[0].startsWith("「大人」のキッザニア")||!t[0].includes("→ 公式 https://www.kidzania.jp/tokyo/over16")){console.log("FAIL 利用者が直した版ではない");process.exit(1);}
if(!t[1].includes("/posts/kidzania-tokyo-adult-christmas-2026/")){console.log("FAIL [2/2] に記事の URL が無い");process.exit(1);}
t.forEach((x,i)=>console.log("  ["+(i+1)+"/2] 文字 "+x.length+" ／ 重み "+w(x)));
if(w(t[0])>275||w(t[1])>275){console.log("FAIL 重みが 275 を超える");process.exit(1);}
const pj=JSON.parse(show("ops/data/x-cards/kidzania-tokyo-adult-christmas-2026.panels.json"));
const alts=["2-point.jpg","1-official.jpg","3-price.jpg"].map(f=>((pj.panels||[]).find(x=>x.file===f)||{}).alt||"");
if(alts.some(a=>!a)){console.log("FAIL ALT が無い画像がある");process.exit(1);}
fs.writeFileSync(altf,JSON.stringify(alts));console.log("  ALT: "+alts.map((a,i)=>(i+1)+"枚目 "+a.length+"字").join(" ／ "));
const q=JSON.parse(fs.readFileSync(qp,"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);
if(!Array.isArray(rows)){console.log("FAIL キューの配列が取れない");process.exit(1);}
if(rows.some(r=>r&&r.id===id)){console.log("FAIL 同じ id がもう在る（二重投稿を防ぐ）: "+id);process.exit(1);}
rows.push({id,kind:"thread",status:"awaiting_approval",auto_publish:false,created_at:new Date().toISOString(),
 text:t[0],image_path:csv,thread_chain:[{text:t[0],role:"hook",image_path:csv},{text:t[1],role:"cta"}],
 _note:"2026-11-08 利用者「コメントした修正を反映したら、そのまま投稿してください。今日この後すぐにやってください。」。x438 が run-publish.sh でいま 1 回だけ出す。文面は指示なく変えない"});
fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);JSON.parse(fs.readFileSync(qp,"utf8"));
console.log("OK 積んだ: "+id);' "$D/post_queue.json" "$ID" "$CSV" "$REPO" "$ALTF" 2>&1 | clean
QRC=${PIPESTATUS[0]}; echo '```'
[ "$QRC" -eq 0 ] || { echo "- **積めなかった。出していない。**"; exit 1; }
WB="$S/.x438-writeback.js"
cat > "$WB" <<'WBJS'
const fs=require("fs");const [qp,id]=process.argv.slice(2);let raw="";
process.stdin.on("data",d=>raw+=d).on("end",()=>{const q=JSON.parse(fs.readFileSync(qp,"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);
const e=rows.find(x=>x&&x.id===id);if(!e){console.log("[wb] entry なし");return;}e.auto_publish=false;
const line=raw.split(/\r?\n/).filter(l=>l.trim().startsWith("{")).pop();let r=null;try{r=JSON.parse(line)}catch(_){}
const t1=r&&(r.tweet_id||null);const rs=(r&&r.thread_results)||[];const t2=(rs[1]&&(rs[1].reply_tweet_id||rs[1].tweet_id))||null;
if(t1){e.status="posted";e.x_tweet_id=t1;e.posted_at=new Date().toISOString();if(e.thread_chain&&e.thread_chain[0])e.thread_chain[0].x_tweet_id=t1;if(e.thread_chain&&e.thread_chain[1]&&t2)e.thread_chain[1].x_tweet_id=t2;}
e.last_result=r?{ok:!!r.ok,step:r.step||null,error:(r.error||"").slice(0,300)}:{ok:false,step:"no-json"};
fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);console.log("[wb] t1="+t1+" t2="+t2+" ok="+(r&&r.ok));});
WBJS
posted() { "$NODE_BIN" -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);const e=rows.find(x=>x&&x.id===process.argv[2]);process.exit(e&&e.x_tweet_id?0:1)' "$D/post_queue.json" "$ID"; }
echo; echo "## 3. いま出す（ALT あり）"; echo '```'
cd "$W" || exit 1
OUTP="$(ALT_TEXTS_FILE="$ALTF" /bin/bash "$S/run-publish.sh" "$ID" 2>&1)"; RC=$?
printf '[%s] alt rc=%s\n%s\n' "$(date '+%F %T')" "$RC" "$OUTP" >> "$LOG"
printf '%s' "$OUTP" | "$NODE_BIN" "$WB" "$D/post_queue.json" "$ID" 2>&1
echo "run-publish rc=$RC"; printf '%s\n' "$OUTP" | tail -n 12 | cut -c1-240 | clean
echo '```'
if ! posted; then
  echo; echo "## 3-b. 1 本目が出ていない。ALT なしで 1 回だけ出し直す"; echo '```'
  OUTP="$(/bin/bash "$S/run-publish.sh" "$ID" 2>&1)"; RC=$?
  printf '[%s] noalt rc=%s\n%s\n' "$(date '+%F %T')" "$RC" "$OUTP" >> "$LOG"
  printf '%s' "$OUTP" | "$NODE_BIN" "$WB" "$D/post_queue.json" "$ID" 2>&1
  echo "run-publish rc=$RC"; printf '%s\n' "$OUTP" | tail -n 12 | cut -c1-240 | clean
  echo '```'
fi
echo; echo "## 4. キューの結果（一次情報）"; echo '```'
"$NODE_BIN" -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);const e=rows.find(x=>x&&x.id===process.argv[2]);
console.log(JSON.stringify({status:e&&e.status,x_tweet_id:e&&e.x_tweet_id||null,thread_chain_ids:((e&&e.thread_chain)||[]).map(c=>c&&c.x_tweet_id||null),last_result:e&&e.last_result||null}));' "$D/post_queue.json" "$ID" 2>&1
echo '```'
echo; echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
