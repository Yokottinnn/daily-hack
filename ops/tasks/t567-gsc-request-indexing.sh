#!/bin/bash
# **Search Console の「インデックス登録をリクエスト」を Mac の Chrome で押す（t567・2026-11-07）。** LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-07 利用者「このコンピューターを使ってインデックス登録のリクエストをするのは普通にできると思うので、お前がやれ」。
# 公開 API が無いので、画面のボタンを押す。対象: /wangan-map/（登録済み・順位待ち）と /category/wangan-life/（最終クロール 2026-10-07 で古い）。
# **画面は撮らない**（右上にアカウントが写る。出力は公開リポジトリ）。文字だけ返し、メールアドレスは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.t567-gsc-$STAMP.js"; RAW="$W/.t567-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$OUTDIR/t567-gsc-request-indexing.md"
mask() { sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<メール伏せ>/g'; }
descendants() { local root="$1" p kids; kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"; for p in $kids; do echo "$p"; descendants "$p"; done; }
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 & local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do kill -0 "$pid" 2>/dev/null || break; sleep 1; w=$((w + 1)); done
  if kill -0 "$pid" 2>/dev/null; then local victims p; victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done; sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done; wait "$pid" 2>/dev/null || true; return 124; fi
  wait "$pid"; return $?
}
cat > "$RUNNER" <<'JSEOF'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const SITE = "https://daily-hack.fieldbeside.com/";
const TARGETS = ["https://daily-hack.fieldbeside.com/wangan-map/", "https://daily-hack.fieldbeside.com/category/wangan-life/"];
const REQ = /インデックス登録をリクエスト|REQUEST INDEXING|Request indexing/i;
const DONE = /インデックス登録をリクエスト済み|Indexing requested|URL was added to a priority crawl queue|優先クロールキュー/i;
const QUOTA = /割り当て|quota exceeded|Quota/i;
const txt = async (p) => (await p.evaluate(() => document.body ? document.body.innerText : "")).replace(/\s+/g, " ");
(async () => {
  let b; try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const ctx = b.contexts()[0]; if (!ctx) { console.log(JSON.stringify({ fatal: "context が無い" })); process.exit(0); }
  const out = { results: [] };
  for (const url of TARGETS) {
    const r = { url, steps: [] }; const p = await ctx.newPage(); await p.setViewportSize({ width: 1400, height: 1000 });
    try {
      const u = "https://search.google.com/search-console/inspect?resource_id=" + encodeURIComponent(SITE) + "&id=" + encodeURIComponent(url);
      await p.goto(u, { waitUntil: "domcontentloaded", timeout: 45000 });
      if (/accounts\.google\.com/.test(p.url())) { r.result = "Google にログインしていない（この Chrome では Search Console に入れない）"; out.results.push(r); await p.close(); continue; }
      // 検査の結果が出て、ボタンが出るまで待つ（最長 60 秒）
      let btn = null;
      for (let i = 0; i < 30 && !btn; i++) {
        await p.waitForTimeout(2000);
        const c = p.locator("div[role=button], button, span").filter({ hasText: REQ });
        const n = await c.count(); for (let k = 0; k < n; k++) { const h = c.nth(k); if (await h.isVisible().catch(() => false)) { const t = (await h.innerText().catch(() => "")).trim(); if (REQ.test(t) && t.length < 40) { btn = h; break; } } }
      }
      r.steps.push("ページ: " + p.url().replace(/[?#].*/, ""));
      if (!btn) { const t = await txt(p); r.result = "ボタンが見つからない"; r.page = t.slice(0, 600); out.results.push(r); await p.close(); continue; }
      await btn.click(); r.steps.push("ボタンを押した");
      let fin = "";
      for (let i = 0; i < 60 && !fin; i++) { await p.waitForTimeout(2000); const t = await txt(p); if (DONE.test(t)) fin = "リクエスト済み"; else if (QUOTA.test(t) && /超|exceeded/i.test(t)) fin = "1 日の上限に達した"; }
      r.result = fin || "押したが、完了の表示が 120 秒で出なかった"; if (!fin) r.page = (await txt(p)).slice(0, 600);
    } catch (e) { r.result = "エラー: " + String(e && e.message).slice(0, 200); }
    try { await p.close(); } catch (e) {}
    out.results.push(r);
  }
  console.log(JSON.stringify(out, null, 1)); process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF
{
echo "# Search Console の「インデックス登録をリクエスト」（t567・\$0）"; echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"; echo
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?; echo "node --check rc=$CRC $(printf '%s' "$CK" | head -1 | cut -c1-120)"
[ "$CRC" -ne 0 ] && { rm -f "$RUNNER"; echo "**構文が通らない。走らせない。**"; exit 1; }
T0="$(date +%s)"; run_limited 280 "$RAW" node "$RUNNER"; RC=$?; echo "rc=$RC / $(( $(date +%s) - T0 )) 秒"; echo
if [ -s "$RAW" ]; then node -e '
  const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  if (j.fatal) { console.log("**止まった: " + j.fatal + "**"); process.exit(0); }
  for (const r of j.results) { console.log("## " + r.url + "\n\n**結果: " + r.result + "**\n"); for (const s of r.steps) console.log("- " + s); if (r.page) console.log("\n画面の文字（先頭）:\n```\n" + r.page + "\n```"); console.log(""); }
' "$RAW" 2>&1; else echo "**出力が空**"; fi
} 2>&1 | mask > "$OUT"
rm -f "$RUNNER" "$RAW"
grep -c 'リクエスト済み' "$OUT" | head -1 | sed 's/^/リクエスト済み: /'; echo "$(basename "$OUT")"
