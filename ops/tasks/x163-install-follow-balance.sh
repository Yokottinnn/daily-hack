#!/bin/bash
# **フォローとアンフォローの収支を合わせる係を入れる。まず DRY で確かめる。費用 $0。**
#
# ## ここまでで確定したこと
#
#   9/21  フォロー中 202 / フォロワー 283 / 相互 145 / 見た 118 → **外す候補 1**
#   9/22  フォロー中 193 / フォロワー 295 / 相互 128 / 見た  95 → **外す候補 0**
#   9/24  フォロー中 228 / フォロワー 306 / 相互 169 / 見た 135 → **外す候補 0**
#   9/25  フォロー中 249 / フォロワー 308 / 相互 173 / 見た 135 → **外す候補 0**
#
#   mutual-prune start (**dry=false** max=8 inactive=30d ratio=0.2 absMin=300 grace=14d)
#
# **止められてはいない。基準が狭すぎて候補が 0 件になっている。**
# 「格下」は `フォロワー < 自分の20% かつ < 300` ＝ **実質 58 人 未満**で、相互にほぼ居ない。
#
# **そして片思いが放置されている。** 9/25 で `249 − 173 = 76 件`。
# `mutual-prune.js` は「**相互だけを対象にする。片思いは既存の別ジョブの担当**」と
# 明記しているが、**その別ジョブは 6 本とも載っていない**（`x160`）。
#
# ## 何を入れるか
#
# `scripts/follow-balance.js` を新規に置く。**部品は `mutual-prune.js` から写す**
# （`scrapeList` / `readProfile` / `parseCount` / アンフォローの押し方）。**書き直して壊さない。**
#
#   外す順（2026-09-27 に決定）
#     ① **片思い**（フォロバが無い）  ← いま誰も担当していない。ここが最大の穴
#     ② 休眠（最終投稿が INACTIVE_DAYS より前）
#     ③ 大きいアカウント（フォロワーが BIG_FOLLOWERS 以上）
#
#   守る（2026-09-27 に決定。**この 2 つだけ**）
#     ・反応をくれた人（`reply-followers.json` に記録がある）
#     ・フォローから **7 日 未満**
#     ＋ 既存の whitelist は尊重する（消す理由が無い）
#
#   上限
#     **その日にフォローした数以上**。読めなければ `MIN_UNFOLLOW`（既定 30）
#     フォロー側は `COMPETITOR_FOLLOW_DAILY_CAP=30` で 1 日 2 回 撃つ
#
# ## このタスクは DRY で走らせる。1 件も外さない
#
# **守る側が効きすぎて候補が 0 になる**かもしれないし、**効かなすぎて全部 候補になる**
# かもしれない。**どちらも DRY の出力で分かる。** 見てから本番に切り替える。
#
# ## やらないこと
#
# **アンフォローしない（DRY）。既存のジョブを消さない。plist も置かない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
TARGET="$S/follow-balance.js"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-dry.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cat > "$TARGET.new-$STAMP" <<'JSEOF'
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

const LOG = path.join(WS, "logs", "follow-balance.log");
const STATE = path.join(WS, "data", "follow-balance-state.json");
const ENGAGED = path.join(WS, "data", "reply-followers.json");
const FOLLOWED = path.join(WS, "data", "followed.json");

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
  while (seen.size < want && stable < 6) {
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
  await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 30000 });
  await page.waitForTimeout(3500);
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
    if (/login|i\/flow/.test(page.url())) { log("**ログインが切れている。何もしない。**"); await page.close(); return; }
    me = await page.evaluate(() => {
      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
      const m = a && (a.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
      return m ? m[1] : null;
    });
  } catch (e) { log("/home を開けない: " + String(e.message).slice(0, 100)); await page.close(); return; }
  if (!me) { log("**自分のハンドルが読めない。何もしない。**"); await page.close(); return; }

  const following = await scrapeList(page, "https://x.com/" + me + "/following", 800);
  log("フォロー中: " + following.size + " 件");
  if (following.size === 0) { log("**0 件しか読めない。ページが壊れている。何もしない。**"); await page.close(); return; }
  const followers = await scrapeList(page, "https://x.com/" + me + "/followers", 1000);
  log("フォロワー: " + followers.size + " 件");

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
  const protectedWhy = (h) => {
    const k = h.toLowerCase();
    if (wl.has(k)) return "ホワイトリスト";
    if (engaged.has(k)) return "反応をくれた人";
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
    const why = protectedWhy(h);
    if (why) { noteKeep(why); continue; }
    cuts.push({ h, why: "返していない（片思い）", rank: 1 });
  }
  log("① 片思いから " + cuts.length + " 件");

  // ②③ 足りなければ相互を見る。**ここだけプロフィールを開く**
  let reads = 0;
  if (cuts.length < quota) {
    for (const h of mutual) {
      if (cuts.length >= quota || reads >= MAX_READS) break;
      const why = protectedWhy(h);
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
  log("プロフィールを開いた: " + reads + " 件 / **外す候補 合計 " + cuts.length + " 件**");
  log("守った内訳: ホワイトリスト " + kept["ホワイトリスト"] + " / 反応をくれた人 " + kept["反応をくれた人"] + " / 猶予 " + kept["猶予"]);
  for (const c of cuts) log("  ✂ @" + c.h + " — " + c.why);

  if (DRY) {
    log("**DRY_RUN。1 件も外していない。**");
    await page.close();
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
})();
JSEOF

{
echo "# 収支を合わせる係を入れて DRY で確かめる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **DRY。1 件も外していない。** 既存のジョブも消していない。plist も置いていない。"

echo
echo "## 1. 置く前の確認"
echo
echo '```'
printf '  既に在るか: %s\n' "$( [ -f "$TARGET" ] && echo 'あり（上書きする。バックアップを取る）' || echo '無い（新規）' )"
printf '  書いたもの: %s bytes\n' "$(wc -c < "$TARGET.new-$STAMP" | tr -d ' ')"
echo '```'
echo
echo "**\`node --check\` を通してから置く。** 通らなければ置かない。"
echo
echo '```'
CHK="$(node --check "$TARGET.new-$STAMP" 2>&1)"; CRC=$?
printf '  rc=%s\n' "$CRC"
[ -n "$CHK" ] && printf '%s\n' "$CHK" | sed 's/^/  /'
echo '```'
if [ "$CRC" -ne 0 ]; then
  echo
  echo "- **構文が通らない。置かずに終わる。**"
  rm -f "$TARGET.new-$STAMP"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
[ -f "$TARGET" ] && cp -p "$TARGET" "$TARGET.bak-$STAMP"
mv "$TARGET.new-$STAMP" "$TARGET"
echo
echo '```'
printf '  置いた: %s（%s 行）\n' "$(basename "$TARGET")" "$(wc -l < "$TARGET" | tr -d ' ')"
echo '```'

echo
echo "## 2. DRY で走らせる（**1 件も外さない**）"
echo
echo '```'
cd "$W" || exit 1
DRY_RUN=1 node "$TARGET" 2>&1 | tail -80 | cut -c1-220 | clean | sed 's/^/  /'
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 出方 | 次の一手 |"
echo "| --- | --- |"
echo "| 片思いから候補が**十分 出た** | **本番に切り替える**（\`DRY_RUN\` を外して plist を置く） |"
echo "| 「反応をくれた人」で**ほぼ全部 守られた** | `reply-followers.json` が広すぎる。**守る条件を絞る** |"
echo "| 片思いが**0 件** | 一覧が読めていない。`フォロー中` の件数を見る |"
echo "| フォロー中が **0 件** | ログイン切れかページの壊れ。**何もしないで正しい** |"
echo
echo "## 費用"
echo
echo "**DOM を読んで押すだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "> **量を増やしても API 課金は増えない。** フォロー側も同じく DOM 操作のみ。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'DRY_RUN。1 件も外していない' "$OUT" 2>/dev/null; then
  echo "収支を合わせる係を入れて DRY で確かめた / $(basename "$OUT")"
else
  echo "**DRY まで到達していない。レポートを確認すること** / $(basename "$OUT")"
fi
