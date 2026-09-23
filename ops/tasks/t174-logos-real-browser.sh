#!/bin/bash
# **実ブラウザでロゴを取る（t174）。LLM 不使用・$0。**
#
# ## curl 系は 6 経路 すべて 使い切った
#
# | 入口 | 結果 |
# | --- | --- |
# | 公式トップの `<img ... logo>` | 別サービス・親会社が混ざる |
# | `apple-touch-icon` / `favicon` | **403** が多い。取れても BMP の 16〜32px |
# | フルヘッダ（`Sec-Fetch-*` ほか） | **383 bytes / 0 bytes**（WAF が完全遮断） |
# | MediaWiki API | Olympics のロゴ・持株会社が返る |
# | メディアキット・広報ページ | **同じく 383 bytes** |
# | PR TIMES | ロゴらしい `img` が拾えない |
#
# **JAL・さとふる・レイクは「curl である」こと自体で弾かれている。**
# だから**実ブラウザで開く。** これが最上位ルール 17 で残った最後の入口。
#
# ## X 運用の Chrome を壊さないための約束
#
# **この Chrome は X の 8 ループが使っている**（役割は tweet2・最上位ルール 5）。
# 借りるだけにして、**元の状態に必ず戻す。**
#
# - **新しいタブを開いて、終わったら必ず閉じる。** 既存のタブに触らない
# - **`browser.close()` を呼ばない。** CDP 接続を切るだけ（`disconnect`）。
#   呼ぶと**利用者の Chrome ごと落ちる**
# - **ログインが要るページを開かない。** 企業の公開トップだけ
# - **120 秒 で切り上げる。** 長く居座らない
#
# ## 使うもの
#
# **`playwright-core`**（`playwright` ではない・最上位ルール 14）。
# `connectOverCDP` で既に動いている Chrome に繋ぐ。**新しく起動しない。**
#
# **判断はしない。候補を持ち帰るだけ。**

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t174-logos-real-browser.md"
DIR="$RDIR/logos-browser"
mkdir -p "$DIR"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PORT="${CDP_PORT:-18810}"

{
  echo "# 実ブラウザでロゴを取る（t174・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**curl 系 6 経路は全部 弾かれた**（383 bytes / 0 bytes）。実ブラウザで開く。"
  echo "**X 運用の Chrome を借りるだけ。** 新しいタブを開いて閉じ、接続は切るだけ。"
  echo ""
} > "$OUT"

# --- CDP が生きているか（**ポートの LISTEN では足りない**・最上位ルール 13） ---
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null || true)"
if [ -z "$VER" ]; then
  {
    echo "⚠️ **CDP に繋がらない**（\`http://127.0.0.1:$PORT/json/version\` が空）。"
    echo "Chrome が落ちているか、ポートが違う。**何もせず終わる。**"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- CDP **生きている**（\`$(printf '%s' "$VER" | head -c 80)\`）" >> "$OUT"
echo "" >> "$OUT"

cd "$REPO" 2>/dev/null || { echo "⚠️ リポジトリが無い: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
node -e "require.resolve('playwright-core/package.json')" >/dev/null 2>&1 || {
  echo "⚠️ **\`playwright-core\` が無い。** 何もせず終わる" >> "$OUT"; cat "$OUT"; exit 0; }

SCRIPT="$RDIR/.t174-grab.mjs"
cat > "$SCRIPT" <<'JS'
// **既に動いている Chrome に繋ぐ。新しく起動しない。**
import fs from 'node:fs';
import { chromium } from 'playwright-core';

const PORT = process.env.CDP_PORT || '18810';
const DIR = process.env.GRAB_DIR;
const TARGETS = [
  ['jal', 'JAL', 'https://www.jal.co.jp/jp/ja/'],
  ['satofull', 'さとふる', 'https://www.satofull.jp/'],
  ['lake', 'レイク', 'https://lakealsa.com/'],
  ['promise', 'プロミス', 'https://cyber.promise.co.jp/'],
  ['mobit', 'SMBCモビット', 'https://www.mobit.ne.jp/'],
];

const browser = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`);
const ctx = browser.contexts()[0];
const out = [];
const started = Date.now();

for (const [key, jp, url] of TARGETS) {
  if (Date.now() - started > 120000) { out.push(`## ${jp}\n\n- ⏱️ **時間切れ。見ていない**\n`); continue; }
  let page = null;
  try {
    // **新しいタブ。既存のタブには触らない**
    page = await ctx.newPage();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForTimeout(1200);

    const found = await page.evaluate(() => {
      const abs = (u) => { try { return new URL(u, location.href).href; } catch { return null; } };
      const rows = [];
      for (const img of document.querySelectorAll('img')) {
        const s = `${img.className} ${img.alt || ''} ${img.src || ''}`.toLowerCase();
        if (!/logo|ロゴ/.test(s)) continue;
        const u = abs(img.currentSrc || img.src);
        if (u) rows.push({ url: u, alt: img.alt || '', w: img.naturalWidth, h: img.naturalHeight });
      }
      for (const l of document.querySelectorAll('link[rel*="apple-touch-icon"], link[rel*="icon"]')) {
        const u = abs(l.getAttribute('href'));
        if (u) rows.push({ url: u, alt: `link:${l.getAttribute('rel')}`, w: 0, h: 0 });
      }
      return rows.slice(0, 8);
    });

    out.push(`## ${jp}\n\n- \`${url}\` → **開けた**（title: ${JSON.stringify((await page.title()).slice(0, 60))}）\n`);
    if (!found.length) { out.push('- ⚠️ **ロゴらしい img / link が無い**\n'); }

    let n = 0;
    for (const f of found) {
      if (n >= 3) break;
      try {
        // **ページのコンテキストで取る。** Cookie も Referer もブラウザのものが乗る
        const b64 = await page.evaluate(async (u) => {
          const r = await fetch(u, { credentials: 'include' });
          if (!r.ok) return { err: `HTTP ${r.status}` };
          const ab = await r.arrayBuffer();
          if (ab.byteLength <= 400) return { err: `${ab.byteLength} bytes（小さすぎる）` };
          const ct = r.headers.get('content-type') || '';
          if (!/^image\//.test(ct)) return { err: `画像ではない（${ct}）` };
          let s = ''; const v = new Uint8Array(ab);
          for (let i = 0; i < v.length; i++) s += String.fromCharCode(v[i]);
          return { b64: btoa(s), ct, size: ab.byteLength };
        }, f.url);
        if (b64.err) { out.push(`  - ❌ \`${f.url.slice(0, 70)}\` → ${b64.err}\n`); continue; }
        const ext = /svg/.test(b64.ct) ? 'svg' : /jpe?g/.test(b64.ct) ? 'jpg' : /webp/.test(b64.ct) ? 'webp' : 'png';
        const name = `${key}-${n}.${ext}`;
        fs.writeFileSync(`${DIR}/${name}`, Buffer.from(b64.b64, 'base64'));
        out.push(`  - ⬇️ \`${name}\`（**${b64.size} bytes** / ${b64.ct} / alt: ${JSON.stringify(f.alt.slice(0, 40))}）\n`);
        n++;
      } catch (e) {
        out.push(`  - ❌ \`${f.url.slice(0, 60)}\` → ${String(e).slice(0, 80)}\n`);
      }
    }
    out.push('\n');
  } catch (e) {
    out.push(`## ${jp}\n\n- ❌ **${String(e).slice(0, 140)}**\n\n`);
  } finally {
    // **開けたタブは必ず閉じる**
    if (page) { try { await page.close(); } catch {} }
  }
}

// **`browser.close()` は呼ばない。** CDP 越しに呼ぶと利用者の Chrome ごと落ちる。
// プロセスを終えれば接続は切れる。
console.log(out.join(''));
process.exit(0);
JS

# **`timeout` は macOS に無い**（最上位ルール 14）。素の bash で待つ
CDP_PORT="$PORT" GRAB_DIR="$DIR" node "$SCRIPT" >> "$OUT" 2>&1 &
PID=$!
START=$(date +%s)
while kill -0 "$PID" 2>/dev/null; do
  [ $(( $(date +%s) - START )) -ge 180 ] && { kill "$PID" 2>/dev/null; echo "" >> "$OUT"; echo "⏱️ **180 秒 で打ち切った**" >> "$OUT"; break; }
  sleep 2
done
wait "$PID" 2>/dev/null
rm -f "$SCRIPT"

{
  echo ""
  echo "---"
  echo ""
  echo "**$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ') 件 持ち帰った。**"
  echo "**持株会社・親会社のロゴをサービスのロゴとして使わない**（最上位ルール 17）。"
  echo "**採否はクラウド側でコンタクトシートを見て決める。**"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
