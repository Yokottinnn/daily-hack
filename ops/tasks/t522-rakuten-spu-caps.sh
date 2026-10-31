#!/bin/bash
# **楽天の最大倍率の記事のために、SPU の「対象サービス・達成条件」の表を行ごとに読み（月間獲得上限の対応を取る）、お買い物マラソンと SPU の FAQ の「上限」の答えを開いて読む（t522）。読むだけ・LLM 不使用・$0。**
# 2026-10-31 利用者「楽天ポイントが最大18.3倍みたいな状態の時に、どうやったら最大ポイント倍率になるかの詳細をまとめた記事を作って」。t521 の本文では上限の数字がどの特典のものか対応が取れなかった。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t522-rakuten-caps.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 楽天 SPU の月間上限と FAQ（t522・**\$0**）"
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
SCRIPT="$RDIR/.t522-prices.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const fs = await import('node:fs');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 });
const DIR = process.env.SHOT_DIR; fs.mkdirSync(DIR, { recursive: true });
const t0 = Date.now();
async function open(u){ await p.goto(u,{waitUntil:'domcontentloaded',timeout:25000}).catch(e=>console.log(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`)); await p.waitForTimeout(4000); }
// ① SPU の表を行ごと
await open('https://event.rakuten.co.jp/campaign/point-up/everyday/point/');
const rows = await p.evaluate(()=>[...document.querySelectorAll('table')].map((tb,ti)=>[...tb.querySelectorAll('tr')].map(tr=>`T${ti}| `+[...tr.children].map(c=>c.innerText.replace(/\s+/g,' ').trim()).join(' | ')).filter(x=>x.length<600)).flat()).catch(()=>[]);
console.log(`\n## SPU の表（${rows.length} 行）`); for (const r of rows.slice(0,120)) console.log(`- ${r.slice(0,420)}`);
// 表が無いときのために、「月間獲得上限」の近くの塊を出す
const blocks = await p.evaluate(()=>[...document.querySelectorAll('li,div,dl,section')].filter(e=>/月間獲得上限|上限なし/.test(e.innerText||'') && (e.innerText||'').length<900).map(e=>e.innerText.replace(/\s+/g,' ').trim())).catch(()=>[]);
const uniq=[...new Set(blocks)].sort((a,b)=>a.length-b.length).slice(0,25);
console.log(`\n## 「上限」を含む小さい塊（${uniq.length}）`); for (const u of uniq) console.log(`- ${u.slice(0,600)}`);
// ② FAQ の「上限」を開いて読む
for (const u of ['https://event.rakuten.co.jp/campaign/point-up/everyday/point/','https://event.rakuten.co.jp/campaign/point-up/marathon/guide/']) {
  if (Date.now()-t0>190000) { console.log('- ⏱ 時間切れ'); break; }
  await open(u);
  const qs = p.locator('text=/上限/');
  const n = Math.min(await qs.count().catch(()=>0), 12);
  for (let i=0;i<n;i++){ await qs.nth(i).click({timeout:2000}).catch(()=>{}); await p.waitForTimeout(400); }
  const ans = await p.evaluate(()=>{const t=(document.body.innerText||'').split('\n').map(x=>x.trim()).filter(Boolean); const out=[]; t.forEach((x,i)=>{ if(/上限/.test(x)) out.push(t.slice(i,i+6).join(' ／ ')); }); return [...new Set(out)].filter(x=>!/あなた|保有|現在の/.test(x)).slice(0,30);}).catch(()=>[]);
  console.log(`\n## FAQ（上限）｜${u}`); for (const a of ans) console.log(`- ${a.slice(0,500)}`);
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t522-res.txt"
SHOT_DIR="$RDIR/t522-shots" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
head -c 12000 "$OUT"
