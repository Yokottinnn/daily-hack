#!/bin/bash
# **築地本願寺の 2026年11〜12月の行事を読む（t702）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-18 湾岸ニュースの毎朝の記事。11/17 に「パイプオルガンランチタイムコンサートなどの料金が公式で確かめられない」で保留した分。
# クラウドからは tsukijihongwanji.jp が 503 を返すので Mac で読む。トップ・お知らせ・行事の一覧からリンクを集め、
# 行事・コンサートらしいページ（最大 12）の本文を出す。ログインの要るページは読まない。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t702-tsukiji-hongwanji-events.md"
mkdir -p "$RDIR"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36"
TMP="$(mktemp -d)"
{ echo "# 築地本願寺の 2026年11〜12月の行事（t702・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"

i=0
for u in "https://tsukijihongwanji.jp/" "https://tsukijihongwanji.jp/news/" "https://tsukijihongwanji.jp/event/" "https://tsukijihongwanji.jp/schedule/"; do
  i=$((i+1))
  code="$(curl -sSL --max-time 25 -A "$UA" -o "$TMP/top$i.html" -w '%{http_code}' "$u" 2>/dev/null)"
  echo "- 入口 $u → HTTP **$code**・$(wc -c < "$TMP/top$i.html" 2>/dev/null | tr -d ' ') bytes" >> "$OUT"
done
echo "" >> "$OUT"

node - "$TMP" "$i" >> "$OUT" <<'JS'
const fs = require('fs'); const dir = process.argv[2]; const n = +process.argv[3];
const links = new Map();
for (let k = 1; k <= n; k++) {
  let h = ''; try { h = fs.readFileSync(`${dir}/top${k}.html`, 'utf8'); } catch (e) { continue; }
  for (const m of h.matchAll(/<a[^>]+href="([^"#]+)"[^>]*>([\s\S]*?)<\/a>/g)) {
    let u = m[1]; if (u.startsWith('/')) u = 'https://tsukijihongwanji.jp' + u;
    if (!u.startsWith('https://tsukijihongwanji.jp/')) continue;
    const t = m[2].replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
    if (!links.has(u)) links.set(u, t);
  }
}
const re = /(オルガン|コンサート|ランチタイム|行事|法要|報恩講|除夜|年末|大晦日|クリスマス|マルシェ|イベント|12月|11月|event|news)/i;
const pick = [...links].filter(([u, t]) => re.test(u + ' ' + t) && !/\/(en|zh|ko)\//.test(u));
console.log(`集めたリンク **${links.size}** 件 / 行事らしいもの **${pick.length}** 件\n`);
for (const [u, t] of pick.slice(0, 60)) console.log(`- ${t.slice(0, 80)} — ${u}`);
fs.writeFileSync(`${dir}/pick.txt`, pick.slice(0, 40).map(([u]) => u).join('\n') + '\n');
JS

UA="$UA" TMP="$TMP" node - >> "$OUT" <<'JS'
const fs = require('fs'); const { execFileSync } = require('child_process');
const dir = process.env.TMP;
const urls = fs.readFileSync(`${dir}/pick.txt`, 'utf8').split('\n').filter(Boolean);
const want = /(オルガン|コンサート|ランチタイム|報恩講|除夜|大晦日|年末|クリスマス|マルシェ|2026年1[12]月|11月|12月)/;
let shown = 0, read = 0;
for (const u of urls) {
  if (shown >= 12) break;
  let h = '';
  try { h = execFileSync('curl', ['-sSL', '--max-time', '20', '-A', process.env.UA, u], { encoding: 'utf8', maxBuffer: 2e7 }); } catch (e) { continue; }
  read++;
  const title = ((h.match(/<title>([^<]*)<\/title>/) || [])[1] || '').trim();
  const body = h.replace(/<script[\s\S]*?<\/script>/g, '').replace(/<style[\s\S]*?<\/style>/g, '')
    .replace(/<br\s*\/?>/g, '\n').replace(/<\/(tr|p|div|li|h\d|th|td|dt|dd)>/g, '\n').replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/[ \t]+/g, ' ')
    .split('\n').map((s) => s.trim()).filter(Boolean);
  const text = body.join('\n');
  if (!want.test(title + text)) continue;
  shown++;
  const imgs = [...new Set([...h.matchAll(/(?:src|content)="([^"]+\.(?:jpe?g|png|webp)[^"]*)"/g)].map((m) => m[1]))].filter((s) => !/logo|icon/i.test(s)).slice(0, 8);
  console.log(`\n## ${title}\n\n${u}\n\n\`\`\`text`);
  const a = body.findIndex((s) => want.test(s));
  console.log(body.slice(Math.max(0, a - 5), Math.max(0, a - 5) + 90).join('\n').slice(0, 4500));
  console.log('```');
  console.log('画像: ' + (imgs.join(' ') || 'なし'));
}
console.log(`\n---\n対象 ${urls.length} / 読んだ ${read} / 出した ${shown}`);
JS
rm -rf "$TMP"; head -c 60000 "$OUT"
