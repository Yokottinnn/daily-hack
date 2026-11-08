#!/bin/bash
# **JAL のツアーと別々の予約の記事の下調べ（t593・blog3）。読むだけ・予約しない・LLM 不使用・$0。**
#
# J-TRIP・JAL ダイナミックパッケージ・JAL 国内線・エアトリ国内ツアーの検索ページを Mac の Chrome で開き、
# 検索フォームの項目（name・選択肢）と、検索結果ページへのリンクの形を書き出す。値段を読む本番のタスクは、この結果を見てから作る（推測で URL を組まない）。
# 全体で 200 秒で打ち切る（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t593-jal-tour-probe.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# JAL のツアーと別々の予約の下調べ（t593・**\$0**）"
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

SCRIPT="$RDIR/.t593-read.mjs"
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
const PAGES = [
  ['J-TRIP トップ', 'https://www.jtrip.co.jp/'],
  ['JAL ダイナミックパッケージ', 'https://www.jal.co.jp/jp/ja/domtour/'],
  ['JAL 国内線 トップ', 'https://www.jal.co.jp/jp/ja/dom/'],
  ['エアトリ 国内ツアー', 'https://tour.airtrip.jp/'],
];
for (const [name, url] of PAGES) {
  if (Date.now() - T0 > 180000) { console.log('⚠️ **時間切れで打ち切り**'); break; }
  console.log(`## ${name}\n\n${url}\n`);
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(6000);
    const info = await p.evaluate(() => {
      const forms = [...document.forms].slice(0, 6).map(f => ({ action: f.action, method: f.method,
        fields: [...f.elements].filter(e => e.name).slice(0, 40).map(e => e.name + (e.tagName === 'SELECT' ? '=[' + [...e.options].slice(0, 6).map(o => o.value).join('|') + ']' : (e.value ? '=' + String(e.value).slice(0, 30) : ''))) }));
      const links = [...document.querySelectorAll('a[href]')].map(a => a.href).filter(h => /search|result|plan|tour|dp|list|kensaku/i.test(h)).slice(0, 25);
      return { title: document.title, final: location.href, forms, links };
    });
    console.log(`- HTTP ${r ? r.status() : '?'} ／ 題名: ${info.title.slice(0, 80)} ／ 最終: ${info.final.slice(0, 120)}\n`);
    console.log('```text\n' + info.forms.map(f => `FORM ${f.method} ${f.action}\n  ` + f.fields.join('\n  ')).join('\n') + '\n--- リンク ---\n' + [...new Set(info.links)].join('\n') + '\n```\n');
  } catch (e) { console.log(`⚠️ 開けない: ${String(e).slice(0, 140)}\n`); }
}
await p.close().catch(() => {});
await b.close().catch(() => {});
JS

RES="$RDIR/.t593-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。予約はしない。" >> "$OUT"
cat "$OUT"
