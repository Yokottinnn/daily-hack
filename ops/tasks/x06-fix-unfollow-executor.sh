#!/bin/bash
# **アンフォローの実行役に上限を入れて起動する。費用 $0。**
#
# ## 真因（x05 で確定）
#
# 滞留 196 件を処理するのは **`reply-followers-cleanup.js`**。
# これを呼ぶ plist は **存在し、壊れてもいない**（`plist_mtime 2026-05-13`＝
# 8/22 の破壊を免れている）。
#
#   ai.openclaw.reply-followers-cleanup   **未ロード**
#
# **ただ単に、ロードされていなかった。**
# 壊れた 6 本（`unfollow-cleanup.js` 系）は**別系統**で、滞留の原因ではない。
#
# ## そのまま load してはいけない
#
# `reply-followers-cleanup.js` は**期限到来分を全件 まとめて処理する。上限が無い。**
#
#   for (const [handle, e] of Object.entries(state)) { ... due.push(handle) }
#   log(`due unfollows: ${due.length}`)
#
# **196 件を一度に外すと X のスパム判定に触れる。**
# 先に上限を入れる。**入れてから load する。**
#
# ## やること
#
#   1. `reply-followers-cleanup.js` に `CLEANUP_MAX_PER_RUN`（既定 20）を入れる
#   2. `node --check` を通す。通らなければ退避から戻して**何もしない**
#   3. plist を `plutil -lint` で確かめ、通れば load する
#   4. **`CLEANUP_MAX_PER_RUN=5` で 1 回だけ手で走らせる**（いきなり 20 も外さない）
#   5. **実際に外れたかを状態ファイルの前後で数える**
#
# ## やらないこと
#
# **5 件を超えて外さない。他のジョブを触らない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-unfollow-executor.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LBL="ai.openclaw.reply-followers-cleanup"
P="$LA/$LBL.plist"
F="$S/reply-followers-cleanup.js"
STATE="$W/data/reply-followers.json"
STAMP="$(date +%Y%m%d-%H%M%S)"
FIRST_RUN_CAP=5

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

count_due() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const now=Date.now(); let n=0;
  for(const e of Object.values(s)){
    if(e&&e.scheduled_unfollow_at&&new Date(e.scheduled_unfollow_at).getTime()<=now) n++;
  }
  console.log(n);
}catch(e){ console.log(-1); }
' "$STATE" 2>/dev/null || echo -1
}
count_status() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  let n=0; for(const e of Object.values(s)) if(e&&e.followback_status===process.argv[2]) n++;
  console.log(n);
}catch(e){ console.log(-1); }
' "$STATE" "$1" 2>/dev/null || echo -1
}

{
echo "# アンフォローの実行役に上限を入れて起動する（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **真因は「ロードされていなかった」こと。** plist は壊れていない（2026-05-13 のまま）。"
echo "> **だがそのまま load してはいけない。** このスクリプトは期限到来分を"
echo "> **全件 まとめて処理する。上限が無い。196 件を一度に外すと X の判定に触れる。**"
echo "> **先に上限を入れる。**"

echo
echo "## 0. 走らせる前の数"
echo
BEFORE_DUE="$(count_due)"
BEFORE_UNF="$(count_status unfollowed)"
BEFORE_NO="$(count_status no)"
echo "- 期限到来: **${BEFORE_DUE} 件**"
echo "- \`unfollowed\`: **${BEFORE_UNF} 件** / \`no\`: **${BEFORE_NO} 件**"
if [ "$BEFORE_DUE" = "-1" ]; then echo; echo "- **状態ファイルが読めない。何もしない。**"; exit 1; fi

echo
echo "## 1. 上限を入れる"
echo
if [ ! -f "$F" ]; then echo "- **\`reply-followers-cleanup.js\` が無い。何もしない。**"; exit 1; fi
if grep -q 'CLEANUP_MAX_PER_RUN' "$F" 2>/dev/null; then
  echo "- **すでに入っている。触らない。**"
else
  cp -p "$F" "$F.bak.$STAMP"
  "$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
let s=fs.readFileSync(p,"utf8");
const before=s;
// `due unfollows:` を出す直前に上限を差し込む
s=s.replace(/(\n[ \t]*)(log\(`due unfollows:)/,
  "$1const CLEANUP_MAX_PER_RUN = Number(process.env.CLEANUP_MAX_PER_RUN || 20);" +
  "$1if (due.length > CLEANUP_MAX_PER_RUN) {" +
  "$1  log(`due ${due.length} → 上限 ${CLEANUP_MAX_PER_RUN} 件に絞る（残りは次回）`);" +
  "$1  due.length = CLEANUP_MAX_PER_RUN;" +
  "$1}" +
  "$1$2");
if(s===before){ console.log("  **差し込めなかった。行の形が想定と違う。**"); process.exit(2); }
fs.writeFileSync(p+".tmp", s); fs.renameSync(p+".tmp", p);
console.log("  差し込んだ（既定 20 件・環境変数 CLEANUP_MAX_PER_RUN で変えられる）");
' "$F" 2>&1 | clean
  RC=$?
  if [ "$RC" != "0" ]; then
    echo "- **失敗した。退避から戻す。**"; cp -p "$F.bak.$STAMP" "$F"; exit 1
  fi
  if ! "$NODE_BIN" --check "$F" 2>/dev/null; then
    echo "- **構文が通らない。退避から戻す。**"
    "$NODE_BIN" --check "$F" 2>&1 | head -3 | sed 's/^/    /' | clean
    cp -p "$F.bak.$STAMP" "$F"; exit 1
  fi
  echo "- 構文OK（退避 \`.bak.$STAMP\`）"
fi
echo
echo '```javascript'
grep -n -B2 -A5 'CLEANUP_MAX_PER_RUN' "$F" 2>/dev/null | head -20 | clean
echo '```'

echo
echo "## 2. plist を確かめて load する"
echo
if [ ! -f "$P" ]; then echo "- **plist が無い（\`$P\`）。load しない。**"; exit 1; fi
LINT="$(plutil -lint "$P" 2>&1 | tail -1)"
echo "- \`plutil -lint\`: $(printf '%s' "$LINT" | clean)"
case "$LINT" in *OK*) ;; *) echo; echo "- **plist が壊れている。load しない。**"; exit 1 ;; esac
echo
echo '```xml'
cat "$P" 2>/dev/null | clean
echo '```'
echo
echo '```'
launchctl load -w "$P" 2>&1 | head -5 | clean
launchctl enable "gui/$(id -u)/$LBL" 2>&1 | head -3 | clean
echo '```'
echo
echo "### \`launchctl list\` で確かめる"
echo
echo '```'
LINE="$(launchctl list 2>/dev/null | grep -F "$LBL" || true)"
if [ -z "$LINE" ]; then echo "  **ロードできていない**"
else printf '%s\n' "$LINE" | awk '{printf "  ロード済み  PID=%-8s 最後のrc=%s\n", $1, $2}'; fi
echo '```'
[ -z "$LINE" ] && { echo; echo "- **ロードできていない。ここで止める。**"; exit 1; }

echo
echo "## 3. まず ${FIRST_RUN_CAP} 件だけ外す"
echo
echo "**いきなり 20 件も外さない。** 外れることを実物で確かめてから増やす。"
echo
echo '```'
cd "$W" 2>/dev/null || true
CLEANUP_MAX_PER_RUN=$FIRST_RUN_CAP timeout 300 "$NODE_BIN" "$F" 2>&1 | tail -40 | clean
echo "(rc=$?)"
echo '```'

echo
echo "## 4. 実際に外れたか（**状態ファイルの前後で数える**）"
echo
AFTER_DUE="$(count_due)"
AFTER_UNF="$(count_status unfollowed)"
AFTER_LATE="$(count_status yes_late)"
echo "| | 前 | 後 |"
echo "| --- | --- | --- |"
echo "| 期限到来 | ${BEFORE_DUE} | **${AFTER_DUE}** |"
echo "| \`unfollowed\` | ${BEFORE_UNF} | **${AFTER_UNF}** |"
echo "| \`yes_late\`（あとからフォロバ） | — | ${AFTER_LATE} |"
echo
DIFF=$(( AFTER_UNF - BEFORE_UNF ))
echo "- **今回 外した数: ${DIFF} 件**"
if [ "$DIFF" -gt 0 ]; then
  echo "- **外れている。実行役は生きている。**"
elif [ "$AFTER_DUE" -lt "$BEFORE_DUE" ]; then
  echo "- 外してはいないが期限到来が減った＝**あとからフォロバされていた分をキャンセルした**（正しい動き）"
else
  echo "- **何も動いていない。上のログを読むこと。**"
fi
echo
echo "- 残りの期限到来: **${AFTER_DUE} 件**"
echo "  定時実行で 1 回あたり最大 20 件ずつ減る（\`CLEANUP_MAX_PER_RUN\` の既定）"

echo
echo "---"
echo
echo "**${FIRST_RUN_CAP} 件を超えて外していない。他のジョブは触っていない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '外れている。実行役は生きている' "$OUT" 2>/dev/null; then
  echo "**アンフォローを復旧した（上限つきで起動・\$0）** / $(basename "$OUT")"
elif grep -q 'ロード済み' "$OUT" 2>/dev/null; then
  echo "**起動はした。外れたかはレポートを読むこと** / $(basename "$OUT")"
else
  echo "**復旧できていない。レポートを読むこと** / $(basename "$OUT")"
fi
