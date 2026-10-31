#!/bin/bash
# **大掃除のハウスクリーニング比較の記事のために、4 社のロゴを取り、ナックダスキンの浴室・キッチンの料金を本文から読む（t491）。読むだけ・LLM 不使用・$0。**
# 2026-10-31 利用者がダイアログで「大掃除のハウスクリーニング比較」を選んだ。A8 の提携詳細から広告主のサイトを辿り、料金・メニューのページの「円」を含む行を出す。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t491-cleaning-prices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# ハウスクリーニング 3 社の公式の料金（t491・**\$0**）"
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
SCRIPT="$RDIR/.t491-prices.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const fs = await import('node:fs');
const DIR = process.env.LOGO_DIR; fs.mkdirSync(DIR, { recursive: true });
const man = {};
for (const [key, brand, u] of [['yourmystar', 'ユアマイスター', 'https://yourmystar.jp/'], ['duskin', 'ダスキン（ナックダスキン）', 'https://nac-duskin.com/duskin-acclean/'], ['kireiyu', 'キレイユ', 'https://kireiyu.com/'], ['migxl', 'ミガクる', 'https://migxl.com/']]) {
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
  await p.waitForTimeout(3000);
  const cands = await p.evaluate(() => [...document.querySelectorAll('img, link[rel*=icon], meta[property="og:image"]')].map((e) => ({ src: e.currentSrc || e.src || e.href || e.content || '', alt: e.alt || '', cls: (e.className || '') + ' ' + (e.parentElement?.className || ''), w: e.naturalWidth || 0, h: e.naturalHeight || 0, tag: e.tagName })).filter((x) => x.src && /logo|ロゴ|icon|og:image/i.test(x.src + ' ' + x.alt + ' ' + x.cls + ' ' + x.tag)).slice(0, 6));
  console.log(`\n## ${brand}\n- ${p.url()}`);
  let i = 0;
  for (const c of cands) {
    i++;
    const r = await p.request.get(c.src).catch(() => null);
    if (!r || !r.ok()) { console.log(`- ⚠️ 取れない ${c.src}`); continue; }
    const body = await r.body();
    const ext = (/\.svg/i.test(c.src) || body.slice(0, 200).toString().includes('<svg')) ? 'svg' : (/\.webp/i.test(c.src) ? 'webp' : (/\.jpe?g/i.test(c.src) ? 'jpg' : 'png'));
    const name = `${key}-${i}.${ext}`;
    fs.writeFileSync(`${DIR}/${name}`, body);
    man[name] = { brand, src: c.src, page: p.url(), alt: c.alt, fetched: new Date().toISOString().slice(0, 10), task: 'ops/tasks/t491-cleaning-logos-duskin.sh' };
    console.log(`- ${name} ${body.length} bytes ${c.w}x${c.h} alt=${c.alt} ${c.src}`);
  }
}
fs.writeFileSync(`${DIR}/_manifest.json`, JSON.stringify(man, null, 2));
for (const u of ['https://nac-duskin.com/duskin-bathcleaning/', 'https://nac-duskin.com/duskin-kitchencleaning/', 'https://nac-duskin.com/duskin-acclean/']) {
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
  await p.waitForTimeout(3000);
  const t = await p.evaluate(() => (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean));
  const idx = t.map((x, i) => (/円|税込|料金|価格|台|㎡|m2|プラン|セット|対象エリア|対応エリア/.test(x) ? i : -1)).filter((i) => i >= 0);
  const keep = [...new Set(idx.flatMap((i) => [i - 1, i, i + 1]))].filter((i) => i >= 0 && i < t.length).sort((a, b) => a - b);
  const alts = await p.evaluate(() => [...document.querySelectorAll('img[alt]')].map((i) => i.alt.trim()).filter((a) => /円|料金|価格/.test(a)));
  console.log(`\n## 本文 ${u}\n`, ...keep.slice(0, 80).map((i) => `\n  - ${t[i].slice(0, 140)}`), ...alts.slice(0, 20).map((a) => `\n  - 画像の alt: ${a.slice(0, 140)}`));
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t491-res.txt"
LOGO_DIR="$RDIR/t491-logos" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
cp "$OUT" "$RDIR/t491-cleaning-prices.md" 2>/dev/null
head -c 12000 "$OUT"
