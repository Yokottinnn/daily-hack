#!/bin/bash
# **電子書籍リーダーの比較記事の材料（続き）: Kindle Scribe（2026 年モデル・B0FC1PBJRB）の商品ページから、解像度・防水・重さなどの公式の仕様の行を読む（t1114）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# t1113 では Scribe のページだけ作りが違い（タブが無い）、仕様が取れなかった。今回はページの本文から「ppi・防水・重量・サイズ・解像度・バッテリー・ペン」を含む行と、技術仕様の表（#productDetails・#tech）だけを残す。
# Mac の Chrome（CDP）で **Cookie の無い新しいコンテキスト**で開く（ログインしていない状態）。結果は reports/t1114/scribe.txt。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1114-kindle-scribe-spec.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# Kindle Scribe 2026 年モデルの仕様（t1114・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

# ── playwright-core を探す（**棚卸しに書いてある場所から**） ──
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  {
    echo "⚠️ **\`playwright-core\` がどちらにも無い。**"
    echo ""
    echo "**ここで止める。** 推測で埋めない（最上位ルール 20）。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: **\`$PWDIR\`** に在る" >> "$OUT"

# ── Chrome が CDP で上がっているか（**ポートの LISTEN では足りない**・ルール 13） ──
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  {
    echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** 新しく起動はしない（t174 と同じ）"
    echo ""
    echo "**ここで止める。** Chrome が戻ってから同じものを出し直す。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"
echo "" >> "$OUT"

# ── 描画して読む ──────────────────────────────────────────
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
D="$RDIR/t1114"; rm -rf "$D"; mkdir -p "$D/img"
SCRIPT="$RDIR/.t1114.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 }, locale: 'ja-JP' });   // Cookie なし（ログインしていない）
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 226000 - (Date.now() - t0);
const PAGES = [
  ['scribe', 'https://www.amazon.co.jp/dp/B0FC1PBJRB'],
];
const TABS = ['デザインのディテール', '測定値', 'ディスプレイ', 'パフォーマンス', '電源', '接続性', 'ソフトウェア', 'サービス', 'その他の詳細', '技術仕様', '仕様'];
let first = true;
for (const [key, url] of PAGES) {
  if (left() < 30000) { console.log(`- ⏱ ${key} は時間切れ`); continue; }
  if (!first) await p.waitForTimeout(20000);   // 続けて開くと確認画面になる（t1110）
  first = false;
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    for (let i = 1; i <= 5; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 5), i); await p.waitForTimeout(400); }
    const ti = await p.title();
    const fin = p.url();
    if (/checkpoint|validateCaptcha/.test(fin)) { console.log(`\n### ${key}\n- ⚠️ 確認画面（${fin.slice(0, 60)}）。読めない`); continue; }
    const asin = (fin.match(/\/dp\/([A-Z0-9]{10})/) || [])[1] || '';
    let out = `TITLE: ${ti}\nURL: ${fin}\nASIN: ${asin}\n`;
    let got = 0;
    for (const lab of TABS) {
      const ok = await p.evaluate((lab) => {
        const els = [...document.querySelectorAll('a,button,li,span,div,[role=tab]')].filter((e) => (e.innerText || '').trim() === lab && e.offsetParent !== null);
        const e = els[els.length - 1]; if (!e) return false; e.scrollIntoView({ block: 'center' }); e.click(); return true;
      }, lab).catch(() => false);
      if (!ok) continue;
      await p.waitForTimeout(800);
      const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
      const s = txt.lastIndexOf('商品仕様'); const e = txt.indexOf('電子書籍リーダーの比較', s);
      const part = s >= 0 ? txt.slice(s, e > s ? Math.min(e, s + 4000) : s + 4000) : '';
      out += `\n## タブ: ${lab}\n${part}\n`; got++;
    }
    // Scribe はタブの無い作り。仕様の表と、仕様の語を含む行だけを残す（ページ全体は出さない・レビューは除く）
    const tbl = await p.evaluate(() => [...document.querySelectorAll('#productDetails_techSpec_section_1, #productDetails_detailBullets_sections1, #tech, #techSpecs_section, #feature-bullets, #productOverview_feature_div')].map((e) => e.innerText).join('\n---\n'));
    out += `\n## 仕様の表\n${tbl.slice(0, 6000)}\n`;
    const all = await p.evaluate(() => { const r = document.querySelector('#cm-cr-dp-review-list, #reviewsMedley'); if (r) r.remove(); return document.body ? document.body.innerText : ''; });
    const lines = [...new Set(all.split('\n').map((l) => l.trim()).filter((l) => l.length <= 300 && /ppi|防水|IPX|重量|重さ|サイズ|解像度|バッテリー|ペン|mm|インチ/.test(l)))];
    out += `\n## 仕様の語を含む行（${lines.length}）\n${lines.slice(0, 120).join('\n')}\n`;
    fs.writeFileSync(`${D}/${key}.txt`, out);
    const imgs = await p.evaluate(() => {
      const out = [];
      const li = document.querySelector('#landingImage, #imgBlkFront');
      if (li) {
        if (li.getAttribute('data-old-hires')) out.push(li.getAttribute('data-old-hires'));
        const dyn = li.getAttribute('data-a-dynamic-image');
        if (dyn) { try { const o = JSON.parse(dyn); const best = Object.entries(o).sort((a, z) => z[1][0] - a[1][0])[0]; if (best) out.push(best[0]); } catch {} }
      }
      for (const s of document.querySelectorAll('script')) { const m = (s.textContent || '').match(/"hiRes":"(https:[^"]+)"/g); if (m) for (const x of m) out.push(x.slice(9, -1)); }
      return [...new Set(out)].slice(0, 6);
    });
    console.log(`\n### ${key}\n- 「${ti.slice(0, 100)}」 ${fin.slice(0, 120)}\n- ASIN: **${asin}** / 押せたタブ ${got} / 写真候補 ${imgs.length}`);
    let n = 0;
    for (const s of imgs) {
      if (n >= 4 || left() < 15000) break;
      try {
        const r = await ctx.request.get(s, { timeout: 15000 });
        if (!r.ok()) { console.log(`  - img ✗ ${r.status()} ${s.slice(0, 100)}`); continue; }
        const buf = await r.body(); n++; const f = `${key}-${n}.jpg`; fs.writeFileSync(`${D}/img/${f}`, buf);
        console.log(`  - img ${f} ${buf.length}B ${s.slice(0, 120)}`);
      } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
console.log(`\n---\n対象 ${PAGES.length} / 経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
JS
RES="$RDIR/.t1114-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; ls -la "$D" "$D/img" | awk '{print $5, $9}' >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
