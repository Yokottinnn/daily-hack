#!/bin/bash
# **高輪ゲートウェイシティの公式の施設写真を取る（t225）。読むだけ・LLM 不使用・$0。**
#
# 記事案 #7 の表紙（6 枚タイル）と節の写真。Commons には開業後の写真が無かった（t221 は工事中と駅だけ）。
# blog-article スキル: 施設写真は公式から取り、「画像: 各施設公式」と出典を書く。
# 公式 4 ページを描画し、**横長で幅 900px 以上**の画像と og:image を拾う（ロゴ・バナー名は弾く）。
# 台帳 `_ledger.json` に取得元と取得日を残す。**選ぶのはクラウド側で、目で見てから。** 200 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t225-takanawa-official-photos.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 描画してから本文を読む（t225・**\$0**）"
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

# **拡張子は保つ**（`.new` 等を付けると Node が弾く・最上位ルール 14）
SCRIPT="$RDIR/.t225-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
import fs from 'node:fs';
const PAGES = [
  'https://www.takanawagateway-city.com/',
  'https://www.newoman.jp/takanawa/',
  'https://www.newoman.jp/takanawa/restaurant/',
  'https://montakanawa.jp/',
];
const DIR = process.env.OUT_DIR;
fs.mkdirSync(DIR, { recursive: true });
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const ledger = {}; let n = 0;
for (const u of PAGES) {
  console.log(`## ${u}\n`);
  const p = await ctx.newPage();
  try {
    await p.setViewportSize({ width: 1400, height: 1000 });
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 800) { window.scrollTo(0, y); await new Promise(r => setTimeout(r, 150)); } });
    await p.waitForTimeout(1500);
    const imgs = await p.evaluate(() => {
      const og = document.querySelector('meta[property="og:image"]')?.content;
      const list = [...document.images].filter(i => i.naturalWidth >= 900 && i.naturalWidth / Math.max(1, i.naturalHeight) <= 2.4 && i.naturalWidth / Math.max(1, i.naturalHeight) >= 1.1).map(i => [i.currentSrc || i.src, i.naturalWidth, i.naturalHeight, (i.alt || '').slice(0, 60)]);
      return { og, list };
    });
    const cand = [...new Map([...(imgs.og ? [[imgs.og, 0, 0, 'og:image']] : []), ...imgs.list].map(x => [x[0], x])).values()].filter(x => !/logo|icon|sprite|banner|bnr/i.test(x[0])).slice(0, 6);
    for (const [src, w, h, alt] of cand) {
      try {
        const r = await fetch(src, { headers: { 'User-Agent': 'Mozilla/5.0', Referer: u } });
        const buf = Buffer.from(await r.arrayBuffer());
        if (buf.length < 30000) { console.log(`- ✗ 小さい（${buf.length} bytes）: ${src}`); continue; }
        n++; const name = `tk-${String(n).padStart(2, '0')}.${/png/i.test(r.headers.get('content-type') || '') ? 'png' : 'jpg'}`;
        fs.writeFileSync(`${DIR}/${name}`, buf);
        ledger[name] = { src, page: u, w, h, alt, fetched: new Date().toISOString().slice(0, 10) };
        console.log(`- ✅ \`${name}\` ← ${src} / ${w}x${h} / ${alt} / ${buf.length} bytes`);
      } catch (e) { console.log(`- ✗ 取れない: ${src} ${String(e).slice(0, 80)}`); }
    }
    console.log('');
  } catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 140)}\n`); } finally { await p.close(); }
}
fs.writeFileSync(`${DIR}/_ledger.json`, JSON.stringify(ledger, null, 1));
console.log(`---\n\n**取れた枚数: ${n}**`);
await b.close().catch(() => {});
JS

RES="$RDIR/.t225-res.md"
OUT_DIR="$RDIR/takanawa-photos" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
