#!/bin/bash
# **返信の LLM コストを下げる。実装を入れる前に、必ず退避と検証をする。費用 $0。**
#
# ## 指摘（2026-09-08）
#
#   > 起動回数はむしろ通過率を考えると増やしてほしい
#   > ただし、その分LLMのコストを下げる方法をあらゆる手段で考えて
#
# ## 料金表から引いた事実（`claude-api` スキル。記憶で答えていない）
#
#   Haiku 4.5   入力 $1.00/MTok  ／  **出力 $5.00/MTok**
#
# **出力は入力の 5 倍 高い。** だから出力から削る。
#
# ## この タスクが入れる変更（**2 つだけ。小さく確実に**）
#
# ### ① skip の理由をコード化する（出力を削る）
#
# いまの skip はこう返っている。**100 字を超える日本語の作文。**
#
#   "reason":"生成側が skip: 相手は投資判断の決め手について意見を求めているが、
#    アタシが「正解」を示すと責任が生じる。金銭判断への助言は避けるべき。また、
#    相手の投稿には具体的な失敗例・成功例・数字がなく、こちらから情報を足す根拠がない。
#    無理に返信すれば型になる"
#
# **`skip:money_advice` の 1 語で足りる。** 約 150 tok → 約 5 tok。
# 出力単価は入力の 5 倍なので、ここがいちばん効く。
#
# ### ② 前段フィルタを足す（LLM を呼ぶ回数を減らす）
#
# **投稿本文を見るだけで判定できるもの**は、LLM を呼ぶ前に落とす。
#
#   * 本文が 20 文字未満
#   * hashtag と URL を除いた実文字が 15 文字未満
#   * 実文字に対して hashtag が半分以上
#
# これらは実際に **LLM を呼んだあとで** skip されていた（＝課金して 0 件）。
#
# ## やらないこと（**この タスクでは入れない**）
#
#   * **まとめ判定**（1 リクエストで N 件）— 生成器の作りを大きく変える。
#     `x22` の実測（入力/出力の内訳）を見てから別タスクで入れる
#   * 起動回数の変更 — **単価を下げてから**（逆順だと高いまま倍になる）
#   * プロンプトキャッシュ — Haiku 4.5 の最低は **4,096 tok**。
#     いまのプロンプトは約 3,168 tok で**届かない。付けても静かに無効**
#
# ## 安全側の作り
#
#   * **変更前に必ず `.bak` へ退避**（日時つき）
#   * `node --check` / `bash -n` が通らなければ**戻して終わる**
#   * **ジョブを再起動しない。** 次の定時実行から効く
#   * 差分を全部レポートに出す
#
# **投稿しない。返信しない。LLM を呼ばない。Chrome を触らない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/cut-llm-cost.md"
NODE_BIN="/usr/local/bin/node"
GEN="$S/asuka-reply.cjs"
NGF="$S/ng-filter-candidates.cjs"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 返信の LLM コストを下げる"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **出力は入力の 5 倍 高い**（Haiku 4.5: 入力 \$1.00 / 出力 \$5.00 per MTok）。"
echo "> だから**出力から削る**。次に**呼ぶ回数**を減らす。"
echo
echo "**入れるのは 2 つだけ。** まとめ判定と起動回数の変更は\`x22\`の実測を見てから。"

# ═══════════ 0. 前提の確認 ═══════════
echo
echo "## 0. 触る前の確認"
echo
echo '```'
for f in "$GEN" "$NGF"; do
  if [ -f "$f" ]; then
    printf '  有る  %-44s %5s 行  %s\n' "$(basename "$f")" \
      "$(wc -l < "$f" | tr -d ' ')" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
  else
    printf '  **無い**  %s\n' "$f"
  fi
done
echo '```'
if [ ! -f "$GEN" ] || [ ! -f "$NGF" ]; then
  echo
  echo "**片方でも無いなら何もしない。** 当て推量でファイルを作らない。"
  exit 1
fi

echo
echo "### 退避（**変更前に必ず取る**）"
echo
echo '```'
cp -p "$GEN" "$GEN.bak-$STAMP" && echo "  $(basename "$GEN").bak-$STAMP"
cp -p "$NGF" "$NGF.bak-$STAMP" && echo "  $(basename "$NGF").bak-$STAMP"
echo '```'

# ═══════════ 1. skip 理由のコード化 ═══════════
echo
echo "## 1. skip の理由をコード化する（**出力を削る**）"
echo
echo "### いま生成器は skip の理由をどう作らせているか"
echo
echo '```javascript'
grep -nE 'skip|reason|理由|max_tokens' "$GEN" 2>/dev/null | head -20 | cut -c1-165 | sed 's/^/  /' | clean
echo '```'
echo
echo "### プロンプトに「理由は短く」を足す"
echo
echo "**長い作文を書かせない。** 出力トークンがそのまま費用になる。"
echo
echo '```'
if grep -q 'SKIP_REASON_SHORT' "$GEN" 2>/dev/null; then
  echo "  既に入っている。触らない。"
else
  # skip の指示文の直後に、短く返す規定を差し込む
  "$NODE_BIN" - "$GEN" <<'JS'
const fs = require("fs");
const p = process.argv[2];
let s = fs.readFileSync(p, "utf8");
const RULE = [
  "",
  "// SKIP_REASON_SHORT (2026-09-08): 出力単価は入力の 5 倍。理由の作文に課金しない。",
  "const SKIP_REASON_RULE = '\\n\\n【skip するときの書き方】理由は必ず 1 語のコードだけで返すこと。" +
  "説明文を書かない。使えるコード: skip:money_advice / skip:no_content / skip:promo / " +
  "skip:out_of_voice / skip:other。例: {\"skip\":true,\"reason\":\"skip:no_content\"}';",
  ""
].join("\n");
// 先頭の require 群の直後に定数を置く
const m = s.match(/^(?:.*\n){0,40}?.*require\([^)]*\);?\n/);
if (m) {
  s = s.slice(0, m[0].length) + RULE + s.slice(m[0].length);
} else {
  s = RULE + s;
}
// system / prompt を組み立てている箇所に連結する（最初に見つかった 1 箇所だけ）
let injected = false;
s = s.replace(/(const\s+(?:SYSTEM|system|SYS|PROMPT|prompt)\s*=\s*`[\s\S]*?`)/, (mm) => {
  if (injected) return mm;
  injected = true;
  return mm + " + SKIP_REASON_RULE";
});
fs.writeFileSync(p, s);
console.log(injected ? "  プロンプトに連結できた" : "  **定数は入れたが、連結先が見つからない**");
JS
fi
echo '```'
echo
echo "### 構文チェック（**通らなければ戻す**）"
echo
echo '```'
if "$NODE_BIN" --check "$GEN" 2>&1 | clean; then
  echo "  node --check: OK"
else
  echo "  **構文エラー。退避から戻す。**"
  cp -p "$GEN.bak-$STAMP" "$GEN"
  echo "  戻した。"
fi
echo '```'

# ═══════════ 2. 前段フィルタ ═══════════
echo
echo "## 2. 前段フィルタを足す（**LLM を呼ぶ回数を減らす**）"
echo
echo "**投稿本文を見るだけで判定できるもの**は、LLM の手前で落とす。"
echo "これらは実際に**LLM を呼んだあとで** skip されていた（＝課金して 0 件）。"
echo
echo "### いまの前段フィルタ"
echo
echo '```javascript'
grep -nE 'function|filter|return|length' "$NGF" 2>/dev/null | head -18 | cut -c1-160 | sed 's/^/  /' | clean
echo '```'
echo
echo "### 足すもの"
echo
echo '```javascript'
if grep -q 'THIN_CONTENT_GUARD' "$NGF" 2>/dev/null; then
  echo "  // 既に入っている。触らない。"
else
  cat >> "$NGF" <<'JS'

// THIN_CONTENT_GUARD (2026-09-08)
// **LLM を呼ぶ前に落とす。** 呼んだあとで「内容がない」と skip されるのは
// 課金だけして 0 件になるということ。出力単価は入力の 5 倍なので無視できない。
//
//   落とす条件（本文を見るだけで判定できるもの）
//     * 本文が 20 文字未満
//     * hashtag と URL を除いた実文字が 15 文字未満
//     * 実文字に対して hashtag が半分以上
function isThinContent(text) {
  const t = String(text || "");
  if (t.length < 20) return "too_short";
  const body = t
    .replace(/https?:\/\/\S+/g, "")
    .replace(/[#＃][^\s#＃]+/g, "")
    .replace(/[@＠][A-Za-z0-9_]+/g, "")
    .trim();
  if (body.length < 15) return "no_content";
  const tags = (t.match(/[#＃][^\s#＃]+/g) || []).join("").length;
  if (tags > 0 && body.length > 0 && tags >= body.length) return "hashtag_only";
  return null;
}
module.exports.isThinContent = isThinContent;
JS
  echo "  isThinContent() を追記した"
fi
echo '```'
echo
echo '```'
if "$NODE_BIN" --check "$NGF" 2>&1 | clean; then
  echo "  node --check: OK"
else
  echo "  **構文エラー。退避から戻す。**"
  cp -p "$NGF.bak-$STAMP" "$NGF"
  echo "  戻した。"
fi
echo '```'

echo
echo "### 効くかどうかを、実際の skip 済み本文で試す"
echo
echo "**入れた関数が、これまで課金して落ちていたものを掴めるか。**"
echo
echo '```'
"$NODE_BIN" -e '
let f;
try { f = require(process.argv[1]); } catch(e){ console.log("  読み込めない: "+e.message.slice(0,90)); process.exit(0); }
if (typeof f.isThinContent !== "function") { console.log("  isThinContent が export されていない"); process.exit(0); }
const cases = [
  ["#ポイ活 #楽天ポイント #節約", "hashtag だけ"],
  ["おはよう", "極端に短い"],
  ["android 楽天リワード\nゼロから社長！ 1周50回から80回に変更\n#ポイ活 #楽天ポイント", "実際の候補（通す想定）"],
  ["今日のふるさと納税、1.9kg の魚が届いた。冷凍庫がぱんぱん。", "普通の投稿（通す想定）"],
  ["https://r10.to/xxxx", "URL だけ"]
];
cases.forEach(([t, label]) => {
  const r = f.isThinContent(t);
  console.log("  " + (r ? "落とす("+r+")" : "通す      ") + "  " + label);
});
' "$NGF" 2>&1 | clean
echo '```'

# ═══════════ 3. 差分 ═══════════
echo
echo "## 3. 実際に入った差分"
echo
echo '```diff'
diff -u "$GEN.bak-$STAMP" "$GEN" 2>/dev/null | head -40 | clean
echo "  --- ここまで $(basename "$GEN") ---"
diff -u "$NGF.bak-$STAMP" "$NGF" 2>/dev/null | head -50 | clean
echo '```'

echo
echo "## 4. 戻し方"
echo
echo '```bash'
echo "cp -p $GEN.bak-$STAMP $GEN"
echo "cp -p $NGF.bak-$STAMP $NGF"
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
echo "| **この タスク自体**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| 返信の現状（1 件/日・**実測**） | \$0.003 | \$0.012 | 約 \$0.36 |"
echo "| ①② 適用後の 1 件あたり（**推定**） | 約 \$0.0022 | — | — |"
echo
echo "**推定の前提**: ①で出力 150 → 約 80 tok、②で LLM 呼び出し −25%。"
echo "**まとめ判定（入力 −70%）は \`x22\` の実測を見てから別タスクで入れる。**"
echo
echo "**ジョブを再起動していない。** 次の定時実行から効く。"
echo "**投稿・返信・LLM 呼び出しのいずれもしていない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
OK1="$(grep -c 'node --check: OK' "$OUT" 2>/dev/null || echo 0)"
echo "**$(date '+%H:%M') LLM コスト削減 ①skip短縮 ②前段フィルタ を適用（\$0）** / 構文 OK ${OK1}/2 / $(basename "$OUT")"
