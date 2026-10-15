#!/bin/bash
# **認証済みフォロワーのうち、こちらがフォロー返ししていない人を数える。あわせてフォロー返しのジョブを今 1 回走らせる。費用 $0。**
# 利用者（2026-10-15）: 「ブルーバッジのタイミングでフォローしてくれた認証済みアカウントをちゃんとフォロバしてる？ すぐアンフォローされちゃうよ」
# ① /verified_followers を上から読み、各人のボタンが「フォロー中（-unfollow）」か「フォローバック（-follow）」かを数える（押さない）
# ② badge-followback の定時・設定・10/12 以降のログ
# ③ badge-followback を kickstart（いつもの定時ジョブを前倒しで 1 回。launchd 側で走るのでこのタスクはすぐ終わる）
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/verified-followback-check.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
P="$W/.x296-scan.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.goto("https://x.com/heng_ji31590/verified_followers", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('[data-testid="UserCell"]', { timeout: 25000 });
  const seen = new Map(); let still = 0;
  for (let i = 0; i < 40 && still < 4; i++) {
    const rows = await p.evaluate(() => [...document.querySelectorAll('[data-testid="UserCell"]')].map((c) => {
      const a = [...c.querySelectorAll('a[href^="/"]')].map((x) => x.getAttribute("href")).find((h) => /^\/[A-Za-z0-9_]{1,15}$/.test(h));
      const btn = c.querySelector('button[data-testid$="-follow"], button[data-testid$="-unfollow"]');
      const t = btn ? btn.getAttribute("data-testid") : "";
      return { h: a ? a.slice(1) : null, st: t.endsWith("-unfollow") ? "following" : (t.endsWith("-follow") ? "not" : "?"), txt: btn ? btn.innerText.trim() : "" };
    }));
    const before = seen.size; for (const r of rows) if (r.h && !seen.has(r.h)) seen.set(r.h, r);
    still = seen.size === before ? still + 1 : 0;
    await p.evaluate(() => window.scrollBy(0, 2500)); await p.waitForTimeout(1800);
  }
  await p.close();
  const all = [...seen.values()];
  const c = (s) => all.filter((r) => r.st === s).length;
  console.log(JSON.stringify({ total: all.length, following: c("following"), not: c("not"), unknown: c("?"), notList: all.filter((r) => r.st === "not").map((r) => "@" + r.h + "（" + r.txt + "）") }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 200) })); process.exit(0); });
JS
{
echo "# 認証済みフォロワーへのフォロー返し（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・押していない）"
echo
echo "## ① 認証済みフォロワーの一覧（上から読めた分）"
echo '```'
R="$(cd "$W" && node "$P" 2>&1 | tail -1)"
echo "$R" | node -e 'let s=require("fs").readFileSync(0,"utf8");try{const j=JSON.parse(s);if(j.error){console.log("読めなかった: "+j.error)}else{console.log("読めた "+j.total+" 人 / フォロー中 "+j.following+" / **フォロー返ししていない "+j.not+"** / 判定不能 "+j.unknown);j.notList.forEach(x=>console.log("  - "+x))}}catch(e){console.log(s)}' | hide
echo '```'
rm -f "$P"
echo
echo "## ② badge-followback"
L="ai.openclaw.badge-followback"; PL="$HOME/Library/LaunchAgents/$L.plist"
echo '```'
launchctl print "gui/$(id -u)/$L" 2>&1 | grep -E "state =|runs =|last exit code" | tr -d '\t' | head -3
echo "定時: $(plutil -extract StartCalendarInterval json -o - "$PL" 2>/dev/null || plutil -extract StartInterval raw -o - "$PL" 2>/dev/null)"
echo "環境変数:"; plutil -extract EnvironmentVariables json -o - "$PL" 2>/dev/null | tr ',' '\n' | grep -v -i "token\|key\|secret\|pass" | head -20
echo "プログラム: $(plutil -extract ProgramArguments json -o - "$PL" 2>/dev/null | head -c 300)"
echo '```'
LOGF="$(ls -t "$W"/logs/badge-followback*.log 2>/dev/null | head -1)"
echo "ログ: $(basename "${LOGF:-なし}")"
echo '```'
[ -n "$LOGF" ] && grep -E "2026-10-1[2-5]" "$LOGF" | sed -E 's/^\[[^]]*\] //' | grep -vE "^\s*$" | awk '!seen[$0]++' | hide | tail -40
[ -n "$LOGF" ] && { echo "--- 末尾 15 行（日付なしの行も含む）"; tail -15 "$LOGF" | hide; }
echo '```'
echo
echo "## ③ いま 1 回走らせる"
echo '```'
launchctl kickstart "gui/$(id -u)/$L" 2>&1 | head -1; echo "kickstart rc=$?"
sleep 4; launchctl print "gui/$(id -u)/$L" 2>&1 | grep -E "state =|pid =" | tr -d '\t' | head -2
echo '```'
echo
echo "**一覧は読むだけで押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 結果は次のタスクで読む。"
} > "$OUT" 2>&1
echo "認証済みフォロワーへのフォロー返しを数え、badge-followback を走らせた / $(basename "$OUT")"
