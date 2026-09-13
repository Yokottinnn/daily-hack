#!/bin/bash
# **フォロワー数 0 の正体を見る ＋ フォロー返し率をフォロワー帯ごとに測る。費用 $0。**
#
# ## なぜ（2026-09-13 の x53 実測）
#
#   competitor-follower-follow: 10未満 347 件 / 1000以上 298 件
#   hashtag-follow:             10未満   4 件 / 1000以上  90 件
#   直近の実数: 0 0 0 0 67000 67000 0 0 0 0 3 3
#
# **`0` が多い。** 本当にフォロワー 0 人 なのか、**読めていないだけ**なのか。
# 読めていないだけなら、**347 件 が不当に落ちている。**
#
# **フォロワー 0 人 のアカウントは実在するが、347 件 も連続で当たるのは不自然。**
# `hashtag-follow` は 10未満 が 4 件 しかない。**同じ X を見ているのに差がありすぎる。**
#
# ## 上限 50000 をどうするかは、データで決める
#
# 大型（1000 以上）が 388 件 弾かれている。上げれば通るが、
# **大型アカウントはフォロー返し率が低い**ので、フォロワー増に直結しないかもしれない。
#
# **既に 338 件 フォローしている。** どの帯が返してくれたかを集計すれば、
# **上限を勘ではなく実績で決められる。**
#
# ## このタスクは測るだけ
#
#   1. `0` と出た相手を**実際に開いて**、フォロワー数が読めるか確かめる（5 件）
#   2. フォロー済みの相手を**フォロワー帯ごとに分けて**、返してくれた割合を出す
#
# **上限を変えない。フォローしない。アンフォローしない。**
#
# ## ルール 15 を守る
#
# **測るだけ。5 分 以内。** 直す側は結果を見てから別タスクにする。
#
# ## やらないこと
#
# **投稿しない。フォローしない。設定を書き換えない。LLM を呼ばない（$0）。**
# **`timeout` を使わない**（macOS に無い）。一時ファイルは `.js` のまま。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/follower-count-truth.md"
NODE_BIN="/usr/local/bin/node"
CDP="http://127.0.0.1:18810"
PROBE="$S/.x57-probe.js"     # **`.js` のまま**
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

# ─── `0` と出た相手を実際に開いて確かめる ───
cat > "$PROBE" <<'JSEOF'
// 「フォロワー 0」と判定された相手を実際に開き、**読めるかどうか**を確かめる。
// フォローもアンフォローもしない。**読むだけ。**
const { chromium } = require("playwright-core");   // **playwright ではない**

const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
const HANDLES = (process.env.HANDLES || "").split(",").map(s => s.trim()).filter(Boolean);

// 「1,234」「12.3K」「1.2万」を数値にする。読めなければ null（**0 にしない**）
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

(async () => {
  if (!HANDLES.length) { console.log("対象のハンドルが渡されていない"); return; }
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
  catch (e) { console.log("CDP に繋がらない: " + String(e.message).slice(0, 110)); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log("context が無い"); return; }
  const page = await ctx.newPage();

  let readable = 0, unreadable = 0, trulyZero = 0;
  for (const h of HANDLES.slice(0, 5)) {
    try {
      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      await page.waitForTimeout(4000);
      const r = await page.evaluate(() => {
        const out = { vf: null, f: null, aria: null, notFound: false, suspended: false };
        const a1 = document.querySelector('a[href$="/verified_followers"]');
        const a2 = document.querySelector('a[href$="/followers"]');
        if (a1) out.vf = (a1.innerText || "").trim();
        if (a2) { out.f = (a2.innerText || "").trim(); out.aria = a2.getAttribute("aria-label"); }
        const body = document.body ? document.body.innerText : "";
        out.notFound = /このアカウントは存在しません|doesn.t exist/i.test(body);
        out.suspended = /凍結されています|suspended/i.test(body);
        return out;
      });
      const n = parseCount(r.aria) ?? parseCount(r.f) ?? parseCount(r.vf);
      let verdict;
      if (r.notFound) { verdict = "**アカウントが無い**"; unreadable++; }
      else if (r.suspended) { verdict = "**凍結**"; unreadable++; }
      else if (n === null) { verdict = "**読めない（DOM から数値が取れない）**"; unreadable++; }
      else if (n === 0) { verdict = "**本当に 0 人**"; trulyZero++; }
      else { verdict = "**読めた: " + n + " 人**"; readable++; }
      console.log("  @" + h + " → " + verdict);
      console.log("     /followers の文字: " + JSON.stringify(r.f));
      console.log("     aria-label       : " + JSON.stringify(r.aria));
      console.log("     verified の文字  : " + JSON.stringify(r.vf));
    } catch (e) {
      console.log("  @" + h + " → 例外 " + String(e.message).slice(0, 70));
      unreadable++;
    }
  }
  console.log("");
  console.log("=== 判定 ===");
  console.log("  読めた: " + readable + " 件 / 本当に 0 人: " + trulyZero + " 件 / 読めない: " + unreadable + " 件");
  if (readable > 0) {
    console.log("  → **読めるのに 0 と判定されていた。** フォロー側の数値取得が壊れている。");
    console.log("     347 件 が不当に落ちている可能性がある。");
  } else if (trulyZero > 0 && unreadable === 0) {
    console.log("  → **本当に 0 人 のアカウントだった。** 弾いているのは正しい挙動。");
  } else {
    console.log("  → **読めない相手が多い。** 凍結・削除・鍵アカの可能性。");
  }
  await page.close();
})().catch((e) => { console.log("落ちた: " + String(e && e.message).slice(0, 180)); });
JSEOF

{
echo "# フォロワー数 0 の正体 ＋ フォロー返し率"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`0 0 0 0 67000 67000 0 0 0 0 3 3\`"
echo ">"
echo "> **\`0\` が多い。** 本当に 0 人 なのか、**読めていないだけ**なのか。"
echo "> 読めていないだけなら、**347 件 が不当に落ちている。**"
echo
echo "**測るだけ。上限を変えない。フォローしない。**"

# ═══════════ 0. 前提 ═══════════
echo
echo "## 0. 前提"
echo
echo '```'
cdp_ok && echo "  CDP: 健全" || echo "  CDP: **落ちている**"
[ -d "$W/node_modules/playwright-core" ] && echo "  playwright-core: 在る" || echo "  playwright-core: **無い**"
echo '```'

# ═══════════ 1. 0 と出た相手を拾う ═══════════
echo
echo "## 1. \`0\` と判定された相手を、実際に開いて確かめる"
echo
echo "**ログから \`out of range (0\` の相手を拾い、プロフィールを開く。**"
echo "フォローもアンフォローもしない。読むだけ。"
echo
echo '```'
F="$W/logs/competitor-follower-follow.log"
HANDLES=""
if [ -f "$F" ]; then
  # `@xxx: ❌ follower count out of range (0, ...` の形からハンドルを拾う
  HANDLES="$(grep -aoE '@[A-Za-z0-9_]{2,15}: ❌ follower count out of range \(0,' "$F" 2>/dev/null \
    | grep -oE '^@[A-Za-z0-9_]{2,15}' | sed 's/^@//' | tail -5 | tr '\n' ',' | sed 's/,$//')"
  echo "  ログから拾えた対象: $(printf '%s' "$HANDLES" | tr ',' '\n' | grep -c . || echo 0) 件"
else
  echo "  **$F が無い。**"
fi
if [ -z "$HANDLES" ]; then
  echo "  **0 と出た相手をログから拾えない。** 形式が想定と違う。"
  echo "  --- out of range の行の実物（直近 3 件） ---"
  grep -a 'out of range' "$F" 2>/dev/null | tail -3 | cut -c1-200 | sed 's/^/    /' | clean
fi
echo '```'
echo
echo '```'
if [ -z "$HANDLES" ]; then
  echo "  対象が無いので開かない。"
elif ! cdp_ok; then
  echo "  CDP が落ちている。開けない。"
elif ! "$NODE_BIN" --check "$PROBE" 2>/dev/null; then
  echo "  **調査スクリプトが構文エラー。走らせない。**"
  "$NODE_BIN" --check "$PROBE" 2>&1 | head -5 | sed 's/^/    /'
else
  R="${TMPDIR:-/tmp}/p57.$$"
  ( cd "$W" && CDP_URL="$CDP" HANDLES="$HANDLES" run_limited 180 "$R" "$NODE_BIN" "$PROBE" ) || true
  rc=$?
  cat "$R" 2>/dev/null | cut -c1-240 | sed 's/^/  /' | clean
  [ "$rc" = "124" ] && echo "  **3 分 で打ち切った。**"
  rm -f "$R"
fi
echo '```'

# ═══════════ 2. フォロー返し率 ═══════════
echo
echo "## 2. フォロー返し率（**上限を勘ではなく実績で決める**）"
echo
echo "既に 338 件 フォローしている。**どの帯が返してくれたか**を集計する。"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
try{
  const d=JSON.parse(fs.readFileSync(p,"utf8"));
  // 帯ごとに「フォローした数」と「返してくれた数」を数える
  const band = (n) => {
    if (n === null || n === undefined || !isFinite(n)) return "不明";
    if (n < 10) return "0〜9";
    if (n < 100) return "10〜99";
    if (n < 1000) return "100〜999";
    if (n < 10000) return "1000〜9999";
    if (n < 50000) return "1万〜4.9万";
    return "5万以上";
  };
  const tally = {};
  let total = 0, back = 0, noInfo = 0;
  for (const [h, e] of Object.entries(d)) {
    if (!e || typeof e !== "object") continue;
    total++;
    // フォロワー数らしきキーを探す（決め打ちしない）
    const k = Object.keys(e).find(x => /^(followers|followers_count|follower_count|fc)$/i.test(x));
    const n = k ? Number(e[k]) : null;
    if (n === null || !isFinite(n)) noInfo++;
    const b = band(n);
    tally[b] = tally[b] || { n: 0, back: 0 };
    tally[b].n++;
    // 返してくれたか。状態の持ち方を決め打ちしない
    const fb = e.followback_status || e.followed_back || e.follows_back || e.mutual;
    const isBack = fb === true || fb === "followed_back" || fb === "mutual" || fb === "ok";
    if (isBack) { tally[b].back++; back++; }
  }
  console.log("  フォロー済み 合計: " + total + " 件 / 返してくれた: " + back + " 件");
  console.log("  フォロワー数が記録されていない: " + noInfo + " 件");
  console.log("");
  console.log("  帯           フォロー   返し   返し率");
  const order = ["0〜9","10〜99","100〜999","1000〜9999","1万〜4.9万","5万以上","不明"];
  for (const b of order) {
    const t = tally[b]; if (!t) continue;
    const r = t.n ? Math.round(t.back / t.n * 1000) / 10 : 0;
    console.log("  " + b.padEnd(12) + String(t.n).padStart(7) + String(t.back).padStart(7) + String(r).padStart(7) + "%");
  }
  if (noInfo === total) {
    console.log("");
    console.log("  **フォロワー数が 1 件も記録されていない。**");
    console.log("  帯ごとの判断はこのファイルからはできない。記録するところから要る。");
  }
}catch(e){ console.log("  **読めない: " + String(e.message).slice(0,80) + "**"); }
' "$D/reply-followers.json" 2>&1 | clean
echo '```'
echo
echo '```'
echo "  --- 状態ファイルが何を持っているか（キーの一覧・値は出さない） ---"
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const keys=new Map();
  let i=0;
  for(const e of Object.values(d)){
    if(!e||typeof e!=="object") continue;
    for(const k of Object.keys(e)) keys.set(k,(keys.get(k)||0)+1);
    if(++i>=500) break;
  }
  const rows=[...keys].sort((a,b)=>b[1]-a[1]);
  for(const [k,n] of rows) console.log("    " + k.padEnd(28) + n + " 件で出現");
}catch(e){ console.log("    読めない"); }
' "$D/reply-followers.json" 2>&1 | clean
echo '```'

# ═══════════ 3. 読み方 ═══════════
echo
echo "## 3. 読み方"
echo
echo "| §1 の判定 | 意味 | 次にやること |"
echo "| --- | --- | --- |"
echo "| **読めるのに 0 と判定** | フォロー側の数値取得が壊れている | 取得を直す。**347 件 が戻る** |"
echo "| **本当に 0 人** | 弾いているのは正しい | 触らない |"
echo "| **読めない相手が多い** | 凍結・削除・鍵アカ | 候補の取り方を見直す |"
echo
echo "| §2 の結果 | 意味 |"
echo "| --- | --- |"
echo "| 帯ごとに返し率が出た | **上限を実績で決められる。** 返し率が高い帯に寄せる |"
echo "| フォロワー数が記録されていない | **記録するところから要る。** いまは帯で判断できない |"
echo
echo "**上限 50000 を上げるかどうかは、この結果を見てから決める。** 勘で動かさない。"
echo
echo "## 4. 費用"
echo
echo "**LLM を一切 呼ばない。DOM を読むだけ。フォローもアンフォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "フォロワー数 0 の正体と返し率 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
