#!/bin/bash
# **候補の供給元を増やす。1 本 枯れても止まらないようにする。費用 $0（LLM 不使用）。**
#
# ## なぜ必要か
#
# 返信は `trend-detect.js` **1 本だけ**に候補を依存している。
# それが 0 件 を返した瞬間、**後ろの修理も禁止リストも全部 出番が来ない。**
#
#   {"ok":true,"count":0,"candidates":[]}  →  no candidates  →  **0 件**
#
# **1 本の経路に全部 ぶら下げたのが設計の問題。**
# `trend-detect` を直すのは `x54` の結果を見てからだが、
# **直っても また枯れる。** 供給元を増やしておく。
#
# ## 足す経路（**どれも LLM を使わない。DOM を読むだけ**）
#
#   ① **自分へのリプライ** … 既に `incoming-reply-watcher` が拾っている。
#      返していないものが残っていれば、それは**最良の候補**（相手はこちらを知っている）
#   ② **フォロワーのタイムライン** … `/home` に流れてくる投稿。
#      フォロー済みの相手なので関連性が高い
#   ③ **ハッシュタグ検索** … `hashtag-follow` が既に使っている検索語を流用する
#
# **新しい検索語を発明しない。** 既に動いている経路の出力を候補に回すだけ。
#
# ## このタスクは「作る」ではなく「在るものを数える」
#
# **いきなり配線しない。** まず**それぞれの経路から何件 取れるか**を測る。
# 取れないものを配線しても、供給元が 1 本 増えるだけで枯れ方は変わらない。
#
# 測ってから、**取れた経路だけ**を次のタスクで配線する。
#
# ## ルール 15 を守る
#
# **測るだけ。5 分 以内。** 直す側は別タスクにする。
#
# ## やらないこと
#
# **投稿しない。フォローしない。設定を書き換えない。LLM を呼ばない（$0）。**
# **`timeout` を使わない**（macOS に無い）。一時ファイルは `.js` のまま。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/candidate-sources.md"
NODE_BIN="/usr/local/bin/node"
CDP="http://127.0.0.1:18810"
PROBE="$S/.x55-sources.js"     # **`.js` のまま**
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

# ─── 各経路から何件 取れるかを数えるだけ。**返信しない** ───
cat > "$PROBE" <<'JSEOF'
// 候補の供給元ごとに「何件 取れるか」を数える。**返信も投稿もしない。**
//
// ① /notifications/mentions … 自分へのリプライ
// ② /home                    … フォロー済みの相手の投稿
// ③ /search?q=<ハッシュタグ> … 既に使っている検索語
const { chromium } = require("playwright-core");   // **playwright ではない**

const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
const TAGS = (process.env.TAGS || "").split(",").map(s => s.trim()).filter(Boolean);

// 投稿カードを数える。**本文は出さない**（公開リポジトリに載るため）
async function countPosts(page, url, label) {
  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForTimeout(4500);
    if (/login|i\/flow/.test(page.url())) { console.log(label + ": **ログインに飛ばされた**"); return 0; }
    let seen = 0, stable = 0, last = 0;
    for (let i = 0; i < 6 && stable < 3; i++) {
      seen = await page.evaluate(() => document.querySelectorAll("article[data-testid=tweet]").length);
      if (seen === last) stable++; else stable = 0;
      last = seen;
      await page.mouse.wheel(0, 2400);
      await page.waitForTimeout(1200);
    }
    console.log(label + ": **" + seen + " 件**");
    return seen;
  } catch (e) {
    console.log(label + ": 取れない — " + String(e.message).slice(0, 80));
    return 0;
  }
}

(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 15000 }); }
  catch (e) { console.log("CDP に繋がらない: " + String(e.message).slice(0, 110)); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log("context が無い"); return; }
  const page = await ctx.newPage();

  const r = {};
  r.mentions = await countPosts(page, "https://x.com/notifications/mentions", "① 自分へのリプライ");
  r.home = await countPosts(page, "https://x.com/home", "② フォロー中のタイムライン");

  for (const t of TAGS.slice(0, 3)) {
    const q = encodeURIComponent(t);
    r["tag:" + t] = await countPosts(page,
      "https://x.com/search?q=" + q + "&f=live", "③ 検索『" + t + "』（最新）");
  }

  console.log("");
  console.log("=== まとめ ===");
  let total = 0;
  for (const [k, v] of Object.entries(r)) { console.log("  " + k + ": " + v + " 件"); total += v; }
  console.log("  **合計: " + total + " 件**");
  if (total === 0) {
    console.log("  → **どの経路も 0 件。** 検索語ではなく、**ログインか DOM** を疑う。");
  } else {
    console.log("  → **取れている経路がある。** そこを候補に回せば、1 本 枯れても止まらない。");
  }
  await page.close();
})().catch((e) => { console.log("落ちた: " + String(e && e.message).slice(0, 180)); });
JSEOF

{
echo "# 候補の供給元を増やす（**まず何件 取れるかを測る**）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 返信は \`trend-detect.js\` **1 本だけ**に候補を依存している。"
echo "> それが 0 件 を返した瞬間、**後ろの修理も禁止リストも全部 出番が来ない。**"
echo ">"
echo "> **1 本の経路に全部 ぶら下げたのが設計の問題。**"
echo "> 直っても また枯れる。供給元を増やしておく。"
echo
echo "**いきなり配線しない。** それぞれの経路から**何件 取れるか**を先に測る。"
echo "取れないものを配線しても、枯れ方は変わらない。"

# ═══════════ 0. 前提 ═══════════
echo
echo "## 0. 前提"
echo
echo '```'
cdp_ok && echo "  CDP: 健全" || echo "  CDP: **落ちている**"
[ -f /tmp/x-login-in-progress ] && echo "  login ロック: **在る**" || echo "  login ロック: 無い"
[ -d "$W/node_modules/playwright-core" ] && echo "  playwright-core: 在る" || echo "  playwright-core: **無い**"
echo '```'

# ═══════════ 1. 既に使っている検索語を拾う ═══════════
echo
echo "## 1. 既に使っている検索語（**新しく発明しない**）"
echo
echo "\`hashtag-follow\` が動いている経路の検索語を流用する。"
echo
echo '```'
TAGS=""
for f in hashtags.json hashtag-targets.json trend-keywords.json search-queries.json target-config.json; do
  P="$D/$f"; [ -f "$P" ] || continue
  echo "  [$f] 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  T="$("$NODE_BIN" -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  let a=Array.isArray(d)?d:(Object.values(d).find(v=>Array.isArray(v))||[]);
  a=a.map(x=>typeof x==="string"?x:(x&&(x.tag||x.query||x.keyword||x.name)||"")).filter(Boolean);
  console.log(a.slice(0,8).join(","));
}catch(e){ console.log(""); }' "$P" 2>/dev/null)"
  echo "    $T" | clean
  [ -z "$TAGS" ] && [ -n "$T" ] && TAGS="$T"
done
[ -z "$TAGS" ] && echo "  **検索語の設定が読めない。** §2 は検索無しで走らせる"
echo '```'

# ═══════════ 2. 各経路から何件 取れるか ═══════════
echo
echo "## 2. 各経路から何件 取れるか（**返信しない。数えるだけ**）"
echo
echo "| 経路 | なぜ候補になるか |"
echo "| --- | --- |"
echo "| ① 自分へのリプライ | **相手はこちらを知っている。** 最も関係が続きやすい |"
echo "| ② フォロー中のタイムライン | フォロー済みなので関連性が高い |"
echo "| ③ ハッシュタグ検索 | 既に \`hashtag-follow\` が使っている経路 |"
echo
echo '```'
if ! cdp_ok; then
  echo "  CDP が落ちている。測れない。"
elif [ ! -d "$W/node_modules/playwright-core" ]; then
  echo "  **playwright-core が無い。**"
elif ! "$NODE_BIN" --check "$PROBE" 2>/dev/null; then
  echo "  **調査スクリプトが構文エラー。走らせない。**"
  "$NODE_BIN" --check "$PROBE" 2>&1 | head -5 | sed 's/^/    /'
else
  R="${TMPDIR:-/tmp}/src55.$$"
  ( cd "$W" && CDP_URL="$CDP" TAGS="$TAGS" run_limited 240 "$R" "$NODE_BIN" "$PROBE" ) || true
  rc=$?
  cat "$R" 2>/dev/null | cut -c1-240 | sed 's/^/  /' | clean
  [ "$rc" = "124" ] && echo "  **4 分 で打ち切った。**"
  rm -f "$R"
fi
echo '```'

# ═══════════ 3. 未返信のリプライ ═══════════
echo
echo "## 3. 返していない自分へのリプライ（**在れば最良の候補**）"
echo
echo "\`incoming-reply-watcher\` が既に拾っている。**残っていれば、そのまま候補になる。**"
echo
echo '```'
for f in incoming-replies.json mentions.json reply-inbox.json incoming-reply-state.json; do
  P="$D/$f"; [ -f "$P" ] || continue
  CNT="$("$NODE_BIN" -e '
const fs=require("fs");
try{ const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  if(Array.isArray(d)) console.log(d.length);
  else {const a=Object.values(d).find(v=>Array.isArray(v));console.log(a?a.length:Object.keys(d).length);}
}catch(e){ console.log("読めない"); }' "$P" 2>/dev/null)"
  printf '  %-30s %6s 件 / 最終更新 %s\n' "$f" "$CNT" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
done
echo
echo "  --- incoming-reply-watcher のログ 末尾 12 行 ---"
tail -12 "$W/logs/incoming-reply-watcher.log" 2>/dev/null | cut -c1-230 | sed 's/^/    /' | clean
echo '```'

# ═══════════ 4. 読み方 ═══════════
echo
echo "## 4. 読み方"
echo
echo "| §2 の合計 | 意味 | 次にやること |"
echo "| --- | --- | --- |"
echo "| **0 件** | 検索語ではなく**ログインか DOM** の問題 | 認証とセレクタを見る |"
echo "| ①が取れている | **未返信のリプライが在る** | そこを最優先で候補に回す |"
echo "| ②が取れている | TL は読めている | TL を候補に回す配線を足す |"
echo "| ③だけ 0 | **検索語が古い／狭い** | 検索語を見直す |"
echo
echo "**取れた経路だけを次のタスクで配線する。** 取れないものは配線しても無駄。"
echo
echo "## 5. 費用"
echo
echo "**LLM を一切 呼ばない。DOM を読むだけ。返信も投稿もしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**供給元を増やしても、生成の回数は変わらない**（1 回の実行で作る数は"
echo "\`MAX_PICKS_PER_FIRE\` が決めるため）。定時の返信ループは **推定**"
echo "1 回 \$0.003 ／ 1 日 約 \$0.19 ／ 1 か月 約 \$5.8"
echo "（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。"
} > "$OUT" 2>&1

echo "候補の供給元を測る / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
