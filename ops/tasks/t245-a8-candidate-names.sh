#!/bin/bash
# **A8 の未提携の候補（記事に合うもの）の名前と、提携が「即時」か「審査」かを読む（t245）。** 読むだけ・LLM 不使用・**$0**。
# 提携の申し込みはしない（利用者のアカウント操作なので、許可をもらってから）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t245-a8-candidate-names.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"
{ echo "# A8 の候補の名前と提携方式（t245・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
[ -n "$PWDIR" ] || { echo "⚠️ playwright-core が無い" >> "$OUT"; cat "$OUT"; exit 0; }
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
SCRIPT="$RDIR/.t245.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
const { chromium } = createRequire(process.env.PW_DIR + '/x.js')('playwright-core');
const IDS = ['s00000023355003','s00000024441001','s00000026575004','s00000026575013','s00000015597014','s00000026575008','s00000026575010','s00000023297001','s00000013470008','s00000025908001','s00000017066001','s00000018660001','s00000020637001','s00000024400001','s00000027196001','s00000027505001','s00000021551001','s00000005350011'];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
console.log('| programId | 名前 | 提携方式 | 成果報酬（広告側） |\n| --- | --- | --- | --- |');
for (const id of IDS) {
  try {
    await p.goto(`https://media-console.a8.net/program/detail?programId=${id}`, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await p.waitForTimeout(2500);
    const r = await p.evaluate(() => {
      const t = document.body.innerText;
      const h = [...document.querySelectorAll('h1,h2,h3')].map((e) => e.innerText.trim()).filter((x) => x && !/A8|メニュー|プログラム検索/.test(x));
      const mode = /即時提携/.test(t) ? '即時提携' : (/審査/.test(t) ? '審査あり' : '不明');
      const rew = (t.match(/成果報酬[\s\S]{0,80}/) || [''])[0].replace(/\s+/g, ' ').slice(0, 80);
      return { title: document.title.replace(/｜.*$/, '').trim(), h: h.slice(0, 2).join(' / '), mode, rew, login: !!document.querySelector('input[type=password]') };
    });
    if (r.login) { console.log(`| ${id} | （未ログイン） | | |`); continue; }
    console.log(`| ${id} | ${(r.h || r.title).replace(/\|/g, '／').slice(0, 70)} | ${r.mode} | ${r.rew.replace(/\|/g, '／')} |`);
  } catch (e) { console.log(`| ${id} | 失敗 ${String(e).slice(0, 60)} | | |`); }
}
await p.close(); process.exit(0);
JS
PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 200 /opt/homebrew/bin/node "$SCRIPT" >> "$OUT" 2>&1
RC=$?
echo "" >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 1500 "$OUT"
