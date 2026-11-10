#!/bin/bash
# x459（2026-11-10・$0）: 11/12（木）12:00 のららぽーとの予約（x446）の前後に、1 回だけ動く見張りを 2 つ置く。
# 利用者がダイアログで「11/12 の予約の前後を見張る」を選んだ。11/9 の高輪は、12:00 に Chrome が起きず失敗し、そのあと X からログアウトしていた（x447〜x449）。
#  ① 11/12 11:30 … Chrome（CDP 18810）と X のログインを確かめる。CDP が死んでいれば ensure-chrome.sh、ログアウトなら x-login.js で入り直す（投稿はしない）
#  ② 11/12 12:20 … キューに x_tweet_id が無く、プロフィールの直近 8 本にも無ければ、①と同じ確認のあと x446 の投稿スクリプトをもう一度走らせる
POST_APPROVAL_QUOTE="あと最終確認は不要だからそのまま木曜日のイベント開始前日に必ず投稿して"
POST_APPROVAL_AT="2026-11-09 11:5x JST（チャット）"
POST_SET_KEY="news-lalaport-bf"
# **x_tweet_id があれば・プロフィールに出ていれば絶対に出し直さない。** LLM を呼ばない（$0／回・$0／日・$0／月）。常駐させない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"; U="$(id -u)"
ID="x-news-20261112-lalaport-bf"; RUNNER="$S/publish-lalaport-bf-oneshot.sh"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x459-guard-lalaport-1112.md"; LOG="$W/logs/lalaport-guard-1112.log"
G="$S/lalaport-guard-1112.sh"; PJS="$S/.lalaport-guard-prof.js"
cat > "$PJS" <<'JSEOF'
const { chromium } = require("playwright-core");
(async () => { let b; try { b = await chromium.connectOverCDP("http://127.0.0.1:18810", { timeout: 60000 }); } catch (e) { console.log(JSON.stringify({ fatal: "cdp" })); process.exit(0); }
  const p = await b.contexts()[0].newPage(); const res = {};
  try { await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 45000 }); await p.waitForTimeout(7000);
    res.loggedIn = !!(await p.$('[data-testid="SideNav_NewTweet_Button"], [data-testid="AppTabBar_Profile_Link"]'));
    const rows = await p.evaluate(() => [...document.querySelectorAll("article")].slice(0, 8).map((a) => { const tm = a.querySelector("time"); const tx = a.querySelector('[data-testid="tweetText"]'); return { href: tm && tm.closest("a") ? tm.closest("a").getAttribute("href") : null, text: tx ? tx.innerText.slice(0, 60) : "" }; }));
    const hit = rows.find((r) => r.href && r.href.startsWith("/heng_ji31590/") && /ららぽーと豊洲/.test(r.text) && /ブラックフライデー/.test(r.text)); res.hit = hit ? hit.href : null; res.n = rows.length;
  } catch (e) { res.error = String(e && e.message).slice(0, 160); }
  try { await p.close(); } catch (e) {} console.log(JSON.stringify(res)); process.exit(0); })();
JSEOF
cat > "$G" <<GEOF
#!/bin/bash
# 11/12 の見張り（x459）。引数 pre = 11:30 の確認 ／ post = 12:20 の出し直し
set -uo pipefail
MODE="\${1:-pre}"; cd "$S" || exit 1
log() { echo "[\$(date '+%F %T')] \$*" >> "$LOG"; }
prof() { "$NODE_BIN" "$PJS" 2>/dev/null | tail -n 1; }
heal() {
  if ! "$NODE_BIN" "$S/cdp-health.js" >/dev/null 2>&1; then log "CDP NG → ensure-chrome.sh"; /bin/bash "$S/ensure-chrome.sh" >> "$LOG" 2>&1; sleep 5; fi
  P="\$(prof)"; log "プロフィール: \$P"
  if ! printf '%s' "\$P" | grep -q '"loggedIn":true'; then log "ログアウト → x-login.js"; (cd "$W" && "$NODE_BIN" "$S/x-login.js" >> "$LOG" 2>&1); P="\$(prof)"; log "入り直したあと: \$P"; fi
}
qid() { "$NODE_BIN" -e 'const q=require(process.argv[1]);const r=(Array.isArray(q)?q:(q.queue||q.items||q.posts)).find(x=>x&&x.id===process.argv[2]);console.log(r&&r.x_tweet_id||"")' "$D/post_queue.json" "$ID" 2>/dev/null; }
log "start \$MODE"
heal
if [ "\$MODE" = "post" ]; then
  T="\$(qid)"
  if [ -n "\$T" ]; then log "もう出ている: \$T（出し直さない）"
  elif printf '%s' "\$P" | grep -q '"hit":"/'; then log "プロフィールに出ている（キュー未記入）。出し直さない: \$P"
  elif ! printf '%s' "\$P" | grep -q '"loggedIn":true'; then log "**ログインできていない。出さない**"
  elif pgrep -f "run-publish.sh $ID" >/dev/null 2>&1; then log "別の処理が出している最中。重ねない"
  elif [ -f "$RUNNER" ]; then log "未投稿 → 出し直す"; /bin/bash "$RUNNER" >/dev/null 2>&1; log "runner rc=\$? x_tweet_id=\$(qid)"
  else log "投稿スクリプトが無い: $RUNNER"; fi
fi
log "done \$MODE"
launchctl bootout "gui/$U/com.dailyhack.lalaport-guard-1112-\$MODE" 2>/dev/null
rm -f "$LA/com.dailyhack.lalaport-guard-1112-\$MODE.plist"
GEOF
chmod +x "$G"
mk() { local mode="$1" hh="$2" mi="$3" lb="com.dailyhack.lalaport-guard-1112-$1"
cat > "$LA/$lb.plist" <<PLEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$lb</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$G</string><string>$mode</string></array>
  <key>StartCalendarInterval</key><dict><key>Month</key><integer>11</integer><key>Day</key><integer>12</integer><key>Hour</key><integer>$hh</integer><key>Minute</key><integer>$mi</integer></dict>
  <key>StandardOutPath</key><string>$W/logs/lalaport-guard-1112-out.log</string>
  <key>StandardErrorPath</key><string>$W/logs/lalaport-guard-1112-err.log</string>
</dict></plist>
PLEOF
launchctl bootout "gui/$U/$lb" 2>/dev/null; launchctl bootstrap "gui/$U" "$LA/$lb.plist" 2>&1 | head -1
if launchctl print "gui/$U/$lb" >/dev/null 2>&1; then echo "  $lb（11/12 $hh:$(printf %02d $mi)）→ 載っている"; else echo "  $lb → **載っていない**"; fi; }
{
echo "# 11/12 のららぽーとの予約の見張り（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'
for f in "$S/cdp-health.js" "$S/ensure-chrome.sh" "$S/x-login.js" "$RUNNER"; do [ -f "$f" ] && echo "  在る: $(basename "$f")" || echo "  **無い: $f**"; done
"$NODE_BIN" --check "$PJS" && bash -n "$G" && echo "  構文 OK"
mk pre 11 30
mk post 12 20
echo '```'
echo "取り消すとき: launchctl bootout gui/$U/com.dailyhack.lalaport-guard-1112-pre; launchctl bootout gui/$U/com.dailyhack.lalaport-guard-1112-post"
} > "$OUT" 2>&1
grep -E '→' "$OUT" | head -2
exit 0
