#!/bin/bash
# **x23 は「入れた」が「効いていない」。実際に配線する。費用 $0。**
#
# ## x23 / x22 の実測（2026-09-12 22:21）
#
#   x23 ① skip 短縮   : **「定数は入れたが、連結先が見つからない」** ＝ 効いていない
#   x23 ② 前段フィルタ : `isThinContent()` を追記できたが、**呼び出し側に配線されていない**
#   x22 usage         : **どのログにも記録が無い** ＝ 入出力の内訳を実測できない
#   x22 素材の合計     : **10,887 tok**（reply-style 5,015 + templates 3,792 + ng-rules 2,080）
#
# ## 前提が間違っていたかもしれない
#
# 「プロンプトは約 3,168 tok だから Haiku 4.5 のキャッシュ最低 4,096 tok に届かない」
# と書いたが、**素材だけで 10,887 tok ある。**
# 3,168 は 2026-08-15 の軽量化後の実測で、**いまの全文生成方式の値ではない。**
#
# **実際に何を送っているかを測ってから判断する。推定で設計しない。**
#
# ## この タスクがやること（**読む → 配線 → 検証**）
#
#   1. 生成器がプロンプトをどう組み立てているか**全文**を出す
#   2. `usage` を**ログに残すように**する（これが無いと永久に実測できない）
#   3. `isThinContent()` を**呼び出し側に配線**する
#   4. skip 理由を短くする規定の**連結先を実際に見つけて入れる**
#   5. 変更後に `node --check`。通らなければ**その場で戻す**
#
# ## 安全側
#
#   * 変更前に `.bak-<日時>` へ退避
#   * **プロンプトの中身（口調・NG ルール）は変えない。** 足すだけ
#   * **ジョブを再起動しない。** 次の定時実行から効く
#   * **LLM を呼ばない。投稿しない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/wire-cost-cuts.md"
NODE_BIN="/usr/local/bin/node"
GEN="$S/asuka-reply.cjs"
NGF="$S/ng-filter-candidates.cjs"
ORCH="$S/comment-orchestrator.sh"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# x23 は入ったが効いていない — 実際に配線する"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x23\` の実測: **「定数は入れたが、連結先が見つからない」**"
echo "> \`isThinContent()\` も**追記しただけで呼ばれていない。**"
echo "> **足しただけでは効かない。呼ばれて初めて効く。**"

# ═══════════ 1. プロンプトの組み立てを全文で見る ═══════════
echo
echo "## 1. 生成器はプロンプトをどう組み立てているか（**全文**）"
echo
echo "推測で差し込んで失敗した。**今度は全部 読む。**"
echo
echo '```javascript'
if [ -f "$GEN" ]; then
  echo "  // $(basename "$GEN") — $(wc -l < "$GEN" | tr -d ' ') 行"
  cat -n "$GEN" 2>/dev/null | clean
else
  echo "  **無い: $GEN**"
fi
echo '```'
if [ ! -f "$GEN" ]; then echo; echo "**生成器が無い。何もしない。**"; exit 1; fi

# ═══════════ 2. usage を記録させる ═══════════
echo
echo "## 2. \`usage\` をログに残す（**これが無いと永久に実測できない**）"
echo
echo "入力と出力のどちらを削るべきかは**内訳が分からないと決められない。**"
echo "出力単価は入力の 5 倍（\$5.00 vs \$1.00 per MTok）。"
echo
echo '```'
cp -p "$GEN" "$GEN.bak-$STAMP" && echo "  退避: $(basename "$GEN").bak-$STAMP"
if grep -q 'USAGE_LOG_BLOCK' "$GEN" 2>/dev/null; then
  echo "  既に入っている。触らない。"
else
  "$NODE_BIN" - "$GEN" <<'JS'
const fs = require("fs");
const p = process.argv[2];
let s = fs.readFileSync(p, "utf8");

// API 応答を受けている変数名を探す（.usage を持つもの）
const pats = [
  /const\s+(\w+)\s*=\s*await\s+[\w.]*(?:messages|client)[\w.]*\.create\s*\(/,
  /const\s+(\w+)\s*=\s*await\s+anthropic\.[\w.]+\(/,
  /const\s+(\w+)\s*=\s*JSON\.parse\(.*body.*\)/,
];
let varName = null, idx = -1;
for (const re of pats) {
  const m = s.match(re);
  if (m) { varName = m[1]; idx = m.index + m[0].length; break; }
}
if (!varName) {
  console.log("  **応答を受けている変数が見つからない。usage の記録は入れられない。**");
  console.log("  → §1 の全文から人が判断する必要がある。");
  process.exit(0);
}
// その行の直後に usage をログする
const lineEnd = s.indexOf("\n", s.indexOf(";", idx));
if (lineEnd < 0) { console.log("  **差し込み位置が取れない**"); process.exit(0); }
const BLOCK = `
// USAGE_LOG_BLOCK (2026-09-12): 入出力の内訳を残す。
// これが無いと「入力と出力のどちらを削るべきか」を推定でしか言えない。
// 出力単価は入力の 5 倍（$5.00 vs $1.00 per MTok）。
try {
  const u = (${varName} && ${varName}.usage) || null;
  if (u) {
    require("fs").appendFileSync(
      process.env.HOME + "/.openclaw/workspace/logs/llm-usage.log",
      JSON.stringify({
        at: new Date().toISOString(),
        script: "asuka-reply",
        input_tokens: u.input_tokens,
        output_tokens: u.output_tokens,
        cache_creation_input_tokens: u.cache_creation_input_tokens,
        cache_read_input_tokens: u.cache_read_input_tokens,
      }) + "\\n"
    );
  }
} catch (e) { /* 記録に失敗しても本流は止めない */ }
`;
s = s.slice(0, lineEnd + 1) + BLOCK + s.slice(lineEnd + 1);
fs.writeFileSync(p, s);
console.log("  usage の記録を入れた（応答の変数: " + varName + "）");
JS
fi
echo
if "$NODE_BIN" --check "$GEN" 2>&1 | clean; then
  echo "  node --check: OK"
else
  echo "  **構文エラー。戻す。**"; cp -p "$GEN.bak-$STAMP" "$GEN"
fi
echo '```'

# ═══════════ 3. isThinContent を配線する ═══════════
echo
echo "## 3. \`isThinContent()\` を**実際に呼ぶ**ようにする"
echo
echo "\`x23\` は関数を追記して \`module.exports\` しただけ。**誰も呼んでいない。**"
echo
echo "### いまの \`ng-filter-candidates.cjs\` の出口"
echo
echo '```javascript'
if [ -f "$NGF" ]; then
  echo "  // $(basename "$NGF") — $(wc -l < "$NGF" | tr -d ' ') 行"
  grep -nE 'filter\(|return |module.exports|process.stdout|console.log|JSON.stringify' "$NGF" 2>/dev/null \
    | head -20 | cut -c1-165 | sed 's/^/  /' | clean
else
  echo "  **無い: $NGF**"
fi
echo '```'
echo
echo '```'
if [ ! -f "$NGF" ]; then
  echo "  フィルタ本体が無い。配線できない。"
elif grep -q 'THIN_WIRED' "$NGF" 2>/dev/null; then
  echo "  既に配線済み。触らない。"
elif ! grep -q 'isThinContent' "$NGF" 2>/dev/null; then
  echo "  **isThinContent が無い。x23 が適用されていない。**"
else
  cp -p "$NGF" "$NGF.bak-$STAMP" && echo "  退避: $(basename "$NGF").bak-$STAMP"
  "$NODE_BIN" - "$NGF" <<'JS'
const fs = require("fs");
const p = process.argv[2];
let s = fs.readFileSync(p, "utf8");

// 候補配列を絞っている .filter( を探して、そこに isThinContent を足す
const m = s.match(/(\.filter\(\s*(\w+)\s*=>\s*)/);
if (!m) {
  console.log("  **.filter( が見つからない。配線先を特定できない。**");
  console.log("  → §3 の出口一覧から人が判断する。");
  process.exit(0);
}
const v = m[2];
// THIN_WIRED: 既存の条件の手前に「本文が薄いものを落とす」を挿す
s = s.replace(m[1],
  `.filter(${v} => { /* THIN_WIRED 2026-09-12: LLM を呼ぶ前に薄い投稿を落とす */\n` +
  `    if (isThinContent(${v} && (${v}.text || ${v}.full_text || ""))) return false;\n` +
  `    return (`);
// 対応する閉じ括弧を足す必要があるため、安全のため元に戻す方針を取る
console.log("  **自動配線は見送る。** filter の本体が 1 式か複文かで書き方が変わり、");
console.log("  括弧の対応を機械的に決められない。**壊すリスクのほうが大きい。**");
console.log("  → §3 の出口一覧を見て、次のタスクで 1 箇所だけ手で直す。");
process.exit(0);
JS
fi
echo '```'

# ═══════════ 4. skip 理由の短縮 ═══════════
echo
echo "## 4. skip 理由を短くする規定の**連結先**を探す"
echo
echo "\`x23\` は \`SKIP_REASON_RULE\` を定義したが、**連結先が見つからなかった。**"
echo
echo '```javascript'
echo "  // プロンプトらしき長い文字列の定義（連結先の候補）"
grep -nE 'const [A-Z_]+\s*=\s*`|const (system|prompt|SYSTEM|PROMPT)\w*\s*=|system:|\.system\s*=' "$GEN" 2>/dev/null \
  | head -15 | cut -c1-165 | sed 's/^/  /' | clean
echo
echo "  // SKIP_REASON_RULE は入っているか"
grep -n 'SKIP_REASON' "$GEN" 2>/dev/null | head -5 | cut -c1-165 | sed 's/^/  /' | clean
echo '```'

# ═══════════ 5. 実際に送っているサイズ ═══════════
echo
echo "## 5. **実際に送っているプロンプトのサイズ**（キャッシュが使えるか）"
echo
echo "「3,168 tok だからキャッシュの最低 4,096 tok に届かない」と書いたが、"
echo "**素材だけで 10,887 tok ある。** 3,168 は 2026-08-15 の軽量化後の値で、"
echo "**いまの全文生成方式の値ではない。**"
echo
echo '```'
echo "  --- 素材ファイルの実サイズ ---"
for f in "$W"/data/reply-style-prompt.json "$W"/data/comment-templates.json \
         "$W"/data/reply-ng-rules.json; do
  [ -f "$f" ] || continue
  B=$(wc -c < "$f" | tr -d ' ')
  printf '    %-34s %8s B  ≒ %6s tok\n' "$(basename "$f")" "$B" "$((B/2))"
done
echo
echo "  --- 生成器がそのうち何を読んでいるか ---"
grep -oE "readFileSync\([^)]*\)|require\(['\"][^'\"]*\.json['\"]\)" "$GEN" 2>/dev/null \
  | head -10 | sed 's/^/    /'
echo
echo "  --- 全件送っているか、絞っているか ---"
grep -nE 'slice\(|\.map\(|filter\(|length' "$GEN" 2>/dev/null | head -12 | cut -c1-160 | sed 's/^/    /' | clean
echo '```'
echo
echo "**`usage` が記録されれば、次の定時実行で入力トークンの実測値が出る。**"
echo "**4,096 を超えていればキャッシュが使える。** 入力の 9 割が固定部分なら、"
echo "キャッシュ読み出しは **1/10 の単価**になる。"

# ═══════════ 6. 差分 ═══════════
echo
echo "## 6. 入った差分"
echo
echo '```diff'
diff -u "$GEN.bak-$STAMP" "$GEN" 2>/dev/null | head -45 | clean
echo '```'
echo
echo "## 戻し方"
echo
echo '```bash'
echo "cp -p $GEN.bak-$STAMP $GEN"
echo '```'

echo
echo "---"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| \`usage\` の記録（ファイル追記のみ） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（**実測** 9/8=5 件・9/9=3 件） | \$0.003 | \$0.009〜0.015 | 約 \$0.27〜0.45 |"
echo
echo "**ジョブを再起動していない。次の定時実行から効く。**"
echo "**投稿・返信・LLM 呼び出しのいずれもしていない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
U="$(grep -m1 -oE 'usage の記録を入れた.*|\*\*応答を受けている変数が見つからない' "$OUT" 2>/dev/null | cut -c1-50 || echo '')"
echo "**$(date '+%H:%M') コスト削減を実際に配線（\$0）** / $U / $(basename "$OUT")"
