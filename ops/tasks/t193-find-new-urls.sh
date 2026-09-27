#!/bin/bash
# **切れたリンクの正しい URL を探す（t193）。LLM 不使用・$0。**
#
# ## t192 で「切れている」が 26 件 確定した
#
# **実ブラウザで開いて title を見た結果なので、これは確か。**
#
#   "404 Not Found" / "ページが見つかりません | Ｌｏｏｏｐ" /
#   "お探しのページが見つかりません｜ENEOS" / "該当ページURLは存在しません" …
#
# ## 差し替え先を当て推量で作らない（最上位ルール 17 と同じ作法）
#
# **検索語は記事のリンク文字から作った。** 「その記事が何を指すつもりだったか」の
# 一次情報はリンク文字であって、URL の形ではない。
#
#   `<a href="https://www.eneos.co.jp/denki/">ENEOSでんき 公式 →</a>`
#                                              ^^^^^^^^^^ ここから「ENEOSでんき 公式」
#
# リンク文字が無い 3 件（`references` に在るものなど）だけ、記事の主題から補った。
#
# ## 何を持ち帰るか
#
#   ① 検索の上位 3 件（**URL とタイトル**）
#   ② 1 件目を実際に開いた title
#
# **採否はクラウド側で決める。** 同名の別ページ・まとめサイトをここで弾く。
#
# ## X 運用の Chrome を借りるだけ
#
# 新しいタブを開いて必ず閉じる。**`browser.close()` を呼ばない**（利用者の Chrome ごと落ちる）。
#
# **280 秒 で打ち切る**（最上位ルール 15）。26 件。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t193-find-new-urls.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PORT="${CDP_PORT:-18810}"

{
  echo "# 切れたリンクの正しい URL を探す（t193・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**検索語は記事のリンク文字から作った。** URL の形から推測していない。"
  echo "**採否はクラウド側で決める。** 同名の別ページ・まとめサイトはそこで弾く。"
  echo ""
} > "$OUT"

VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null || true)"
PWDIR=""
for d in "$REPO/node_modules" "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }
done
if [ -z "$VER" ] || [ -z "$PWDIR" ]; then
  echo "⚠️ **CDP か playwright-core が無い。** 何もせず終わる。" >> "$OUT"; cat "$OUT"; exit 0
fi

SCRIPT="$RDIR/.t193.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
// **ESM の import は `NODE_PATH` を見ない。** CommonJS の require で場所を指定して解決する
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const PORT = process.env.CDP_PORT || '18810';
const ROWS = JSON.parse(process.env.ROWS);

const browser = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`);
const ctx = browser.contexts()[0];
const started = Date.now();
const out = [];

async function search(q) {
  const p = await ctx.newPage();
  try {
    await p.goto('https://duckduckgo.com/html/?q=' + encodeURIComponent(q),
                 { waitUntil: 'domcontentloaded', timeout: 18000 });
    await p.waitForTimeout(800);
    return await p.evaluate(() => {
      const rows = [];
      for (const a of document.querySelectorAll('a.result__a, a[data-testid="result-title-a"]')) {
        let h = a.href;
        try { const u = new URL(h, location.href); const d = u.searchParams.get('uddg');
              if (d) h = decodeURIComponent(d); } catch {}
        if (/^https?:/.test(h)) rows.push({ href: h, text: (a.textContent || '').trim().slice(0, 70) });
        if (rows.length >= 3) break;
      }
      return rows;
    });
  } catch (e) { return [{ href: '', text: 'ERR ' + String(e.message || e).slice(0, 60) }]; }
  finally { try { await p.close(); } catch {} }
}

for (const [oldUrl, q] of ROWS) {
  if (Date.now() - started > 240000) { out.push(`### （時間切れ）${oldUrl}\n\n`); continue; }
  out.push(`### \`${oldUrl}\`\n\n- 検索語 **${q}**\n`);
  const hits = await search(q);
  for (const h of hits) out.push(`  - ${JSON.stringify(h.text)} -> \`${h.href}\`\n`);
  const first = (hits.find((h) => /^https?:/.test(h.href)) || {}).href;
  if (first) {
    let p = null;
    try {
      p = await ctx.newPage();
      const r = await p.goto(first, { waitUntil: 'domcontentloaded', timeout: 18000 });
      await p.waitForTimeout(300);
      const title = (await p.title()).slice(0, 80);
      // **開いた結果も 404 のことが在る。** そう書く
      const dead = /404|not found|見つかりません|存在しません/i.test(title);
      out.push(`- 1 件目を開いた: HTTP ${r ? r.status() : '?'} / title ${JSON.stringify(title)}`
               + `${dead ? ' … **これも 404**' : ''}\n  - 最終 URL \`${p.url()}\`\n`);
    } catch (e) {
      out.push(`- 1 件目を開けない: ${String(e.message || e).slice(0, 70)}\n`);
    } finally { if (p) { try { await p.close(); } catch {} } }
  }
  out.push('\n');
}
// **`browser.close()` は呼ばない。** CDP 越しに呼ぶと利用者の Chrome ごと落ちる
console.log(out.join(''));
process.exit(0);
JS

ROWS='[["https://docomo-cycle.jp/tokyo-bikeshare/", "ドコモ・バイクシェア 東京 公式"], ["https://event.rakuten.co.jp/furusato/guide/simulator/", "楽天ふるさと納税 シミュレーター 詳細版"], ["https://looop.co.jp/denki/", "Looopでんき 公式"], ["https://mst.monex.co.jp/mst/servlet/ITS/fx/", "マネックスFX 公式"], ["https://travel.yahoo.co.jp/dir-00000070/", "横浜ベイホテル東急 Yahoo!トラベル"], ["https://travel.yahoo.co.jp/dir-00000998/", "シギラベイサイドスイート アラマンダ Yahoo!トラベル"], ["https://travel.yahoo.co.jp/dir-00003354/", "ザ ロイヤルパークホテル 舞浜リゾート 東京ベイ Yahoo!トラベル"], ["https://travel.yahoo.co.jp/h/?keyword=%E6%9D%89%E4%B9%83%E4%BA%95", "別府温泉 杉乃井ホテル Yahoo!トラベル"], ["https://www.amazon.co.jp/b?node=5961517051", "Amazon Prime Student 公式"], ["https://www.ana.co.jp/ja/jp/amc/reference/anamile/pocket/", "ANA Pocket 公式"], ["https://www.ana.co.jp/ja/jp/guide/ana-pocket/", "ANA Pocket 公式"], ["https://www.bang.co.jp/auto/", "保険スクエアbang 自動車保険 公式"], ["https://www.bang.co.jp/insurance/", "保険スクエアbang 公式"], ["https://www.click-sec.com/corp/fx/", "GMOクリック証券 公式"], ["https://www.eneos.co.jp/citygas/", "ENEOS都市ガス 公式"], ["https://www.eneos.co.jp/denki/", "ENEOSでんき 公式"], ["https://www.jalan.net/uw/uwp3500/uww3551.do", "じゃらん お得な10日間 セール"], ["https://www.lucidchart.com/pages/ja/education", "Lucidchart 公式"], ["https://www.lucidchart.com/pages/ja/pricing", "Lucidchart Individual 公式"], ["https://www.matsui.co.jp/service/fx/", "松井FX 公式"], ["https://www.parallels.com/jp/products/desktop/education/", "Parallels Desktop 公式"], ["https://www.pointtown.com/ptu/static/companyData", "ポイントタウン 運営会社 GMOメディア"], ["https://www.soumu.go.jp/main_sosiki/jichi_zeisei/czaisei/czaisei_seido/furusato/index.html", "総務省 ふるさと納税ポータルサイト"], ["https://www.spotify.com/jp-ja/student/", "Spotify Premium 公式"], ["https://www.sugi-net.jp/sugisapo/", "スギサポwalk+ 公式"], ["https://www.toys.or.jp/toyshow/", "東京おもちゃショー（一般公開） 公式"]]'

START=$(date +%s)
CDP_PORT="$PORT" PW_DIR="$PWDIR" ROWS="$ROWS" node "$SCRIPT" >> "$OUT" 2>&1 &
PID=$!
while kill -0 "$PID" 2>/dev/null; do
  [ $(( $(date +%s) - START )) -ge 280 ] && { kill "$PID" 2>/dev/null; echo "**280 秒 で打ち切った**" >> "$OUT"; break; }
  sleep 3
done
wait "$PID" 2>/dev/null
rm -f "$SCRIPT"

{
  echo ""
  echo "---"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "**弾くもの**"
  echo ""
  echo "- **まとめサイト・比較サイト**（公式でないもの）"
  echo "- **同名の別ページ**（例: ENEOS の別サービス）"
  echo "- **開いたら 404 だったもの**（上にそう書いてある）"
} >> "$OUT"

cat "$OUT"
