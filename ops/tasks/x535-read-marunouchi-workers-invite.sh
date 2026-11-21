#!/bin/bash
# x535（2026-11-22・読むだけ・$0）: 丸の内ワーカーズのお友だち紹介キャンペーンの告知を作るため、公開ページ 3 つを読む（利用者の依頼）。
#  ① キャンペーンの詳細 https://www.marunouchi.com/pickup/campaign/11212/
#  ② 招待の LP（案内文の URL・code=yyKkyL6sn）
#  ③ 招待の LP（code を利用者の紹介コード 8Q9YWPzzJ に差し替えたもの）が開くか・コードが出るか
#  本文の文字（公開ページ・ログイン不要）・画像の一覧・og:image を出し、大きい画像と画面を reports/x535/ に保存する。何も押さない。LLM 不使用。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$RDIR/x535-read-marunouchi-workers-invite.md"; IMG="$RDIR/x535"; PORT="${CDP_PORT:-18810}"
mkdir -p "$IMG"
PWDIR=""; for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 丸の内ワーカーズの紹介キャンペーンを読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
[ -n "$PWDIR" ] || { echo "playwright-core が無い。止める"; exit 0; }
curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" >/dev/null 2>&1 || { echo "Chrome が CDP で応答しない。止める"; exit 0; }
cat > "$IMG/.read.cjs" <<'JS'
const { chromium } = require(process.env.PWDIR + "/playwright-core");
const fs = require("fs"), path = require("path");
const urls = [
  ["detail", "https://www.marunouchi.com/pickup/campaign/11212/"],
  ["lp-orig", "https://www.marunouchi-workers-portal.com/lp/invite/index.html?code=yyKkyL6sn&event=10000578"],
  ["lp-mine", "https://www.marunouchi-workers-portal.com/lp/invite/index.html?code=8Q9YWPzzJ&event=10000578"],
];
(async () => {
  const b = await chromium.connectOverCDP("http://127.0.0.1:" + process.env.PORT);
  const ctx = b.contexts()[0];
  for (const [key, u] of urls) {
    const p = await ctx.newPage();
    console.log("\n## " + key + "\n" + u + "\n```");
    try {
      const r = await p.goto(u, { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(3500);
      console.log("status=" + (r && r.status()) + " final=" + p.url());
      console.log("title=" + (await p.title()));
      const info = await p.evaluate(() => {
        const og = (n) => (document.querySelector(`meta[property="${n}"]`) || {}).content || "";
        const imgs = [...document.images].filter(i => i.naturalWidth >= 300).map(i => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || "").slice(0, 60) }));
        const main = document.querySelector("main") || document.body;
        return { og: og("og:image"), ogt: og("og:title"), text: main.innerText.replace(/\n{2,}/g, "\n").slice(0, 3500), imgs: imgs.slice(0, 20), hasMine: document.body.innerText.includes("8Q9YWPzzJ"), hasOrig: document.body.innerText.includes("yyKkyL6sn") };
      });
      console.log("og:title=" + info.ogt + "\nog:image=" + info.og);
      console.log("コード 8Q9YWPzzJ がページに出る: " + info.hasMine + " ／ yyKkyL6sn が出る: " + info.hasOrig);
      console.log("--- 画像（幅300以上）");
      info.imgs.forEach((i, n) => console.log(n + " " + i.w + "x" + i.h + " " + i.alt + " " + i.src));
      console.log("--- 本文");
      console.log(info.text.replace(/[\w.+-]+@[\w-]+\.[\w.]+/g, "<メール伏せ>"));
      await p.screenshot({ path: path.join(process.env.IMG, key + "-screen.png"), fullPage: true }).catch(e => console.log("screenshot " + e.message));
      const list = [info.og, ...info.imgs.map(i => i.src)].filter(Boolean);
      let n = 0;
      for (const s of [...new Set(list)].slice(0, 8)) {
        try { const rr = await p.request.get(s, { timeout: 20000 }); if (rr.ok()) { const ext = (s.match(/\.(jpe?g|png|webp|gif)/i) || [, "jpg"])[1]; const f = path.join(process.env.IMG, `${key}-${n}.${ext}`); fs.writeFileSync(f, await rr.body()); console.log("保存 " + path.basename(f) + " " + fs.statSync(f).size + " bytes ← " + s); n++; } else console.log("取れない " + rr.status() + " " + s); } catch (e) { console.log("取れない " + e.message.slice(0, 80) + " " + s); }
      }
    } catch (e) { console.log("失敗 " + e.message.slice(0, 200)); }
    console.log("```");
    await p.close();
  }
  process.exit(0);
})();
JS
PWDIR="$PWDIR" PORT="$PORT" IMG="$IMG" "$NODE_BIN" "$IMG/.read.cjs" 2>&1 &
pid=$!; t0=$(date +%s); while kill -0 $pid 2>/dev/null; do [ $(( $(date +%s) - t0 )) -ge 200 ] && { kill $pid; echo "200 秒で打ち切った"; }; sleep 2; done
rm -f "$IMG/.read.cjs"
echo; echo "**読むだけ。公開ページのみ・何も押していない。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E 'status=|コード' "$OUT" | head -6
exit 0
