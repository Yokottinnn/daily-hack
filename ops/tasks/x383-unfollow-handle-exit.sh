#!/bin/bash
# **unfollow-handle.js が結果を出したあと終わらない（x382 で特定）のを直す（x383）。$0。**
# x382: 02:27:59 に結果の JSON を出してタブも閉じたのに、Chrome とのつながり（CDP）が残ってプロセスが生き続け、
# 120 秒で x380 の時間切れに当たっていた。親（reply-followers-cleanup）は時間切れで結果を捨て、毎時 同じ 20 件を打ち直していた。
# 直し方: 結果の JSON（{"ok":…）を 1 行出したら 0.5 秒後に終える。browser.close() は呼ばない（Chrome ごと落ちうる・09-13 の注記）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; UH="$S/unfollow-handle.js"; RF="$S/reply-followers-cleanup.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x383-unfollow-handle-exit.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
H="mao_otk_tw"   # x382 で「もうフォローしていない」と出た相手。確かめても誰も外れない
mask() { sed -E "s/$H/<伏せ>/g; s/@[A-Za-z0-9_]{3,15}/@<伏せ>/g"; }
{
echo "# 外す処理が終わらないのを直す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
cp -p "$UH" "$UH.bak-x383"
if grep -q 'x383:' "$UH"; then echo "もう入っている"; else
"$NODE_BIN" -e '
const fs=require("fs");const p=process.argv[1];const L=fs.readFileSync(p,"utf8").split("\n");
const snip="/* x383: 結果の JSON を出したら終える（CDP のつながりが残って終わらず、親に 120 秒で捨てられていた） */ { const _cl=console.log; console.log=(...a)=>{ _cl(...a); if(typeof a[0]===\"string\"&&a[0].startsWith(\"{\\\"ok\\\":\")) setTimeout(()=>process.exit(0),500); }; }";
let i=L.findIndex(l=>l.includes("x380:")); i = i>=0 ? i+1 : (L[0].startsWith("#!")?1:0);
L.splice(i,0,snip);fs.writeFileSync(p,L.join("\n"));console.log("入れた（"+(i+1)+" 行目）");' "$UH"
fi
if "$NODE_BIN" --check "$UH" 2>/dev/null; then echo "構文 OK"; else cp -p "$UH.bak-x383" "$UH"; echo "**構文が壊れたので元に戻した**"; fi
echo '```'

echo; echo "## 確かめる（もうフォローしていない相手で 1 回。何も外れない）"; echo '```'
T0=$(date +%s)
"$NODE_BIN" "$UH" "$H" 2>&1 | tail -3 | mask &
P=$!
while kill -0 "$P" 2>/dev/null; do [ $(( $(date +%s) - T0 )) -ge 130 ] && break; sleep 1; done
if kill -0 "$P" 2>/dev/null; then kill "$P" 2>/dev/null; echo "→ **130 秒で終わらなかった（直っていない）**"; else wait "$P"; echo "→ 終わった 経過 $(( $(date +%s) - T0 )) 秒（直す前は毎回 120 秒）"; fi
echo '```'

echo; echo "## 親は「もうフォローしていない」をどう扱うか"; echo '```'
grep -n -E 'not_following|status ?===?|unfollowed_at|no unfollow' "$RF" | head -15 | cut -c1-200
echo '```'
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。外していない。**"
} > "$OUT" 2>&1
echo "x383 / $(basename "$OUT")"
