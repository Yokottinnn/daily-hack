#!/bin/bash
# **新電力 3 社のロゴを実ブラウザで取る（t180）。LLM 不使用・$0。**
#
# ## なぜ curl ではなく実ブラウザか
#
# **t177 / t179 で当たった経路。** curl 系 6 経路（トップの `img`・規格アイコン・
# フルヘッダ・MediaWiki・メディアキット・PR TIMES）は 383 bytes / 0 bytes で全滅したが、
# **実ブラウザでは普通に開けた。** 「curl である」こと自体で弾かれていた。
#
# ## 対象（**URL は記事の CTA から取った。推測で組み立てない**・最上位ルール 17）
#
# | ブランド | URL | t167（curl）で何を掴んでいたか |
# | --- | --- | --- |
# | 楽天でんき | `https://energy.rakuten.co.jp/` | **`logo_energy.svg`＝楽天エナジー（運営会社）**。`logo_denki.svg` が在ったのに取りこぼした |
# | auでんき | `https://www.au.com/energy/` | **`au_logo_t.png`＝au（親ブランド）** / `logo_10th.png`＝周年版 |
# | ドコモでんき | `https://denki.docomo.ne.jp/` | **`NTT docomo`＝親ブランド** / `My docomo`＝別サービス |
#
# **auでんきの URL は `/energy/`。** t167 が使った `/electricity/` とは**別ページ**。
#
# ## t179 から変えたこと
#
# **3 社とも「親ブランド／運営会社を掴む」で落ちている。**
# 数を 3 → **5 件**に増やし、**URL とファイル名に `denki` `でんき` が入るものを先に**取る。
# 1 番目だけ持ち帰ると、また親ブランドで終わる。
#
# ## X 運用の Chrome を壊さないための約束（t174 から変えていない）
#
# - **新しいタブを開いて、終わったら必ず閉じる。** 既存のタブに触らない
# - **`browser.close()` を呼ばない。** 呼ぶと**利用者の Chrome ごと落ちる**
# - **ログインが要るページを開かない。** 企業の公開ページだけ
#
# **`playwright-core`**（`playwright` ではない・最上位ルール 14）。
# **入れ直さない。** t175 で実測した場所から `createRequire` で読む。
#
# **判断はしない。候補を持ち帰るだけ。** 採否はクラウド側でコンタクトシートを見て決める。
#
# **3 社だけ。180 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t180-logos-denki.md"
DIR="$RDIR/logos-denki"
mkdir -p "$DIR"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PORT="${CDP_PORT:-18810}"

{
  echo "# 新電力 3 社のロゴを実ブラウザで取る（t180・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**3 社とも t167（curl）では親ブランド・運営会社しか掴めなかった。**"
  echo "**\`denki\` / \`でんき\` を含むものを先に取る。**"
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

# --- `playwright-core` の在りかを探す（**入れ直さない**・t175 で実測済み） ---
PWDIR=""
for d in "$REPO/node_modules" "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }
done
if [ -z "$PWDIR" ]; then
  echo "⚠️ **\`playwright-core\` がどこにも無い。** 何もせず終わる" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- \`playwright-core\`: \`$PWDIR/playwright-core\`" >> "$OUT"
echo "" >> "$OUT"

SCRIPT="$RDIR/.t180-grab.mjs"
cat > "$SCRIPT" <<'JS'
// **既に動いている Chrome に繋ぐ。新しく起動しない。**
import fs from 'node:fs';
import { createRequire } from 'node:module';
// **ESM の import は `NODE_PATH` を見ない。** CommonJS の require で場所を指定して解決する
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');

const PORT = process.env.CDP_PORT || '18810';
const DIR = process.env.GRAB_DIR;
// **URL は記事の CTA から取った。推測で組み立てない**
const TARGETS = [
  ['rakuten-denki', '楽天でんき', 'https://energy.rakuten.co.jp/'],
  ['au-denki', 'auでんき', 'https://www.au.com/energy/'],
  ['docomo-denki', 'ドコモでんき', 'https://denki.docomo.ne.jp/'],
];

const browser = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`);
const ctx = browser.contexts()[0];
const out = [];
const started = Date.now();

for (const [key, jp, url] of TARGETS) {
  if (Date.now() - started > 150000) { out.push(`## ${jp}\n\n- ⏱️ **時間切れ。見ていない**\n\n`); continue; }
  let page = null;
  try {
    // **新しいタブ。既存のタブには触らない**
    page = await ctx.newPage();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForTimeout(1500);

    const found = await page.evaluate(() => {
      const abs = (u) => { try { return new URL(u, location.href).href; } catch { return null; } };
      const rows = [];
      const seen = new Set();
      const add = (img, why) => {
        const u = abs(img.currentSrc || img.src);
        if (!u || seen.has(u)) return;
        // **小さすぎるものは入れない。** favicon を掴んで終わるのを防ぐ
        if (img.naturalWidth && img.naturalWidth < 40) return;
        seen.add(u);
        rows.push({ url: u, alt: `${img.alt || ''}${why}`, w: img.naturalWidth, h: img.naturalHeight });
      };
      // ① 名前・alt・class に logo が入っているもの
      for (const img of document.querySelectorAll('img')) {
        const s = `${img.className} ${img.alt || ''} ${img.src || ''}`.toLowerCase();
        if (/logo|ロゴ/.test(s)) add(img, '');
      }
      // ② **`logo` が入っていないサイトがある**。ヘッダと h1 の中の img も拾う
      for (const sel of ['header img', 'h1 img', '[class*="header"] img', '[id*="header"] img']) {
        for (const img of document.querySelectorAll(sel)) add(img, ' [header]');
      }
      // **`denki` / `でんき` を含むものを先に。**
      // 1 番目だけ持ち帰ると、また親ブランド（au / NTT docomo / 楽天エナジー）で終わる
      const score = (r) => (/denki|でんき|electric/i.test(`${r.url} ${r.alt}`) ? 0 : 1);
      rows.sort((a, b) => score(a) - score(b));
      return rows.slice(0, 8);
    });

    out.push(`## ${jp}\n\n- \`${url}\` → **開けた**（title: ${JSON.stringify((await page.title()).slice(0, 60))}）\n`);
    if (!found.length) { out.push('- ⚠️ **ロゴらしい img が無い**\n'); }

    let n = 0;
    for (const f of found) {
      if (n >= 5) break;
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
        if (b64.err) { out.push(`  - ❌ \`${f.url.slice(0, 80)}\` → ${b64.err}\n`); continue; }
        const ext = /svg/.test(b64.ct) ? 'svg' : /jpe?g/.test(b64.ct) ? 'jpg' : /webp/.test(b64.ct) ? 'webp' : 'png';
        const name = `${key}-${n}.${ext}`;
        fs.writeFileSync(`${DIR}/${name}`, Buffer.from(b64.b64, 'base64'));
        // **どこから取ったかを残す**（`_manifest.json` に書くため・最上位ルール 17）
        out.push(`  - ⬇️ \`${name}\`（**${b64.size} bytes** / ${b64.ct} / ${f.w}x${f.h} / alt: ${JSON.stringify(f.alt.slice(0, 40))}）\n`);
        out.push(`    - 取得元: \`${f.url}\`\n`);
        n++;
      } catch (e) {
        out.push(`  - ❌ \`${f.url.slice(0, 70)}\` → ${String(e).slice(0, 80)}\n`);
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
console.log(out.join(''));
process.exit(0);
JS

# **`timeout` は macOS に無い**（最上位ルール 14）。素の bash で待つ
CDP_PORT="$PORT" GRAB_DIR="$DIR" PW_DIR="$PWDIR" node "$SCRIPT" >> "$OUT" 2>&1 &
PID=$!
START=$(date +%s)
while kill -0 "$PID" 2>/dev/null; do
  [ $(( $(date +%s) - START )) -ge 180 ] && { kill "$PID" 2>/dev/null; echo "" >> "$OUT"; echo "⏱️ **180 秒 で打ち切った**" >> "$OUT"; break; }
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
  echo "**採否はクラウド側でコンタクトシートを見て決める。** 次は却下する:"
  echo ""
  echo "- **親ブランド**（au / NTT docomo）を、でんきのロゴとして使わない"
  echo "- **運営会社**（楽天エナジー）を、楽天でんきのロゴとして使わない"
  echo "- **周年版・キャンペーン版**（\`logo_10th\` など）"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
} >> "$OUT"

cat "$OUT"
