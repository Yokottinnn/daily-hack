#!/bin/bash
# **フォローとアンフォローの収支を測る。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# 「**フォロー数がアンフォローする数より多いのだけど、ちゃんとアンフォローしてる？**」
#
# 記録（`x143`・2026-09-26）では、こう見えている。
#
#   competitor-follower-follow.log   ✅ 431 件   更新 **09-23**
#   hashtag-follow.log               ✅  65 件   更新 **09-23**
#   unfollow-cleanup-morning.log     ✅   0 件   更新 **08-06**
#   unfollow-cleanup-evening.log     ✅   0 件   更新 **08-06**
#   unfollow-daily.log               ✅   0 件   更新 **08-10**
#   unfollow-evening.log             ✅   0 件   更新 **08-09**
#
# **フォローは今月 動き、アンフォローは 8 月 で止まっているように見える。**
# だが**これは 9/26 のレポートであって「いま」ではない**（最上位ルール 11）。
# **一次情報で測り直す。**
#
# ## 何を出すか
#
#   ① **プロフィールの実数**（フォロー中 / フォロワー）。**これが答えそのもの**
#   ② フォロー系・アンフォロー系の**ジョブが載っているか**（`launchctl print`）
#   ③ 各ログの**最終更新と末尾**（何をして終わっているか。書式も分かる）
#   ④ **相互フォローの材料が在るか**（誰が返してくれているか）。管理の土台になる
#   ⑤ `mutual-prune.js` が在るなら、**何を基準に外しているか**
#
# ## やらないこと
#
# **フォローしない。アンフォローしない。設定も変えない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-unfollow-balance.md"
PROBE="$W/.x160-probe.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

{
echo "# フォローとアンフォローの収支（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** フォローもアンフォローもしていない。設定も変えていない。"

echo
echo "## 1. プロフィールの実数（**これが答えそのもの**）"
echo
# **プローブはワークスペースの中に置く。** $TMPDIR だと playwright-core が解決できない
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
(async () => {
  let b, p;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 20000 });
    const ctx = b.contexts()[0];
    if (!ctx) { console.log(JSON.stringify({ ok: false, error: "no context" })); return; }
    p = await ctx.newPage();
    await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForTimeout(4000);
    const r = await p.evaluate(() => {
      const pick = (sel) => {
        const a = document.querySelector(sel);
        if (!a) return null;
        const t = (a.querySelector("span span") || a).textContent || "";
        return t.trim();
      };
      const toN = (t) => {
        if (!t) return null;
        const s = String(t).replace(/,/g, "");
        if (/万/.test(s)) return Math.round(parseFloat(s) * 10000);
        if (/k/i.test(s)) return Math.round(parseFloat(s) * 1000);
        const n = parseInt(s, 10);
        return Number.isFinite(n) ? n : null;
      };
      const followingTxt = pick('a[href$="/following"]');
      const followersTxt = pick('a[href$="/verified_followers"]') || pick('a[href$="/followers"]');
      return { followingTxt, followersTxt, following: toN(followingTxt), followers: toN(followersTxt) };
    });
    console.log(JSON.stringify({ ok: true, ...r }));
  } catch (e) {
    console.log(JSON.stringify({ ok: false, error: String((e && e.message) || e).slice(0, 140) }));
  } finally {
    try { if (p) await p.close(); } catch {}
    try { if (b) await b.close(); } catch {}
  }
})();
PJS
echo '```json'
node "$PROBE" 2>&1 | clean | sed 's/^/  /'
echo '```'
rm -f "$PROBE"
echo
echo "> **取れなければ、そう書く。** 推測の数字は置かない。"

echo
echo "## 2. ジョブが載っているか（**載っていなければ、そもそも走らない**）"
echo
echo '```'
echo "  --- フォローする側 ---"
for lb in ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow ai.openclaw.reply-follow; do
  if launchctl print "gui/$UID_N/$lb" >/dev/null 2>&1; then
    r="$(launchctl print "gui/$UID_N/$lb" 2>/dev/null | grep -E '^\s+runs = ' | tr -s ' ')"
    printf '  %-42s **載っている** %s\n' "$lb" "$r"
  else
    printf '  %-42s 載っていない\n' "$lb"
  fi
done
echo
echo "  --- アンフォローする側 ---"
for lb in ai.openclaw.unfollow-daily ai.openclaw.unfollow-evening ai.openclaw.unfollow-cleanup-morning \
          ai.openclaw.unfollow-cleanup-evening ai.openclaw.auto-detect-and-unfollow-inactive \
          ai.openclaw.revenge-unfollow ai.openclaw.mutual-prune ai.openclaw.reply-followers-cleanup \
          ai.openclaw.unfollow-stats-monitor; do
  if launchctl print "gui/$UID_N/$lb" >/dev/null 2>&1; then
    r="$(launchctl print "gui/$UID_N/$lb" 2>/dev/null | grep -E '^\s+runs = ' | tr -s ' ')"
    printf '  %-42s **載っている** %s\n' "$lb" "$r"
  else
    printf '  %-42s 載っていない\n' "$lb"
  fi
done
echo
echo "  --- LaunchAgents に在る unfollow / prune 系の plist ---"
ls -1 "$HOME/Library/LaunchAgents" 2>/dev/null | grep -iE "unfollow|prune|cleanup" | sed 's/^/    /' || echo "    （無い）"
echo '```'

echo
echo "## 3. 各ログの最終更新と末尾（**何をして終わっているか**）"
echo
echo '```'
for n in competitor-follower-follow hashtag-follow unfollow-daily unfollow-evening \
         unfollow-cleanup-morning unfollow-cleanup-evening auto-detect-and-unfollow-inactive \
         revenge-unfollow mutual-prune reply-followers-cleanup; do
  f="$L/$n.log"
  if [ -f "$f" ]; then
    printf '  %-36s 更新 %s  %9s bytes\n' "$n" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)" "$(wc -c < "$f" | tr -d ' ')"
  else
    printf '  %-36s **無い**\n' "$n"
  fi
done
echo '```'
echo
echo "アンフォロー系の末尾（**書式が分かる。数え方を決められる**）:"
echo
for n in unfollow-daily unfollow-evening unfollow-cleanup-morning mutual-prune reply-followers-cleanup auto-detect-and-unfollow-inactive; do
  f="$L/$n.log"
  [ -f "$f" ] || continue
  echo "### \`$n.log\`"
  echo
  echo '```'
  tail -12 "$f" 2>/dev/null | cut -c1-200 | clean | sed 's/^/  /'
  echo '```'
  echo
done

echo
echo "## 4. 相互フォローの材料が在るか（**管理の土台**）"
echo
echo "「相互だけど外してよさそうな相手」を選ぶには、**誰をフォローしているか**と"
echo "**誰が返してくれているか**の両方が要る。"
echo
echo '```'
for f in followed.json reply-followers.json badge-followback-state.json refollow-blacklist.json \
         unfollow-whitelist.json follower-history.json unfollow-cleanup-state.json; do
  p="$D/$f"
  if [ -f "$p" ]; then
    printf '  %-34s %9s bytes  更新 %s\n' "$f" "$(wc -c < "$p" | tr -d ' ')" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$p" 2>/dev/null)"
  else
    printf '  %-34s **無い**\n' "$f"
  fi
done
echo '```'
echo
echo "\`followed.json\` の 1 件の形（**いつフォローしたか・返ってきたかが要る**）:"
echo
echo '```json'
node -e '
  const fs = require("fs");
  try {
    const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const arr = Array.isArray(j) ? j : Object.values(j);
    console.log("  件数: " + arr.length);
    const s = arr.find((x) => x && typeof x === "object");
    if (s) for (const k of Object.keys(s).slice(0, 20)) {
      let v = s[k]; if (typeof v === "object") v = JSON.stringify(v).slice(0, 50);
      console.log("  " + String(k).padEnd(20) + " " + String(v).slice(0, 60));
    }
  } catch (e) { console.log("  読めない: " + e.message); }
' "$D/followed.json" 2>&1 | clean
echo '```'

echo
echo "## 5. \`mutual-prune.js\` は何を基準に外すか"
echo
echo '```javascript'
if [ -f "$S/mutual-prune.js" ]; then
  printf '  %s 行  更新 %s\n\n' "$(wc -l < "$S/mutual-prune.js" | tr -d ' ')" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$S/mutual-prune.js" 2>/dev/null)"
  grep -n -E "DRY|LIMIT|CAP|MAX|days|DAYS|threshold|mutual|whitelist|skip|return" "$S/mutual-prune.js" 2>/dev/null | head -40 | cut -c1-200 | clean | sed 's/^/  /'
else
  echo "  **mutual-prune.js が無い**"
  ls -1 "$S" 2>/dev/null | grep -iE "unfollow|prune" | sed 's/^/    /'
fi
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 出方 | 何が言えるか |"
echo "| --- | --- |"
echo "| §2 でアンフォロー側が**全部 載っていない** | **アンフォローは走っていない。** フォローだけ増えて当然 |"
echo "| 載っているのにログが 8 月 止まり | **走って何もしていない。** §3 の末尾で理由が分かる |"
echo "| §4 に返信フォロワーの記録が在る | **相互の判定に使える。** 管理の土台になる |"
echo "| §1 が取れない | Chrome か CDP の問題。**数字は書かない** |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'アンフォローする側' "$OUT" 2>/dev/null; then
  echo "フォローとアンフォローの収支を測った / $(basename "$OUT")"
else
  echo "**測れていない。レポートを確認すること** / $(basename "$OUT")"
fi
