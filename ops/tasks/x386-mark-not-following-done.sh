#!/bin/bash
# **「もうフォローしていない（no unfollow button）」を解除済みとして記録する（x386）。$0。** 利用者がダイアログで「解除済みとして記録する」を選んだ。
# x385: reply-followers-cleanup.js は uo.ok のときだけ記録し、not_following は「unfollow failed」で何も付けない → 毎時 先頭 20 件に居座る。
# 足すのは else if の 1 分岐だけ。印は followback_status=unfollowed・unfollowed_at・unfollow_note（理由つき）。
set -uo pipefail
RF="$HOME/.openclaw/workspace/scripts/reply-followers-cleanup.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x386-mark-not-following-done.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 「もうフォローしていない」を解除済みにする（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
cp -p "$RF" "$RF.bak-x386"
if grep -q 'x386' "$RF"; then echo "もう入っている"; else
"$NODE_BIN" -e '
const fs=require("fs");const p=process.argv[1];let s=fs.readFileSync(p,"utf8");
const old="      } else {\n        log(`@${r.handle}: unfollow failed (${uo.reason || \"unknown\"})`);";
const add="      } else if (uo.status === \"not_following\") {\n        // x386: もうフォローしていない相手は解除済みにする（印を付けないと毎時 先頭 20 件に居座る）\n        e.followback_status = \"unfollowed\";\n        e.unfollowed_at = new Date().toISOString();\n        e.unfollow_note = \"not_following（解除ボタンが無い・x386）\";\n        e.scheduled_unfollow_at = null;\n        log(`@${r.handle}: already not following — marked done (x386)`);\n";
const n=s.split(old).length-1;
if(n!==1){console.log("**当てる場所が "+n+" か所。直していない**");process.exit(0)}
s=s.replace(old,add+old);fs.writeFileSync(p,s);console.log("入れた");' "$RF"
fi
if "$NODE_BIN" --check "$RF" 2>/dev/null; then echo "構文 OK"; else cp -p "$RF.bak-x386" "$RF"; echo "**構文が壊れたので元に戻した**"; fi
echo "--- 直したところ"
grep -n -A8 'not_following' "$RF" | head -12
echo "--- いま動いている回（直す前の中身で動いている。次の毎時から効く）"
ps -axo pid,etime,command | grep reply-followers-cleanup | grep -v grep
echo '```'
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。外していない。**"
} > "$OUT" 2>&1
echo "x386 / $(basename "$OUT")"
