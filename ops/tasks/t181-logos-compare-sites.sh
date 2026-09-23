#!/bin/bash
# **比較サイト 4 社のロゴを実ブラウザで取る（t181）。LLM 不使用・$0。**
#
# ## なぜ要るか
#
# 表にブランド名が並んでいるのにロゴが置けていない箇所が残っている
# （最上位ルール 17 は「**もれなく全て**」）。
#
# | ブランド | 出る記事 | 表の中で今どうなっているか |
# | --- | --- | --- |
# | ワラウ | `point-service-complete-guide-2026` | **6 行中この 1 行だけロゴが無い** |
# | 保険スクエアbang! | `car-insurance-comparison-2026` | 一括見積もりの表・**4 行中 3 行がロゴ無し** |
# | 価格.com 自動車保険 | 同上 | 〃 |
# | 楽天保険の窓口 | 同上 | 〃 |
#
# ## URL の出どころ（**推測で組み立てない**・最上位ルール 17）
#
# **3 つは記事の中のリンクから取った。**
#
#   保険スクエアbang!   https://www.bang.co.jp/auto/
#   価格.com 自動車保険  https://kakaku.com/kuruma_hoken/
#   楽天保険の窓口       https://hoken.rakuten.co.jp/car/
#
# **ワラウだけ記事にリンクが無い。** だから**当てずっぽうで URL を打たず、
# 実ブラウザで検索して、出てきた URL とページタイトルを持ち帰る。**
# 採否はクラウド側で決める。
#
# ## 気をつけること（最上位ルール 17）
#
# - **親ブランド・運営会社を、サービスのロゴとして出さない。**
#   「楽天」のロゴは**楽天保険の窓口のロゴではない**。オープンスマイルは**ワラウではない**
# - 取得元 URL をレポートに残す（`_manifest.json` に書くため）
#
# ## X 運用の Chrome を借りるだけ（t174 から変えていない）
#
# - 新しいタブを開いて、終わったら必ず閉じる。既存のタブに触らない
# - **`browser.close()` を呼ばない。** 呼ぶと**利用者の Chrome ごと落ちる**
# - ログインが要るページを開かない
#
# **`playwright-core`**（`playwright` ではない・最上位ルール 14）。**入れ直さない。**
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t181-logos-compare-sites.md"
DIR="$RDIR/logos-compare"
mkdir -p "$DIR"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PORT="${CDP_PORT:-18810}"

{
  echo "# 比較サイト 4 社のロゴを実ブラウザで取る（t181・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**URL は記事のリンクから取った。ワラウだけ記事にリンクが無いので検索する。**"
  echo ""
} > "$OUT"

VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null || true)"
if [ -z "$VER" ]; then
  echo "⚠️ **CDP に繋がらない。** 何もせず終わる。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- CDP **生きている**" >> "$OUT"; echo "" >> "$OUT"

cd "$REPO" 2>/dev/null || { echo "⚠️ リポジトリが無い: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }

PWDIR=""
for d in "$REPO/node_modules" "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }
done
[ -n "$PWDIR" ] || { echo "⚠️ **\`playwright-core\` が無い。** 何もせず終わる" >> "$OUT"; cat "$OUT"; exit 0; }
echo "- \`playwright-core\`: \`$PWDIR/playwright-core\`" >> "$OUT"; echo "" >> "$OUT"

SCRIPT="$RDIR/.t181-grab.mjs"
cat > "$SCRIPT" <<'JS'
import fs from 'node:fs';
import { createRequire } from 'node:module';
// **ESM の import は `NODE_PATH` を見ない。** CommonJS の require で場所を指定して解決する
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');

const PORT = process.env.CDP_PORT || '18810';
const DIR = process.env.GRAB_DIR;
// url が null のものは **検索して URL を先に突き止める**
const TARGETS = [
  ['bang', '保険スクエアbang!', 'https://www.bang.co.jp/auto/'],
  ['kakaku', '価格.com 自動車保険', 'https://kakaku.com/kuruma_hoken/'],
  ['rakuten-hoken', '楽天保険の窓口', 'https://hoken.rakuten.co.jp/car/'],
  ['warau', 'ワラウ', null, 'ワラウ ポイントサイト 公式'],
];

const browser = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`);
const ctx = browser.contexts()[0];
const out = [];
const started = Date.now();

// **当てずっぽうで URL を打たない。** 検索結果の実物から取る
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
        // DuckDuckGo の中継 URL から実体を取り出す
        try {
          const u = new URL(h, location.href);
          const d = u.searchParams.get('uddg');
          if (d) h = decodeURIComponent(d);
        } catch {}
        if (/^https?:/.test(h)) rows.push({ href: h, text: (a.textContent || '').trim().slice(0, 60) });
        if (rows.length >= 5) break;
      }
      return rows;
    });
  } catch (e) {
    return [{ href: '', text: 'ERR ' + String(e).slice(0, 80) }];
  } finally { try { await p.close(); } catch {} }
}

for (const [key, jp, fixedUrl, query] of TARGETS) {
  if (Date.now() - started > 200000) { out.push(`## ${jp}\n\n- ⏱️ **時間切れ**\n\n`); continue; }
  let url = fixedUrl;
  out.push(`## ${jp}\n\n`);
  if (!url) {
    const hits = await findUrl(query);
    out.push(`- 検索 \`${query}\` の上位:\n`);
    for (const h of hits) out.push(`  - ${JSON.stringify(h.text)} → \`${h.href}\`\n`);
    url = (hits.find((h) => /^https?:/.test(h.href)) || {}).href || '';
    if (!url) { out.push('- ❌ **URL が取れない**\n\n'); continue; }
    out.push(`- **この URL で開く**: \`${url}\`（採否はクラウド側で見る）\n`);
  }

  let page = null;
  try {
    page = await ctx.newPage();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForTimeout(1500);
    const title = (await page.title()).slice(0, 70);
    out.push(`- \`${url}\` → **開けた**（title: ${JSON.stringify(title)}）\n`);

    const found = await page.evaluate(() => {
      const abs = (u) => { try { return new URL(u, location.href).href; } catch { return null; } };
      const rows = []; const seen = new Set();
      const add = (img, why) => {
        const u = abs(img.currentSrc || img.src);
        if (!u || seen.has(u)) return;
        // **小さすぎるものは入れない。** favicon を掴んで終わるのを防ぐ
        if (img.naturalWidth && img.naturalWidth < 40) return;
        seen.add(u);
        rows.push({ url: u, alt: `${img.alt || ''}${why}`, w: img.naturalWidth, h: img.naturalHeight });
      };
      for (const img of document.querySelectorAll('img')) {
        const s = `${img.className} ${img.alt || ''} ${img.src || ''}`.toLowerCase();
        if (/logo|ロゴ/.test(s)) add(img, '');
      }
      // **`logo` が入っていないサイトがある。** ヘッダと h1 の中も拾う
      for (const sel of ['header img', 'h1 img', '[class*="header"] img', '[id*="header"] img']) {
        for (const img of document.querySelectorAll(sel)) add(img, ' [header]');
      }
      return rows.slice(0, 6);
    });
    if (!found.length) out.push('- ⚠️ **ロゴらしい img が無い**\n');

    let n = 0;
    for (const f of found) {
      if (n >= 4) break;
      try {
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
        if (b64.err) { out.push(`  - ❌ \`${f.url.slice(0, 80)}\` → ${b64.err}\n`); continue; }
        const ext = /svg/.test(b64.ct) ? 'svg' : /jpe?g/.test(b64.ct) ? 'jpg' : /webp/.test(b64.ct) ? 'webp' : 'png';
        const name = `${key}-${n}.${ext}`;
        fs.writeFileSync(`${DIR}/${name}`, Buffer.from(b64.b64, 'base64'));
        out.push(`  - ⬇️ \`${name}\`（**${b64.size} bytes** / ${b64.ct} / ${f.w}x${f.h} / alt: ${JSON.stringify(f.alt.slice(0, 40))}）\n`);
        out.push(`    - 取得元: \`${f.url}\`\n`);
        n++;
      } catch (e) {
        out.push(`  - ❌ \`${f.url.slice(0, 70)}\` → ${String(e).slice(0, 80)}\n`);
      }
    }
    out.push('\n');
  } catch (e) {
    out.push(`- ❌ **${String(e).slice(0, 140)}**\n\n`);
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
  [ $(( $(date +%s) - START )) -ge 240 ] && { kill "$PID" 2>/dev/null; echo "" >> "$OUT"; echo "⏱️ **240 秒 で打ち切った**" >> "$OUT"; break; }
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
  echo "**$N 件 持ち帰った。**"
  echo ""
  echo "**却下するもの**（最上位ルール 17）"
  echo ""
  echo "- **楽天のロゴを「楽天保険の窓口」のロゴとして使わない**（親ブランド）"
  echo "- **オープンスマイルのロゴを「ワラウ」のロゴとして使わない**（運営会社）"
  echo "- キャンペーン版・周年版"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
