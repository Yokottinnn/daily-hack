#!/bin/bash
# x393（2026-10-31・読むだけ・$0）: 利用者が「外した記録が本当か確かめる」を選んだ。
# x386 で「もうフォローしていない（解除ボタンが無い）→解除済み」と印を付けた相手を 6 件選び、
# プロフィールを長めに待って開き、フォロー中かどうかを読む。**ボタンは押さない。**
# 相手のハンドルは出さない（番号だけ）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x393-verify-not-following.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 「もう外れていた」の記録は本当か（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## ① 印の数"; echo '```'
"$NODE_BIN" -e '
const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const xs=Object.values(r).filter(v=>/x386/.test(v.unfollow_note||""));
console.log("x386 の印",xs.length,"件");' "$W/data/reply-followers.json" 2>&1
echo '```'
echo; echo "## ② 6 件をプロフィールで確かめる（ボタンは押さない）"; echo '```'
PROBE="$W/.x393-probe.js"
cat > "$PROBE" <<'PJS'
const fs = require("fs");
const { chromium } = require("playwright-core");
(async () => {
  const r = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  const ents = Object.entries(r).filter(([, v]) => /x386/.test(v.unfollow_note || ""))
    .sort((a, b) => Date.parse(b[1].unfollowed_at || 0) - Date.parse(a[1].unfollowed_at || 0));
  // 新しいものから 3 件・古いものから 3 件
  const pick = [...ents.slice(0, 3), ...ents.slice(-3)];
  const tally = { following: 0, not_following: 0, unknown: 0 };
  let b, ctx;
  try { b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); ctx = b.contexts()[0]; }
  catch (e) { console.log("CDP に繋がらない:", String(e.message).slice(0, 150)); process.exit(0); }
  let i = 0;
  for (const [key, v] of pick) {
    i++;
    const handle = (v.handle || key || "").replace(/^@/, "");
    const p = await ctx.newPage();
    const o = { n: i, unfollowed_at: v.unfollowed_at || "" };
    try {
      await p.goto("https://x.com/" + handle, { waitUntil: "domcontentloaded", timeout: 40000 });
      // 3.5 秒で読んでいた本番より長く待つ。ボタンが出るまで最大 12 秒
      await p.waitForSelector('[data-testid$="-follow"],[data-testid$="-unfollow"],[data-testid="emptyState"],[data-testid="error-detail"]', { timeout: 12000 }).catch(() => {});
      await p.waitForTimeout(1500);
      o.url_login = /login|i\/flow/.test(p.url());
      Object.assign(o, await p.evaluate(() => {
        const bs = Array.from(document.querySelectorAll("button,[role=button]"));
        const t = bs.map((x) => ({ id: x.getAttribute("data-testid") || "", tx: (x.innerText || "").trim() }))
          .filter((x) => /-(un)?follow$/.test(x.id) || /^(フォロー中|Following|フォロー|Follow|フォローする)$/.test(x.tx));
        const body = document.body.innerText || "";
        return {
          buttons: t.map((x) => (x.id.replace(/^\d+-/, "<id>-") + ":" + x.tx)).slice(0, 4),
          gone: /このアカウントは存在しません|This account doesn’t exist|This account doesn't exist|アカウントは凍結|Account suspended|一時的に制限/.test(body),
        };
      }));
      const s = (o.buttons || []).join(" ");
      o.state = /-unfollow|フォロー中|Following/.test(s) ? "following" : /-follow:|:フォロー$|:Follow$/.test(s) ? "not_following" : "unknown";
    } catch (e) { o.error = String(e.message).slice(0, 120); o.state = "unknown"; }
    tally[o.state] = (tally[o.state] || 0) + 1;
    console.log(JSON.stringify(o));
    await p.close().catch(() => {});
    await new Promise((res) => setTimeout(res, 4000));
  }
  console.log("まとめ", JSON.stringify(tally));
  process.exit(0);
})();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" "$W/data/reply-followers.json" 2>&1 | tail -10
rm -f "$PROBE"
echo '```'
echo; echo "**following が 1 件でもあれば、x386 の印は誤り（本当はまだフォロー中）。**"
} > "$OUT" 2>&1
cat "$OUT" | head -40
exit 0
