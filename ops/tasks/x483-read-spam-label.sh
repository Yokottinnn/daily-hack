#!/bin/bash
# x483（2026-11-14・読むだけ・$0）: X のスパム（プラットフォーム操作）のラベルが付いたまま か、外れたかを見る。
# 通知のページと自分のプロフィールを描画して、ラベル・審査・制限に関わる文だけを抜き出す（他人の名前は出さない）。何も押さない。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/x483-read-spam-label.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
echo "# スパムのラベルが残っているか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）" > "$OUT"
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then echo "playwright-core が無い。止める" >> "$OUT"; cat "$OUT"; exit 0; fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then echo "Chrome が CDP（$PORT）で応答しない。止める" >> "$OUT"; cat "$OUT"; exit 0; fi
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
SCRIPT="$RDIR/.x483-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const KEY = /ラベル|プラットフォーム操作|スパム|審査|制限|一時的|表示範囲|label|spam|manipulation|restrict|review/i;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
for (const [name, url] of [['通知', 'https://x.com/notifications'], ['自分のプロフィール', 'https://x.com/heng_ji31590']]) {
  const p = await ctx.newPage();
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(5000);
    if (/login|i\/flow/.test(p.url())) { console.log(`## ${name}\n- ログインが切れている`); continue; }
    const lines = await p.evaluate(() => (document.querySelector('main') || document.body).innerText.split('\n').map(s => s.trim()).filter(Boolean));
    const hit = lines.filter(l => /ラベル|プラットフォーム操作|スパム|審査|制限|一時的|表示範囲|label|spam|manipulation|restrict|review/i.test(l));
    console.log(`## ${name}（${url.replace('https://', '')}）\n- 読めた行 ${lines.length}・当てはまった行 ${hit.length}`);
    for (const l of [...new Set(hit)].slice(0, 15)) console.log('  - ' + l.replace(/@[A-Za-z0-9_]{2,15}/g, m => m === '@heng_ji31590' ? m : '@<伏せ>').slice(0, 160));
    console.log('');
  } catch (e) { console.log(`## ${name}\n- 開けない: ${String(e).slice(0, 120)}`); } finally { await p.close(); }
}
await b.close().catch(() => {});
JS
RES="$RDIR/.x483-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 120 node "$SCRIPT" > "$RES" 2>&1
echo "終了コード $?" >> "$OUT"; echo >> "$OUT"
cat "$RES" >> "$OUT" 2>/dev/null
rm -f "$SCRIPT" "$RES"
echo >> "$OUT"; echo "何も押していない。LLM 不使用・\$0。" >> "$OUT"
grep -E '当てはまった行|ログインが切れ|開けない' "$OUT" | head -3 | cut -c1-120
exit 0
