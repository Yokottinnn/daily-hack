// 同じ相手への返信は 1 日（JST）1 回まで。**ジョブをまたいで**キュー（post_queue.json）から数える。
//
// 2026-10-11 の指示:
//   > 投稿数が多い場合に毎回毎回返してたら不自然だから、同じ相手へのリプライは1日1回迄にして
//
// 使い方
//   const { check } = require("./reply-once-per-day.cjs");
//   check("money_yossy")            // → { ok: false, count: 1, reason: "..." }
//   node reply-once-per-day.cjs money_yossy   // 同じ JSON を 1 行で出す（シェルから使う）
//
// 数えるもの: 相手が分かる返信のうち、**今日（JST）に積まれた・出たもの**。
//   投稿済み（x_tweet_id / tweet_id / status=posted）と、まだ出ていない待ち（失敗・失効・見送り以外）の両方。
//   待ちも数えないと、別のジョブが同じ日に同じ相手へ積んでしまう。
//
// **設備の故障では止めない**（x-reply-style §4）。キューが読めないときは ok:true（今日と同じ状態に戻るだけ）。
// throw はしない。ここで投げると返信ジョブごと落ちる。
"use strict";
const fs = require("fs");
const path = require("path");

const QUEUE = process.env.POST_QUEUE || path.join(process.env.HOME || "", ".openclaw/workspace/data/post_queue.json");
const LIMIT = Number(process.env.REPLY_PER_TARGET_DAILY || 1);
const DEAD = new Set(["failed", "expired", "skipped", "rejected", "cancelled", "canceled", "dropped", "deleted"]);

const norm = (h) => String(h || "").trim().replace(/^@/, "").toLowerCase();
const handleOf = (e) => norm(e.target_handle || e.reply_to_handle || e.in_reply_to_handle ||
  (String(e.target_url || e.reply_to_url || "").match(/(?:x|twitter)\.com\/([A-Za-z0-9_]+)\/status/) || [])[1]);
const timeOf = (e) => {
  for (const k of ["posted_at", "created_at", "enqueued_at", "updated_at"]) { const t = Date.parse(e[k] || ""); if (t) return t; }
  const m = String(e.id || "").match(/(20\d{6})-(\d{4})/);
  return m ? Date.parse(`${m[1].slice(0, 4)}-${m[1].slice(4, 6)}-${m[1].slice(6)}T${m[2].slice(0, 2)}:${m[2].slice(2)}:00+09:00`) : 0;
};
const jstDay = (t) => new Date(t + 9 * 3600e3).toISOString().slice(0, 10);

function check(handle, opt = {}) {
  const h = norm(handle);
  if (!h) return { ok: true, count: 0, reason: "相手が分からないので数えない" };
  let q;
  try { q = JSON.parse(fs.readFileSync(opt.queuePath || QUEUE, "utf8")).queue || []; }
  catch (e) { return { ok: true, count: 0, reason: "キューが読めないので素通し: " + String(e.message).slice(0, 80) }; }
  const today = jstDay(opt.now || Date.now());
  const hits = q.filter((e) => e && handleOf(e) === h && !DEAD.has(String(e.status || "").toLowerCase()) &&
    timeOf(e) && jstDay(timeOf(e)) === today);
  const ok = hits.length < LIMIT;
  return { ok, count: hits.length, limit: LIMIT, day: today,
    reason: ok ? "今日はまだ " + hits.length + " 回" : "今日（" + today + " JST）はもう " + hits.length + " 回返している（上限 " + LIMIT + "）" };
}

module.exports = { check, handleOf };

if (require.main === module) {
  try { console.log(JSON.stringify(check(process.argv[2]))); }
  catch (e) { console.log(JSON.stringify({ ok: true, count: 0, reason: "判定できないので素通し" })); }
}
