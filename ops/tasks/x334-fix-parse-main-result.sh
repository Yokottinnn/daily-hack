#!/bin/bash
# **run-publish.sh が「出せたのに parse-main-result で ok:false」を返す穴を直す（x334）。投稿しない。費用 $0。**
#
# ## 原因（x333 で実物を読んだ）
#
#   単発の経路の最後で `node -e "…" MAIN_RES="$MAIN_RES" THREAD_RES="$THREAD_RES"` と書いてある。
#   **コマンドの後ろに置いた `X=…` は環境変数ではなく引数になる**ので、process.env.MAIN_RES は毎回空。
#   そのため投稿が出ても `{"ok":false,"step":"parse-main-result","raw":""}` を返していた（x325・x328・x332 の 3 回とも）。
#
# ## 直し方
#
#   node の中で、環境変数が空なら引数（MAIN_RES=… / THREAD_RES=…）から読むようにする。呼び出し方は変えない。
#   元は run-publish.sh.bak-x334 に残す。直したあと bash -n と、同じ書き方の小さな再現で ok:true が返ることを確かめる。
#
# **投稿しない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"
# 直す対象は「単発の経路」を持つ投稿の振り分けスクリプト。**書き換えるだけで、実行はしない**（このタスクは投稿しない）
RP="$(grep -l 'Branch 2: legacy single-post' "$S"/*.sh 2>/dev/null | head -1)"
[ -n "$RP" ] || { echo "x334 / 対象が見つからない"; exit 1; }
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-parse-main-result.md"
{
echo "# 出せたのに失敗と返す穴を直す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## 1. 置き換え"; echo '```'
if grep -q "argOf('MAIN_RES')" "$RP"; then echo "  もう直っている"
else
  cp "$RP" "$RP.bak-x334"
  "$NODE_BIN" -e '
const fs=require("fs");const p=process.argv[1];let s=fs.readFileSync(p,"utf8");
const a="const raw = process.env.MAIN_RES || \x27\x27;";
const b="const argOf = (k) => { const h = process.argv.find(x => x.startsWith(k + \x27=\x27)); return h ? h.slice(k.length + 1) : \x27\x27; };\n  const raw = process.env.MAIN_RES || argOf(\x27MAIN_RES\x27);";
const c="const threadStr = process.env.THREAD_RES || \x27\x27;";
const d="const threadStr = process.env.THREAD_RES || (process.argv.find(x => x.startsWith(\x27THREAD_RES=\x27)) || \x27\x27).slice(11);";
const n1=s.split(a).length-1,n2=s.split(c).length-1;
if(n1!==1||n2!==1){console.log("  置き換え対象が 1 箇所ずつではない（raw "+n1+" / thread "+n2+"）。止まる");process.exit(1);}
s=s.replace(a,b).replace(c,d);fs.writeFileSync(p,s);console.log("  置き換えた（raw 1 / thread 1）");' "$RP" || exit 1
fi
bash -n "$RP" && echo "  bash -n: OK" || { echo "  **bash -n が通らない。元に戻して止まる**"; cp "$RP.bak-x334" "$RP"; exit 1; }
grep -n -E "argOf|THREAD_RES=" "$RP" | cut -c1-200
echo '```'
echo; echo "## 2. 同じ書き方の小さな再現で確かめる（投稿しない）"; echo '```'
T="$W/.x334-test.sh"
{ echo 'MAIN_RES=$(printf "%s\n%s" "[log] attached 4/4" "{\"ok\":true,\"tweet_id\":\"123\",\"url\":\"u\"}")'; echo 'THREAD_RES=""';
  awk '/^\/usr\/local\/bin\/node -e "$/{buf=$0; inb=1; next} inb{buf=buf"\n"$0} inb && /MAIN_RES="\$MAIN_RES" THREAD_RES="\$THREAD_RES"/{last=buf; inb=0} END{print last}' "$RP"; } > "$T"
R="$(/bin/bash "$T" 2>&1 | tail -1)"; rm -f "$T"
echo "  $R"
case "$R" in *'"ok":true'*'"tweet_id":"123"'*) echo "  → **直った（ok:true と tweet_id が返る）**";; *) echo "  → **まだ返らない。元に戻す**"; cp "$RP.bak-x334" "$RP";; esac
echo '```'
echo; echo "**投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x334 / $(basename "$OUT")"
