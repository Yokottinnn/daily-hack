#!/bin/bash
# **同じ相手への返信を 1 日 1 回までにし、返す相手を分散させる。費用 $0（LLM を呼ばない）。**
#
# ## 指示（2026-10-11）
#
#   > このアカウントに返信すぎなので控えてほしい（money_yossy）
#   > 同じ相手へのリプライは1日1回迄にして
#   > 何回も同じようの返信するのであれば、他のアカウントに分散させてフォロワー増える機会を効率的に作ってほしい
#
# ## x258 で分かったこと（2026-10-11 16:58 の実測）
#
#   money_yossy への返信 7 件／7 日（10/7・10/11 は 1 日 2 回）。同じ相手に 1 日 2 回の組は 7 組、**全部 comment-warmup**。
#   comment-state.js は相手ごとに 7 日あける作りだが、**record-comment がどこからも呼ばれていない**
#   （daily_counts が 2026-07-06 で止まっている）。だから last_commented_at が古いままで、**間隔が効いていなかった。**
#
# ## やること
#
#   ① ops/lib/reply-once-per-day.cjs を scripts/ に置く（今日 JST にその相手へ積んだ・出した返信をキューから数える）
#   ② comment-orchestrator.sh の「選ぶループ」を 2 か所 直す
#      - 候補を「直近 7 日に返した回数が少ない順」に並べ替える（同じ回数なら元の順のまま）→ **分散**
#      - can-comment に加えて reply-once-per-day も通ったものだけ選ぶ → **1 日 1 回**
#   ③ 直した「選ぶループ」を、偽の候補（money_yossy と、今日まだ返していない相手）で実際に走らせて確かめる
#      can-comment は読むだけ（record しない）なので、状態は変わらない
#
# **量（MAX_PICKS_PER_FIRE=4・16 件/日）は変えない。** 返せない相手の枠は、次の候補で埋まる。
# 置き換える前のファイルは .bak.<時刻> に退避する。目印が見つからなければ**何も書き換えずに止まる。**
#
# 費用: **$0／回・$0／日・$0／月**（このタスク）。返信ジョブの費用は件数が変わらないので据え置き（月 $1.44）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-once-per-target.md"
STAMP="$(date +%Y%m%d-%H%M%S)"
ORCH="$S/comment-orchestrator.sh"
GUARD="$S/reply-once-per-day.cjs"
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(xox[abp]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
hide() { perl -pe 's/@(?!(?:heng_ji31590|money_yossy)\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# 同じ相手への返信を 1 日 1 回まで・相手を分散（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"

echo
echo "## ① 判定の部品を置く"
echo
echo '```'
TMP="$GUARD.x259.$STAMP"
if git -C "$REPO" show "origin/main:ops/lib/reply-once-per-day.cjs" > "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
  [ -f "$GUARD" ] && cp -p "$GUARD" "$GUARD.bak.$STAMP"
  mv "$TMP" "$GUARD"
  echo "  置いた: $(basename "$GUARD") $(wc -c < "$GUARD" | tr -d ' ') B"
else
  rm -f "$TMP"; echo "  **取れない: origin/main:ops/lib/reply-once-per-day.cjs**（何も書き換えずに止める）"; echo '```'; exit 1
fi
echo "  money_yossy の今日: $(node "$GUARD" money_yossy 2>&1)"
echo '```'

echo
echo "## ② comment-orchestrator.sh の選ぶループを直す"
echo
echo '```'
node - "$ORCH" "$STAMP" <<'NODE' 2>&1
const fs = require("fs");
const [file, stamp] = process.argv.slice(2);
let s = fs.readFileSync(file, "utf8");
if (s.includes("reply-once-per-day")) { console.log("  もう入っている（据置）"); process.exit(0); }
const A = "  for (const item of items) {\n";
const B = "      if (can.ok) { picked.push(item); seen.add(item.author); }\n";
const cnt = (x) => s.split(x).length - 1;
if (cnt(A) !== 1 || cnt(B) !== 1) { console.log("  **目印が見つからない（A=" + cnt(A) + " / B=" + cnt(B) + "）。書き換えない**"); process.exit(2); }
// bash の "..." の中に入る JS なので、ダブルクォートと $ を使わない
const A2 =
"  // 2026-10-11 x259: 直近 7 日に返した回数が少ない相手を先に選ぶ（同じ回数なら元の順）。返す相手を分散させる\n" +
"  const ONCE = require('/Users/ny/.openclaw/workspace/scripts/reply-once-per-day.cjs');\n" +
"  const recent = {};\n" +
"  try {\n" +
"    const q = JSON.parse(fs.readFileSync('/Users/ny/.openclaw/workspace/data/post_queue.json', 'utf8')).queue || [];\n" +
"    const since = Date.now() - 7 * 864e5;\n" +
"    for (const e of q) { const h = ONCE.handleOf(e); const t = Date.parse(e.posted_at || e.created_at || ''); if (h && t >= since) recent[h] = (recent[h] || 0) + 1; }\n" +
"  } catch (e) {}\n" +
"  const rc = (it) => recent[String(it.author || '').replace(/^@/, '').toLowerCase()] || 0;\n" +
"  items.sort((a, b) => rc(a) - rc(b));\n" +
A;
const B2 =
"      // 2026-10-11 x259: 同じ相手への返信は 1 日（JST）1 回まで。ジョブをまたいでキューから数える\n" +
"      const once = ONCE.check(item.author);\n" +
"      if (can.ok && !once.ok) console.error('skip @' + item.author + ': ' + once.reason);\n" +
"      if (can.ok && once.ok) { picked.push(item); seen.add(item.author); }\n";
fs.copyFileSync(file, file + ".bak." + stamp);
s = s.replace(A, A2).replace(B, B2);
fs.writeFileSync(file, s);
console.log("  直した（退避 " + require("path").basename(file) + ".bak." + stamp + "）");
NODE
RC=$?
bash -n "$ORCH" && echo "  bash -n: 通る" || echo "  **bash -n: 通らない**"
echo '```'
if [ "$RC" -ne 0 ]; then echo; echo "**直していない（rc=$RC）。止める。**"; exit 1; fi

echo
echo "直したあとの選ぶループ"
echo
echo '```js'
awk '/^PICKS_FILE=/{p=1} p{print} /^N_PICKED=/{exit}' "$ORCH" | hide
echo '```'

echo
echo "## ③ 直した選ぶループを、偽の候補で走らせる"
echo
# 選ぶループの JS を取り出し、$MAX_PICKS と $PICKS_FILE を入れて走らせる（can-comment は読むだけ）
JS="$W/.x259-pick.js"; PF="$W/.x259-picks.json"
awk '/^echo "\$CANDIDATES" \| \/usr\/local\/bin\/node -e "$/{p=1;next} p&&/^"$/{exit} p{print}' "$ORCH" \
  | sed -e "s#\$MAX_PICKS#4#g" -e "s#\$PICKS_FILE#$PF#g" > "$JS"
OTHER="$(node -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).queue||[];
const g=require(process.argv[2]); const seen=new Set(q.map(g.handleOf));
for (const h of ["zzz_x259_test_a","zzz_x259_test_b"]) if(!seen.has(h)){console.log(h);break;}' "$D/post_queue.json" "$GUARD")"
echo '[{"author":"money_yossy","tweet_url":"https://x.com/money_yossy/status/1"},{"author":"'"$OTHER"'","tweet_url":"https://x.com/'"$OTHER"'/status/2"}]' \
  | node "$JS" 2> "$W/.x259-err.txt"
echo '```'
echo "  選ばれた: $(node -e 'try{console.log(require(process.argv[1]).map(x=>x.author==="money_yossy"?x.author:"今日まだ返していない相手").join(", ")||"（無し）")}catch(e){console.log("読めない: "+e.message)}' "$PF")"
echo "  はじいた理由: $(cat "$W/.x259-err.txt" | head -3 | hide)"
echo '```'
rm -f "$JS" "$PF" "$W/.x259-err.txt"
echo
echo "**money_yossy が選ばれず、もう一方だけ選ばれていれば効いている**（money_yossy は今日すでに返しているため）。"

echo
echo "**LLM を呼んでいない。投稿していない（\$0／回・\$0／日・\$0／月）。返信の件数（16 件/日）は変えていない。**"
} > "$OUT" 2>&1
echo "同じ相手への返信を 1 日 1 回までにした / $(basename "$OUT")"
