#!/bin/bash
# **湾岸ニュース 2026-11-20 の話題 3 件の元のページを Chrome で開き、行き先の URL・日付と場所と料金の行・リンク先・画像の URL を抜き出す（t711）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 豊洲場外マルシェ（2026-11-21 三陸常磐）・みんなでヨガ in 晴海ふ頭公園・SCSK の CAMP こよみワークショップ。Google ニュースの転送先がクラウドから解けないため Mac で開く。
# 公開のニュースページだけを開く。ログインの要るページは開かない。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t711-wangan-news-sources-read.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{
  echo "# 湾岸ニュース 2026-11-20 の元のページ（t711・読むだけ・\$0）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then echo "⚠️ playwright-core が無い。ここで止める。" >> "$OUT"; cat "$OUT"; exit 0; fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then echo "⚠️ Chrome が CDP（$PORT）で応答しない。ここで止める。" >> "$OUT"; cat "$OUT"; exit 0; fi

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

SCRIPT="$RDIR/.t711.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [
  ["marche-dmenu", "https://news.google.com/rss/articles/CBMigwFBVV95cUxOZ0tNUmFqWm5IOXRieUVKT29SOW1yZWlZS29kRDdiYWVoMXd4M0NqcUxWZjc5N0ZqYlp0cVlvdU1KZ0V2eTlleDhpOWQ1T1N5ZUJEV3Q0WkNua21MYVI3Yl8tOERDU0J4LVJMZEZ4V1huU01CNkxvUEktTXhrRVQxZHZpQdIBgwFBVV95cUxOZ0tNUmFqWm5IOXRieUVKT29SOW1yZWlZS29kRDdiYWVoMXd4M0NqcUxWZjc5N0ZqYlp0cVlvdU1KZ0V2eTlleDhpOWQ1T1N5ZUJEV3Q0WkNua21MYVI3Yl8tOERDU0J4LVJMZEZ4V1huU01CNkxvUEktTXhrRVQxZHZpQQ?oc=5"],
  ["yoga-walker", "https://news.google.com/rss/articles/CBMiW0FVX3lxTE5pLWFOT1FYaDdDNHIxYUpFWXJ0azBfcnlDdHRvTFBydEpjeEJuQUVXeDZBT1dYMUpKWWdONUh4VUYwT3gtWHZDN3l5SFQyTnZNa052QjZUX3lvOVk?oc=5"],
  ["scsk-ref", "https://news.google.com/rss/articles/CBMibEFVX3lxTE84Nktva3BKUjg2ZjFGX1dfa2xXMEs1V1NGWUkyd3BDY0Q2UFJIVUJyTi1Bckszby1aNkpOUzA2SlpaYnJoRGNzd2ZwV3JpbWNTWWM5WXl1SHhoZ1Q5N1BFTDVKTzlpN2E4SWRQbQ?oc=5"],
];
const KEEP = /(20\d\d年|\d{1,2}月\d{1,2}日|\d{1,2}\/\d{1,2}|時|分|円|無料|会場|場所|住所|主催|共催|後援|定員|先着|申込|締切|対象|豊洲|晴海|江東区|中央区|マルシェ|ヨガ|こよみ|SCSK|三陸|常磐|試食|販売|出店|雨天|中止|持ち物|問い合わせ|URL|http)/;
for (const [k,u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 30000 });
    for (let i = 0; i < 10 && /news\.google\.com/.test(p.url()); i++) await p.waitForTimeout(1500);
    await p.waitForTimeout(4000);
    const d = await p.evaluate(() => {
      const main = document.querySelector('article') || document.querySelector('main') || document.body;
      const links = [...main.querySelectorAll('a[href]')].map(a => [a.href, (a.textContent||'').trim().slice(0,60)]).filter(([h]) => /^https?:/.test(h) && !/twitter\.com\/intent|facebook\.com\/share|line\.me\/R|google|doubleclick/.test(h));
      const imgs = [...main.querySelectorAll('img')].map(i => [i.currentSrc || i.src, i.naturalWidth, i.naturalHeight, (i.alt||'').slice(0,60)]).filter(x => x[1] >= 300);
      const og = document.querySelector('meta[property="og:image"]')?.content || '';
      return { t: main.innerText || '', links, imgs, og, title: document.title };
    });
    const lines = [...new Set(d.t.split('\n').map(s=>s.trim()).filter(s=>s && s.length<=220 && KEEP.test(s)))].slice(0,110);
    console.log(`\n## ${k}\n\n- タイトル: ${d.title}\n- 行き先: ${p.url()}\n- og:image: ${d.og}\n- 本文 ${d.t.length} 文字のうち、日付・場所・料金の行 ${lines.length} 行\n\n\`\`\`text\n${lines.join('\n')}\n\`\`\`\n\n### リンク（本文の中・上位 40）\n\n\`\`\`text\n${[...new Map(d.links.map(x=>[x[0],x])).values()].slice(0,40).map(x=>x.join(' | ')).join('\n')}\n\`\`\`\n\n### 画像（幅 300 以上）\n\n\`\`\`text\n${d.imgs.slice(0,15).map(x=>x.join(' | ')).join('\n')}\n\`\`\``);
  } catch (e) { console.log(`\n## ${k}\n\n- ⚠️ ${String(e).slice(0,160)}`); }
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t711-res.txt"
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 150 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 12000 "$OUT"
