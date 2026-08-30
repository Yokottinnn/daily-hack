#!/bin/bash
# **サウナ告知を X へ出す（t002 の失敗を直した版）。**
#
# ## t002 が出せなかった理由（実測で確定）
#
#   1. **`node -e` の argv がずれていた。**
#      `node -e 'code' A B C` では process.argv = [execPath, A, B, C] で、
#      **スクリプトのパスが入らない。** slice(2) にしたので A が落ち、
#      id に本文が入った（`{"ok":true,"id":"明日 8/31、…"}`）。**slice(1) が正しい。**
#
#   2. **publisher は id ではなく kind を取る。**
#        usage: node auto-x-publisher.js <blog-promo|trend_post|trend_qt>
#      id を渡したので usage を出して終わっていた。
#
#   3. queue-manager は `id, kind, text` を必須にし、
#      **`NO_APPROVAL` に含まれない kind は `awaiting_approval` で積まれる。**
#      承認待ちのまま置かれると publisher が拾わない可能性がある。
#
# ## だから、この版は「読んでから合わせる」
#
#   - `NO_APPROVAL` の中身を読む → 承認が要るなら queue-manager の承認コマンドを使う
#   - publisher の `blog-promo` の分岐を読む → **画像をどのフィールドで受けるか**を決める
#   - 決まった形で積んで、`auto-x-publisher.js blog-promo` を叩く
#
# **二重投稿はしない。** 開始前に確認し、ロックを置き、出した後に件数を数える。
# t002 が積んだ壊れたエントリ（id が本文になっているもの）は**掃除する。**
#
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-sauna-v2.md"
LOCK="$W/data/.t004-sauna-post.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-sauna"
P="$W/scripts/auto-x-publisher.js"
Q="$W/scripts/queue-manager.js"
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
echo "# サウナ告知を X へ出す（t002 の失敗を直した版・$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> t002 は **node -e の argv ずれ**と**publisher に id を渡した**ので出なかった。"
echo "> **読んでから形を合わせる。**"

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
echo "## 1. t002 が積んだ壊れたエントリを掃除する"
echo
"$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
const p=path.join(process.argv[1],"data/post_queue.json");
try{
  const q=JSON.parse(fs.readFileSync(p,"utf8"));
  const before=(q.queue||[]).length;
  // id が本文になっている（改行を含む id）壊れたエントリだけを消す
  q.queue=(q.queue||[]).filter(e=>!(typeof e.id==="string" && e.id.includes("\n")));
  const removed=before-q.queue.length;
  if(removed>0){ fs.writeFileSync(p, JSON.stringify(q,null,2)); }
  console.log(`- 壊れたエントリ: ${removed} 件 削除`);
}catch(e){ console.log("- 掃除できない: "+e.message); }
' "$W" 2>&1 | head -3

echo
echo "## 2. 契約を読む"
echo
echo "### queue-manager.js の承認まわり"
echo '```javascript'
grep -nE 'NO_APPROVAL|approve|case "' "$Q" 2>/dev/null | mask | cut -c1-150 | head -16
echo '```'
echo
echo "### auto-x-publisher.js の blog-promo と画像の受け口"
echo '```javascript'
grep -nE 'blog-promo|images|imagePaths|media|attach|KIND ===|kind ===' "$P" 2>/dev/null \
  | mask | cut -c1-150 | head -18
echo '```'

# 画像フィールド名を実物から決める。無ければ images
# **正規表現で凝らない。** 単純な包含で、優先順に最初に見つかったものを採る
IMGKEY="$("$NODE_BIN" -e '
const fs=require("fs");
const s=fs.readFileSync(process.argv[1],"utf8");
const k=["imagePaths","imageFiles","attachments","images","media"].find(x=>s.includes(x));
console.log(k||"images");
' "$P" 2>/dev/null || echo images)"
echo
echo "- 画像のフィールド名: **\`$IMGKEY\`**"
NOAPP="$(grep -oE 'NO_APPROVAL\s*=\s*\[[^]]*\]' "$Q" 2>/dev/null | head -1 | mask)"
echo "- NO_APPROVAL: \`${NOAPP:-読めない}\`"

echo
echo "## 3. 画像を用意する"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
IMGJSON="[]"; N=0
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
IMGJSON="$("$NODE_BIN" -e '
const d=process.argv[1];
console.log(JSON.stringify(["1-summary","2-maihama","3-takanawa","4-oimachi"].map(f=>`${d}/${f}.jpg`)));
' "$IMGDIR")"

echo
echo "## 4. 積む（**argv は slice(1)。t002 のバグを直した**）"
echo
ID="sauna-x-$(date +%Y%m%d-%H%M%S)"
PAYLOAD="$("$NODE_BIN" -e '
const [id,text,imgs,url,key]=process.argv.slice(1);
const o={id,kind:"blog-promo",text,target_url:url};
o[key]=JSON.parse(imgs);
console.log(JSON.stringify(o));
' "$ID" "$T1" "$IMGJSON" "https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/" "$IMGKEY")"
echo "- id: \`$ID\`（本文が入っていないことを確認）"
ENQ="$(printf '%s' "$PAYLOAD" | "$NODE_BIN" "$Q" enqueue 2>&1 | tail -2)"
echo '```'; printf '%s\n' "$ENQ" | hide | mask | cut -c1-160; echo '```'
if ! printf '%s' "$ENQ" | grep -q '"ok":true'; then
  echo "- **enqueue に失敗。投稿しない。**"; rm -f "$LOCK"; exit 1
fi

# 承認待ちで積まれたなら承認する
ST="$("$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
const e=(q.queue||[]).find(x=>x.id===process.argv[2]);
console.log(e?e.status:"?");
' "$W" "$ID" 2>/dev/null)"
echo "- 積んだ直後の status: **$ST**"
if [ "$ST" = "awaiting_approval" ]; then
  echo "- 承認する（Slack で 👍 済み）"
  AP="$("$NODE_BIN" "$Q" approve "$ID" 2>&1 | tail -2)"
  echo '```'; printf '%s\n' "$AP" | mask | cut -c1-150; echo '```'
fi

echo
echo "## 5. 出す"
echo
R="$("$NODE_BIN" "$P" blog-promo 2>&1 | tail -8)"
echo '```'; printf '%s\n' "$R" | hide | mask | cut -c1-160; echo '```'

echo
echo "## 6. 件数（**2 件以上なら事故**）"
echo
AFTER="$(posted_count)"
echo "- 前 ${BEFORE} 件 → 後 **${AFTER} 件**"
if [ "${AFTER:-0}" -gt 1 ] 2>/dev/null; then
  echo; echo "🚨 **2 件以上。二重投稿の可能性。すぐ確認して余分を消すこと。**"
elif [ "${AFTER:-0}" = "1" ]; then
  echo "- **1 件だけ。正常。**"
  TID="$("$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
const e=(q.queue||[]).filter(x=>x.x_tweet_id&&((x.text||"").includes("門仲SAUNAS"))).pop();
console.log(e?e.x_tweet_id:"");
' "$W" 2>/dev/null)"
  [ -n "$TID" ] && echo "- **投稿 URL: https://x.com/heng_ji31590/status/$TID**"
  echo
  echo "**[2/2] は次の一手で出す。**（[1/2] の tweet id が要るため）"
else
  echo "- **出ていない。** ロックを外して次の周回で再試行"
  rm -f "$LOCK"
fi
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
n="$(grep -oE '後 \*\*[0-9-]+ 件' "$OUT" 2>/dev/null | grep -oE '[0-9-]+' | head -1)"
u="$(grep -oE 'https://x.com/[^ ]*' "$OUT" 2>/dev/null | head -1)"
if grep -q '既に出ている' "$OUT" 2>/dev/null; then echo "既に投稿済み / $(basename "$OUT")"
elif [ "${n:-0}" = "1" ]; then echo "**投稿した** ${u:-} / $(basename "$OUT")"
else echo "投稿できていない（${n:-?} 件）/ $(basename "$OUT")"; fi
