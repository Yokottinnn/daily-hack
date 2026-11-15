#!/bin/bash
# x502（2026-11-15・$0）: フォローを人の見方に寄せる。利用者がダイアログで「フォロー前にプロフィールを眺める」「ときどき相手の投稿にいいねしてからフォロー」を選んだ。
#  ① follow-handle.js: 押す直前に 2.5〜7 秒 止まる → 1〜4 回スクロール（1 回 0.9〜2.6 秒）→ 4 回に 1 回、固定でない最新の投稿にいいね（間隔の決まりの like を通す。空かなければいいねしない）→ 上に戻ってから押す
#     眺める段で失敗してもフォローは続ける
#  ② 呼び出し側（competitor-follower-follow・hashtag-follow・incoming-reply-watcher）の follow-handle の打ち切りを 240 秒に
#     （follow-handle は空きを最大 150 秒待つのに、30〜60 秒で打ち切っていた）
# LLM を呼ばない。置く前に node --check。通らなければ元に戻す。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; STAMP="$(date +%Y%m%d-%H%M%S)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x502-follow-dwell-and-like.md"
{
echo "# フォロー前に眺める・ときどきいいね（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① follow-handle.js"; echo '```'
F="$S/follow-handle.js"
if grep -q 'x502' "$F"; then echo "もう入っている"; else
cp -p "$F" "$F.bak-x502"
"$NODE_BIN" - "$F" <<'JS'
const fs = require("fs"); const f = process.argv[2]; let s = fs.readFileSync(f, "utf8");
const anchor = `    const btn = await page.waitForSelector('[data-testid$="-follow"]', { state: "visible", timeout: 8000 });`;
const n = s.split(anchor).length - 1;
if (n !== 1) { console.log("目印の行が " + n + " か所。直さない"); process.exit(1); }
const add = `    /* x502（2026-11-15）: 人の見方に寄せる。押す直前に眺める・スクロール・4 回に 1 回いいね。失敗してもフォローは続ける */
    try {
      const _rnd = (a, b) => a + Math.floor(Math.random() * (b - a));
      await page.waitForTimeout(_rnd(2500, 7000));
      const _n = _rnd(1, 5);
      for (let i = 0; i < _n; i++) { await page.mouse.wheel(0, _rnd(250, 700)); await page.waitForTimeout(_rnd(900, 2600)); }
      if (Math.random() < 0.25) {
        const _pl = require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").take("like");
        if (_pl.ok) {
          const _lk = page.locator('article:not(:has([data-testid="socialContext"]))').first().locator('[data-testid="like"]');
          if (await _lk.count()) { await _lk.first().scrollIntoViewIfNeeded(); await page.waitForTimeout(_rnd(700, 1800)); await _lk.first().click({ timeout: 5000 }); console.error("[x502] いいねしてからフォロー"); await page.waitForTimeout(_rnd(1200, 3000)); }
        } else console.error("[x502] いいねは間隔待ちで見送り: " + _pl.reason);
      }
      await page.mouse.wheel(0, -6000); await page.waitForTimeout(_rnd(800, 2000));
    } catch (e) { console.error("[x502] 眺める段で失敗（フォローは続ける）: " + e.message); }
`;
s = s.replace(anchor, add + anchor); fs.writeFileSync(f, s); console.log("入れた");
JS
if "$NODE_BIN" --check "$F" 2>/dev/null; then echo "node --check 通った（$(wc -l < "$F" | tr -d ' ') 行）"; grep -n 'x502' "$F" | head -3 | cut -c1-120
else cp -p "$F.bak-x502" "$F"; echo "**node --check が通らない。元に戻した**"; fi
fi
echo '```'
echo; echo "## ② 呼び出し側の打ち切りを 240 秒に"; echo '```'
for n in competitor-follower-follow hashtag-follow incoming-reply-watcher; do
  F="$S/$n.js"; [ -f "$F" ] || { echo "$n: 無い"; continue; }
  cp -p "$F" "$F.bak-x502"
  "$NODE_BIN" - "$F" <<'JS'
const fs = require("fs"); const f = process.argv[2];
let c = 0; const out = fs.readFileSync(f, "utf8").split("\n").map((l) => {
  if (/FOLLOW_HANDLE|follow-handle\.js/.test(l) && /execSync/.test(l) && /timeout:\s*\d+/.test(l)) { c++; return l.replace(/timeout:\s*\d+/, "timeout: 240000"); }
  return l; });
fs.writeFileSync(f, out.join("\n")); console.log(require("path").basename(f) + ": " + c + " か所");
JS
  if "$NODE_BIN" --check "$F" 2>/dev/null; then grep -n 'timeout: 240000' "$F" | head -2 | cut -c1-140; else cp -p "$F.bak-x502" "$F"; echo "**$n: node --check が通らない。元に戻した**"; fi
done
echo '```'
echo; echo "**LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '入れた|通った|か所|元に戻した|もう入って' "$OUT" | head -6 | cut -c1-140
exit 0
