#!/bin/bash
# **おせち・カニの売れ筋ランキングと楽天の商品ページを読む（t740）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-20 利用者「ブログの進行中の記事をちゃんと進めて公開までしてね」。作戦室の ideas/osechi-2027-reizou-reitou・ideas/kani-tsuhan-kaitougo-tanka の材料。
# クラウドからは楽天が読めず Yahoo! のランキングも弾かれるので、Mac の Chrome（CDP）で開く。Cookie の無い新しいコンテキストで開く（ログイン中の名前などをレポートに入れない・t688 の反省）。


set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t740-osechi-kani-pages.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# おせち・カニのランキングと商品ページ（t740・**\$0**）"
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

D="$RDIR/t740"; mkdir -p "$D"
SCRIPT="$RDIR/.t740.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし（ログインの情報を持ち込まない）
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 230000 - (Date.now() - t0);
const ITEM = /^https:\/\/(item\.rakuten\.co\.jp\/[^/]+\/[^/?#]+|store\.shopping\.yahoo\.co\.jp\/[^/]+\/[^/?#]+\.html)/;
async function ranking(key, url) {
  if (left() < 15000) { console.log(`- ⏱ ${key} は時間切れ`); return; }
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4000);
    await p.evaluate(() => window.scrollTo(0, document.body.scrollHeight / 2));
    await p.waitForTimeout(1500);
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href, t: (a.innerText || a.title || (a.querySelector('img') && a.querySelector('img').alt) || '').replace(/\s+/g, ' ').trim() })));
    const seen = new Map();
    for (const l of links) {
      const m = l.h.match(ITEM); if (!m) continue;
      const u = m[0]; const prev = seen.get(u) || '';
      seen.set(u, l.t.length > prev.length ? l.t : prev);
    }
    console.log(`\n### ${key}（${await p.title()}）\n- URL: ${p.url()}\n- 商品リンク ${seen.size} 件（ページに出た順）`);
    let i = 0;
    for (const [u, t] of seen) { if (++i > 30) break; console.log(`${i}. ${t.slice(0, 110)} — ${u}`); }
    const body = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${await p.title()}\nURL: ${p.url()}\n\n${body.slice(0, 60000)}`);
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 120)}`); }
}
async function page(key, url) {
  if (left() < 12000) { console.log(`- ⏱ ${key} は時間切れ`); return []; }
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3500);
    const t = await p.evaluate(() => document.body ? document.body.innerText : '');
    const ti = await p.title();
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${t.slice(0, 80000)}`);
    const rk = await p.evaluate(() => [...document.querySelectorAll('a[href*="ranking.rakuten.co.jp"]')].map((a) => ({ t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 50), h: a.href })).slice(0, 8));
    console.log(`- ${key}: ${t.length} 文字 「${ti.slice(0, 70)}」`);
    for (const r of rk) console.log(`  - ランキング: ${r.t} — ${r.h}`);
    return rk;
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 100)}`); return []; }
}
// 1) カニのランキング（楽天・Yahoo!）
await ranking('rk-kani-zuwai', 'https://ranking.rakuten.co.jp/daily/110411/tags=1011126/');
await ranking('rk-kani-tags1011192', 'https://ranking.rakuten.co.jp/daily/110411/tags=1011192/');
await ranking('rk-kani-110411', 'https://ranking.rakuten.co.jp/daily/110411/');
await ranking('yh-kani-951', 'https://shopping.yahoo.co.jp/categoryranking/951/list');
await ranking('yh-kani-955', 'https://shopping.yahoo.co.jp/categoryranking/955/list');
// 2) おせちのランキング（Yahoo! はおせち料理のカテゴリ 41555。楽天は商品ページに出るランキングのリンクから辿る）
await ranking('yh-osechi-41555', 'https://shopping.yahoo.co.jp/categoryranking/41555/list');
const rk1 = await page('rt-omosan-9030', 'https://item.rakuten.co.jp/omosan/9030/');
const ru = (rk1.find((r) => /おせち/.test(r.t) && /daily|realtime|weekly/.test(r.h)) || rk1.find((r) => /daily|realtime|weekly/.test(r.h)) || {}).h;
if (ru) await ranking('rk-osechi', ru); else console.log('- 楽天のおせちのランキングへのリンクが商品ページに無かった');
// 3) おせちの候補の楽天の商品ページ（affiliate の docs/research/article-candidates-2026-10.md の R1）
for (const [k, u] of [["rt-itamae-sandannp", "https://item.rakuten.co.jp/2-itamae/sandannp/"], ["rt-omosan-senfuji", "https://item.rakuten.co.jp/omosan/senfuji/"], ["rt-belluna-7823753", "https://item.rakuten.co.jp/belluna-gourmet/7823753/"], ["rt-kanidokoro-428", "https://item.rakuten.co.jp/kanidokoro/428/"]]) await page(k, u);
await ctx.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t740-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 245 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 20000 "$OUT"
