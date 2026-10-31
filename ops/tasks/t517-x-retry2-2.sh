#!/bin/bash
# **比較記事に載せる X の実投稿と YouTube を探す（t517・X の再取り直し 2/4）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-10-31 利用者「Xの投稿記事とかYoutubeの動画は私の記事だとマストなのだけど、ちゃんと入れて欲しいので、比較記事を全て見直して」。
# t496〜t503 で X が 0 件だった 26 本の取り直し（検索語は ops/data/embed-search/xretry2-2.json）。1 回ごとに 10 秒あける。X は話題順の上位を syndication で本文・日付・いいね数まで確かめ、YouTube は検索結果を oEmbed で照合する。230 秒で打ち切る。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t517-embed-search.md"
PORT="${CDP_PORT:-18810}"
mkdir -p "$RDIR"

{
  echo "# 比較記事の X・YouTube の候補（t517・**\$0**）"
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

REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
QJSON="$RDIR/.t517-q.json"
git -C "$REPO" show origin/main:ops/data/embed-search/xretry2-2.json > "$QJSON" 2>/dev/null || { echo "⚠️ 検索語の JSON が main に無い" >> "$OUT"; cat "$OUT"; exit 0; }
SCRIPT="$RDIR/.t517-embed.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const Q = JSON.parse(fs.readFileSync(process.env.QJSON, 'utf8'));
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const t0 = Date.now();
const res = {};
for (const it of Q) {
  if (Date.now() - t0 > 215000) { console.log(`- ⏱ 時間切れ（${it.slug} 以降は次の回）`); break; }
  const r = res[it.slug] = { x: [], yt: [] };
  console.log(`\n## ${it.slug}`);
  let ids = [];
  for (const q of it.x) {
    try {
      await p.goto(`https://x.com/search?q=${encodeURIComponent(q + ' since:2025-10-01 -filter:replies lang:ja')}&src=typed_query&f=top`, { waitUntil: 'domcontentloaded', timeout: 25000 });
      await p.waitForTimeout(6000);
      const got = await p.evaluate(() => document.querySelectorAll('article').length);
      if (!got) console.log(`- ⚠️ X の結果が 0 件（${q}）: ${(await p.evaluate(() => document.body.innerText.replace(/\s+/g, ' ').slice(0, 160)))}`);
      ids.push(...await p.evaluate(() => [...document.querySelectorAll('article')].slice(0, 6).map((a) => ([...a.querySelectorAll('a[href*="/status/"]')].map((x) => x.getAttribute('href')).find((h) => /\/status\/\d+$/.test(h)) || '').split('/status/')[1]).filter(Boolean)));
      await p.waitForTimeout(20000);
    } catch (e) { console.log(`- ⚠️ X 検索失敗 ${q}: ${String(e).slice(0, 100)}`); }
  }
  for (const id of [...new Set(ids)].slice(0, 9)) {
    try {
      const j = await (await fetch(`https://cdn.syndication.twimg.com/tweet-result?id=${id}&lang=ja&token=a`)).json();
      const o = { id, name: j.user?.name, sn: j.user?.screen_name, blue: !!(j.user?.is_blue_verified || j.user?.verified), at: j.created_at, likes: j.favorite_count ?? null, text: (j.text || '').replace(/\s+/g, ' ').slice(0, 300), media: !!(j.mediaDetails?.length) };
      r.x.push(o);
      console.log(`- X ${id} @${o.sn} ${o.blue ? '✔' : ''} ${o.at?.slice(0, 10)} ♥${o.likes} ${o.text.slice(0, 90)}`);
    } catch (e) { console.log(`- X ${id} ⚠️ syndication 失敗`); }
  }
  if (it.yt) try {
    await p.goto(`https://www.youtube.com/results?search_query=${encodeURIComponent(it.yt)}`, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4000);
    const vids = await p.evaluate(() => [...document.querySelectorAll('ytd-video-renderer')].slice(0, 6).map((v) => ({ id: (v.querySelector('a#thumbnail')?.href || '').match(/v=([\w-]{11})/)?.[1], title: v.querySelector('#video-title')?.textContent.trim(), ch: v.querySelector('ytd-channel-name a')?.textContent.trim(), meta: v.querySelector('#metadata-line')?.innerText.replace(/\s+/g, ' ') })).filter((v) => v.id));
    for (const v of vids) {
      try {
        const o = await (await fetch(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${v.id}&format=json`)).json();
        r.yt.push({ ...v, oTitle: o.title, oAuthor: o.author_name });
        console.log(`- YT ${v.id} 「${o.title.slice(0, 70)}」 / ${o.author_name} / ${v.meta}`);
      } catch { console.log(`- YT ${v.id} ⚠️ oEmbed で照合できない（埋め込み不可の可能性）`); }
    }
  } catch (e) { console.log(`- ⚠️ YouTube 検索失敗: ${String(e).slice(0, 100)}`); }
}
fs.writeFileSync(process.env.RES_JSON, JSON.stringify(res, null, 1));
console.log(`\n---\n対象 ${Q.length} / 読めた ${Object.keys(res).length}`);
await p.close().catch(() => {});
process.exit(0);
JS
mkdir -p "$RDIR/embed-search"
RES="$RDIR/.t517-res.txt"
QJSON="$QJSON" RES_JSON="$RDIR/embed-search/xretry2-2.json" PW_DIR="$PWDIR" CDP_PORT="$PORT" run_limited 235 node "$SCRIPT" > "$RES" 2>&1
echo "rc=$?" >> "$OUT"
cat "$RES" >> "$OUT"
head -c 9000 "$OUT"
