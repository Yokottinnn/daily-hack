#!/bin/bash
# **記事の構想に使うトレンドのワードを毎日ためる**（launchd 毎日 07:10・t296）。LLM 不使用・**$0**。
# 利用者（2026-10-14）:「最新のトレンドのワードをちゃんと用いて、それに適した記事を作って欲しい」
#   Google トレンドの急上昇（日本・RSS）と Yahoo! リアルタイム検索の急上昇を読み、
#   reports/board/trend/<YYYY-MM-DD>.json と reports/board/trend-words.json（最新）に置く。heartbeat が push する。
# macOS で使えない構文（timeout / sed -i / date -d / stat -c）は使わない（最上位ルール 14）。
set -uo pipefail
REPORTS="${OPS_REPORT_DIR:-$HOME/.openclaw/ops-heartbeat-wt/reports}"
DIR="$REPORTS/board/trend"; mkdir -p "$DIR"
WORK="${TMPDIR:-/tmp}/trend-daily"; mkdir -p "$WORK"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
curl -sL --max-time 25 -A "$UA" 'https://trends.google.co.jp/trending/rss?geo=JP' -o "$WORK/g.xml"
curl -sL --max-time 25 -A "$UA" 'https://search.yahoo.co.jp/realtime' -o "$WORK/y.html"
DAY="$(date '+%Y-%m-%d')"
"$NODE_BIN" - "$WORK/g.xml" "$WORK/y.html" "$DIR/$DAY.json" "$REPORTS/board/trend-words.json" <<'JSEOF'
const fs = require('fs');
const [g, y, out, latest] = process.argv.slice(2);
const gx = fs.existsSync(g) ? fs.readFileSync(g, 'utf8') : '';
const clean = (x) => x.replace(/<!\[CDATA\[|\]\]>/g, '').replace(/&amp;/g, '&').trim();
const google = [...gx.matchAll(/<item>([\s\S]*?)<\/item>/g)].map((m) => {
  const t = (re) => clean((m[1].match(re) || [])[1] || '');
  return { word: t(/<title>([\s\S]*?)<\/title>/), traffic: t(/<ht:approx_traffic>([\s\S]*?)<\/ht:approx_traffic>/), news: [...m[1].matchAll(/<ht:news_item_title>([\s\S]*?)<\/ht:news_item_title>/g)].map((n) => clean(n[1])).slice(0, 2) };
}).filter((i) => i.word);
const yh = fs.existsSync(y) ? fs.readFileSync(y, 'utf8') : '';
let yahoo = [];
const nd = yh.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
if (nd) { const walk = (o) => { if (!o || typeof o !== 'object') return; if (Array.isArray(o)) return o.forEach(walk); for (const [k, v] of Object.entries(o)) { if (/^(query|keyword|word)$/i.test(k) && typeof v === 'string' && v.length <= 30) yahoo.push(v); else walk(v); } }; try { walk(JSON.parse(nd[1])); } catch {} }
if (!yahoo.length) yahoo = [...yh.matchAll(/realtime\/search\?p=([^"&]+)/g)].map((m) => decodeURIComponent(m[1].replace(/\+/g, ' ')));
// 画面の部品（メニューの文字）を外す
const NAV = /^(リアルタイム検索|トレンドランキング|人気ポスト|動画ランキング|事故・災害|つぶやきピックアップ|SNSのバズまとめ|リアルタイム検索アプリ|設定|ミュートしたアカウント|その他|X（旧Twitter）データについて|プライバシーポリシー|プライバシーセンター|規約|ヘルプ)$/;
yahoo = [...new Set(yahoo.map((w) => w.trim()).filter((w) => w && !NAV.test(w)))].slice(0, 30);
const res = { generated: new Date().toISOString(), google, yahoo };
const s = JSON.stringify(res, null, 1);
fs.writeFileSync(out, s); fs.writeFileSync(latest, s);
JSON.parse(fs.readFileSync(out, 'utf8'));
console.log(`trend: google=${google.length} yahoo=${yahoo.length}`);
JSEOF
