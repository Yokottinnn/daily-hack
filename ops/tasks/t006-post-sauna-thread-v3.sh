#!/bin/bash
# **サウナ告知のスレッド [1/2]+[2/2] を X へ出す（t004/t005 の失敗を直した版）。**
#
# ## t004 が出せなかった理由（実測で確定）
#
# t004 は `auto-x-publisher.js blog-promo` に拾わせようとしたが、
# `pickEntry()` の `blog-promo` 分岐は **5 条件すべての AND** である
# （`scripts/auto-x-publisher.js` の該当行を「## 1. 契約」で本文に出す）。
# t004 が積んだエントリは **5 条件すべてを外していた**。
#
#     条件                  要求                    t004 の実際
#     status                awaiting_approval       pending
#     kind                  "thread"                "blog-promo"
#     id の接頭辞           "blog-promo-"           "sauna-x-"
#     auto_publish          true                    フィールドなし
#     scheduled_at          now 以前                フィールドなし
#
# 根本は `auto-x-publisher.js:6` のコメントの読み違いである。
#
#     kind = blog-promo (== thread + blog-promo- prefix)
#
# `blog-promo` は**コマンドラインのモード名**であって、エントリの `kind` の値ではない。
# エントリ側は `kind:"thread"` かつ id が `blog-promo-` 始まりでなければならない。
#
# t004 にはさらに 2 つ誤りがあった。
#
#   - **画像のフィールド名が違う。** t004 は publisher のソースに `images` という
#     文字列が含まれるかだけを見て `images` を選んだが、実際に読まれるのは
#     `run-publish.sh` の **`image_path`**（**カンマ区切り**で最大 4 枚）である。
#     `post-via-playwright.js:31` が `split(",")` している。
#   - **`queue-manager.js` に `approve` は存在しない。**
#     ある case は next-pending / show / list-awaiting / list-by-status /
#     mark-drafted / mark-skipped / mark-posted / enqueue / mark-dm-sent の 9 つだけ。
#
# ## t005（[2/2]）が構造的に出せなかった理由
#
# t005 は [1/2] の tweet id を待ってから `auto-x-publisher.js blog-promo` を
# もう一度叩く設計だった。**これは [1/2] が成功していても失敗する。**
# `pickEntry()` は同じ日に blog-promo thread が投稿済みなら
# `skip: "blog-promo already posted today"` を返すからである。
# **同日に 2 回 auto-publisher で出すことはできない。**
#
# ## だからこの版は auto-x-publisher を使わない
#
# `run-publish.sh <id>` が本体であり、**`thread_chain[]` を解釈して
# 1 本目を本投稿、2 本目以降を直前への reply として順に出す**（v3.2）。
# [1/2] と [2/2] を **1 エントリ・1 回の呼び出し**で出せるので、
# 「t004 が出す→t005 が待つ」という壊れた受け渡し自体が要らなくなる。
#
# ## 積むことと出すことを分ける
#
# ops-heartbeat はタスクを **1 回しか走らせない**（`ops-heartbeat.sh:162` が
# rc に関係なく `done/<task>.sh` を書く）。t005 はこれで焼き切れた。
# そこでこのタスクは **id を固定して冪等に積み**、投稿できなかった場合も
# **エントリを正しい形でキューに残す**。あとはログイン後に
# `run-publish.sh <id>` を 1 回叩けば出る状態にしておく。
#
# ## 自動投稿には拾わせない
#
# 積むときの status は **`pending` のまま**にし、`auto_publish` も付けない。
# `pickEntry()` の 5 条件を意図的に外してあるので、**定時の auto-publisher が
# 勝手に出すことはない**。出すのはこのスクリプトの明示的な呼び出しだけである。
#
# ## 出す前に Chrome を確かめる
#
# `run-publish.sh` は冒頭で `ensure-chrome.sh` を呼ぶ。ensure-chrome.sh 自身の
# 注記のとおり **cookie がディスクに永続化できておらず、再起動＝即ログアウト**である。
# ログアウト状態のまま thread_chain を走らせると **[1/2] だけ出て [2/2] が落ちる**
# 中途半端なスレッドになりうる。**CDP が健全でなければ出さない。**
#
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-sauna-v3.md"
LOCK="$W/data/.t006-sauna-thread.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-sauna"
Q="$W/scripts/queue-manager.js"
P="$W/scripts/auto-x-publisher.js"
RP="$W/scripts/run-publish.sh"
HEALTH="$W/scripts/cdp-health.js"
ID="blog-promo-20260830-sauna-openings-2026"
URL="https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/"
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

T1='明日 8/31、門前仲町に「門仲SAUNAS LO」がオープンするわ。
銭湯とマンションが併設で、サウナは男性3室・女性1室😏

直近だと 8/11 に小田原駅前の「海賊サウナ＆カプセルホテル」も開いたばかり。
首都圏で今年オープンのサウナ、17施設ぶん全部並べたわよ。

#サウナ #ととのう #サウナ新店'

T2='同じ「サウナ行く」でも、財布の減り方が全然違うのよね。

・一番安い → 黄金湯 新宿 550円（銭湯の入浴料。サウナは別料金）
・一番高い → 高輪SAUNAS 3,700円（男性・平日4時間／女性3,200円）

17施設ぶんの料金と最寄駅、1軒ずつまとめてあるわ。

▶ 2026年オープンのサウナ新店 首都圏17施設
https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/'

# サウナ告知として既に出ているものの件数
posted_count() {
  "$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
try{
  const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
  console.log((q.queue||[]).filter(e=>{
    const t=(e.text||"")+" "+(e.target_url||"")
      +" "+((e.thread_chain||[]).map(x=>x&&x.text||"").join(" "));
    return (t.includes("門仲SAUNAS")||t.includes("sauna-openings-2026"))
        && (e.status==="posted"||e.x_tweet_id);
  }).length);
}catch(e){ console.log(-1); }
' "$W" 2>/dev/null || echo -1
}

{
echo "# サウナ告知のスレッドを X へ出す（t004/t005 を直した版・$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> t004 は **pickEntry の 5 条件すべてを外していた**（\`no candidate\`）。"
echo "> t005 は **同日 2 回目の auto-publisher が構造的に skip される**設計だった。"
echo "> **auto-x-publisher を使わず、\`run-publish.sh\` の \`thread_chain\` で 1 回に出す。**"

echo
echo "## 0. もう出ていないか"
echo
BEFORE="$(posted_count)"
echo "- 投稿済みエントリ: **${BEFORE} 件**"
[ "$BEFORE" = "-1" ] && { echo "- **post_queue が読めない。何もしない。**"; exit 1; }
[ "${BEFORE:-0}" -gt 0 ] 2>/dev/null && { echo "- → **既に出ている。何もしない。**"; exit 0; }
[ -f "$LOCK" ] && { echo "- **ロックがある。二重に走らせない。**"; exit 0; }
mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"

echo
echo "## 1. 契約（**推測せず、実物を出す**）"
echo
echo "### auto-x-publisher.js が blog-promo に要求する 5 条件"
echo '```javascript'
"$NODE_BIN" -e '
const fs=require("fs");
const s=fs.readFileSync(process.argv[1],"utf8").split(/\r?\n/);
const i=s.findIndex(l=>l.includes("KIND === \"blog-promo\""));
if(i<0){ console.log("(該当箇所が見つからない)"); }
else{ s.slice(i,i+14).forEach((l,n)=>console.log((i+n+1)+": "+l.slice(0,150))); }
' "$P" 2>/dev/null | mask
echo '```'
echo
echo "### run-publish.sh が読むフィールド（**image_path はカンマ区切り**）"
echo '```bash'
grep -nE 'image_path|thread_chain|e\.kind|ENTRY_ID|ensure-chrome' "$RP" 2>/dev/null \
  | mask | cut -c1-150 | head -12
echo '```'
echo
echo "### queue-manager.js に実在する case（**approve は無い**）"
echo '```javascript'
grep -nE '^\s+case "' "$Q" 2>/dev/null | mask | cut -c1-80
echo '```'

echo
echo "## 2. 画像を用意する（**4 枚そろわなければ出さない**）"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
N=0
for f in 1-summary 2-maihama 3-takanawa 4-oimachi; do
  dst="$IMGDIR/$f.jpg"
  if git -C "$REPO" show "origin/main:public/images/sauna-openings-2026/x/$f.jpg" > "$dst" 2>/dev/null && [ -s "$dst" ]; then
    echo "- $f.jpg: $(wc -c < "$dst" | tr -d ' ') B"; N=$((N+1))
  else rm -f "$dst"; echo "- $f.jpg: **取り出せない**"; fi
done
if [ "$N" != "4" ]; then echo "- **4 枚そろわない。出さない。**"; rm -f "$LOCK"; exit 1; fi
S1="$(wc -c < "$IMGDIR/1-summary.jpg" | tr -d ' ')"
if [ "$S1" -lt 258000 ] 2>/dev/null; then
  echo "- **1-summary.jpg が ${S1} B。古い版。出さない。**"; rm -f "$LOCK"; exit 1
fi
IMGCSV="$IMGDIR/1-summary.jpg,$IMGDIR/2-maihama.jpg,$IMGDIR/3-takanawa.jpg,$IMGDIR/4-oimachi.jpg"

echo
echo "## 3. 積む（**id 固定・冪等。status は pending のままにして自動投稿に拾わせない**）"
echo
echo "- id: \`$ID\`"
PAYLOAD="$("$NODE_BIN" -e '
const [id,t1,t2,imgcsv,url]=process.argv.slice(1);
console.log(JSON.stringify({
  id, kind:"thread", text:t1, target_url:url, blog_url:url,
  image_path:imgcsv,
  thread_chain:[
    { text:t1, role:"hook", image_path:imgcsv },
    { text:t2, role:"cta",  url:url }
  ]
}));
' "$ID" "$T1" "$T2" "$IMGCSV" "$URL")"
ENQ="$(printf '%s' "$PAYLOAD" | "$NODE_BIN" "$Q" enqueue 2>&1 | tail -2)"
echo '```'; printf '%s\n' "$ENQ" | hide | mask | cut -c1-160; echo '```'
if ! printf '%s' "$ENQ" | grep -qE '"ok":true|id already exists'; then
  echo "- **enqueue に失敗。投稿しない。**"; rm -f "$LOCK"; exit 1
fi

echo
echo "### 積まれた形を読み返す（**当て推量でなく実物**）"
echo '```json'
"$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
const e=(q.queue||[]).find(x=>x.id===process.argv[2]);
if(!e){ console.log("{\"error\":\"not found\"}"); process.exit(0); }
console.log(JSON.stringify({
  id:e.id, kind:e.kind, status:e.status,
  auto_publish:e.auto_publish===undefined?null:e.auto_publish,
  chain_len:(e.thread_chain||[]).length,
  chain_roles:(e.thread_chain||[]).map(x=>x.role),
  chain_images:(e.thread_chain||[]).map(x=>(x.image_path||"").split(",").filter(Boolean).length),
  images_exist:(e.thread_chain&&e.thread_chain[0]&&e.thread_chain[0].image_path||"")
    .split(",").filter(Boolean).every(p=>fs.existsSync(p))
},null,2));
' "$W" "$ID" 2>&1 | mask
echo '```'

echo
echo "## 4. Chrome を確かめる（**ログアウト中に走らせると [1/2] だけ出る**）"
echo
if [ -f /tmp/x-login-in-progress ]; then
  echo "- **/tmp/x-login-in-progress がある。手動ログイン中。出さない。**"
  echo; echo "> エントリは積んである。ログインが終わったら次の 1 行で出る。"
  echo '> ```'; echo "> /bin/bash $RP $ID"; echo '> ```'
  rm -f "$LOCK"; exit 1
fi
if "$NODE_BIN" "$HEALTH" >/dev/null 2>&1; then
  echo "- CDP: **健全**"
else
  echo "- CDP: **応答しない**（ポートが開いていてもハングしていることがある）"
  echo
  echo "**ログアウト/ハングの疑いがあるので出さない。**"
  echo "thread_chain は [1/2] を出してから [2/2] を出すので、"
  echo "途中で落ちると**片方だけ公開された状態**になる。それは事故である。"
  echo
  echo "> エントリは \`$ID\` として積んである。"
  echo "> ログインを回復したら次の 1 行で [1/2]+[2/2] がまとめて出る。"
  echo '> ```'; echo "> /bin/bash $RP $ID"; echo '> ```'
  rm -f "$LOCK"; exit 1
fi

echo
echo "## 5. 出す（**run-publish.sh を直接。auto-x-publisher は使わない**）"
echo
R="$(/bin/bash "$RP" "$ID" 2>&1 | tail -12)"
echo '```'; printf '%s\n' "$R" | hide | mask | cut -c1-200; echo '```'
TWEET_ID="$(printf '%s' "$R" | "$NODE_BIN" -e '
let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{
  const lines=d.split(/\r?\n/).filter(x=>x.trim().startsWith("{"));
  for(let i=lines.length-1;i>=0;i--){
    try{ const o=JSON.parse(lines[i]);
      if(o.ok===true){ console.log(o.tweet_id||String(o.url||"").split("/status/")[1]||""); return; }
    }catch(e){}
  }
  console.log("");
});' 2>/dev/null)"

if [ -n "$TWEET_ID" ]; then
  MP="$("$NODE_BIN" "$Q" mark-posted "$ID" "$TWEET_ID" 2>&1 | tail -1)"
  echo
  echo "- キューに記録: \`$(printf '%s' "$MP" | hide | mask | cut -c1-120)\`"
fi

echo
echo "## 6. 件数（**2 件以上なら事故**）"
echo
AFTER="$(posted_count)"
echo "- 前 ${BEFORE} 件 → 後 **${AFTER} 件**"
if [ "${AFTER:-0}" -gt 1 ] 2>/dev/null; then
  echo; echo "🚨 **2 件以上。二重投稿の可能性。すぐ確認して余分を消すこと。**"
elif [ "${AFTER:-0}" = "1" ] && [ -n "$TWEET_ID" ]; then
  echo "- **1 件だけ。正常。**"
  CNT="$(printf '%s' "$R" | grep -oE '"thread_count":[0-9]+' | head -1 | grep -oE '[0-9]+')"
  echo "- スレッド本数: **${CNT:-?}**（[1/2] と [2/2] で 2 なら正常）"
  echo "- **投稿 URL: https://x.com/heng_ji31590/status/$TWEET_ID**"
  if [ "${CNT:-0}" != "2" ]; then
    echo; echo "🚨 **2 本になっていない。スレッドが途中で落ちた可能性。X 上で確認すること。**"
  fi
else
  echo "- **出ていない。**"
  rm -f "$LOCK"
  echo
  echo "> エントリ \`$ID\` はキューに残してある。上の出力で原因を直したうえで、"
  echo "> \`/bin/bash $RP $ID\` を叩けば出る。**このタスクは二度と走らない。**"
fi
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
u="$(grep -oE 'https://x.com/[^ *]*' "$OUT" 2>/dev/null | tail -1)"
if grep -q '既に出ている' "$OUT" 2>/dev/null; then echo "既に投稿済み / $(basename "$OUT")"
elif grep -q '🚨' "$OUT" 2>/dev/null; then echo "🚨 **要確認** / $(basename "$OUT")"
elif grep -q '1 件だけ。正常' "$OUT" 2>/dev/null; then echo "**スレッドを投稿した** ${u:-} / $(basename "$OUT")"
elif grep -q 'CDP: \*\*応答しない\*\*' "$OUT" 2>/dev/null; then echo "**Chrome がログアウト/ハング。積んだが出していない** / $(basename "$OUT")"
else echo "投稿できていない / $(basename "$OUT")"; fi
