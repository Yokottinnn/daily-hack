#!/bin/bash
# **高輪ゲートウェイシティの細部を読む（t224）。読むだけ・LLM 不使用・$0。**
#
# MoN Takanawa の公式（開館時間・料金）、街の公式の施設ページ、高輪SAUNAS のフロアガイドを描画して読む。
# あわせて t222 で選んだ X 投稿 6 本を syndication API で照合する。200 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t224-takanawa-details.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 描画してから本文を読む（t224・**\$0**）"
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
SCRIPT="$RDIR/.t224-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const URLS = [
  'https://montakanawa.jp/',
  'https://www.takanawagateway-city.com/facilities/',
  'https://www.newoman.jp/takanawa/floorguide/detail/?scd=003014',
];
const KEY = /紅葉|いちょう|イチョウ|ライトアップ|夜間|入園|料金|開園|アクセス|交通|行き方|access|autumn|2026/i;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
let ok = 0;
for (const u of URLS) {
  console.log(`## ${u}\n`);
  const p = await ctx.newPage();
  try {
    await p.setViewportSize({ width: 1200, height: 1000 });
    const r = await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3500);   // 数字が後から入るのを待つ
    const t = (await p.evaluate(() => document.body.innerText)).replace(/\s+/g, ' ').trim();
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map(a => [a.innerText.trim().replace(/\s+/g,' ').slice(0,60), a.href]));
    ok++;
    console.log(`- status **${r ? r.status() : '?'}** / title: ${await p.title()} / 本文 ${t.length} 字\n`);
    const ls = [...new Map(links.filter(([x, h]) => x && (KEY.test(x) || KEY.test(h))).map(l => [l[1], l])).values()].slice(0, 30);
    if (ls.length) { console.log('**関係しそうなリンク**\n'); for (const [x, h] of ls) console.log(`- ${x} → ${h}`); console.log(''); }
    console.log('```text\n' + t.slice(0, 12000) + '\n```\n');
  } catch (e) {
    console.log(`⚠️ 取れない: ${String(e).slice(0, 160)}\n`);
  } finally { await p.close(); }
}
console.log('## X の投稿（syndication API）\n');
const IDS = ['2042499769181093991','2055505566760673539','2037806494008365090','2106073467598827578','2093285359593603488','2087389182394302924'];
for (const id of IDS) {
  try {
    const r = await fetch(`https://cdn.syndication.twimg.com/tweet-result?id=${id}&lang=ja&token=a`, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    const j = await r.json();
    console.log(`- **${id}** / ${j.user?.name} (@${j.user?.screen_name}) / ${j.created_at}\n  > ${(j.text || '').replace(/\s+/g, ' ')}`);
  } catch (e) { console.log(`- **${id}** ⚠️ 取れない: ${String(e).slice(0, 100)}`); }
}
console.log(`\n---\n\n**対象 ${URLS.length} / 取れた ${ok}**`);
await b.close().catch(() => {});
JS

RES="$RDIR/.t224-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
