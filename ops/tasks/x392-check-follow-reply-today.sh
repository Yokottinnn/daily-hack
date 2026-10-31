#!/bin/bash
# x392（2026-10-31・読むだけ）: 利用者「いまフォローとか返信ってちゃんと動いている？」
# 今日（JST）のフォロー・返信・アンフォローのジョブが、実際に押したかをログから数える。
# 書き換えは一切しない。他人のハンドルは伏せる（@*** / x.com/***）。
set -u
OUT="${OPS_REPORT_DIR:-/tmp}/x392-follow-reply-today.md"
exec > >(tee "$OUT") 2>&1
echo "# 今日のフォロー・返信・アンフォロー（読むだけ・\$0）"
WS="$HOME/.openclaw/workspace"
LOGS="$WS/logs"
TODAY="$(TZ=Asia/Tokyo date +%Y-%m-%d)"
mask() { sed -E 's#@[A-Za-z0-9_]{1,15}#@***#g; s#(x|twitter)\.com/[A-Za-z0-9_]{1,15}#\1.com/***#g'; }
echo "now_jst=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M') today=$TODAY"

echo "== ジョブの状態（launchctl print）"
for L in competitor-follower-follow hashtag-follow badge-followback follow-balance mutual-prune reply-followers-cleanup reply-followback-check comment-warmup incoming-reply-watcher; do
  out="$(launchctl print "gui/$(id -u)/ai.openclaw.$L" 2>/dev/null)"
  if [ -z "$out" ]; then echo "$L: 載っていない"; continue; fi
  runs="$(printf '%s\n' "$out" | awk -F'= ' '/^\truns =/{print $2; exit}')"
  lec="$(printf '%s\n' "$out" | awk -F'= ' '/last exit code =/{print $2; exit}')"
  st="$(printf '%s\n' "$out" | awk -F'= ' '/^\tstate =/{print $2; exit}')"
  echo "$L: state=$st runs=$runs last_exit=$lec"
done

echo "== 今日のログ（ファイルごとに 今日の日付を含む行数・最終更新・末尾 6 行）"
for f in competitor-follower-follow hashtag-follow badge-followback follow-balance mutual-prune reply-followers-cleanup comment-warmup comment-orchestrator incoming-reply-watcher; do
  for p in "$LOGS/$f.log" "$LOGS/$f.out" "$LOGS/$f.err"; do
    [ -f "$p" ] || continue
    n="$(grep -c "$TODAY" "$p" | head -1)"; case "$n" in ''|*[!0-9]*) n=0;; esac
    m="$(TZ=Asia/Tokyo date -r "$p" '+%m-%d %H:%M' 2>/dev/null)"
    echo "--- $(basename "$p")  今日の行=$n  最終更新=$m"
    tail -n 6 "$p" | cut -c1-220 | mask
  done
done

echo "== 今日の「押した」語の数（ログ全体から今日の行だけ）"
for f in competitor-follower-follow hashtag-follow badge-followback follow-balance mutual-prune reply-followers-cleanup comment-warmup comment-orchestrator incoming-reply-watcher; do
  p="$LOGS/$f.log"; [ -f "$p" ] || continue
  fo="$(grep "$TODAY" "$p" | grep -ciE 'followed|フォローした|follow ok|"followed"' | head -1)"
  un="$(grep "$TODAY" "$p" | grep -ciE 'unfollowed|解除した|フォロー解除' | head -1)"
  re="$(grep "$TODAY" "$p" | grep -ciE 'replied|返信した|posted|tweet_id' | head -1)"
  sk="$(grep "$TODAY" "$p" | grep -ciE 'skip|見送り|pacer|待つ|rate' | head -1)"
  er="$(grep "$TODAY" "$p" | grep -ciE 'error|fail|失敗|timeout' | head -1)"
  echo "$f: follow=$fo unfollow=$un reply=$re skip=$sk error=$er"
done

echo "== 30 分台帳（いま時点・種類ごとの回数と最後の時刻）"
node -e '
const fs=require("fs");const p=process.argv[1];
try{const j=JSON.parse(fs.readFileSync(p,"utf8"));for(const [k,v] of Object.entries(j)){const a=(v||[]);const last=a.length?new Date(a[a.length-1]+9*3600e3).toISOString().slice(11,16):"-";console.log(k,"件数",a.length,"最後",last,"JST")}}catch(e){console.log("読めない",e.message)}' "$WS/data/x-action-ledger.json"
exit 0
