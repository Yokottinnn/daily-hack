#!/bin/bash
# **アンフォローがちゃんと動いているかを見る。読むだけ。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > アンフォローのオペレーションってちゃんと動いてる？
#
# 10/3 11:36 のヘッダーで **フォロー中 230 / フォロワー 304（比率 0.757）**。
# 目標 0.58・上限 0.65（最上位ルール 19）を超えているのに下がっていない疑いがある。
#
#   ① follow-balance が launchd に載っているか・最後にいつ走ったか・終了コード（`launchctl print`）
#   ② follow-balance.log の直近の実行（何件 外そうとして、何件 外せたか・止まった理由）
#   ③ 状態ファイル（follow-balance-state.json）の中身（値の要約）
#   ④ フォローする側のジョブ（competitor-follower-follow など）が今日どれだけ足しているか
#   ⑤ いまのヘッダーの数（フォロー中 / フォロワー / 比率）
#
# **外さない。フォローしない。設定を変えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
D="$W/data"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x217-read-$STAMP.js"
RAW="$W/.x217-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/unfollow-health.md"
UIDN="$(id -u)"

hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

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
// x217: プロフィールのヘッダーの数だけ読む。$0。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const p = await b.contexts()[0].newPage();
  const r = {};
  try {
    await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 45000 });
    await p.waitForTimeout(6000);
    Object.assign(r, await p.evaluate(() => {
      const pick = (sel) => { const a = document.querySelector(sel); return a ? ((a.querySelector("span span") || a).textContent || "").trim() : null; };
      return { following: pick('a[href$="/following"]'), followers: pick('a[href$="/verified_followers"]') || pick('a[href$="/followers"]') };
    }));
  } catch (e) { r.error = String(e && e.message).slice(0, 160); }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(r));
  process.exit(0);
})();
JSEOF

{
echo "# アンフォローは動いているか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **外さない。フォローしない。設定を変えない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo "## ① launchd（\`launchctl print\` が証拠。\`list\` は使わない・最上位ルール 13）"
echo
echo '```'
for lab in ai.openclaw.follow-balance ai.openclaw.competitor-follower-follow ai.openclaw.unfollow-daily ai.openclaw.unfollow-cleanup-morning ai.openclaw.unfollow-cleanup-evening ai.openclaw.x-follower-unfollow ai.openclaw.auto-detect-and-unfollow-inactive ai.openclaw.revenge-unfollow ai.openclaw.follow-daily ai.openclaw.follow-morning ai.openclaw.hashtag-follow ai.openclaw.x-follower-follow; do
  pr="$(launchctl print "gui/$UIDN/$lab" 2>/dev/null)"
  if [ -n "$pr" ]; then
    printf '  載っている  %-44s state=%s runs=%s last_exit=%s\n' "$lab" \
      "$(printf '%s' "$pr" | awk -F'= ' '/^\tstate =/{print $2; exit}')" \
      "$(printf '%s' "$pr" | awk -F'= ' '/^\truns =/{print $2; exit}')" \
      "$(printf '%s' "$pr" | awk -F'= ' '/last exit code =/{print $2; exit}')"
  else
    pl="$HOME/Library/LaunchAgents/$lab.plist"
    if [ -f "$pl" ]; then printf '  **載っていない**  %-40s（plist は在る）\n' "$lab"
    elif [ -f "$pl.disabled" ]; then printf '  止めてある  %-44s（.disabled）\n' "$lab"
    else printf '  無い        %s\n' "$lab"; fi
  fi
done
echo
echo "  --- follow-balance の定時"
plutil -p "$HOME/Library/LaunchAgents/ai.openclaw.follow-balance.plist" 2>/dev/null | grep -A12 -E 'StartCalendarInterval|StartInterval' | head -14
echo '```'
echo
echo "## ② follow-balance.log の直近（末尾 60 行）"
echo
echo '```'
for f in "$L/follow-balance.log" "$L/follow-balance-err.log" "$L/follow-balance.out" "$L/follow-balance.err"; do
  [ -f "$f" ] || continue
  printf '  == %s（%s bytes・更新 %s）\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')" "$(stat -f '%Sm' -t '%m/%d %H:%M' "$f" 2>/dev/null)"
  tail -60 "$f" | cut -c1-220 | clean | sed 's/^/    /'
done
echo '```'
echo
echo "## ③ 状態ファイル"
echo
echo '```'
for f in "$D/follow-balance-state.json" "$D/unfollow-cleanup-state.json"; do
  [ -f "$f" ] || { echo "  無い  $(basename "$f")"; continue; }
  printf '  == %s（更新 %s）\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%m/%d %H:%M' "$f" 2>/dev/null)"
  node -e '
    const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
    const sum=(o,d)=>{ if(Array.isArray(o)) return "[配列 "+o.length+" 件]"; if(o&&typeof o==="object"){ if(d>1) return "{…"+Object.keys(o).length+" キー}"; const r={}; for(const k of Object.keys(o).slice(0,25)) r[k]=sum(o[k],d+1); return r;} return o; };
    console.log(JSON.stringify(sum(j,0),null,1).split("\n").slice(0,40).map(l=>"    "+l).join("\n"));
  ' "$f" 2>&1 | cut -c1-200 | clean
done
echo '```'
echo
echo "## ④ 今日のフォロー（足す側）"
echo
echo '```'
TODAY="$(date '+%Y-%m-%d')"
for f in "$L"/*follow*.log; do
  case "$f" in *unfollow*|*follow-balance*) continue;; esac
  n="$(grep -c "$TODAY" "$f" 2>/dev/null | head -1)"; case "$n" in ''|*[!0-9]*) n=0;; esac
  [ "$n" -gt 0 ] && printf '  %-40s 今日の行 %s（更新 %s）\n' "$(basename "$f")" "$n" "$(stat -f '%Sm' -t '%m/%d %H:%M' "$f" 2>/dev/null)"
done
echo "  （ここに出ていないログは、今日の行が無い）"
echo '```'
echo
echo "## ⑤ いまのヘッダー"
echo
echo '```'
if node --check "$RUNNER" 2>/dev/null; then
  run_limited 90 "$RAW" node "$RUNNER"
  node -e '
    let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop()); } catch (e) { console.log("  読めない"); process.exit(0); }
    if (j.fatal || j.error) { console.log("  " + (j.fatal || j.error)); process.exit(0); }
    const n = (s) => Number(String(s || "").replace(/[^0-9.]/g, "")) * (/万/.test(s) ? 10000 : 1);
    const a = n(j.following), b = n(j.followers);
    console.log("  フォロー中 " + j.following + " / フォロワー " + j.followers + " / 比率 " + (b ? (a / b).toFixed(3) : "?"));
    if (b) { console.log("  目標 0.58 なら フォロー中 " + Math.round(b * 0.58) + " 件・上限 0.65 なら " + Math.round(b * 0.65) + " 件"); }
  ' "$RAW" 2>&1
fi
echo '```'
rm -f "$RUNNER" "$RAW"
echo
echo "**外していない。フォローしていない。設定を変えていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
if grep -aq '## ⑤' "$OUT" 2>/dev/null; then echo "アンフォローの稼働を読んだ / $(basename "$OUT")"; else echo "**読めていない** / $(basename "$OUT")"; fi
