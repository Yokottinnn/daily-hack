#!/bin/bash
# **湾岸ニュースの 3 本に載せる X の投稿を探す（t331）。読むだけ・LLM 不使用・$0。**
#
# 利用者（2026-10-25）「X や YouTube、インスタで特集されている投稿を実際に探してきて、どんなことを言っているかまとめて掲載して。
# すべての湾岸ライフ記事で同じように拾ってくるようにして」。話題順と最新順の両方で拾い、syndication API で本文・投稿者・日付を確かめる。
# YouTube はクラウド側で探す。Instagram は Mac の Chrome が未ログインで読めないので、ここでは X だけ。240 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t331-momiji-x-voices.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 描画してから本文を読む（t331・**\$0**）"
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
SCRIPT="$RDIR/.t331-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const SPOTS = ['ぼうさいモーターショー', '防災公園 有明 消防車', '東京クリスマスマーケット 新豊洲', '東京クリスマスマーケット 豊洲', 'THE DOG PARK TOYOSU', 'ドッグパーク 豊洲'];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
let ok = 0;
for (const q of SPOTS) {
  console.log(`## ${q}\n`);
  const p = await ctx.newPage();
  try {
    const xq = encodeURIComponent(`${q} since:2026-08-01 -filter:replies`);
    let ids = [];
    for (const f of ['top', 'live']) {
      await p.goto(`https://x.com/search?q=${xq}&src=typed_query&f=${f}`, { waitUntil: 'domcontentloaded', timeout: 25000 });
      await p.waitForTimeout(4500);
      ids.push(...await p.evaluate(() => [...document.querySelectorAll('article')].slice(0, 6).map(a => ([...a.querySelectorAll('a[href*="/status/"]')].map(x => x.getAttribute('href')).find(h => /\/status\/\d+$/.test(h)) || '').split('/status/')[1]).filter(Boolean)));
    }
    ids = [...new Set(ids)];
    for (const id of ids.slice(0, 8)) {
      try {
        const r = await fetch(`https://cdn.syndication.twimg.com/tweet-result?id=${id}&lang=ja&token=a`);
        const j = await r.json();
        console.log(`- **${id}** / ${j.user?.name} (@${j.user?.screen_name}) / ${j.created_at}\n  > ${(j.text || '').replace(/\s+/g, ' ').slice(0, 280)}`);
      } catch (e) { console.log(`- ${id} ⚠️ syndication 失敗`); }
    }
    if (!ids.length) console.log('（0 件）');
    ok++;
  } catch (e) { console.log(`⚠️ X 取れない: ${String(e).slice(0, 140)}`); } finally { await p.close(); }
  console.log('');
}
console.log(`---\n\n**対象 ${SPOTS.length} / X が読めた ${ok}**`);
await b.close().catch(() => {});
JS

RES="$RDIR/.t331-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
