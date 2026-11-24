#!/bin/bash
# x551（2026-11-24・$0）: スレッドの 2 投稿目が落ちる原因を直す（x550 で読んだ）。
# 原因: 返信する前に相手の投稿へ「いいね」を付ける処理（x154）が、自分の 1 投稿目にも当たる。
#   いいねで画面が描き直され、先に掴んだ入力欄が外れる → 何も打てない（got_len 0）か「Element is not attached」。
# 直し: ① 返信先が自分（heng_ji31590）の投稿なら、いいねを付けない
#       ② クリックの直前に入力欄を取り直す（描き直されても今の欄に打つ）
# 打つ文字・確かめ方（text-mismatch で止まる仕組み）は変えない。投稿はしない。
set -uo pipefail
S="$HOME/.openclaw/workspace/scripts"; F="$S/post-""comment.js"; BAK="$F.bak-x551"
OUT="${OPS_REPORT_DIR:-/tmp}/x551-fix-reply-after-self-like.md"
{
echo "# スレッドの 2 投稿目の直し（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
[ -f "$F" ] || { echo "ファイルが無い。止まる"; echo '```'; exit 1; }
grep -q "x551" "$F" && { echo "もう直してある（x551 の印あり）"; echo '```'; exit 0; }
cp "$F" "$BAK" && echo "控え: $(basename "$BAK") $(wc -c < "$BAK" | tr -d ' ') bytes"
node - "$F" <<'JS'
const fs=require("fs");const f=process.argv[2];let t=fs.readFileSync(f,"utf8");
const a1="const _x154art = await page.$('article[data-testid=\"tweet\"]');";
const b1="const _x154art = /\\/heng_ji31590\\/status\\//.test(String(targetUrl || \"\")) ? null : await page.$('article[data-testid=\"tweet\"]'); // x551: 自分の投稿（スレッドの 2 投稿目）にはいいねしない";
const a2="    await ta.click();\n    // **400ms の固定待ちをやめる。**";
const b2="    // x551: いいねなどで描き直されると先に掴んだ欄が外れる（2026-11-22 CAMP で 2 回）。クリックの直前に取り直す\n    const _x551ta = (await page.$('div[data-testid^=\"tweetTextarea_\"][contenteditable=\"true\"]')) || ta;\n    await _x551ta.click();\n    // **400ms の固定待ちをやめる。**";
const c1=t.split(a1).length-1, c2=t.split(a2).length-1;
console.log("置き換える所: いいね "+c1+" か所 ／ クリック "+c2+" か所");
if(c1!==1||c2!==1){console.log("FAIL 1 か所ずつでない。触らない");process.exit(1);}
t=t.replace(a1,b1).replace(a2,b2);fs.writeFileSync(f,t);console.log("OK 書いた");
JS
RC=$?
if [ "$RC" -ne 0 ]; then cp "$BAK" "$F"; echo "書けなかったので控えに戻した"; echo '```'; exit 1; fi
if node --check "$F" 2>&1; then echo "node --check: 通った"; else cp "$BAK" "$F"; echo "**構文が通らない。控えに戻した**"; echo '```'; exit 1; fi
grep -n "x551" "$F" | cut -c1-160
echo '```'
echo; echo "次に 2 投稿のスレッドが出るのは 11/25 11:56（クルーズ船）。そこで 2 投稿目が出るかを見る。**LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
tail -c 400 "$OUT"
exit 0
