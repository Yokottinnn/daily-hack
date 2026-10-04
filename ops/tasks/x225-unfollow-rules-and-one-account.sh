#!/bin/bash
# **いまのアンフォローのルール（期限・頻度・守る条件）と、指定の 1 アカウントがなぜ外れていないかを読む。費用 $0。**
#
# ## 指示（2026-10-04）
#
#   > もう一度ルールを確認したいんだけど、今は：
#   > 1. フォローしてフォローバックされてないアカウント
#   > 2. もしくは、相互フォローしていたけどフォローを外されたアカウント
#   > のフォローを外すという行為を、どれぐらいの期限で、どれぐらいの頻度でモニタリングしてやってる？
#   > 例えばこのアカウントなどはフォローを外されていると思うのですが、実際にこちら側のアクションとしてアンフォローをしていない
#
# 推測で答えない。**いま Mac に入っているもの**を読む。
#
#   ① follow-balance.js（片思いを外す）の実際の条件: 猶予日数・守る条件・1 回の上限・候補の取り方
#   ② 定時（plist）と環境変数
#   ③ 「フォロバ判定」系の古い仕組み（followed.json の scheduled_unfollow_at・reply-followback-check）が今どうなっているか
#   ④ 指定の 1 アカウント: こちらのデータのどこに居るか（フォロー中の一覧・フォロワーの一覧・反応の記録・フォロー日時・
#      ホワイトリスト・外した記録）／ログに出てきたか／**いまのプロフィールで「フォローされています」が出るか**
#
# **外さない。フォローしない。設定を変えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
# 指定のアカウント名はレポートに出さない（<指定> と書く）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
TARGET="$(printf '%s' 'c2hpcm9rdW1hX2xpdmVz' | base64 -D 2>/dev/null || printf '%s' 'c2hpcm9rdW1hX2xpdmVz' | base64 -d)"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x225-read-$STAMP.js"
RAW="$W/.x225-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/unfollow-rules-and-one-account.md"
mask() { perl -pe "s/\\Q$TARGET\\E/<指定>/gi" | sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#"/[A-Za-z0-9_]{2,15}"#"/<伏せ>"#g; s#x\.com/[A-Za-z0-9_]{2,15}#x.com/<伏せ>#g; s#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }

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

cat > "$RUNNER" <<'JSEOF'
// x225: 指定の 1 アカウントのプロフィールを読むだけ。押さない。$0。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const h = process.argv[2];
(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない" })); process.exit(0); }
  const p = await b.contexts()[0].newPage();
  const r = {};
  try {
    await p.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 40000 });
    await p.waitForSelector('[data-testid="UserName"]', { timeout: 15000 }).catch(() => {});
    await p.waitForTimeout(2500);
    Object.assign(r, await p.evaluate(() => {
      const t = document.body.innerText || "";
      const btn = [...document.querySelectorAll('[data-testid$="-unfollow"],[data-testid$="-follow"]')][0];
      const pick = (sel) => { const a = document.querySelector(sel); return a ? ((a.querySelector("span span") || a).textContent || "").trim() : null; };
      return {
        followsYou: !!document.querySelector('[data-testid="userFollowIndicator"]') || /フォローされています|Follows you/.test(t.slice(0, 1500)),
        myButton: btn ? (btn.getAttribute("data-testid").endsWith("-unfollow") ? "フォロー中（こちらがフォローしている）" : "フォロー（こちらはフォローしていない）") : "ボタンが読めない",
        theirFollowing: pick('a[href$="/following"]'), theirFollowers: pick('a[href$="/verified_followers"]') || pick('a[href$="/followers"]'),
        lastPost: (document.querySelector("article time") || {}).getAttribute ? document.querySelector("article time").getAttribute("datetime") : null,
      };
    }));
  } catch (e) { r.error = String(e && e.message).slice(0, 160); }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(r));
  process.exit(0);
})();
JSEOF

{
echo "# アンフォローのルールと、指定の 1 アカウント（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "## ① follow-balance.js の実際の条件"
echo
echo '```'
F="$S/follow-balance.js"
grep -n -E 'const (GRACE_DAYS|INACTIVE_DAYS|BIG|MAXN|MINN|ONEWAY|TARGET_RATIO|CEIL|FLOOR|SCAN|PROFILE)|process\.env\.[A-Z_]+ \|\|' "$F" 2>/dev/null | cut -c1-180 | head -25
echo
echo "  --- 守る条件（どれかに当たると外さない）"
a="$(grep -n 'const why\|function keep\|ホワイトリスト"' "$F" | head -1 | cut -d: -f1)"
grep -n -B1 -A10 'return "反応をくれた人"' "$F" 2>/dev/null | cut -c1-180 | head -20
echo
echo "  --- 片思いから候補を取るところ"
grep -n -B3 -A10 '① 片思い（フォロバが無い）' "$F" 2>/dev/null | cut -c1-180 | head -24
echo
echo "  --- 下調べの打ち切り"
grep -n -E '打ち切|150|SCAN_SEC|deadline' "$F" 2>/dev/null | cut -c1-180 | head -6
echo '```'
echo
echo "## ② 定時と環境変数"
echo
echo '```'
for lab in ai.openclaw.follow-balance ai.openclaw.mutual-prune ai.openclaw.reply-followback-check ai.openclaw.unfollow-cleanup-morning ai.openclaw.unfollow-daily; do
  PL="$HOME/Library/LaunchAgents/$lab.plist"
  [ -f "$PL" ] || { [ -f "$PL.disabled" ] && echo "  $lab: 止めてある（.disabled）" || echo "  $lab: plist 無し"; continue; }
  st="$(launchctl print "gui/$(id -u)/$lab" >/dev/null 2>&1 && echo '載っている' || echo '**載っていない**')"
  echo "  == $lab（$st）"
  plutil -p "$PL" 2>/dev/null | grep -E '"Hour"|"Minute"|StartInterval|"[A-Z_]+" =>' | grep -v -E 'PATH|HOME|TOKEN|KEY|SECRET' | tr -s ' ' | sed 's/^/     /' | head -14
done
echo '```'
echo
echo "## ③ フォロバ判定の古い仕組み（followed.json）"
echo
echo '```'
for f in "$D/followed.json" "$D/reply-followers.json"; do
  [ -f "$f" ] || { echo "  無い  $(basename "$f")"; continue; }
  node -e '
    const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const rows = Array.isArray(j) ? j : (j.accounts || j.followed || j.users || Object.values(j));
    const arr = Array.isArray(rows) ? rows : [];
    const st = {}; let due = 0, past = 0; const now = Date.now(); let lastJudge = null;
    for (const r of arr) { if (!r || typeof r !== "object") continue;
      st[r.followback_status || "?"] = (st[r.followback_status || "?"] || 0) + 1;
      if (r.scheduled_unfollow_at) { due++; if (new Date(r.scheduled_unfollow_at).getTime() < now) past++; }
      if (r.followback_judgment_at && (!lastJudge || r.followback_judgment_at > lastJudge)) lastJudge = r.followback_judgment_at; }
    console.log("  " + require("path").basename(process.argv[1]) + ": " + arr.length + " 件 ／ followback_status " + JSON.stringify(st) +
      " ／ 外す予定日あり " + due + "（うち期日を過ぎた " + past + "）／ 最後のフォロバ判定 " + lastJudge);
  ' "$f" 2>&1 | head -3
done
echo
echo "  --- reply-followback-check の中身（先頭のコメント）"
for c in "$S/reply-followback-check.js" "$S/reply-followback-check.sh"; do [ -f "$c" ] && { head -30 "$c" | grep -E '^\s*(//|#)' | cut -c1-160 | sed 's/^/    /'; }; done
echo "  --- そのログの末尾"
tail -8 "$L/reply-followback-check.log" 2>/dev/null | cut -c1-180 | mask | sed 's/^/    /'
echo '```'
echo
echo "## ④ 指定の 1 アカウント"
echo
echo '```'
echo "  --- こちらのデータのどこに居るか（data/*.json を全部 見る）"
for f in "$D"/*.json; do
  grep -q -i "$TARGET" "$f" 2>/dev/null || continue
  node -e '
    const [f, h] = process.argv.slice(1); const H = h.toLowerCase();
    const j = JSON.parse(require("fs").readFileSync(f, "utf8"));
    const hits = [];
    (function walk(o, path) {
      if (Array.isArray(o)) { o.forEach((v, i) => { if (typeof v === "string" && v.toLowerCase().replace(/^@/, "") === H) hits.push(path + "[]"); else walk(v, path + "[" + i + "]"); }); return; }
      if (o && typeof o === "object") for (const k of Object.keys(o)) {
        if (k.toLowerCase().replace(/^@/, "") === H) { const v = o[k]; hits.push(path + ".<指定> = " + (v && typeof v === "object" ? JSON.stringify(v).slice(0, 220) : String(v))); }
        else if (typeof o[k] === "string" && o[k].toLowerCase().replace(/^@/, "") === H) { const sib = Object.assign({}, o); hits.push(path + " の要素 = " + JSON.stringify(sib).slice(0, 220)); }
        else walk(o[k], path + "." + k);
      }
    })(j, "");
    console.log("  " + require("path").basename(f) + ": " + (hits.length ? hits.slice(0, 4).join("\n      ") : "（文字としては在るが、場所が読めない）"));
  ' "$f" "$TARGET" 2>&1 | head -6
done
echo
echo "  --- ログに出てきた行（follow-balance / mutual-prune / follow 系・新しい 10 行）"
grep -h -i "$TARGET" "$L"/follow-balance.log "$L"/mutual-prune.log "$L"/*follow*.log 2>/dev/null | awk '!s[$0]++' | tail -10 | cut -c1-200
echo
echo "  --- いまのプロフィール（読むだけ）"
if node --check "$RUNNER" 2>/dev/null; then
  run_limited 90 "$RAW" node "$RUNNER" "$TARGET"
  tail -1 "$RAW" 2>/dev/null | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => { try { const j = JSON.parse(s);
      if (j.fatal || j.error) { console.log("  " + (j.fatal || j.error)); return; }
      console.log("  相手がこちらをフォローしているか（フォローされています の表示）: " + (j.followsYou ? "している" : "**していない**"));
      console.log("  こちらのボタン: " + j.myButton);
      console.log("  相手のフォロー中 " + j.theirFollowing + " / フォロワー " + j.theirFollowers + " ／ 最新の投稿 " + j.lastPost);
    } catch (e) { console.log("  読めない: " + s.slice(0, 120)); } });'
fi
echo '```'
rm -f "$RUNNER" "$RAW"
echo
echo "**外していない。フォローしていない。設定を変えていない（\$0／回・\$0／日・\$0／月）。**"
} 2>&1 | mask > "$OUT"

if grep -aq '## ④' "$OUT"; then echo "アンフォローのルールと指定の 1 件を読んだ / $(basename "$OUT")"; else echo "**読めていない** / $(basename "$OUT")"; fi
