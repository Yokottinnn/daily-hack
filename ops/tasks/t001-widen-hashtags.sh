#!/bin/bash
# **ハッシュタグを 8 → 16 に増やす。フォロー候補の供給を太くする。**
#
# ## 052 で分かったこと（推測ではない）
#
# 詰まりは 2 か所にあって、**性質が逆だった。**
#
#   hashtag-follow      trend candidates: 13 / 2 / 6 / 4   ← **取得そのものが細い**
#                       EARLY_EXIT_COUNT=20 に一度も届いていない
#
#   competitor-follower scraped 53〜61 → new targets 10 → end: 0〜1/10
#                       ← **候補は cap ぶん揃っている。落ちているのは足切り**
#
# **hashtag 側は「取れていない」。** タグを増やせば candidates はほぼ比例して増える。
# trend-detect.js のコメントに「HASHTAGS を優先度高 core 12個に絞る (元 24)」とあり、
# **実体は 8 個**。絞りすぎている。
#
# ## competitor 側の足切りには触らない
#
# 一番効くのは `follow-handle.js` の `ratio < 0.3`（人気アカを全部弾く）だが、
# これは **2026-05-25 に利用者が指示して入れた条件**（コード中に明記）。
# **勝手に緩めない。** 変えるなら利用者の判断を仰ぐ。
#
# ## 足すタグ（曖昧なものは入れない）
#
# 「キャンペーン」「お得」のような広い語は、売春垢や情報商材を拾う。
# ng-filter は返信の入口にしか無く、**フォローは無検査**なので、
# **ジャンルが一意に決まる語だけ**足す。
#
# ## 安全側の作り
#
#   - 既に 16 個以上なら何もしない
#   - 触る前に .pre-widen.<時刻> へ退避
#   - node --check を通す。**通らなければ即座に元へ戻す**
#   - 配列の要素数が想定どおりでなければ元へ戻す
#
# **cap は触らない。** 1 日にフォローする数は変わらず、候補だけが増える。
# **X のスパム判定リスクは上がらない。**
#
# **読むのと 1 ファイルの書き換えだけ。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
T="$W/scripts/trend-detect.js"
OUT="${OPS_REPORT_DIR:-/tmp}/widen-hashtags.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# ハッシュタグを増やす（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **hashtag 側は「取れていない」。** candidates が 2〜13 件で EARLY_EXIT(20) に届かない。"
echo "> **cap は触らない。** フォロー数は変わらず、候補だけが増える。"

echo
echo "## 1. いまの中身"
echo
if [ ! -f "$T" ]; then echo "**trend-detect.js が無い。中止。**"; exit 1; fi
echo '```javascript'
awk '/const HASHTAGS *= *\[/,/\]/' "$T" | mask | head -12
echo '```'
NOW="$("$NODE_BIN" -e '
const fs=require("fs");
const s=fs.readFileSync(process.argv[1],"utf8");
const m=s.match(/const HASHTAGS\s*=\s*\[([\s\S]*?)\]/);
console.log(m ? m[1].split(",").filter(x=>x.trim()).length : -1);
' "$T" 2>/dev/null)"
echo
echo "- 現在のタグ数: **${NOW}**"
if [ "${NOW:-0}" -ge 16 ] 2>/dev/null; then
  echo "- **既に 16 以上。何もしない。**"; exit 0
fi
if [ "${NOW:-0}" -le 0 ] 2>/dev/null; then
  echo "- **配列を読めない。触らない。**"; exit 1
fi

echo
echo "## 2. 足すタグ"
echo
echo "**ジャンルが一意に決まる語だけ。** 「キャンペーン」「お得」のような広い語は入れない"
echo "（フォローは無検査なので、売春垢や情報商材を拾う）。"
echo
cp "$T" "$T.pre-widen.$STAMP"
echo "- 退避: $(basename "$T").pre-widen.$STAMP"

# **拡張子が無いと node --check が ERR_UNKNOWN_FILE_EXTENSION で落ちる。** .js を付ける
TMPF="${TMPDIR:-/tmp}/trend.$$.js"
"$NODE_BIN" - "$T" "$TMPF" <<'JS'
const fs = require("fs");
const [src, dst] = process.argv.slice(2);
let s = fs.readFileSync(src, "utf8");
const m = s.match(/const HASHTAGS\s*=\s*\[([\s\S]*?)\]/);
if (!m) { console.error("配列が無い"); process.exit(1); }
const cur = m[1].split(",").map(x => x.trim().replace(/^["']|["']$/g, "")).filter(Boolean);
// ジャンルが一意に決まる語だけ。広い語は入れない
const ADD = ["楽天ポイント","dポイント","Vポイント","節約術","家計簿","貯金","クレジットカード","電子マネー"];
const next = [...cur];
for (const t of ADD) if (!next.includes(t)) next.push(t);
const body = "\n  " + next.map(t => `"${t}"`).join(", ").replace(/((?:"[^"]*", ){5})/g, "$1\n  ") + "\n";
s = s.replace(m[0], `const HASHTAGS = [${body}]`);
fs.writeFileSync(dst, s);
console.log(`  ${cur.length} → ${next.length} 個`);
console.log(`  足したもの: ${ADD.filter(t => !cur.includes(t)).join(" / ")}`);
JS
rc=$?
if [ "$rc" != "0" ] || [ ! -s "$TMPF" ]; then
  echo "- **書き換えに失敗。元のまま残す。**"; rm -f "$TMPF"; exit 1
fi

if ! "$NODE_BIN" --check "$TMPF" 2>/dev/null; then
  echo "- **構文エラー。元のまま残す。**"
  "$NODE_BIN" --check "$TMPF" 2>&1 | mask | head -3 | sed 's/^/      /'
  rm -f "$TMPF"; exit 1
fi
AFTER="$("$NODE_BIN" -e '
const fs=require("fs");
const m=fs.readFileSync(process.argv[1],"utf8").match(/const HASHTAGS\s*=\s*\[([\s\S]*?)\]/);
console.log(m ? m[1].split(",").filter(x=>x.trim()).length : -1);
' "$TMPF")"
if [ "${AFTER:-0}" != "16" ]; then
  echo "- **要素数が ${AFTER} で想定（16）と違う。元のまま残す。**"; rm -f "$TMPF"; exit 1
fi
cp "$TMPF" "$T"; rm -f "$TMPF"
echo "- **書き換えた**（node --check 通過・要素数 16）"

echo
echo "## 3. 結果"
echo
echo '```javascript'
awk '/const HASHTAGS *= *\[/,/\]/' "$T" | mask | head -12
echo '```'
echo
echo "- 構文: $("$NODE_BIN" --check "$T" 2>/dev/null && echo '**正常**' || echo '**エラー**')"
echo "- \`hashtag-follow\` の稼働: $(launchctl list 2>/dev/null | awk '{print $3}' | grep -qx ai.openclaw.hashtag-follow && echo 稼働 || echo '**未ロード**')"

echo
echo "## 4. 次の発火で見ること"
echo
echo "\`trend candidates:\` が **2〜13 から増えているか。** 増えなければタグではなく"
echo "スクレイプ側（\`PER_ITEM_TIMEOUT_MS=12s\` で打ち切られている等）が原因。"
echo
echo "直近のログ:"
grep -E 'trend candidates|unique new authors|picks:|=== end' "$W/logs/hashtag-follow.log" 2>/dev/null \
  | tail -8 | mask | cut -c1-120 | sed 's/^/    /'

echo
echo "## 5. 触っていないもの（**利用者の判断が要る**）"
echo
echo "competitor 側は候補が cap ぶん揃っていて、落ちているのは足切り。"
echo "一番効くのは \`follow-handle.js\` の **\`ratio < 0.3\`**（人気アカを全部弾く）だが、"
echo "**2026-05-25 に利用者が指示して入れた条件**なので勝手に緩めない。"
echo
echo "    // 🚨 2026-05-25 改定 user 指示: 規模問わず ratio<0.3 で skip"
echo
echo "同様に \`follower_count\` の 100〜10000 も、上げると大きいアカウントを追うことになり"
echo "フォロバ率が落ちる。**どちらも数字を見せて判断を仰ぐこと。**"
} > "$OUT" 2>&1

n="$(grep -oE '現在のタグ数: \*\*[0-9]+' "$OUT" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
if grep -q '書き換えた' "$OUT" 2>/dev/null; then
  echo "ハッシュタグを ${n:-?} → 16 に増やした / $(basename "$OUT")"
else
  echo "**増やせていない** / $(basename "$OUT")"
fi
