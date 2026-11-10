#!/bin/bash
# x467（2026-11-11）: 取りこぼした返信 1 件に返す。相手の返信 2117613776182853984（11/3 22:44 JST・楽天の株主優待はポイントアップ対象外）。
POST_APPROVAL_QUOTE="いや、リプライは確認しなくていいからすぐに出して"
POST_APPROVAL_AT="2026-11-11 00:5x JST（チャット）"
POST_SET_KEY="reply-rakuten-yutai"
# 元の投稿は 11/1 で、7 日に広げた見張り（x466）の範囲にも入らないので、ここで 1 回だけ返す。
# **もう返していれば返さない**（スレッドに自分の返信があるか先に見る）。LLM 不使用（$0）。他人のハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; TARGET="https://x.com/i/status/2117613776182853984"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x467-reply-to-2117613776.md"
TXT="そこ見落としやすいのよね。モバイルが無料でもポイントアップ対象外なら、ポイント目当てで株主になる理由にはならないわね。いい指摘ありがと😏"
PJS="$S/.x467-look.js"
cat > "$PJS" <<'JSEOF'
const { chromium } = require("playwright-core");
(async () => { const b = await chromium.connectOverCDP("http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage(); const res = {};
  try { await p.goto(process.argv[2], { waitUntil: "domcontentloaded", timeout: 45000 }); await p.waitForTimeout(7000);
    res.loggedIn = !!(await p.$('[data-testid="SideNav_NewTweet_Button"], [data-testid="AppTabBar_Profile_Link"]'));
    res.mine = await p.evaluate(() => [...document.querySelectorAll("article")].slice(1, 15).some((a) => { const l = [...a.querySelectorAll('a[href*="/status/"]')].map(x => x.getAttribute("href")); return l.some(h => /^\/heng_ji31590\/status\/\d+$/.test(h)); }));
  } catch (e) { res.error = String(e && e.message).slice(0, 160); }
  try { await p.close(); } catch (e) {} console.log(JSON.stringify(res)); process.exit(0); })();
JSEOF
{
echo "# 取りこぼした返信に返す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'
"$NODE_BIN" -e 'const {checkTone}=require(process.argv[1]);const R=require(process.argv[2]);console.log("  tone: "+JSON.stringify(checkTone(process.argv[3],R)))' "$S/reply-tone-check.cjs" "$W/data/reply-tone-rules.json" "$TXT" 2>&1 | head -1
L1="$(cd "$S" && "$NODE_BIN" "$PJS" "$TARGET" | tail -1)"; echo "  前: $L1"
if printf '%s' "$L1" | grep -q '"mine":true'; then echo "  もう返している。返さない"
elif ! printf '%s' "$L1" | grep -q '"loggedIn":true'; then echo "  **ログインできていない。返さない**"
else
  B64="$(printf '%s' "$TXT" | base64 | tr -d '\n')"
  (cd "$W" && "$NODE_BIN" scripts/post-comment.js "$B64" "$TARGET" 2>&1) | grep -v '^\[step\]' | tail -4 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
fi
echo '```'
} > "$OUT" 2>&1
rm -f "$PJS"
grep -oE '"reply_tweet_id":"[0-9]+"|もう返している|返さない' "$OUT" | head -1
exit 0
