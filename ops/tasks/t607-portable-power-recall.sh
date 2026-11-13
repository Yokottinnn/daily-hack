#!/bin/bash
# **ポータブル電源のリコールを公的なサイトで検索して読む（t607・blog3）。読むだけ・LLM 不使用・$0。**
#
# t605 では消費者庁・経済産業省・NITE のページが「別のナビゲーションで中断」で読めなかった。今回は goto の失敗を無視して読み込みを待ち、消費者庁はトップの検索欄にメーカー名を入れて結果を読む。Mac の Chrome で描画して、本文の行と画像の URL を書き出す。推測で埋めない（最上位ルール 20）。
# 全体で 260 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t607-portable-power-recall.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ポータブル電源のリコールを検索する（t607・**\$0**）"
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

SCRIPT="$RDIR/.t607-read.mjs"
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
const KW = ['Jackery','EcoFlow','エコフロー','Anker','アンカー','ポータブル電源'];
const RE = /ポータブル電源|Jackery|ジャクリ|EcoFlow|エコフロー|Anker|アンカー|リン酸|回収|交換|発火|発煙|リコール|対象|型番|年|月/;
async function dump(label) {
  await p.waitForTimeout(7000);
  const info = await p.evaluate((src) => {
    const re = new RegExp(src);
    const lines = document.body ? document.body.innerText.split('\n').map(s => s.replace(/\s+/g, ' ').trim()).filter(Boolean) : [];
    return { title: document.title, final: location.href, n: lines.length, hit: lines.filter(s => re.test(s)).slice(0, 60) };
  }, RE.source);
  console.log(`## ${label}\n\n- 題名: ${info.title} ／ 最終 URL: ${info.final.slice(0, 160)} ／ 行数 ${info.n}\n`);
  console.log('```text\n' + (info.hit.join('\n') || '（それらしい行が 0 件）') + '\n```\n');
}
async function go(url) { try { await p.goto(url, { waitUntil: 'load', timeout: 30000 }); } catch (e) { console.log(`- goto: ${String(e).slice(0, 120)}`); } }
for (const kw of KW) {
  if (Date.now() - T0 > 200000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  await go('https://www.recall.caa.go.jp/');
  await p.waitForTimeout(4000);
  let ok = false;
  try {
    const box = await p.$('input[type="search"], input[name*="keyword" i], input[name*="word" i], input[type="text"]');
    if (box) { await box.fill(kw); await box.press('Enter'); ok = true; }
  } catch (e) { console.log(`- 検索欄: ${String(e).slice(0, 120)}`); }
  await dump(`消費者庁 リコール情報サイト「${kw}」${ok ? '' : '（検索欄が見つからない）'}`);
}
for (const [label, url] of [['NITE リコール情報', 'https://www.nite.go.jp/jiko/chuikanki/recall/index.html'], ['経済産業省 リコール一覧', 'https://www.meti.go.jp/product_safety/recall/index.html']]) {
  if (Date.now() - T0 > 235000) break;
  await go(url); await dump(label);
}
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t607-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 260 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。買い物はしない。" >> "$OUT"
cat "$OUT"
