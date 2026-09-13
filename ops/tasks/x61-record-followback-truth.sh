#!/bin/bash
# **測れるようにする。フォロー返し・フォロワー数・いまの実態を記録する。費用 $0。**
#
# ## 分かったこと（x57 の実測・2026-09-13）
#
#   フォロー済み 合計: 344 件 / 返してくれた: 0 件
#   キーの一覧: followed_at  344 件で出現   ← **これしか無い**
#
# `reply-followers.json` は **`followed_at` しか持っていない。** だから、
#
#   - **フォロー返し率を測れない**（どの層が返してくれたか分からない）
#   - **フォロワー数を記録していない**（上限 50000 の妥当性を検証できない）
#   - **いまフォローしているかを持っていない**（期限到来が水増しされる）
#
# 実際、期限到来は **328 件** だが、**実際にフォローしているのは 170 件**（x53）。
# **半分以上は既に外れているのに、外そうとして失敗し続けていた。**
#
# ## 3 つを 1 本にする理由
#
# **どれも同じファイル（`reply-followers.json`）に書く。**
# 分けると、後のタスクが前のタスクの書き込みを上書きする。
#
# ## やること
#
#   1. `/following` と `/followers` を読む（**これが唯一の真実**）
#   2. 各エントリに 3 つを足す
#        `still_following`  … いまもフォローしているか
#        `follows_back`     … 相手がこちらをフォローしているか
#        `checked_at`       … いつ確かめたか
#   3. 既に外れているものに `unfollowed_at` を入れる（**水増しを消す**）
#   4. 集計を出す（フォロー返し率・本当の滞留数）
#
# **フォロワー数の記録は、ここでは入れない。**
# 1 件ずつプロフィールを開くと 344 件 で 20 分 かかり、ルール 15 に反する。
# **フォローする瞬間に記録するのが正しい。** それは次のタスクで生成側に入れる。
#
# ## 安全弁
#
#   - **`.bak-<日時>` に退避。** JSON が壊れたら戻す
#   - **既存のキーを消さない。** 足すだけ
#   - `/following` が 0 件 で読めたら**何もしない**（ページが壊れている合図）
#   - **フォローもアンフォローもしない。** 読んで記録するだけ
#
# ## やらないこと
#
# **投稿しない。フォローしない。アンフォローしない。上限を触らない。**
# **LLM を呼ばない（$0）。`timeout` を使わない。** 一時ファイルは `.js` のまま。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/record-followback.md"
NODE_BIN="/usr/local/bin/node"
CDP="http://127.0.0.1:18810"
RF="$D/reply-followers.json"
PROBE="$S/.x61-record.js"     # **`.js` のまま**
STAMP="$(date '+%Y%m%d-%H%M%S')"
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

cat > "$PROBE" <<'JSEOF'
// `/following` と `/followers` を真実として、状態ファイルに実態を記録する。
//
// **フォローもアンフォローもしない。読んで書くだけ。**
//
// 足すキー:
//   still_following  いまもフォローしているか
//   follows_back     相手がこちらをフォローしているか
//   checked_at       いつ確かめたか
//
// 既に外れているものには unfollowed_at を入れて、期限到来の水増しを消す。
// **既存のキーは消さない。**
const { chromium } = require("playwright-core");
const fs = require("fs");
const path = require("path");

const WS = process.env.OPS_WS;
const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
const RF = path.join(WS, "data", "reply-followers.json");

async function scrapeList(page, url, want) {
  const seen = new Set();
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForTimeout(4000);
  let stable = 0, last = 0;
  while (seen.size < want && stable < 7) {
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
    if (/login|i\/flow/.test(page.url())) { console.log("**ログインが切れている。何もしない。**"); await page.close(); return; }
    me = await page.evaluate(() => {
      const a = document.querySelector("[data-testid=AppTabBar_Profile_Link]");
      const m = a && (a.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
      return m ? m[1] : null;
    });
  } catch (e) { console.log("/home が開けない: " + String(e.message).slice(0, 80)); await page.close(); return; }
  if (!me) { console.log("**自分のハンドルが読めない。何もしない。**"); await page.close(); return; }

  const following = await scrapeList(page, "https://x.com/" + me + "/following", 600);
  console.log("いまフォロー中 : **" + following.size + " 件**");
  if (following.size === 0) { console.log("**0 件しか読めない。書かずに終わる。**"); await page.close(); return; }

  const followers = await scrapeList(page, "https://x.com/" + me + "/followers", 900);
  console.log("いまフォロワー : **" + followers.size + " 件**");
  await page.close();

  let d;
  try { d = JSON.parse(fs.readFileSync(RF, "utf8")); }
  catch (e) { console.log("**状態ファイルが読めない: " + String(e.message).slice(0, 70) + "**"); return; }

  const now = new Date().toISOString();
  let total = 0, stillF = 0, back = 0, gone = 0, markedGone = 0;
  for (const [h, e] of Object.entries(d)) {
    if (!e || typeof e !== "object") continue;
    total++;
    const k = String(h).toLowerCase();
    const sf = following.has(k);
    const fb = followers.has(k);
    e.still_following = sf;
    e.follows_back = fb;
    e.checked_at = now;
    if (sf) stillF++;
    if (fb) back++;
    if (!sf) {
      gone++;
      // **既に外れているものに印を付け、期限到来の水増しを消す**
      if (!e.unfollowed_at) { e.unfollowed_at = now; e.unfollow_source = "reconciled"; markedGone++; }
    }
  }

  try { fs.writeFileSync(RF, JSON.stringify(d, null, 2)); }
  catch (e) { console.log("**書けない: " + String(e.message).slice(0, 70) + "**"); return; }

  console.log("");
  console.log("=== 記録した ===");
  console.log("  状態ファイルの件数        : " + total + " 件");
  console.log("  いまもフォローしている    : **" + stillF + " 件**");
  console.log("  既に外れている            : " + gone + " 件（うち **" + markedGone + " 件** に印を付けた）");
  console.log("  相手がこちらをフォロー    : **" + back + " 件**");
  const rate = total ? Math.round(back / total * 1000) / 10 : 0;
  console.log("  **フォロー返し率: " + rate + "%**（" + back + " / " + total + "）");
  console.log("");
  console.log("  ※ この返し率は「状態ファイルに載っている相手のうち、いま相互の割合」。");
  console.log("     フォローした直後は返ってこないので、**低めに出る。**");
})().catch((e) => { console.log("落ちた: " + String(e && e.message).slice(0, 180)); });
JSEOF

{
echo "# 測れるようにする（フォロー返し・実態の記録）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`reply-followers.json\` は **\`followed_at\` しか持っていない。**"
echo "> だからフォロー返し率も、いまフォローしているかも分からない。"
echo ">"
echo "> 期限到来は **328 件** だが、**実際にフォローしているのは 170 件**。"
echo "> **半分以上は既に外れているのに、外そうとして失敗し続けていた。**"
echo
echo "**フォローもアンフォローもしない。読んで記録するだけ。**"

echo
echo "## 0. 前提"
echo
echo '```'
cdp_ok && echo "  CDP: 健全" || echo "  CDP: **落ちている**"
[ -f "$RF" ] && echo "  reply-followers.json: 在る（$(stat -f '%z' "$RF" 2>/dev/null) bytes）" || echo "  reply-followers.json: **無い**"
echo "  いまのキー:"
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const keys=new Map(); let i=0;
  for(const e of Object.values(d)){ if(!e||typeof e!=="object")continue;
    for(const k of Object.keys(e)) keys.set(k,(keys.get(k)||0)+1);
    if(++i>=500) break; }
  for(const [k,n] of [...keys].sort((a,b)=>b[1]-a[1])) console.log("    "+k.padEnd(22)+n+" 件");
}catch(e){ console.log("    読めない"); }' "$RF" 2>&1 | clean
echo '```'

echo
echo "## 1. \`/following\` と \`/followers\` を読んで記録する"
echo
echo "| 足すキー | 意味 |"
echo "| --- | --- |"
echo "| \`still_following\` | **いまもフォローしているか** |"
echo "| \`follows_back\` | **相手がこちらをフォローしているか** |"
echo "| \`checked_at\` | いつ確かめたか |"
echo
echo "既に外れているものには \`unfollowed_at\` を入れて、**期限到来の水増しを消す。**"
echo "**既存のキーは消さない。足すだけ。**"
echo
echo '```'
if [ ! -f "$RF" ]; then
  echo "  **状態ファイルが無い。何もしない。**"
elif ! cdp_ok; then
  echo "  CDP が落ちている。**何もしない。**"
elif ! "$NODE_BIN" --check "$PROBE" 2>/dev/null; then
  echo "  **スクリプトが構文エラー。走らせない。**"
  "$NODE_BIN" --check "$PROBE" 2>&1 | head -5 | sed 's/^/    /'
else
  cp "$RF" "$RF.bak-$STAMP" && echo "  退避: $(basename "$RF").bak-$STAMP"
  R="${TMPDIR:-/tmp}/rec61.$$"
  ( cd "$W" && OPS_WS="$W" CDP_URL="$CDP" run_limited 270 "$R" "$NODE_BIN" "$PROBE" ) || true
  rc=$?
  cat "$R" 2>/dev/null | cut -c1-240 | sed 's/^/  /' | clean
  [ "$rc" = "124" ] && echo "  **4.5 分 で打ち切った。**"
  rm -f "$R"
  echo
  if "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$RF" 2>/dev/null; then
    echo "  JSON: OK"
  else
    echo "  **JSON が壊れた。戻す。**"
    cp "$RF.bak-$STAMP" "$RF"
  fi
fi
echo '```'

echo
echo "## 2. 記録した後のキー"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const keys=new Map(); let i=0;
  for(const e of Object.values(d)){ if(!e||typeof e!=="object")continue;
    for(const k of Object.keys(e)) keys.set(k,(keys.get(k)||0)+1);
    if(++i>=1000) break; }
  for(const [k,n] of [...keys].sort((a,b)=>b[1]-a[1])) console.log("  "+k.padEnd(22)+n+" 件");
}catch(e){ console.log("  読めない"); }' "$RF" 2>&1 | clean
echo '```'

echo
echo "## 3. 本当の滞留数（**水増しを消した後**）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const now=Date.now(); let due=0, old=0;
  for(const [h,x] of Object.entries(d)){
    if(!x||typeof x!=="object") continue;
    if(x.followback_status==="unfollowed"||x.unfollowed_at) continue;
    const at=x.scheduled_unfollow_at||x.followed_at||x.at; if(!at) continue;
    const t=new Date(at).getTime(); if(!isFinite(t)) continue;
    due++; if((now-t)/86400000>=30) old++;
  }
  console.log("  期限到来: **"+due+" 件**（30 日以上 放置が "+old+" 件）");
}catch(e){ console.log("  読めない"); }' "$RF" 2>&1 | clean
echo
echo "  **前: 328 件**（いまフォローしているかを見ていなかった）"
echo '```'

echo
echo "## 4. 次にやること（**このタスクでは触らない**）"
echo
echo "**フォロワー数の記録は、ここでは入れていない。**"
echo "1 件ずつプロフィールを開くと 344 件 で 20 分 かかり、ルール 15 に反する。"
echo
echo "**フォローする瞬間に記録するのが正しい。**"
echo "\`competitor-follower-follow\` と \`hashtag-follow\` は、**弾くときに"
echo "フォロワー数を読んでいる**（\`out of range (67000\` と出せている）。"
echo "**通したときにも同じ数字を書けば、帯ごとの返し率が出せる。**"

echo
echo "## 5. 費用"
echo
echo "**LLM を一切 呼ばない。** DOM を読んで JSON に書くだけ。"
echo "**フォローもアンフォローもしない。**"
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

echo "フォロー返しを記録する / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
