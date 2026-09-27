#!/bin/bash
# **①片思いは「反応をくれた人」でも外す ②終了しないバグを直す。DRY で確かめる。$0。**
#
# ## 直したこと 1: 片思いの守りを緩める（2026-09-27 に利用者が選択）
#
# DRY の結果はこうだった。
#
#   フォロー中 274 / フォロワー 311
#   片思い 100 / 相互 174
#   守った内訳: ホワイトリスト 2 / **反応をくれた人 122** / 猶予 12
#   ① 片思いから **20 件** → プロフィールを開いた 40 件 → **外す候補 合計 21 件**
#
# **上限は 30 件 なのに 21 件 で止まった。** 片思いは 100 件 在るのに 20 件 しか採れていない。
# **80 件 が「反応をくれた人」で守られていた**（`reply-followers.json` に 485 件 の記録）。
#
# **相手がこちらをフォローしていないなら、過去に反応があっても外してよい。**
# **相互は今までどおり守る。** ホワイトリストと猶予（7 日）は片思いでも効かせる。
#
#   `ONEWAY_IGNORE_ENGAGED=0` で従来に戻せる
#
# ## 直したこと 2: 終了しないバグ（**本番の前に必ず直す**）
#
#   12:36:47 start → 12:37:20 フォロー中 → 12:37:50 フォロワー ＝ **実作業 63 秒**
#   なのに rc=124（実測 344 秒）＝ **約 280 秒 ぶら下がっていた**
#
# `b.close()` が 1 箇所も無く、**`connectOverCDP` の接続が開いたままで node が終わらない。**
# `x164` の 900 秒 も同じ原因の可能性が高い。
#
# **本番でこれが起きると、アンフォローの途中で打ち切られる。** 先に直す。
# `b.close()` は利用者の Chrome に触りうるので、**`process.exit(0)` で明示的に抜ける**（10 箇所）。
#
# ## このタスクは DRY。1 件も外さない
#
# 一覧は `x176` が書いたキャッシュを使う（**取り直さない**）。
#
# ## やらないこと
#
# **アンフォローしない。フォローもしない。plist も置かない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
TARGET="$S/follow-balance.js"
LF="$D/follow-balance-lists.json"
STAMP="$(date '+%Y%m%d-%H%M%S')"
# **拡張子は `.js` のまま保つ**（`x163` の教訓）
TMPJS="$S/.follow-balance-oneway-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-oneway.md"
RUNLOG="$W/.x179-run.log"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    local victims p
    victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

cat > "$TMPJS" <<'JSEOF'
// フォローとアンフォローの収支を合わせる。
//
// 2026-09-27 作成。**LLM を呼ばない（DOM を読むだけ）ので API 課金は $0。**
//
// **部品は mutual-prune.js から写している。書き直して壊さない。**
//   - playwright-core（`playwright` はこのワークスペースに存在しない）
//   - connectOverCDP で既存の Chrome に繋ぐ（新しく起動しない）
//   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
//
// **なぜ要るか。** mutual-prune.js は「相互だけを対象にする。片思いは既存の別ジョブの担当」
// と明記しているが、**その別ジョブが 1 本も載っていない**（2026-09-27 に確認）。
// 結果、9/25 時点で `フォロー中 249 − 相互 173 = 76 件` の片思いが放置されていた。
//
// 環境変数（既定値は安全側）:
//   DRY_RUN=1            1 件も外さず、判定だけ出す
//   MIN_UNFOLLOW=30      その日のフォロー数が読めないときの下限
//   MAX_UNFOLLOW=60      1 回に外す絶対上限（暴走よけ）
//   GRACE_DAYS=7         フォローしてからこの日数 未満は触らない
//   INACTIVE_DAYS=30     最終投稿がこれより前なら「休眠」
//   BIG_FOLLOWERS=5000   これ以上なら「大きいアカウント」
//   MAX_PROFILE_READS=40 プロフィールを開く上限（時間の暴走よけ）
const { chromium } = require("playwright-core");
const fs = require("fs");
const path = require("path");

const WS = process.env.OPS_WS || path.join(process.env.HOME || "", ".openclaw", "workspace");
const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
const DRY = process.env.DRY_RUN === "1";
const MINN = Number(process.env.MIN_UNFOLLOW || 30);
const MAXN = Number(process.env.MAX_UNFOLLOW || 60);
const GRACE_DAYS = Number(process.env.GRACE_DAYS || 7);
const INACTIVE_DAYS = Number(process.env.INACTIVE_DAYS || 30);
const BIG = Number(process.env.BIG_FOLLOWERS || 5000);
const MAX_READS = Number(process.env.MAX_PROFILE_READS || 40);
// **一覧の取得と判定を分ける**（2026-09-27）。
// まとめて走らせると 900 秒 の上限に当たって打ち切られ、出力が 1 行も残らなかった。
//   MODE=collect  一覧だけ取ってキャッシュに書いて終わる（スクロールが重い）
//   MODE=decide   キャッシュを読んで判定する（プロフィールを開く分が重い）
//   MODE 未指定   従来どおり通しで走る
const MODE = String(process.env.MODE || "all").toLowerCase();
const CACHE_MAX_H = Number(process.env.CACHE_MAX_H || 6);
// **1 本の scrapeList に持ち時間を持たせる。** 無いと片方で使い切る
const LIST_BUDGET_S = Number(process.env.LIST_BUDGET_S || 150);
// **プロフィールを開く側にも持ち時間を持たせる。**
// `readProfile` は 1 件 30 秒 のタイムアウトを持つので、詰まると
// 40 件 × 30 秒 で 900 秒 を超える。2026-09-27 に実際に打ち切られた
const DECIDE_BUDGET_S = Number(process.env.DECIDE_BUDGET_S || 200);
// **片思いは「反応をくれた人」でも外す**（既定 on。0 で従来に戻る）
const ONEWAY_IGNORE_ENGAGED = process.env.ONEWAY_IGNORE_ENGAGED !== "0";

const LOG = path.join(WS, "logs", "follow-balance.log");
const STATE = path.join(WS, "data", "follow-balance-state.json");
const ENGAGED = path.join(WS, "data", "reply-followers.json");
const FOLLOWED = path.join(WS, "data", "followed.json");
const LISTS = path.join(WS, "data", "follow-balance-lists.json");

const FOLLOWING_RE = /^(フォロー中|Following)$/;
const FOLLOW_RE = /^(フォロー|フォローする|Follow|Follow back|フォローバック)$/;

function log(msg) {
  const line = "[" + new Date().toISOString() + "] " + msg;
  console.log(line);
  try { fs.appendFileSync(LOG, line + "\n"); } catch (e) {}
}

function loadWhitelist() {
  const out = new Set();
  for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
    try {
      const d = JSON.parse(fs.readFileSync(path.join(WS, p), "utf8"));
      const arr = Array.isArray(d) ? d : (d.handles || d.whitelist || Object.keys(d));
      for (const h of arr) out.add(String(h).replace(/^@/, "").toLowerCase());
    } catch (e) {}
  }
  return out;
}

// **どんな形で入っていても handle と followed_at を拾う。**
// followed.json は {キー: {handle, followed_at}} の入れ子で、素朴に読むと 0 件になる
// （2026-09-27 に実際そうなった）。**形を決め打ちしない。**
function harvest(file) {
  const byHandle = new Map();
  let root;
  try { root = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { return byHandle; }
  const seen = new Set();
  const walk = (node, keyHint) => {
    if (!node || typeof node !== "object" || seen.has(node)) return;
    seen.add(node);
    if (Array.isArray(node)) { for (const v of node) walk(v, null); return; }
    const at = node.followed_at || node.at || node.created_at || node.followedAt;
    // **容器のキーを handle と見なさない。** 入れ子の {handles:{0:{...}}} で
    // "handles" を 1 件 数えてしまった（2026-09-27 のローカル検証で発見）。
    // **日付の有無では切らない**——日付が無い記録まで落ちて、守る側が弱くなる。
    // 中に子オブジェクトを持つものが容器、持たないものが記録、と見る。
    const isLeaf = !Object.values(node).some((v) => v && typeof v === "object");
    const h = node.handle || node.screen_name || node.username || (isLeaf ? keyHint : null);
    if (h && typeof h === "string" && /^[A-Za-z0-9_]{1,15}$/.test(h.replace(/^@/, ""))) {
      const k = h.replace(/^@/, "").toLowerCase();
      const prev = byHandle.get(k);
      if (!prev || (at && !prev.at)) byHandle.set(k, { at: at || (prev && prev.at) || null });
    }
    for (const [k, v] of Object.entries(node)) walk(v, typeof k === "string" ? k : null);
  };
  walk(root, null);
  return byHandle;
}

function parseCount(s) {
  if (!s) return null;
  const t = String(s).replace(/[\s,]/g, "");
  const m = t.match(/([0-9]+(?:\.[0-9]+)?)(万|億|K|M|k|m)?/);
  if (!m) return null;
  let n = parseFloat(m[1]);
  if (!isFinite(n)) return null;
  const u = m[2];
  if (u === "万") n *= 10000;
  else if (u === "億") n *= 100000000;
  else if (u === "K" || u === "k") n *= 1000;
  else if (u === "M" || u === "m") n *= 1000000;
  return Math.round(n);
}

async function scrapeList(page, url, want) {
  const seen = new Set();
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForTimeout(4000);
  let stable = 0, last = 0;
  // **持ち時間を超えたら、そこまでで返す。** want は実数より大きく置いてあるので
  // 終了条件は実質「6 回 変化なし」だけだった。それだけだと時間が読めない
  const deadline = Date.now() + LIST_BUDGET_S * 1000;
  while (seen.size < want && stable < 6) {
    if (Date.now() > deadline) { log("  ⏱ " + LIST_BUDGET_S + " 秒 を超えたので打ち切る（" + seen.size + " 件）"); break; }
    const got = await page.evaluate(() => {
      const a = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
      const out = [];
      for (const el of a) {
        const m = (el.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
        if (m && !["home", "explore", "notifications", "messages", "i"].includes(m[1])) out.push(m[1]);
      }
      return out;
    });
    got.forEach((h) => seen.add(h));
    if (seen.size === last) stable++; else stable = 0;
    last = seen.size;
    await page.mouse.wheel(0, 2600);
    await page.waitForTimeout(1200);
  }
  return seen;
}

async function readProfile(page, handle) {
  // **タイムアウトは短く。** 1 件で 30 秒 待つと 40 件で 20 分 になる
  await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 12000 });
  await page.waitForTimeout(2200);
  return await page.evaluate(() => {
    const res = { followersText: null, lastPost: null, verified: false };
    const a = document.querySelector('a[href$="/verified_followers"]') ||
              document.querySelector('a[href$="/followers"]');
    if (a) res.followersText = (a.innerText || "").trim();
    const ts = Array.from(document.querySelectorAll("article time[datetime]"))
      .map((t) => t.getAttribute("datetime")).filter(Boolean);
    if (ts.length) {
      const ms = ts.map((x) => new Date(x).getTime()).filter((n) => isFinite(n) && n > 0);
      if (ms.length) res.lastPost = new Date(Math.max.apply(null, ms)).toISOString();
    }
    res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
    return res;
  });
}

(async () => {
  log("=== follow-balance start (dry=" + DRY + " min=" + MINN + " max=" + MAXN +
      " grace=" + GRACE_DAYS + "d inactive=" + INACTIVE_DAYS + "d big=" + BIG + ") ===");

  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
  catch (e) { log("CDP に繋がらない: " + String(e.message).slice(0, 120)); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { log("context が無い。何もしない。"); return; }
  const page = await ctx.newPage();

  let me = null;
  try {
    await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(3000);
    if (/login|i\/flow/.test(page.url())) { log("**ログインが切れている。何もしない。**"); await page.close(); process.exit(0); }
    me = await page.evaluate(() => {
      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
      const m = a && (a.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
      return m ? m[1] : null;
    });
  } catch (e) { log("/home を開けない: " + String(e.message).slice(0, 100)); await page.close(); process.exit(0); }
  if (!me) { log("**自分のハンドルが読めない。何もしない。**"); await page.close(); process.exit(0); }

  let following, followers;
  if (MODE === "decide") {
    // **キャッシュから読む。** 取り直さないので速い
    let c;
    try { c = JSON.parse(fs.readFileSync(LISTS, "utf8")); }
    catch (e) { log("**一覧のキャッシュが読めない。MODE=collect を先に走らせる。** " + String(e.message).slice(0, 80)); await page.close(); process.exit(0); }
    const ageH = (Date.now() - new Date(c.at || 0).getTime()) / 3600000;
    if (!isFinite(ageH) || ageH > CACHE_MAX_H) {
      log("**キャッシュが古い（" + (isFinite(ageH) ? ageH.toFixed(1) : "?") + " 時間）。取り直しが要る。**");
      await page.close(); process.exit(0);
    }
    following = new Set(c.following || []);
    followers = new Set(c.followers || []);
    log("キャッシュから読んだ（" + ageH.toFixed(1) + " 時間 前）: フォロー中 " + following.size + " / フォロワー " + followers.size);
    if (following.size === 0) { log("**キャッシュが空。何もしない。**"); await page.close(); process.exit(0); }
  } else {
    const t0 = Date.now();
    following = await scrapeList(page, "https://x.com/" + me + "/following", 800);
    const t1 = Date.now();
    log("フォロー中: " + following.size + " 件（" + Math.round((t1 - t0) / 1000) + " 秒）");
    if (following.size === 0) { log("**0 件しか読めない。ページが壊れている。何もしない。**"); await page.close(); process.exit(0); }
    followers = await scrapeList(page, "https://x.com/" + me + "/followers", 1000);
    const t2 = Date.now();
    log("フォロワー: " + followers.size + " 件（" + Math.round((t2 - t1) / 1000) + " 秒）");

    // **取れたら必ず書く。** collect でも all でも残す
    try {
      fs.writeFileSync(LISTS, JSON.stringify({
        at: new Date().toISOString(), me,
        following: [...following], followers: [...followers],
        secs: { following: Math.round((t1 - t0) / 1000), followers: Math.round((t2 - t1) / 1000) },
      }, null, 2));
      JSON.parse(fs.readFileSync(LISTS, "utf8"));   // **書いた JSON を自分で読み直す**
      log("一覧を書いた: " + path.basename(LISTS));
    } catch (e) { log("一覧を書けない: " + String(e.message).slice(0, 80)); }

    if (MODE === "collect") {
      log("=== MODE=collect なのでここで終わる（判定はしない） ===");
      await page.close(); process.exit(0);
    }
  }

  const lowerFollowers = new Set([...followers].map((h) => h.toLowerCase()));
  const wl = loadWhitelist();
  const engaged = harvest(ENGAGED);
  const followedMap = harvest(FOLLOWED);
  log("ホワイトリスト " + wl.size + " 件 / 反応の記録 " + engaged.size + " 件 / フォロー日時の記録 " + followedMap.size + " 件");

  // **その日にフォローした数。** 読めなければ下限を使う
  const now = Date.now();
  const jstDay = (ms) => new Date(ms + 9 * 3600 * 1000).toISOString().slice(0, 10);
  const today = jstDay(now);
  let followedToday = 0;
  for (const [, v] of followedMap) {
    if (!v.at) continue;
    const t = new Date(v.at).getTime();
    if (isFinite(t) && jstDay(t) === today) followedToday++;
  }
  const quota = Math.min(MAXN, Math.max(MINN, followedToday));
  log("今日フォローした数: " + followedToday + " 件 → **今回の上限 " + quota + " 件**（下限 " + MINN + " / 絶対上限 " + MAXN + "）");

  const ageDays = (h) => {
    const e = followedMap.get(h.toLowerCase()) || engaged.get(h.toLowerCase());
    if (!e || !e.at) return null;
    const t = new Date(e.at).getTime();
    return isFinite(t) ? (now - t) / 86400000 : null;
  };
  // **片思いのときは「反応をくれた人」で守らない**（2026-09-27 に利用者が選択）。
  // 相手はこちらをフォローしていないので、過去に反応があっても外してよい。
  // **相互は今までどおり守る。** ホワイトリストと猶予は片思いでも効かせる
  const protectedWhy = (h, oneWayStage) => {
    const k = h.toLowerCase();
    if (wl.has(k)) return "ホワイトリスト";
    if (engaged.has(k) && !(oneWayStage && ONEWAY_IGNORE_ENGAGED)) return "反応をくれた人";
    const d = ageDays(h);
    if (d !== null && d < GRACE_DAYS) return "フォローしてまだ " + Math.floor(d) + " 日（猶予 " + GRACE_DAYS + " 日）";
    return null;
  };

  // ① 片思い（フォロバが無い）。**いま誰も担当していない**
  const oneWay = [...following].filter((h) => !lowerFollowers.has(h.toLowerCase()));
  // 相互（②③ の対象）
  const mutual = [...following].filter((h) => lowerFollowers.has(h.toLowerCase()));
  log("片思い: " + oneWay.length + " 件 / 相互: " + mutual.length + " 件");

  const cuts = [];
  const kept = { ホワイトリスト: 0, "反応をくれた人": 0, 猶予: 0 };
  const noteKeep = (why) => {
    if (/ホワイトリスト/.test(why)) kept["ホワイトリスト"]++;
    else if (/反応/.test(why)) kept["反応をくれた人"]++;
    else kept["猶予"]++;
  };

  // ① 片思い。プロフィールを開かずに決められるので速い
  for (const h of oneWay) {
    if (cuts.length >= quota) break;
    const why = protectedWhy(h, true);   // ← 片思いの段
    if (why) { noteKeep(why); continue; }
    cuts.push({ h, why: "返していない（片思い）", rank: 1 });
  }
  log("① 片思いから " + cuts.length + " 件");

  // ②③ 足りなければ相互を見る。**ここだけプロフィールを開く**
  let reads = 0;
  let timeUp = false;
  if (cuts.length < quota) {
    const dl2 = Date.now() + DECIDE_BUDGET_S * 1000;
    for (const h of mutual) {
      if (cuts.length >= quota || reads >= MAX_READS) break;
      if (Date.now() > dl2) { timeUp = true; break; }
      const why = protectedWhy(h, false);  // ← 相互の段。反応は守る
      if (why) { noteKeep(why); continue; }
      let p;
      try { p = await readProfile(page, h); reads++; }
      catch (e) { continue; }
      if (p.verified) continue;
      const fc = parseCount(p.followersText);
      const idle = p.lastPost ? Math.floor((now - new Date(p.lastPost).getTime()) / 86400000) : null;
      if (idle !== null && idle >= INACTIVE_DAYS) { cuts.push({ h, why: "休眠 " + idle + " 日", rank: 2 }); continue; }
      if (fc !== null && fc >= BIG) { cuts.push({ h, why: "大きいアカウント " + fc + " フォロワー", rank: 3 }); continue; }
    }
  }
  log("プロフィールを開いた: " + reads + " 件 / **外す候補 合計 " + cuts.length + " 件**" +
      (timeUp ? "（**" + DECIDE_BUDGET_S + " 秒 で打ち切った。相互を見切れていない**）" : ""));
  log("守った内訳: ホワイトリスト " + kept["ホワイトリスト"] + " / 反応をくれた人 " + kept["反応をくれた人"] + " / 猶予 " + kept["猶予"]);
  for (const c of cuts) log("  ✂ @" + c.h + " — " + c.why);

  if (DRY) {
    log("**DRY_RUN。1 件も外していない。**");
    await page.close();
    process.exit(0);
    return;
  }

  let state = {};
  try { state = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
  let done = 0;
  for (const c of cuts) {
    const h = c.h;
    try {
      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      await page.waitForTimeout(3500);
      const btn = await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        for (const b of bs) {
          const t = b.getAttribute("data-testid") || "";
          if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText || "").trim() };
        }
        for (const b of bs) {
          const x = (b.innerText || "").trim();
          if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid") || "", text: x };
        }
        return null;
      });
      if (!btn) { log("  @" + h + ": フォロー中のボタンが無い（既に外れている可能性）"); continue; }
      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
        log("  @" + h + ": 「フォロー中」ではないので押さない: " + (btn.text || btn.testid));
        continue;
      }
      await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        const t = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || "")) ||
                  bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
        if (t) t.click();
      });
      await page.waitForTimeout(1200);
      await page.evaluate(() => {
        const c2 = document.querySelector("[data-testid=confirmationSheetConfirm]");
        if (c2) c2.click();
      });
      await page.waitForTimeout(2500);
      const after = await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
        return t ? ((t.innerText || "").trim() || t.getAttribute("data-testid")) : "-";
      });
      if (FOLLOW_RE.test(after)) {
        done++;
        state[h] = { unfollowed_at: new Date().toISOString(), why: c.why, rank: c.rank };
        log("  ✂ @" + h + " — 外れた（" + c.why + "）");
      } else {
        log("  @" + h + ": 押したが外れていない（" + after + "）");
      }
      await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));
    } catch (e) {
      log("  @" + h + ": 例外 " + String(e.message).slice(0, 80));
    }
  }
  try { fs.writeFileSync(STATE, JSON.stringify(state, null, 2)); JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
  log("=== 外した: " + done + " 件 / 候補 " + cuts.length + " 件（今日のフォロー " + followedToday + " 件）===");
  await page.close();
  // **`connectOverCDP` の接続が開いたままだと node は終わらない。**
  // 2026-09-27、実作業 63 秒 のあと約 280 秒 ぶら下がって打ち切られた（rc=124）。
  // `b.close()` は利用者の Chrome に触りうるので、明示的に抜ける
  process.exit(0);
})();
JSEOF

{
echo "# 片思いの守りを緩めて DRY で確かめる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **DRY。1 件も外していない。** 一覧も取り直していない。"

echo
echo "## 1. 置き換える"
echo
echo '```'
printf '  書いたもの: %s bytes / %s 行\n' "$(wc -c < "$TMPJS" | tr -d ' ')" "$(wc -l < "$TMPJS" | tr -d ' ')"
CHK="$(node --check "$TMPJS" 2>&1)"; CRC=$?
printf '  node --check rc=%s（打つ名前: %s）\n' "$CRC" "$(basename "$TMPJS")"
[ -n "$CHK" ] && printf '%s\n' "$CHK" | cut -c1-200 | sed 's/^/  /'
echo '```'
if [ "$CRC" -ne 0 ]; then
  echo
  echo "- **構文が通らない。置かずに終わる。**"
  rm -f "$TMPJS"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
[ -f "$TARGET" ] && cp -p "$TARGET" "$TARGET.bak-$STAMP"
mv "$TMPJS" "$TARGET"
echo '```'
printf '  置いた: %s（%s 行）\n' "$(basename "$TARGET")" "$(wc -l < "$TARGET" | tr -d ' ')"
printf '  ONEWAY_IGNORE_ENGAGED %s 箇所 / process.exit(0) %s 箇所\n' \
  "$(cnt 'ONEWAY_IGNORE_ENGAGED' "$TARGET")" "$(cnt 'process.exit(0)' "$TARGET")"
printf '  page.close(); return が残っていないか: %s 箇所（0 が正）\n' "$(cnt 'page.close(); return' "$TARGET")"
echo '```'

echo
echo "## 2. DRY で判定する（**終了するかも同時に見る**）"
echo
echo "**前回は実作業 100 秒 のあとぶら下がって 260 秒 で打ち切られた。**"
echo "直っていれば、**打ち切られずに自分で終わる**。"
echo
echo '```'
T0="$(date +%s)"
MODE=decide DRY_RUN=1 DECIDE_BUDGET_S=200 MAX_PROFILE_READS=40 \
  run_limited 240 "$RUNLOG" node "$TARGET"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **まだ打ち切られている。終了バグが残っている**' || echo '← **自分で終わった**' )"
echo
tail -60 "$RUNLOG" 2>/dev/null | cut -c1-210 | clean | sed 's/^/  /'
echo '```'

echo
echo "## 3. 前回との差（**ここが答え**）"
echo
echo '```'
if [ -f "$RUNLOG" ]; then
  echo "  --- 今回 ---"
  grep -hE '片思い|相互|守った内訳|外す候補|今回の上限|プロフィールを開いた' "$RUNLOG" 2>/dev/null \
    | tail -8 | cut -c1-190 | clean | sed 's/^/    /'
else
  echo "  **ログが無い**"
fi
echo
echo "  --- 前回（2026-09-27 21:42・反応で守っていたとき）---"
echo "    片思い: 100 件 / 相互: 174 件"
echo "    守った内訳: ホワイトリスト 2 / **反応をくれた人 122** / 猶予 12"
echo "    ① 片思いから **20 件** → **外す候補 合計 21 件**（上限 30）"
echo '```'
rm -f "$RUNLOG"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §3 の「外す候補」 | 次の一手 |"
echo "| --- | --- |"
echo "| **30 件（上限に達した）** | **本番に切り替えてよい。** \`DRY_RUN\` を外し、plist を置く |"
echo "| 21〜29 件 | **まだ足りない。** 猶予（7 日）かホワイトリストが効いている。内訳を見る |"
echo "| 21 件 のまま | **緩めが効いていない。** \`ONEWAY_IGNORE_ENGAGED\` が入っているか §1 で確かめる |"
echo
echo "| §2 の rc | 意味 |"
echo "| --- | --- |"
echo "| **0** | **終了バグが直った。** 本番に回してよい |"
echo "| 124 | **まだぶら下がっている。** 本番に回すと途中で止まる |"
echo
echo "**1 件も外していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '前回との差' "$OUT" 2>/dev/null; then
  echo "片思いの守りを緩めて DRY で確かめた / $(basename "$OUT")"
else
  echo "**確かめられていない。レポートを確認すること** / $(basename "$OUT")"
fi
