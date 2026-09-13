#!/bin/bash
# **広告投稿を「選ぶ前」に弾く。実装は $0。定常費用は月 $0.81 → $1.44（承認済み）。**
#
# ## なぜ（x62 / x65 の実測）
#
#   2026-09-13: picked 16 件 → 広告 4 件・話題外 3 件 が **生成の直前に落ちた**
#
# 落ちること自体は正しい（LLM を呼ぶ前なので $0）。だが **picked の枠を 7 つ 空振り
# させている。** 枠は 1 回 4 件 × 4 発火 = 16 件 しかない。
#
# 弾いている実体は `asuka-reply.cjs:108-114`。`reply-relevance-rules.json` の
# `target_skip`（hashtags / domains / campaign_words）を本文に当てているだけ。
# **同じ判定を、選ぶループに置く。**
#
# ## 費用（**増える。承認済み**）
#
# | | 1 回あたり | 1 日あたり | 1 か月あたり |
# | --- | --- | --- | --- |
# | いま（生成 9 件/日） | $0.003 | $0.027 | 約 $0.81 |
# | この変更の後（生成 最大 16 件/日） | $0.003 | $0.048 | **$1.44** |
#
# **増加は月 +$0.63。** 単価は実測（2026-09-06・全文生成・Haiku 4.5）。
# 件数は 2026-09-13 のログ実測。**16 件 は上限であり、候補が足りなければ下回る。**
#
# ## 当て方（**2 箇所だけ**）
#
#   1. 選ぶループの前に、target_skip を読む関数を置く
#   2. `seen.has(item.author)` の直後に、広告なら飛ばす 1 行 を足す
#
# **挿入する式に `$` とバッククォートと二重引用符を入れない。**
# この inline node は**二重引用符の中に在る**ため、入れるとシェルが展開して壊れる。
#
# ## やらないこと
#
# **上限（MAX_PICKS / cap）を変えない。判定の中身を足さない**（既存の JSON をそのまま使う）。
# **投稿しない。フォローしない。LLM を呼ばない（このタスク自体は $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/skip-ads-before-picking.md"
NODE_BIN="/usr/local/bin/node"
ORCH="$S/comment-orchestrator.sh"
RULES="$W/data/reply-relevance-rules.json"
PATCH="$S/.x68-patch.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
trap 'rm -f "$PATCH" "$ORCH.x68-new.sh"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[a-z]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

cat > "$PATCH" <<'JSEOF'
const fs = require("fs");
const p = process.argv[2];
const src = fs.readFileSync(p, "utf8");

if (src.includes("isAdPost")) {
  console.log("  **既に入っている。当てない。**");
  process.exit(3);
}

// ① 判定を置く（**seen の宣言の直後**）
const A_OLD = "  const picked = [];\n  const seen = new Set();";
const A_NEW = [
  "  const picked = [];",
  "  const seen = new Set();",
  "  // 2026-09-13 x68: 広告投稿を選ぶ前に弾く（asuka-reply.cjs と同じ target_skip を使う）",
  "  var TS = {};",
  "  try { TS = (JSON.parse(fs.readFileSync('/Users/ny/.openclaw/workspace/data/reply-relevance-rules.json', 'utf8')).target_skip) || {}; } catch (e) { TS = {}; }",
  "  var adSkipped = 0;",
  "  var isAdPost = function (it) {",
  "    var t = [it.text, it.tweet_url, it.title, it.bio].filter(Boolean).join(' ');",
  "    var lists = [TS.hashtags || [], TS.domains || [], TS.campaign_words || []];",
  "    for (var li = 0; li < lists.length; li++) {",
  "      for (var i = 0; i < lists[li].length; i++) { if (t.indexOf(lists[li][i]) >= 0) return true; }",
  "    }",
  "    return false;",
  "  };",
].join("\n");

// ② 飛ばす 1 行（**seen の判定の直後**）
const B_OLD = "    if (seen.has(item.author)) continue;";
const B_NEW = [
  "    if (seen.has(item.author)) continue;",
  "    if (isAdPost(item)) { adSkipped++; continue; }",
].join("\n");

// ③ 何件 飛ばしたかを残す（**シェルを触らずに済むよう、脇のファイルへ**）
const C_OLD = "  fs.writeFileSync('$PICKS_FILE', JSON.stringify(picked));";
const C_NEW = [
  "  try { fs.writeFileSync('/tmp/orch-adskip.json', JSON.stringify({ at: new Date().toISOString(), ad_skipped: adSkipped, considered: items.length, picked: picked.length })); } catch (e) {}",
  "  fs.writeFileSync('$PICKS_FILE', JSON.stringify(picked));",
].join("\n");

const count = (s, sub) => s.split(sub).length - 1;
const nA = count(src, A_OLD), nB = count(src, B_OLD), nC = count(src, C_OLD);
console.log("  目印 ①（判定を置く場所）: " + nA + " 箇所");
console.log("  目印 ②（飛ばす場所）    : " + nB + " 箇所");
console.log("  目印 ③（件数を残す場所）: " + nC + " 箇所");

if (nA !== 1 || nB !== 1 || nC !== 1) {
  console.log("  **1 箇所 でないので当てない。** ファイルが変わっている");
  process.exit(4);
}

// **挿入する式に $ / バッククォート / 二重引用符 が無いことを確かめる**
const inserted = [A_NEW, B_NEW, C_NEW].join("\n").split("\n")
  .filter((l) => !src.includes(l));
const bad = inserted.filter((l) => /[$`"]/.test(l.replace("'$PICKS_FILE'", "")));
if (bad.length) {
  console.log("  **挿入する式に $ か ` か \" が混ざっている。当てない。**");
  for (const b of bad.slice(0, 3)) console.log("    " + b.slice(0, 120));
  process.exit(5);
}
console.log("  挿入する式の検査: OK（$ / バッククォート / 二重引用符 を含まない）");

const patched = src.replace(A_OLD, A_NEW).replace(B_OLD, B_NEW).replace(C_OLD, C_NEW);
fs.writeFileSync(p + ".x68-new.sh", patched);
console.log("  当てた（検査待ち）");
JSEOF

{
echo "# 広告投稿を「選ぶ前」に弾く"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 2026-09-13: picked 16 件 → **広告 4 件・話題外 3 件 が生成の直前に落ちた。**"
echo "> 落ちること自体は正しい（\$0）が、**picked の枠を 7 つ 空振りさせている。**"
echo
echo "**費用が増える変更（月 +\$0.63）。承認を得てから実施している。**"

# ═══════════ 0. 当てる前 ═══════════
echo
echo "## 0. 当てる前"
echo
echo '```'
if [ ! -f "$ORCH" ]; then
  echo "  **$ORCH が無い。**"
else
  printf '  %s 行 / 最終更新 %s\n' "$(wc -l < "$ORCH" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$ORCH" 2>/dev/null)"
  echo "  isAdPost を含む箇所: $(grep -c 'isAdPost' "$ORCH" 2>/dev/null || echo 0)"
fi
echo
echo "  --- 使う判定（既存の JSON。**中身は足さない**） ---"
if [ -f "$RULES" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const ts=(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).target_skip)||{};
console.log("    hashtags      : "+(ts.hashtags||[]).length+" 件");
console.log("    domains       : "+(ts.domains||[]).length+" 件");
console.log("    campaign_words: "+(ts.campaign_words||[]).length+" 件");
' "$RULES" 2>&1 | clean
else
  echo "    **$RULES が無い。**"
fi
echo '```'

# ═══════════ 1. 当てる ═══════════
echo
echo "## 1. 当てる（**2 箇所 ＋ 件数の記録 1 箇所**）"
echo
echo '```'
if [ ! -f "$ORCH" ]; then
  echo "  対象が無い。"
elif ! "$NODE_BIN" --check "$PATCH" 2>/dev/null; then
  echo "  **パッチが構文エラー。当てない。**"
  "$NODE_BIN" --check "$PATCH" 2>&1 | head -5 | sed 's/^/    /'
else
  "$NODE_BIN" "$PATCH" "$ORCH" 2>&1 | clean
  if [ -f "$ORCH.x68-new.sh" ]; then
    echo
    echo "  --- 検査して置き換える ---"
    if bash -n "$ORCH.x68-new.sh" 2>/dev/null; then
      cp "$ORCH" "$ORCH.bak-$STAMP"
      mv "$ORCH.x68-new.sh" "$ORCH"
      chmod +x "$ORCH"
      echo "    **置き換えた**（退避 $(basename "$ORCH").bak-$STAMP）"
    else
      echo "    **bash の構文エラー。置き換えない**"
      bash -n "$ORCH.x68-new.sh" 2>&1 | head -4 | sed 's/^/      /'
      rm -f "$ORCH.x68-new.sh"
    fi
  fi
fi
echo '```'

# ═══════════ 2. 当てた後 ═══════════
echo
echo "## 2. 当てた後（**実物**）"
echo
echo '```javascript'
if [ -f "$ORCH" ]; then
  N="$(grep -n 'isAdPost = function' "$ORCH" 2>/dev/null | head -1 | cut -d: -f1)"
  if [ -n "$N" ]; then
    awk -v s="$((N - 6))" -v e="$((N + 16))" 'NR>=s && NR<=e {printf("%4d| %s\n", NR, $0)}' "$ORCH" \
      | cut -c1-190 | clean
  else
    echo "    （目印が見つからない）"
  fi
fi
echo '```'
echo
echo '```'
echo "  --- bash の構文検査（置き換えた後の実物） ---"
if bash -n "$ORCH" 2>/dev/null; then echo "    OK"; else bash -n "$ORCH" 2>&1 | head -4 | sed 's/^/    /'; fi
echo '```'

# ═══════════ 3. 効いたかの見方 ═══════════
echo
echo "## 3. 効いたかの確かめ方（**rc=0 は証拠にならない**）"
echo
echo "次の周回のあと、**次の 2 つ**で見る。"
echo
echo "| 見るもの | 効いていれば |"
echo "| --- | --- |"
echo "| \`/tmp/orch-adskip.json\` | \`ad_skipped\` に 1 以上 が入る |"
echo "| \`comment-warmup.log\` の日次 | **広告の列が 0 に近づき、enqueue が増える** |"
echo
echo '```'
if [ -f /tmp/orch-adskip.json ]; then
  echo "  いまの /tmp/orch-adskip.json:"
  cat /tmp/orch-adskip.json 2>/dev/null | cut -c1-200 | sed 's/^/    /'
else
  echo "  /tmp/orch-adskip.json: **まだ無い**（次の周回で作られる）"
fi
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用（**増える**）"
echo
echo "| | 1 回あたり | 1 日あたり | 1 か月あたり |"
echo "| --- | --- | --- | --- |"
echo "| いままで（生成 9 件/日・実績） | \$0.003 | \$0.027 | 約 \$0.81 |"
echo "| **この変更の後**（生成 最大 16 件/日） | \$0.003 | **\$0.048** | **\$1.44** |"
echo
echo "**増加は月 +\$0.63。** 単価は実測（2026-09-06・全文生成・Haiku 4.5）、"
echo "件数は 2026-09-13 のログ実測。"
echo "**16 件 は上限であって予想ではない。** 候補が足りなければ下回る。"
echo
echo "このタスク自体（パッチを当てる処理）は **\$0**。文字列の一致だけで LLM を呼ばない。"
} > "$OUT" 2>&1

echo "広告を選ぶ前に弾く / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
