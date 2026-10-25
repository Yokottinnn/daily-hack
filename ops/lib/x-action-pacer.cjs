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

function judge(j, type, now) {
  const L = LIMITS[type];
  if (!L) return { ok: true, waitMs: 0, reason: "対象外" };
  const xs = (j[type] || []).filter((t) => now - t < WINDOW_MS);
  if (xs.length) {
    const since = now - xs[xs.length - 1];
    if (since < L.gapMs) return { ok: false, waitMs: L.gapMs - since, reason: `${type}: 前の回から ${Math.round(since / 1000)} 秒（${L.gapMs / 1000} 秒 あける）` };
  }
  if (xs.length >= L.max) return { ok: false, waitMs: WINDOW_MS - (now - xs[0]) + 1000, reason: `${type}: 30 分で ${xs.length} 回（上限 ${L.max}）` };
  return { ok: true, waitMs: 0, reason: "" };
}

function check(type, now = Date.now()) { return judge(read(), type, now); }

function take(type, now = Date.now()) {
  if (!LIMITS[type]) return { ok: true, waitMs: 0, reason: "対象外" };
  // ロックが取れない＝台帳が壊れている等。**止める側に倒す**（押さない）
  if (!lock()) return { ok: false, waitMs: 5000, reason: "台帳のロックが取れない" };
  try {
    const j = read();
    for (const k of Object.keys(j)) j[k] = (j[k] || []).filter((t) => now - t < 2 * WINDOW_MS);
    const r = judge(j, type, now);
    if (r.ok) { (j[type] = j[type] || []).push(now); write(j); }
    return r;
  } finally { unlock(); }
}

async function waitTake(type, maxWaitMs) {
  const t0 = Date.now();
  for (;;) {
    const r = take(type);
    if (r.ok) return r;
    const left = maxWaitMs - (Date.now() - t0);
    if (r.waitMs > left) return r;
    await new Promise((res) => setTimeout(res, Math.min(r.waitMs, left) + 250));
  }
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

module.exports = { LIMITS, LEDGER, WINDOW_MS, check, take, waitTake, waitFree };

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
    const j = read(), now = Date.now();
    for (const [t, L] of Object.entries(LIMITS)) {
      const xs = (j[t] || []).filter((x) => now - x < WINDOW_MS);
      console.log(`${t}: 直近 30 分 ${xs.length}/${L.max}・間隔 ${L.gapMs / 1000} 秒`);
    }
  } else {
    console.error("usage: x-action-pacer.cjs wait <tweet|like|follow|unfollow> [秒] | status");
    process.exit(2);
  }
}
