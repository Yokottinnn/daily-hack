#!/bin/bash
# **高輪ゲートウェイシティの公式を読む（t220）。読むだけ・LLM 不使用・$0。**
#
# 記事案 #7。t212 で `takanawagatewaycity.com` に繋がらなかったのは、**正しい URL がハイフン入りの
# `takanawagateway-city.com`** だったため（検索で確定・2026-10-04）。公式トップとニュウマン高輪を描画し、
# フロア・ショップ・レストラン・駐車場・アクセス・施設のリンクを 1 段だけ辿る（1 サイト 5 ページまで）。
# 既存の Chrome に CDP で繋ぐ。260 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t220-takanawa-official.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 描画してから本文を読む（t220・**\$0**）"
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
SCRIPT="$RDIR/.t220-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const SEEDS = ["https://www.takanawagateway-city.com/", "https://www.newoman.jp/takanawa/"];
const KEY = /フロア|floor|ショップ|shop|レストラン|restaurant|グルメ|駐車|parking|アクセス|access|施設|facilit|営業時間|hours|MoN|ミュージアム/i;
const MAXSUB = 5;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
let ok = 0, total = 0;
async function read(u, depth) {
  total++;
  console.log(`${depth ? '###' : '##'} ${u}\n`);
  const p = await ctx.newPage();
  try {
    await p.setViewportSize({ width: 1200, height: 1000 });
    const r = await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3000);
    const t = (await p.evaluate(() => document.body.innerText)).replace(/\s+/g, ' ').trim();
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map(a => [a.innerText.trim().replace(/\s+/g, ' ').slice(0, 60), a.href]));
    ok++;
    console.log(`- status **${r ? r.status() : '?'}** / title: ${await p.title()} / 本文 ${t.length} 字\n`);
    console.log('```text\n' + t.slice(0, depth ? 6000 : 8000) + '\n```\n');
    return links;
  } catch (e) { console.log(`⚠️ 取れない: ${String(e).slice(0, 160)}\n`); return []; }
  finally { await p.close(); }
}
for (const s of SEEDS) {
  const links = await read(s, 0);
  const host = new URL(s).host;
  const subs = [...new Map(links.filter(([x, h]) => x && h.includes(host) && KEY.test(x) && !h.includes('#')).map(l => [l[1], l])).values()].slice(0, MAXSUB);
  console.log('**辿るリンク**\n'); for (const [x, h] of subs) console.log(`- ${x} → ${h}`); console.log('');
  for (const [, h] of subs) await read(h, 1);
}
console.log(`---\n\n**開いた ${total} / 読めた ${ok}**`);
await b.close().catch(() => {});
JS

RES="$RDIR/.t220-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 260 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
