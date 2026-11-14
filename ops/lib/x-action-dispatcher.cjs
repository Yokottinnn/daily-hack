// 押す係（第 2 段・試し運転）。2026-11-14、X に「スパム・プラットフォーム操作」のラベルが付いた対策。
// 利用者がダイアログで選んだ「押す係を 1 つにまとめる（順番待ち）」「この順でよい」「まず試し運転で作る」。
//
// 試し運転（DRY_RUN=1・既定）では何も押さない。x-action-pacer が残す「押す直前の記録」（x-action-shadow.jsonl）を
// 順番待ちの列とみなし、押す係が 1 本だった場合にいつ・どれを押したかだけを x-action-dispatcher-dry.jsonl に書く。
//   - 起きるのは launchd の 15 分ごと。前回から 15〜40 分のランダムな時間がたっていなければ何もしない
//   - JST 8:00〜23:29 だけ動く
//   - 1 回に 1 件。優先の順: 認証済みへのフォロー返し ＞ 返信をくれた人 ＞ コメントした人 ＞ 解除 ＞ 競合・ハッシュタグ
//   - 列に 48 時間より長く残ったものは押さずに捨てる
//   - 1 日の上限はフォロー 10・解除 10（x-action-pacer と同じ）
"use strict";
const fs = require("fs"), path = require("path"), os = require("os");
const DATA = process.env.X_DISPATCH_DATA || path.join(os.homedir(), ".openclaw", "workspace", "data");
const SHADOW = path.join(DATA, "x-action-shadow.jsonl");
const STATE = path.join(DATA, "x-action-dispatcher-state.json");
const OUTLOG = path.join(DATA, "x-action-dispatcher-dry.jsonl");
const DRY = process.env.DRY_RUN !== "0";
const GAP = [15 * 60000, 40 * 60000], TTL = 48 * 3600000, DAILY = { follow: 10, unfollow: 10 };

function source(r) {
  const s = `${r.script} ${r.parent}`;
  if (/badge-followback/.test(s)) return { src: "認証済みへのフォロー返し", pri: 1 };
  if (/incoming-reply-watcher/.test(s)) return { src: "返信をくれた人", pri: 2 };
  if (/comment-orchestrator|comment-warmup/.test(s)) return { src: "コメントした人", pri: 3 };
  if (r.type === "unfollow") return { src: /mutual-prune/.test(s) ? "相互の解除" : /reply-followers-cleanup/.test(s) ? "返さない人の解除" : "片思いの解除", pri: 4 };
  if (/competitor-follower/.test(s)) return { src: "競合のフォロワー", pri: 5 };
  if (/hashtag-follow/.test(s)) return { src: "ハッシュタグ", pri: 5 };
  return { src: "その他", pri: 6 };
}
const jst = (t) => new Date(t + 9 * 3600000);
function readJsonl(f) { try { return fs.readFileSync(f, "utf8").split("\n").filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean); } catch { return []; } }

function main(now = Date.now()) {
  let st = {}; try { st = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch {}
  st.consumed = st.consumed || {}; st.done = st.done || [];
  const h = jst(now).getUTCHours(), m = jst(now).getUTCMinutes();
  if (h < 8 || (h === 23 && m >= 30)) return { skip: "時間外（JST 8:00〜23:29 だけ動く）" };
  if (st.nextAt && now < st.nextAt) return { skip: `次に起きるのは ${jst(st.nextAt).toISOString().slice(11, 16)}` };
  const day = st.done.filter((d) => now - d.t < 24 * 3600000);
  const queue = readJsonl(SHADOW).filter((r) => r && r.t && !st.consumed[r.t + r.type] && now - r.t < TTL && r.t <= now)
    .map((r) => ({ ...r, ...source(r) }))
    .filter((r) => (day.filter((d) => d.type === r.type).length) < (DAILY[r.type] || 99))
    .sort((a, b) => a.pri - b.pri || a.t - b.t);
  const gap = GAP[0] + Math.floor(Math.random() * (GAP[1] - GAP[0]));
  st.nextAt = now + gap;
  let picked = null;
  if (queue.length) {
    picked = queue[0]; st.consumed[picked.t + picked.type] = now;
    const rec = { at: now, at_jst: jst(now).toISOString().slice(0, 16).replace("T", " "), type: picked.type, src: picked.src, pri: picked.pri,
      queued_jst: jst(picked.t).toISOString().slice(0, 16).replace("T", " "), waited_min: Math.round((now - picked.t) / 60000), queue_left: queue.length - 1, dry: DRY };
    fs.appendFileSync(OUTLOG, JSON.stringify(rec) + "\n");
    st.done.push({ t: now, type: picked.type }); st.done = st.done.filter((d) => now - d.t < 48 * 3600000);
  }
  for (const k of Object.keys(st.consumed)) if (now - st.consumed[k] > 3 * TTL) delete st.consumed[k];
  fs.writeFileSync(STATE, JSON.stringify(st));
  return { picked: picked ? `${picked.type}（${picked.src}）` : "列が空", next_in_min: Math.round(gap / 60000), queue: queue.length };
}

if (require.main === module) {
  const r = main();
  console.log(`[x-action-dispatcher ${DRY ? "試し運転" : "本番"}] ${new Date().toISOString()} ${JSON.stringify(r)}`);
}
module.exports = { main, source };
