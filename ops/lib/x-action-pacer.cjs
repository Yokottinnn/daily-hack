// X のアクションの間隔と 30 分あたりの回数を、全ジョブで共有して数える（2026-10-26・シャドウバン対策）。
//
// 利用者「1日の中でも必ず間隔をおいて各種アクションをするようにして／絶対に守られる体制とシステムを作って」。
// 目安（@SakuyaAkiV の図・2026-10-24）: 返信＋投稿＋リポスト 25 回/30 分・いいね 20 回/30 分・フォロー 8 回/30 分。
// **ここの上限は目安の半分前後**にしてある。目安ちょうどを狙わない。
//
// 台帳は 1 つのファイル（ジョブをまたいで数える）。書くときは mkdir のロックで順番にする。
// 判定に使うのは「押した回数」（成功・失敗を問わない）。数え漏れより数えすぎに倒す。
//
//   const p = require("./x-action-pacer.cjs");
//   p.check("follow")            → { ok, waitMs, reason }   見るだけ
//   p.take("follow")             → { ok, waitMs, reason }   空いていれば記録して ok
//   await p.waitTake("follow", 180000) → 最大 180 秒 待って取る。取れなければ ok:false
//
// CLI: node x-action-pacer.cjs until <type> [最大待ち秒]  … 空くまで待つだけ（記録しない）。空いたら exit 0、空かなければ exit 3
//      node x-action-pacer.cjs wait <type> [最大待ち秒]   … 取れたら記録して exit 0、取れなければ exit 3
//      node x-action-pacer.cjs status                   … いまの数
"use strict";
const fs = require("fs");
const path = require("path");
const os = require("os");

const LEDGER = process.env.X_ACTION_LEDGER || path.join(os.homedir(), ".openclaw", "workspace", "data", "x-action-ledger.json");
const LOCK = LEDGER + ".lock";
const WINDOW_MS = 30 * 60 * 1000;

// type: { max: 30 分あたりの上限, gapMs: 前の回からあける最小の間隔 }
const LIMITS = {
  tweet:    { max: 12, gapMs: 60 * 1000 },   // 返信・投稿・引用・リポストを合わせて（目安 25）
  like:     { max: 10, gapMs: 45 * 1000 },   // 目安 20
  follow:   { max: 4,  gapMs: 3 * 60 * 1000 }, // 目安 8
  unfollow: { max: 6,  gapMs: 2 * 60 * 1000 }, // 目安に無い。一気に外すのも同じく危ない
};

function lock() {
  const t0 = Date.now();
  for (;;) {
    try { fs.mkdirSync(LOCK); return true; } catch (e) {
      try { if (Date.now() - fs.statSync(LOCK).mtimeMs > 30000) fs.rmdirSync(LOCK); } catch {}
      if (Date.now() - t0 > 10000) return false;
      const until = Date.now() + 50; while (Date.now() < until) {}
    }
  }
}
function unlock() { try { fs.rmdirSync(LOCK); } catch {} }

function read() {
  try { const j = JSON.parse(fs.readFileSync(LEDGER, "utf8")); return j && typeof j === "object" ? j : {}; } catch { return {}; }
}
function write(j) {
  fs.mkdirSync(path.dirname(LEDGER), { recursive: true });
  const tmp = path.join(path.dirname(LEDGER), ".x-action-ledger.tmp.json");
  fs.writeFileSync(tmp, JSON.stringify(j));
  fs.renameSync(tmp, LEDGER);
}

// 1 日の上限は外した（2026-11-15・利用者「ランダムに一律に実行しないというルールを絶対に守った上で、1日の上限は無くして欲しい」）。
// 代わりに「人の 1 日の動き方」で散らす。決めるのは時刻と日付から作る乱数なので、状態を持たずにどのジョブでも同じ答えになる。
//   ① その日の起きている時間: 始まり 7:00〜9:30・終わり 22:00〜23:50（日ごとに変わる）。外は押さない
//   ② その日の休憩: 昼（11:30〜13:30 に始まり 30〜90 分）・夕方（17:30〜20:00 に始まり 40〜120 分）・半分の日はもう 1 回（20〜60 分）
//   ③ その日の調子: 15% の日は少なめ（間隔 2.2 倍）・20% の日は多め（0.7 倍）・ほかは 0.85〜1.25 倍。毎日の件数がそろわない
//   ④ まとまり: 2〜4 件を数分おきに押したら、20〜75 分は離れる（人はアプリを開いて何件か触って閉じる）
//   ⑤ まとまりの中の間隔も一様にしない（中央 4 分・2〜15 分の偏った分布）
// JST 0〜7 時はどの日も必ず押さない（①より強い）。投稿（tweet）は対象外（予約の告知と返信を止めない）
const DAILY = {};
const DAY_MS = 24 * 60 * 60 * 1000;
const QUIET = { types: ["follow", "unfollow", "like"], fromHour: 0, toHour: 7 };
const HUMAN = { types: ["follow", "unfollow", "like"] };
const COMBINED = { types: ["follow", "unfollow"], max: 4 };
const RAND_GAP = { follow: true, unfollow: true };
const MIN = 60000;
function hash32(x) {
  let h = (Math.floor(x) ^ 0x5bd1e995) >>> 0;
  h = Math.imul(h ^ (h >>> 15), 0x2c1b3c6d); h = Math.imul(h ^ (h >>> 12), 0x297a2d39); h ^= h >>> 15;
  return h >>> 0;
}
function rng(seed) {
  let a = hash32(seed) || 1;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
function jstMinOfDay(now) { const d = new Date(now + 9 * 3600000); return d.getUTCHours() * 60 + d.getUTCMinutes(); }
function jstHour(now) { return new Date(now + 9 * 3600000).getUTCHours(); }
function jstDayKey(now) { return Math.floor((now + 9 * 3600000) / DAY_MS); }
function dayStartUtc(now) { return jstDayKey(now) * DAY_MS - 9 * 3600000; }
function dayPlan(now) {
  const r = rng(jstDayKey(now) * 7919 + 17);
  const start = 7 * 60 + Math.floor(r() * 150), end = Math.min(23 * 60 + 50, 22 * 60 + Math.floor(r() * 110));
  const breaks = [];
  const b1 = 11 * 60 + 30 + Math.floor(r() * 120); breaks.push([b1, b1 + 30 + Math.floor(r() * 60)]);
  const b2 = 17 * 60 + 30 + Math.floor(r() * 150); breaks.push([b2, b2 + 40 + Math.floor(r() * 80)]);
  if (r() < 0.5) { const b3 = start + 60 + Math.floor(r() * Math.max(1, end - start - 180)); breaks.push([b3, b3 + 20 + Math.floor(r() * 40)]); }
  const m = r(); const level = m < 0.15 ? 2.2 : m < 0.35 ? 0.7 : 0.85 + r() * 0.4;
  return { start, end, breaks, level, mood: m < 0.15 ? "少なめの日" : m < 0.35 ? "多めの日" : "ふつうの日" };
}
const hm = (x) => `${String(Math.floor(x / 60)).padStart(2, "0")}:${String(x % 60).padStart(2, "0")}`;
// いまが起きている時間か。外なら次に動ける時刻までの ms
function awake(now) {
  const p = dayPlan(now), t = jstMinOfDay(now), base = dayStartUtc(now);
  if (t < p.start) return { ok: false, waitMs: (p.start - t) * MIN, reason: `その日の始まり（${hm(p.start)}）前` };
  if (t >= p.end) { const q = dayPlan(now + DAY_MS); return { ok: false, waitMs: Math.max(MIN, base + DAY_MS + q.start * MIN - now), reason: `その日の終わり（${hm(p.end)}）より後` }; }
  for (const [a, b] of p.breaks) if (t >= a && t < b) return { ok: false, waitMs: (b - t) * MIN, reason: `休憩中（${hm(a)}〜${hm(b)}）` };
  return { ok: true };
}
// 前の回からあける間隔。前の回の時刻から決まるので、どのジョブが聞いても同じ値になる
function humanGap(type, hist, now) {
  const p = dayPlan(now), last = hist[hist.length - 1];
  const r = rng(last * 31 + (type === "like" ? 7 : 3));
  if (type === "like") return Math.round((45000 + (-Math.log(1 - r() * 0.98)) * 90000) * p.level);
  // いまのまとまりが何件目か（15 分より短い間隔でつながっている数）
  let n = 1; for (let i = hist.length - 1; i > 0 && hist[i] - hist[i - 1] < 15 * MIN; i--) n++;
  const k = 2 + (hash32(hist[hist.length - n] * 13) % 3);
  if (n >= k) return Math.round((20 + r() * 55) * MIN * p.level);
  const z = Math.sqrt(-2 * Math.log(1 - r() * 0.999)) * Math.cos(2 * Math.PI * r());
  return Math.round(Math.max(2 * MIN, Math.min(15 * MIN, 4 * MIN * Math.exp(0.55 * z)) * Math.min(1.6, p.level)));
}
function msUntilQuietEnds(now) {
  const d = new Date(now + 9 * 3600000); d.setUTCHours(QUIET.toHour, 0, 0, 0);
  return Math.max(1000, d.getTime() - 9 * 3600000 - now);
}

// 押す係（2026-11-15・本番）: 待っているジョブの中で、優先の高いもの・先に並んだものから順に取る（1 つずつ）。
// 優先: 認証済みへのフォロー返し 1 ＞ 返信をくれた人 2 ＞ コメントした人 3 ＞ 解除 4 ＞ 競合・ハッシュタグ 5 ＞ その他 6
let ME = null;
function me() {
  if (ME) return ME;
  let parent = "";
  try { parent = require("child_process").execSync(`ps -o command= -p ${process.ppid}`, { encoding: "utf8", timeout: 2000 }).trim().slice(0, 300); } catch {}
  const s = `${path.basename(process.argv[1] || "")} ${parent}`;
  const pri = /badge-followback/.test(s) ? 1 : /incoming-reply-watcher/.test(s) ? 2 : /comment-orchestrator|comment-warmup/.test(s) ? 3
    : /follow-balance|mutual-prune|reply-followers-cleanup|unfollow-handle/.test(s) ? 4 : /competitor-follower|hashtag-follow/.test(s) ? 5 : 6;
  ME = { id: `${process.pid}-${Date.now()}`, pid: process.pid, pri, parent };
  return ME;
}
function alive(pid) { try { process.kill(pid, 0); return true; } catch (e) { return e.code === "EPERM"; } }
function groupOf(type) { return COMBINED.types.includes(type) ? "fu" : type; }
function ahead(j, type, now) {
  const w = j._wait || {}, m = me(), g = groupOf(type);
  const mine = w[m.id] ? w[m.id].since : now;
  for (const [id, x] of Object.entries(w)) {
    if (id === m.id || !x || x.g !== g) continue;
    if (!alive(x.pid) || now - x.since > 40 * MIN) continue;
    if (x.pri < m.pri || (x.pri === m.pri && x.since < mine)) return x;
  }
  return null;
}

function judge(j, type, now) {
  const L = LIMITS[type];
  if (!L) return { ok: true, waitMs: 0, reason: "対象外" };
  if (QUIET.types.includes(type)) {
    const h = jstHour(now);
    if (h >= QUIET.fromHour && h < QUIET.toHour) return { ok: false, waitMs: msUntilQuietEnds(now), reason: `${type}: 深夜（JST ${QUIET.fromHour}〜${QUIET.toHour} 時）は押さない` };
  }
  if (HUMAN.types.includes(type)) { const a = awake(now); if (!a.ok) return { ok: false, waitMs: a.waitMs, reason: `${type}: ${a.reason}` }; }
  // フォローと解除は合わせて数える（同じ 30 分に混ぜて固めない・2026-11-14）
  if (COMBINED.types.includes(type)) {
    const both = COMBINED.types.flatMap((k) => (j[k] || []).filter((t) => now - t < DAY_MS)).sort((a, b) => a - b);
    const w30 = both.filter((t) => now - t < WINDOW_MS);
    if (w30.length >= COMBINED.max) return { ok: false, waitMs: WINDOW_MS - (now - w30[0]) + 1000, reason: `フォロー＋解除: 30 分で ${w30.length} 回（合わせて上限 ${COMBINED.max}）` };
    if (both.length) {
      const g = humanGap(type, both, now), since = now - both[both.length - 1];
      if (since < g) return { ok: false, waitMs: g - since, reason: `${type}: 前の回（フォロー・解除のどちらか）から ${Math.round(since / 1000)} 秒（今回は ${Math.round(g / 1000)} 秒 あける）` };
    }
  } else if (type === "like") {
    const ls = (j.like || []).filter((t) => now - t < DAY_MS);
    if (ls.length) { const g = humanGap("like", ls, now), since = now - ls[ls.length - 1]; if (since < g) return { ok: false, waitMs: g - since, reason: `like: 前の回から ${Math.round(since / 1000)} 秒（今回は ${Math.round(g / 1000)} 秒 あける）` }; }
  }
  const xs = (j[type] || []).filter((t) => now - t < WINDOW_MS);
  if (xs.length) {
    const since = now - xs[xs.length - 1];
    if (since < L.gapMs) return { ok: false, waitMs: L.gapMs - since, reason: `${type}: 前の回から ${Math.round(since / 1000)} 秒（${L.gapMs / 1000} 秒 あける）` };
  }
  if (xs.length >= L.max) return { ok: false, waitMs: WINDOW_MS - (now - xs[0]) + 1000, reason: `${type}: 30 分で ${xs.length} 回（上限 ${L.max}）` };
  if (HUMAN.types.includes(type)) { const x = ahead(j, type, now); if (x) return { ok: false, waitMs: 20000, reason: `${type}: 先に並んでいるジョブ（優先 ${x.pri}）がある` }; }
  return { ok: true, waitMs: 0, reason: "" };
}

// 第 2 段（押す係を 1 つにまとめる）の試し運転用に、押す直前の記録を残す（2026-11-14）。失敗しても押すほうは止めない
const SHADOW = path.join(path.dirname(LEDGER), "x-action-shadow.jsonl");
function shadow(type, now) {
  try {
    let parent = "";
    try { parent = require("child_process").execSync(`ps -o command= -p ${process.ppid}`, { encoding: "utf8", timeout: 2000 }).trim().slice(0, 200); } catch {}
    const rec = { t: now, type, script: path.basename(process.argv[1] || ""), arg: (process.argv[2] || "").slice(0, 40), parent };
    fs.appendFileSync(SHADOW, JSON.stringify(rec) + "\n");
  } catch {}
}

function check(type, now = Date.now()) { return judge(read(), type, now); }

function trim(j, now) {
  for (const k of Object.keys(j)) if (Array.isArray(j[k])) j[k] = j[k].filter((t) => now - t < DAY_MS + WINDOW_MS);
  if (j._wait) for (const [id, x] of Object.entries(j._wait)) if (!x || !alive(x.pid) || now - x.since > 40 * MIN) delete j._wait[id];
}
// 並ぶ（waitTake の間だけ）。優先の高いジョブが並んでいる間は、低いジョブは取れない
function queue(type, on, now = Date.now()) {
  if (!HUMAN.types.includes(type) || !lock()) return;
  try { const j = read(); trim(j, now); j._wait = j._wait || {}; const m = me();
    if (on) { if (!j._wait[m.id]) j._wait[m.id] = { pid: m.pid, pri: m.pri, g: groupOf(type), since: now }; } else delete j._wait[m.id];
    write(j);
  } finally { unlock(); }
}

function take(type, now = Date.now()) {
  if (!LIMITS[type]) return { ok: true, waitMs: 0, reason: "対象外" };
  // ロックが取れない＝台帳が壊れている等。**止める側に倒す**（押さない）
  if (!lock()) return { ok: false, waitMs: 5000, reason: "台帳のロックが取れない" };
  try {
    const j = read();
    trim(j, now);
    const r = judge(j, type, now);
    if (r.ok) { (j[type] = j[type] || []).push(now); if (j._wait) delete j._wait[me().id]; write(j); shadow(type, now); }
    return r;
  } finally { unlock(); }
}

async function waitTake(type, maxWaitMs) {
  const t0 = Date.now();
  queue(type, true);
  try {
    for (;;) {
      const r = take(type);
      if (r.ok) return r;
      const left = maxWaitMs - (Date.now() - t0);
      if (r.waitMs > left) return r;
      await new Promise((res) => setTimeout(res, Math.min(r.waitMs, left) + 250));
    }
  } finally { queue(type, false); }
}

// 空くまで待つだけ（記録しない）。スクリプトが押す前に呼ぶ。記録は関所（x-action-guard）が実際のリクエストで行う
async function waitFree(type, maxWaitMs) {
  const t0 = Date.now();
  for (;;) {
    const r = check(type);
    if (r.ok) return r;
    const left = maxWaitMs - (Date.now() - t0);
    if (r.waitMs > left) return r;
    await new Promise((res) => setTimeout(res, Math.min(r.waitMs, left) + 250));
  }
}

module.exports = { LIMITS, DAILY, QUIET, HUMAN, RAND_GAP, COMBINED, LEDGER, WINDOW_MS, check, take, waitTake, waitFree, dayPlan, awake, humanGap };

if (require.main === module) {
  const [cmd, type, sec] = process.argv.slice(2);
  if (cmd === "until") {
    waitFree(type, Number(sec || 180) * 1000).then((r) => {
      console.error(`[x-action-pacer] ${type}: ${r.ok ? "空いた" : "空かない（" + r.reason + "）"}`);
      process.exit(r.ok ? 0 : 3);
    });
  } else if (cmd === "wait") {
    waitTake(type, Number(sec || 180) * 1000).then((r) => {
      console.error(`[x-action-pacer] ${type}: ${r.ok ? "取れた" : "取れない（" + r.reason + "）"}`);
      process.exit(r.ok ? 0 : 3);
    });
  } else if (cmd === "status") {
    const j = read(), now = Date.now(), p = dayPlan(now);
    console.log(`きょうの動き方: ${hm(p.start)}〜${hm(p.end)}・休憩 ${p.breaks.map(([a, b]) => hm(a) + "〜" + hm(b)).join(" / ")}・${p.mood}（間隔 ${p.level.toFixed(2)} 倍）`);
    const a = awake(now); console.log(`いま: ${a.ok ? "動ける時間" : a.reason}`);
    for (const [t, L] of Object.entries(LIMITS)) {
      const xs = (j[t] || []).filter((x) => now - x < WINDOW_MS);
      const d = (j[t] || []).filter((x) => now - x < DAY_MS);
      console.log(`${t}: 直近 30 分 ${xs.length}/${L.max}・直近 24 時間 ${d.length}（1 日の上限なし）`);
    }
    const w = Object.values(j._wait || {}).filter((x) => x && alive(x.pid));
    console.log(`並んでいるジョブ: ${w.length ? w.map((x) => "優先" + x.pri).join(" ") : "なし"}`);
  } else {
    console.error("usage: x-action-pacer.cjs wait <tweet|like|follow|unfollow> [秒] | status");
    process.exit(2);
  }
}
