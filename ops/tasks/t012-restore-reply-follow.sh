#!/bin/bash
# **返信・フォローの 3 件だけを戻す。他の 11 件には触らない。**
#
# 利用者の判断（2026-08-31）: 「返信・フォローだけ先に戻す」。
#
# ## 何が起きたか
#
# 14:44 UTC は 20 件 稼働していたのに、15:14 UTC は 6 件になっていた。
# **14 件が未ロードになった。** その中に X の本線が含まれている。
#
#   ai.openclaw.comment-warmup              ← 返信
#   ai.openclaw.competitor-follower-follow  ← フォロー（競合フォロワー）
#   ai.openclaw.hashtag-follow              ← フォロー（ハッシュタグ）
#
# **原因は未特定。** だから**戻すのはこの 3 件だけ**にする。
# 投稿系（draft-* / auto-thread-chainifier など）は止めたままにして、
# 再開直後にまとめて出る事故を避ける（2026-08-15 に実際に起きている）。
#
# ## 積まれたまま待っているものが無いか、先に数える
#
# 2026-08-15、`poll-approvals` が 5 日 止まったあと再開し、**承認から 8 日 経った
# エントリを処理してタイムラインへ意図しない投稿をした。** その後 承認 TTL 7 日を
# 実装してあるが、**戻す前に滞留の件数を数えて報告する。**
#
# ## comment-warmup は暴走したことがある
#
# 実機で `MAX_PICKS_PER_FIRE=8`（想定 2 の 4 倍＝32 件/日）で動いていたことがある。
# **2 を超えていたら戻さない。** 費用が 4 倍になるうえ、返信量として多すぎる。
#
#   想定: 2 picks × 4 fires = 8 件/日 × $0.00417 = $0.033/日 = $1.00/月（実測単価）
#
# ## 自分を殺さない
#
# 触るのは `ai.openclaw.*` の 3 件だけ。このタスクを走らせているのは
# `com.dailyhack.ops-poller` / `ops-heartbeat` なので、巻き添えにならない。
#
# **plist は読むだけ。書き換えない。** `plutil -extract` を `-o -` 無しで使わない
# （2026-08-22 に 56 個 破壊した）。
#
# **ハンドルは伏せる。トークンは出さない。このタスク自体は LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/restore-reply-follow.md"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
QJSON="$W/data/post_queue.json"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

TARGETS="ai.openclaw.comment-warmup ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow"

loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$1" || true; }
# **`-o -` を必ず付ける。** 付けないと plist を壊す
pl() { plutil -extract "$2" raw -o - "$1" 2>/dev/null || echo ""; }

{
echo "# 返信・フォローの 3 件を戻す（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> **原因は未特定。だから 3 件だけ戻す。** 投稿系は止めたままにする"
echo "> （再開直後にまとめて出る事故が 2026-08-15 に起きている）。"

echo
echo "## 1. 戻す前の状態"
echo
for L in $TARGETS; do
  echo "- \`$L\`: ロード=**$(loaded "$L")** 件 / plist=$([ -f "$LA/$L.plist" ] && echo あり || echo '**無し**')"
done

echo
echo "## 2. 積まれたまま待っているものを数える（**戻す前に**）"
echo
if [ -f "$QJSON" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const es=q.queue||[];
  const now=Date.now();
  const by={};
  for(const e of es){ const s=String(e.status||"?"); by[s]=(by[s]||0)+1; }
  console.log("| status | 件数 |"); console.log("| --- | --- |");
  for(const k of Object.keys(by).sort()) console.log(`| \`${k}\` | ${by[k]} |`);
  const wait=es.filter(e=>e.status==="awaiting_approval"||e.status==="approved"||e.status==="pending");
  const old=wait.filter(e=>{
    const t=Date.parse(e.approved_at||e.created_at||e.queued_at||0);
    return t && (now-t) > 7*24*3600*1000;
  });
  console.log("");
  console.log(`- 出番を待っている（pending / awaiting_approval / approved）: **${wait.length} 件**`);
  console.log(`- そのうち **7 日より古い**: **${old.length} 件**（承認 TTL 7 日で失効するはず）`);
}catch(e){ console.log("- キューが読めない: "+e.message); }
' "$QJSON" 2>&1 | head -20
else
  echo "- \`post_queue.json\` が見つからない"
fi

echo
echo "## 3. comment-warmup の返信量を確かめる（**2 を超えていたら戻さない**）"
echo
CW="$LA/ai.openclaw.comment-warmup.plist"
PICKS=""
if [ -f "$CW" ]; then
  # 環境変数は plutil の JSON 出力から読む。**値は出さず、対象キーだけ**
  PICKS="$("$NODE_BIN" -e '
const {execSync}=require("child_process");
try{
  const j=JSON.parse(execSync(`plutil -convert json -o - ${JSON.stringify(process.argv[1])}`,{encoding:"utf8"}));
  const env=j.EnvironmentVariables||{};
  const k=Object.keys(env).find(x=>/MAX_PICKS/i.test(x));
  console.log(k?String(env[k]):"");
}catch(e){ console.log(""); }
' "$CW" 2>/dev/null)"
  echo "- \`MAX_PICKS_PER_FIRE\`: **${PICKS:-未設定（既定値で動く）}**"
  echo "- 起動間隔: StartInterval=**$(pl "$CW" StartInterval)** / Calendar=$(plutil -extract StartCalendarInterval json -o - "$CW" 2>/dev/null | cut -c1-120 || echo '無し')"
else
  echo "- **plist が無い。戻せない。**"
fi

if [ -n "$PICKS" ] && [ "$PICKS" -gt 2 ] 2>/dev/null; then
  echo
  echo "🚨 **\`MAX_PICKS_PER_FIRE=$PICKS\` は想定の 2 を超えている。**"
  echo "2026-08-15 に 8（＝32 件/日）で動いていた前科がある。"
  echo "**費用が $((PICKS / 2)) 倍になるので、comment-warmup は戻さない。**"
  echo "フォローの 2 件だけ戻す。"
  TARGETS="ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow"
fi

echo
echo "## 4. 戻す"
echo
echo "> **plist は読むだけ。書き換えない。** 壊れているものは飛ばす。"
for L in $TARGETS; do
  P="$LA/$L.plist"
  if [ ! -f "$P" ]; then echo "- \`$L\`: **plist が無い。飛ばす**"; continue; fi
  if ! plutil -p "$P" >/dev/null 2>&1; then echo "- \`$L\`: **plist が壊れている。飛ばす**"; continue; fi
  LBL_IN="$(pl "$P" Label)"
  if [ "$LBL_IN" != "$L" ]; then
    echo "- \`$L\`: **中の Label が \`${LBL_IN:-空}\` で一致しない。飛ばす**"; continue
  fi
  if [ "$(loaded "$L")" != "0" ]; then echo "- \`$L\`: 既にロード済み。何もしない"; continue; fi
  launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1
  sleep 1
  if [ "$(loaded "$L")" != "0" ]; then
    echo "- \`$L\`: **ロード成功**"
  else
    echo "- \`$L\`: **ロードできなかった**"
    echo '  ```'
    launchctl bootstrap "gui/$UID_N" "$P" 2>&1 | head -3 | sed 's/^/  /' | mask
    echo '  ```'
  fi
done

echo
echo "## 5. 戻したあとの状態"
echo
for L in ai.openclaw.comment-warmup ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  echo "- \`$L\`: ロード=**$(loaded "$L")** 件"
done
echo
echo "### いま載っているもの（全体）"
echo '```'
launchctl list 2>/dev/null | awk 'NR==1 || /dailyhack|openclaw/ {print}' | head -30 | mask
echo '```'

echo
echo "## 6. まだ戻していないもの"
echo
echo "**投稿系はわざと止めたままにしている。** 再開直後にまとめて出る事故を避けるため。"
echo '```'
for f in "$LA"/*.plist; do
  [ -f "$f" ] || continue
  b="$(basename "$f" .plist)"
  case "$b" in *dailyhack*|*openclaw*) ;; *) continue ;; esac
  [ "$(loaded "$b")" = "0" ] && echo "未ロード: $b"
done | head -30
echo '```'
echo
echo "**費用**: \`comment-warmup\` 8 件/日 × \$0.00417（実測）= \$0.033/日 = **\$1.00/月**。"
echo "フォロー 2 件は LLM を呼ばないので **\$0**。**止まる前の水準に戻すだけで、増額ではない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
OK="$(grep -c 'ロード成功' "$OUT" 2>/dev/null || echo 0)"
if grep -q '🚨' "$OUT" 2>/dev/null; then echo "🚨 **返信量が想定超。フォローのみ戻した（${OK} 件）** / $(basename "$OUT")"
elif [ "${OK:-0}" != "0" ]; then echo "**${OK} 件 戻した** / $(basename "$OUT")"
else echo "**1 件も戻せていない** / $(basename "$OUT")"; fi
