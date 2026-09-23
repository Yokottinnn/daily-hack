#!/bin/bash
# **reply に画像を付けられるようにする。費用 $0。**
#
# ## 直す理由（`x134` / `x135` で確定済み）
#
#   run-publish.sh:7    # thread_chain[]: [{text, role, image_path?, url?}]  ← スキーマには在る
#   run-publish.sh:122  node scripts/post-comment.js "${textB64}" "${prevUrl}"
#                       ↑ **imagePath を渡していない**
#   post-comment.js:20  const [textArg, targetUrl] = process.argv.slice(2);
#                       ↑ **受け口が 2 つ。setInputFiles も 0 箇所**
#
# **書いてあるとおりに積んでも、エラーは出ず画像だけ黙って消える。**
#
# ## 直し方（`post-via-playwright.js` の実績のある書き方を写す）
#
#   post-via-playwright.js:44-47
#     let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
#     if (!fileInput) fileInput = await page.$('input[type="file"]');
#     await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
#
# **`post-comment.js` は文字を打ってから送信する**（101 行 → 114 行）。添付はその間。
#
# ## **付いたことを確かめてから送信する**
#
# `setInputFiles` は**投げるだけ**で X 側の処理を待たない。
# 確かめずに送ると**画像なしで出る**——今回 防いだのと同じ事故になる。
# **現れなければ `ok:false` で止める。** 出さないほうがよい。
#
# ## 第 3 引数は常に渡す（`"null"` で無効化）
#
# **三項で分岐しない。** `post-via-playwright.js` と同じで、受け取る側が
# `"null"` と空を無視する。分岐を足すほど壊す箇所が増える。
#
# ## パッチ本体はヒアドキュメントで書く
#
# **`node -e '...'` に JS を直書きしない。** JS の中に `'` と `"` が両方 出るため、
# シェルのクォートが壊れる（実際に一度 壊した）。`<<'EOF'` なら展開もエスケープも無い。
# **一時ファイルの拡張子は `.js` を保つ**（`.new` を付けると node が弾く・最上位ルール 14）。
#
# **投稿しない。書き換えるだけ。** 落ちたら自動で元に戻す。
# **LLM を呼ばない（$0）。** 出力は公開リポジトリに載るので秘密は伏せる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/patch-reply-image.md"
CMT="$W/scripts/post-comment.js"
RUN="$W/scripts/run-publish.sh"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
STAMP="$(date +%Y%m%d-%H%M%S)"
TMPDIR_X="${TMPDIR:-/tmp}"
P1="$TMPDIR_X/.x136-patch-comment.js"
P2="$TMPDIR_X/.x136-patch-runpub.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

# ---- パッチ 1: post-comment.js ----------------------------------------------
cat > "$P1" <<'PATCH1'
const fs = require("fs");
const p = process.argv[2];
let s = fs.readFileSync(p, "utf8");

const A = "const [textArg, targetUrl] = process.argv.slice(2);";
if (!s.includes(A)) { console.log("  **(1) 引数の行が見つからない**"); process.exit(3); }
s = s.replace(A, "const [textArg, targetUrl, imageArg] = process.argv.slice(2);");
console.log("  (1) 引数を 3 つにした");

const B = "    await page.keyboard.type(text, { delay: 4 });\n    await page.waitForTimeout(1500);\n";
if (!s.includes(B)) { console.log("  **(2) 打鍵の行が見つからない**"); process.exit(4); }

const ATTACH = [
  "",
  "    // 2026-09-23: **reply にも画像を付けられるようにした。**",
  "    // run-publish.sh が chain[i].image_path を第 3 引数で渡してくる（i>=1 の reply）。",
  "    // これが無かったため、スキーマに image_path? と書いてあっても",
  "    // **エラーも出さずに画像だけ消えていた**（x134 のガードが投稿前に止めた）。",
  "    const imagePaths = (imageArg && imageArg !== \"null\")",
  "      ? imageArg.split(\",\").map((q) => q.trim()).filter(Boolean) : [];",
  "    if (imagePaths.length) {",
  "      step = \"attach-image\";",
  "      console.error(\"[step] \" + step + \" n=\" + imagePaths.length + \" t=\" + ((Date.now()-t0)|0) + \"ms\");",
  "      if (imagePaths.length > 4) { out({ ok: false, step, error: \"X allows max 4 images, got \" + imagePaths.length }); process.exit(1); }",
  "      const missing = imagePaths.filter((q) => !require(\"fs\").existsSync(q));",
  "      if (missing.length) { out({ ok: false, step, error: \"image not found: \" + missing.join(\",\") }); process.exit(1); }",
  "      // post-via-playwright.js:44-47 と同じ取り方",
  "      let fileInput = await page.$('input[type=\"file\"][data-testid=\"fileInput\"]');",
  "      if (!fileInput) fileInput = await page.$('input[type=\"file\"]');",
  "      if (!fileInput) { out({ ok: false, step, error: \"file input not found on reply composer\" }); process.exit(1); }",
  "      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);",
  "      // **付いたことを確かめてから送信する。** setInputFiles は投げるだけで待たない。",
  "      // 確かめずに送ると**画像なしで出る**——防ぎたいのはまさにそれ",
  "      const attached = await page.waitForSelector(",
  "        '[data-testid=\"attachments\"], [data-testid=\"media\"] img, [data-testid=\"removeMedia\"]',",
  "        { timeout: 25000 }",
  "      ).catch(() => null);",
  "      if (!attached) { out({ ok: false, step, error: \"attachment did not appear - 画像なしでは出さない\" }); process.exit(1); }",
  "      await page.waitForTimeout(1500);",
  "    }",
  "",
].join("\n");

s = s.replace(B, B + ATTACH);
console.log("  (2) 添付の処理を打鍵の直後に入れた");

s = s.replace(" * Args: <text-base64> <reply-target-url>",
              " * Args: <text-base64> <reply-target-url> [<image-paths-csv>]");

fs.writeFileSync(p, s);
console.log("  書き込んだ");
PATCH1

# ---- パッチ 2: run-publish.sh ------------------------------------------------
cat > "$P2" <<'PATCH2'
const fs = require("fs");
const p = process.argv[2];
const lines = fs.readFileSync(p, "utf8").split("\n");
const i = lines.findIndex((l) =>
  l.includes("const cmd") && l.includes("post-comment.js") && l.includes("prevUrl"));
if (i < 0) { console.log("  **reply の cmd 行が見つからない**"); process.exit(3); }
const orig = lines[i];
console.log("  " + (i + 1) + ": " + orig.trim());
// **prevUrl の引数の直後に足す。** 行の形（バッククォートのエスケープ）は壊さない
const m = orig.match(/(\\?"\\?\$\{prevUrl\}\\?")/);
if (!m) { console.log("  **prevUrl の引数の形が想定と違う**"); process.exit(4); }
lines[i] = orig.replace(m[1], m[1] + ' \\"\\${imagePath}\\"');
fs.writeFileSync(p, lines.join("\n"));
console.log("  -> " + lines[i].trim());
console.log("  書き込んだ");
PATCH2

{
echo "# reply に画像を付けられるようにする（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。** 2 ファイルを書き換えて、構文を確かめるだけ。"

echo
echo "## 0. 対象が在るか"
echo
echo '```'
for f in "$CMT" "$RUN"; do
  if [ -f "$f" ]; then printf '  %-24s %4s 行\n' "$(basename "$f")" "$(wc -l < "$f" | tr -d ' ')"
  else printf '  **無い** %s\n' "$f"; fi
done
echo '```'
[ -f "$CMT" ] && [ -f "$RUN" ] || { echo; echo "- **ファイルが無い。何もしない。**"; exit 1; }

if grep -q 'imageArg' "$CMT" 2>/dev/null; then
  echo; echo "- **すでにパッチ済み（\`imageArg\` が在る）。何もしない。**"; exit 0
fi

echo
echo "## 1. バックアップ"
echo
BK_CMT="$CMT.bak-$STAMP"; BK_RUN="$RUN.bak-$STAMP"
cp -p "$CMT" "$BK_CMT" && cp -p "$RUN" "$BK_RUN"
echo '```'
echo "  $(basename "$BK_CMT")"
echo "  $(basename "$BK_RUN")"
echo '```'

restore() {
  cp -p "$BK_CMT" "$CMT" 2>/dev/null
  cp -p "$BK_RUN" "$RUN" 2>/dev/null
  echo "- **元に戻した。**"
}

echo
echo "## 2. \`post-comment.js\` を書き換える"
echo
echo "**\`sed -i\` は使わない**（macOS は \`-i ''\` が要る・最上位ルール 14）。node で書く。"
echo
echo '```'
"$NODE_BIN" "$P1" "$CMT" 2>&1 | clean
RC=${PIPESTATUS[0]}
echo '```'
if [ "$RC" != "0" ]; then echo; echo "- **書き換えに失敗（rc=$RC）。**"; restore; exit 1; fi

echo
echo "## 3. \`run-publish.sh\` に第 3 引数を足す"
echo
echo "**常に渡す。** 受け取る側が \`\"null\"\` と空を無視するので、分岐は要らない。"
echo
echo '```'
"$NODE_BIN" "$P2" "$RUN" 2>&1 | clean
RC=${PIPESTATUS[0]}
echo '```'
if [ "$RC" != "0" ]; then echo; echo "- **書き換えに失敗（rc=$RC）。**"; restore; exit 1; fi

echo
echo "## 4. 構文を確かめる（**落ちたら元に戻す**）"
echo
echo '```'
OK=1
if "$NODE_BIN" --check "$CMT" 2>&1 | clean; then echo "  post-comment.js  node --check OK"; else echo "  **post-comment.js が通らない**"; OK=0; fi
if bash -n "$RUN" 2>&1 | clean; then echo "  run-publish.sh   bash -n OK"; else echo "  **run-publish.sh が通らない**"; OK=0; fi
echo '```'
if [ "$OK" != "1" ]; then echo; echo "- **構文が通らない。**"; restore; exit 1; fi

echo
echo "## 5. 入ったか（**当てた証拠を出す**）"
echo
echo '```'
echo "  --- post-comment.js ---"
grep -n 'imageArg\|setInputFiles\|attach-image\|attachment did not appear' "$CMT" | head -12 | clean
echo "  --- run-publish.sh ---"
grep -n 'post-comment.js' "$RUN" | head -6 | clean
echo '```'

echo
echo "---"
echo
echo "## これで何が変わるか"
echo
echo "- \`thread_chain[i].image_path\`（i>=1）が**実際に効くようになる**"
echo "- **画像が付かなかったら \`ok:false\` で止まる。** 黙って画像なしで出ることはもう無い"
echo "- **今後のスレッド全部に効く。** この記事だけの話ではない"
echo
echo "**まだ投稿していない。** 出すのは次のタスク。"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

rm -f "$P1" "$P2"
[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'run-publish.sh   bash -n OK' "$OUT" 2>/dev/null; then
  echo "**reply に画像を付けられるようにした。構文も通った** / $(basename "$OUT")"
elif grep -q 'すでにパッチ済み' "$OUT" 2>/dev/null; then
  echo "すでに当たっていた / $(basename "$OUT")"
else
  echo "**当てられなかった。元に戻してある。レポートを読むこと** / $(basename "$OUT")"
fi
