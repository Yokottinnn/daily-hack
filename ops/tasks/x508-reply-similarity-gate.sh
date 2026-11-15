#!/bin/bash
# x508（2026-11-15・$0）: 返信の言い回しの重なりを防ぐ。利用者がダイアログで「返信の言い回しの重なりを防ぐ」を選んだ。
#  噛み合い検査（reply-relevance-check.cjs）に「文全体の似すぎ」を足す: 直近 50 件の自分の返信と、記号・絵文字を除いた 2 文字ずつの組の重なりが 0.45 以上なら出さない
#  asuka-reply.cjs が渡す直近の返信を 20 件 → 50 件（書き出し・語尾の検査は今までどおり直近 20 件で見る）
# Mac の今のファイルにその場で差し込む（上書きしない）。置く前に node --check。通らなければ元に戻す。LLM の呼び出し回数は変わらない（弾いたぶん作り直すことはない＝増えない）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; D="$W/data"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/x508-reply-similarity-gate.md"
{
echo "# 返信の似すぎを止める（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null
BLK="$(mktemp)"; git -C "$REPO" show origin/main:ops/lib/reply-relevance-check.cjs | awk '/4-C\. \*\*文全体の似すぎ/{f=1} /\/\/ 5\. 直近重複/{f=0} f' > "$BLK"
echo "差し込む塊: $(wc -l < "$BLK" | tr -d ' ') 行"
F="$S/reply-relevance-check.cjs"
if grep -q '4-C. \*\*文全体の似すぎ' "$F"; then echo "relevance: もう入っている"
elif [ "$(wc -l < "$BLK" | tr -d ' ')" -lt 10 ]; then echo "**塊が取れない。入れない**"
else cp -p "$F" "$F.bak-x508"
  "$NODE_BIN" -e 'const fs=require("fs");const [f,b]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");const a="  // 5. 直近重複\n";if(s.split(a).length!==2){console.log("目印が 1 か所でない");process.exit(1)}fs.writeFileSync(f,s.replace(a,fs.readFileSync(b,"utf8")+a));console.log("relevance: 入れた")' "$F" "$BLK"
  "$NODE_BIN" --check "$F" 2>/dev/null && echo "relevance: node --check 通った" || { cp -p "$F.bak-x508" "$F"; echo "**relevance: 通らない。元に戻した**"; }
fi
F="$S/asuka-reply.cjs"
if grep -q 'RECENT_GATE_N' "$F"; then echo "asuka-reply: もう入っている"
else cp -p "$F" "$F.bak-x508"
  "$NODE_BIN" -e 'const fs=require("fs");const f=process.argv[1];let s=fs.readFileSync(f,"utf8");const a="recentReplies(QUEUE, 20)";if(s.split(a).length!==2){console.log("asuka-reply: 目印が 1 か所でない（"+(s.split(a).length-1)+"）");process.exit(1)}fs.writeFileSync(f,s.replace(a,"recentReplies(QUEUE, Number(process.env.RECENT_GATE_N || 50))"));console.log("asuka-reply: 入れた")' "$F"
  "$NODE_BIN" --check "$F" 2>/dev/null && echo "asuka-reply: node --check 通った" || { cp -p "$F.bak-x508" "$F"; echo "**asuka-reply: 通らない。元に戻した**"; }
fi
F="$D/reply-relevance-rules.json"; cp -p "$F" "$F.bak-x508"
"$NODE_BIN" -e 'const fs=require("fs");const f=process.argv[1];const j=JSON.parse(fs.readFileSync(f,"utf8"));j.similar_window=50;j.similar_max=0.45;fs.writeFileSync(f,JSON.stringify(j,null,2)+"\n");console.log("rules: similar_window=50・similar_max=0.45")' "$F" || { cp -p "$F.bak-x508" "$F"; echo "**rules: 書けない。元に戻した**"; }
echo "--- 試し（ほぼ同じ文は止まり、別の話題は通るか）"
"$NODE_BIN" -e '
const {checkRelevance}=require(process.argv[1]);const r=JSON.parse(require("fs").readFileSync(process.argv[2],"utf8"));
const a=checkRelevance({text:"楽天のポイント5倍、エントリー忘れがちなのよね。アタシも昨日やらかしたわ",targetText:"楽天のポイント5倍のエントリー忘れた",recentReplies:["楽天のポイント5倍、エントリー忘れがちなのよね。アタシも先週やらかしたわ"]},r);
const b=checkRelevance({text:"王将の餃子半額券、500円ごとはアツいわね",targetText:"王将の餃子半額券もらった",recentReplies:["ユニクロ感謝祭のヒートテック、毎年すぐ無くなるのよね"]},r);
console.log("ほぼ同じ文: "+(a.reasons.some(x=>/ほぼ同じ文/.test(x))?"止まった":"**止まらない**")+" ／ 別の話題: "+(b.reasons.some(x=>/ほぼ同じ文/.test(x))?"**止まった**":"通った"))' "$S/reply-relevance-check.cjs" "$D/reply-relevance-rules.json"
rm -f "$BLK"
echo '```'; echo "**LLM の呼び出しは増えない（\$0）。**"
} > "$OUT" 2>&1
grep -E '入れた|通った|止まった|止まらない|元に戻した|取れない' "$OUT" | head -6
exit 0
