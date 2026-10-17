#!/bin/bash
# **認証済みフォロワーのうち、まだフォロー返しできていない人のプロフィールを開いて「押せない理由」を読む。何も押さない。費用 $0。**
# 利用者の選択「残り 19 人が押せない理由をいま調べる」（2026-10-16）。x300 時点で 211 人中 19 人が返し漏れ。
# LLM を呼ばない（$0／回・$0／日・$0／月）。4 分前後で終わる（最大 25 人）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/followback-why-not.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/"handles":\[[^\]]*\]/"handles":["<伏せ>"]/g'; }
P="$W/.x301.js"
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
      return { h: a ? a.slice(1) : null, st: t.endsWith("-unfollow") ? "following" : (t.endsWith("-follow") ? "not" : "?"), cellBtn: btn ? btn.innerText.trim() : "" };
    }));
    const before = seen.size; for (const r of rows) if (r.h && !seen.has(r.h)) seen.set(r.h, r);
    still = seen.size === before ? still + 1 : 0;
    await p.evaluate(() => window.scrollBy(0, 2500)); await p.waitForTimeout(1600);
  }
  const all = [...seen.values()]; const not = all.filter((r) => r.st === "not");
  const res = [];
  for (const r of not.slice(0, 25)) {
    try {
      await p.goto("https://x.com/" + r.h, { waitUntil: "domcontentloaded", timeout: 25000 });
      await p.waitForTimeout(2200);
      const s = await p.evaluate(() => {
        const btns = [...document.querySelectorAll('[data-testid="placementTracking"] button, [data-testid$="-follow"], [data-testid$="-unfollow"]')].map((x) => (x.getAttribute("data-testid") || "") + ":" + (x.innerText || "").trim()).slice(0, 4);
        const body = document.body.innerText;
        const flags = [];
        if (document.querySelector('svg[data-testid="icon-lock"]')) flags.push("鍵アカウント");
        for (const [k, re] of [["一時的に制限", /一時的に制限|temporarily restricted/], ["凍結", /凍結されています|suspended/i], ["ブロック", /ブロックされています|You're blocked|blocked you/i], ["存在しない", /このアカウントは存在しません|doesn’t exist|doesn't exist/], ["フォローリクエスト", /フォローリクエスト|Pending|Follow request/]]) if (re.test(body)) flags.push(k);
        const followsYou = /フォローされています|Follows you/.test(body);
        return { btns, flags, followsYou };
      });
      res.push({ h: r.h, cellBtn: r.cellBtn, ...s });
    } catch (e) { res.push({ h: r.h, error: String(e.message).slice(0, 80) }); }
  }
  await p.close();
  console.log(JSON.stringify({ total: all.length, following: all.filter((r) => r.st === "following").length, not: not.length, checked: res }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 200) })); process.exit(0); });
JS
{
echo "# フォロー返しできていない人の理由（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・押していない）"
echo
if pgrep -f "badge-followback.js" >/dev/null 2>&1; then echo "**badge-followback が走っている最中。数は途中の値**"; echo; fi
echo '```'
(cd "$W" && node "$P" 2>&1 | tail -1) | node -e '
let s=require("fs").readFileSync(0,"utf8");try{const j=JSON.parse(s);if(j.error){console.log("読めなかった: "+j.error);process.exit(0)}
console.log("認証済みフォロワー "+j.total+" 人 / フォロー中 "+j.following+" / 返していない "+j.not);
const tally={};for(const r of j.checked){const k=r.error?"開けなかった":((r.flags&&r.flags.length?r.flags.join("+"):"目立った印なし")+(r.followsYou?"":"・フォローされていない表示"));tally[k]=(tally[k]||0)+1}
console.log("理由の内訳:");for(const[k,v]of Object.entries(tally))console.log("  "+k+": "+v);
console.log("1 人ずつ:");j.checked.forEach(r=>console.log("  @"+r.h+" 一覧のボタン["+r.cellBtn+"] プロフィールのボタン["+(r.btns||[]).join(" / ")+"] 印["+(r.flags||[]).join(",")+"] フォローされている="+r.followsYou+(r.error?" error="+r.error:"")))
}catch(e){console.log(s)}' | hide
echo '```'
rm -f "$P"
echo
echo "## badge-followback（10/16〜）"
echo '```'
grep -E "2026-10-1[67]" "$W/logs/badge-followback.log" | grep -E "verified_followers|scanned=|error|読めなかった" | sed -E 's/^\[[^]]*\] //' | awk '!seen[$0]++' | hide | tail -12
grep -E "^\{\"ok\"" "$W/logs/badge-followback.log" | tail -4 | hide
echo '```'
echo
echo "**押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "フォロー返しできていない人の理由を読んだ / $(basename "$OUT")"
