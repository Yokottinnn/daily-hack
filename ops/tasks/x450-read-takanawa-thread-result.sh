#!/bin/bash
# x450（2026-11-10・読むだけ・$0）: x449 で高輪の [1/2] は出て [2/2] の返信（post-comment.js）で落ちたらしい。
# ログの最後の結果を切らずに読み（thread_results・child_stdout）、[1/2] の投稿 ID と、その下に [2/2] が付いているかを見る。
# **投稿しない・返信しない・キューを書き換えない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; LOG="$W/logs/publish-takanawa-oneshot.log"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$OUTDIR/x450-read-takanawa-thread-result.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"; PJS="$S/.x450-$STAMP.js"; RAW="$W/.x450-$STAMP.out"
hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
{
echo "# 高輪のスレッドの結果（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
echo; echo "## 最後の結果（base64 の引数は落として、JSON の中身を出す）"; echo '```'
grep '"step":"thread-reply' "$LOG" | tail -n 1 | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s.trim());delete j.error;console.log(JSON.stringify(j,null,1).slice(0,3000))}catch(e){console.log(s.replace(/"[A-Za-z0-9+\/=]{60,}"/g,"<b64>").slice(0,3000))}})' | clean
echo '```'
cat > "$PJS" <<'JSEOF'
const { chromium } = require("playwright-core");
(async () => { const b = await chromium.connectOverCDP("http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage(); const res = {};
  try { await p.goto("https://x.com/heng_ji31590/with_replies", { waitUntil: "domcontentloaded", timeout: 45000 }); await p.waitForTimeout(7000);
    res.rows = await p.evaluate(() => [...document.querySelectorAll("article")].slice(0, 6).map((a) => { const tm = a.querySelector("time"); const tx = a.querySelector('[data-testid="tweetText"]');
      return { href: tm && tm.closest("a") ? tm.closest("a").getAttribute("href") : null, at: tm ? tm.getAttribute("datetime") : null, text: tx ? tx.innerText.slice(0, 50).replace(/\n/g, " ") : null, photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length }; }));
  } catch (e) { res.error = String(e && e.message).slice(0, 200); }
  try { await p.close(); } catch (e) {} console.log(JSON.stringify(res)); process.exit(0); })().catch(e => { console.log(JSON.stringify({ fatal: String(e.message).slice(0, 200) })); process.exit(0); });
JSEOF
echo; echo "## 返信を含む直近 6 本"; echo '```'
(cd "$S" && node "$PJS" > "$RAW" 2>&1); node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));for(const r of j.rows||[])console.log("- "+r.at+" "+r.href+" 画像:"+r.photos+" 「"+r.text+"」");if(j.error||j.fatal)console.log(j.error||j.fatal)' "$RAW" 2>&1 | clean
echo '```'
} > "$OUT" 2>&1
rm -f "$PJS" "$RAW"
grep -E 'status/' "$OUT" | head -3 | cut -c1-200
exit 0
