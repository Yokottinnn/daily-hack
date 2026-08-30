#!/bin/bash
# **サウナ告知 [2/2] を、[1/2] へのリプライとして出す（t005 の後継）。**
#
# t005 は設計どおりに動いた。[1/2] が出ていなかったので **3 分待って、出さずに終わった。**
# 順序が逆だとスレッドが繋がらないため、それが正しい振る舞いである。
#
#   - [1/2] の tweet id: **3 分待っても現れない**
#   - **t004 が [1/2] を出せていない。** [2/2] だけ先に出すとスレッドが繋がらないので出さない。
#
# [1/2] は **t006** が出す。名前順に t006 → t007 と、同じ周回で走る。
#
# ## t005 から変えたところ
#
# **積む形を t006 に合わせた。** publisher の候補条件はこうだった。
#
#    6: *   kind = blog-promo (== thread + blog-promo- prefix)
#   136:        e.kind === "thread" &&
#   137:        (e.id || "").startsWith("blog-promo-") &&
#
# よって `kind:"thread"` ／ `id` は `blog-promo-` 始まり。status も候補ブロックから読んで合わせる。
#
# ## 当て推量でリプライのフィールド名を作らない
#
# 候補を順に探し、**1 つも見つからなければソースを出して `exit 1`。**
# 「たぶん in_reply_to だろう」で積むと、無視されて**独立ツイートとして出る。**
#
# ## タスクは 1 回しか走らない
#
# `scripts/ops-heartbeat.sh:162` は rc に関係なく `done/` を書く。詳しくは
# `docs/ops-task-runner.md`。だから待つときは**自分の実行の中で待つ。**
#
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-sauna-v2.md"
LOCK="$W/data/.t007-sauna-reply.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
P="$W/scripts/auto-x-publisher.js"
Q="$W/scripts/queue-manager.js"
QJSON="$W/data/post_queue.json"
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

T2='同じ「サウナ行く」でも、財布の減り方が全然違うのよね。

・一番安い → 黄金湯 新宿 550円（銭湯の入浴料。サウナは別料金）
・一番高い → 高輪SAUNAS 3,700円（男性・平日4時間／女性3,200円）

17施設ぶんの料金と最寄駅、1軒ずつまとめてあるわ。

▶ 2026年オープンのサウナ新店 首都圏17施設
https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/'

head_id() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const e=(q.queue||[]).filter(x=>x.x_tweet_id&&String(x.text||"").includes("門仲SAUNAS")).pop();
  console.log(e?e.x_tweet_id:"");
}catch(e){ console.log(""); }
' "$QJSON" 2>/dev/null
}

reply_count() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  console.log((q.queue||[]).filter(x=>x.x_tweet_id&&String(x.text||"").includes("一番安い")).length);
}catch(e){ console.log(-1); }
' "$QJSON" 2>/dev/null || echo -1
}

{
echo "# サウナ告知 [2/2] をリプライで出す（v2・$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **[1/2] の tweet id が無ければ出さない。** 順序が逆だとスレッドが繋がらない。"

echo
echo "## 0. 前提を確かめる"
echo
# **自分の実行の中で待つ。** 1 回しか走らないので「次の周回」は無い
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
  echo "**t006 が [1/2] を出せていない。** [2/2] だけ先に出さない。"
  echo
  echo "> \`post-sauna-v3.md\` を見て原因を直し、**別名（\`t009-…\`）で出し直すこと。**"
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
grep -nE 'reply|in_reply|thread_parent|conversation' "$P" "$Q" 2>/dev/null | mask | cut -c1-160 | head -24
echo '```'

RKEY="$("$NODE_BIN" -e '
const fs=require("fs");
let s="";
for(const f of process.argv.slice(1)){ try{ s+=fs.readFileSync(f,"utf8"); }catch(e){} }
const k=["reply_to_tweet_id","in_reply_to_tweet_id","in_reply_to_status_id",
         "reply_to_id","in_reply_to","reply_to","thread_parent_id","parent_tweet_id"].find(x=>s.includes(x));
console.log(k||"");
' "$P" "$Q" 2>/dev/null)"

if [ -z "$RKEY" ]; then
  echo
  echo "**リプライのフィールドが見つからない。**"
  echo "当て推量で積むと、無視されて**独立ツイートとして出る。**"
  echo "[2/2] としては事故になるので、**出さずに終わる。**"
  echo
  echo "上のソースから人がフィールド名を決めて、**別名（\`t009-…\`）で出し直すこと。**"
  exit 1
fi
echo
echo "- リプライのフィールド名: **\`$RKEY\`**"

WANT_ST="$("$NODE_BIN" -e '
const fs=require("fs");
const s=fs.readFileSync(process.argv[1],"utf8").split(/\r?\n/).slice(119,150).join("\n");
const m=[...s.matchAll(/status\s*===\s*"([a-z_]+)"/g)].map(x=>x[1]);
console.log([...new Set(m)].join(","));
' "$P" 2>/dev/null)"
echo "- 候補ブロックが見ている status: **\`${WANT_ST:-見つからない}\`**"

mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"

echo
echo "## 2. 積む（**kind は \`thread\`。id は \`blog-promo-\` で始める**）"
echo
ID="blog-promo-sauna-reply-$(date +%Y%m%d-%H%M%S)"
echo "- id: \`$ID\`"
echo "- 親: \`$HEAD\`"
echo "- **画像は付けない。** 1〜4 枚目は [1/2] で出し切っている"
PAYLOAD="$("$NODE_BIN" -e '
const [id,text,parent,key]=process.argv.slice(1);
const o={id,kind:"thread",text,
         target_url:"https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/"};
o[key]=parent;
console.log(JSON.stringify(o));
' "$ID" "$T2" "$HEAD" "$RKEY")"
ENQ="$(printf '%s' "$PAYLOAD" | "$NODE_BIN" "$Q" enqueue 2>&1 | tail -2)"
echo '```'; printf '%s\n' "$ENQ" | hide | mask | cut -c1-160; echo '```'
if ! printf '%s' "$ENQ" | grep -q '"ok":true'; then
  echo "- **enqueue に失敗。投稿しない。**"; rm -f "$LOCK"; exit 1
fi

echo
echo "## 3. status を候補ブロックに合わせる"
echo
ST="$("$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const e=(q.queue||[]).find(x=>x.id===process.argv[2]);
console.log(e?String(e.status):"?");
' "$QJSON" "$ID" 2>/dev/null)"
echo "- 積んだ直後の status: **$ST**"
if "$NODE_BIN" "$Q" 2>&1 | grep -qi 'approve'; then
  "$NODE_BIN" "$Q" approve "$ID" >/dev/null 2>&1
  ST="$("$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const e=(q.queue||[]).find(x=>x.id===process.argv[2]);
console.log(e?String(e.status):"?");
' "$QJSON" "$ID" 2>/dev/null)"
  echo "- \`approve\` のあと: **$ST**"
fi
if [ -n "$WANT_ST" ] && ! printf '%s' ",$WANT_ST," | grep -q ",$ST,"; then
  FIRST="${WANT_ST%%,*}"
  echo "- 条件（\`$WANT_ST\`）に合わないので **\`$FIRST\` に合わせる**"
  "$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
const q=JSON.parse(fs.readFileSync(p,"utf8"));
const e=(q.queue||[]).find(x=>x.id===process.argv[2]);
if(e){ e.status=process.argv[3]; fs.writeFileSync(p, JSON.stringify(q,null,2)); }
' "$QJSON" "$ID" "$FIRST" 2>&1 | head -2
fi

echo
echo "## 4. 出す"
echo
R="$("$NODE_BIN" "$P" blog-promo 2>&1 | tail -10)"
echo '```'; printf '%s\n' "$R" | hide | mask | cut -c1-200; echo '```'

echo
echo "## 5. 件数（**2 件以上なら事故**）"
echo
AFTER="$(reply_count)"
echo "- 前 ${BEFORE} 件 → 後 **${AFTER} 件**"
if [ "${AFTER:-0}" -gt 1 ] 2>/dev/null; then
  echo; echo "🚨 **2 件以上。二重投稿の可能性。すぐ確認して余分を消すこと。**"
elif [ "${AFTER:-0}" = "1" ]; then
  echo "- **1 件だけ。正常。**"
  TID="$("$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const e=(q.queue||[]).filter(x=>x.x_tweet_id&&String(x.text||"").includes("一番安い")).pop();
console.log(e?e.x_tweet_id:"");
' "$QJSON" 2>/dev/null)"
  [ -n "$TID" ] && echo "- **[2/2] URL: https://x.com/heng_ji31590/status/$TID**"
  echo
  echo "**スレッドは 2 本で完結。** 追加の投稿は無い。"
else
  echo "- **出ていない。**"
  rm -f "$LOCK"
  echo
  echo "> **このタスクは二度と走らない。** 原因を直して**別名（\`t009-…\`）で出し直すこと。**"
fi
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '3 分待っても現れない' "$OUT" 2>/dev/null; then echo "**[1/2] が出ていない** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then echo "[2/2] は投稿済み / $(basename "$OUT")"
elif grep -q '1 件だけ。正常' "$OUT" 2>/dev/null; then
  echo "**[2/2] を投稿した** $(grep -oE 'https://x.com/[^ *]*' "$OUT" | tail -1) / $(basename "$OUT")"
else echo "[2/2] を出せていない / $(basename "$OUT")"; fi
