#!/bin/bash
# **A8.net・もしもアフィリエイト・バリューコマースに Mac の Chrome でログインできているかと、
# 「提携中の広告」「リンク取得」画面の URL を読む（t235）。** 読むだけ・LLM 不使用・**$0**。
#
# 利用者: 「アフィリエイトリンクがあるんだったら絶対活用して」「もしも・バリューコマースも登録しているはず。
# リンクを取得して、少しでも儲かる方法をサボらず探して」（ポイントサービス徹底分析のプレビュー指摘・2026-10-05）。
# **公開リポジトリに載るので、本文は出さない。** 出すのは URL・題名・ログイン欄の有無・
# 「提携/プログラム/リンク/広告/検索」を含むメニューのリンクだけ（氏名・報酬額は出さない）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t235-asp-login-discovery.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{
  echo "# ASP のログイン状態と提携画面の URL（t235・**\$0**）"
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

SCRIPT="$RDIR/.t235-read.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const T0 = Date.now();
const URLS = [
  ['A8.net', 'https://pub.a8.net/'],
  ['A8.net（提携中）', 'https://pub.a8.net/a8v2/media/partnerProgramListAction.do'],
  ['もしもアフィリエイト', 'https://af.moshimo.com/'],
  ['もしも（提携中）', 'https://af.moshimo.com/af/shop/promotion/list'],
  ['バリューコマース', 'https://aff.valuecommerce.ne.jp/'],
  ['バリューコマース（提携中）', 'https://aff.valuecommerce.ne.jp/report/ad'],
];
const KW = /提携|プログラム|プロモーション|広告|リンク|検索|案件|ショップ|セルフ/;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
for (const [k, u] of URLS) {
  if (Date.now() - T0 > 180000) { console.log(`## ${k}\n\n（時間切れ）\n`); continue; }
  console.log(`## ${k}\n\n- 開いた URL: ${u}`);
  try {
    const r = await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3000);
    const info = await p.evaluate((kw) => {
      const re = new RegExp(kw);
      const pw = !!document.querySelector('input[type=password]');
      const links = [...document.querySelectorAll('a')]
        .map(a => [(a.innerText || a.title || '').replace(/\s+/g, ' ').trim().slice(0, 40), a.href])
        .filter(([t, h]) => t && h && h.startsWith('http') && re.test(t));
      const seen = new Set(); const uniq = [];
      for (const l of links) { const key = l[0] + l[1]; if (!seen.has(key)) { seen.add(key); uniq.push(l); } }
      return { title: document.title.slice(0, 80), pw, links: uniq.slice(0, 40) };
    }, KW.source);
    console.log(`- 状態: ${r ? r.status() : '?'} / 最終 URL: ${p.url()}`);
    console.log(`- 題名: ${info.title}`);
    console.log(`- **パスワード欄: ${info.pw ? 'あり（＝ログインしていない可能性）' : 'なし'}**\n`);
    if (info.links.length) {
      console.log('| メニュー | URL |\n| --- | --- |');
      for (const [t, h] of info.links) console.log(`| ${t.replace(/\|/g, '／')} | ${h} |`);
    } else console.log('（該当するメニューのリンクなし）');
    console.log('');
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
