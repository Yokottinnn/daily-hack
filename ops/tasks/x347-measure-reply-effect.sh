#!/bin/bash
# **返信の効果を測る（x347）。読むだけ。費用 $0。**
# 利用者が「返信の効果を測る」「返信の ID を記録する」を選んだ（2026-10-26）。x346 で、返信の ID は comment-warmup.log に既に残っていると分かった。
# 直近の返信 20 件の分析画面（/status/ID/analytics）を開き、表示・エンゲージメント・プロフィールへのアクセス・フォローを読む。
# **返信しない・押さない。他人のハンドルは伏せる。LLM を呼ばない（$0／回・$0／日・$0／月）。** 1 件 約 10 秒・合計 4 分以内。
set -uo pipefail
W="$HOME/.openclaw/workspace"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-effect.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x\.com/)(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1<伏せ>#g'; }
LIST="$W/.x347-ids.txt"
grep -hE '^\{"ok":true,"entry_id":"comment-' "$W/logs/comment-warmup.log" 2>/dev/null | tail -20 \
  | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=s.split("\n").filter(Boolean).map(l=>{try{const j=JSON.parse(l);return j.entry_id+" "+j.x_tweet_id}catch{return ""}}).filter(Boolean);process.stdout.write(o.join("\n")+"\n")})' > "$LIST"
PROBE="$W/.x347-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core"); const fs = require("fs");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const rows = fs.readFileSync(process.argv[2], "utf8").split("\n").filter(Boolean).map((l) => l.split(" "));
const LABELS = ["インプレッション数", "エンゲージメント", "詳細のクリック数", "プロフィールへのアクセス数", "フォロー", "新しいフォロワー", "いいね", "返信", "リポスト"];
const T0 = Date.now();
(async () => { const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  for (const [entry, id] of rows) { if (Date.now() - T0 > 210000) { console.log(JSON.stringify({ entry, id, skipped: "時間切れ" })); continue; }
    const r = { entry, id };
    try { await page.goto(`https://x.com/heng_ji31590/status/${id}/analytics`, { waitUntil: "domcontentloaded", timeout: 30000 }); await page.waitForTimeout(6500);
      const lines = await page.evaluate(() => (document.querySelector('[role="dialog"]') || document.querySelector("main") || document.body).innerText.split("\n").map((s) => s.trim()).filter(Boolean));
      for (const L of LABELS) { const i = lines.indexOf(L); if (i >= 0) { const nx = lines[i + 1] || ""; if (/^[\d,.]+[万千]?$/.test(nx)) r[L] = nx; } }
      if (!r["インプレッション数"]) r.raw = lines.filter((s) => s.length < 30).slice(0, 30);
    } catch (e) { r.error = String(e && e.message).slice(0, 120); }
    console.log(JSON.stringify(r)); }
  await page.close().catch(() => {}); process.exit(0); })().catch((e) => { console.log(JSON.stringify({ fatal: String(e.message).slice(0, 200) })); process.exit(0); });
PJS
{
echo "# 返信の効果（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "対象: comment-warmup.log の直近の返信 $(grep -c . "$LIST" | head -1) 件"
echo; echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" "$LIST" 2>&1 | grep '^{' | hide
echo '```'
echo "**読んだだけ。返信・クリックはしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$PROBE" "$LIST"
echo "x347 / $(basename "$OUT")"
