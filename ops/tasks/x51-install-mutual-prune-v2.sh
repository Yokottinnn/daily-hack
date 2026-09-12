#!/bin/bash
# **相互フォローでも「休眠」「格下」なら そっと外すジョブを常駐化する。費用 $0（LLM 不使用）。**
#
# ## x46 が失敗した理由（2026-09-13 の実測）
#
#   TypeError [ERR_UNKNOWN_FILE_EXTENSION]: Unknown file extension ".new"
#     for /Users/ny/.openclaw/workspace/scripts/mutual-prune.js.new
#
# **一時ファイルを `mutual-prune.js.new` という名前にしていた。**
# Mac の Node v24 は拡張子を見て弾く。クラウドの v22 は通していた。
# **`mutual-prune.js` は 1 行も設置されていない。**
#
# 直したのは 2 つだけ。
#   - 一時ファイルを `.mutual-prune-install.js`（**`.js` のまま**）にする
#   - `timeout` を使わない（**macOS に timeout は無い**）
#
# 判定条件・安全弁・上限は **x46 から 1 つも変えていない。**
#
# > フォロワー数をどんどん増やしていきたいので、お互いにフォローしている場合でも、
# > 相手のアカウントがあまり活動していない場合（急に投稿をやめたとか）とか、
# > 自分のアカウントと比べた時に大したことない場合にはそっとアンフォローする
# > ジョブを常駐化してほしい。
#
# ## 既存のものを先に確認した
#
# `auto_detect_and_unfollow_inactive.js` は**既にある**が、`x24` で
# 「大量アンフォロー」として**意図的に復帰対象から外していた**。
# 中身が読めていないものを載せ直すのは危ないので、**別名で新しく作る。**
# 判定条件が読めて、上限が効いていることを確かめられる形にする。
#
# ## 実装は x17 の実証済みパターンを使う
#
#   const { chromium } = require("playwright-core");   ← `playwright` ではない
#   chromium.connectOverCDP("http://127.0.0.1:18810")
#
# フォロー一覧のスクレイプ・アンフォローボタンの押し方・確認ダイアログの確定は、
# **x17 で実際に動いたコードをそのまま使う。** 書き直して壊さない。
#
# ## 外す条件（**どちらか 1 つでも満たせば候補**）
#
#   ① 休眠  … 最終投稿が INACTIVE_DAYS 日 より前（既定 30 日）
#   ② 格下  … 相手のフォロワー数が
#              「自分のフォロワー数 × RATIO」未満（既定 0.20）**かつ**
#              ABS_MIN 未満（既定 300）
#
# **② に「かつ」を入れているのが肝。** 比率だけだと、自分が伸びるほど
# 基準が上がって優良アカウントまで切ってしまう。**絶対値でも歯止めをかける。**
#
# ## 外さない条件（**1 つでも当たれば見送る**）
#
#   - ホワイトリストに居る（`data/unfollow-whitelist.json` / `data/mutual-prune-whitelist.json`）
#   - フォローしてから GRACE_DAYS 日 未満（既定 14 日）＝ 様子見の期間
#   - プロフィールが読めなかった（**読めない ＝ 悪いではない**）
#   - 最終投稿の日付が取れなかった
#   - 認証済み（青バッジ）
#
# ## 安全弁
#
#   - **1 回に外すのは MAX_UNFOLLOW 件まで**（既定 8）。12 時間ごとなので 1 日 最大 16 件
#   - `/following` が 0 件で読めたら**何もしない**（ページが壊れている合図）
#   - ログインが切れていたら**何もしない**
#   - **`RunAtLoad` は false。** 載せた直後には走らない。
#     最初の自動実行は 12 時間後なので、**判定を見てから調整する余地がある**
#   - このタスク自身の実行は **DRY_RUN。1 件も外さない。** 誰をどの理由で外すかだけ出す
#
# ## 費用
#
# **LLM を一切 呼ばない。** DOM を読むだけ。
#
#   1 回あたり: **$0**
#   1 日あたり: **$0**（12 時間ごと ＝ 2 回）
#   1 か月あたり: **$0**
#
# API 課金が発生するのは返信の生成だけで、このジョブはそこに触れない。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/mutual-prune-install.md"
NODE_BIN="/usr/local/bin/node"
CDP="http://127.0.0.1:18810"
UID_NUM="$(id -u)"
LABEL="ai.openclaw.mutual-prune"
JS="$S/mutual-prune.js"
TMPJS="$S/.mutual-prune-install.js"   # `.js` のまま。`.new` は node --check が弾く
PLIST="$LA/$LABEL.plist"
LOG="$W/logs/mutual-prune.log"
STATE="$D/mutual-prune-state.json"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(AKIA|ghp_|xoxb-)[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }

# ─── 本体。引用符つきヒアドキュメント＝シェルは中身を解釈しない ───
cat > "$TMPJS" <<'JSEOF'
// 相互フォローでも「休眠」「格下」なら そっと外す。
//
// 2026-09-13 作成。LLM を呼ばない（DOM を読むだけ）ので API 課金は $0。
//
// **x17 で実際に動いたコードをそのまま使っている。** 書き直して壊さない。
//   - playwright-core（`playwright` はこのワークスペースに存在しない）
//   - connectOverCDP で既存の Chrome に繋ぐ（新しく起動しない）
//   - アンフォローは data-testid の *-unfollow を押し、確認ダイアログを確定する
//
// 環境変数で調整する（既定値は安全側）:
//   DRY_RUN=1          1 件も外さず、判定だけ出す
//   MAX_UNFOLLOW=8     1 回に外す上限
//   INACTIVE_DAYS=30   最終投稿がこれより前なら「休眠」
//   RATIO=0.20         自分のフォロワー数に対する比率。これ未満なら「格下」候補
//   ABS_MIN=300        かつ、この絶対値 未満のときだけ「格下」と判定する
//   GRACE_DAYS=14      フォローしてからこの日数 未満は触らない
const { chromium } = require("playwright-core");
const fs = require("fs");
const path = require("path");

const WS = process.env.OPS_WS || path.join(process.env.HOME || "", ".openclaw", "workspace");
const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
const DRY = process.env.DRY_RUN === "1";
const MAXN = Number(process.env.MAX_UNFOLLOW || 8);
const INACTIVE_DAYS = Number(process.env.INACTIVE_DAYS || 30);
const RATIO = Number(process.env.RATIO || 0.20);
const ABS_MIN = Number(process.env.ABS_MIN || 300);
const GRACE_DAYS = Number(process.env.GRACE_DAYS || 14);

const LOG = path.join(WS, "logs", "mutual-prune.log");
const STATE = path.join(WS, "data", "mutual-prune-state.json");
const FOLLOW_STATE = path.join(WS, "data", "reply-followers.json");

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

// 「1,234」「12.3K」「1.2万」を数値にする。読めなければ null。
// **読めないものを 0 とみなさない。** 0 にすると全員「格下」になる。
function parseCount(s) {
  if (!s) return null;
  const t = String(s).replace(/[\s,]/g, "");
  let m = t.match(/([0-9]+(?:\.[0-9]+)?)(万|億|K|M|k|m)?/);
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

// プロフィールから「フォロワー数」「最終投稿日時」「認証済みか」を読む。
// **読めなかった項目は null を返す。推測で埋めない。**
async function readProfile(page, handle) {
  await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 30000 });
  await page.waitForTimeout(3500);
  return await page.evaluate(() => {
    const res = { followersText: null, lastPost: null, verified: false, protected: false };
    const a = document.querySelector('a[href$="/verified_followers"]') ||
              document.querySelector('a[href$="/followers"]');
    if (a) res.followersText = (a.innerText || "").trim();
    // 固定ツイートが混ざるので**最新の 1 件**を取る
    const ts = Array.from(document.querySelectorAll("article time[datetime]"))
      .map((t) => t.getAttribute("datetime")).filter(Boolean);
    if (ts.length) {
      const ms = ts.map((x) => new Date(x).getTime()).filter((n) => isFinite(n) && n > 0);
      if (ms.length) res.lastPost = new Date(Math.max.apply(null, ms)).toISOString();
    }
    res.verified = !!document.querySelector('[data-testid="UserName"] svg[aria-label]');
    res.protected = !!document.querySelector('[data-testid="UserName"] svg[aria-label*="鍵"]');
    return res;
  });
}

(async () => {
  log("=== mutual-prune start (dry=" + DRY + " max=" + MAXN + " inactive=" + INACTIVE_DAYS +
      "d ratio=" + RATIO + " absMin=" + ABS_MIN + " grace=" + GRACE_DAYS + "d) ===");

  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
  catch (e) { log("CDP に繋がらない: " + String(e.message).slice(0, 120)); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { log("context が無い。何もしない。"); return; }
  const page = await ctx.newPage();

  let me = null, myFollowers = null;
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

  // 自分のフォロワー数。**読めなければ「格下」判定を丸ごと使わない。**
  try {
    const mine = await readProfile(page, me);
    myFollowers = parseCount(mine.followersText);
  } catch (e) {}
  log("自分: @" + me + " / フォロワー " + (myFollowers === null ? "読めない" : myFollowers));

  const following = await scrapeList(page, "https://x.com/" + me + "/following", 400);
  log("フォロー中: " + following.size + " 件");
  if (following.size === 0) { log("**0 件しか読めない。ページが壊れている。何もしない。**"); await page.close(); return; }

  const followers = await scrapeList(page, "https://x.com/" + me + "/followers", 600);
  log("フォロワー: " + followers.size + " 件");

  const wl = loadWhitelist();
  log("ホワイトリスト: " + wl.size + " 件");

  // フォローした日時。猶予の判定に使う
  const followedAt = {};
  for (const p of [FOLLOW_STATE, STATE]) {
    try {
      const d = JSON.parse(fs.readFileSync(p, "utf8"));
      for (const [h, e] of Object.entries(d)) {
        if (e && (e.followed_at || e.at)) followedAt[h.toLowerCase()] = e.followed_at || e.at;
      }
    } catch (e) {}
  }

  const lowerFollowers = new Set([...followers].map((h) => h.toLowerCase()));
  const now = Date.now();

  // **相互だけを対象にする。** 片思いは既存の別ジョブの担当。
  const mutual = [...following].filter((h) => lowerFollowers.has(h.toLowerCase()));
  log("相互フォロー: " + mutual.length + " 件");

  let state = {};
  try { state = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch (e) {}

  const decided = [];
  let looked = 0;
  for (const h of mutual) {
    if (decided.filter((d) => d.cut).length >= MAXN) break;
    const k = h.toLowerCase();
    if (wl.has(k)) { decided.push({ h, cut: false, why: "ホワイトリスト" }); continue; }
    const fa = followedAt[k];
    if (fa) {
      const days = (now - new Date(fa).getTime()) / 86400000;
      if (isFinite(days) && days < GRACE_DAYS) {
        decided.push({ h, cut: false, why: "フォローしてまだ " + Math.floor(days) + " 日（猶予 " + GRACE_DAYS + " 日）" });
        continue;
      }
    }

    let p;
    try { p = await readProfile(page, h); looked++; }
    catch (e) { decided.push({ h, cut: false, why: "プロフィールが開けない: " + String(e.message).slice(0, 50) }); continue; }

    if (p.verified) { decided.push({ h, cut: false, why: "認証済み" }); continue; }

    const fc = parseCount(p.followersText);
    if (fc === null) { decided.push({ h, cut: false, why: "フォロワー数が読めない（読めない＝悪いではない）" }); continue; }
    if (!p.lastPost) { decided.push({ h, cut: false, why: "最終投稿が読めない（読めない＝悪いではない）" }); continue; }

    const idle = Math.floor((now - new Date(p.lastPost).getTime()) / 86400000);
    const reasons = [];
    if (idle >= INACTIVE_DAYS) reasons.push("休眠 " + idle + " 日");
    if (myFollowers !== null && fc < myFollowers * RATIO && fc < ABS_MIN) {
      reasons.push("格下 " + fc + " < min(" + Math.round(myFollowers * RATIO) + ", " + ABS_MIN + ")");
    }

    if (!reasons.length) { decided.push({ h, cut: false, why: "残す（" + fc + " フォロワー / " + idle + " 日前に投稿）" }); continue; }
    decided.push({ h, cut: true, why: reasons.join(" ＋ "), followers: fc, idle: idle });
  }

  const cuts = decided.filter((d) => d.cut);
  log("見たプロフィール: " + looked + " 件 / **外す候補: " + cuts.length + " 件**");
  for (const d of decided) {
    log("  " + (d.cut ? "✂ " : "・ ") + "@" + d.h + " — " + d.why);
  }

  if (DRY) {
    log("**DRY_RUN。1 件も外していない。**");
    await page.close();
    return;
  }

  let done = 0;
  for (const d of cuts.slice(0, MAXN)) {
    const h = d.h;
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
        const c = document.querySelector("[data-testid=confirmationSheetConfirm]");
        if (c) c.click();
      });
      await page.waitForTimeout(2500);
      const after = await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
        return t ? ((t.innerText || "").trim() || t.getAttribute("data-testid")) : "-";
      });
      if (FOLLOW_RE.test(after)) {
        done++;
        state[h] = { unfollowed_at: new Date().toISOString(), why: d.why, followers: d.followers, idle_days: d.idle };
        log("  ✂ @" + h + " — 外れた（" + d.why + "）");
      } else {
        log("  @" + h + ": 押したが外れていない（" + after + "）");
      }
      await page.waitForTimeout(2000 + Math.floor(Math.random() * 2000));
    } catch (e) { log("  @" + h + ": 例外 " + String(e.message).slice(0, 90)); }
  }

  try { fs.writeFileSync(STATE, JSON.stringify(state, null, 2)); } catch (e) {}
  log("=== mutual-prune done: " + done + " 件 外した ===");
  await page.close();
})().catch((e) => { log("落ちた: " + String(e && e.message).slice(0, 200)); });
JSEOF

{
echo "# 相互でも「休眠・格下」なら そっと外すジョブを常駐化"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> フォロワー数をどんどん増やしていきたいので、お互いにフォローしている場合でも、"
echo "> 相手のアカウントがあまり活動していない場合とか、自分のアカウントと比べた時に"
echo "> 大したことない場合にはそっとアンフォローするジョブを常駐化してほしい。"
echo
echo "**このタスクの実行は DRY_RUN。1 件も外さない。** 誰をどの理由で外すかだけ出す。"
echo "常駐ジョブは載せるが **\`RunAtLoad\` は false**。最初の自動実行は 12 時間後。"

# ═══════════ 0. 前提 ═══════════
echo
echo "## 0. 前提"
echo
echo '```'
cdp_ok && echo "  CDP: 健全" || echo "  CDP: **落ちている**"
[ -f /tmp/x-login-in-progress ] && echo "  login ロック: **在る**" || echo "  login ロック: 無い"
if [ -d "$W/node_modules/playwright-core" ]; then echo "  playwright-core: 在る"
else echo "  playwright-core: **無い**"; ls -1 "$W/node_modules" 2>/dev/null | grep -i playwright | sed 's/^/    /'; fi
echo "  既存の同種ジョブ:"
for j in auto-detect-and-unfollow-inactive reply-followers-cleanup revenge-unfollow; do
  L="ai.openclaw.$j"
  if launchctl list 2>/dev/null | grep -qF "$L"; then echo "    $j: ロード済み"
  elif [ -f "$LA/$L.plist" ]; then echo "    $j: plist はあるが未ロード"
  else echo "    $j: plist 無し"; fi
done
echo '```'

# ═══════════ 1. 本体を置く ═══════════
echo
echo "## 1. \`mutual-prune.js\` を置く"
echo
echo "**x17 で実際に動いたコードをそのまま使う。** \`playwright-core\` ／ \`connectOverCDP\` ／"
echo "\`data-testid\` の \`*-unfollow\` を押して確認ダイアログを確定する流れは書き直さない。"
echo
echo '```'
if ! "$NODE_BIN" --check "$TMPJS" 2>/dev/null; then
  echo "  **構文エラー。置かない。**"
  "$NODE_BIN" --check "$TMPJS" 2>&1 | head -5 | sed 's/^/    /'
  rm -f "$TMPJS"
  echo '```'
  exit 1
fi
echo "  node --check: OK（$(wc -l < "$TMPJS" | tr -d ' ') 行）"
[ -f "$JS" ] && cp "$JS" "$JS.bak-$STAMP" && echo "  既存を退避: $(basename "$JS").bak-$STAMP"
mv "$TMPJS" "$JS" && chmod +x "$JS"
echo "  置いた: $JS"
echo '```'

# ═══════════ 2. 判定条件 ═══════════
echo
echo "## 2. 判定条件（**既定値は安全側**）"
echo
echo "### 外す（どちらか 1 つでも満たせば候補）"
echo
echo "| 条件 | 既定 | 意味 |"
echo "| --- | --- | --- |"
echo "| ① 休眠 | \`INACTIVE_DAYS=30\` | 最終投稿が 30 日 より前 |"
echo "| ② 格下 | \`RATIO=0.20\` **かつ** \`ABS_MIN=300\` | 自分の 20% 未満 **かつ** 300 未満 |"
echo
echo "**② に「かつ」を入れているのが肝。** 比率だけだと、自分が伸びるほど基準が上がって"
echo "優良アカウントまで切ってしまう。**絶対値でも歯止めをかける。**"
echo
echo "### 外さない（1 つでも当たれば見送る）"
echo
echo "- ホワイトリストに居る（\`data/mutual-prune-whitelist.json\` / \`data/unfollow-whitelist.json\`）"
echo "- フォローしてから **14 日 未満**（\`GRACE_DAYS\`）＝ 様子見の期間"
echo "- **認証済み（青バッジ）**"
echo "- **フォロワー数が読めない** ／ **最終投稿が読めない**"
echo "  （**読めない ＝ 悪い、ではない。** 読めないものを 0 とみなすと全員 格下になる）"
echo
echo "### 安全弁"
echo
echo "- 1 回に外すのは **8 件**まで（\`MAX_UNFOLLOW\`）。12 時間ごとなので **1 日 最大 16 件**"
echo "- \`/following\` が **0 件**で読めたら何もしない（ページが壊れている合図）"
echo "- **ログインが切れていたら何もしない**"

# ═══════════ 3. 常駐化 ═══════════
echo
echo "## 3. launchd に載せる（12 時間ごと・\`RunAtLoad\` は false）"
echo
echo '```xml'
[ -f "$PLIST" ] && cp -p "$PLIST" "$PLIST.bak-$STAMP"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_BIN</string>
    <string>$JS</string>
  </array>
  <key>StartInterval</key><integer>43200</integer>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$W/logs/mutual-prune.out</string>
  <key>StandardErrorPath</key><string>$W/logs/mutual-prune.err</string>
  <key>WorkingDirectory</key><string>$W</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
    <key>OPS_WS</key><string>$W</string>
    <key>CDP_URL</key><string>$CDP</string>
    <key>MAX_UNFOLLOW</key><string>8</string>
    <key>INACTIVE_DAYS</key><string>30</string>
    <key>RATIO</key><string>0.20</string>
    <key>ABS_MIN</key><string>300</string>
    <key>GRACE_DAYS</key><string>14</string>
  </dict>
</dict>
</plist>
PLISTEOF
cat "$PLIST" | clean
echo '```'
echo
echo '```'
if plutil -lint "$PLIST" >/dev/null 2>&1; then
  echo "  plutil -lint: OK"
  launchctl bootout "gui/${UID_NUM}/$LABEL" >/dev/null 2>&1 || true
  launchctl enable "gui/${UID_NUM}/$LABEL" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/${UID_NUM}" "$PLIST" 2>&1 | head -3 | sed 's/^/    /' | clean
  sleep 3
  SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"
  if printf '%s\n' "$SNAP" | grep -qxF "$LABEL"; then
    echo "  **載った（\`launchctl list\` に出た）** ← 最上位ルール 13: rc は見ない"
  else
    echo "  **載っていない。**"
    launchctl print "gui/${UID_NUM}/$LABEL" 2>&1 | head -6 | sed 's/^/    /' | clean
  fi
else
  echo "  **plist が壊れている。ロードしない。**"
  [ -f "$PLIST.bak-$STAMP" ] && cp -p "$PLIST.bak-$STAMP" "$PLIST"
fi
echo '```'

# ═══════════ 4. DRY_RUN で判定を見る ═══════════
echo
echo "## 4. **DRY_RUN で 1 回 走らせる（1 件も外さない）**"
echo
echo "誰をどの理由で外すかだけ出す。**ここを見てから、しきい値を決める。**"
echo
echo '```'
if ! cdp_ok; then
  echo "  CDP が落ちている。走らせない。"
elif [ -f /tmp/x-login-in-progress ]; then
  echo "  login ロックが在る。走らせない。"
else
  ( cd "$W" && DRY_RUN=1 MAX_UNFOLLOW=8 INACTIVE_DAYS=30 RATIO=0.20 ABS_MIN=300 GRACE_DAYS=14 \
      OPS_WS="$W" CDP_URL="$CDP" "$NODE_BIN" "$JS" ) 2>&1 \
    | tail -60 | cut -c1-240 | sed 's/^/  /' | clean
fi
echo '```'

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**LLM を一切 呼ばない。** DOM を読むだけ。"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり（12 時間ごと ＝ 2 回） | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "API 課金が発生するのは返信の生成だけで、このジョブはそこに触れない。"
echo
echo "## 6. 本番にするには"
echo
echo "plist の \`EnvironmentVariables\` に \`DRY_RUN\` は入れていないので、"
echo "**次の自動実行（12 時間後）から実際に外す。**"
echo "止めたいときは次のどちらか。"
echo
echo '```'
echo "  launchctl bootout gui/\$(id -u)/$LABEL       # ジョブごと止める"
echo "  # または plist の EnvironmentVariables に DRY_RUN=1 を足して載せ直す"
echo '```'
} > "$OUT" 2>&1

echo "mutual-prune を常駐化 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
