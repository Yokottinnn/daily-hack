#!/bin/bash
# **ソフトバンク光と JAL Pay のロゴを取る（t189）。LLM 不使用・$0。**
#
# ## なぜこの 2 つだけ残っているか
#
# **どちらも親ブランドのロゴしか在庫が無い。**
# 最上位ルール 17 は「運営会社・親ブランドを子ブランドに当てない」と決めている。
#
# | 記事 | 見出し／セル | 在庫に在るもの | なぜ使えない |
# | --- | --- | --- | --- |
# | `internet-line-comparison-2026` | `ソフトバンク光` | `softbank.png` | **ソフトバンク＝親ブランド** |
# | `point-kaiaku-timeline-2026` | `JAL Pay` | `jal.png` | **JAL＝親ブランド** |
#
# **実際に 2026-09-26 に softbank.png を当ててしまい、取り消した。**
# 同じことを繰り返さないために、自前のロゴを取りに行く。
#
# ## 2 つの入口を両方 通す
#
#   ① **App Store**（iTunes Search API）… アプリが在れば正方形のアイコンが取れる
#   ② **実ブラウザ（CDP）**… 公式サイトのヘッダのロゴ。curl では弾かれる
#
# **どちらが当たるか分からないので両方 出して、採否はクラウド側で決める。**
# `trackName` / `sellerName` と、取ったページの title を必ず出す
# （**取り違えを人が見て弾けるようにする**・最上位ルール 11）。
#
# ## 気をつけること
#
# - **「ソフトバンク」で検索すると親ブランドが返る。** `ソフトバンク光` で引く
# - **JAL Pay は「JALマイレージバンク」「JAL」と紛らわしい**
# - `ctx.request.get()` を使う（`page.evaluate(fetch)` は **CORS で落ちる**・t182）
# - **`browser.close()` を呼ばない。** 利用者の Chrome ごと落ちる
#
# **180 秒 で打ち切る**（最上位ルール 15）。2 ブランドだけ。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t189-logos-sbhikari-jalpay.md"
DIR="$RDIR/logos-sbjal"
mkdir -p "$DIR"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PORT="${CDP_PORT:-18810}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

{
  echo "# ソフトバンク光と JAL Pay のロゴを取る（t189・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**どちらも親ブランドのロゴしか在庫が無い。** 自前のロゴを取りに行く。"
  echo "**App Store と実ブラウザの両方を通して、採否はクラウド側で決める。**"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "**curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "**python3 が無い**" >> "$OUT"; cat "$OUT"; exit 0; }
START=$(date +%s)

# ======== ① App Store ========
{ echo "## ① App Store（iTunes Search API）"; echo ""; } >> "$OUT"
LIST="$RDIR/.t189-list.tsv"
cat > "$LIST" <<'TSV'
sbhikari	ソフトバンク光	ソフトバンク光	SoftBank
jalpay	JAL Pay	JAL Pay	JAL
TSV
# **末尾に改行が無くても最後の 1 行を読む**（最上位ルール 14）
while IFS=$'\t' read -r key jp term seller || [ -n "${key:-}" ]; do
  [ -n "${key:-}" ] || continue
  { echo "### $jp"; echo ""; echo "- 検索語 \`$term\` / 期待する提供元 **$seller**"; } >> "$OUT"
  Q="$(printf '%s' "$term" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read().strip()))')"
  J="$RDIR/.t189-$key.json"
  curl -sS -A "$UA" --max-time 12 \
    "https://itunes.apple.com/search?country=jp&entity=software&limit=3&term=$Q" -o "$J" 2>/dev/null || true
  ART="$(python3 - "$J" <<'PY' 2>/dev/null || true
import json, sys
try: d = json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
rs = d.get("results") or []
for r in rs[:3]:
    print("  - {} / **{}** / id={}".format(r.get("trackName","?"), r.get("sellerName","?"), r.get("trackId","?")))
print("@@@")
print((rs[0].get("artworkUrl512") or rs[0].get("artworkUrl100") or "") if rs else "")
PY
)"
  rm -f "$J"
  ROWS="$(printf '%s' "$ART" | sed -n '1,/^@@@$/p' | sed '$d')"
  URL="$(printf '%s' "$ART" | sed -n '/^@@@$/,$p' | sed '1d' | head -1)"
  if [ -z "$ROWS" ]; then
    { echo "- **上位 3 件が取れない**"; echo ""; } >> "$OUT"; continue
  fi
  { echo "- 上位 3 件:"; printf '%s\n' "$ROWS"; } >> "$OUT"
  if [ -n "$URL" ]; then
    code="$(curl -sS -A "$UA" --max-time 15 -o "$DIR/$key-app.png" -w '%{http_code}' "$URL" 2>/dev/null || echo 000)"
    n=$(wc -c < "$DIR/$key-app.png" 2>/dev/null | head -1 | tr -d ' ')
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    if [ "$n" -le 1000 ]; then rm -f "$DIR/$key-app.png"
      echo "- **落とせない**: HTTP $code / $n bytes" >> "$OUT"
    else
      { echo "- OK \`$key-app.png\`（**$n bytes** / HTTP $code）"; echo "  - 取得元: \`$URL\`"; } >> "$OUT"
    fi
  fi
  echo "" >> "$OUT"
done < "$LIST"
rm -f "$LIST"

# ======== ② 実ブラウザ（公式サイトのヘッダ） ========
{ echo "## ② 実ブラウザ（公式サイト）"; echo ""; } >> "$OUT"
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null || true)"
PWDIR=""
for d in "$REPO/node_modules" "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }
done
if [ -z "$VER" ] || [ -z "$PWDIR" ]; then
  echo "- **CDP か playwright-core が無いので、この入口は通していない**" >> "$OUT"
else
  SCRIPT="$RDIR/.t189-grab.mjs"
  cat > "$SCRIPT" <<'JS'
import fs from 'node:fs';
import { createRequire } from 'node:module';
// **ESM の import は `NODE_PATH` を見ない。** CommonJS の require で場所を指定して解決する
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const PORT = process.env.CDP_PORT || '18810';
const DIR = process.env.GRAB_DIR;
// **URL は記事のリンクから取った。推測で組み立てない**
const TARGETS = [
  ['sbhikari', 'ソフトバンク光', 'https://www.softbank.jp/internet/hikari/'],
  ['jalpay', 'JAL Pay', 'https://www.jal.co.jp/jp/ja/jalmile/jalpay/'],
];
const browser = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`);
const ctx = browser.contexts()[0];
const out = [];
for (const [key, jp, url] of TARGETS) {
  let page = null;
  out.push(`### ${jp}\n\n`);
  try {
    page = await ctx.newPage();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForTimeout(1500);
    const title = (await page.title()).slice(0, 70);
    out.push(`- \`${url}\` -> **開けた**（title: ${JSON.stringify(title)}）\n`);
    if (/404|not found/i.test(title)) out.push('- **404 らしい。当てにしない**\n');
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
      return rows.slice(0, 6);
    });
    if (!found.length) out.push('- **ロゴらしい img が無い**\n');
    let n = 0;
    for (const f of found) {
      if (n >= 4) break;
      try {
        // **`ctx.request` はブラウザの外で走るので CORS が効かない**（t182）
        const r = await ctx.request.get(f.url, {
          timeout: 12000,
          headers: { referer: url, accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8' },
        });
        if (!r.ok()) { out.push(`  - NG \`${f.url.slice(0, 80)}\` -> HTTP ${r.status()}\n`); continue; }
        const body = await r.body();
        const ct = (r.headers()['content-type'] || '').split(';')[0];
        if (body.length <= 400) { out.push(`  - NG \`${f.url.slice(0, 80)}\` -> ${body.length} bytes\n`); continue; }
        if (!/^image\//.test(ct)) { out.push(`  - NG \`${f.url.slice(0, 80)}\` -> 画像ではない（${ct}）\n`); continue; }
        // **中身で拡張子を決める。** gif を png と書くと、あとで判別できなくなる
        const ext = /svg/.test(ct) ? 'svg' : /jpe?g/.test(ct) ? 'jpg' : /webp/.test(ct) ? 'webp'
                  : /avif/.test(ct) ? 'avif' : /gif/.test(ct) ? 'gif' : 'png';
        const name = `${key}-web${n}.${ext}`;
        fs.writeFileSync(`${DIR}/${name}`, body);
        out.push(`  - OK \`${name}\`（**${body.length} bytes** / ${ct} / ${f.w}x${f.h} / alt: ${JSON.stringify(f.alt.slice(0, 40))}）\n`);
        out.push(`    - 取得元: \`${f.url}\`\n`);
        n++;
      } catch (e) { out.push(`  - NG \`${f.url.slice(0, 70)}\` -> ${String(e).slice(0, 80)}\n`); }
    }
    out.push('\n');
  } catch (e) {
    out.push(`- **${String(e).slice(0, 130)}**\n\n`);
  } finally {
    if (page) { try { await page.close(); } catch {} }
  }
}
// **`browser.close()` は呼ばない。** CDP 越しに呼ぶと利用者の Chrome ごと落ちる
console.log(out.join(''));
process.exit(0);
JS
  CDP_PORT="$PORT" GRAB_DIR="$DIR" PW_DIR="$PWDIR" node "$SCRIPT" >> "$OUT" 2>&1 &
  PID=$!
  while kill -0 "$PID" 2>/dev/null; do
    [ $(( $(date +%s) - START )) -ge 180 ] && { kill "$PID" 2>/dev/null; echo "**180 秒 で打ち切った**" >> "$OUT"; break; }
    sleep 2
  done
  wait "$PID" 2>/dev/null
  rm -f "$SCRIPT"
fi

N=$(ls -1 "$DIR" 2>/dev/null | wc -l | head -1 | tr -d ' ')
case "$N" in ''|*[!0-9]*) N=0 ;; esac
{
  echo ""
  echo "---"
  echo ""
  echo "**対象 2 ブランド / 持ち帰った $N 件。** 経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "**却下する条件**（最上位ルール 17）"
  echo ""
  echo "- **ソフトバンク（親ブランド）を「ソフトバンク光」のロゴとして使わない**"
  echo "- **JAL（親ブランド）を「JAL Pay」のロゴとして使わない**"
  echo "- キャンペーン版・周年版"
} >> "$OUT"

cat "$OUT"
