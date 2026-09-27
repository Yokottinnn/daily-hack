#!/bin/bash
# **差し替え候補を開いて確かめる（t194）。LLM 不使用・$0。**
#
# ## t193 で 10 件 だけ決めきれなかった
#
# | 決めきれなかった理由 | 件数 |
# | --- | --- |
# | 検索の 1 件目が**広告のリダイレクタ**で開けなかった | 8 |
# | 開いたが**中身が違った**（Wikipedia / 別のヘルプ記事） | 2 |
#
# **候補は在る。** ただし**開いて確かめるまで記事に入れない**（最上位ルール 11）。
#
# ## 見るのは title だけ
#
# HTTP の番号より、**ページが何と名乗っているか**のほうが確か。
# 期待する名前を一緒に出すので、**違っていればクラウド側で弾ける。**
#
# **X 運用の Chrome を借りるだけ。** 新しいタブを開いて必ず閉じる。
# **`browser.close()` を呼ばない**（利用者の Chrome ごと落ちる）。
#
# **120 秒 で打ち切る**（最上位ルール 15）。10 件。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t194-verify-candidates.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PORT="${CDP_PORT:-18810}"

{
  echo "# 差し替え候補を開いて確かめる（t194・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**開いて確かめるまで記事に入れない**（最上位ルール 11）。"
  echo "**期待する名前と違えば、クラウド側で弾く。**"
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

SCRIPT="$RDIR/.t194.mjs"
cat > "$SCRIPT" <<'JS'
import { createRequire } from 'node:module';
// **ESM の import は `NODE_PATH` を見ない。** CommonJS の require で場所を指定して解決する
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const ROWS = JSON.parse(process.env.ROWS);
const browser = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
const ctx = browser.contexts()[0];
const out = [];
const started = Date.now();
for (const [url, want] of ROWS) {
  if (Date.now() - started > 100000) { out.push(`- ⏱️ 時間切れ: \`${url}\`\n`); continue; }
  let p = null;
  try {
    p = await ctx.newPage();
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 18000 });
    await p.waitForTimeout(300);
    const title = (await p.title()).slice(0, 90);
    const dead = /404|not found|見つかりません|存在しません/i.test(title);
    out.push(`- ${dead ? '**DEAD**' : 'OK  '} \`${url}\`\n`
           + `    期待 **${want}** / HTTP ${r ? r.status() : '?'} / title ${JSON.stringify(title)}\n`
           + `    最終 URL \`${p.url()}\`\n`);
  } catch (e) {
    out.push(`- **開けない** \`${url}\`\n    ${String(e.message || e).slice(0, 80)}\n`);
  } finally { if (p) { try { await p.close(); } catch {} } }
}
// **`browser.close()` は呼ばない。** CDP 越しに呼ぶと利用者の Chrome ごと落ちる
console.log(out.join(''));
process.exit(0);
JS

ROWS='[["https://travel.yahoo.co.jp/00000070/", "横浜ベイホテル東急"], ["https://travel.yahoo.co.jp/00000998/", "シギラベイサイドスイート アラマンダ"], ["https://travel.yahoo.co.jp/00003354/", "ザ ロイヤルパークホテル 舞浜リゾート 東京ベイ"], ["https://travel.yahoo.co.jp/00001104/", "別府温泉 杉乃井ホテル"], ["https://www.jalan.net/theme/otoku_10days/", "じゃらん お得な10日間"], ["https://www.matsui.co.jp/fx/", "松井FX"], ["https://www.parallels.com/jp/products/desktop/", "Parallels Desktop"], ["https://www.soumu.go.jp/main_sosiki/jichi_zeisei/czaisei/czaisei_seido/080430_2_kojin.html", "総務省 ふるさと納税"], ["https://www.gmo-media.jp/", "GMOメディア（ポイントタウン運営会社）"], ["https://lucid.co/ja/pricing/lucidchart", "Lucidchart 料金"]]'
START=$(date +%s)
CDP_PORT="$PORT" PW_DIR="$PWDIR" ROWS="$ROWS" node "$SCRIPT" >> "$OUT" 2>&1 &
PID=$!
while kill -0 "$PID" 2>/dev/null; do
  [ $(( $(date +%s) - START )) -ge 120 ] && { kill "$PID" 2>/dev/null; echo "**120 秒 で打ち切った**" >> "$OUT"; break; }
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
  echo "**title が期待する名前と噛み合っているものだけ記事に入れる。**"
} >> "$OUT"

cat "$OUT"
