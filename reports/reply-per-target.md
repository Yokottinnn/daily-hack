# 同じ相手への返信の回数と、相手ごとの間隔（2026-10-11 16:58:32 JST・$0）

## ① comment-state.js の全文

```js
// 164 行 / 最終更新 2026-05-09 22:42
#!/usr/bin/env node
/**
 * comment-state.js — Manage comment-bot warm-up rate limits.
 *
 * State file: ~/.openclaw/workspace/data/comment-state.json
 * Schema: {
 *   rollout_started_at: ISO,
 *   targets: [{ handle, last_commented_at }],  # 7-day cooldown per target
 *   daily_counts: { "YYYY-MM-DD": N },
 *   hourly_counts: { "YYYY-MM-DD-HH": N },
 *   recent_negative_signals: [{ at, target, kind }]
 * }
 *
 * Subcommands:
 *   phase                       → returns current warm-up phase + limits {phase,daily_max,hourly_max,tone}
 *   can-comment <handle>        → checks if we can comment to this handle right now {ok:bool, reason?}
 *   record-comment <handle>     → record a successful comment (increment counters)
 *   record-negative <handle> <kind>  → log negative signal (block/mute/insult), may auto-pause
 *   stats                       → return current stats
 */
const fs = require("fs");
const os = require("os");
const path = require("path");

const STATE_PATH = path.join(os.homedir(), ".openclaw", "workspace", "data", "comment-state.json");

function loadState() {
  if (!fs.existsSync(STATE_PATH)) {
    return {
      rollout_started_at: new Date().toISOString(),
      targets: [],
      daily_counts: {},
      hourly_counts: {},
      recent_negative_signals: [],
      paused: false,
      pause_reason: null,
    };
  }
  return JSON.parse(fs.readFileSync(STATE_PATH, "utf8"));
}
function saveState(s) {
  const tmp = STATE_PATH + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(s, null, 2));
  fs.renameSync(tmp, STATE_PATH);
}

function jstDate() {
  const d = new Date();
  const j = new Date(d.getTime() + 9 * 3600000);
  return j.toISOString().slice(0, 10);
}
function jstHour() {
  const d = new Date();
  const j = new Date(d.getTime() + 9 * 3600000);
  return j.toISOString().slice(0, 13);
}

function getPhase(s) {
  const start = new Date(s.rollout_started_at).getTime();
  const days = Math.floor((Date.now() - start) / 86400000);
  if (days < 7)  return { phase: "warmup_w1", daily_max: 2,  hourly_max: 1, tone: "soft", days_in: days };
  if (days < 14) return { phase: "warmup_w2", daily_max: 5,  hourly_max: 1, tone: "soft", days_in: days };
  return        { phase: "scale",      daily_max: 10, hourly_max: 2, tone: "mid",  days_in: days };
}

function out(obj) { console.log(JSON.stringify(obj)); }

const COOLDOWN_DAYS = 7;

function main() {
  const [, , cmd, ...args] = process.argv;
  const s = loadState();
  const phase = getPhase(s);

  switch (cmd) {
    case "phase": {
      out(phase);
      return;
    }
    case "can-comment": {
      const handle = args[0];
      if (s.paused) return out({ ok: false, reason: "bot paused: " + s.pause_reason });
      const today = jstDate();
      const hour = jstHour();
      const dailyN = s.daily_counts[today] || 0;
      const hourlyN = s.hourly_counts[hour] || 0;
      if (dailyN >= phase.daily_max) return out({ ok: false, reason: `daily limit reached (${dailyN}/${phase.daily_max})` });
      if (hourlyN >= phase.hourly_max) return out({ ok: false, reason: `hourly limit reached (${hourlyN}/${phase.hourly_max})` });
      // Cooldown per target
      if (handle) {
        const t = s.targets.find(x => x.handle === handle);
        if (t) {
          const ageDays = (Date.now() - new Date(t.last_commented_at).getTime()) / 86400000;
          if (ageDays < COOLDOWN_DAYS) return out({ ok: false, reason: `cooldown ${COOLDOWN_DAYS}d for @${handle}, last ${Math.round(ageDays*10)/10}d ago` });
        }
      }
      out({ ok: true, phase: phase.phase, daily_count: dailyN, hourly_count: hourlyN });
      return;
    }
    case "record-comment": {
      const handle = args[0];
      const today = jstDate();
      const hour = jstHour();
      s.daily_counts[today] = (s.daily_counts[today] || 0) + 1;
      s.hourly_counts[hour] = (s.hourly_counts[hour] || 0) + 1;
      // Trim old hourly counts (keep 7 days)
      const cutoff = jstHour();
      // For simplicity skip pruning here
      // Update target
      const existing = s.targets.find(x => x.handle === handle);
      if (existing) existing.last_commented_at = new Date().toISOString();
      else s.targets.push({ handle, last_commented_at: new Date().toISOString() });
      saveState(s);
      out({ ok: true });
      return;
    }
    case "record-negative": {
      const [handle, kind] = args;
      s.recent_negative_signals.push({
        at: new Date().toISOString(), target: handle, kind,
      });
      // Auto-pause if 3 negative signals in 24h
      const recent = s.recent_negative_signals.filter(n =>
        Date.now() - new Date(n.at).getTime() < 86400000);
      if (recent.length >= 3) {
        s.paused = true;
        s.pause_reason = `${recent.length} negative signals in 24h`;
      }
      saveState(s);
      out({ ok: true, paused: s.paused });
      return;
    }
    case "stats": {
      const today = jstDate();
      const hour = jstHour();
      out({
        phase: phase.phase,
        days_in: phase.days_in,
        daily_count: s.daily_counts[today] || 0,
        daily_max: phase.daily_max,
        hourly_count: s.hourly_counts[hour] || 0,
        hourly_max: phase.hourly_max,
        targets_in_cooldown: s.targets.filter(t =>
          (Date.now() - new Date(t.last_commented_at).getTime()) / 86400000 < COOLDOWN_DAYS).length,
        paused: s.paused,
        pause_reason: s.pause_reason,
        recent_negatives: s.recent_negative_signals.length,
      });
      return;
    }
    case "unpause": {
      s.paused = false;
      s.pause_reason = null;
      saveState(s);
      out({ ok: true });
      return;
    }
    default:
      console.error("Usage: comment-state.js <phase|can-comment|record-comment|record-negative|stats|unpause> [args]");
      process.exit(1);
  }
}

main();
```

## ② comment-state.json の設定（targets は件数だけ）

```
  rollout_started_at: "2026-04-25T06:19:20.061Z"
  targets: 配列 58 件
  daily_counts:
    2026-05-10: 1
    2026-05-11: 4
    2026-05-12: 9
    2026-05-13: 10
    2026-05-14: 8
    2026-05-15: 6
    2026-05-16: 10
    2026-05-17: 4
    2026-05-18: 1
    2026-07-05: 4
    2026-07-06: 2
  hourly_counts: オブジェクト 34 キー
  recent_negative_signals: 配列 0 件
  paused: false
  pause_reason: null
  targets に money_yossy: 在る
```

## ③ 返信を「相手 × 日」で数える（キュー・直近 7 日・JST）

対象: 相手が分かる返信 129 件（うち投稿済み 125 件）／キュー全体 1544 件

### money_yossy への返信 7 件（投稿済み 7 件）

| JST | ジョブ | 投稿済み | 本文の先頭 |
| --- | --- | --- | --- |
| 10-06 19:04 | comment | はい | それアタシもずっと思ってるわ。給与上げたら減税、顧客満足度高い会社は優遇、みたい |
| 10-07 16:05 | comment | はい | ループ地獄、やだわね…。で、その交換ページ、キャッシュクリアしてみた？ブラウザの |
| 10-07 22:03 | comment | はい | ④と⑤、本当にそれ。アタシもパスワード使いまわしてた時期あるけど、一個漏れたら全 |
| 10-09 12:03 | comment | はい | ふん、先手を打ったわね。情報漏洩のニュース見るたびにアタシも思うわ。ポイントサイ |
| 10-10 05:03 | comment | はい | あら、紹介したサービスがコケるとメンタル来るのね。その気持ちわかるわ。HafHも |
| 10-11 05:04 | comment | はい | 10年と7年、両方試してるんだ。それでも折り合いつけようとしてる姿勢、アタシは嫌 |
| 10-11 16:03 | comment | はい | えっ、iPhoneAirでもそんな変わんないの？だったら買い替える理由、カメラか |

### 投稿済みで、同じ相手に 1 日 2 回以上返した組（相手 × 日）: 7 組

ジョブ別（その組に含まれる返信の数）: {"comment":14}

| 相手 | 日 | 回数 | ジョブ |
| --- | --- | --- | --- |
| me…(13字) | 2026-10-05 | 2 | comment |
| 71…(6字) | 2026-10-07 | 2 | comment |
| po…(14字) | 2026-10-07 | 2 | comment |
| money_yossy | 2026-10-07 | 2 | comment |
| ok…(11字) | 2026-10-08 | 2 | comment |
| po…(14字) | 2026-10-10 | 2 | comment |
| money_yossy | 2026-10-11 | 2 | comment |

### 7 日の合計で多い相手（上位 10・伏せ）／相手の数 92 人

- po…(14字) 7 回
- money_yossy 7 回
- _9…(6字) 4 回
- 1x…(15字) 3 回
- in…(14字) 3 回
- jf…(11字) 2 回
- ci…(9字) 2 回
- do…(15字) 2 回
- ha…(12字) 2 回
- os…(10字) 2 回

## ④ 返信を出しているスクリプトと、can-comment を通っているか

```
  asuka-fill.js                      can-comment を呼ぶ行 0
  auto-reply.js                      can-comment を呼ぶ行 0
  dm-process.js                      can-comment を呼ぶ行 0
  grok-trending-daily.js             can-comment を呼ぶ行 0
  incoming-reply-responder.js        can-comment を呼ぶ行 0
  pick-past-article-for-qt.js        can-comment を呼ぶ行 0
  poll-approvals.js                  can-comment を呼ぶ行 0
  post-quote-tweet.js                can-comment を呼ぶ行 0
  quick-reply-watcher.js             can-comment を呼ぶ行 0
  comment-orchestrator.sh            can-comment を呼ぶ行 2
  qt-orchestrator.sh                 can-comment を呼ぶ行 0
  qt-past-articles-orchestrator.sh   can-comment を呼ぶ行 0
  run-comment.sh                     can-comment を呼ぶ行 0
```

auto-reply.js の頭（どこから呼ばれ、何を確かめてから出すか）

```js
#!/usr/bin/env node
// 2026-07-26 silence-enforce: intercept slackPost when kind is silent
(function(){
  const __sn_fs = require("fs");
  const SILENCE_SCRIPT_KIND = "auto-reply-complete";
  let __IS_SILENT = false;
  try {
    const cfgPath = process.env.HOME + "/.openclaw/workspace/config/silent_slack.json";
    const cfg = JSON.parse(__sn_fs.readFileSync(cfgPath, "utf8"));
    if (cfg.kill_switch_all || (cfg.silent_kinds && cfg.silent_kinds[SILENCE_SCRIPT_KIND])) {
      __IS_SILENT = true;
    }
  } catch (e) {}
  if (__IS_SILENT) {
    const __sn_https = require("https");
    const __sn_orig_request = __sn_https.request;
    __sn_https.request = function(opts, cb) {
      const host = (typeof opts === "string") ? new URL(opts).hostname : (opts.hostname || opts.host || "");
      if (host === "slack.com") {
        const fake = {
          on: () => fake,
          write: () => fake,
          setHeader: () => fake,
          removeHeader: () => fake,
          end: () => {
            if (cb) cb({
              statusCode: 200,
              on: (ev, fn) => {
                if (ev === "data") fn(Buffer.from('{"ok":true,"skipped":"silent_kind:' + SILENCE_SCRIPT_KIND + '","ts":"silenced"}'));
                if (ev === "end") fn();
              },
            });
          },
        };
        return fake;
      }
      return __sn_orig_request.apply(__sn_https, arguments);
    };
    if (typeof fetch !== "undefined") {
      const __sn_orig_fetch = fetch;
      global.fetch = async function(url, opts) {
        const u = typeof url === "string" ? url : (url && url.url);
        if (u && String(u).includes("slack.com")) {
          const body = '{"ok":true,"skipped":"silent_kind:' + SILENCE_SCRIPT_KIND + '"}';
          return { ok: true, status: 200, json: async () => JSON.parse(body), text: async () => body };
        }
        return __sn_orig_fetch(url, opts);
      };
    }
    console.error("[silence-enforce] this script kind=" + SILENCE_SCRIPT_KIND + " is silent, slack HTTP calls suppressed");
  }
})();

/**
 * auto-reply.js <entry-id>
 *
 * 2026-05-18 確立: kind=comment (リプライ) は user 承認不要、即時 X 投稿 + Slack 報告のみ。
 * 関連 memory: feedback_immediate_post_on_approval.md 「🟩 reply/comment: 承認不要・自動投稿」
 * 2026-05-19 fix: stderr キャプチャ + リトライ(最大2回, 10s待機) 追加
 *
```

## ⑤ 返信を出すジョブの載り具合（launchctl print）

```
  ai.openclaw.comment-warmup               載っている / 	runs = 29 	last exit code = 0 
  ai.openclaw.incoming-reply-watcher       載っている / 	runs = 519 	last exit code = 0 
  ai.openclaw.quick-reply-watcher          載っていない
  ai.openclaw.auto-thread-chainifier       載っていない
```

**書き換えていない。投稿していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
