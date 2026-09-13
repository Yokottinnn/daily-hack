#!/bin/bash
# **アンフォローを直す。x17 で実際に外せた取り方に合わせる。最大 5 分・費用 $0。**
#
# ## 実物を読んで分かったこと（x56・2026-09-13）
#
#   const { openWorkTab } = require("./lib/work-window.js");   // ← 専用ウィンドウ
#   const _w = await openWorkTab("unfollow");
#   await page.goto(..., { waitUntil: "commit", timeout: 25000 });
#   await page.waitForTimeout(4000);
#   const unfollowBtn = await page.$('[data-testid$="-unfollow"]');
#   ...
#   await browser.close();
#
# **セレクタ `[data-testid$="-unfollow"]` は正しい。**
# x53 が同じ相手のプロフィールで `2040770556531011584-unfollow` の実在を確認している。
#
# ## 疑うのは 3 つ
#
#   ① **`openWorkTab` が別コンテキスト**（＝未ログイン）
#      x53 は `connectOverCDP` → `contexts()[0]` → `newPage()` で**見つけた。**
#      同じページ・同じ瞬間で、片方は見つけ、片方は見つけない。**取り方の差**が濃厚。
#
#   ② **`waitUntil: "commit"` は描画前**
#      `commit` はナビゲーションが確定した瞬間で、**DOM はまだ無い。**
#      x17 は `domcontentloaded` ＋ 3.5 秒 で外せた。**commit ＋ 4 秒 より後**。
#
#   ③ **`browser.close()`**
#      CDP で繋いだブラウザに対して呼ぶと、**Chrome ごと落ちうる。**
#      「勝手にブラウザが消える」の一因かもしれない。**外す。**
#
# ## 直し方（**x17 の実証済みの形にそろえる**）
#
#   - `connectOverCDP` → `contexts()[0]` → `newPage()`
#   - `waitUntil: "domcontentloaded"` ＋ 3.5 秒
#   - `[data-testid$="-unfollow"]` が無ければ**「フォロー中」の文字でも探す**
#   - 確認ダイアログを確定する（ここは元のままで正しい）
#   - **`browser.close()` を呼ばない。** `page.close()` だけ
#
# **判定ロジックも出力の JSON も変えない。** 呼び出し側はそのまま動く。
#
# ## 安全弁
#
#   - `.bak-<日時>` に退避。`node --check` が通らなければその場で戻す
#   - **試すのは 1 件だけ。** 直ったかを確かめるだけで、大量に外さない
#   - 期限到来は 322 件 あるが、**上限は今のまま（1 回 5 件）**
#
# ## やらないこと
#
# **Chrome を kill しない。上限を上げない。LLM を呼ばない（$0）。**
# **`timeout` を使わない**（macOS に無い）。一時ファイルは `.js` のまま。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-unfollow-handle.md"
NODE_BIN="/usr/local/bin/node"
F="$S/unfollow-handle.js"
TMPJS="$S/.unfollow-handle-install.js"   # **`.js` のまま**
STAMP="$(date '+%Y%m%d-%H%M%S')"
trap 'rm -f "$TMPJS"' EXIT

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

# ─── 差し替える本体。**出力の JSON は元と同じ形を保つ** ───
cat > "$TMPJS" <<'JSEOF'
#!/usr/bin/env node
// unfollow-handle.js — Unfollow a single X handle via CDP.
// Usage: node unfollow-handle.js <handle>
// Output: JSON {ok, status: unfollowed/not_following/unconfirmed/error, reason?}
//
// 2026-09-13: **x17 で実際に外せた取り方にそろえた。**
//
// 直したのは 3 つだけ。判定も出力の JSON も変えていない。
//
//   ① work-window ではなく `contexts()[0]` を使う
//      x53 で、同じ相手のプロフィールに `…-unfollow` が在ることを確認済み。
//      それでも「no unfollow button」になっていた＝**取り方の差**。
//      専用ウィンドウが別コンテキスト（未ログイン）だと、ボタンは出ない。
//
//   ② `waitUntil: "commit"` → `"domcontentloaded"`
//      `commit` はナビゲーション確定の瞬間で、**DOM はまだ無い。**
//      4 秒 待っても、描画が間に合わなければ空振りする。
//
//   ③ `browser.close()` を呼ばない
//      CDP で繋いだブラウザに対して呼ぶと **Chrome ごと落ちうる。**
//      閉じるのは自分が開いたタブだけ。
//
// あわせて、`…-unfollow` が取れないときは**「フォロー中」の文字でも探す**。
// 描画の揺れで data-testid が間に合わないことがあるため。
const { chromium } = require("playwright-core");
const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";

const FOLLOWING_RE = /^(フォロー中|Following)$/;

async function main() {
  const handle = process.argv[2];
  if (!handle) {
    console.log(JSON.stringify({ ok: false, error: "missing handle" }));
    process.exit(1);
  }

  let browser, page;
  try {
    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
  } catch (e) {
    console.log(JSON.stringify({ ok: false, status: "error", reason: "cdp: " + e.message }));
    return;
  }
  const ctx = browser.contexts()[0];
  if (!ctx) {
    console.log(JSON.stringify({ ok: false, status: "error", reason: "no context" }));
    return;
  }

  try {
    page = await ctx.newPage();
    await page.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(3500);

    // ログインが切れていれば、ボタンが無いのは当然。**「未フォロー」と混同しない。**
    if (/login|i\/flow/.test(page.url())) {
      console.log(JSON.stringify({ ok: false, status: "error", reason: "logged out" }));
      return;
    }

    // ① data-testid ② 「フォロー中」の文字、の順に探す
    let clicked = await page.evaluate(() => {
      const bs = Array.from(document.querySelectorAll("button,[role=button]"));
      const byId = bs.find((b) => /-unfollow$|^unfollow/i.test(b.getAttribute("data-testid") || ""));
      if (byId) { byId.click(); return { how: "testid", label: (byId.innerText || "").trim() }; }
      const byText = bs.find((b) => /^(フォロー中|Following)$/.test((b.innerText || "").trim()));
      if (byText) { byText.click(); return { how: "text", label: (byText.innerText || "").trim() }; }
      return null;
    });

    if (!clicked) {
      console.log(JSON.stringify({ ok: false, status: "not_following", reason: "no unfollow button" }));
      return;
    }

    await page.waitForTimeout(900);
    const confirm = await page
      .waitForSelector('[data-testid="confirmationSheetConfirm"]', { state: "visible", timeout: 4000 })
      .catch(() => null);
    if (confirm) {
      await confirm.click();
      await page.waitForTimeout(1500);
    }

    // **外れたか。** 「フォロー」に戻っていれば外れている
    const after = await page.evaluate(() => {
      const bs = Array.from(document.querySelectorAll("button,[role=button]"));
      const t = bs.find((b) => /-(un)?follow$/i.test(b.getAttribute("data-testid") || ""));
      return t ? { testid: t.getAttribute("data-testid") || "", text: (t.innerText || "").trim() } : null;
    });
    if (after && /-follow$/i.test(after.testid) && !/-unfollow$/i.test(after.testid)) {
      console.log(JSON.stringify({ ok: true, status: "unfollowed", how: clicked.how }));
    } else {
      console.log(JSON.stringify({
        ok: false, status: "unconfirmed",
        reason: "no follow button visible after unfollow",
        after: after || null, how: clicked.how,
      }));
    }
  } catch (e) {
    console.log(JSON.stringify({ ok: false, status: "error", reason: e.message }));
  } finally {
    // **`browser.close()` を呼ばない。** 自分の開いたタブだけ閉じる
    if (page) await page.close().catch(() => {});
  }
}

main();
JSEOF

{
echo "# アンフォローを直す（x17 で外せた取り方にそろえる）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x53 の判定: **B. フォロー中なのに外せていない。**"
echo "> ボタンは在る（\`2040770556531011584-unfollow\` ／「フォロー中」）。"
echo "> **セレクタは正しい。取り方が違う。**"

# ═══════════ 0. 前提 ═══════════
echo
echo "## 0. 前提"
echo
echo '```'
cdp_ok && echo "  CDP: 健全" || echo "  CDP: **落ちている**"
[ -f "$F" ] && echo "  unfollow-handle.js: 在る（$(wc -l < "$F" | tr -d ' ') 行）" || echo "  unfollow-handle.js: **無い**"
grep -q 'connectOverCDP' "$F" 2>/dev/null && echo "  既に直っている（connectOverCDP を使っている）" || echo "  まだ work-window を使っている"
echo '```'

# ═══════════ 1. work-window の中身 ═══════════
echo
echo "## 1. \`lib/work-window.js\` は何をしていたのか"
echo
echo "**ここが別コンテキスト（未ログイン）なら、ボタンが出ないのは当然。**"
echo
echo '```javascript'
WW="$S/lib/work-window.js"
if [ -f "$WW" ]; then
  echo "// $(wc -l < "$WW" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$WW" 2>/dev/null)"
  head -60 "$WW" | clean
else
  echo "// **$WW が無い**"
  ls -1 "$S/lib" 2>/dev/null | head -10 | sed 's/^/\/\/   /'
fi
echo '```'

# ═══════════ 2. 差し替える ═══════════
echo
echo "## 2. \`unfollow-handle.js\` を差し替える"
echo
echo "**直したのは 3 つだけ。判定も出力の JSON も変えていない。**"
echo
echo "| 直したところ | 理由 |"
echo "| --- | --- |"
echo "| work-window → \`contexts()[0]\` | x53 はこの取り方で**ボタンを見つけた** |"
echo "| \`commit\` → \`domcontentloaded\` | \`commit\` は**DOM がまだ無い**瞬間 |"
echo "| \`browser.close()\` を呼ばない | CDP 接続に対して呼ぶと **Chrome ごと落ちうる** |"
echo
echo "あわせて、\`…-unfollow\` が取れないときは**「フォロー中」の文字でも探す。**"
echo "ログインが切れているときは \`error\` にする（**「未フォロー」と混同しない**）。"
echo
echo '```'
if [ ! -f "$F" ]; then
  echo "  **対象が無い。何もしない。**"
elif ! "$NODE_BIN" --check "$TMPJS" 2>/dev/null; then
  echo "  **差し替える中身が構文エラー。置かない。**"
  "$NODE_BIN" --check "$TMPJS" 2>&1 | head -5 | sed 's/^/    /'
else
  echo "  差し替える中身の node --check: OK（$(wc -l < "$TMPJS" | tr -d ' ') 行）"
  cp "$F" "$F.bak-$STAMP" && echo "  退避: $(basename "$F").bak-$STAMP"
  mv "$TMPJS" "$F" && chmod +x "$F"
  if "$NODE_BIN" --check "$F" 2>/dev/null; then
    echo "  対象の node --check: OK"
    echo "  --- 差し替えた後 ---"
    grep -nE 'connectOverCDP|domcontentloaded|browser.close|contexts\(\)' "$F" 2>/dev/null \
      | head -6 | cut -c1-130 | sed 's/^/    /'
  else
    echo "  **構文エラーになった。戻す。**"
    cp "$F.bak-$STAMP" "$F"
  fi
fi
echo '```'

# ═══════════ 3. 1 件だけ試す ═══════════
echo
echo "## 3. **1 件だけ**試して、直ったか確かめる"
echo
echo "**大量に外さない。** 直ったかを確かめるだけ。上限は今のまま。"
echo
echo '```'
if ! grep -q 'connectOverCDP' "$F" 2>/dev/null; then
  echo "  差し替わっていない。試さない。"
elif ! cdp_ok; then
  echo "  CDP が落ちている。試さない。"
else
  H="$("$NODE_BIN" -e '
const fs=require("fs"),path=require("path");
const p=path.join(process.env.HOME,".openclaw","workspace","data","reply-followers.json");
try{
  const d=JSON.parse(fs.readFileSync(p,"utf8"));
  const rows=[];
  for(const [h,e] of Object.entries(d)){
    if(!e||typeof e!=="object") continue;
    if(e.followback_status==="unfollowed"||e.unfollowed_at) continue;
    const at=e.scheduled_unfollow_at||e.followed_at||e.at; if(!at) continue;
    const t=new Date(at).getTime(); if(!isFinite(t)) continue;
    rows.push({h,t});
  }
  rows.sort((a,b)=>a.t-b.t);
  console.log(rows.length?rows[0].h:"");
}catch(e){ console.log(""); }' 2>/dev/null)"
  if [ -z "$H" ]; then
    echo "  **期限到来の相手が読めない。試さない。**"
  else
    echo "  対象: 期限がいちばん古い 1 件（ハンドルは伏せる）"
    R="${TMPDIR:-/tmp}/uf58.$$"
    ( cd "$S" && run_limited 90 "$R" "$NODE_BIN" "$F" "$H" ) || true
    rc=$?
    echo "  --- 結果 ---"
    cat "$R" 2>/dev/null | cut -c1-300 | sed 's/^/    /' | clean
    [ "$rc" = "124" ] && echo "    **90 秒 で打ち切った。**"
    rm -f "$R"
    echo
    echo "  **\`\"status\":\"unfollowed\"\` なら直った。**"
    echo "  \`\"not_following\"\` のままなら、原因は取り方ではない。"
    echo "  \`\"logged out\"\` なら認証。\`\"unconfirmed\"\` なら押せたが戻っていない。"
  fi
fi
echo '```'

# ═══════════ 4. 滞留の数 ═══════════
echo
echo "## 4. 滞留している数（**直れば減り始める**）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const now=Date.now(); let due=0, old=0, oldest=null;
  for(const [h,x] of Object.entries(d)){
    if(!x||typeof x!=="object") continue;
    if(x.followback_status==="unfollowed"||x.unfollowed_at) continue;
    const at=x.scheduled_unfollow_at||x.followed_at||x.at; if(!at) continue;
    const t=new Date(at).getTime(); if(!isFinite(t)) continue;
    due++; if((now-t)/86400000>=30) old++;
    if(oldest===null||t<oldest) oldest=t;
  }
  console.log("  期限到来: "+due+" 件（30 日以上 放置が "+old+" 件）");
  if(oldest) console.log("  いちばん古い: "+new Date(oldest).toISOString().slice(0,10));
}catch(e){ console.log("  読めない"); }
' "$D/reply-followers.json" 2>&1 | clean
echo
echo "  09-12 の x09 時点: 197 件 → 09-13 の x53 時点: 322 件"
echo "  **外せていないので積み上がっている。**"
echo '```'

echo
echo "## 5. 費用"
echo
echo "**LLM を一切 呼ばない。** DOM を操作するだけ。**外すのは 1 件だけ。**"
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

echo "アンフォローを直す / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
