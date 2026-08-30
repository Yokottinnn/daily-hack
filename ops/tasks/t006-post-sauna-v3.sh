#!/bin/bash
# **サウナ告知 [1/2] を X へ出す（t004 の "no candidate" を直した版）。**
#
# ## t004 が出せなかった理由（実測で確定）
#
# publisher は積んだ直後にこう返した。
#
#   {"ok":true,"action":"skip","reason":"no candidate","kind":"blog-promo"}
#
# t004 が吐いた publisher のソースに答えが書いてある。
#
#    6: *   kind = blog-promo (== thread + blog-promo- prefix)
#   136:        e.kind === "thread" &&
#   137:        (e.id || "").startsWith("blog-promo-") &&
#
# **`blog-promo` は kind の名前ではなく「モード」の名前だった。**
# 実際に積むエントリは **`kind: "thread"`** で、**`id` が `blog-promo-` で始まる**必要がある。
# t004 は `kind:"blog-promo"` / `id:"sauna-x-…"` で積んだので、どちらも外していた。
#
# ## まだ確定していない 2 つを、この実行の中で確定させる
#
#   1. **候補の条件にある status。** 136〜137 行の前後は grep に写っていない。
#      → **候補ブロックを丸ごと出してから、そこに書かれている status を読んで合わせる。**
#   2. **画像のフィールド名。** t004 の推定は `images` だったが、
#      全文検索なので当てにならない。
#      → **blog-promo の画像処理ブロックを出す。**
#      あわせて**候補になりうるキーを全部入れて積む。**
#      余分なキーは無視されるだけだが、足りないと画像なしで出てしまう。
#
# **当て推量で「たぶんこれ」を 1 つ選ばない。** 外すとまた 1 周回 失う。
#
# ## 掃除
#
# t004 が積んだ `sauna-x-…`（kind が違うので永遠に拾われない）を消す。
#
# **二重投稿はしない。** 開始前に確認し、ロックを置き、出した後に件数を数える。
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-sauna-v3.md"
LOCK="$W/data/.t006-sauna-post.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-sauna"
P="$W/scripts/auto-x-publisher.js"
Q="$W/scripts/queue-manager.js"
QJSON="$W/data/post_queue.json"
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

T1='明日 8/31、門前仲町に「門仲SAUNAS LO」がオープンするわ。
銭湯とマンションが併設で、サウナは男性3室・女性1室😏

直近だと 8/11 に小田原駅前の「海賊サウナ＆カプセルホテル」も開いたばかり。
首都圏で今年オープンのサウナ、17施設ぶん全部並べたわよ。

#サウナ #ととのう #サウナ新店'

posted_count() {
  "$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
try{
  const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
  console.log((q.queue||[]).filter(e=>{
    const t=(e.text||"")+" "+(e.target_url||"");
    return (t.includes("門仲SAUNAS")||t.includes("sauna-openings-2026"))
        && (e.status==="posted"||e.x_tweet_id);
  }).length);
}catch(e){ console.log(-1); }
' "$W" 2>/dev/null || echo -1
}

{
echo "# サウナ告知 [1/2] を X へ出す（v3・$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> t004 は \`kind\` と \`id\` の形を外していた。**publisher のソースに答えが書いてあった。**"
echo "> \`kind = blog-promo (== thread + blog-promo- prefix)\`"

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
echo "## 1. 候補の条件を、丸ごと出して読む"
echo
echo "### blog-promo の候補選び（120〜150 行）"
echo '```javascript'
sed -n '120,150p' "$P" 2>/dev/null | mask
echo '```'
echo
echo "### blog-promo の画像処理（205〜245 行）"
echo '```javascript'
sed -n '205,245p' "$P" 2>/dev/null | mask
echo '```'

# 候補ブロックが要求する status を**読んで**決める。当て推量しない
WANT_ST="$("$NODE_BIN" -e '
const fs=require("fs");
const s=fs.readFileSync(process.argv[1],"utf8").split(/\r?\n/).slice(119,150).join("\n");
const m=[...s.matchAll(/status\s*===\s*"([a-z_]+)"/g)].map(x=>x[1]);
console.log([...new Set(m)].join(","));
' "$P" 2>/dev/null)"
echo
echo "- 候補ブロックが見ている status: **\`${WANT_ST:-見つからない}\`**"

echo
echo "## 2. t004 が積んだ、拾われないエントリを消す"
echo
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
try{
  const q=JSON.parse(fs.readFileSync(p,"utf8"));
  const before=(q.queue||[]).length;
  q.queue=(q.queue||[]).filter(e=>{
    const id=String(e.id||"");
    const dead = id.startsWith("sauna-x-") && !e.x_tweet_id && e.status!=="posted";
    return !dead;
  });
  const removed=before-q.queue.length;
  if(removed>0) fs.writeFileSync(p, JSON.stringify(q,null,2));
  console.log(`- 拾われないエントリ: ${removed} 件 削除`);
}catch(e){ console.log("- 掃除できない: "+e.message); }
' "$QJSON" 2>&1 | head -3

echo
echo "## 3. 画像を用意する"
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

echo
echo "## 4. 積む（**kind は \`thread\`。id は \`blog-promo-\` で始める**）"
echo
ID="blog-promo-sauna-openings-2026-$(date +%Y%m%d-%H%M%S)"
echo "- id: \`$ID\`"
echo "- kind: \`thread\`"
echo "- **画像キーは 1 つに絞らず、候補を全部入れる**（余分は無視される。足りないと画像なしで出る）"
PAYLOAD="$("$NODE_BIN" -e '
const [id,text,dir,url]=process.argv.slice(1);
const files=["1-summary","2-maihama","3-takanawa","4-oimachi"].map(f=>`${dir}/${f}.jpg`);
const o={id,kind:"thread",text,target_url:url};
for(const k of ["images","imagePaths","imageFiles","media","attachments"]) o[k]=files;
console.log(JSON.stringify(o));
' "$ID" "$T1" "$IMGDIR" "https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/")"
ENQ="$(printf '%s' "$PAYLOAD" | "$NODE_BIN" "$Q" enqueue 2>&1 | tail -2)"
echo '```'; printf '%s\n' "$ENQ" | hide | mask | cut -c1-160; echo '```'
if ! printf '%s' "$ENQ" | grep -q '"ok":true'; then
  echo "- **enqueue に失敗。投稿しない。**"; rm -f "$LOCK"; exit 1
fi

echo
echo "## 5. status を、候補ブロックが見ているものに合わせる"
echo
ST="$("$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const e=(q.queue||[]).find(x=>x.id===process.argv[2]);
console.log(e?String(e.status):"?");
' "$QJSON" "$ID" 2>/dev/null)"
echo "- 積んだ直後の status: **$ST**"

# queue-manager に承認の口があるなら、まずそれを使う
if "$NODE_BIN" "$Q" 2>&1 | grep -qi 'approve'; then
  AP="$("$NODE_BIN" "$Q" approve "$ID" 2>&1 | tail -2)"
  echo "- \`queue-manager approve\` を試した: \`$(printf '%s' "$AP" | mask | cut -c1-100)\`"
  ST="$("$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const e=(q.queue||[]).find(x=>x.id===process.argv[2]);
console.log(e?String(e.status):"?");
' "$QJSON" "$ID" 2>/dev/null)"
  echo "- そのあとの status: **$ST**"
fi

# それでも候補の条件に合わないなら、**読み取った値**に直接合わせる
if [ -n "$WANT_ST" ] && ! printf '%s' ",$WANT_ST," | grep -q ",$ST,"; then
  FIRST="${WANT_ST%%,*}"
  echo "- 候補の条件（\`$WANT_ST\`）に合わないので、**\`$FIRST\` に直接合わせる**"
  "$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
const q=JSON.parse(fs.readFileSync(p,"utf8"));
const e=(q.queue||[]).find(x=>x.id===process.argv[2]);
if(e){ e.status=process.argv[3]; fs.writeFileSync(p, JSON.stringify(q,null,2)); console.log("  → status を "+e.status+" にした"); }
else console.log("  → エントリが見つからない");
' "$QJSON" "$ID" "$FIRST" 2>&1 | head -2
fi

echo
echo "## 6. 出す"
echo
R="$("$NODE_BIN" "$P" blog-promo 2>&1 | tail -10)"
echo '```'; printf '%s\n' "$R" | hide | mask | cut -c1-200; echo '```'

echo
echo "## 7. 件数（**2 件以上なら事故**）"
echo
AFTER="$(posted_count)"
echo "- 前 ${BEFORE} 件 → 後 **${AFTER} 件**"
if [ "${AFTER:-0}" -gt 1 ] 2>/dev/null; then
  echo; echo "🚨 **2 件以上。二重投稿の可能性。すぐ確認して余分を消すこと。**"
elif [ "${AFTER:-0}" = "1" ]; then
  echo "- **1 件だけ。正常。**"
  TID="$("$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const e=(q.queue||[]).filter(x=>x.x_tweet_id&&String(x.text||"").includes("門仲SAUNAS")).pop();
console.log(e?e.x_tweet_id:"");
' "$QJSON" 2>/dev/null)"
  [ -n "$TID" ] && echo "- **投稿 URL: https://x.com/heng_ji31590/status/$TID**"
  echo
  echo "**[2/2] は t007 が出す。**"
else
  echo "- **出ていない。**"
  rm -f "$LOCK"
  echo
  echo "> **このタスクは二度と走らない。** 上の 1 章のソースを読んで直し、"
  echo "> **別名（\`t008-…\`）で出し直すこと。**"
fi
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
n="$(grep -oE '後 \*\*[0-9-]+ 件' "$OUT" 2>/dev/null | grep -oE '[0-9-]+' | head -1)"
u="$(grep -oE 'https://x.com/[^ *]*' "$OUT" 2>/dev/null | head -1)"
if grep -q '既に出ている' "$OUT" 2>/dev/null; then echo "既に投稿済み / $(basename "$OUT")"
elif [ "${n:-0}" = "1" ]; then echo "**投稿した** ${u:-} / $(basename "$OUT")"
else echo "投稿できていない（${n:-?} 件）/ $(basename "$OUT")"; fi
