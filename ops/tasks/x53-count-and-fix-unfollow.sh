#!/bin/bash
# **本日の実数を数える ＋ アンフォローが外せない理由を確定する ＋ フォローの追いかけ先を見る。**
# 費用 **$0**（LLM を一切 呼ばない。DOM を読むだけ。ボタンは押さない）。
#
# ## 動いたことの確認は済んでいる（2026-09-13 10:08 JST の heartbeat）
#
#   "x_jobs":     {"loaded": 8, "expected": 8, "missing": []}
#   "last_reply": {"at": "2026-09-12T18:06:31.876Z", "age_hours": 7, "stale": false}
#   "supervisor": {"ran":8,"total":9,"not_run":["mutual-prune"]}
#
# **返信は 03:06 JST に出ている**（75 時間の停止から復帰）。
# **次は「何件 出たか」を一次情報で数える。**
#
# ## ① アンフォローが 0 件 なのはなぜか
#
#   due 197 → 上限 5 件に絞る
#   @…: unfollow failed (no unfollow button)   × 5 件 **全部**
#   期限到来 197 件 ／ うち **30 日以上 放置が 164 件** ／ いちばん古い期限 2026-05-20
#
# **x09 で調べようとしたが、`playwright`（`-core` ではない）で落ちて答えが出ていない。**
# 今回は `playwright-core` で開く。候補は 2 つ。
#
#   A. **そもそも既にフォローしていない。** 状態ファイルが古く、
#      画面には「フォローする」しか無い（＝ボタンが無いのは正しい挙動）
#   B. **X の DOM が変わってセレクタが効かない**
#
# **`/following` の実物と突き合わせれば、どちらか分かる。**
# A なら状態ファイルの掃除、B ならセレクタの修正。**直す前に確定させる。**
#
# ## ② フォロー 2 本の追いかけ先
#
# 復帰はしたが、**候補のフォロワー数が 3〜7 人 で全部 弾かれる**問題は残っている。
#
#   ❌ follower count out of range (6, need 10-50000)
#
# **下限は下げない。** フォロワー 3 人 を追っても返りはほぼ無い。
# **追いかけ先の一覧がいつのものか**、**候補の分布がどうなっているか**を見る。
#
# ## やらないこと
#
# **ボタンを押さない。アンフォローしない。フォローしない。投稿しない。**
# **状態ファイルを書き換えない。しきい値を触らない。Chrome を kill しない。**
# **`timeout` を使わない**（macOS に無い・最上位ルール 14）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/count-and-fix-unfollow.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$D/post_queue.json"
CDP="http://127.0.0.1:18810"
PROBE="$S/.x53-probe.js"     # **拡張子は .js のまま**（node --check が .new を弾く）
trap 'rm -f "$PROBE"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(AKIA|ghp_|xoxb-)[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }

# timeout を使わない打ち切り（最上位ルール 14）
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

# ─── 調べるだけのスクリプト。**押さない。** ───
cat > "$PROBE" <<'JSEOF'
// アンフォローが外せない理由を確定する。**ボタンは押さない。**
//
// A. そもそも既にフォローしていない  → 画面に「フォローする」しか無い
// B. DOM が変わってセレクタが効かない → 「フォロー中」が在るのに掴めていない
//
// `/following` の実物と突き合わせれば、どちらか分かる。
const { chromium } = require("playwright-core");   // **playwright ではない**
const fs = require("fs");
const path = require("path");

const WS = process.env.OPS_WS;
const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
const N = Number(process.env.PROBE_N || 4);

function dueHandles() {
  // 期限到来のうち、古い順に N 件
  for (const f of ["reply-followers.json", "followed.json"]) {
    try {
      const d = JSON.parse(fs.readFileSync(path.join(WS, "data", f), "utf8"));
      const rows = [];
      for (const [h, e] of Object.entries(d)) {
        if (!e || typeof e !== "object") continue;
        if (e.followback_status === "unfollowed" || e.unfollowed_at) continue;
        const at = e.scheduled_unfollow_at || e.followed_at || e.at;
        if (!at) continue;
        const t = new Date(at).getTime();
        if (isFinite(t)) rows.push({ h, t, at });
      }
      if (rows.length) { rows.sort((a, b) => a.t - b.t); return rows.slice(0, N); }
    } catch (e) {}
  }
  return [];
}

(async () => {
  const due = dueHandles();
  console.log("期限到来の古い順 " + due.length + " 件を見る");
  if (!due.length) { console.log("**対象が読めない。** 状態ファイルの形が想定と違う"); return; }

  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
  catch (e) { console.log("CDP に繋がらない: " + String(e.message).slice(0, 120)); return; }
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
  } catch (e) { console.log("/home を開けない: " + String(e.message).slice(0, 90)); await page.close(); return; }
  console.log("ログイン: 生きている（@" + me + "）");

  // 実際にフォローしている一覧
  const following = new Set();
  try {
    await page.goto("https://x.com/" + me + "/following", { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForTimeout(4000);
    let stable = 0, last = 0;
    while (following.size < 400 && stable < 6) {
      const got = await page.evaluate(() => {
        const a = Array.from(document.querySelectorAll("[data-testid=UserCell] a[href^=\"/\"]"));
        const out = [];
        for (const el of a) {
          const m = (el.getAttribute("href") || "").match(/^\/([^/?#]+)$/);
          if (m && !["home","explore","notifications","messages","i"].includes(m[1])) out.push(m[1].toLowerCase());
        }
        return out;
      });
      got.forEach((h) => following.add(h));
      if (following.size === last) stable++; else stable = 0;
      last = following.size;
      await page.mouse.wheel(0, 2600);
      await page.waitForTimeout(1200);
    }
  } catch (e) { console.log("/following が読めない: " + String(e.message).slice(0, 90)); }
  console.log("実際にフォロー中: " + following.size + " 件");
  if (following.size === 0) { console.log("**0 件しか読めない。判定できない。**"); await page.close(); return; }

  let inList = 0, notInList = 0;
  for (const row of due) {
    const h = row.h;
    const isFollowing = following.has(String(h).toLowerCase());
    isFollowing ? inList++ : notInList++;
    let btn = null;
    try {
      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      await page.waitForTimeout(3500);
      btn = await page.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        const found = [];
        for (const b of bs) {
          const t = b.getAttribute("data-testid") || "";
          const x = (b.innerText || "").trim();
          if (/follow/i.test(t) || /^(フォロー中|Following|フォロー|フォローする|Follow)$/.test(x)) {
            found.push({ testid: t, text: x });
          }
        }
        return found.slice(0, 3);
      });
    } catch (e) { btn = [{ testid: "例外", text: String(e.message).slice(0, 50) }]; }
    console.log("");
    console.log("  @" + h);
    console.log("    期限: " + row.at);
    console.log("    /following に居る: " + (isFollowing ? "**はい**" : "**いいえ**"));
    console.log("    画面のボタン: " + (btn && btn.length ? JSON.stringify(btn) : "**見つからない**"));
  }

  console.log("");
  console.log("=== 判定 ===");
  console.log("  /following に居る: " + inList + " 件 / 居ない: " + notInList + " 件");
  if (notInList > inList) {
    console.log("  → **A. 状態ファイルが古い。** 既に外れている相手を外そうとしている。");
    console.log("     直すのはセレクタではなく**状態ファイルの掃除**。");
  } else if (inList > 0) {
    console.log("  → **B. フォロー中なのに外せていない。** 上のボタンの実物を見て");
    console.log("     セレクタを合わせる（`Following` / `フォロー中` が在るか）。");
  }
  await page.close();
})().catch((e) => { console.log("落ちた: " + String(e && e.message).slice(0, 200)); });
JSEOF

{
echo "# 本日の実数 ＋ アンフォローが外せない理由 ＋ 追いかけ先"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "**ボタンを押さない。アンフォローもフォローもしない。LLM を呼ばない（\$0）。**"

# ═══════════ 1. 本日の実数 ═══════════
echo
echo "## 1. 本日の実数（**一次情報だけ**）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const t=new Date(Date.now()+9*3600*1000).toISOString().slice(0,10);
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
  const today=rows.filter(e=>{const d=new Date(e.posted_at||e.created_at||0);
    return !isNaN(d) && new Date(d.getTime()+9*3600*1000).toISOString().slice(0,10)===t;});
  console.log("  返信 累計      : "+rows.length+" 件");
  console.log("  返信 本日("+t+"): **"+today.length+" 件**");
  const last=rows[rows.length-1];
  if(last) console.log("  最後の 1 件    : "+(last.posted_at||last.created_at));
  console.log("");
  console.log("  --- 本日 出た返信 ---");
  today.forEach(e=>{
    console.log("    "+(e.posted_at||e.created_at)+"  https://x.com/heng_ji31590/status/"+(e.x_tweet_id||e.tweet_id));
  });
}catch(e){ console.log("  **キューが読めない**"); }
' "$QJSON" 2>&1 | clean
echo '```'
echo
echo '```'
echo "  --- 状態ファイル（フォロー関連） ---"
for f in reply-followers.json followed.json mutual-prune-state.json; do
  P="$D/$f"; [ -f "$P" ] || { printf '  %-26s 無し\n' "$f"; continue; }
  CNT="$("$NODE_BIN" -e '
const fs=require("fs");
try{ const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  if(Array.isArray(d)) console.log(d.length);
  else {const a=Object.values(d).find(v=>Array.isArray(v));console.log(a?a.length:Object.keys(d).length);}
}catch(e){ console.log("読めない"); }' "$P" 2>/dev/null)"
  printf '  %-26s %6s 件 / 最終更新 %s\n' "$f" "$CNT" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
done
echo
echo "  --- 本日 動いたジョブ（ログに今日の行が在るか） ---"
TODAY="$(date '+%Y-%m-%d')"
for L in comment-warmup competitor-follower-follow hashtag-follow badge-followback \
         reply-followback-check reply-followers-cleanup incoming-reply-watcher \
         pipeline-heartbeat daily-supervisor mutual-prune; do
  F="$W/logs/$L.log"
  if [ ! -f "$F" ]; then printf '  %-28s ログ無し\n' "$L"; continue; fi
  if grep -aq "$TODAY" "$F" 2>/dev/null; then
    printf '  %-28s **本日 動いた** / 最終更新 %s\n' "$L" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$F" 2>/dev/null)"
  else
    printf '  %-28s 本日は無し      / 最終更新 %s\n' "$L" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$F" 2>/dev/null)"
  fi
done
echo '```'

# ═══════════ 2. アンフォローの理由を確定 ═══════════
echo
echo "## 2. アンフォローが外せない理由を確定する（**押さない**）"
echo
echo "x09 は \`playwright\`（\`-core\` ではない）で落ちて答えが出ていない。**今回は \`playwright-core\`。**"
echo
echo "| 候補 | 見分け方 |"
echo "| --- | --- |"
echo "| **A. 状態ファイルが古い** | 期限到来の相手が **\`/following\` に居ない** |"
echo "| **B. セレクタが古い** | \`/following\` に**居るのに**「フォロー中」を掴めていない |"
echo
echo '```'
if ! cdp_ok; then
  echo "  CDP が落ちている。判定できない。"
elif [ ! -d "$W/node_modules/playwright-core" ]; then
  echo "  **playwright-core が無い。**"
  ls -1 "$W/node_modules" 2>/dev/null | grep -i playwright | sed 's/^/    /'
elif ! "$NODE_BIN" --check "$PROBE" 2>/dev/null; then
  echo "  **調査スクリプトが構文エラー。走らせない。**"
  "$NODE_BIN" --check "$PROBE" 2>&1 | head -5 | sed 's/^/    /'
else
  R="${TMPDIR:-/tmp}/probe.$$"
  ( cd "$W" && OPS_WS="$W" CDP_URL="$CDP" PROBE_N=4 run_limited 420 "$R" "$NODE_BIN" "$PROBE" ) || true
  rc=$?
  cat "$R" 2>/dev/null | cut -c1-260 | sed 's/^/  /' | clean
  [ "$rc" = "124" ] && echo "  **7 分 で打ち切った。**"
  rm -f "$R"
fi
echo '```'
echo
echo '```'
echo "  --- 期限到来の古さ（状態ファイルから） ---"
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
try{
  const d=JSON.parse(fs.readFileSync(p,"utf8"));
  const now=Date.now(); const b={a:0,b:0,c:0,e:0}; let oldest=null, due=0;
  for(const [h,x] of Object.entries(d)){
    if(!x||typeof x!=="object") continue;
    if(x.followback_status==="unfollowed"||x.unfollowed_at) continue;
    const at=x.scheduled_unfollow_at||x.followed_at||x.at; if(!at) continue;
    const t=new Date(at).getTime(); if(!isFinite(t)) continue;
    due++; const days=(now-t)/86400000;
    if(days<7)b.a++; else if(days<14)b.b++; else if(days<30)b.c++; else b.e++;
    if(oldest===null||t<oldest) oldest=t;
  }
  console.log("    期限到来: "+due+" 件");
  console.log("      0〜6日   "+b.a+" 件");
  console.log("      7〜13日  "+b.b+" 件");
  console.log("      14〜29日 "+b.c+" 件");
  console.log("      30日以上 "+b.e+" 件");
  if(oldest) console.log("    いちばん古い: "+new Date(oldest).toISOString().slice(0,10));
}catch(e){ console.log("    読めない"); }
' "$D/reply-followers.json" 2>&1 | clean
echo '```'

# ═══════════ 3. フォローの追いかけ先 ═══════════
echo
echo "## 3. フォロー 2 本の追いかけ先（**下限は下げない**）"
echo
echo "復帰はしたが、**候補のフォロワー数が 3〜7 人 で全部 弾かれる**問題は残っている。"
echo "フォロワー 3 人 を追っても返りはほぼ無い。**追いかけ先が古くないか**を見る。"
echo
echo '```'
echo "  --- 追いかけ先の一覧ファイル ---"
for f in target-config.json targets.json competitors.json competitor-accounts.json \
         hashtags.json hashtag-targets.json follow-targets.json; do
  P="$D/$f"; [ -f "$P" ] || continue
  CNT="$("$NODE_BIN" -e '
const fs=require("fs");
try{ const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  if(Array.isArray(d)) console.log(d.length);
  else {const a=Object.values(d).find(v=>Array.isArray(v));console.log(a?a.length:Object.keys(d).length);}
}catch(e){ console.log("読めない"); }' "$P" 2>/dev/null)"
  printf '  %-28s %5s 件 / 最終更新 %s\n' "$f" "$CNT" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
done
echo
echo "  --- data/ で follow / target を含むファイル ---"
ls -1 "$D" 2>/dev/null | grep -iE 'follow|target|hashtag|competitor' | head -15 | sed 's/^/    /'
echo '```'
echo
echo '```'
echo "  --- 弾かれた候補のフォロワー数の分布（直近のログ全体） ---"
for L in competitor-follower-follow hashtag-follow; do
  F="$W/logs/$L.log"
  [ -f "$F" ] || continue
  echo "  [$L]"
  grep -aoE 'out of range \([0-9]+' "$F" 2>/dev/null | grep -oE '[0-9]+' \
    | awk '{ if($1<10) a++; else if($1<100) b++; else if($1<1000) c++; else d++ }
           END { printf "    10 未満: %d 件 / 10〜99: %d 件 / 100〜999: %d 件 / 1000 以上: %d 件\n", a,b,c,d }'
  echo "    直近 12 件の実数: $(grep -aoE 'out of range \([0-9]+' "$F" 2>/dev/null | grep -oE '[0-9]+' | tail -12 | tr '\n' ' ')"
  echo "    本日 フォローできた数: $(grep -ac 'followed\|✅' "$F" 2>/dev/null | tr -dc '0-9') 件（ログ由来・**一次情報ではない**）"
done
echo '```'

echo
echo "## 4. 費用"
echo
echo "**LLM を一切 呼ばない。DOM を読むだけ。ボタンを押さない。**"
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

echo "本日の実数とアンフォローの原因 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
