#!/bin/bash
# **サウナ告知を X へ出す。調べて、出すところまで 1 回でやる。**
#
#   画像（差し替え版含む）に 👍  2026-08-30 19:43
#   文面 v3 に 👍                2026-08-30 21:20
#
# ## 設計の考え方
#
# 「口が分からないので持ち帰る」では 30 分 無駄になる。**実行時に調べて、
# 分かったらその場で出す。** 当て推量ではない — 実物を読んでから撃つ。
#
# 順に試し、**最初に成立した経路で 1 回だけ出す。**
#
#   経路A  auto-x-publisher.js に --text/--images 系の口がある → それで出す
#   経路B  queue-manager.js enqueue で積んで publisher を id 指定で叩く
#          （comment-orchestrator.sh と同じ形。実物で確認済みの流れ）
#   経路C  どれも成立しない → 出さずにインターフェースを持ち帰る
#
# ## 二重投稿を絶対にしない
#
#   1. 開始前に post_queue.json を見て、既に出ていれば即終了
#   2. ロックファイルを置く（同じ周回で 2 回走っても 1 回）
#   3. 出した直後に件数を数え、2 件以上なら **大きく警告**する
#
# Slack の `@OpenClaw tweet` でも依頼済み。**両方動いても 1 回しか出ない。**
#
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-sauna.md"
LOCK="$W/data/.t002-sauna-post.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-sauna"
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

count_posted() {
  "$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
try{
  const q=JSON.parse(fs.readFileSync(path.join(process.argv[1],"data/post_queue.json"),"utf8"));
  const n=(q.queue||[]).filter(e=>{
    const t=(e.text||"")+" "+(e.target_url||"");
    return (t.includes("門仲SAUNAS")||t.includes("sauna-openings-2026"))
        && (e.status==="posted"||e.x_tweet_id);
  }).length;
  console.log(n);
}catch(e){ console.log(-1); }
' "$W" 2>/dev/null || echo -1
}

{
echo "# サウナ告知を X へ出す（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> 承認済み。**調べて、出すところまで 1 回でやる。**"
echo "> **二重投稿はしない。** 開始前に確認し、ロックを置く。"

echo
echo "## 0. もう出ていないか"
echo
BEFORE="$(count_posted)"
echo "- 該当する投稿済みエントリ: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then
  echo "- **post_queue.json が読めない。安全側に倒して何もしない。**"; exit 1
fi
if [ "${BEFORE:-0}" -gt 0 ] 2>/dev/null; then
  echo "- → **既に出ている。何もしない。**"; exit 0
fi
if [ -f "$LOCK" ]; then
  echo "- **ロックがある**（$(cat "$LOCK" 2>/dev/null | head -1 | mask)）。二重に走らせない。"; exit 0
fi
mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"
echo "- ロックを置いた"

echo
echo "## 1. 画像を用意する"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
IMGS=""
for f in 1-summary 2-maihama 3-takanawa 4-oimachi; do
  src="public/images/sauna-openings-2026/x/$f.jpg"
  dst="$IMGDIR/$f.jpg"
  if git -C "$REPO" show "origin/main:$src" > "$dst" 2>/dev/null && [ -s "$dst" ]; then
    echo "- $f.jpg: $(wc -c < "$dst" | tr -d ' ') B"
    IMGS="$IMGS$dst,"
  else
    rm -f "$dst"; echo "- $f.jpg: **取り出せない**"
  fi
done
IMGS="${IMGS%,}"
NIMG="$(printf '%s' "$IMGS" | tr ',' '\n' | grep -c . || true)"
echo "- 用意できた枚数: **${NIMG}/4**"
if [ "${NIMG:-0}" != "4" ]; then
  echo "- **4 枚そろわないので出さない。** どれを見て 👍 したのか分からなくなる。"
  rm -f "$LOCK"; exit 1
fi
# 1 枚目が差し替え版（キャラ＋♨）か。250KB 前後なら古い
S1="$(wc -c < "$IMGDIR/1-summary.jpg" | tr -d ' ')"
if [ "$S1" -lt 258000 ] 2>/dev/null; then
  echo "- **1-summary.jpg が ${S1} B。古い版の可能性が高い（差し替え版は 264KB 前後）。出さない。**"
  rm -f "$LOCK"; exit 1
fi
echo "- 1-summary.jpg は差し替え版（${S1} B）"

echo
echo "## 2. 出す口を調べる（**実物を読んでから撃つ**）"
echo
P="$W/scripts/auto-x-publisher.js"
ROUTE=""
if [ -f "$P" ]; then
  echo "### auto-x-publisher.js"
  echo '```javascript'
  grep -nE 'process\.argv|Usage|usage|--text|--images|--media|entryId|queue' "$P" 2>/dev/null \
    | mask | cut -c1-160 | head -14
  echo '```'
  # 引数で本文と画像を受ける口があるか
  if grep -qE '\-\-text' "$P" && grep -qE '\-\-images|\-\-media' "$P"; then
    ROUTE="A"
  fi
fi
Q="$W/scripts/queue-manager.js"
if [ -z "$ROUTE" ] && [ -f "$Q" ]; then
  echo "### queue-manager.js（enqueue の受け口）"
  echo '```javascript'
  grep -nE 'enqueue|kind|images|media|required|schema' "$Q" 2>/dev/null \
    | mask | cut -c1-160 | head -16
  echo '```'
  grep -q 'enqueue' "$Q" && [ -f "$P" ] && ROUTE="B"
fi
echo
echo "- 採る経路: **${ROUTE:-C（成立せず）}**"

echo
echo "## 3. 投稿"
echo
case "$ROUTE" in
  A)
    echo "経路A: \`auto-x-publisher.js --text ... --images ...\`"
    R1="$("$NODE_BIN" "$P" --text "$T1" --images "$IMGS" 2>&1 | tail -5)"
    echo '```'; printf '%s\n' "$R1" | hide | mask | cut -c1-160; echo '```'
    TID="$(printf '%s' "$R1" | grep -oE '"x_tweet_id":"[0-9]+"|status/[0-9]+' | grep -oE '[0-9]{6,}' | head -1)"
    if [ -n "$TID" ]; then
      echo "- **[1/2] を出した**: $TID"
      R2="$("$NODE_BIN" "$P" --text "$T2" --reply-to "$TID" 2>&1 | tail -5)"
      echo '```'; printf '%s\n' "$R2" | hide | mask | cut -c1-160; echo '```'
    else
      echo "- **[1/2] の投稿 ID を取れない。[2/2] は出さない。**"
    fi
    ;;
  B)
    echo "経路B: queue-manager.js で積んで auto-x-publisher.js を id 指定で叩く"
    ID="sauna-x-$(date +%Y%m%d-%H%M)"
    PAYLOAD="$("$NODE_BIN" -e '
const [id,text,imgs,url]=process.argv.slice(2);
console.log(JSON.stringify({id,kind:"post",text,images:imgs.split(","),target_url:url}));
' "$ID" "$T1" "$IMGS" "https://daily-hack.fieldbeside.com/posts/sauna-openings-2026/")"
    ENQ="$(printf '%s' "$PAYLOAD" | "$NODE_BIN" "$Q" enqueue 2>&1 | tail -3)"
    echo '```'; printf '%s\n' "$ENQ" | hide | mask | cut -c1-160; echo '```'
    if printf '%s' "$ENQ" | grep -q '"ok":true'; then
      R1="$("$NODE_BIN" "$P" "$ID" 2>&1 | tail -5)"
      echo '```'; printf '%s\n' "$R1" | hide | mask | cut -c1-160; echo '```'
    else
      echo "- **enqueue に失敗。投稿しない。**"
    fi
    ;;
  *)
    echo "**成立する口が無い。出さない。** 上の §2 の内容を見て次を決める。"
    ;;
esac

echo
echo "## 4. 出た件数を数える（**2 件以上なら事故**）"
echo
AFTER="$(count_posted)"
echo "- 投稿済みエントリ: 前 ${BEFORE} 件 → 後 **${AFTER} 件**"
if [ "${AFTER:-0}" -gt 1 ] 2>/dev/null; then
  echo
  echo "🚨 **2 件以上 出ている。二重投稿の可能性。すぐ確認して余分を消すこと。**"
elif [ "${AFTER:-0}" = "1" ]; then
  echo "- **1 件だけ。正常。**"
else
  echo "- **出ていない。** ロックを外すので次の周回で再試行される"
  rm -f "$LOCK"
fi
} > "$OUT" 2>&1

if [ -f "$OUT" ]; then mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; fi
n="$(grep -oE '後 \*\*[0-9-]+ 件' "$OUT" 2>/dev/null | grep -oE '[0-9-]+' | head -1)"
if grep -q '既に出ている' "$OUT" 2>/dev/null; then echo "既に投稿済み。何もしなかった / $(basename "$OUT")"
elif [ "${n:-0}" = "1" ]; then echo "**投稿した**（1 件）/ $(basename "$OUT")"
else echo "投稿していない（${n:-?} 件）/ $(basename "$OUT")"; fi
