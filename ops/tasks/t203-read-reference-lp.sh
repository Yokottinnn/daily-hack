#!/bin/bash
# **参照 LP を Mac で実際に読む（t203）。読むだけ・LLM 不使用・$0。**
#
# ## なぜこれが要るか（2026-10-01 に叱られた・最上位ルール 20）
#
# 利用者から参照 LP の URL をもらったが、**クラウドセッションの egress プロキシが
# ドメイン単位でブロックしていて開けなかった**（`EGRESS_BLOCKED`）。
#
# **そこで自分で考えた意匠を 515 行 書いて PR まで出した。これが間違い。**
#
# > 「〇〇ができなかったから、勝手に自分で考えてこれやりました」とかは2度としないで
# > それならすぐに「それが読めなかったから、何とかして読める方法を探します」に切り替えて
#
# **Mac は塞がれていない。** `ops/tasks` は既にそのための経路で、
# X の実投稿・コモンズの写真・各社のロゴを、ここから取ってきている
# （`docs/article-refresh.md` の「B. 素材の収集」）。**最初からこれを使うべきだった。**
#
# ## 持ち帰るもの（**判断はしない。素材だけ**）
#
#   ① **生の HTML**（`reports/lp-ref/page.html`）
#   ② **CSS**（インラインと外部。外部は実体も取る）
#   ③ **色の一覧**（出現回数つき。**何が主色で何がアクセントか**がこれで分かる）
#   ④ **class 名の一覧**（出現回数つき。ランキング・CTA・バッジの作りが見える）
#   ⑤ **画面の実物**（PC 1200px / スマホ 390px の PNG）
#
# **`reports/` に置いたものは `ops/heartbeat` ブランチへ push される**ので、
# クラウド側から git で読める。これで「見ていないものに寄せる」が無くなる。
#
# 読むだけ。何も直さない。**$0/回・$0/日・$0/月。**

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t203-read-reference-lp.md"
DIR="$RDIR/lp-ref"
PORT="${CDP_PORT:-18810}"
URL='https://app-mania.online/point/rank.php?ID=GSN_AppM_point_main_cpa_001a_res_04_ranking001_A000I'
mkdir -p "$DIR"

{
  echo "# 参照 LP を実際に読む（t203・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "対象: \`app-mania.online/point/rank.php\`（利用者から指定）"
  echo ""
} > "$OUT"

# ── ① HTML を取る ─────────────────────────────────────────
# **User-Agent を付ける。** 素の curl を弾く LP は珍しくない
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36'
HTTP="$(curl -sS -L --max-time 40 -A "$UA" -o "$DIR/page.html" -w '%{http_code}' "$URL" 2>"$DIR/curl.err")"
SZ="$(wc -c < "$DIR/page.html" 2>/dev/null | tr -d ' ')"
case "$SZ" in ''|*[!0-9]*) SZ=0 ;; esac
{
  echo "## ① HTML"
  echo ""
  echo "| | |"
  echo "| --- | --- |"
  echo "| HTTP | **${HTTP}** |"
  echo "| 大きさ | **${SZ} bytes** |"
  echo ""
} >> "$OUT"

if [ "$SZ" -lt 500 ]; then
  {
    echo "⚠️ **取れなかった。** curl のエラー:"
    echo ""
    echo '```text'
    head -c 500 "$DIR/curl.err" 2>/dev/null
    echo '```'
    echo ""
    echo "**ここで止める。** 推測で埋めない（最上位ルール 20）。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi

# ── ② CSS（インライン＋外部の実体） ────────────────────────
# **`sed -i` を使わない**（macOS は `-i ''` が要る・最上位ルール 14）
node -e '
  const fs = require("fs");
  const h = fs.readFileSync(process.argv[1], "utf8");
  const base = new URL(process.argv[2]);
  const inline = [...h.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/gi)].map(m => m[1]).join("\n\n");
  fs.writeFileSync(process.argv[3] + "/inline.css", inline);
  const links = [...h.matchAll(/<link[^>]+rel=["\x27]?stylesheet["\x27]?[^>]*>/gi)]
    .map(m => (m[0].match(/href=["\x27]([^"\x27]+)/) || [])[1])
    .filter(Boolean)
    .map(u => { try { return new URL(u, base).toString(); } catch { return null; } })
    .filter(Boolean);
  fs.writeFileSync(process.argv[3] + "/css-urls.txt", links.join("\n") + (links.length ? "\n" : ""));
  console.log("inline " + inline.length + " bytes / 外部 " + links.length + " 本");
' "$DIR/page.html" "$URL" "$DIR" >> "$DIR/css.log" 2>&1

# **末尾に改行が無い最後の 1 行を落とさない**（最上位ルール 14）
i=0
while IFS= read -r u || [ -n "$u" ]; do
  [ -n "$u" ] || continue
  i=$((i + 1))
  [ "$i" -gt 6 ] && break
  curl -sS -L --max-time 20 -A "$UA" -o "$DIR/ext-$i.css" "$u" 2>/dev/null
done < "$DIR/css-urls.txt"

cat "$DIR/inline.css" "$DIR"/ext-*.css > "$DIR/all.css" 2>/dev/null
ACSS="$(wc -c < "$DIR/all.css" 2>/dev/null | tr -d ' ')"
case "$ACSS" in ''|*[!0-9]*) ACSS=0 ;; esac
{
  echo "## ② CSS"
  echo ""
  echo "- 合計 **${ACSS} bytes**（\`reports/lp-ref/all.css\` に置いた）"
  echo "- 外部 CSS: **$(grep -c . "$DIR/css-urls.txt" 2>/dev/null | head -1) 本**"
  echo ""
} >> "$OUT"

# ── ③ 色（出現回数つき） ───────────────────────────────────
{
  echo "## ③ 色（多い順・上位 30）"
  echo ""
  echo '```text'
  grep -oE '#[0-9A-Fa-f]{6}|#[0-9A-Fa-f]{3}\b|rgba?\([0-9. ,]+\)' "$DIR/all.css" "$DIR/page.html" 2>/dev/null \
    | sed 's/^.*://' | tr 'A-F' 'a-f' | sort | uniq -c | sort -rn | head -30
  echo '```'
  echo ""
  echo "グラデーションの指定:"
  echo ""
  echo '```text'
  grep -oE '(linear|radial)-gradient\([^;]{0,160}' "$DIR/all.css" 2>/dev/null | sort | uniq -c | sort -rn | head -14
  echo '```'
  echo ""
} >> "$OUT"

# ── ④ class 名（出現回数つき） ─────────────────────────────
{
  echo "## ④ class 名（多い順・上位 45）"
  echo ""
  echo '```text'
  grep -oE 'class="[^"]*"' "$DIR/page.html" 2>/dev/null \
    | sed 's/class="//; s/"$//' | tr ' ' '\n' | grep -v '^$' | sort | uniq -c | sort -rn | head -45
  echo '```'
  echo ""
  echo "**順位・CTA・バッジらしきもの**（名前で引いた）:"
  echo ""
  echo '```text'
  grep -oE '\.[a-zA-Z0-9_-]*(rank|rnk|no[0-9]|crown|medal|gold|silver|bronze|cta|btn|badge|ribbon|star|point|osusume|ninki)[a-zA-Z0-9_-]*' "$DIR/all.css" 2>/dev/null \
    | sort -u | head -50
  echo '```'
  echo ""
} >> "$OUT"

# ── ⑤ 画面の実物 ──────────────────────────────────────────
# **`playwright-core`**（`playwright` ではない・最上位ルール 14）。
# **既に動いている Chrome に CDP で繋ぐ。新しく起動しない**（t174 と同じ作り）。
{
  echo "## ⑤ 画面"
  echo ""
} >> "$OUT"

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
cd "$REPO" 2>/dev/null || true
if node -e "require.resolve('playwright-core/package.json')" >/dev/null 2>&1; then
  SCRIPT="$RDIR/.t203-shot.mjs"
  cat > "$SCRIPT" <<'JS'
// **既に動いている Chrome に繋ぐ。新しく起動しない。**
import { chromium } from 'playwright-core';
const PORT = process.env.CDP_PORT || '18810';
const DIR = process.env.SHOT_DIR;
const URL = process.env.SHOT_URL;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
for (const [w, h, name, full] of [[1200, 1000, 'pc', true], [390, 844, 'sp', false]]) {
  const p = await ctx.newPage();
  await p.setViewportSize({ width: w, height: h });
  await p.goto(URL, { waitUntil: 'domcontentloaded', timeout: 30000 }).catch(() => {});
  await p.waitForTimeout(2500);
  // **全画面は重くなりすぎることがある。** PC だけ全体、スマホは 1 画面
  await p.screenshot({ path: `${DIR}/${name}.png`, fullPage: full }).catch(() => {});
  console.log(name, 'ok');
  await p.close();
}
await b.close();
JS
  CDP_PORT="$PORT" SHOT_DIR="$DIR" SHOT_URL="$URL" run_limited 150 node "$SCRIPT" >> "$DIR/shot.log" 2>&1
  SRC=$?
  rm -f "$SCRIPT"
  for f in pc sp; do
    if [ -f "$DIR/$f.png" ]; then
      n="$(wc -c < "$DIR/$f.png" | tr -d ' ')"
      echo "- \`reports/lp-ref/$f.png\` **${n} bytes** ✅" >> "$OUT"
    else
      echo "- \`$f.png\` は**撮れなかった**" >> "$OUT"
    fi
  done
  {
    echo ""
    echo "撮影のログ:"
    echo ""
    echo '```text'
    tail -8 "$DIR/shot.log" 2>/dev/null
    echo '```'
    echo ""
    echo "（rc=${SRC}。**Chrome が CDP で上がっていないと撮れない。** その場合は HTML と CSS だけで読む）"
  } >> "$OUT"
else
  echo "- ⚠️ \`playwright-core\` が無い。**HTML と CSS だけ持ち帰る**" >> "$OUT"
fi

# ── 片付け（**生データは残す。これが目的**） ────────────────
rm -f "$DIR/curl.err" "$DIR/css.log" "$DIR/shot.log" "$DIR"/ext-*.css 2>/dev/null

{
  echo ""
  echo "---"
  echo ""
  echo "> **判断はしていない。素材を持ち帰っただけ**（最上位ルール 20）。"
  echo "> 置き場: \`reports/lp-ref/\`（\`page.html\` / \`all.css\` / \`pc.png\` / \`sp.png\`）"
  echo ""
  echo "LLM 不使用。**\$0/回・\$0/日・\$0/月。**"
} >> "$OUT"

cat "$OUT"
