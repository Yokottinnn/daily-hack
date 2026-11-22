#!/bin/bash
# **ヘアアイロンの比較記事の材料: ダイソン（Airstrait）・ヤーマン・クレイツの公式の製品ページとヘッダーのロゴを読む（t960）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-22 利用者「商品の比較記事を増やして」。blog3 の hair-iron-comparison-2026 の型番・価格・仕様・写真・ロゴ。
# dyson.co.jp・ya-man.com は 403、create-ion.co.jp はクラウドからつながらないので、Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開く（ログインの情報を持ち込まない）。
# 本文は reports/t960/<key>.txt、写真の候補は reports/t960/img/（幅 600px 以上・各ページ 6 枚まで）。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t960-dryer-official.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ヘアアイロン ダイソン・ヤーマン・クレイツの公式ページ（t960・**\$0**）"
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

D="$RDIR/t960"; rm -rf "$D"; mkdir -p "$D/img" "$D/logo"
SCRIPT="$RDIR/.t960.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし（ログインを持ち込まない）
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 226000 - (Date.now() - t0);
const seen = new Set();
async function save(key, im, url) {
  try {
    const r = await ctx.request.get(im, { headers: { Referer: url }, timeout: 15000 });
    if (!r.ok()) { console.log(`  - ✗ ${r.status()} ${im.slice(0, 120)}`); return null; }
    const buf = await r.body(); const ct = r.headers()['content-type'] || '';
    const ext = /svg/.test(ct) ? 'svg' : /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : /avif/.test(ct) ? 'avif' : 'jpg';
    return { buf, ext };
  } catch (e) { console.log(`  - ⚠️ ${String(e).slice(0, 80)}`); return null; }
}
async function read(key, url, opt = {}) {
  if (left() < 15000) { console.log(`- ⏱ ${key} は時間切れ`); return []; }
  if (seen.has(url)) return []; seen.add(url);
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    for (let i = 1; i <= 5; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 5), i); await p.waitForTimeout(400); }
    await p.evaluate(() => { for (const el of document.querySelectorAll('button,summary,a,[role=button]')) { const t = (el.innerText || '').trim(); if (/^(仕様|スペック|製品仕様|すべての仕様|技術仕様|詳細仕様|仕様・スペック|商品仕様|SPEC)/i.test(t) && t.length < 20) { try { el.click(); } catch {} } } });
    await p.waitForTimeout(1200);
    const ti = await p.title();
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${txt.slice(0, 90000)}`);
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || a.getAttribute('aria-label') || a.querySelector('img')?.alt || '').replace(/\s+/g, ' ').trim().slice(0, 70) })));
    if (opt.logo) {
      // ヘッダーのロゴ（img・インライン svg）を丸ごと書き出す。選ぶのはクラウドで目で見てから
      const lg = await p.evaluate(() => {
        const out = [];
        for (const im of document.querySelectorAll('header img, img[class*=logo i], img[alt*=logo i], img[src*=logo i], [class*=logo i] img')) out.push({ k: 'img', s: im.currentSrc || im.src, alt: im.alt || '', w: im.naturalWidth, h: im.naturalHeight });
        for (const sv of document.querySelectorAll('header svg, [class*=logo i] svg, svg[class*=logo i]')) { const h = sv.outerHTML; if (h.length > 300 && h.length < 60000) out.push({ k: 'svg', html: h, cls: (sv.getAttribute('class') || '') + ' / ' + (sv.parentElement?.className || '') }); }
        const ic = document.querySelector('link[rel*=apple-touch-icon]'); if (ic) out.push({ k: 'img', s: ic.href, alt: 'apple-touch-icon' });
        return out;
      });
      let n = 0;
      for (const l of lg.slice(0, 10)) {
        n++;
        if (l.k === 'svg') { fs.writeFileSync(`${D}/logo/${key}-${n}.svg`, l.html); console.log(`  - logo svg ${key}-${n}.svg ${l.html.length}B (${String(l.cls).slice(0, 60)})`); continue; }
        const s = await save(key, l.s, url); if (!s) continue;
        fs.writeFileSync(`${D}/logo/${key}-${n}.${s.ext}`, s.buf); console.log(`  - logo img ${key}-${n}.${s.ext} ${l.w}x${l.h} 「${l.alt}」 ${l.s.slice(0, 140)}`);
      }
    }
    const imgs = await p.evaluate(() => {
      const out = [];
      for (const im of document.querySelectorAll('img')) { const s = im.currentSrc || im.src; if (s && im.naturalWidth >= 600) out.push({ s, w: im.naturalWidth, h: im.naturalHeight, alt: (im.alt || '').slice(0, 60) }); }
      const og = document.querySelector('meta[property="og:image"]'); if (og) out.unshift({ s: og.content, w: 0, h: 0, alt: 'og:image' });
      return out;
    });
    console.log(`\n### ${key}\n- 「${ti.slice(0, 80)}」 ${p.url()}\n- 本文 ${txt.length} 文字 / 画像（幅600以上）${imgs.length} 枚`);
    let n = 0; const got = new Set();
    for (const im of imgs) {
      if (n >= (opt.imgs ?? 5) || left() < 12000) break;
      if (got.has(im.s) || /logo|icon|sprite|badge|banner|bnr|bn\d/i.test(im.s)) continue; got.add(im.s);
      const s = await save(key, im.s, url); if (!s) continue;
      n++; const f = `${key}-${n}.${s.ext}`; fs.writeFileSync(`${D}/img/${f}`, s.buf);
      console.log(`  - img ${f} ${im.w}x${im.h} ${s.buf.length}B 「${im.alt}」 ${im.s.slice(0, 140)}`);
    }
    return links;
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); return []; }
}
const uniq = (arr) => [...new Map(arr.map((l) => [l.h, l])).values()];
// 1) ダイソン: ストレイトナーの一覧 → Airstrait の製品ページ（最大 2）
let dl = await read('dyson-list', 'https://www.dyson.co.jp/hair-care/hair-straighteners', { imgs: 0 });
if (!dl.some((l) => /airstrait/i.test(l.h))) dl = dl.concat(await read('dyson-hair', 'https://www.dyson.co.jp/hair-care', { imgs: 0 }));
const dprod = uniq(dl.filter((l) => /dyson\.co\.jp\/hair-care\/.*(airstrait|straightener|corrale)/i.test(l.h) && !/accessor|compare|support|owner|spare/i.test(l.h)));
console.log(`\n- ダイソンのストレイトナー候補 ${dprod.length} 件`); for (const l of dprod.slice(0, 15)) console.log(`  - ${l.t} — ${l.h}`);
let i = 0; for (const l of dprod.filter((l) => /\/[a-z0-9-]+\/[a-z0-9-]+$/.test(l.h)).slice(0, 2)) await read(`dyson-p${++i}`, l.h, { imgs: 5 });
// 2) ヤーマン: ヘアケアの一覧（カテゴリ番号を当たる）と検索 → アイロンの製品ページ（最大 3）。ロゴも
let yl = await read('yaman-top', 'https://www.ya-man.com/', { imgs: 0, logo: true });
for (const c of ['104102', '104103', '104104', '104']) yl = yl.concat(await read(`yaman-cat${c}`, `https://www.ya-man.com/Form/Product/ProductList.aspx?cat=${c}`, { imgs: 0 }));
yl = yl.concat(await read('yaman-search', 'https://www.ya-man.com/Form/Product/ProductList.aspx?swrd=%E3%82%A2%E3%82%A4%E3%83%AD%E3%83%B3', { imgs: 0 }));
const yprod = uniq(yl.filter((l) => /ProductDetail\.aspx/i.test(l.h)));
console.log(`\n- ヤーマンの製品ページ ${yprod.length} 件`); for (const l of yprod.slice(0, 40)) console.log(`  - ${l.t} — ${l.h}`);
let j = 0; for (const l of yprod.filter((l) => /アイロン|iron|ストレート|カール/i.test(l.t)).slice(0, 3)) await read(`yaman-p${++j}`, l.h, { imgs: 4 });
// 3) クレイツ: トップ → アイロンの製品ページ（最大 4）。ロゴも
let cl = await read('create-top', 'https://www.create-ion.co.jp/', { imgs: 0, logo: true });
const cnav = uniq(cl.filter((l) => /create-ion\.co\.jp/.test(l.h) && /(product|item|lineup|iron|アイロン)/i.test(l.h + ' ' + l.t)));
console.log(`\n- クレイツの候補 ${cnav.length} 件`); for (const l of cnav.slice(0, 40)) console.log(`  - ${l.t} — ${l.h}`);
const clist = cnav.filter((l) => /(products?|lineup|item)\/?$|category|iron\/?$/i.test(l.h)).slice(0, 2);
for (const [k, l] of clist.entries()) cl = cl.concat(await read(`create-list${k + 1}`, l.h, { imgs: 0 }));
const cprod = uniq(cl.filter((l) => /create-ion\.co\.jp/.test(l.h) && /アイロン|iron/i.test(l.h + ' ' + l.t) && !/faq|support|news|contact/i.test(l.h)));
console.log(`\n- クレイツのアイロン候補 ${cprod.length} 件`); for (const l of cprod.slice(0, 30)) console.log(`  - ${l.t} — ${l.h}`);
let m = 0; for (const l of cprod.filter((l) => !clist.includes(l)).slice(0, 4)) await read(`create-p${++m}`, l.h, { imgs: 4 });
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
JS
RES="$RDIR/.t960-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; ls -la "$D" "$D/img" "$D/logo" | awk '{print $5, $9}' >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
