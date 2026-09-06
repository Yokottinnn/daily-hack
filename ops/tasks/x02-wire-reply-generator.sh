#!/bin/bash
# **返信の生成器を全文生成に配線する ＋ 私が壊した NG ルールを戻す。費用 $0。**
#
# ## 分かったこと（x01 / t057 の実測）
#
# **`asuka-reply.cjs` と `reply-relevance-check.cjs` は Mac に一度も入っていなかった。**
# 全文生成の経路は未完成のままで、**あのまま `comment-warmup` を起動していたら、
# 確実に古いテンプレ経路で返信が出ていた。**（9/2 に『トンチンカン』と言われた経路）
#
# 配線はこうなっている（`comment-orchestrator.sh`）。
#
#    46行  ng-filter-candidates.cjs   入口フィルタ（既にある）
#   111行  asuka-fill.js              ← **ここだけを差し替える**
#   113行  tone-gate.cjs              出口ゲート（既にある）
#   115行  GEN_OK != "true" → 次の候補へ
#
# 入力は `{trend: $PICK, kind: 'comment'}`（110行）。**`asuka-reply.cjs` の契約と一致している。**
# `template_id` は 120 行で `||'unknown'` のフォールバックつきなので、返さなくても落ちない。
#
# ## 私が 1 つ壊したので、先に戻す
#
# `x01` で `reply-ng-rules.json` を **4160 → 3246 B に置換**した。
# だがリポジトリ側は **PR #229（8/22 以前）の古い版**で、Mac 側は **8/28 更新**だった。
# **新しいものを古いもので上書きしている。** 退避が残っているので戻す。
#
# **直す前に、自分が壊したものを戻す。**
#
# ## やらないこと
#
# **返信を生成しない。投稿しない。`comment-warmup` を load しない。LLM を呼ばない。**
# 起動は次のタスクで、**試験生成の文面を利用者が見てから**行う。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/wire-reply-generator.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
ORCH="$S/comment-orchestrator.sh"
STAMP="$(date +%Y%m%d-%H%M%S)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# 返信の生成器を全文生成に配線する（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **\`asuka-reply.cjs\` は Mac に一度も入っていなかった**（x01 で判明）。"
echo "> あのまま起動していたら、**確実に古いテンプレ経路で返信が出ていた。**"
echo "> **起動しない。** 試験生成の文面を利用者が見てから。"

echo
echo "## 0. 私が壊した NG ルールを戻す"
echo
echo "\`x01\` で \`reply-ng-rules.json\` を 4160 → 3246 B に置換した。"
echo "**リポジトリ側が古く（PR #229）、Mac 側が新しかった（8/28 更新）。**"
echo "**直す前に、自分が壊したものを戻す。**"
echo
echo '```'
BAK="$(ls -t "$D"/reply-ng-rules.json.bak.* 2>/dev/null | head -1)"
if [ -z "$BAK" ]; then
  echo "  **退避が見つからない。** data/ の .bak を確認すること:"
  ls -la "$D"/reply-ng-rules.json* 2>/dev/null | sed 's/^/    /'
elif [ ! -s "$BAK" ]; then
  echo "  **退避が空。戻さない。** $BAK"
else
  cur="$( [ -f "$D/reply-ng-rules.json" ] && wc -c < "$D/reply-ng-rules.json" | tr -d ' ' || echo 0 )"
  if "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$BAK" 2>/dev/null; then
    cp -p "$BAK" "$D/reply-ng-rules.json"
    echo "  戻した: $cur → $(wc -c < "$D/reply-ng-rules.json" | tr -d ' ') B"
    echo "  出どころ: $(basename "$BAK")"
  else
    echo "  **退避が JSON として壊れている。戻さない。** $(basename "$BAK")"
  fi
fi
echo '```'
echo
echo "**リポジトリ側の \`ops/data/reply-ng-rules.json\` も、Mac の版に合わせて更新すること。**"
echo "（このタスクはリポジトリを書き換えない。次に人がやる）"
echo
echo "### 戻したあとの中身の頭"
echo
echo '```json'
head -c 700 "$D/reply-ng-rules.json" 2>/dev/null | clean
echo ""
echo '```'

echo
echo "## 1. 配線の前の状態"
echo
if [ ! -f "$ORCH" ]; then
  echo "- **\`comment-orchestrator.sh\` が無い。何もしない。**"
  exit 1
fi
echo '```bash'
grep -nE 'asuka-fill|asuka-reply|asuka-gen' "$ORCH" 2>/dev/null | clean
echo '```'
echo
echo "- 生成器の呼び出し: **$(grep -c 'asuka-fill.js' "$ORCH" 2>/dev/null) 箇所**（\`asuka-fill.js\`）"

echo
echo "## 2. 差し替えに必要なものが揃っているか"
echo
echo "**揃っていなければ差し替えない。** 呼んだ瞬間に落ちる状態にしない。"
echo
READY=1
echo '```'
for f in asuka-reply.cjs reply-relevance-check.cjs tone-gate.cjs ng-filter-candidates.cjs; do
  if [ -f "$S/$f" ] && "$NODE_BIN" --check "$S/$f" 2>/dev/null; then
    printf '  OK    scripts/%s\n' "$f"
  else
    printf '  **NG** scripts/%s\n' "$f"; READY=0
  fi
done
for f in reply-style-prompt.json reply-relevance-rules.json reply-ng-rules.json reply-tone-rules.json; do
  if [ -f "$D/$f" ] && "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$D/$f" 2>/dev/null; then
    printf '  OK    data/%s\n' "$f"
  else
    printf '  **NG** data/%s\n' "$f"; READY=0
  fi
done
if [ -f "$S/anthropic-client.js" ]; then printf '  OK    scripts/anthropic-client.js\n'; else printf '  **NG** scripts/anthropic-client.js（生成器が API を呼べない）\n'; READY=0; fi
echo '```'
if [ "$READY" != "1" ]; then
  echo
  echo "- **揃っていない。配線しない。**"
  exit 1
fi

echo
echo "## 3. 配線する（**1 行だけ**）"
echo
echo "\`asuka-fill.js\` → \`asuka-reply.cjs\`。"
echo "**\`RECENT_TEMPLATE_IDS\` は落とす**（テンプレ方式の変数で、全文生成では使わない）。"
echo "**\`2>&1\` を \`2>>\$LOG\` に変える**——標準エラーが JSON に混ざると、"
echo "\`GEN_OK\` の判定が必ず false になる（\`tone-gate.cjs\` は既にそうしている）。"
echo
cp -p "$ORCH" "$ORCH.bak.$STAMP"
echo "- 退避: \`$(basename "$ORCH").bak.$STAMP\`"
echo
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
let s=fs.readFileSync(p,"utf8");
const before=s;
s=s.replace(
  /RECENT_TEMPLATE_IDS="\$RECENT_IDS" \/usr\/local\/bin\/node scripts\/asuka-fill\.js 2>&1/g,
  "/usr/local/bin/node scripts/asuka-reply.cjs 2>>\"$LOG\""
);
if(s===before){
  // 念のため、環境変数が無い形にも当てる
  s=s.replace(/\/usr\/local\/bin\/node scripts\/asuka-fill\.js 2>&1/g,
              "/usr/local/bin/node scripts/asuka-reply.cjs 2>>\"$LOG\"");
}
if(s===before){ console.log("  **置換できなかった。行の形が想定と違う。**"); process.exit(2); }
fs.writeFileSync(p+".tmp", s); fs.renameSync(p+".tmp", p);
console.log("  置換した");
' "$ORCH" 2>&1 | clean
RC=$?
if [ "$RC" != "0" ]; then
  echo
  echo "- **置換に失敗した（rc=$RC）。退避から戻す。**"
  cp -p "$ORCH.bak.$STAMP" "$ORCH"
  exit 1
fi
chmod +x "$ORCH" 2>/dev/null || true

echo
echo "## 4. 配線したあとの確認"
echo
echo '```bash'
grep -nE 'asuka-fill|asuka-reply|tone-gate|ng-filter' "$ORCH" 2>/dev/null | clean
echo '```'
echo
echo "- \`asuka-fill.js\` の残り: **$(grep -c 'asuka-fill.js' "$ORCH" 2>/dev/null) 箇所**（0 なら完全に外れた）"
echo "- \`asuka-reply.cjs\` の呼び出し: **$(grep -c 'asuka-reply.cjs' "$ORCH" 2>/dev/null) 箇所**"
echo
echo "### シェルの構文が通るか"
echo
echo '```'
if bash -n "$ORCH" 2>&1; then echo "  構文OK"; else echo "  **構文NG。退避から戻す。**"; cp -p "$ORCH.bak.$STAMP" "$ORCH"; fi
echo '```'

echo
echo "## 5. ジョブは触っていない"
echo
echo '```'
echo "  comment-warmup: $(launchctl list 2>/dev/null | grep -F 'comment-warmup' || echo '**未ロード（触っていない）**')"
echo '```'
echo
echo "**次は試験生成。** 少数だけ生成して文面をチャットに出し、"
echo "**利用者が読んでから**起動する。ここまでは 1 度も LLM を呼んでいない。"

echo
echo "---"
echo
echo "**返信を生成していない。投稿していない。ジョブも起動していない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '構文OK' "$OUT" 2>/dev/null && grep -q '置換した' "$OUT" 2>/dev/null; then
  echo "**全文生成に配線した（起動はしていない・\$0）** / $(basename "$OUT")"
else
  echo "**配線できていない。レポートを読むこと** / $(basename "$OUT")"
fi
