// X のアクションの「最後の関所」（2026-10-26・シャドウバン対策）。
//
// 利用者「1日の中でも必ず間隔をおいて各種アクションをするようにして／絶対に守られる体制とシステムを作って」。
// 各ジョブの node に `NODE_OPTIONS=--require <このファイル>` で読み込ませる（ai.openclaw.* の plist に入れる）。
// playwright / playwright-core を読み込んだ時点で connectOverCDP / launch を包み、
// **X に飛ぶアクションのリクエスト**（投稿・いいね・リポスト・フォロー・フォロー解除）を見張る。
// x-action-pacer の上限・間隔に当たったら、その場でリクエストを止める（abort）。**待たない**。
// 待つとスクリプト側の時間切れと重なり、「出たのに失敗扱い」が起きるため。待つのは各スクリプトの役目。
//
// 故障のときの倒し方: このファイル自体が壊れていても、ジョブは今までどおり動く（素通し）。
// ただし台帳のロックが取れないときは「押さない」側に倒す（x-action-pacer.take）。
"use strict";
const Module = require("module");
const path = require("path");

let pacer = null;
try { pacer = require(path.join(__dirname, "x-action-pacer.cjs")); } catch (e) { pacer = null; }

// URL → アクションの種類
function classify(url, method) {
  if (method !== "POST") return null;
  if (/\/i\/api\/graphql\/[^/]+\/(CreateTweet|CreateNoteTweet|CreateRetweet)\b/.test(url)) return "tweet";
  if (/\/i\/api\/graphql\/[^/]+\/FavoriteTweet\b/.test(url)) return "like";
  if (/\/i\/api\/1\.1\/friendships\/create\.json/.test(url)) return "follow";
  if (/\/i\/api\/1\.1\/friendships\/destroy\.json/.test(url)) return "unfollow";
  return null;
}

const LOG = (msg) => { try { process.stderr.write(`[x-action-guard] ${msg}\n`); } catch {} };
const ROUTE = /\/i\/api\//;

async function handler(route) {
  let req;
  try { req = route.request(); } catch { return route.continue().catch(() => {}); }
  const type = classify(req.url(), req.method());
  if (!type || !pacer) return route.fallback ? route.fallback().catch(() => route.continue().catch(() => {})) : route.continue().catch(() => {});
  const r = pacer.take(type);
  if (r.ok) {
    LOG(`${type}: 通した`);
    return route.fallback ? route.fallback().catch(() => route.continue().catch(() => {})) : route.continue().catch(() => {});
  }
  LOG(`${type}: **止めた**（${r.reason}・あと ${Math.round(r.waitMs / 1000)} 秒）`);
  return route.abort("blockedbyclient").catch(() => {});
}

const done = new WeakSet();
async function guardContext(ctx) {
  if (!ctx || done.has(ctx)) return;
  done.add(ctx);
  try { await ctx.route(ROUTE, handler); } catch (e) { LOG(`route を張れない: ${e && e.message}`); }
}
async function guardBrowser(b) {
  try {
    for (const c of b.contexts()) await guardContext(c);
    const orig = b.newContext && b.newContext.bind(b);
    if (orig) b.newContext = async (...a) => { const c = await orig(...a); await guardContext(c); return c; };
  } catch (e) { LOG(`browser を包めない: ${e && e.message}`); }
  return b;
}

function wrapType(bt) {
  if (!bt || bt.__xGuard) return;
  bt.__xGuard = true;
  for (const name of ["connectOverCDP", "connect", "launch"]) {
    const orig = bt[name];
    if (typeof orig !== "function") continue;
    bt[name] = async function (...a) { const b = await orig.apply(this, a); return guardBrowser(b); };
  }
  const lp = bt.launchPersistentContext;
  if (typeof lp === "function") bt.launchPersistentContext = async function (...a) { const c = await lp.apply(this, a); await guardContext(c); return c; };
}

const origLoad = Module._load;
Module._load = function (request, parent, isMain) {
  const m = origLoad.apply(this, arguments);
  try {
    if (/(^|\/)playwright(-core)?$/.test(request) && m && m.chromium) wrapType(m.chromium);
  } catch {}
  return m;
};

module.exports = { classify };
