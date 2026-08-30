#!/bin/bash
# **サウナ告知の [2/2] を、[1/2] へのリプライとして出す。**
#
# [1/2] は t004 が出す。**その tweet id が無ければ何もしない。**
# 順序が逆になるとスレッドが繋がらないので、id の存在が唯一の起動条件である。
#
# ## タスクは 1 回しか走らない。**「次の周回で」は無い**
#
# `scripts/ops-heartbeat.sh:162` は rc に関係なく `done/<task>.sh` を書く。
#
#   out="$(/bin/bash "$task_tmp/$t" 2>&1)"; rc=$?
#   printf '%s rc=%s\n' ... > "$WT/done/$t"      # ← 成否を問わず必ず書く
#
# したがって「今回は条件が揃わないので何もせず、次の周回で再確認する」は成立しない。
# **一度 exit したら二度と走らない。**
#
# だからこのタスクは**自分の実行の中で待つ。** t004 は同じ周回の直前に
# （`ls-tree` は名前順なので t004 → t005）同期的に走り終わっているはずだが、
# publisher が非同期に書く場合に備えて最大 3 分ポーリングする。
# それでも揃わなければ、**別名（t006…）で出し直す必要がある**ことを報告に書く。
#
# ## 当て推量でフィールド名を作らない
#
# publisher / queue-manager がリプライをどのフィールドで受けるかは**読んで決める。**
# 候補を順に探し、**1 つも見つからなければ grep の結果を出して `exit 1`。**
# 「たぶん in_reply_to だろう」で積むと、無視されて**独立ツイートとして出る。**
# それは [2/2] としては事故なので、出さないほうがよい。
#
# ## 二重投稿はしない
#
# 開始前に [2/2] が出ていないか数え、ロックを置き、出したあとにもう一度数える。
#
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-sauna-2of2.md"
LOCK="$W/data/.t005-sauna-reply.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
P="$W/scripts/auto-x-publisher.js"
Q="$W/scripts/queue-manager.js"
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

T2='同じ「サウナ行く」でも、財布の減り方が全然違うのよね。

・一番安い → 黄金湯 新宿 550円（銭湯の入浴料。サウナは別料金）
・一番高い → 高輪SAUNAS 3,700円（男性・平日4時間／女性3,200円）

17施設ぶんの料金と最寄駅、1軒ずつまとめてあるわ。

▶ 2026年オープンのサウナ新店 首都圏17施設
https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/'

# [1/2] の tweet id。門仲SAUNAS を含み、x_tweet_id を持つものの最後
head_id() {
  "$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
try{
  const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
  const e=(q.queue||[]).filter(x=>x.x_tweet_id&&String(x.text||"").includes("門仲SAUNAS")).pop();
  console.log(e?e.x_tweet_id:"");
}catch(e){ console.log(""); }
' "$W" 2>/dev/null
}

# [2/2] が既に出ているか。記事 URL を含み x_tweet_id を持つもの
reply_count() {
  "$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
try{
  const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
  console.log((q.queue||[]).filter(x=>
    x.x_tweet_id && String(x.text||"").includes("一番安い")).length);
}catch(e){ console.log(-1); }
' "$W" 2>/dev/null || echo -1
}

{
echo "# サウナ告知の [2/2] をリプライで出す（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **[1/2] の tweet id が無ければ何もしない。** 順序が逆だとスレッドが繋がらない。"

echo
echo "## 0. 前提を確かめる"
echo
# **自分の実行の中で待つ。** 1 回しか走らないので「次の周回」は無い（冒頭の注記）
HEAD=""
for i in $(seq 1 18); do
  HEAD="$(head_id)"
  [ -n "$HEAD" ] && break
  sleep 10
done
BEFORE="$(reply_count)"
if [ -z "$HEAD" ]; then
  echo "- [1/2] の tweet id: **3 分待っても現れない**"
  echo
  echo "**t004 が [1/2] を出せていない。** [2/2] だけ先に出すとスレッドが繋がらないので出さない。"
  echo
  echo "> **このタスクはもう二度と走らない**（\`done/\` の印が付く）。"
  echo "> t004 のレポート \`post-sauna-v2.md\` を見て原因を直し、"
  echo "> **別名（\`t006-…\`）で出し直すこと。** 同じ名前では実行されない。"
  exit 1
fi
echo "- [1/2] の tweet id: \`$HEAD\`"
echo "- [2/2] の投稿済み件数: **${BEFORE} 件**"
[ "$BEFORE" = "-1" ] && { echo "- **post_queue が読めない。何もしない。**"; exit 1; }
[ "${BEFORE:-0}" -gt 0 ] 2>/dev/null && { echo "- → **既に出ている。何もしない。**"; exit 0; }
[ -f "$LOCK" ] && { echo "- **ロックがある。二重に走らせない。**"; exit 0; }

echo
echo "## 1. リプライの受け口を読む（**当て推量で作らない**）"
echo
echo '```javascript'
grep -nE 'reply|in_reply|thread|conversation' "$P" "$Q" 2>/dev/null | mask | cut -c1-150 | head -20
echo '```'

RKEY="$("$NODE_BIN" -e '
const fs=require("fs");
let s="";
for(const f of process.argv.slice(1)){ try{ s+=fs.readFileSync(f,"utf8"); }catch(e){} }
const k=["reply_to_tweet_id","in_reply_to_tweet_id","in_reply_to_status_id",
         "reply_to_id","in_reply_to","reply_to","thread_parent_id"].find(x=>s.includes(x));
console.log(k||"");
' "$P" "$Q" 2>/dev/null)"

if [ -z "$RKEY" ]; then
  echo
  echo "**リプライのフィールドが見つからない。**"
  echo "当て推量で積むと、無視されて**独立ツイートとして出る。**"
  echo "[2/2] としては事故になるので、**出さずに終わる。**"
  echo
  echo "上の grep 結果から、人がフィールド名を決めて \`RKEY\` に固定すること。"
  exit 1
fi
echo
echo "- リプライのフィールド名: **\`$RKEY\`**"

mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"

echo
echo "## 2. 積む（**argv は slice(1)**）"
echo
ID="sauna-x-reply-$(date +%Y%m%d-%H%M%S)"
PAYLOAD="$("$NODE_BIN" -e '
const [id,text,parent,key]=process.argv.slice(1);
const o={id,kind:"blog-promo",text,
         target_url:"https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/"};
o[key]=parent;
console.log(JSON.stringify(o));
' "$ID" "$T2" "$HEAD" "$RKEY")"
echo "- id: \`$ID\`（本文が入っていないことを確認）"
echo "- 親: \`$HEAD\`"
echo "- **画像は付けない。** [2/2] は記事への導線であり、1〜4 枚目は [1/2] で出し切っている"
ENQ="$(printf '%s' "$PAYLOAD" | "$NODE_BIN" "$Q" enqueue 2>&1 | tail -2)"
echo '```'; printf '%s\n' "$ENQ" | hide | mask | cut -c1-160; echo '```'
if ! printf '%s' "$ENQ" | grep -q '"ok":true'; then
  echo "- **enqueue に失敗。投稿しない。**"; rm -f "$LOCK"; exit 1
fi

ST="$("$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
const e=(q.queue||[]).find(x=>x.id===process.argv[2]);
console.log(e?e.status:"?");
' "$W" "$ID" 2>/dev/null)"
echo "- 積んだ直後の status: **$ST**"
if [ "$ST" = "awaiting_approval" ]; then
  echo "- 承認する（[1/2] と同じ草案として Slack で 👍 済み）"
  AP="$("$NODE_BIN" "$Q" approve "$ID" 2>&1 | tail -2)"
  echo '```'; printf '%s\n' "$AP" | mask | cut -c1-150; echo '```'
fi

echo
echo "## 3. 出す"
echo
R="$("$NODE_BIN" "$P" blog-promo 2>&1 | tail -8)"
echo '```'; printf '%s\n' "$R" | hide | mask | cut -c1-160; echo '```'

echo
echo "## 4. 件数（**2 件以上なら事故**）"
echo
AFTER="$(reply_count)"
echo "- 前 ${BEFORE} 件 → 後 **${AFTER} 件**"
if [ "${AFTER:-0}" -gt 1 ] 2>/dev/null; then
  echo; echo "🚨 **2 件以上。二重投稿の可能性。すぐ確認して余分を消すこと。**"
elif [ "${AFTER:-0}" = "1" ]; then
  echo "- **1 件だけ。正常。**"
  TID="$("$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
const e=(q.queue||[]).filter(x=>x.x_tweet_id&&String(x.text||"").includes("一番安い")).pop();
console.log(e?e.x_tweet_id:"");
' "$W" 2>/dev/null)"
  [ -n "$TID" ] && echo "- **[2/2] URL: https://x.com/heng_ji31590/status/$TID**"
  echo
  echo "**スレッドは 2 本で完結。** 追加の投稿は無い。"
else
  echo "- **出ていない。**"
  rm -f "$LOCK"
  echo
  echo "> **このタスクは二度と走らない。** 原因を直して**別名（\`t006-…\`）で出し直すこと。**"
fi
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '3 分待っても現れない' "$OUT" 2>/dev/null; then echo "**[1/2] が出ていない。t006 で出し直す** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then echo "[2/2] は投稿済み / $(basename "$OUT")"
elif grep -q '1 件だけ。正常' "$OUT" 2>/dev/null; then
  echo "**[2/2] を投稿した** $(grep -oE 'https://x.com/[^ *]*' "$OUT" | tail -1) / $(basename "$OUT")"
else echo "[2/2] を出せていない / $(basename "$OUT")"; fi
