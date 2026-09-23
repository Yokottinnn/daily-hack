#!/bin/bash
# **CORS で落ちたロゴを取り直す（t182）。LLM 不使用・$0。**
#
# ## t180 / t181 が落ちた理由は 1 つだけ
#
# **`page.evaluate(() => fetch(url))` は CORS の制約を受ける。**
# ロゴは別オリジンの CDN に置かれていることが多く、
# `Access-Control-Allow-Origin` が付いていなければ **`TypeError: Failed to fetch`** で落ちる。
#
# **ページが `<img>` として表示できているのに、スクリプトからは読めない。**
# これで t180 / t181 の ❌ は全部 説明がつく。
#
# | 落ちた先 | 何だったか |
# | --- | --- |
# | `production-image-proxy.reproio.com` | **auでんきの本命**の可能性 |
# | `cache2.denki.cilite.docomo.ne.jp/assets_brand/img/common/logo_…` | **ドコモでんきの本命** |
# | `warau.akamaized.net/.../logo/…` | **ワラウの本命** |
# | `img1.kakaku.k-img.com/images/logo.png` | **価格.com の本命** |
#
# ## 直し方
#
# **`ctx.request.get()`（Playwright の APIRequestContext）を使う。**
# ブラウザのクッキーは乗るが、**CORS は効かない**（ブラウザの外で走るため）。
# `referer` を元ページにして、リンク元を見ている CDN にも通す。
#
# ## 保険スクエアbang! は記事のリンクが 404 だった
#
# `https://www.bang.co.jp/auto/` は **title が "404 Not Found"**。
# **記事のリンクが切れている。** 正しい URL を検索で突き止めて持ち帰る。
# **当てずっぽうで打たない**（最上位ルール 17）。
#
# ## 却下する条件（最上位ルール 17）
#
# - **親ブランド**（au / NTT docomo / 楽天）を、そのサービスのロゴとして使わない
# - **運営会社**（楽天エナジー / オープンスマイル）も同じ
# - **周年版・キャンペーン版**（`10th anniversary`）
# - **料金プランのロゴ束**（ドコモMAX ほか）は**ドコモでんきのロゴではない**
#
# ## X 運用の Chrome を借りるだけ（t174 から変えていない）
#
# - 新しいタブを開いて、終わったら必ず閉じる。既存のタブに触らない
# - **`browser.close()` を呼ばない。** 呼ぶと**利用者の Chrome ごと落ちる**
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t182-logos-cors-fix.md"
DIR="$RDIR/logos-cors"
mkdir -p "$DIR"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PORT="${CDP_PORT:-18810}"

{
  echo "# CORS で落ちたロゴを取り直す（t182・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**\`page.evaluate(fetch)\` は CORS で落ちる。** \`ctx.request.get()\` に替える。"
  echo ""
} > "$OUT"

VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null || true)"
if [ -z "$VER" ]; then
  echo "⚠️ **CDP に繋がらない。** 何もせず終わる。" >> "$OUT"; cat "$OUT"; exit 0
fi
cd "$REPO" 2>/dev/null || { echo "⚠️ リポジトリが無い: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
PWDIR=""
for d in "$REPO/node_modules" "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }
done
[ -n "$PWDIR" ] || { echo "⚠️ **\`playwright-core\` が無い。**" >> "$OUT"; cat "$OUT"; exit 0; }
echo "- CDP **生きている** / \`playwright-core\`: \`$PWDIR/playwright-core\`" >> "$OUT"; echo "" >> "$OUT"

SCRIPT="$RDIR/.t182-grab.mjs"
cat > "$SCRIPT" <<'JS'
import fs from 'node:fs';
import { createRequire } from 'node:module';
// **ESM の import は `NODE_PATH` を見ない。** CommonJS の require で場所を指定して解決する
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');

const PORT = process.env.CDP_PORT || '18810';
const DIR = process.env.GRAB_DIR;
const TARGETS = [
  ['au-denki', 'auでんき', 'https://www.au.com/energy/'],
  ['docomo-denki', 'ドコモでんき', 'https://denki.docomo.ne.jp/'],
  ['warau', 'ワラウ', 'https://www.warau.jp/'],
  ['kakaku', '価格.com 自動車保険', 'https://kakaku.com/kuruma_hoken/'],
  ['bang', '保険スクエアbang!', null, '保険スクエアbang 自動車保険 一括見積もり 公式'],
];

const browser = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`);
const ctx = browser.contexts()[0];
const out = [];
const started = Date.now();

async function findUrl(query) {
  const p = await ctx.newPage();
  try {
    await p.goto('https://duckduckgo.com/html/?q=' + encodeURIComponent(query),
                 { waitUntil: 'domcontentloaded', timeout: 20000 });
    await p.waitForTimeout(1200);
    return await p.evaluate(() => {
      const rows = [];
      for (const a of document.querySelectorAll('a.result__a, a[data-testid="result-title-a"]')) {
        let h = a.href;
        try { const u = new URL(h, location.href); const d = u.searchParams.get('uddg');
              if (d) h = decodeURIComponent(d); } catch {}
        if (/^https?:/.test(h)) rows.push({ href: h, text: (a.textContent || '').trim().slice(0, 60) });
        if (rows.length >= 5) break;
      }
      return rows;
    });
  } catch (e) { return [{ href: '', text: 'ERR ' + String(e).slice(0, 80) }]; }
  finally { try { await p.close(); } catch {} }
}

for (const [key, jp, fixedUrl, query] of TARGETS) {
  if (Date.now() - started > 200000) { out.push(`## ${jp}\n\n- 時間切れ。見ていない\n\n`); continue; }
  out.push(`## ${jp}\n\n`);
  let url = fixedUrl;
  if (!url) {
    const hits = await findUrl(query);
    out.push('- 検索の上位:\n');
    for (const h of hits) out.push(`  - ${JSON.stringify(h.text)} -> \`${h.href}\`\n`);
    url = (hits.find((h) => /^https?:/.test(h.href)) || {}).href || '';
    if (!url) { out.push('- **URL が取れない**\n\n'); continue; }
  }

  let page = null;
  try {
    page = await ctx.newPage();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForTimeout(1500);
    const title = (await page.title()).slice(0, 70);
    out.push(`- \`${url}\` -> **開けた**（title: ${JSON.stringify(title)}）\n`);
    // **404 を「開けた」と書かない**（最上位ルール 11）
    if (/404|not found/i.test(title)) out.push('- **404 らしい。このページは当てにしない**\n');

    const found = await page.evaluate(() => {
      const abs = (u) => { try { return new URL(u, location.href).href; } catch { return null; } };
      const rows = []; const seen = new Set();
      const add = (img, why) => {
        const u = abs(img.currentSrc || img.src);
        if (!u || seen.has(u)) return;
        if (img.naturalWidth && img.naturalWidth < 40) return;
        seen.add(u);
        rows.push({ url: u, alt: `${img.alt || ''}${why}`, w: img.naturalWidth, h: img.naturalHeight });
      };
      for (const img of document.querySelectorAll('img')) {
        const s = `${img.className} ${img.alt || ''} ${img.src || ''}`.toLowerCase();
        if (/logo/.test(s)) add(img, '');
      }
      for (const sel of ['header img', 'h1 img', '[class*="header"] img', '[id*="header"] img']) {
        for (const img of document.querySelectorAll(sel)) add(img, ' [header]');
      }
      return rows.slice(0, 8);
    });
    if (!found.length) out.push('- **ロゴらしい img が無い**\n');

    let n = 0;
    for (const f of found) {
      if (n >= 5) break;
      try {
        // **ここが t180 / t181 との違い。** `ctx.request` はブラウザの外で走るので **CORS が効かない**
        const r = await ctx.request.get(f.url, {
          timeout: 15000,
          headers: { referer: url, accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8' },
        });
        if (!r.ok()) { out.push(`  - NG \`${f.url.slice(0, 80)}\` -> HTTP ${r.status()}\n`); continue; }
        const body = await r.body();
        const ct = (r.headers()['content-type'] || '').split(';')[0];
        if (body.length <= 400) { out.push(`  - NG \`${f.url.slice(0, 80)}\` -> ${body.length} bytes（小さすぎる）\n`); continue; }
        if (!/^image\//.test(ct)) { out.push(`  - NG \`${f.url.slice(0, 80)}\` -> 画像ではない（${ct}）\n`); continue; }
        const ext = /svg/.test(ct) ? 'svg' : /jpe?g/.test(ct) ? 'jpg' : /webp/.test(ct) ? 'webp'
                  : /avif/.test(ct) ? 'avif' : 'png';
        const name = `${key}-${n}.${ext}`;
        fs.writeFileSync(`${DIR}/${name}`, body);
        out.push(`  - OK \`${name}\`（**${body.length} bytes** / ${ct} / ${f.w}x${f.h} / alt: ${JSON.stringify(f.alt.slice(0, 40))}）\n`);
        out.push(`    - 取得元: \`${f.url}\`\n`);
        n++;
      } catch (e) {
        out.push(`  - NG \`${f.url.slice(0, 70)}\` -> ${String(e).slice(0, 90)}\n`);
      }
    }
    out.push('\n');
  } catch (e) {
    out.push(`- **${String(e).slice(0, 140)}**\n\n`);
  } finally {
    if (page) { try { await page.close(); } catch {} }
  }
}

// **`browser.close()` は呼ばない。** CDP 越しに呼ぶと利用者の Chrome ごと落ちる
console.log(out.join(''));
process.exit(0);
JS

# **`timeout` は macOS に無い**（最上位ルール 14）。素の bash で待つ
CDP_PORT="$PORT" GRAB_DIR="$DIR" PW_DIR="$PWDIR" node "$SCRIPT" >> "$OUT" 2>&1 &
PID=$!
START=$(date +%s)
while kill -0 "$PID" 2>/dev/null; do
  [ $(( $(date +%s) - START )) -ge 240 ] && { kill "$PID" 2>/dev/null; echo "" >> "$OUT"; echo "**240 秒 で打ち切った**" >> "$OUT"; break; }
  sleep 2
done
wait "$PID" 2>/dev/null
rm -f "$SCRIPT"

N=$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ')
case "$N" in ''|*[!0-9]*) N=0 ;; esac
{
  echo ""
  echo "---"
  echo ""
  echo "**$N 件 持ち帰った。** 経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "**採否はクラウド側でコンタクトシートを見て決める。**"
} >> "$OUT"

cat "$OUT"
