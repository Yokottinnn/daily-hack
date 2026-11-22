#!/bin/bash
# x536（2026-11-22・読むだけ・$0）: 利用者「丸の内ワーカーズのリファラル投稿ってSNSで禁止されてたりする？」。
#  キャンペーンの詳細ページ・招待ページの全文と、そこからリンクされた規約（利用規約・応募規約・注意事項・FAQ）を開き、
#  SNS・不特定・転載・公開・掲載・譲渡・紹介コード に当たる文の前後だけを出す。何も押さない。LLM 不使用。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$RDIR/x536-read-marunouchi-workers-terms.md"; PORT="${CDP_PORT:-18810}"
PWDIR=""; for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
JS="$RDIR/.x536.cjs"
{
echo "# 丸の内ワーカーズの紹介を SNS に出してよいか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
[ -n "$PWDIR" ] || { echo "playwright-core が無い"; exit 0; }
cat > "$JS" <<'J'
const { chromium } = require(process.env.PWDIR + "/playwright-core");
const start = ["https://www.marunouchi.com/pickup/campaign/11212/","https://www.marunouchi-workers-portal.com/lp/invite/index.html?code=8Q9YWPzzJ&event=10000578","https://www.marunouchi-workers-portal.com/"];
const KW = /SNS|ＳＮＳ|ソーシャル|不特定|転載|公開|掲載|譲渡|売買|インターネット|ブログ|X（旧|Twitter|紹介コード|禁止|禁じ/;
(async () => {
  const b = await chromium.connectOverCDP("http://127.0.0.1:" + process.env.PORT);
  const ctx = b.contexts()[0]; const seen = new Set(); const queue = [...start];
  const linkRe = /規約|利用規約|応募規約|注意事項|よくある質問|FAQ|terms|kiyaku|rule|policy|faq/i;
  while (queue.length && seen.size < 12) {
    const u = queue.shift(); if (seen.has(u)) continue; seen.add(u);
    const p = await ctx.newPage();
    console.log("\n## " + u + "\n```");
    try {
      await p.goto(u, { waitUntil: "domcontentloaded", timeout: 30000 }); await p.waitForTimeout(3000);
      const r = await p.evaluate(() => ({ title: document.title, text: document.body.innerText, links: [...document.querySelectorAll("a")].map(a => ({ t: (a.innerText || "").trim().slice(0, 40), h: a.href })) }));
      console.log("title=" + r.title + " ／ 文字数=" + r.text.length);
      const lines = r.text.split(/\n+/).map(s => s.trim()).filter(Boolean);
      let hits = 0;
      lines.forEach((l, i) => { if (KW.test(l)) { hits++; if (hits <= 40) console.log("[" + i + "] " + l.slice(0, 260)); } });
      console.log("当たった行: " + hits);
      const cand = r.links.filter(x => x.h.startsWith("http") && (linkRe.test(x.t) || linkRe.test(x.h)));
      console.log("-- 規約らしいリンク");
      cand.slice(0, 12).forEach(x => console.log("  " + x.t + " → " + x.h));
      for (const x of cand) if (!seen.has(x.h) && /marunouchi|mec\.co\.jp|machi/.test(x.h) && !/\.pdf$/i.test(x.h)) queue.push(x.h);
    } catch (e) { console.log("失敗 " + e.message.slice(0, 160)); }
    console.log("```"); await p.close();
  }
  process.exit(0);
})();
J
PWDIR="$PWDIR" PORT="$PORT" "$NODE_BIN" "$JS" 2>&1 | perl -pe 's/[\w.+-]+@[\w-]+\.[\w.]+/<メール伏せ>/g' &
pid=$!; t0=$(date +%s); while kill -0 $pid 2>/dev/null; do [ $(( $(date +%s) - t0 )) -ge 220 ] && { kill $pid; echo "220 秒で打ち切った"; }; sleep 2; done
rm -f "$JS"
echo; echo "**読むだけ。公開ページのみ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -cE '^## ' "$OUT"
exit 0
