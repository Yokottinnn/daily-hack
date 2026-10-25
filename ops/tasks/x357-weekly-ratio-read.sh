#!/bin/bash
# **毎週のフォロー比率チェック用に、いまのプロフィールのヘッダーと follow-balance の外せた件数を読む（x357）。読むだけ・LLM 不使用・$0。**
# x-numbers.json が 1 日以上前（2026-10-24 21:43Z）のため、いまの値を取る。押さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x357-weekly-ratio.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.x357-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 }); await p.waitForTimeout(6000);
  const t = await p.evaluate(() => [...document.querySelectorAll('a[href$="/following"], a[href$="/verified_followers"], a[href$="/followers"]')].map((a) => a.innerText.replace(/\s+/g, " ").trim()));
  r.links = t; await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r)); process.exit(0); })();
PJS
{
echo "# フォロー比率の週次チェック用（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## いまのプロフィールのヘッダー"; echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -1
echo '```'
echo; echo "## follow-balance・mutual-prune の外せた件数（直近 8 回）"; echo '```'
grep -hE '=== (外した|mutual-prune done)' "$W/logs/follow-balance.log" "$W/logs/mutual-prune.log" 2>/dev/null | awk '!seen[$0]++' | tail -8
echo '```'
echo; echo "## 関所が止めた回数（全ログ・種類別）"; echo '```'
grep -hoE 'x-action-guard\] [a-z]+: \*\*止めた' "$W"/logs/*.log 2>/dev/null | sed -E 's/.*\] ([a-z]+):.*/\1/' | sort | uniq -c
echo '```'
echo "**読んだだけ。押していない。LLM を呼んでいない（\$0／回）。**"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "x357 / $(basename "$OUT")"
