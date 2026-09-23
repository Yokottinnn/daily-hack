#!/bin/bash
# **取得元が未記録のロゴを取り直す・その1（ポイントサイトとアンケート）（t183）。LLM 不使用・$0。**
#
# ## なぜ取り直すか
#
# `point-service-complete-guide-2026` のロゴは **#433 でまとめて入り、
# 取得元がどこにも記録されていない。** 最上位ルール 17 は
# 「**どこから取ったか言えない画像は使わない**」と決めている。
#
# **表示はできている。穴は出所の記録のほう。** 公式サイトから取り直して、
# `_manifest.json` に **URL と取得日**を残せる状態にする。
#
# **この回で見るのは 11 ブランド**（ポイントサイト 4・アンケート 4・移動/健康 3）。
# 残り（共通ポイント・流通・商業施設）は **t184** で見る。
# **測るものと直すものを分ける**（最上位ルール 15）のと同じ理由で、1 本に詰め込まない。
#
# ## URL は推測で組み立てない（最上位ルール 17）
#
# **記事にリンクが無いブランドばかり**なので、
# **実ブラウザで検索して、出てきた URL とページタイトルを持ち帰る。**
# 採否はクラウド側でコンタクトシートを見て決める。
#
# ## t182 で分かったことを踏まえている
#
# - **`page.evaluate(fetch)` は CORS で落ちる。** `ctx.request.get()` を使う
# - **拡張子は content-type から決める。** gif を png と書くと、あとで判別できない
#
# ## 却下する条件（最上位ルール 17）
#
# - **親ブランド・運営会社**をサービスのロゴとして使わない
# - **周年版・キャンペーン版**
# - **他社のロゴが並んでいる画像**（提携先一覧など）
#
# ## X 運用の Chrome を借りるだけ（t174 から変えていない）
#
# - 新しいタブを開いて、終わったら必ず閉じる。既存のタブに触らない
# - **`browser.close()` を呼ばない。** 呼ぶと**利用者の Chrome ごと落ちる**
#
# **240 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t183-logo-sources-a.md"
DIR="$RDIR/logos-logo-sources-a"
mkdir -p "$DIR"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PORT="${CDP_PORT:-18810}"

{
  echo "# 取得元が未記録のロゴを取り直す・その1（ポイントサイトとアンケート）（t183・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**取得元が記録されていないロゴを、公式サイトから取り直す。**"
  echo "**URL は推測せず、実ブラウザの検索で突き止める。**"
  echo ""
} > "$OUT"

VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null || true)"
if [ -z "$VER" ]; then
  echo "**CDP に繋がらない。** 何もせず終わる。" >> "$OUT"; cat "$OUT"; exit 0
fi
cd "$REPO" 2>/dev/null || { echo "**リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
PWDIR=""
for d in "$REPO/node_modules" "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }
done
[ -n "$PWDIR" ] || { echo "**\`playwright-core\` が無い。**" >> "$OUT"; cat "$OUT"; exit 0; }
echo "- CDP **生きている** / \`playwright-core\`: \`$PWDIR/playwright-core\`" >> "$OUT"
echo "" >> "$OUT"

TARGETS='[["moppy","モッピー","モッピー ポイントサイト 公式サイト"],["hapitas","ハピタス","ハピタス ポイントサイト 公式サイト"],["ecnavi","ECナビ","ECナビ ポイントサイト 公式サイト"],["chobirich","ちょびリッチ","ちょびリッチ ポイントサイト 公式サイト"],["macromill","マクロミル","マクロミル アンケートモニター 公式サイト"],["cuemonitor","キューモニター","キューモニター アンケートモニター 公式サイト"],["powl","Powl","Powl アンケートアプリ 公式サイト"],["rakuteninsight","楽天インサイト","楽天インサイト アンケート 公式サイト"],["anapocket","ANA Pocket","ANA Pocket 移動でマイル 公式サイト"],["jalwellness","JAL Wellness & Travel","JAL Wellness Travel 公式サイト"],["dhealth","dヘルスケア","dヘルスケア ドコモ 公式サイト"]]'

SCRIPT="$RDIR/.t183-grab.mjs"
cat > "$SCRIPT" <<'JS'
import fs from 'node:fs';
import { createRequire } from 'node:module';
// **ESM の import は `NODE_PATH` を見ない。** CommonJS の require で場所を指定して解決する
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');

const PORT = process.env.CDP_PORT || '18810';
const DIR = process.env.GRAB_DIR;
// **URL は書かない。** 記事にリンクが無いので、**実ブラウザで検索して実物の URL を突き止める**
const TARGETS = JSON.parse(process.env.TARGETS);

const browser = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`);
const ctx = browser.contexts()[0];
const out = [];
const started = Date.now();

async function findUrl(query) {
  const p = await ctx.newPage();
  try {
    await p.goto('https://duckduckgo.com/html/?q=' + encodeURIComponent(query),
                 { waitUntil: 'domcontentloaded', timeout: 20000 });
    await p.waitForTimeout(900);
    return await p.evaluate(() => {
      const rows = [];
      for (const a of document.querySelectorAll('a.result__a, a[data-testid="result-title-a"]')) {
        let h = a.href;
        try { const u = new URL(h, location.href); const d = u.searchParams.get('uddg');
              if (d) h = decodeURIComponent(d); } catch {}
        if (/^https?:/.test(h)) rows.push({ href: h, text: (a.textContent || '').trim().slice(0, 60) });
        if (rows.length >= 3) break;
      }
      return rows;
    });
  } catch (e) { return [{ href: '', text: 'ERR ' + String(e).slice(0, 70) }]; }
  finally { try { await p.close(); } catch {} }
}

for (const [key, jp, query] of TARGETS) {
  if (Date.now() - started > 190000) { out.push(`## ${jp}\n\n- 時間切れ。見ていない\n\n`); continue; }
  out.push(`## ${jp}（\`${key}\`）\n\n`);
  const hits = await findUrl(query);
  for (const h of hits) out.push(`- 検索: ${JSON.stringify(h.text)} -> \`${h.href}\`\n`);
  const url = (hits.find((h) => /^https?:/.test(h.href)) || {}).href || '';
  if (!url) { out.push('- **URL が取れない**\n\n'); continue; }

  let page = null;
  try {
    page = await ctx.newPage();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 18000 });
    await page.waitForTimeout(1200);
    const title = (await page.title()).slice(0, 70);
    out.push(`- \`${url}\` -> **開けた**（title: ${JSON.stringify(title)}）\n`);
    // **404 を「開けた」と書かない**（最上位ルール 11）
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
      return rows.slice(0, 5);
    });
    if (!found.length) out.push('- **ロゴらしい img が無い**\n');

    let n = 0;
    for (const f of found) {
      if (n >= 3) break;
      try {
        // **`ctx.request` はブラウザの外で走るので CORS が効かない**（t182 で分かったこと）
        const r = await ctx.request.get(f.url, {
          timeout: 12000,
          headers: { referer: url, accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8' },
        });
        if (!r.ok()) { out.push(`  - NG \`${f.url.slice(0, 80)}\` -> HTTP ${r.status()}\n`); continue; }
        const body = await r.body();
        const ct = (r.headers()['content-type'] || '').split(';')[0];
        if (body.length <= 400) { out.push(`  - NG \`${f.url.slice(0, 80)}\` -> ${body.length} bytes\n`); continue; }
        if (!/^image\//.test(ct)) { out.push(`  - NG \`${f.url.slice(0, 80)}\` -> 画像ではない（${ct}）\n`); continue; }
        // **中身で拡張子を決める。** gif を png と書くと、あとで判別できなくなる（t182 で踏んだ）
        const ext = /svg/.test(ct) ? 'svg' : /jpe?g/.test(ct) ? 'jpg' : /webp/.test(ct) ? 'webp'
                  : /avif/.test(ct) ? 'avif' : /gif/.test(ct) ? 'gif' : 'png';
        const name = `${key}-${n}.${ext}`;
        fs.writeFileSync(`${DIR}/${name}`, body);
        out.push(`  - OK \`${name}\`（**${body.length} bytes** / ${ct} / ${f.w}x${f.h} / alt: ${JSON.stringify(f.alt.slice(0, 40))}）\n`);
        out.push(`    - 取得元: \`${f.url}\`\n`);
        n++;
      } catch (e) {
        out.push(`  - NG \`${f.url.slice(0, 70)}\` -> ${String(e).slice(0, 80)}\n`);
      }
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

# **`timeout` は macOS に無い**（最上位ルール 14）。素の bash で待つ
CDP_PORT="$PORT" GRAB_DIR="$DIR" PW_DIR="$PWDIR" TARGETS="$TARGETS" node "$SCRIPT" >> "$OUT" 2>&1 &
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
  echo "**採ったものは \`_manifest.json\` に取得元 URL と取得日を残す**（最上位ルール 17）。"
} >> "$OUT"

cat "$OUT"
