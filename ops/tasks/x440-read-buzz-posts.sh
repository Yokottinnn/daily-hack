#!/bin/bash
# **いま伸びている投稿を、こちらのジャンル（ポイ活・節約・家計・湾岸）で集める（x440）。読むだけ・LLM 不使用・$0。**
#
# 利用者（2026-11-08）「バズりそうな投稿をうまく分析して、同じようなアナロジーで投稿することで、『その角度で考えてるんだ』っていうのが伝わるような投稿も作りたい」。
# 型を推測で作らないため、実物を読む（最上位ルール 20）。X の検索（話題順・いいねの下限つき）で拾い、syndication API で本文・日付・いいね数を確かめる。
# 他人のハンドルは伏せる。投稿・いいね・フォローはしない。235 秒で打ち切る。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/x440-buzz-posts.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 描画してから本文を読む（x440・**\$0**）"
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
SCRIPT="$RDIR/.x440-render.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const SPOTS = ['ポイ活 min_faves:500', '節約 min_faves:1000', '家計 min_faves:1000', '楽天ポイント min_faves:300', 'PayPay min_faves:500', 'ふるさと納税 min_faves:300', '豊洲 min_faves:300', 'タワマン min_faves:500', 'お得 min_faves:1500'];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
let ok = 0;
for (const q of SPOTS) {
  console.log(`## ${q}\n`);
  const p = await ctx.newPage();
  try {
    const xq = encodeURIComponent(`${q} since:2026-10-01 -filter:replies lang:ja`);
    let ids = [];
    for (const f of ['top']) {
      await p.goto(`https://x.com/search?q=${xq}&src=typed_query&f=${f}`, { waitUntil: 'domcontentloaded', timeout: 25000 });
      await p.waitForTimeout(4500);
      ids.push(...await p.evaluate(() => [...document.querySelectorAll('article')].slice(0, 5).map(a => ([...a.querySelectorAll('a[href*="/status/"]')].map(x => x.getAttribute('href')).find(h => /\/status\/\d+$/.test(h)) || '').split('/status/')[1]).filter(Boolean)));
    }
    ids = [...new Set(ids)];
    for (const id of ids.slice(0, 5)) {
      try {
        const r = await fetch(`https://cdn.syndication.twimg.com/tweet-result?id=${id}&lang=ja&token=a`);
        const j = await r.json();
        const media=(j.mediaDetails||[]).map(m=>m.type).join('+')||'なし';console.log(`### ${id}\n- 日付 ${j.created_at} ／ いいね ${j.favorite_count ?? '?'} ／ 返信 ${j.conversation_count ?? '?'} ／ 画像 ${media} ／ 引用 ${j.quoted_tweet ? 'あり' : 'なし'}\n\n\`\`\`text\n${(j.text || '').replace(/@[A-Za-z0-9_]{2,15}/g,'@<伏せ>').replace(/https:\/\/t\.co\/\S+/g,'<URL>').slice(0, 700)}\n\`\`\`\n`);
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

RES="$RDIR/.x440-res.md"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"; echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$RES"
echo "" >> "$OUT"; echo "LLM 不使用。**\$0/回**（1 回きり）。" >> "$OUT"
cat "$OUT"
