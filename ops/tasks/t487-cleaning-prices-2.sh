#!/bin/bash
# **大掃除のハウスクリーニング比較の記事のために、ナックダスキン・キレイユの公式サイトを A8 の詳細の本文から探して料金を読む（t487）。読むだけ・LLM 不使用・$0。**
# 2026-10-31 利用者がダイアログで「大掃除のハウスクリーニング比較」を選んだ。A8 の提携詳細から広告主のサイトを辿り、料金・メニューのページの「円」を含む行を出す。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t487-cleaning-prices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ハウスクリーニング 3 社の公式の料金（t487・**\$0**）"
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
SCRIPT="$RDIR/.t487-prices.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const PROGS = [['ナックダスキン', 's00000023342001', ''], ['キレイユ', 's00000020635004', ''], ['ミガクる', 's00000020635003', '']];
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
for (const [name, id, seed] of PROGS) {
  console.log(`\n## ${name}\n`);
  let home = seed;
  const d = await read(`https://media-console.a8.net/program/detail-partnered?programId=${id}`);
  // t486 では足元のリンク（A8 の運営会社）を拾った。本文の中の URL を読む
  const body = await p.evaluate(() => (document.querySelector('main, #main, .main, .contents') || document.body).innerText).catch(() => '');
  console.log('- A8 の詳細の本文（URL・サイト・広告主を含む行）:', ...body.split('\n').map((x) => x.trim()).filter((x) => /https?:\/\/|サイト|広告主|URL/.test(x) && x.length < 160).slice(0, 15).map((x) => `\n  - ${x}`));
  const ext = [...body.matchAll(/https?:\/\/[^\s"'<>）)]+/g)].map((m) => m[0]).filter((h) => !/a8\.net|fancs\.com|google|twitter|facebook|line\.me/.test(h));
  console.log(`- A8 の詳細から見えた外部リンク: ${[...new Set(ext)].slice(0, 6).join(' / ') || '無し'}`);
  if (!home) home = ext[0] || '';
  if (!home) { console.log('- 公式サイトが分からない。ここで止める'); continue; }
  const top = await read(home);
  console.log(`### ${top.title}\n- ${top.url}`, ...top.yen.map((x) => `  - ${x}`));
  const host = new URL(top.url).host;
  const subs = [...new Map(top.links.filter((l) => SVC.test(l.t) && l.h.includes(host) && !l.h.includes('#')).map((l) => [l.h, l])).values()].slice(0, 9);
  console.log(`- 料金・メニューらしいリンク: ${subs.map((l) => `${l.t}=${l.h}`).join(' ／ ') || '無し'}`);
  for (const l of subs) {
    if (Date.now() - t0 > 215000) { console.log('- ⏱ 時間切れ'); break; }
    const s = await read(l.h);
    console.log(`\n### ${l.t}｜${s.title}\n- ${s.url}`, ...s.yen.map((x) => `  - ${x}`), ...s.imgs.map((x) => `  - 画像 ${x}`));
  }
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t487-res.txt"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
cp "$OUT" "$RDIR/t487-cleaning-prices.md" 2>/dev/null
head -c 12000 "$OUT"
