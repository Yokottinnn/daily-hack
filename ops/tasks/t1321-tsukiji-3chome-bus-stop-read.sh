#!/bin/bash
# **都営バス「築地三丁目（晴海埠頭方向）バス停のりば変更のお知らせ」を読む（t1321）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-28 blog3 の湾岸ニュース（築地）。東京都交通局のお知らせ（2026-11-27 付）の本文で、変更の日・移る距離と向き・対象の系統を確かめる。
# クラウドからは kotsu.metro.tokyo.jp が Incapsula で弾かれるので、Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開く。ログインの要るページは開かない。
# お知らせの URL は交通局のバスのページ・お知らせ一覧のリンクの文字から拾う。推測で組み立てない。本文は 1 ページ 6000 字まで。200 秒で打ち切る。

set -uo pipefail
TASK=t1321
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/$TASK-tsukiji-3chome-bus-stop.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 都営バス 築地三丁目（晴海埠頭方向）のりば変更のお知らせ（$TASK・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **\`playwright-core\` がどちらにも無い。** ここで止める（最上位ルール 20）。" >> "$OUT"
  cat "$OUT"; exit 0
fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then
  echo "- ⚠️ **Chrome が CDP（$PORT）で応答しない。** ここで止める。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"

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

SCRIPT="$RDIR/.$TASK.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 190000 - (Date.now() - t0);
const seen = new Set();
const cand = [];
async function links(url) {
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3000);
    const ls = await p.evaluate(() => [...document.querySelectorAll('a')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 100) })));
    console.log(`- 開けた: ${url}（リンク ${ls.length}・題名「${(await p.title()).slice(0, 60)}」）`);
    return ls;
  } catch (e) { console.log(`- ⚠️ 開けない: ${url}: ${String(e).slice(0, 120)}`); return []; }
}
for (const u of ['https://www.kotsu.metro.tokyo.jp/bus/', 'https://www.kotsu.metro.tokyo.jp/bus/news/', 'https://www.kotsu.metro.tokyo.jp/', 'https://www.kotsu.metro.tokyo.jp/news/']) {
  if (left() < 80000) break;
  for (const l of await links(u)) {
    if (/築地三丁目|築地/.test(l.t) && !seen.has(l.h)) { seen.add(l.h); cand.push(l); }
  }
}
console.log(`\n## お知らせの候補（${cand.length}）`);
for (const c of cand.slice(0, 12)) console.log(`- ${c.t} — ${c.h}`);
const pick = cand.filter((c) => /築地三丁目/.test(c.t)).concat(cand.filter((c) => !/築地三丁目/.test(c.t)));
for (const c of pick.slice(0, 3)) {
  if (left() < 25000) { console.log('- ⏱ 時間切れ'); break; }
  if (/\.pdf($|\?)/i.test(c.h)) { console.log(`\n- PDF: ${c.h}（本文は読まない。URL だけ）`); continue; }
  try {
    await p.goto(c.h, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(2500);
    const r = await p.evaluate(() => ({
      title: document.title,
      text: (document.querySelector('main') || document.querySelector('#contents') || document.body).innerText.replace(/\n{2,}/g, '\n').slice(0, 6000),
      links: [...document.querySelectorAll('a')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) })).filter((l) => /pdf|地図|案内|のりば|築地/i.test(l.t + ' ' + l.h)).slice(0, 20),
      imgs: [...document.querySelectorAll('img')].filter((i) => i.naturalWidth >= 300).map((i) => `${i.src}（${i.naturalWidth}x${i.naturalHeight}・alt「${(i.alt || '').slice(0, 60)}」）`).slice(0, 8),
    }));
    console.log(`\n## ${r.title}\n${c.h}\n\n\`\`\`text\n${r.text}\n\`\`\``);
    console.log('\n関係するリンク:');
    for (const l of r.links) console.log(`- ${l.t} — ${l.h}`);
    console.log('\n画像:');
    for (const i of r.imgs) console.log(`- ${i}`);
  } catch (e) { console.log(`- ⚠️ 読めない ${c.h}: ${String(e).slice(0, 120)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.$TASK-res.txt"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?（rc は証拠にならない。下の本文で見る）" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"
echo "出力の長さ: $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 20000 "$OUT"
