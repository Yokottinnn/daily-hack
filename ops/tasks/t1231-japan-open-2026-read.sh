#!/bin/bash
# **ジャパンオープン2026（50m・競泳）の大会のページを読む（t1231）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-24 blog3 の湾岸ニュース japan-open-swimming-2026（2026年12月4日〜6日・東京アクアティクスセンター・江東区辰巳）。
# 日程・観戦の方法（チケットの有無・料金・販売先）・時間・中継を、日本水泳連盟（swim.or.jp）の一次情報で確かめる。
# クラウドからは swim.or.jp に TLS で繋がらないので、Mac の Chrome（CDP）で Cookie の無い新しいコンテキストで開く。ログインの要るページは開かない。
# 大会のページの URL は swim.or.jp のトップと大会一覧のリンクの文字から拾う。推測で組み立てない。本文は 1 ページ 6000 字まで。200 秒で打ち切る。

set -uo pipefail
TASK=t1231
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/$TASK-japan-open-2026.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ジャパンオープン2026（50m）の大会のページ（$TASK・**\$0**）"
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
    await p.waitForTimeout(2500);
    const ls = await p.evaluate(() => [...document.querySelectorAll('a')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80) })));
    console.log(`- 開けた: ${url}（リンク ${ls.length}）`);
    return ls;
  } catch (e) { console.log(`- ⚠️ 開けない: ${url}: ${String(e).slice(0, 120)}`); return []; }
}
for (const u of ['https://swim.or.jp/', 'https://swim.or.jp/compe/', 'https://swim.or.jp/tournament/']) {
  if (left() < 60000) break;
  for (const l of await links(u)) {
    if (/ジャパンオープン|japan.?open|japanopen/i.test(l.t + ' ' + l.h) && /swim\.or\.jp/.test(l.h) && !seen.has(l.h)) { seen.add(l.h); cand.push(l); }
  }
}
console.log(`\n## 大会のページの候補（${cand.length}）`);
for (const c of cand.slice(0, 12)) console.log(`- ${c.t} — ${c.h}`);
for (const c of cand.slice(0, 4)) {
  if (left() < 25000) { console.log('- ⏱ 時間切れ'); break; }
  try {
    await p.goto(c.h, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(2500);
    const r = await p.evaluate(() => ({
      title: document.title,
      text: (document.querySelector('main') || document.body).innerText.replace(/\n{2,}/g, '\n').slice(0, 6000),
      links: [...document.querySelectorAll('a')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) })).filter((l) => /チケット|ticket|観戦|入場|中継|配信|要項|pdf/i.test(l.t + ' ' + l.h)).slice(0, 25),
      imgs: [...document.querySelectorAll('img')].filter((i) => i.naturalWidth >= 500).map((i) => i.src).slice(0, 6),
    }));
    console.log(`\n## ${r.title}\n${c.h}\n\n\`\`\`text\n${r.text}\n\`\`\``);
    console.log('\n関係するリンク:');
    for (const l of r.links) console.log(`- ${l.t} — ${l.h}`);
    console.log('\n大きい画像:');
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
