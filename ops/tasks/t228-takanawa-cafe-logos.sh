#!/bin/bash
# **ニュウマン高輪のカフェのロゴを取る（t228）。読むだけ・LLM 不使用・$0。**
#
# t227 で飲食店 24 店は取れたが、**カフェと一部の店が一覧ページの詳細リンクに出てこなかった**
# （フロアガイドは 1 フロアぶんの 14 件しか DOM に無かった）。
# 今回は**フロアガイドのフロアのタブ（South 1F〜MIMURE 3F）を順に押して**リンクを集める。
#
# 記事案 #7（高輪ゲートウェイシティ）で店名を表に並べる。最上位ルール 17: **店名の左にロゴ**。
# ニュウマン高輪のレストラン一覧とフロアガイドから各店の詳細ページ（`?scd=`）を拾い、
# 詳細ページにだけ出る画像（一覧ページにも出るサイト共通の画像は除く）を保存する。
# あわせて TAKANAWA GATEWAY CITY / MoN Takanawa / 高輪SAUNAS の公式サイトのロゴ候補も取る。
# **選ぶのはクラウド側で、目で見てから。** 台帳 `_ledger.json` に取得元と取得日を残す。240 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t228-takanawa-shop-logos.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ニュウマン高輪の店舗ロゴ（t228・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **\`playwright-core\` が無い。** ここで止める（最上位ルール 20）。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: **\`$PWDIR\`**" >> "$OUT"

VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** ここで止める。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"
echo "" >> "$OUT"

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

SCRIPT="$RDIR/.t228-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
import fs from 'node:fs';
const DIR = process.env.OUT_DIR;
fs.mkdirSync(DIR, { recursive: true });
const T0 = Date.now();
// 記事の表に出す店（部分一致で拾う）
const WANT = ['ZEROCORNER', 'VERVE', 'ブルーボトル', '365日とCOFFEE', 'SOW COFFEE', 'STARBUCKS', 'THE CITY BAKERY', '高輪SAUNAS',
  'PAN', 'CUP', 'PIZ', 'GLS', 'TAP'];
const FLOORS = ['South', 'North', 'LUFTBAUM', 'MIMURE'];
const LEVELS = ['1F', '2F', '3F', '4F', '5F', '28F', '29F'];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1400, height: 1000 });
const scroll = async () => { await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 900) { window.scrollTo(0, y); await new Promise(r => setTimeout(r, 120)); } }); await p.waitForTimeout(800); };
const ledger = {};
const save = async (name, src, page, meta) => {
  try {
    const r = await fetch(src, { headers: { 'User-Agent': 'Mozilla/5.0', Referer: page } });
    const buf = Buffer.from(await r.arrayBuffer());
    const ct = r.headers.get('content-type') || '';
    const ext = /svg/.test(ct) || /\.svg/i.test(src) ? 'svg' : /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : 'jpg';
    const fn = `${name}.${ext}`;
    fs.writeFileSync(`${DIR}/${fn}`, buf);
    ledger[fn] = { src, page, ...meta, bytes: buf.length, fetched: new Date().toISOString().slice(0, 10) };
    console.log(`  - ✅ \`${fn}\` ← ${src} / ${meta.w}x${meta.h} / alt「${meta.alt}」 / ${buf.length} bytes`);
  } catch (e) { console.log(`  - ✗ 取れない: ${src} ${String(e).slice(0, 80)}`); }
};
const imgsOf = () => p.evaluate(() => [...document.images].map(i => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || '').slice(0, 60), cls: (i.className || '').toString().slice(0, 60) })).filter(x => x.src && x.w >= 60));

// ① 一覧ページから詳細リンクを集める。一覧に出る画像は「サイト共通」として控える
const links = new Map(); const common = new Set();
for (const u of ['https://www.newoman.jp/takanawa/restaurant/', 'https://www.newoman.jp/takanawa/floorguide/']) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }); await scroll();
    for (const i of await imgsOf()) common.add(i.src);
    const grab = async () => {
      const a = await p.evaluate(() => [...document.querySelectorAll('a[href*="scd="]')].map(a => [a.href, (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80)]));
      for (const [h, t] of a) if (!links.has(h) || (t && !links.get(h))) links.set(h, t);
      return a.length;
    };
    console.log(`- ${u}: 詳細リンク **${await grab()}** 件 / 画像 ${common.size} 件`);
    if (u.includes('floorguide')) {
      // フロアのタブを順に押す（建物 → 階）。押せた数とリンクの増え方を出す
      for (const f of FLOORS) {
        const bf = p.getByText(f, { exact: true }).first();
        if (await bf.count()) { await bf.click({ timeout: 3000 }).catch(() => {}); await p.waitForTimeout(500); }
        for (const l of LEVELS) {
          if (Date.now() - T0 > 120000) break;
          const bl = p.getByText(l, { exact: true }).first();
          if (!(await bl.count())) continue;
          const ok = await bl.click({ timeout: 3000 }).then(() => true).catch(() => false);
          await p.waitForTimeout(700);
          console.log(`  - ${f} ${l}: ${ok ? '押せた' : '押せない'} → 累計リンク ${links.size}（この画面 ${await grab()}）`);
        }
      }
    }
  } catch (e) { console.log(`- ⚠️ 開けない ${u}: ${String(e).slice(0, 120)}`); }
}
console.log('');
// ② 欲しい店の詳細ページを開き、詳細ページにだけある画像を取る
const hit = new Set();
let k = 0;
for (const [h, t] of links) {
  if (Date.now() - T0 > 210000) { console.log('⚠️ **時間切れで打ち切り。**'); break; }
  const w = WANT.find(x => (x.length <= 3 ? new RegExp(`\\b${x}\\s*[:：]`).test(t) : t.includes(x)));
  if (!w || hit.has(w)) continue;
  hit.add(w); k++;
  console.log(`### ${w}（${t}）\n\n- ${h}`);
  try {
    await p.goto(h, { waitUntil: 'domcontentloaded', timeout: 20000 }); await p.waitForTimeout(900);
    const own = (await imgsOf()).filter(i => !common.has(i.src)).slice(0, 3);
    if (!own.length) console.log('  - ✗ 詳細ページにだけある画像が無い');
    let j = 0;
    for (const i of own) await save(`shop-${String(k).padStart(2, '0')}-${++j}`, i.src, h, { shop: w, title: t, w: i.w, h: i.h, alt: i.alt, cls: i.cls });
  } catch (e) { console.log(`  - ⚠️ 開けない: ${String(e).slice(0, 120)}`); }
  console.log('');
}
console.log(`**見つからなかった店**: ${WANT.filter(x => !hit.has(x)).join(' / ') || 'なし'}\n`);
fs.writeFileSync(`${DIR}/_ledger.json`, JSON.stringify(ledger, null, 1));
console.log(`---\n\n**取れたファイル: ${Object.keys(ledger).length}**`);
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t228-res.md"
OUT_DIR="$RDIR/takanawa-logos2" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
