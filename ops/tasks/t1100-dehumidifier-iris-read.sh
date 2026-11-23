#!/bin/bash
# **除湿機の比較記事の材料: アイリスオーヤマの衣類乾燥除湿機（デシカント式・サーキュレーター付きなど）の公式ページ・仕様・写真を読む（t1100）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして」。blog3 の dehumidifier-comparison-2026 の型番・仕様・発売日・写真。
# irisohyama.co.jp はクラウドから 403 で読めないので、Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開く（ログインの情報を持ち込まない）。
# 本文は reports/t1100/<key>.txt、写真の候補は reports/t1100/img/（幅 600px 以上・各ページ 5 枚まで）。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1100-dehumidifier-iris.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 除湿機 アイリスオーヤマの公式ページ（t1100・**\$0**）"
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
    echo '```text'
    ls -d "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules" 2>&1
    echo '```'
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
D="$RDIR/t1100"; rm -rf "$D"; mkdir -p "$D/img"
SCRIPT="$RDIR/.t1100.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 228000 - (Date.now() - t0);
const seen = new Set();
async function read(key, url, opt = {}) {
  if (left() < 15000) { console.log(`- ⏱ ${key} は時間切れ`); return []; }
  if (seen.has(url)) return []; seen.add(url);
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4500);
    for (let i = 1; i <= 6; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 6), i); await p.waitForTimeout(500); }
    // 「仕様」「スペック」を開くボタンがあれば押す
    await p.evaluate(() => { for (const el of document.querySelectorAll('button,summary,a,[role=button]')) { const t = (el.innerText || '').trim(); if (/^(仕様|スペック|製品仕様|すべての仕様|技術仕様|詳細仕様|仕様・スペック|SPEC)/i.test(t) && t.length < 20) { try { el.click(); } catch {} } } });
    await p.waitForTimeout(1500);
    const ti = await p.title();
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${txt.slice(0, 90000)}`);
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || a.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 60) })));
    const imgs = await p.evaluate(() => {
      const out = [];
      for (const im of document.querySelectorAll('img')) { const s = im.currentSrc || im.src; if (s && im.naturalWidth >= 600) out.push({ s, w: im.naturalWidth, h: im.naturalHeight, alt: (im.alt || '').slice(0, 60) }); }
      const og = document.querySelector('meta[property="og:image"]'); if (og) out.unshift({ s: og.content, w: 0, h: 0, alt: 'og:image' });
      return out;
    });
    console.log(`\n### ${key}\n- 「${ti.slice(0, 80)}」 ${p.url()}\n- 本文 ${txt.length} 文字 / 画像（幅600以上）${imgs.length} 枚`);
    let n = 0; const got = new Set();
    for (const im of imgs) {
      if (n >= (opt.imgs ?? 6) || left() < 12000) break;
      if (got.has(im.s) || /logo|icon|sprite|badge|banner|bnr/i.test(im.s)) continue; got.add(im.s);
      try {
        const r = await ctx.request.get(im.s, { headers: { Referer: url }, timeout: 15000 });
        if (!r.ok()) { console.log(`  - img ✗ ${r.status()} ${im.s.slice(0, 120)}`); continue; }
        const buf = await r.body(); const ct = r.headers()['content-type'] || '';
        const ext = /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : /avif/.test(ct) ? 'avif' : 'jpg';
        n++; const f = `${key}-${n}.${ext}`; fs.writeFileSync(`${D}/img/${f}`, buf);
        console.log(`  - img ${f} ${im.w}x${im.h} ${buf.length}B 「${im.alt}」 ${im.s.slice(0, 140)}`);
      } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
    }
    return links;
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); return []; }
}
// 1) アイリスオーヤマ: 除湿機の一覧と、サーキュレーター付きの一覧から製品ページを拾って読む
const il = [];
for (const [k, u] of [['iris-cat', 'https://www.irisohyama.co.jp/products/electrical-appliances/air-conditioning/dehumidifier/'], ['iris-circ', 'https://www.irisohyama.co.jp/products/electrical-appliances/air-conditioning/dehumidifier/dehumidifier-with-circulator']]) il.push(...await read(k, u, { imgs: 0 }));
const idet = [...new Map(il.filter((l) => /air-conditioning\/dehumidifier\/[^?#]+/i.test(l.h) && !/\/dehumidifier\/?$/.test(l.h)).map((l) => [l.h.split('?')[0], l])).values()];
console.log(`\n- アイリスオーヤマの除湿機のページ候補 ${idet.length} 件`); for (const l of idet.slice(0, 40)) console.log(`  - ${l.t} — ${l.h}`);
// 型番の入った詳細ページを先に読む（最大 6 件）
const pri = idet.filter((l) => /IJD|IJDC|IJC|IJH|KIJ/i.test(l.h + ' ' + l.t));
const ipick = [...pri, ...idet.filter((l) => !pri.includes(l))].map((l) => l.h);
let i = 0; for (const h of ipick.slice(0, 6)) await read(`iris-${++i}`, h, { imgs: 5 });
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
JS
RES="$RDIR/.t1100-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; ls -la "$D" "$D/img" | awk '{print $5, $9}' >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
