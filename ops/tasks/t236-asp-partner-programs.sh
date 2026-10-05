#!/bin/bash
# **ログイン後の A8.net・もしもアフィリエイト・バリューコマースで、提携中の広告（プログラム名と ID）と
# 管理画面のメニュー URL を読む（t236）。** 読むだけ・LLM 不使用・**$0**。
#
# t235 では 3 つとも未ログインだった。利用者が Mac の Chrome（CDP 18810）でログインしたあとに走らせる。
# ポイントサービス徹底分析に当てる広告（楽天カード・三井住友カード・PayPayカード・ビューカード・JAL・ANA・
# モッピー・ポイントサイト・証券など）を探す前段。**公開リポジトリに載るので、報酬額・氏名・口座は出さない。**
# 出すのは「プログラム名を含むリンク」と「メニューの URL」だけ。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t236-asp-partner-programs.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{
  echo "# ASP の提携中プログラム（t236・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  if [ -d "$d/playwright-core" ]; then PWDIR="$d"; break; fi
done
if [ -z "$PWDIR" ]; then echo "⚠️ playwright-core が無い。止める。" >> "$OUT"; cat "$OUT"; exit 0; fi
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null | head -c 200)"
if [ -z "$VER" ]; then echo "⚠️ Chrome が CDP（$PORT）で応答しない。止める。" >> "$OUT"; cat "$OUT"; exit 0; fi
echo "- Chrome: **CDP $PORT で応答あり**" >> "$OUT"; echo "" >> "$OUT"

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

SCRIPT="$RDIR/.t236-read.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
// 入口 → そこから辿るメニューの語
const SITES = [
  { name: 'A8.net', start: 'https://media-console.a8.net/', menu: /提携|参加中|プログラム|広告リンク/ },
  { name: 'もしもアフィリエイト', start: 'https://af.moshimo.com/af/shop/promotion/list', menu: /提携|プロモーション|広告|リンク/ },
  { name: 'バリューコマース', start: 'https://aff.valuecommerce.ne.jp/', menu: /提携|広告主|プログラム|リンク|MyLink|LinkSwitch/ },
];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
async function dump(label) {
  const info = await p.evaluate(() => {
    const pw = !!document.querySelector('input[type=password]');
    const links = [...document.querySelectorAll('a')]
      .map(a => [(a.innerText || a.title || '').replace(/\s+/g, ' ').trim().slice(0, 60), a.href])
      .filter(([t, h]) => t && h && h.startsWith('http'));
    // 表の行（プログラム名の候補）。数字だけの列・円を含む列は落とす
    const rows = [...document.querySelectorAll('tr, li')].map(r => r.innerText.replace(/\s+/g, ' ').trim())
      .filter(t => t.length > 3 && t.length < 120 && !/円|¥|報酬額|口座|氏名/.test(t)).slice(0, 80);
    return { title: document.title.slice(0, 80), url: location.href, pw, links, rows };
  });
  console.log(`### ${label}\n\n- 最終 URL: ${info.url}\n- 題名: ${info.title}\n- **パスワード欄: ${info.pw ? 'あり（未ログイン）' : 'なし'}**\n`);
  return info;
}
for (const s of SITES) {
  if (Date.now() - T0 > 200000) { console.log(`## ${s.name}\n\n（時間切れ）\n`); continue; }
  console.log(`## ${s.name}\n`);
  try {
    await p.goto(s.start, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3500);
    const top = await dump('入口');
    if (top.pw) { console.log('**ログインしていないので、ここで止める。**\n'); continue; }
    const menu = top.links.filter(([t]) => s.menu.test(t));
    const seen = new Set(); const uniq = menu.filter(([t, h]) => !seen.has(h) && seen.add(h)).slice(0, 25);
    console.log('| メニュー | URL |\n| --- | --- |');
    for (const [t, h] of uniq) console.log(`| ${t.replace(/\|/g, '／')} | ${h} |`);
    console.log('');
    // 「提携」を含む最初のメニューを開いて、行を出す
    const go = uniq.find(([t]) => /提携/.test(t));
    if (go) {
      await p.goto(go[1], { waitUntil: 'domcontentloaded', timeout: 25000 });
      await p.waitForTimeout(3500);
      const pg = await dump(`「${go[0]}」を開いた`);
      console.log('```text\n' + pg.rows.join('\n') + '\n```\n');
    } else {
      console.log('```text\n' + top.rows.join('\n') + '\n```\n');
    }
  } catch (e) {
    console.log(`- ⚠️ 失敗: ${String(e).slice(0, 200)}\n`);
  }
}
await p.close();
process.exit(0);
JS

PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 240 node "$SCRIPT" >> "$OUT" 2>&1
RC=$?
echo "" >> "$OUT"
echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 2000 "$OUT"
