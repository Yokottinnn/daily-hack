#!/bin/bash
# **ロボット掃除機の比較記事の 3 店ボタン（楽天・Yahoo!・Amazon）の行き先を Mac の Chrome で開いて確かめる（t801）。** 読むだけ・ログインの要るページは開かない・LLM 不使用・$0／回・$0／日・$0／月。
# ブリーフ（2026-11-22）「作ったリンクは遷移先を Mac で確かめる」。着いた URL・ページの題名・型番が何回出るか・上位 3 件の商品名だけを出す（本文は保存しない）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t801-robot-cleaner-shop-links.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ロボット掃除機の 3 店ボタンの行き先（t801・**\$0**）"
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

LJSON="$RDIR/.t801-links.json"
cat > "$LJSON" <<'JSON'
[["F155260", "https://hb.afl.rakuten.co.jp/hgc/587f2635.77bb335f.587f2636.e34c8733/?pc=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2F%25E3%2583%25AB%25E3%2583%25B3%25E3%2583%2590%2520%25E3%2583%259F%25E3%2583%258B%2520F155260%2F&m=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2F%25E3%2583%25AB%25E3%2583%25B3%25E3%2583%2590%2520%25E3%2583%259F%25E3%2583%258B%2520F155260%2F"], ["X285060", "https://hb.afl.rakuten.co.jp/hgc/587f2635.77bb335f.587f2636.e34c8733/?pc=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2F%25E3%2583%25AB%25E3%2583%25B3%25E3%2583%2590%2520Max%2520775%2520Combo%2520X285060%2F&m=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2F%25E3%2583%25AB%25E3%2583%25B3%25E3%2583%2590%2520Max%2520775%2520Combo%2520X285060%2F"], ["T90", "https://hb.afl.rakuten.co.jp/hgc/587f2635.77bb335f.587f2636.e34c8733/?pc=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FDEEBOT%2520T90%2520MAX%2520OMNI%2F&m=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FDEEBOT%2520T90%2520MAX%2520OMNI%2F"], ["C10", "https://hb.afl.rakuten.co.jp/hgc/587f2635.77bb335f.587f2636.e34c8733/?pc=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FEufy%2520Robot%2520Vacuum%2520Auto-Empty%2520C10%2F&m=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FEufy%2520Robot%2520Vacuum%2520Auto-Empty%2520C10%2F"], ["C28", "https://hb.afl.rakuten.co.jp/hgc/587f2635.77bb335f.587f2636.e34c8733/?pc=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FEufy%2520Robot%2520Vacuum%2520Omni%2520C28%2F&m=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FEufy%2520Robot%2520Vacuum%2520Omni%2520C28%2F"], ["Saros 20", "https://hb.afl.rakuten.co.jp/hgc/587f2635.77bb335f.587f2636.e34c8733/?pc=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FRoborock%2520Saros%252020%2F&m=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FRoborock%2520Saros%252020%2F"], ["K11", "https://hb.afl.rakuten.co.jp/hgc/587f2635.77bb335f.587f2636.e34c8733/?pc=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FSwitchBot%2520%25E3%2583%25AD%25E3%2583%259C%25E3%2583%2583%25E3%2583%2588%25E6%258E%2583%25E9%2599%25A4%25E6%25A9%259F%2520K11%252B%2F&m=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FSwitchBot%2520%25E3%2583%25AD%25E3%2583%259C%25E3%2583%2583%25E3%2583%2588%25E6%258E%2583%25E9%2599%25A4%25E6%25A9%259F%2520K11%252B%2F"], ["F155260", "https://shopping.yahoo.co.jp/search?p=%E3%83%AB%E3%83%B3%E3%83%90%20%E3%83%9F%E3%83%8B%20F155260"], ["X285060", "https://shopping.yahoo.co.jp/search?p=%E3%83%AB%E3%83%B3%E3%83%90%20Max%20775%20Combo%20X285060"], ["T90", "https://shopping.yahoo.co.jp/search?p=DEEBOT%20T90%20MAX%20OMNI"], ["C10", "https://shopping.yahoo.co.jp/search?p=Eufy%20Robot%20Vacuum%20Auto-Empty%20C10"], ["C28", "https://shopping.yahoo.co.jp/search?p=Eufy%20Robot%20Vacuum%20Omni%20C28"], ["Saros 20", "https://shopping.yahoo.co.jp/search?p=Roborock%20Saros%2020"], ["K11", "https://shopping.yahoo.co.jp/search?p=SwitchBot%20%E3%83%AD%E3%83%9C%E3%83%83%E3%83%88%E6%8E%83%E9%99%A4%E6%A9%9F%20K11%2B"], ["T90", "https://www.amazon.co.jp/s?k=%E3%82%A8%E3%82%B3%E3%83%90%E3%83%83%E3%82%AF%E3%82%B9%20DEEBOT%20T90%20MAX%20OMNI&tag=dailyhack-22"], ["X285060", "https://www.amazon.co.jp/s?k=%E3%83%AB%E3%83%B3%E3%83%90%20Max%20775%20Combo%20X285060&tag=dailyhack-22"], ["F155260", "https://www.amazon.co.jp/s?k=%E3%83%AB%E3%83%B3%E3%83%90%20Mini%20F155260&tag=dailyhack-22"], ["C10", "https://www.amazon.co.jp/s?k=Eufy%20Robot%20Vacuum%20Auto-Empty%20C10&tag=dailyhack-22"], ["C28", "https://www.amazon.co.jp/s?k=Eufy%20Robot%20Vacuum%20Omni%20C28&tag=dailyhack-22"], ["Saros 20", "https://www.amazon.co.jp/s?k=Roborock%20Saros%2020&tag=dailyhack-22"], ["K11", "https://www.amazon.co.jp/s?k=SwitchBot%20%E3%83%AD%E3%83%9C%E3%83%83%E3%83%88%E6%8E%83%E9%99%A4%E6%A9%9F%20K11%2B&tag=dailyhack-22"]]
JSON
SCRIPT="$RDIR/.t801.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const L = JSON.parse(fs.readFileSync(process.env.LJSON, 'utf8'));
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const t0 = Date.now();
let n = 0;
for (const [key, url] of L) {
  if (Date.now() - t0 > 200000) { console.log('- ⏱ 時間切れ'); break; }
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3500);
    const r = await p.evaluate((k) => {
      const t = document.body ? document.body.innerText : '';
      const names = [...document.querySelectorAll('h2 a, [class*="title"] a, a h2, [data-testid*="title"]')].map((e) => e.textContent.trim()).filter((s) => s.length > 8 && s.includes(k)).slice(0, 3);
      return { title: document.title.slice(0, 80), hits: t.split(k).length - 1, names };
    }, key);
    const host = new URL(p.url()).host;
    const tagOk = /tag=dailyhack-22|scid=af_|sc_e=afvc|valuecommerce/.test(p.url()) ? '計測の印あり' : '計測の印なし';
    n++;
    console.log(`- **${key}** ${host} — 型番の出現 ${r.hits} 回 — ${tagOk}\n  - 着いた先: ${p.url().slice(0, 160)}\n  - 題名: ${r.title}\n  - 上位: ${r.names.map((s) => s.slice(0, 60)).join(' / ') || '（取れず）'}`);
  } catch (e) { console.log(`- **${key}** ⚠️ ${String(e).slice(0, 120)} ${url.slice(0, 100)}`); }
}
console.log(`\n対象 ${L.length} / 開けた ${n}`);
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t801-res.txt"
LJSON="$LJSON" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
head -c 9000 "$OUT"
