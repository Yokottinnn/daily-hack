#!/bin/bash
# **大掃除のハウスクリーニング比較の記事のために、ナックダスキン・キレイユ・ミガクるの公式の料金を読む（URL は t488 で A8 の詳細から取った）（t489）。読むだけ・LLM 不使用・$0。**
# 2026-10-31 利用者がダイアログで「大掃除のハウスクリーニング比較」を選んだ。A8 の提携詳細から広告主のサイトを辿り、料金・メニューのページの「円」を含む行を出す。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t489-cleaning-prices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ハウスクリーニング 3 社の公式の料金（t489・**\$0**）"
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
SCRIPT="$RDIR/.t489-prices.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const PAGES = [['ナックダスキン', ['https://nac-duskin.com/duskin-acclean/', 'https://nac-duskin.com/duskin-bathcleaning/', 'https://nac-duskin.com/duskin-kitchencleaning', 'https://nac-duskin.com/duskin-toiletcleaning/', 'https://nac-duskin.com/duskin-homecleaning/']], ['キレイユ', ['https://kireiyu.com/', 'https://kireiyu.com/area/']], ['ミガクる', ['https://migxl.com/']]];
const SVC = /エアコン|浴室|お風呂|風呂釜|キッチン|レンジフード|換気扇|料金|価格|メニュー|まとめて|セット|トイレ|洗面/;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const t0 = Date.now();
const read = async (u) => {
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch((e) => console.log(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`));
  await p.waitForTimeout(3000);
  return p.evaluate(() => ({
    url: location.href, title: document.title,
    yen: [...new Set((document.body.innerText || '').split('\n').map((x) => x.trim()).filter((x) => /[0-9０-９,，]+\s*円/.test(x) && x.length < 140))].slice(0, 70),
    links: [...document.querySelectorAll('a[href]')].map((a) => ({ t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 50), h: a.href })),
    imgs: [...document.querySelectorAll('img')].filter((i) => i.naturalWidth >= 600).map((i) => `${i.naturalWidth}x${i.naturalHeight} ${i.currentSrc || i.src}`).slice(0, 8),
  })).catch(() => ({ url: u, title: '（読めない）', yen: [], links: [], imgs: [] }));
};
for (const [name, urls] of PAGES) {
  console.log(`\n## ${name}\n`);
  const seen = new Set(urls);
  const queue = [...urls];
  let n = 0;
  while (queue.length && n < 9) {
    if (Date.now() - t0 > 70000 * (PAGES.findIndex((x) => x[0] === name) + 1)) { console.log('- ⏱ この社の持ち時間が切れた'); break; }
    const u = queue.shift(); n++;
    const s = await read(u);
    console.log(`\n### ${s.title}\n- ${s.url}`, ...s.yen.map((x) => `  - ${x}`), ...s.imgs.map((x) => `  - 画像 ${x}`));
    const host = new URL(s.url).host;
    for (const l of s.links) if (SVC.test(l.t) && l.h.includes(host) && !l.h.includes('#') && !seen.has(l.h) && seen.size < 14) { seen.add(l.h); queue.push(l.h); console.log(`  - リンク ${l.t}=${l.h}`); }
  }
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t489-res.txt"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
cp "$OUT" "$RDIR/t489-cleaning-prices.md" 2>/dev/null
head -c 12000 "$OUT"
