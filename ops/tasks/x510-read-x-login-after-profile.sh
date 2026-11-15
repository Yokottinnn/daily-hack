#!/bin/bash
# x510（2026-11-16・読むだけ・$0）: Mac の Chrome（CDP 18810）が会社の Google アカウントのプロファイルだけになった（2026-11-15 20:30 ごろ・affiliate から連絡）。
# ① そのプロファイルで X にログインできているか ② 11/15 20:30 以降も X の自動処理（投稿・返信・フォロー・解除）が動いているか ③ tab-guard・ensure-chrome が止めていないか ④ follow-balance が外せているか を読む。
# 本文は保存しない（ログイン状態は「自分のアカウントのボタンがあるか」だけを見る）。何も押さない。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/x510-read-x-login-after-profile.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
echo "# 会社のプロファイルで X が動いているか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）" > "$OUT"
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then echo "playwright-core が無い。止める" >> "$OUT"; cat "$OUT"; exit 0; fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then echo "Chrome が CDP（$PORT）で応答しない。止める" >> "$OUT"; cat "$OUT"; exit 0; fi
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
SCRIPT="$RDIR/.x510-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
console.log(`## ① ログイン\n- Chrome の文脈 ${b.contexts().length} 個・開いているタブ ${ctx.pages().length} 枚`);
const p = await ctx.newPage();
try {
  await p.goto('https://x.com/home', { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(6000);
  const r = await p.evaluate(() => ({
    me: !!document.querySelector('[data-testid="SideNav_AccountSwitcher_Button"]'),
    mine: (document.querySelector('[data-testid="SideNav_AccountSwitcher_Button"]')?.innerText || '').includes('heng_ji31590'),
    compose: !!document.querySelector('[data-testid="SideNav_NewTweet_Button"]'),
    loginBtn: !!document.querySelector('[data-testid="loginButton"],a[href="/login"]'),
  }));
  console.log(`- 開いた先: ${p.url().replace(/\?.*/, '')}`);
  console.log(`- 自分のアカウントのボタン: ${r.me ? 'ある' : 'ない'}（@heng_ji31590 ${r.mine ? 'と一致' : 'と一致しない'}）・投稿ボタン: ${r.compose ? 'ある' : 'ない'}・ログインのボタン: ${r.loginBtn ? 'ある（ログアウト状態）' : 'ない'}`);
  console.log(`- 判定: ${r.mine && r.compose ? '**ログインできている**' : '**ログインできていない**'}`);
} catch (e) { console.log(`- 開けない: ${String(e).slice(0, 120)}`); } finally { await p.close(); }
await b.close().catch(() => {});
JS
RES="$RDIR/.x510-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 90 node "$SCRIPT" > "$RES" 2>&1
echo "終了コード $?" >> "$OUT"; echo >> "$OUT"
cat "$RES" >> "$OUT" 2>/dev/null
rm -f "$SCRIPT" "$RES"
W="$HOME/.openclaw/workspace"; L="$W/logs"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo; echo "## ② 11/15 20:30 JST 以降に押した回数（間隔の決まりの台帳）"; echo '```'
"$NODE_BIN" -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const t0=Date.parse("2026-11-15T11:30:00Z");
for(const k of ["tweet","like","follow","unfollow"]){const xs=(j[k]||[]).filter(t=>t>=t0).sort((a,b)=>a-b);const last=xs.length?new Date(xs[xs.length-1]+9*3600e3).toISOString().slice(5,16).replace("T"," "):"なし";console.log(k+": "+xs.length+" 回（最後 "+last+" JST）")}' "$W/data/x-action-ledger.json" 2>&1
echo '```'
echo; echo "## ② キュー: 11/15 20:30 以降に出た（x_tweet_id が付いた）もの"; echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);const t0=Date.parse("2026-11-15T11:30:00Z");
const by={};let n=0,last="";for(const e of rows){if(!e||!(e.x_tweet_id||e.tweet_id))continue;const t=Date.parse(e.posted_at||e.updated_at||e.created_at||"");if(!(t>=t0))continue;n++;by[e.kind||"?"]=(by[e.kind||"?"]||0)+1;const s=new Date(t+9*3600e3).toISOString().slice(5,16).replace("T"," ");if(s>last)last=s}
console.log("出た "+n+" 件 "+JSON.stringify(by)+"（最後 "+(last||"なし")+" JST）");
const f=rows.filter(e=>e&&!(e.x_tweet_id||e.tweet_id)&&Date.parse(e.updated_at||e.created_at||"")>=t0&&/fail|error/i.test(JSON.stringify(e.last_result||e.status||""))).length;console.log("失敗の印がある未投稿 "+f+" 件")' "$W/data/post_queue.json" 2>&1
echo '```'
echo; echo "## ③ tab-guard・ensure-chrome のログ（直近 8 行・11/15 20 時以降）"; echo '```'
for f in "$L"/tab-guard*.log "$L"/ensure-chrome*.log; do [ -f "$f" ] || continue; echo "--- $(basename "$f")"; grep -aE '2026-11-1[56]' "$f" | grep -aE '11-15[ T](2[0-3])|11-16' | tail -8 | cut -c1-200 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; done
echo '```'
echo; echo "## ④ follow-balance の直近の結果"; echo '```'
grep -aE '外した|外せ|quota|比率|ratio|following|空かない' "$L/follow-balance.log" 2>/dev/null | tail -10 | cut -c1-200 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
echo; echo "何も押していない。LLM 不使用・\$0。"
} >> "$OUT" 2>&1
grep -E '判定|回（最後|出た ' "$OUT" | head -6 | cut -c1-120
exit 0
