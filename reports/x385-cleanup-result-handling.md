# 外す処理の結果の扱い（2026-10-31 11:59:13 JST・読むだけ・$0）
全 100 行
```javascript
#!/usr/bin/env node
// reply-followers-cleanup.js — every 1h cron.
// For each entry with scheduled_unfollow_at <= now:
//   - 直前再check (master rule): if follows_us → cancel unfollow, status=yes_late
//   - else → call unfollow-handle, status=unfollowed
const fs = require("fs");
const { execSync } = require("child_process");

const STATE_PATH = "/Users/ny/.openclaw/workspace/data/reply-followers.json";
const CHECK_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/check-followback.js";
const UNFOLLOW_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/unfollow-handle.js";
const LOG_PATH = "/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.log";

function log(s) {
  const line = `[${new Date().toISOString()}] ${s}\n`;
  try { fs.appendFileSync(LOG_PATH, line); } catch {}
  console.log(line.trim());
}

function loadState() {
  if (!fs.existsSync(STATE_PATH)) return {};
  return JSON.parse(fs.readFileSync(STATE_PATH, "utf8"));
}
function saveState(s) {
  const tmp = STATE_PATH + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(s, null, 2));
  fs.renameSync(tmp, STATE_PATH);
}

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  const state = loadState();
  const now = Date.now();

  const due = [];
  for (const [handle, e] of Object.entries(state)) {
    if (!e.scheduled_unfollow_at) continue;
    if (e.followback_status !== "no") continue;
    const sat = new Date(e.scheduled_unfollow_at).getTime();
    if (sat > now) continue;
    due.push(handle);
  }
  if (due.length === 0) {
    log("nothing due");
    return;
  }
  const CLEANUP_MAX_PER_RUN = Number(process.env.CLEANUP_MAX_PER_RUN || 20);
  if (due.length > CLEANUP_MAX_PER_RUN) {
    log(`due ${due.length} → 上限 ${CLEANUP_MAX_PER_RUN} 件に絞る（残りは次回）`);
    due.length = CLEANUP_MAX_PER_RUN;
  }
  log(`due unfollows: ${due.length} → ${due.join(",")}`);

  // Master rule: 直前再check (batch)
  let recheck;
  try {
    const out = execSync(`/usr/local/bin/node ${CHECK_SCRIPT} ${due.join(" ")}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024, timeout: 120000 });
    recheck = JSON.parse(out.trim().split("\n").pop());
  } catch (e) {
    log(`recheck failed: ${e.message} — abort cleanup`);
    return;
  }

  for (const r of recheck.results || []) {
    const e = state[r.handle];
    if (!e) continue;
    if (r.follows_us === true) {
      e.followback_status = "yes_late";
      e.scheduled_unfollow_at = null;
      e.late_followback_at = new Date().toISOString();
      log(`@${r.handle}: late followback detected — unfollow cancelled (yes_late)`);
      continue;
    }
    if (r.follows_us !== false) {
      log(`@${r.handle}: recheck error, skip this cycle`);
      continue;
    }
    // Confirmed no followback → unfollow
    try {
      const out = execSync(`/usr/local/bin/node ${UNFOLLOW_SCRIPT} ${r.handle}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024, timeout: 120000 });
      const uo = JSON.parse(out.trim().split("\n").pop());
      if (uo.ok) {
        e.followback_status = "unfollowed";
        e.unfollowed_at = new Date().toISOString();
        e.scheduled_unfollow_at = null;
        log(`@${r.handle}: unfollowed`);
      } else {
        log(`@${r.handle}: unfollow failed (${uo.reason || "unknown"})`);
      }
    } catch (e2) {
      log(`@${r.handle}: unfollow exec error: ${e2.message}`);
    }
    await sleep(2500);
  }
  saveState(state);
  log("done");
}

main().catch(e => { log(`fatal: ${e.message}`); process.exit(1); });
```
**読んだだけ（$0／回・$0／日・$0／月）。**
