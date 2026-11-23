#!/bin/bash
# x548（2026-11-23・読むだけ・$0）: follow-balance が外せない 2 つの原因を直す前に、コードを読む。
# ① 11/22 20:15 の回が、ほかのジョブが開いた shared_worker に Playwright が当たって落ちた（crBrowser _onAttachedToTarget の assert）
# ② 06:44 の回が、候補 16 件のうち 14 件を「フォローしていない（一覧の取り込み間違い）」として外せなかった
# **何も書き換えない・押さない。** 他人のハンドルと秘密は伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/x548-read-follow-balance-code.md"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x|twitter)\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1.com/<伏せ>#g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g'; }
F="$S/follow-balance.js"
{
echo "# follow-balance のコードを読む（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo '```'; ls -la "$F" 2>&1 | sed "s#$HOME#~#"; wc -l "$F" 2>&1 | sed "s#$HOME#~#"; echo '```'
echo; echo "## 接続のところ（connectOverCDP・newPage・contexts）"; echo '```'
grep -n -E 'connectOverCDP|chromium\.|newPage|contexts\(\)|newContext|process\.on|unhandled|uncaught|close\(\)' "$F" 2>&1 | cut -c1-200 | clean
echo '```'
echo; echo "## 「フォローしていない」「取り込み間違い」の判定"; echo '```'
for pat in 'フォローしていない' '取り込み間違い' '覚えた' 'notFollowing' 'mistake'; do
  grep -n "$pat" "$F" 2>/dev/null | cut -c1-200 | clean
done
echo '```'
echo; echo "## 判定の前後 60 行"; echo '```'
n="$(grep -n '取り込み間違い' "$F" 2>/dev/null | head -1 | cut -d: -f1)"
if [ -n "${n:-}" ]; then s=$(( n > 60 ? n - 60 : 1 )); sed -n "${s},$(( n + 25 ))p" "$F" | cut -c1-220 | clean; fi
echo '```'
echo; echo "## 一覧（following）を読むところ"; echo '```'
for pat in '/following' 'UserCell' 'userCell' 'collectFollowing' 'scroll'; do grep -n "$pat" "$F" 2>/dev/null | head -8 | cut -c1-200 | clean; done
echo '```'
echo; echo "## 覚えた未フォローの記録ファイル"; echo '```'
grep -n -o -E "[A-Za-z0-9_./-]*\.json" "$F" 2>/dev/null | sort -u | head -20
echo '```'
echo; echo "## ログ: 11/22〜23 の『外した』行と落ちた行"; echo '```'
grep -E '^\[2026-11-2[23].*(外した:|start|Error|error)' "$L/follow-balance.log" 2>/dev/null | awk '!seen[$0]++' | tail -20 | cut -c1-200 | clean
tail -n 30 "$L/follow-balance-err.log" "$L/follow-balance.stderr.log" 2>/dev/null | awk '!seen[$0]++' | tail -30 | cut -c1-200 | clean
echo '```'
echo; echo "## ほかに shared_worker を開きうるタブ（いま開いているページの URL のホスト）"; echo '```'
PORT="$(grep -o -E 'CDP_PORT[^0-9]*[0-9]{4,5}' "$F" 2>/dev/null | grep -o -E '[0-9]{4,5}' | head -1)"; PORT="${PORT:-18810}"
curl -s "http://127.0.0.1:$PORT/json/list" 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const a=JSON.parse(s);const c={};for(const t of a){const h=(t.url||"").split("/").slice(0,3).join("/");const k=t.type+" "+h;c[k]=(c[k]||0)+1}for(const[k,v]of Object.entries(c))console.log(v,k)}catch(e){console.log("読めない",e.message)}})'
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
