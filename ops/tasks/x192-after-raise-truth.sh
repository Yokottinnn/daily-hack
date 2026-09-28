#!/bin/bash
# **上限を上げた後の確定値を読む。読むだけ。外さない。費用 $0。**
#
# ## なぜ要るか
#
# `x191` は上限を 20 にして 1 回 走らせたが、**210 秒 で見るのをやめた。**
# そのときの §5 は **走行中のスナップショット**であって、最終結果ではない。
#
#   §5「外した記録: 25 → 25 件（差 0）」    ← **210 秒 時点の値**
#   §4 のログ 14:21:43 / 14:21:52          ← **その時点で 2 件 外れている**
#
# **矛盾している。走っている途中を結果として読んではいけない**（`docs/ops-task-runner.md`）。
#
# ## もう 1 つ、上限より重い話が出た
#
#   フォロー中: **190 件**（前回の走査は 265 件）
#   **片思い: 12 件** / 相互: 178 件
#   ① 片思いから **5 件**（12 件 中 7 件 は守られた）
#   プロフィールを開いた: **40 件**（`MAX_PROFILE_READS=40` で打ち切り）→ 候補 **合計 7 件**
#
# **上限 20 に対して候補が 7 件 しか出ていない。** つまり
# **いま詰まっているのは上限ではなく「外してよい相手が居ないこと」。**
# 上限をこれ以上 上げても増えない。
#
# ## 何を読むか
#
#   ① 23:18 の run の**最終行**（`=== 外した: N 件 ...`）
#   ② 状態ファイルと、覚えた未フォローの**いまの件数**
#   ③ **プロフィールのヘッダーが出す実数**（走査の 190 が本当か。← 答え合わせの基準）
#   ④ plist の値が 20 のままか
#
# ## やらないこと
#
# **外さない。走らせない。設定も触らない。LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
LABEL="ai.openclaw.follow-balance"
P="$LA/$LABEL.plist"
PB="/usr/libexec/PlistBuddy"
LOG="$L/follow-balance.log"
ST="$D/follow-balance-state.json"
NF="$D/follow-balance-notfollowing.json"
LF="$D/follow-balance-lists.json"
PROBE="$W/.x192-probe.js"
OUT="${OPS_REPORT_DIR:-/tmp}/after-raise-truth.md"
ME="heng_ji31590"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

jn() {
  node -e '
    const fs = require("fs");
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { process.stdout.write("0"); process.exit(0); }
    process.stdout.write(String(Array.isArray(j) ? j.length : Object.keys(j || {}).length));
  ' "$1" 2>/dev/null
}

{
echo "# 上限を上げた後の確定値（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。外さない。走らせない。**"
echo "> \`x191\` の §5 は **210 秒 時点のスナップショット**だった。ここで確定値を取る。"

echo
echo "## 1. 23:18 の run の最終行（**一次情報**）"
echo
echo '```'
if [ ! -f "$LOG" ]; then
  echo "  **ログが無い**"
else
  echo "  --- \`=== 外した:\` の行（直近 3 本）---"
  grep -a '=== 外した:' "$LOG" 2>/dev/null | tr -d '\000' | tail -3 | cut -c1-220 | clean | sed 's/^/    /'
  echo
  echo "  --- \`start\` の行（今日ぶん）---"
  grep -a "$(date '+%Y-%m-%d')" "$LOG" 2>/dev/null | grep -a 'follow-balance start' \
    | tr -d '\000' | tail -4 | cut -c1-200 | clean | sed 's/^/    /'
  echo
  echo "  --- 末尾 20 行（**そのまま**）---"
  tail -20 "$LOG" 2>/dev/null | tr -d '\000' | cut -c1-220 | clean | sed 's/^/    /'
fi
echo '```'

echo
echo "## 2. いまの件数"
echo
echo '```'
printf '  外した記録        %s 件   ← x191 の開始時は 25 件\n' "$(jn "$ST")"
printf '  覚えた未フォロー  %s 件   ← x191 の開始時は 8 件\n' "$(jn "$NF")"
echo
if [ -f "$LF" ]; then
  node -e '
    const fs = require("fs");
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("  一覧のキャッシュが読めない"); process.exit(0); }
    const f = j.following || [], g = j.followers || [];
    const lower = new Set(g.map((h) => String(h).toLowerCase()));
    const one = f.filter((h) => !lower.has(String(h).toLowerCase()));
    const ageM = (Date.now() - new Date(j.at || 0).getTime()) / 60000;
    console.log("  一覧のキャッシュ: " + (isFinite(ageM) ? ageM.toFixed(0) : "?") + " 分 前");
    console.log("  走査 フォロー中 " + f.length + " / フォロワー " + g.length + "（差 " + (g.length - f.length) + "）");
    console.log("  走査 片思い " + one.length + " / 相互 " + (f.length - one.length));
  ' "$LF" 2>&1 | clean
else
  echo "  一覧のキャッシュが無い"
fi
echo '```'

echo
echo "## 3. プロフィールのヘッダーの実数（**答え合わせの基準**）"
echo
echo "**走査に頼らず、X が表示している数をそのまま読む。**"
echo "走査は 265 → 190 と大きく動いた。**どちらが本当か、ここで決める。**"
echo
# **プローブはワークスペースの中に置く**（$TMPDIR だと playwright-core が解決できない）
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const ME = process.env.X_ME || "heng_ji31590";
(async () => {
  let b, p;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 20000 });
    const ctx = b.contexts()[0];
    if (!ctx) { console.log(JSON.stringify({ ok: false, error: "no context" })); process.exit(0); }
    p = await ctx.newPage();
    await p.goto("https://x.com/" + ME, { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForTimeout(5000);
    const r = await p.evaluate(() => {
      const pick = (sel) => {
        const a = document.querySelector(sel);
        if (!a) return null;
        return ((a.querySelector("span span") || a).textContent || "").trim();
      };
      const toN = (t) => {
        if (!t) return null;
        const s = String(t).replace(/,/g, "");
        if (/万/.test(s)) return Math.round(parseFloat(s) * 10000);
        if (/k/i.test(s)) return Math.round(parseFloat(s) * 1000);
        const n = parseInt(s, 10);
        return Number.isFinite(n) ? n : null;
      };
      const fg = pick('a[href$="/following"]');
      const fr = pick('a[href$="/verified_followers"]') || pick('a[href$="/followers"]');
      return { following: toN(fg), followers: toN(fr) };
    });
    console.log(JSON.stringify({ ok: true, ...r }));
  } catch (e) {
    console.log(JSON.stringify({ ok: false, error: String((e && e.message) || e).slice(0, 160) }));
  } finally {
    try { if (p) await p.close(); } catch {}
    process.exit(0);
  }
})();
PJS
echo '```json'
X_ME="$ME" node "$PROBE" 2>&1 | tr -d '\000' | cut -c1-200 | clean | sed 's/^/  /'
echo '```'
rm -f "$PROBE"

echo
echo "## 4. plist の値（**20 のままか**）"
echo
echo '```'
launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
  | grep -aE 'MIN_UNFOLLOW|MAX_UNFOLLOW|MAX_PROFILE_READS|DECIDE_BUDGET_S' | sed 's/^/    /'
launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
  | grep -aE '^[[:space:]]+(state|runs|last exit code) ' | sed 's/^/    /'
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §1・§2 の出方 | 意味 | 次 |"
echo "| --- | --- | --- |"
echo "| \`=== 外した: 4 件 / 候補 7 件\` のような行 | **完走した。** それが確定値 | — |"
echo "| \`=== 外した:\` が 23:18 の分だけ無い | **まだ走っているか、途中で落ちた** | \`state\` を見る |"
echo "| §3 のヘッダーが **190 前後** | **走査は正しい。本当に 190 まで減った** | 片思いが枯れたということ |"
echo "| §3 のヘッダーが **240 前後** | **走査が取りこぼしている** | \`LIST_BUDGET_S\` を上げる |"
echo
echo "**上限 20 に対して候補が 7 件。** 詰まっているのは上限ではない。"
echo "増やすなら **\`MAX_PROFILE_READS\`（40 で打ち切った）** か **守りの条件**を触る話になる。"
echo
echo "**外していない。走らせていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -aq 'ヘッダーの実数' "$OUT" 2>/dev/null; then
  echo "上限を上げた後の確定値を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
