#!/bin/bash
# **ふるさと納税12月の記事に載せる返礼品ページの配送の行を Chrome で読む（t752）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-20 blog3 の記事（作戦室で利用者が書くと決めた「ふるさと納税12月の駆け込み」）。返礼品ページはクラウドから 403。年内に届くか・何日までの決済か、の行だけを抜き出す（名前などは出さない）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t752-furusato-items.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 返礼品ページの配送の行（t752・**\$0**）"
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

D="$RDIR/t752"; mkdir -p "$D"
SCRIPT="$RDIR/.t752.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const pages = [
 ["hotate", "https://item.rakuten.co.jp/f016918-betsukai/be018-0054/"],
 ["zuwai", "https://item.rakuten.co.jp/f042056-kesennuma/20560597/"],
 ["gyutan", "https://item.rakuten.co.jp/f016918-betsukai/ns0000020/"],
 ["chicken", "https://item.rakuten.co.jp/f452025-miyakonojo/mj-3314/"],
 ["mizutaki", "https://item.rakuten.co.jp/f402303-itoshima/aib001/"],
 ["hamburg", "https://item.rakuten.co.jp/f082112-joso/ni01095/"],
 ["rice", "https://item.rakuten.co.jp/f012246-chitose/ci007/"],
 ["salmon", "https://item.rakuten.co.jp/f016918-betsukai/mt000tz00/"]
];
// **ログインした画面の本文を保存しない**（最上位ルール「ログインが要るページの本文をレポートに保存しない」）。
// 返礼品のページは公開だが、ヘッダーに名前が出ることがあるので、配送・寄付額・内容量の行だけを抜き出す。
const KEEP = /(年内|発送|お届け|配送|着日|決済|寄付金額|内容量|容量|消費期限|賞味期限|保存方法|提供|事業者|\d+円)/;
const DROP = /(様|さん|ポイント残高|ログイン|会員|お気に入り|閲覧履歴|購入履歴|カード番号)/;
for (const [k, u] of pages) {
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4000);
    const t = await p.evaluate(() => document.body ? document.body.innerText : '');
    const ti = await p.title();
    const lines = [...new Set(t.split('\n').map((s) => s.trim()).filter((s) => s && s.length < 260 && KEEP.test(s) && !DROP.test(s)))].slice(0, 60);
    fs.writeFileSync(`${D}/${k}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${lines.join('\n')}\n`);
    console.log(`- ${k}: ${lines.length} 行 「${ti.slice(0, 60)}」`);
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0, 100)}`); }
}
await p.close().catch(() => {});
process.exit(0);
JS
RES="$RDIR/.t752-res.txt"
D="$D" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 150 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
head -c 9000 "$OUT"
