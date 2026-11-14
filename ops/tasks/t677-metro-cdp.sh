#!/bin/bash
# **東京メトロ・都営地下鉄の駅別乗降人員のページを Chrome で開いて取る（t677）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-15 利用者「あらためて上記を徹底して記事の候補作成と実際の作成に取り組んで」。t675 は curl だと両社とも Bot 対策（Akamai・Incapsula）で読めなかったので、Mac の Chrome（CDP）で開いて HTML と張られた PDF・Excel を保存する。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t677-metro-cdp.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 東京の地下鉄の駅別乗降人員（t677・**\$0**）"
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

D="$RDIR/t677"; mkdir -p "$D"
SCRIPT="$RDIR/.t677.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [['metro','https://www.tokyometro.jp/corporate/enterprise/passenger_rail/transportation/passengers/index.html'],['toei','https://www.kotsu.metro.tokyo.jp/subway/kanren/passengers.html']];
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(6000);
    const html = await p.content();
    fs.writeFileSync(`${D}/${k}.html`, html);
    console.log(`- ${k}: ${html.length} 文字 「${(await p.title()).slice(0,60)}」`);
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map(a => [a.href, a.textContent.replace(/\s+/g,' ').trim().slice(0,60)]).filter(([h]) => /\.(pdf|xlsx?|csv)(\?|$)/i.test(h)));
    console.log(`  ファイルのリンク ${links.length} 本`);
    for (const [h,t] of links.slice(0,40)) console.log(`  ${h} | ${t}`);
    let n=0;
    for (const [h] of links.slice(0,6)) {
      try {
        const b64 = await p.evaluate(async (url) => { const r = await fetch(url, {credentials:'include'}); const a = new Uint8Array(await r.arrayBuffer()); let s=''; for (let i=0;i<a.length;i+=32768) s+=String.fromCharCode.apply(null, a.subarray(i,i+32768)); return [r.status, btoa(s)]; }, h);
        const ext = (h.match(/\.(pdf|xlsx?|csv)/i)||['','bin'])[1];
        const buf = Buffer.from(b64[1], 'base64'); fs.writeFileSync(`${D}/${k}-${n}.${ext}`, buf);
        console.log(`  保存 ${k}-${n}.${ext} ← ${h} → ${b64[0]} ${buf.length} bytes ${buf.slice(0,5).toString('latin1').replace(/[^A-Za-z%<!-]/g,'')}`); n++;
      } catch (e) { console.log(`  ⚠️ 取れない ${h}: ${String(e).slice(0,100)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${k} を開けない: ${String(e).slice(0,120)}`); }
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t677-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 9000 "$OUT"
