#!/bin/bash
# x554（2026-11-24・$0）: 画像の説明（ALT）を入れるとき「次の画像」を押す回数が最大 4 回だったため、6 枚目以降に届かず投稿が止まった（x553）。
# 11/24 のクリスマスマーケット（10 枚）が ALT 5 枚目のあと 2 回とも落ちて出なかった。11/25 11:56 のクルーズ船（6 枚）も同じ所で落ちる。
# 直し: 押す回数の上限を 4 → 12 にする（X の上限 10 枚に余裕を足した数）。ほかは触らない。投稿はしない。
set -uo pipefail
S="$HOME/.openclaw/workspace/scripts"; F="$S/post-via-""playwright.js"; BAK="$F.bak-x554"
OUT="${OPS_REPORT_DIR:-/tmp}/x554-fix-alt-next-image-limit.md"
{
echo "# ALT の「次の画像」の回数の直し（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
grep -q "x554" "$F" && { echo "もう直してある"; echo '```'; exit 0; }
cp "$F" "$BAK" && echo "控え: $(basename "$BAK") $(wc -c < "$BAK" | tr -d ' ') bytes"
node - "$F" <<'JS'
const fs=require("fs");const f=process.argv[2];let t=fs.readFileSync(f,"utf8");
const a="for (let guard = 0; at !== i && guard < 4; guard++) {";
const b="for (let guard = 0; at !== i && guard < 12; guard++) { // x554: 4 回では 6 枚目以降に届かない（2026-11-24 クリスマスマーケットで止まった）";
const c=t.split(a).length-1; console.log("置き換える所: "+c+" か所");
if(c!==1){console.log("FAIL 1 か所でない。触らない");process.exit(1);}
fs.writeFileSync(f,t.replace(a,b));console.log("OK 書いた");
JS
if [ $? -ne 0 ]; then cp "$BAK" "$F"; echo "控えに戻した"; echo '```'; exit 1; fi
if node --check "$F" 2>&1; then echo "node --check: 通った"; else cp "$BAK" "$F"; echo "**構文が通らない。控えに戻した**"; echo '```'; exit 1; fi
grep -n "x554" "$F" | cut -c1-160
echo '```'
echo "**LLM 不使用（\$0）。** 次に使うのは 11/25 11:56 のクルーズ船（6 枚）。"
} > "$OUT" 2>&1
tail -c 300 "$OUT"
exit 0
