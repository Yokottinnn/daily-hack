#!/bin/bash
# x449（2026-11-10）: 自動化用 Chrome が X からログアウトしていた（x448: loggedIn=false・wait-textarea で 30 秒待って落ちた）。
# ensure-chrome.sh と同じ x-login.js で入り直し、ログインできたら高輪の告知を出す。
POST_APPROVAL_QUOTE="いますぐ投稿して頼むから"
POST_APPROVAL_AT="2026-11-10 00:2x JST（チャット）"
POST_SET_KEY="takanawa"
# **x_tweet_id があれば・プロフィールに高輪の投稿があれば絶対に出し直さない。** LLM を呼ばない（$0）。
set -uo pipefail
ID="x-news-20261109-takanawa"
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"
RUNNER_SH="$S/publish-takanawa-oneshot.sh"; LOG="$W/logs/publish-takanawa-oneshot.log"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$OUTDIR/x449-relogin-and-post-takanawa.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"; PJS="$S/.x449-prof-$STAMP.js"; RAW="$W/.x449-$STAMP.out"
hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(password["=: ]+)[^", ]+#\1<MASKED>#Ig'; }
clean() { hide | secrets; }
descendants() { local root="$1" p kids; kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"; for p in $kids; do echo "$p"; descendants "$p"; done; }
run_limited() { local limit="$1" outf="$2"; shift 2; "$@" > "$outf" 2>&1 & local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do kill -0 "$pid" 2>/dev/null || break; sleep 1; w=$((w + 1)); done
  if kill -0 "$pid" 2>/dev/null; then local victims p; victims="$(descendants "$pid") $pid"; for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done; sleep 3; for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done; wait "$pid" 2>/dev/null || true; return 124; fi
  wait "$pid"; return $?; }
cat > "$PJS" <<'JSEOF'
const { chromium } = require("playwright-core");
(async () => {
  let b; try { b = await chromium.connectOverCDP("http://127.0.0.1:18810", { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 200) })); process.exit(0); }
  const p = await b.contexts()[0].newPage(); const res = {};
  try {
    await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 45000 }); await p.waitForTimeout(7000);
    res.loggedIn = !!(await p.$('[data-testid="SideNav_NewTweet_Button"], [data-testid="AppTabBar_Profile_Link"]'));
    const rows = await p.evaluate(() => [...document.querySelectorAll("article")].slice(0, 8).map((a) => { const tm = a.querySelector("time"); const tx = a.querySelector('[data-testid="tweetText"]');
      return { href: tm && tm.closest("a") ? tm.closest("a").getAttribute("href") : null, text: tx ? tx.innerText.slice(0, 40) : null }; }));
    const hit = rows.find((r) => r.text && /高輪ゲートウェイに/.test(r.text)); res.hit = hit ? hit.href : null; res.n = rows.length;
  } catch (e) { res.error = String(e && e.message).slice(0, 200); }
  try { await p.close(); } catch (e) {} console.log(JSON.stringify(res)); process.exit(0);
})();
JSEOF
prof() { (cd "$S" && run_limited 90 "$RAW.p" node "$PJS"); tail -n 1 "$RAW.p" 2>/dev/null; rm -f "$RAW.p"; }
qid() { node -e 'const q=require(process.argv[1]);const r=(Array.isArray(q)?q:(q.queue||q.items||q.posts)).find(x=>x&&x.id===process.argv[2]);console.log(r&&r.x_tweet_id||"")' "$D/post_queue.json" "$ID" 2>/dev/null; }
{
echo "# 入り直して高輪の告知を出す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## 1. いまの状態"; echo '```'
P1="$(prof)"; echo "  プロフィール: $P1" | clean; T0="$(qid)"; echo "  キューの x_tweet_id: ${T0:-（空）}"
echo '```'
LOGGED="$(printf '%s' "$P1" | grep -c '"loggedIn":true' | head -1)"
if [ "${LOGGED:-0}" = "0" ]; then
  echo; echo "## 2. x-login.js で入り直す"; echo '```'
  (cd "$W" && run_limited 150 "$RAW.l" node "$S/x-login.js"); echo "  rc=$?"; tail -n 15 "$RAW.l" 2>/dev/null | cut -c1-240 | clean; rm -f "$RAW.l"
  P1="$(prof)"; echo "  入り直したあと: $P1" | clean
  echo '```'
fi
echo; echo "## 3. 出す"; echo '```'
T0="$(qid)"
if [ -n "$T0" ]; then echo "  もう出ている: https://x.com/heng_ji31590/status/$T0（出し直さない）"
elif printf '%s' "$P1" | grep -q '"hit":"/'; then echo "  プロフィールにもう出ている（キューに未記入）。出し直さない: $P1"
elif ! printf '%s' "$P1" | grep -q '"loggedIn":true'; then echo "  **ログインできていない。出さない。**"
elif pgrep -f "run-publish.sh $ID" >/dev/null 2>&1; then echo "  別の処理が出している最中。重ねない"
else echo "  ログイン済み・未投稿 → 出す"; /bin/bash "$RUNNER_SH" >/dev/null 2>&1; echo "  runner rc=$?"
  grep -v '^\[run-publish\]' "$LOG" | tail -n 3 | cut -c1-600 | clean
fi
echo '```'
echo; echo "## 4. 結果"; echo '```'; T1="$(qid)"; echo "  x_tweet_id: ${T1:-（空）}"; [ -n "$T1" ] && echo "  https://x.com/heng_ji31590/status/$T1"; echo '```'
} > "$OUT" 2>&1
rm -f "$PJS" "$RAW"*
grep -E 'https://x.com|ログインできていない|もう出ている' "$OUT" | head -2 | cut -c1-200
exit 0
