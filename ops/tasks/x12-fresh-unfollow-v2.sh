#!/bin/bash
# **いまの条件で外すべき相手を外す（v2）。`playwright` の解決を直した。費用 $0。**
#
# ## x10 が落ちた理由
#
#   Error: Cannot find module 'playwright'
#   requireStack: [ '/Users/ny/.openclaw/workspace/[eval]' ]
#
# `cd "$W"` は効いていた（requireStack が workspace を指している）。
# だが **`playwright` は `$W/node_modules` に無い。** 既存の
# `post-via-playwright.js` は `$W/scripts/` にあり、そこから解決されている。
#
# `node -e` は **cwd から**解決するので届かない。
# **一時スクリプトを `scripts/` に置いて実行する。** 既存スクリプトと同じ経路になる。
#
# ## 判定の条件（いまの実物だけで決める。古いキューは使わない）
#
#   1. いま自分がフォローしている（`/following` をその場で読む）
#   2. その相手が自分をフォローしていない（`/followers` をその場で読む）
#   3. ホワイトリストに入っていない
#   4. フォローしてから 3 日以上 経っている
#
# ## 安全側の作り
#
#   * **1 回に外すのは 5 件まで**
#   * 押す前にボタンの文字列を読み、「フォロー中 / Following」でなければ押さない
#   * 押したあと確認ダイアログを確かめてから確定する
#   * **押す前と押した後のボタン文字列を 1 件ずつ表で記録する**
#   * `/following` が 0 件しか読めなければ何もしない
#
# **5 件を超えて外さない。フォローしない。投稿しない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/fresh-unfollow-v2.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
STATE="$W/data/reply-followers.json"
CDP="http://127.0.0.1:18810"
MAXN="${FRESH_UNFOLLOW_MAX:-5}"
GRACE_DAYS=3
TMPJS="$S/.x12-fresh-unfollow.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

cleanup() { rm -f "$TMPJS"; }
trap cleanup EXIT

{
echo "# いまの条件で外すべき相手を外す v2（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> \`x10\` は \`playwright\` が \`MODULE_NOT_FOUND\` で落ちた。"
echo "> \`cd \$W\` は効いていたが、**\`playwright\` は \`\$W/node_modules\` に無い。**"
echo "> 既存の \`post-via-playwright.js\` は \`scripts/\` にあり、そこから解決されている。"
echo "> **一時スクリプトを \`scripts/\` に置いて実行する。**"
echo
echo "判定は 4 つ全部を満たすものだけ（**古いキューは使わない**）。"
echo
echo "1. いま自分がフォローしている"
echo "2. その相手が自分をフォローしていない"
echo "3. ホワイトリストに入っていない"
echo "4. フォローしてから **${GRACE_DAYS} 日以上** 経っている"
echo
echo "**1 回に外すのは ${MAXN} 件まで。**"

echo
echo "## 実行"
echo
echo '```'
cat > "$TMPJS" <<'XJSEOF'
const { chromium } = require("playwright");
const fs = require("fs");

const CDP = process.argv[2];
const MAXN = Number(process.argv[3]);
const GRACE = Number(process.argv[4]);
const STATE = process.argv[5];
const WS = process.argv[6];

const FOLLOWING_RE = /^(フォロー中|Following)$/;
const FOLLOW_RE = /^(フォロー|フォローする|Follow|Follow back|フォローバック)$/;

function loadWhitelist() {
  const out = new Set();
  for (const p of ["data/unfollow-whitelist.json", "data/whitelist.json"]) {
    try {
      const d = JSON.parse(fs.readFileSync(WS + "/" + p, "utf8"));
      const arr = Array.isArray(d) ? d : (d.handles || d.whitelist || Object.keys(d));
      for (const h of arr) out.add(String(h).replace(/^@/, "").toLowerCase());
    } catch (e) {}
  }
  return out;
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
        if (m && !["home","explore","notifications","messages","i"].includes(m[1])) out.push(m[1]);
      }
      return out;
    });
    got.forEach(h => seen.add(h));
    if (seen.size === last) stable++; else stable = 0;
    last = seen.size;
    await page.mouse.wheel(0, 2600);
    await page.waitForTimeout(1200);
  }
  return seen;
}

(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
  catch (e) { console.log("  CDP に繋がらない: " + e.message.slice(0,120)); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log("  context が無い"); return; }
  const page = await ctx.newPage();

  // 自分のハンドルを確かめる
  let me = null;
  try {
    await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(3000);
    if (/login|i\/flow/.test(page.url())) { console.log("  **ログインが切れている。何もしない。**"); await page.close(); return; }
    me = await page.evaluate(() => {
      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
      const m = a && (a.getAttribute("href")||"").match(/^\/([^/?#]+)$/);
      return m ? m[1] : null;
    });
  } catch (e) { console.log("  /home を開けない: " + e.message.slice(0,100)); await page.close(); return; }
  if (!me) { console.log("  **自分のハンドルが読めない。何もしない。**"); await page.close(); return; }
  console.log("  ログイン: 生きている");

  console.log("  /following を読む…");
  const following = await scrapeList(page, `https://x.com/${me}/following`, 400);
  console.log("  フォロー中: " + following.size + " 件");

  console.log("  /followers を読む…");
  const followers = await scrapeList(page, `https://x.com/${me}/followers`, 600);
  console.log("  フォロワー: " + followers.size + " 件");

  if (following.size === 0) { console.log("  **フォロー中が 0 件。読めていない。何もしない。**"); await page.close(); return; }

  const wl = loadWhitelist();
  console.log("  ホワイトリスト: " + wl.size + " 件");

  let state = {};
  try { state = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}
  const followedAt = {};
  for (const [h, e] of Object.entries(state)) if (e && e.followed_at) followedAt[h.toLowerCase()] = e.followed_at;

  const lowerFollowers = new Set([...followers].map(h => h.toLowerCase()));
  const now = Date.now();
  const cands = [];
  for (const h of following) {
    const k = h.toLowerCase();
    if (lowerFollowers.has(k)) continue;            // 相互
    if (wl.has(k)) continue;                        // ホワイトリスト
    const fa = followedAt[k];
    if (fa) {
      const days = (now - new Date(fa).getTime()) / 86400000;
      if (days < GRACE) continue;                   // まだ猶予中
    }
    cands.push(h);
  }
  console.log("");
  console.log("  **片思い（こちらだけフォロー）: " + cands.length + " 件**");
  console.log("  今回 外す: " + Math.min(cands.length, MAXN) + " 件");
  console.log("");

  let done = 0;
  const results = [];
  for (const h of cands.slice(0, MAXN)) {
    let before = "-", after = "-", note = "";
    try {
      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      await page.waitForTimeout(3500);
      const btn = await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        for (const b of bs) {
          const t = (b.getAttribute("data-testid") || "");
          if (/-unfollow$|^unfollow/i.test(t)) return { testid: t, text: (b.innerText||"").trim() };
        }
        for (const b of bs) {
          const x = (b.innerText || "").trim();
          if (/^(フォロー中|Following)$/.test(x)) return { testid: b.getAttribute("data-testid")||"", text: x };
        }
        return null;
      });
      if (!btn) { note = "フォロー中のボタンが無い（既に外れている可能性）"; results.push([h, before, after, note]); continue; }
      before = btn.text || btn.testid;
      if (!FOLLOWING_RE.test(btn.text) && !/-unfollow$|^unfollow/i.test(btn.testid)) {
        note = "「フォロー中」ではないので押さない: " + before;
        results.push([h, before, after, note]); continue;
      }
      // 押す
      await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        const t = bs.find(b => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid")||"")) ||
                  bs.find(b => /^(フォロー中|Following)$/.test((b.innerText||"").trim()));
        if (t) t.click();
      });
      await page.waitForTimeout(1200);
      // 確認ダイアログ
      const confirmed = await page.evaluate(() => {
        const c = document.querySelector("[data-testid=confirmationSheetConfirm]");
        if (c) { c.click(); return true; }
        return false;
      });
      note = confirmed ? "確認ダイアログを確定した" : "確認ダイアログが出なかった";
      await page.waitForTimeout(2500);
      after = await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        const t = bs.find(b => /-(un)?follow$/i.test(b.getAttribute("data-testid")||""));
        return t ? ((t.innerText||"").trim() || t.getAttribute("data-testid")) : "-";
      });
      if (FOLLOW_RE.test(after)) {
        done++;
        const k = Object.keys(state).find(x => x.toLowerCase() === h.toLowerCase());
        if (k) { state[k].followback_status = "unfollowed"; state[k].unfollowed_at = new Date().toISOString(); state[k].scheduled_unfollow_at = null; }
        note += " / **外れた**";
      } else {
        note += " / 外れていない";
      }
    } catch (e) { note = "例外: " + e.message.slice(0, 90); }
    results.push([h, before, after, note]);
  }

  try {
    fs.writeFileSync(STATE + ".tmp", JSON.stringify(state, null, 2));
    fs.renameSync(STATE + ".tmp", STATE);
  } catch (e) { console.log("  状態ファイルに書き戻せない: " + e.message.slice(0,80)); }

  console.log("  | 相手 | 押す前 | 押した後 | 備考 |");
  console.log("  | --- | --- | --- | --- |");
  for (const [h, b0, a0, n] of results) console.log("  | @" + h + " | " + b0 + " | " + a0 + " | " + n + " |");
  console.log("");
  console.log("  **今回 外した数: " + done + " 件**");
  await page.close().catch(()=>{});
})();
XJSEOF
if [ ! -s "$TMPJS" ]; then echo "  一時スクリプトを置けない"; exit 1; fi
"$NODE_BIN" --check "$TMPJS" 2>&1 | head -3 | clean || { echo "  一時スクリプトの構文が通らない"; exit 1; }
( cd "$S" && "$NODE_BIN" "$TMPJS" "$CDP" "$MAXN" "$GRACE_DAYS" "$STATE" "$W" ) 2>&1 | clean
echo "(rc=$?)"
echo '```'

echo
echo "---"
echo
echo "**${MAXN} 件を超えて外していない。フォローも投稿もしていない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
N="$(grep -oE '今回 外した数: [0-9]+ 件' "$OUT" 2>/dev/null | tail -1 | grep -oE '[0-9]+' || echo 0)"
if [ "${N:-0}" -gt 0 ] 2>/dev/null; then
  echo "**いまの条件で ${N} 件 外した（\$0）** / $(basename "$OUT")"
else
  echo "**0 件だった。押す前後のボタン文字列をレポートに出した** / $(basename "$OUT")"
fi
