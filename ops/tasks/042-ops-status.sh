#!/bin/bash
# **返信とフォローが本当に動いているかを、実数で出す。**
#
# Jordan の問い「いまちゃんと返信 and フォローのオペレーションが動いているか」
#
# ## 040 の間違いを直す
#
# 040 は `tone-gate` を **comment-warmup.log だけ**で探して「0 行」と報告した。
# だが orchestrator の `$LOG` がどのファイルかを確かめていない。
# **ログ名を当て推量した誤判定は、025（日付照合）・027（ログ名）に続いて 3 度目。**
#
# ここでは **logs/ 配下を全部 grep する。** どのファイルに出ているかも一緒に出す。
#
# ## 出すもの
#
#   1. tone-gate / ng-filter が「どのログに・何行」出ているか（全ログ横断）
#   2. 返信: 発火ごとの drafts 数と、実際に投稿された件数
#   3. フォロー: ジョブごとの ✅/❌ の実数（cap ではなく実績）
#   4. フォロワー推移と目標までのペース
#   5. auth の期限切れが何のトークンなのか（**キー名だけ。値は出さない**）
#
# **上限と実績を混同しない。** 両方出してどちらがどちらか明示する。
#
# **読むだけ。何も書き換えない。LLM を呼ばない（費用 $0）。**
# **ハンドルは伏せる。** **plutil -extract は使わない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/ops-status.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide_handle() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
TODAY="$(date '+%Y-%m-%d')"

{
echo "# 返信とフォローは動いているか（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **上限と実績を混同しない。** 両方出す。"
echo "> **ログ名を当て推量しない。** logs/ を全部 grep する。"

echo
echo "## 1. 出口の検査はどのログに出ているか（040 の訂正）"
echo
echo "040 は comment-warmup.log だけを見て「0 行」と報告した。**探す場所が違った可能性がある。**"
echo
for pat in tone-gate ng-filter; do
  echo "### \`$pat\`"
  found=0
  for f in "$W"/logs/*.log; do
    [ -f "$f" ] || continue
    n="$(grep -c -- "$pat" "$f" 2>/dev/null || true)"
    if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
      echo "- $(basename "$f"): **${n} 行**"
      found=1
    fi
  done
  [ "$found" = "0" ] && echo "- **logs/ のどこにも出ていない**"
  echo
done
echo "orchestrator が stderr を書く先（\$LOG の定義）:"
echo '```bash'
grep -nE '^[[:space:]]*LOG=' "$W/scripts/comment-orchestrator.sh" 2>/dev/null | mask | cut -c1-140
echo '```'
echo
echo "tone-gate の直近の行（見つかった全ログから）:"
grep -h -- 'tone-gate' "$W"/logs/*.log 2>/dev/null | tail -12 | hide_handle | mask | cut -c1-150 | sed 's/^/    /'
grep -qh -- 'tone-gate' "$W"/logs/*.log 2>/dev/null || echo "    （まだ 1 行も無い）"

echo
echo "## 2. 返信 — 実績"
echo
for name in comment-warmup comment-orchestrator incoming-reply-watcher; do
  L="$W/logs/$name.log"
  [ -f "$L" ] || { echo "### $name — ログ無し"; echo; continue; }
  echo "### $name"
  echo "- 最終更新: $(date -r "$L" '+%m-%d %H:%M' 2>/dev/null)"
  echo "- 本日（$TODAY）の発火: $(grep -c "$TODAY.*orchestrator start" "$L" 2>/dev/null || true) 回"
  # **投稿行に日付の接頭辞が無い。** entry_id に埋まっている YYYYMMDD で数える
  echo "- 本日 実際に投稿できた件数: $(grep -c "comment-$(date '+%Y%m%d')-.*x_tweet_id\|x_tweet_id.*comment-$(date '+%Y%m%d')-" "$L" 2>/dev/null || true) 件"
  echo "  （日付の接頭辞が無い行があるため entry_id の YYYYMMDD で数えている）"
  echo "- 直近の締め行:"
  grep -E 'orchestrator done|=== end' "$L" 2>/dev/null | tail -4 | mask | cut -c1-140 | sed 's/^/      /'
  echo
done

echo
echo "## 3. フォロー — 実績（cap ではなく実数）"
echo
for row in "competitor-follower-follow:COMPETITOR_FOLLOW_DAILY_CAP:④ 競合フォロー" \
           "hashtag-follow:HASHTAG_FOLLOW_DAILY_CAP:④ タグフォロー" \
           "badge-followback::② フォロー返し" \
           "auto-detect-and-unfollow-inactive::③ アンフォロー"; do
  name="${row%%:*}"; rest="${row#*:}"; envk="${rest%%:*}"; role="${rest#*:}"
  L="$W/logs/$name.log"
  echo "### $role — $name"
  P="$HOME/Library/LaunchAgents/ai.openclaw.$name.plist"
  if [ -n "$envk" ] && [ -f "$P" ]; then
    v="$(plutil -p "$P" 2>/dev/null | grep -A1 "\"$envk\"" | grep -oE '"[0-9]+"' | tr -d '"' | head -1)"
    echo "- **上限**（$envk）: ${v:-読めない}  ← 安全弁。予想件数ではない"
  fi
  if [ ! -f "$L" ]; then echo "- ログ無し"; echo; continue; fi
  echo "- 最終更新: $(date -r "$L" '+%m-%d %H:%M' 2>/dev/null)"
  echo "- 本日の **成功（✅）**: $(grep "$TODAY" "$L" 2>/dev/null | grep -c '✅' || true) 件"
  echo "- 本日の **失敗（❌）**: $(grep "$TODAY" "$L" 2>/dev/null | grep -c '❌' || true) 件"
  echo "- 直近 3 日の締め行:"
  grep -E '=== end|followed_back|done' "$L" 2>/dev/null | tail -6 | hide_handle | mask | cut -c1-140 | sed 's/^/      /'
  echo "- 本日 弾いた理由の内訳:"
  grep "$TODAY" "$L" 2>/dev/null | grep -oE '❌ [^(（]{3,40}' | sort | uniq -c | sort -rn | head -8 | sed 's/^/      /'
  echo
done

echo
echo "## 4. フォロワー推移と目標"
echo
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
try{
  const pairs={};
  for(const line of fs.readFileSync(p,"utf8").split("\n")){
    const md=line.match(/(\d{4}-\d{2}-\d{2})/), mc=line.match(/"count_today":(\d+)/);
    if(md&&mc) pairs[md[1]]=+mc[1];
  }
  const it=Object.entries(pairs).sort().slice(-10);
  let prev=null;
  for(const [d,c] of it){ console.log("    "+d+"  "+c+(prev===null?"":"  ("+(c-prev>=0?"+":"")+(c-prev)+")")); prev=c; }
  if(it.length>=2){
    const a=it[0], b=it[it.length-1];
    const days=(new Date(b[0])-new Date(a[0]))/86400000||1;
    const pace=(b[1]-a[1])/days;
    const left=(new Date("2026-09-30")-new Date(b[0]))/86400000;
    console.log("");
    console.log("  実測ペース: "+(pace>=0?"+":"")+pace.toFixed(2)+" 人/日");
    console.log("  必要ペース: +"+((300-b[1])/left).toFixed(2)+" 人/日（残り "+Math.round(left)+" 日）");
    console.log("  このままの 9/30 見込み: 約 "+Math.round(b[1]+pace*left)+" 人");
  }
}catch(e){ console.log("    読めない: "+e.message); }
' "$W/logs/follower-snapshot.log" 2>&1 | head -18

echo
echo "## 5. 期限切れのトークンは何か（**キー名だけ。値は出さない**）"
echo
echo "heartbeat が \`auth.ok: false / トークンの有効期限を過ぎている\` を出している。"
echo "**それでも投稿は続いている**ので、X の投稿に使う認証とは別の可能性がある。どれか確かめる。"
echo
echo "ops-heartbeat.sh が auth を組み立てている箇所:"
echo '```bash'
grep -nE 'auth|expires_at|有効期限' "$HOME/.openclaw/workspace/scripts/ops-heartbeat.sh" 2>/dev/null \
  | mask | cut -c1-140 | head -12
echo '```'
if [ ! -s /dev/null ]; then :; fi
for f in "$HOME/projects/anta-baka-x/blog/scripts/ops-heartbeat.sh"; do
  [ -f "$f" ] || continue
  echo
  echo "リポジトリ側の同ファイル:"
  echo '```bash'
  grep -nE 'auth|expires_at|有効期限' "$f" 2>/dev/null | mask | cut -c1-140 | head -12
  echo '```'
done

echo
echo "## 6. まとめの判定"
echo
echo "- 返信が動いている＝**本日の x_tweet_id が 1 件以上**"
echo "- フォローが動いている＝**本日の ✅ が 1 件以上**"
echo "- 出口の検査が動いている＝**tone-gate の行がどこかのログに出ている**"
echo
echo "**ログがある＝動いている、ではない。** 上の 3 つの実数で判断すること。"
} > "$OUT" 2>&1

tg="$(grep -c 'tone-gate' "$OUT" 2>/dev/null || true)"
echo "稼働状況を出した / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
