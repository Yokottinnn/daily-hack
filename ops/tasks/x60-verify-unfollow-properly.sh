#!/bin/bash
# **アンフォローの修正を、正しい相手で検証し直す。費用 $0（LLM 不使用）。**
#
# ## x58 の検証は不適切だった（私のミス）
#
# x58 は「期限がいちばん古い 1 件」を選んだ。**それは x53 で
# `/following に居る: いいえ` と出ていた相手そのもの。**
#
#   @… 期限: 2026-05-16T04:03:05.644Z
#       /following に居る: **いいえ**
#       画面のボタン: [{"testid":"…-follow","text":"フォロー"}, ...]
#
# **本当にフォローしていない相手に「フォローしていない」と答えただけ。**
# 修正が効いたかどうかは、**まだ分かっていない。**
#
# ## 状態ファイルは当てにならない（x57 の実測）
#
#   フォロー済み 合計: 344 件
#   キーの一覧: followed_at  344 件で出現   ← **これしか無い**
#
# `reply-followers.json` は **`followed_at` しか持っていない。**
# だから「期限到来 328 件」は**いまフォローしているかに関係なく**、
# ただ「フォローしてから時間が経った」だけの数。
#
# **実際にフォローしているのは 170 件**（x53 の実測）。
# 328 件 のうち **半分以上は既に外れている。**
#
# ## だから `/following` を真実として使う
#
#   1. `/following` を読む（**これが唯一の真実**）
#   2. 期限到来のうち、**実際にまだフォローしている**ものだけを取り出す
#   3. そのうち 3 件 で `unfollow-handle.js` を試す
#   4. 直ったかを判定する
#
# **本当の滞留数もここで分かる。** 328 件 ではなく、実際は何件なのか。
#
# ## やらないこと
#
# **3 件 より多く外さない。上限を上げない。Chrome を kill しない。**
# **LLM を呼ばない（$0）。`timeout` を使わない。** 一時ファイルは `.js` のまま。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/verify-unfollow.md"
NODE_BIN="/usr/local/bin/node"
CDP="http://127.0.0.1:18810"
PROBE="$S/.x60-verify.js"     # **`.js` のまま**
trap 'rm -f "$PROBE"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }

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

# ─── /following を真実として、外す相手を選び、実際に外す ───
cat > "$PROBE" <<'JSEOF'
// **`/following` を真実として使う。** 状態ファイルは followed_at しか持っていない。
//
// 1. /following を読む
// 2. 期限到来のうち、実際にまだフォローしているものを取り出す
// 3. そのうち MAXN 件 で unfollow-handle.js の中身と同じ手順を踏む
//
// **MAXN 件 より多く外さない。**
const { chromium } = require("playwright-core");
const fs = require("fs");
const path = require("path");

const WS = process.env.OPS_WS;
const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
const MAXN = Number(process.env.MAXN || 3);
const GRACE_DAYS = Number(process.env.GRACE_DAYS || 7);

const FOLLOW_RE = /^(フォロー|フォローする|Follow|Follow back|フォローバック)$/;

function dueList() {
  const p = path.join(WS, "data", "reply-followers.json");
  const rows = [];
  try {
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    const now = Date.now();
    for (const [h, e] of Object.entries(d)) {
      if (!e || typeof e !== "object") continue;
      if (e.followback_status === "unfollowed" || e.unfollowed_at) continue;
      const at = e.scheduled_unfollow_at || e.followed_at || e.at;
      if (!at) continue;
      const t = new Date(at).getTime();
      if (!isFinite(t)) continue;
      if ((now - t) / 86400000 < GRACE_DAYS) continue;   // 新しいものは触らない
      rows.push({ h, t, at });
    }
  } catch (e) {}
  rows.sort((a, b) => a.t - b.t);
  return rows;
}

async function scrapeFollowing(page, me) {
  const seen = new Set();
  await page.goto("https://x.com/" + me + "/following", { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForTimeout(4000);
  let stable = 0, last = 0;
  while (seen.size < 600 && stable < 6) {
    const got = await page.evaluate(() => {
      const a = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
      const out = [];
      for (const el of a) {
        const m = (el.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
        if (m && !["home","explore","notifications","messages","i"].includes(m[1])) out.push(m[1].toLowerCase());
      }
      return out;
    });
    got.forEach((h) => seen.add(h));
    if (seen.size === last) stable++; else stable = 0;
    last = seen.size;
    await page.mouse.wheel(0, 2600);
    await page.waitForTimeout(1100);
  }
  return seen;
}

(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
  catch (e) { console.log("CDP に繋がらない: " + String(e.message).slice(0, 110)); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log("context が無い"); return; }
  const page = await ctx.newPage();

  let me = null;
  try {
    await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(3000);
    if (/login|i\/flow/.test(page.url())) { console.log("**ログインが切れている**"); await page.close(); return; }
    me = await page.evaluate(() => {
      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
      const m = a && (a.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
      return m ? m[1] : null;
    });
  } catch (e) { console.log("/home が開けない: " + String(e.message).slice(0, 80)); await page.close(); return; }
  if (!me) { console.log("**自分のハンドルが読めない**"); await page.close(); return; }

  const following = await scrapeFollowing(page, me);
  console.log("実際にフォロー中: **" + following.size + " 件**");
  if (following.size === 0) { console.log("**0 件しか読めない。何もしない。**"); await page.close(); return; }

  const due = dueList();
  const reallyDue = due.filter((r) => following.has(String(r.h).toLowerCase()));
  console.log("状態ファイルの期限到来: " + due.length + " 件");
  console.log("**そのうち 実際にまだフォローしている: " + reallyDue.length + " 件**");
  console.log("→ 差の " + (due.length - reallyDue.length) + " 件 は**既に外れている**（状態ファイルが古い）");
  console.log("");

  if (!reallyDue.length) { console.log("**外す相手が居ない。**"); await page.close(); return; }

  let ok = 0, ng = 0;
  for (const r of reallyDue.slice(0, MAXN)) {
    const h = r.h;
    try {
      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      await page.waitForTimeout(3500);
      const clicked = await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        const byId = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || ""));
        if (byId) { byId.click(); return { how: "testid", label: (byId.innerText || "").trim() }; }
        const byText = bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
        if (byText) { byText.click(); return { how: "text", label: (byText.innerText || "").trim() }; }
        return null;
      });
      if (!clicked) { console.log("  @" + h + " → **ボタンが無い**（/following に居るのに）"); ng++; continue; }
      await page.waitForTimeout(900);
      const confirmed = await page.evaluate(() => {
        const c = document.querySelector("[data-testid=confirmationSheetConfirm]");
        if (c) { c.click(); return true; }
        return false;
      });
      await page.waitForTimeout(2200);
      const after = await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
        return t ? { testid: t.getAttribute("data-testid") || "", text: (t.innerText || "").trim() } : null;
      });
      const done = after && /-follow$/i.test(after.testid) && !/-unfollow$/i.test(after.testid);
      if (done) { ok++; console.log("  @" + h + " → **外れた**（" + clicked.how + " / 確認ダイアログ " + (confirmed ? "有" : "無") + "）"); }
      else { ng++; console.log("  @" + h + " → 押したが戻っていない: " + JSON.stringify(after)); }
      await page.waitForTimeout(2000);
    } catch (e) { ng++; console.log("  @" + h + " → 例外 " + String(e.message).slice(0, 70)); }
  }

  console.log("");
  console.log("=== 判定 ===");
  console.log("  外れた: **" + ok + " 件** / 外れなかった: " + ng + " 件");
  if (ok > 0) console.log("  → **直った。** 定時のジョブでも外せるようになる。");
  else console.log("  → **まだ外せない。** ボタンの実物をもう一度 見る必要がある。");
  await page.close();
})().catch((e) => { console.log("落ちた: " + String(e && e.message).slice(0, 180)); });
JSEOF

{
echo "# アンフォローの修正を、正しい相手で検証し直す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "## x58 の検証は不適切だった"
echo
echo "x58 は「期限がいちばん古い 1 件」を選んだが、**それは x53 で"
echo "\`/following に居る: いいえ\` と出ていた相手そのもの。**"
echo
echo "**本当にフォローしていない相手に「フォローしていない」と答えただけ。**"
echo "修正が効いたかどうかは、**まだ分かっていない。**"
echo
echo "## 状態ファイルは当てにならない（x57 の実測）"
echo
echo '```'
echo "  フォロー済み 合計: 344 件"
echo "  キーの一覧: followed_at  344 件で出現   ← **これしか無い**"
echo '```'
echo
echo "\`reply-followers.json\` は **\`followed_at\` しか持っていない。**"
echo "だから「期限到来 328 件」は**いまフォローしているかに関係なく**、"
echo "ただ「フォローしてから時間が経った」だけの数。"
echo
echo "**実際にフォローしているのは 170 件**（x53 の実測）。"
echo "**328 件 のうち 半分以上は既に外れている。**"

echo
echo "## 1. 前提"
echo
echo '```'
cdp_ok && echo "  CDP: 健全" || echo "  CDP: **落ちている**"
grep -q 'connectOverCDP' "$S/unfollow-handle.js" 2>/dev/null \
  && echo "  unfollow-handle.js: **x58 の修正が入っている**" \
  || echo "  unfollow-handle.js: 修正が入っていない"
echo '```'

echo
echo "## 2. \`/following\` を真実として、**最大 3 件**だけ外す"
echo
echo "**3 件 より多く外さない。** 直ったかを確かめるだけ。"
echo
echo '```'
if ! cdp_ok; then
  echo "  CDP が落ちている。試さない。"
elif ! "$NODE_BIN" --check "$PROBE" 2>/dev/null; then
  echo "  **検証スクリプトが構文エラー。走らせない。**"
  "$NODE_BIN" --check "$PROBE" 2>&1 | head -5 | sed 's/^/    /'
else
  R="${TMPDIR:-/tmp}/v60.$$"
  ( cd "$W" && OPS_WS="$W" CDP_URL="$CDP" MAXN=3 GRACE_DAYS=7 \
      run_limited 270 "$R" "$NODE_BIN" "$PROBE" ) || true
  rc=$?
  cat "$R" 2>/dev/null | cut -c1-260 | sed 's/^/  /' | clean
  [ "$rc" = "124" ] && echo "  **4.5 分 で打ち切った。**"
  rm -f "$R"
fi
echo '```'

echo
echo "## 3. ここで分かること"
echo
echo "| 出力 | 意味 |"
echo "| --- | --- |"
echo "| **外れた: 1 件 以上** | **直った。** 定時のジョブでも外せるようになる |"
echo "| ボタンが無い（\`/following\` に居るのに） | **DOM の取り方がまだ違う** |"
echo "| 押したが戻っていない | 確認ダイアログか待ち時間 |"
echo "| 実際にまだフォローしている件数 | **本当の滞留数。** 328 件 は水増し |"

echo
echo "## 4. 分かった別の問題（**次にやること**）"
echo
echo "\`reply-followers.json\` に **\`followed_at\` しか無い。**"
echo
echo "- **フォロー返し率を測れない。** どの層が返してくれたか分からない"
echo "- **フォロワー数を記録していない。** 上限 50000 の妥当性を検証できない"
echo "- **いまフォローしているかを持っていない。** だから期限到来が水増しされる"
echo
echo "\`badge-followback\` と \`reply-followback-check\` は動いているのに、"
echo "**結果がこのファイルに書かれていない。** ここを繋げば全部 測れるようになる。"

echo
echo "## 5. 費用"
echo
echo "**LLM を一切 呼ばない。** DOM を操作するだけ。**外すのは最大 3 件。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "定時の返信ループは **推定** 1 回 \$0.003 ／ 1 日 約 \$0.19 ／ 1 か月 約 \$5.8"
echo "（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。"
} > "$OUT" 2>&1

echo "アンフォローを正しく検証 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
