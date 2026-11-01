#!/bin/bash
# x398（2026-11-01・$0）: 利用者「この投稿内容に書かれている投稿を伸ばす方法を完全にコピーしてオペレーションに組み込んで」
# 元の投稿（@Jdj5VLZbsB21682・2026-11-01 16:56）の方法:
#   アナリティクスで「時間ごとの伸び方」を見る。投稿直後が最大で減っていくのは伸びない。
#   時間とともに右肩上がりの投稿は大きく伸びる可能性がある → 自分で追い風を吹かす:
#     1 引用重ね  2 自分の別の投稿のリプ欄に、伸びている投稿を貼る（利用者がダイアログで選んだ意味）  3 固定ポストへの移動
#
# このタスクで入れるもの（**投稿はしない**）:
#   scripts/boost-watch.js ＋ ai.openclaw.boost-watch（10 分ごと）
#   - 自分の投稿（キューで posted・x_tweet_id あり・出てから 3 時間以内）の表示回数を読み、data/boost-watch.json に時系列で残す
#   - 右肩上がり（直近の 1 分あたりの伸びが、1 つ前の区間の 1.3 倍以上・最初の区間以上・毎分 BOOST_MIN_RATE 以上）なら
#     ③ 固定ポストに移す（投稿ではない）。①② は「出す予定」をログに残すだけ（投稿の部分は利用者の「投稿して」を引用した別タスクで入れる）
# LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。投稿がない時間は Chrome を開かない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; D="$W/data"; LA="$HOME/Library/LaunchAgents"
LABEL="ai.openclaw.boost-watch"; UID_N="$(id -u)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x398-install-boost-watch.md"
F="$S/boost-watch.js"; TMPJS="$S/.boost-watch-x398.js"
{
echo "# 伸び始めた投稿に追い風を吹かす仕組み（計測と固定）を入れる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
cat > "$TMPJS" <<'JSEOF'
// boost-watch.js（x398・2026-11-01）: 自分の投稿の伸び方を 10 分ごとに読み、右肩上がりなら追い風を吹かす。$0（LLM 不使用）。
const fs = require("fs"), path = require("path");
const W = path.join(process.env.HOME, ".openclaw/workspace");
const Q = path.join(W, "data/post_queue.json"), ST = path.join(W, "data/boost-watch.json"), LOG = path.join(W, "logs/boost-watch.log");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const WINDOW_MIN = Number(process.env.BOOST_WINDOW_MIN || 180);   // 出てから何分まで見るか
const MIN_RATE = Number(process.env.BOOST_MIN_RATE || 5);          // 毎分これ以上伸びていること
const RISE = Number(process.env.BOOST_RISE || 1.3);                // 直近 / 1 つ前 の比
const SELF = process.env.SELF_HANDLE || "heng_ji31590";
const log = (s) => { const l = "[" + new Date().toISOString() + "] " + s; fs.appendFileSync(LOG, l + "\n"); console.log(l); };
const readJ = (f, d) => { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch (e) { return d; } };
const fromId = (id) => Number((BigInt(id) >> 22n) + 1288834974657n);

(async () => {
  const q = readJ(Q, []); const rows = Array.isArray(q) ? q : (q.queue || q.items || q.posts || []);
  const now = Date.now();
  const watch = rows.filter((e) => e && e.status === "posted" && e.x_tweet_id && /^\d+$/.test(String(e.x_tweet_id)))
    .filter((e) => now - fromId(String(e.x_tweet_id)) < WINDOW_MIN * 60000);
  if (!watch.length) return; // 見る投稿がない時間は Chrome を開かない
  const st = readJ(ST, { tweets: {} });
  const { chromium } = require("playwright-core");
  let b; try { b = await chromium.connectOverCDP(CDP, { timeout: 30000 }); } catch (e) { log("CDP に繋がらない: " + String(e.message).slice(0, 100)); return; }
  const ctx = b.contexts()[0]; if (!ctx) { log("context が無い"); return; }
  for (const e of watch) {
    const id = String(e.x_tweet_id); const t = st.tweets[id] = st.tweets[id] || { entry: e.id, posted_ms: fromId(id), samples: [] };
    const p = await ctx.newPage();
    try {
      await p.goto("https://x.com/" + SELF + "/status/" + id, { waitUntil: "domcontentloaded", timeout: 40000 });
      await p.waitForSelector('article [role="group"][aria-label]', { timeout: 15000 }).catch(() => {});
      const label = await p.evaluate((id) => { const a = [...document.querySelectorAll("article")].find((x) => x.querySelector('a[href*="/status/' + id + '"]')) || document.querySelector("article");
        const g = a && a.querySelector('[role="group"][aria-label]'); return g ? g.getAttribute("aria-label") : ""; }, id);
      const m = String(label).match(/([\d,]+)\s*件の表示/) || String(label).match(/([\d,]+)\s*views/i);
      if (!m) { log(id + ": 表示回数が読めない"); continue; }
      const views = Number(m[1].replace(/,/g, "")); t.samples.push({ t: Date.now(), v: views });
      const s = t.samples; let verdict = "様子見";
      if (s.length >= 3 && !t.rising_at) {
        const rate = (a, c) => (c.v - a.v) / Math.max(1, (c.t - a.t) / 60000);
        const r1 = rate(s[0], s[1]), rp = rate(s[s.length - 3], s[s.length - 2]), rl = rate(s[s.length - 2], s[s.length - 1]);
        // 投稿直後の伸び（posted → 1 回目）も最初の区間として見る
        const r0 = s[0].v / Math.max(1, (s[0].t - t.posted_ms) / 60000);
        verdict = "毎分 " + rl.toFixed(1) + "（1 つ前 " + rp.toFixed(1) + "・最初 " + Math.max(r0, r1).toFixed(1) + "）";
        if (rl >= MIN_RATE && rl >= rp * RISE && rl >= Math.min(r0, r1)) { t.rising_at = new Date().toISOString(); verdict = "**右肩上がり** " + verdict; }
      }
      log(id + "（" + e.id + "）: 表示 " + views + " / " + verdict);
      if (t.rising_at && !t.pinned) {
        // ③ 固定ポストへの移動（投稿ではない）
        try {
          const art = p.locator("article").first();
          await art.locator('[data-testid="caret"]').first().click({ timeout: 8000 });
          const item = p.locator('[role="menuitem"]', { hasText: /プロフィールに固定する|Pin to your profile/ }).first();
          if (await item.count()) { await item.click({ timeout: 5000 }); await p.locator('[data-testid="confirmationSheetConfirm"]').first().click({ timeout: 8000 }); t.pinned = new Date().toISOString(); log(id + ": 固定ポストに移した"); }
          else { await p.keyboard.press("Escape"); t.pinned = "already"; log(id + ": 固定のメニューが無い（もう固定されている可能性）"); }
        } catch (err) { log(id + ": 固定できない: " + String(err.message).slice(0, 100)); }
        // ① 引用 ② 別の投稿のリプ欄に貼る — 投稿の部分は利用者の「投稿して」を引用した別タスクで入れる。それまでは予定だけ残す
        if (!t.posts_planned) { t.posts_planned = new Date().toISOString(); log(id + ": 引用とリプ（自分の別の投稿に貼る）は、投稿の部分が未導入のため出していない"); }
      }
    } catch (err) { log(id + ": 読めない: " + String(err.message).slice(0, 100)); }
    finally { await p.close().catch(() => {}); }
  }
  // 古い記録は 3 日で消す
  for (const [id, t] of Object.entries(st.tweets)) if (Date.now() - t.posted_ms > 3 * 86400000) delete st.tweets[id];
  fs.writeFileSync(ST, JSON.stringify(st, null, 1));
  process.exit(0);
})().catch((e) => { log("fatal: " + String(e && e.message).slice(0, 200)); process.exit(0); });
JSEOF
if "$NODE_BIN" --check "$TMPJS" 2>&1; then mv "$TMPJS" "$F"; echo "boost-watch.js を入れた（構文 OK）"; else echo "構文 NG。入れない"; rm -f "$TMPJS"; echo '```'; exit 1; fi
cat > "$LA/$LABEL.plist" <<PLEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$NODE_BIN</string><string>$F</string></array>
  <key>WorkingDirectory</key><string>$W</string>
  <key>StartInterval</key><integer>600</integer>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key><string>$HOME</string>
    <key>BOOST_MIN_RATE</key><string>5</string>
  </dict>
  <key>StandardOutPath</key><string>$W/logs/boost-watch-out.log</string>
  <key>StandardErrorPath</key><string>$W/logs/boost-watch-err.log</string>
</dict></plist>
PLEOF
launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
BS="$(launchctl bootstrap "gui/$UID_N" "$LA/$LABEL.plist" 2>&1)"; echo "bootstrap rc=$? $BS"
launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1 && echo "**載っている**" || echo "**載っていない**"
grep -qx "$LABEL" "$HOME/projects/anta-baka-x/blog/ops/data/autoload-jobs.txt" 2>/dev/null && echo "autoload 一覧: 在る" || echo "autoload 一覧: 無い（リポジトリ側で足す）"
echo "--- 試しに 1 回走らせる（見る投稿が無ければ何もしない）"
cd "$W" && "$NODE_BIN" "$F" 2>&1 | tail -5
echo '```'
echo "**LLM を呼ばない（1 回 \$0・1 日 \$0・1 か月 \$0）。このタスクは投稿していない。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
