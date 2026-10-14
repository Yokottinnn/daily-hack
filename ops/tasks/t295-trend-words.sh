#!/bin/bash
# **記事の構想に使う「いまのトレンドのワード」を集める（t295）。** 利用者が 2026-10-14 に「最新のトレンドのワードをちゃんと用いて記事を」。
# 読むだけ・LLM 不使用・**$0**。Google トレンドの急上昇（日本・RSS）と Yahoo! リアルタイム検索の急上昇を取る。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t295-trend-words.md"
mkdir -p "$RDIR/board"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
{ echo "# トレンドのワード（t295・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
G="$RDIR/.gtrends.xml"; Y="$RDIR/.yrt.html"
curl -sL --max-time 25 -A "$UA" 'https://trends.google.co.jp/trending/rss?geo=JP' -o "$G"; echo "- Google トレンド RSS: $(wc -c < "$G" | tr -d ' ') bytes" >> "$OUT"
curl -sL --max-time 25 -A "$UA" 'https://search.yahoo.co.jp/realtime' -o "$Y"; echo "- Yahoo! リアルタイム: $(wc -c < "$Y" | tr -d ' ') bytes" >> "$OUT"
"$NODE_BIN" - "$G" "$Y" "$RDIR/board/trend-words.json" >> "$OUT" 2>&1 <<'JSEOF'
const fs = require('fs');
const [g, y, out] = process.argv.slice(2);
const gx = fs.existsSync(g) ? fs.readFileSync(g, 'utf8') : '';
const items = [...gx.matchAll(/<item>([\s\S]*?)<\/item>/g)].map((m) => {
  const t = (re) => ((m[1].match(re) || [])[1] || '').replace(/<!\[CDATA\[|\]\]>/g, '').trim();
  return { word: t(/<title>([\s\S]*?)<\/title>/), traffic: t(/<ht:approx_traffic>([\s\S]*?)<\/ht:approx_traffic>/), news: [...m[1].matchAll(/<ht:news_item_title>([\s\S]*?)<\/ht:news_item_title>/g)].map((n) => n[1].replace(/<!\[CDATA\[|\]\]>/g, '').trim()).slice(0, 2) };
});
const yh = fs.existsSync(y) ? fs.readFileSync(y, 'utf8') : '';
let ywords = [];
const nd = yh.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
if (nd) { const walk = (o) => { if (!o || typeof o !== 'object') return; if (Array.isArray(o)) return o.forEach(walk); for (const [k, v] of Object.entries(o)) { if (/^(query|keyword|word|title)$/i.test(k) && typeof v === 'string' && v.length <= 30) ywords.push(v); else walk(v); } }; try { walk(JSON.parse(nd[1])); } catch {} }
if (!ywords.length) ywords = [...yh.matchAll(/realtime\/search\?p=([^"&]+)/g)].map((m) => decodeURIComponent(m[1].replace(/\+/g, ' ')));
ywords = [...new Set(ywords)].slice(0, 40);
const res = { generated: new Date().toISOString(), google: items, yahoo: ywords };
fs.writeFileSync(out, JSON.stringify(res, null, 1));
JSON.parse(fs.readFileSync(out, 'utf8'));
console.log(`\n## Google トレンド 急上昇（${items.length} 件）\n`);
items.forEach((i) => console.log(`- ${i.word}（${i.traffic}）${i.news.length ? ' — ' + i.news.join(' ／ ') : ''}`));
console.log(`\n## Yahoo! リアルタイム検索（${ywords.length} 件）\n`);
ywords.forEach((w) => console.log(`- ${w}`));
JSEOF
echo "rc=$?" >> "$OUT"
head -c 3000 "$OUT"
