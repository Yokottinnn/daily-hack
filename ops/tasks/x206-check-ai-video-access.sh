#!/bin/bash
# **動画生成 AI を使えるかを Mac で調べる。読むだけ。費用 $0。値は出さない。**
#
# ## 指示（2026-10-03）
#
#   > ちゃんとAiを使って動画を生成してくれない？
#   > この環境には動画生成APIキーがないって誰が決めつけたの？ちゃんと調べた？
#
# クラウドの環境変数だけを見て「キーが無い」と言った。**Mac を見ていなかった。** ここで全部 見る。
#
#   ① 設定ファイル・シェルの初期化ファイル・launchctl の環境に、どの **キーの名前** があるか（値は長さだけ）
#   ② 既存のジョブが Grok をどの経路で呼んでいるか（api.x.ai か、ブラウザの Grok か）
#   ③ ブラウザで grok.com/imagine と x.com/i/grok が**ログイン済みで開けるか**（画面を撮るだけ。生成はしない）
#
# **生成しない。投稿しない。LLM も動画 API も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x206-read-$STAMP.js"
RAW="$W/.x206-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/ai-video-access.md"

# **値は絶対に出さない。** 鍵らしき長いトークンは全部伏せる
mask() { sed -E -e 's#(sk-[A-Za-z0-9_-]{2})[A-Za-z0-9_-]{8,}#\1<MASKED>#g' \
                -e 's#(xai-)[A-Za-z0-9_-]{6,}#\1<MASKED>#g' \
                -e 's#(AIza)[A-Za-z0-9_-]{10,}#\1<MASKED>#g' \
                -e 's#([=:] *["'"'"']?)[A-Za-z0-9_./+-]{24,}#\1<MASKED>#g' \
                -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }

descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    local victims p
    victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

cat > "$RUNNER" <<'JSEOF'
// x206: Grok Imagine の画面がログイン済みで開けるかを見るだけ。生成しない。$0。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const OUTDIR = process.argv[2];
(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log(JSON.stringify({ fatal: "context が無い" })); process.exit(0); }
  const p = await ctx.newPage();
  await p.setViewportSize({ width: 1200, height: 1000 });
  const out = [];
  for (const [tag, url] of [["grok-imagine", "https://grok.com/imagine"], ["x-grok", "https://x.com/i/grok"]]) {
    const r = { tag, url };
    try {
      await p.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(7000);
      r.finalUrl = p.url();
      r.title = await p.title();
      r.text = (await p.evaluate(() => document.body ? document.body.innerText : "")).slice(0, 700);
      r.hasLogin = /log ?in|sign ?in|ログイン|サインイン/i.test(r.text);
      r.hasImagine = /imagine|video|動画|画像を生成|generate/i.test(r.text);
      await p.screenshot({ path: OUTDIR + "/x206-" + tag + ".png" }); r.shot = "x206-" + tag + ".png";
    } catch (e) { r.error = String(e && e.message).slice(0, 160); }
    out.push(r);
  }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify({ rows: out }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

# 探すキーの名前（部分一致）。値ではなく名前だけを見る
NAMES='XAI|GROK|OPENAI|GEMINI|GOOGLE|VERTEX|FAL|REPLICATE|RUNWAY|KLING|LUMA|PIKA|MINIMAX|HAILUO|STABILITY|BFL|IDEOGRAM|ANTHROPIC'
names_in() {
  awk -v pat="$NAMES" '{ line=$0; sub(/^export +/, "", line);
    if (match(line, /^[A-Za-z_][A-Za-z0-9_]*=/)) { name=substr(line, 1, RLENGTH-1); val=substr(line, RLENGTH+1);
      gsub(/^["'"'"']|["'"'"']$/, "", val);
      if (toupper(name) ~ pat) printf "        %s  （値の長さ %d）\n", name, length(val) } }' "$1"
}

{
echo "# 動画生成 AI を使えるか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **値は出さない（名前と長さだけ）。生成しない。LLM も動画 API も呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo "## ① キーの名前（設定ファイル・シェル・launchctl）"
echo
echo '```'
for f in "$HOME/openclaw/config/.env" "$HOME/.openclaw/.env" "$W/.env" "$W/config/.env" "$HOME/.env" \
         "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zshenv" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile" \
         "$HOME/projects/anta-baka-x/blog/.env" "$HOME/projects/anta-baka-x/.env"; do
  [ -f "$f" ] || { printf '  無い  %s\n' "${f#$HOME/}"; continue; }
  printf '  在る  %s\n' "${f#$HOME/}"
  names_in "$f"
done
echo
echo "  --- 他の .env（ホーム配下 深さ 4 まで・名前が一致するものだけ）"
find "$HOME" -maxdepth 4 -name '.env*' -type f 2>/dev/null | grep -v node_modules | head -40 | while IFS= read -r f || [ -n "$f" ]; do
  hits="$(names_in "$f" | awk '{print $1}' | tr '\n' ' ')"
  [ -n "$hits" ] && printf '  %s → %s\n' "${f#$HOME/}" "$hits"
done
echo
echo "  --- openclaw.json の中のキー名（値は長さだけ）"
for j in "$HOME/.openclaw/openclaw.json" "$W/openclaw.json"; do
  [ -f "$j" ] || continue
  node -e '
    const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const pat = new RegExp(process.argv[2], "i"); const hits = [];
    (function walk(o, path) { if (o && typeof o === "object") for (const k of Object.keys(o)) { const p = path ? path + "." + k : k;
      if (pat.test(k) || (/key|token|secret/i.test(k) && pat.test(p))) hits.push(p + (typeof o[k] === "string" ? "（値の長さ " + o[k].length + "）" : ""));
      walk(o[k], p); } })(j, "");
    console.log("  " + process.argv[1].replace(process.env.HOME + "/", "") + ": " + (hits.length ? hits.slice(0, 20).join(" / ") : "該当なし"));
  ' "$j" "$NAMES" 2>&1 | head -5
done
echo
echo "  --- launchctl の環境（名前に一致するもの）"
launchctl print "gui/$(id -u)" 2>/dev/null | awk '/environment = \{/{f=1;next} f&&/\}/{f=0} f' | awk -v pat="$NAMES" '{ n=$1; if (toupper(n) ~ pat) print "  " n "  （値は出さない）" }'
echo "  （ここに何も出なければ launchctl には無い）"
echo '```'
echo
echo "## ② 既存のジョブが Grok をどう呼んでいるか"
echo
echo '```'
grep -rl -E 'api\.x\.ai|XAI|GROK_|grok\.com|x\.com/i/grok|imagine' "$S" 2>/dev/null | grep -v '/\.' | head -15 | while IFS= read -r f || [ -n "$f" ]; do
  echo "  == ${f#$HOME/}"
  grep -n -E 'api\.x\.ai|XAI|GROK_|grok\.com|x\.com/i/grok|imagine|model' "$f" | head -8 | cut -c1-200 | mask | sed 's/^/     /'
done
echo '```'
echo
echo "## ③ ブラウザで Grok Imagine が開けるか（撮るだけ・生成しない）"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
if [ "$CRC" -eq 0 ]; then
  rm -f "$OUTDIR"/x206-*.png
  run_limited 120 "$RAW" node "$RUNNER" "$OUTDIR"; printf '  rc=%s\n' "$?"
  for f in "$OUTDIR"/x206-*.png; do [ -s "$f" ] && printf '  %s（%s bytes）\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"; done
fi
echo '```'
rm -f "$RUNNER"
if [ -s "$RAW" ]; then
  node -e '
    let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); } catch (e) { console.log("**JSON として読めない**"); process.exit(0); }
    if (j.fatal) { console.log("\n**止まった: " + j.fatal + "**"); process.exit(0); }
    for (const r of j.rows || []) {
      console.log("\n### " + r.tag + "  →  " + (r.finalUrl || "?") + (r.error ? "  **エラー: " + r.error + "**" : ""));
      console.log("\nタイトル: " + (r.title || "?") + " ／ ログインを求める文言: " + (r.hasLogin ? "あり" : "なし") + " ／ 生成の文言: " + (r.hasImagine ? "あり" : "なし") + " ／ 画面: " + (r.shot || "なし") + "\n");
      console.log("```text\n" + String(r.text || "").slice(0, 600) + "\n```");
    }
  ' "$RAW" 2>&1 | mask
fi
rm -f "$RAW"
echo
echo "**生成していない。LLM も動画 API も呼んでいない（\$0／回・\$0／日・\$0／月）。値は出していない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$RUNNER" "$RAW"
if grep -aq '## ③' "$OUT" 2>/dev/null; then echo "動画生成 AI の使える経路を調べた / $(basename "$OUT")"; else echo "**読めていない** / $(basename "$OUT")"; fi
