#!/bin/bash
# **返信を再開する。`comment-warmup` を 8 件/日 で起動する。**
#
# ## 承認の記録
#
# 2026-09-06、`x03` の返信案 10 件（実際は 8 件 評価・4 件 通過）を利用者が読み、
# **「この文面で OK。起動する」**と承認。**8 件/日**（1 回 2 件 × 日 4 回）。
#
#   実測 $0.003/件 → **$0.024/日・$0.72/月**
#
# ## 起動してよい根拠（すべて実測で確認済み）
#
#   * 配線: `asuka-fill.js` **0 箇所** / `asuka-reply.cjs` **1 箇所**・`bash -n` 通過
#   * 部品: `.cjs` 5 本・JSON 4 本すべて構文 OK
#   * 生成: 8 件 評価して 4 件 通過。**固有名詞（BNB / iDeco / 松井 / 企業型DC）を拾っている**
#   * ゲート: PR 投稿 2 件・絵文字の重複 2 件を**弾いた**
#   * NG ルール: `x01` で古い版に上書きした分を `x02` で 4160 B に**復元済み**
#
# ## 8/15 の事故を繰り返さない
#
# `comment-warmup` は実機で **`MAX_PICKS_PER_FIRE=8`（想定 2 の 4 倍・32 件/日）**で
# 動いていたことがある。**起動する前に plist の実値を読み、2 でなければ直す。**
# **plist を読まずに load しない。**
#
# ## やること
#
#   1. plist の存在と `plutil -lint` を確かめる（壊れていれば起動しない）
#   2. **`MAX_PICKS_PER_FIRE` の実値を読む。** 2 でなければ 2 に直す（退避を取る）
#   3. `launchctl load` する
#   4. **ロードされたことを `launchctl list` で確かめる**
#      （CLAUDE.md: ログが動いても復活の証拠にならない。判定は `launchctl list`）
#   5. **1 回だけ手で走らせて、実際に返信が出るところまで見届ける**
#      （`launchctl kickstart -k`。次の定時を待たない＝最上位ルール 9）
#   6. 出た返信を**本文つきで**出す
#
# ## やらないこと
#
# **8 件/日 を超える設定にしない。他のジョブを触らない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/start-comment-warmup.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LA="$HOME/Library/LaunchAgents"
LBL="ai.openclaw.comment-warmup"
P="$LA/$LBL.plist"
STAMP="$(date +%Y%m%d-%H%M%S)"
WANT_PICKS=2

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# 返信を再開する（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> 利用者が \`x03\` の文面を読んで **「この文面で OK。起動する」** と承認。"
echo "> **8 件/日**（1 回 2 件 × 日 4 回）。実測 \$0.003/件 → **\$0.024/日・\$0.72/月**。"
echo "> **8/15 に \`MAX_PICKS_PER_FIRE=8\`（32 件/日）で暴走した前科がある。**"
echo "> **plist を読まずに load しない。**"

echo
echo "## 1. plist を読む"
echo
if [ ! -f "$P" ]; then
  echo "- **plist が無い（\`$P\`）。起動しない。**"
  exit 1
fi
echo "- $(wc -c < "$P" | tr -d ' ') B / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
LINT="$(plutil -lint "$P" 2>&1 | tail -1)"
echo "- \`plutil -lint\`: $(printf '%s' "$LINT" | clean)"
case "$LINT" in
  *OK*) ;;
  *) echo; echo "- **plist が壊れている。起動しない。**"; exit 1 ;;
esac
echo
echo '```xml'
cat "$P" 2>/dev/null | clean
echo '```'

echo
echo "## 2. 1 回あたりの件数を 2 にする"
echo
CUR="$(plutil -extract EnvironmentVariables.MAX_PICKS_PER_FIRE raw -o - "$P" 2>/dev/null || echo "")"
echo "- 現在の \`MAX_PICKS_PER_FIRE\`: **${CUR:-（設定なし）}**"
if [ "$CUR" = "$WANT_PICKS" ]; then
  echo "- 望む値と同じ。**触らない。**"
else
  cp -p "$P" "$P.bak.$STAMP"
  if [ -z "$CUR" ]; then
    plutil -insert EnvironmentVariables.MAX_PICKS_PER_FIRE -string "$WANT_PICKS" "$P" 2>/dev/null \
      || plutil -replace EnvironmentVariables -json "{\"MAX_PICKS_PER_FIRE\":\"$WANT_PICKS\"}" "$P" 2>/dev/null
  else
    plutil -replace EnvironmentVariables.MAX_PICKS_PER_FIRE -string "$WANT_PICKS" "$P" 2>/dev/null
  fi
  NEW="$(plutil -extract EnvironmentVariables.MAX_PICKS_PER_FIRE raw -o - "$P" 2>/dev/null || echo "")"
  echo "- **${CUR:-なし} → ${NEW:-失敗}** に直した（退避 \`.bak.$STAMP\`）"
  if [ "$NEW" != "$WANT_PICKS" ]; then
    echo "- **直せなかった。退避から戻して起動しない。**"
    cp -p "$P.bak.$STAMP" "$P"; exit 1
  fi
  plutil -lint "$P" >/dev/null 2>&1 || { echo "- **直したら壊れた。戻す。**"; cp -p "$P.bak.$STAMP" "$P"; exit 1; }
fi

echo
echo "## 3. 起動する"
echo
echo '```'
launchctl load -w "$P" 2>&1 | head -5 | clean
launchctl enable "gui/$(id -u)/$LBL" 2>&1 | head -3 | clean
echo '```'
echo
echo "### \`launchctl list\` で確かめる（**ログでは判定しない**）"
echo
echo '```'
LINE="$(launchctl list 2>/dev/null | grep -F "$LBL" || true)"
if [ -z "$LINE" ]; then
  echo "  **ロードできていない**"
else
  printf '%s\n' "$LINE" | awk '{printf "  ロード済み  PID=%-8s 最後のrc=%s\n", $1, $2}'
fi
echo '```'
if [ -z "$LINE" ]; then
  echo
  echo "- **ロードできていない。ここで止める。**"
  exit 1
fi

echo
echo "## 4. 定時を待たずに 1 回 走らせる"
echo
echo "**次の周回を待たない**（CLAUDE.md 最上位ルール 9）。実際に返信が出るまで見届ける。"
echo
BEFORE="$("$NODE_BIN" -e '
const fs=require("fs");
try{const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
console.log((q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")).length)}catch(e){console.log(-1)}
' "$W/data/post_queue.json")"
echo "- 走らせる前の comment/reply 件数: **$BEFORE**"
echo
echo '```'
launchctl kickstart -k "gui/$(id -u)/$LBL" 2>&1 | head -5 | clean
echo '```'
echo
echo "- 走り終わるのを待つ（最大 240 秒）"
LOG="$W/logs/comment-warmup.log"
BEFORE_MTIME="$(stat -f '%m' "$LOG" 2>/dev/null || echo 0)"
i=0
while [ $i -lt 240 ]; do
  sleep 10; i=$((i+10))
  NOW_MTIME="$(stat -f '%m' "$LOG" 2>/dev/null || echo 0)"
  [ "$NOW_MTIME" != "$BEFORE_MTIME" ] && break
done
echo "- 待った時間: **${i} 秒**（ログ更新: $([ "$NOW_MTIME" != "$BEFORE_MTIME" ] && echo あり || echo なし)）"

echo
echo "### \`comment-warmup.log\` の末尾"
echo
echo '```'
tail -30 "$LOG" 2>/dev/null | clean
echo '```'

echo
echo "## 5. 実際に出た返信"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
let q; try{ q=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }catch(e){ console.log("  キューが読めない"); process.exit(0); }
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply"));
console.log("  comment/reply 合計: "+rows.length+" 件（開始前 "+process.argv[2]+"）");
const today=new Date().toISOString().slice(0,10);
const mine=rows.filter(e=>String(e.created_at||e.posted_at||"").slice(0,10)===today);
console.log("  今日つくられた: "+mine.length+" 件");
const by={}; for(const e of mine) by[e.status||"(なし)"]=(by[e.status||"(なし)"]||0)+1;
Object.entries(by).forEach(([k,v])=>console.log("    "+String(k).padEnd(20)+v+" 件"));
mine.slice(-4).forEach((e,i)=>{
  console.log("");
  console.log("  --- 今日の "+(i+1)+" 件目 / status="+(e.status||"?")+" ---");
  console.log("  "+String(e.text||"").replace(/\n/g,"\n  "));
  if(e.x_tweet_id||e.tweet_id) console.log("  tweet_id: "+(e.x_tweet_id||e.tweet_id));
});
' "$W/data/post_queue.json" "$BEFORE" 2>&1 | clean
echo '```'

echo
echo "---"
echo
echo "**8 件/日 を超える設定にしていない。他のジョブは触っていない。**"
echo "**実測 \$0.003/件 → \$0.024/日・\$0.72/月。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'ロード済み' "$OUT" 2>/dev/null; then
  echo "**返信を再開した（8 件/日・\$0.024/日）** / $(basename "$OUT")"
else
  echo "**起動できていない。レポートを読むこと** / $(basename "$OUT")"
fi
