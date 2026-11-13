#!/bin/bash
# **ポータブル電源のリコールの中身を読む（t608・blog3）。読むだけ・LLM 不使用・$0。**
#
# t607 で消費者庁のトップに「EcoFlow Technology Japan「ポータブル電源：EcoFlow RIVER Pro、…」」が出ていた。その詳細を開いて対象の型番を読む。経済産業省のリコール一覧は全行からポータブル電源・3 社の名前の行だけを拾う。Mac の Chrome で描画して、本文の行と画像の URL を書き出す。推測で埋めない（最上位ルール 20）。
# 全体で 260 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t608-portable-power-recall-detail.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ポータブル電源のリコールの中身を読む（t608・**\$0**）"
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

# ── 描画して読む ──
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

SCRIPT="$RDIR/.t608-read.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1300, height: 1600 });
const q = (s) => encodeURIComponent(s);
async function go(url) { try { await p.goto(url, { waitUntil: 'load', timeout: 30000 }); } catch (e) { console.log(`- goto: ${String(e).slice(0, 120)}`); } await p.waitForTimeout(6000); }
const NAME = /ポータブル電源|蓄電池|Jackery|ジャクリ|EcoFlow|エコフロー|Anker|アンカー/;
// ① 消費者庁のトップから EcoFlow の詳細へ
await go('https://www.recall.caa.go.jp/');
const links = await p.evaluate(() => [...document.querySelectorAll('a')].map(a => ({ t: a.innerText.replace(/\s+/g, ' ').trim(), h: a.href })).filter(x => /EcoFlow|ポータブル電源/.test(x.t)));
console.log('## 消費者庁トップのリンク\n\n```text\n' + links.map(x => x.t + ' → ' + x.h).join('\n') + '\n```\n');
const seen = new Set();
for (const l of links) {
  if (seen.has(l.h) || seen.size >= 2) continue; seen.add(l.h);
  await go(l.h);
  const t = await p.evaluate(() => document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 140));
  console.log(`## 詳細: ${l.t}\n\n${l.h}\n\n` + '```text\n' + t.join('\n') + '\n```\n');
}
// ② 経済産業省のリコール一覧（全行から名前の行だけ）
await go('https://www.meti.go.jp/product_safety/recall/index.html');
const m = await p.evaluate((src) => { const re = new RegExp(src); const L = document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean); return { n: L.length, hit: L.filter(s => re.test(s)) }; }, NAME.source);
console.log(`## 経済産業省 リコール一覧（全 ${m.n} 行から）\n\n` + '```text\n' + (m.hit.join('\n') || '（0 件）') + '\n```\n');
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t608-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 260 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。買い物はしない。" >> "$OUT"
cat "$OUT"
