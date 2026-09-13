#!/bin/bash
# **物乞い・乗っ取り系の投稿を入口で落とす。費用 $0（LLM 不使用）。**
#
# ## なぜ（2026-09-13 の x54 実測）
#
# `trend-detect` が返した候補の 1 件目がこれ。
#
#   "text":"おかねください\n #乞食 #PayPay #PayPayください #PayPay乞食"
#
# **ゲートは弾くので実害は出ていない。** だが弾くのは**生成した後**なので、
# **LLM 代を払ってから捨てている。**
#
# 入口（`target_skip`）で落とせば、その分が丸ごと浮く。
#
# ## 足すもの（**高精度なものだけ**）
#
# 物乞い・現金配布・乗っ取りは、**タグが特徴的で誤爆しにくい。**
#
#   #乞食 #PayPay乞食 #PayPayください #お金ください #現金配布
#   #投げ銭 #支援希望 #カンパ #物乞い
#   おかねください / お金ください / 恵んでください
#
# **曖昧な語は入れない。** 「PayPay」単体は普通の話題で出るので入れない。
# 「支援」単体も災害支援などで出るので入れない。**タグか定型句だけ。**
#
# ## やらないこと
#
# **しきい値を触らない。上限を変えない。投稿しない。フォローしない。**
# **LLM を呼ばない（$0）。** JSON に足すだけ。
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/block-beggar.md"
NODE_BIN="/usr/local/bin/node"
RULES="$D/reply-relevance-rules.json"
PATCH="$(mktemp -t beg).js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
trap 'rm -f "$PATCH"' EXIT

secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide | secrets; }

cat > "$PATCH" <<'JSEOF'
const fs = require('fs');
const p = process.argv[2];
const r = JSON.parse(fs.readFileSync(p, 'utf8'));
r.target_skip = r.target_skip || {};

// **タグは hashtags へ。** campaign_words と混ぜない（意味が違う）
const tags = r.target_skip.hashtags || [];
const addTags = [
  '#乞食', '#PayPay乞食', '#PayPayください', '#お金ください', '#おかねください',
  '#現金配布', '#投げ銭', '#支援希望', '#カンパ', '#物乞い', '#金欲しい',
];
const beforeT = tags.length;
for (const t of addTags) if (!tags.includes(t)) tags.push(t);
r.target_skip.hashtags = tags;

// **定型句は campaign_words へ。** 高精度なものだけ
const cw = r.target_skip.campaign_words || [];
const addWords = [
  'おかねください', 'お金ください', 'お金下さい', '恵んでください', '恵んで下さい',
  '助けてください金', 'カンパお願い', '投げ銭お願い',
];
const beforeW = cw.length;
for (const w of addWords) if (!cw.includes(w)) cw.push(w);
r.target_skip.campaign_words = cw;

fs.writeFileSync(p, JSON.stringify(r, null, 2));
console.log('  hashtags      : ' + beforeT + ' → ' + tags.length + ' 件');
console.log('  campaign_words: ' + beforeW + ' → ' + cw.length + ' 件');
JSEOF

{
echo "# 物乞い・乗っ取り系を入口で落とす"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`trend-detect\` が返した候補の 1 件目:"
echo ">"
echo "> \`\"text\":\"おかねください\\n #乞食 #PayPay #PayPayください #PayPay乞食\"\`"
echo ">"
echo "> **ゲートは弾くので実害は出ていない。** だが弾くのは**生成した後**なので、"
echo "> **LLM 代を払ってから捨てている。**"

echo
echo "## 1. 足す前"
echo
echo '```'
if [ ! -f "$RULES" ]; then
  echo "  **$RULES が無い。**"
else
  "$NODE_BIN" -e '
const fs=require("fs");
const r=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const ts=r.target_skip||{};
console.log("  hashtags      : "+(ts.hashtags||[]).length+" 件");
console.log("  campaign_words: "+(ts.campaign_words||[]).length+" 件");
console.log("  domains       : "+(ts.domains||[]).length+" 件");
console.log("");
console.log("  いまの hashtags: "+JSON.stringify(ts.hashtags||[]));
' "$RULES" 2>&1 | clean
fi
echo '```'

echo
echo "## 2. 足すもの（**高精度なものだけ**）"
echo
echo "物乞い・現金配布は**タグが特徴的で誤爆しにくい。**"
echo
echo "| 種類 | 足すもの |"
echo "| --- | --- |"
echo "| タグ | \`#乞食\` \`#PayPay乞食\` \`#PayPayください\` \`#お金ください\` \`#おかねください\` \`#現金配布\` \`#投げ銭\` \`#支援希望\` \`#カンパ\` \`#物乞い\` \`#金欲しい\` |"
echo "| 定型句 | \`おかねください\` \`お金ください\` \`お金下さい\` \`恵んでください\` \`恵んで下さい\` \`助けてください金\` \`カンパお願い\` \`投げ銭お願い\` |"
echo
echo "**曖昧な語は入れない。**"
echo "「PayPay」単体は普通の話題で出る。「支援」単体は災害支援などで出る。"
echo "**タグか定型句だけにする。**"
echo
echo '```'
if [ ! -f "$RULES" ]; then
  echo "  対象が無い。"
elif ! "$NODE_BIN" --check "$PATCH" 2>/dev/null; then
  echo "  **パッチが構文エラー。当てない。**"
  "$NODE_BIN" --check "$PATCH" 2>&1 | head -5 | sed 's/^/    /'
else
  cp "$RULES" "$RULES.bak-$STAMP" && echo "  退避: $(basename "$RULES").bak-$STAMP"
  "$NODE_BIN" "$PATCH" "$RULES" 2>&1 | sed 's/^/  /' | clean
  if "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$RULES" 2>/dev/null; then
    echo "  JSON: OK"
  else
    echo "  **JSON が壊れた。戻す。**"
    cp "$RULES.bak-$STAMP" "$RULES"
  fi
fi
echo '```'

echo
echo "## 3. 足した後"
echo
echo '```'
if [ -f "$RULES" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
const r=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const ts=r.target_skip||{};
console.log("  hashtags      : "+(ts.hashtags||[]).length+" 件");
console.log("  campaign_words: "+(ts.campaign_words||[]).length+" 件");
console.log("");
console.log("  hashtags: "+JSON.stringify(ts.hashtags||[]));
' "$RULES" 2>&1 | clean
fi
echo '```'

echo
echo "## 4. どれくらい浮くか"
echo
echo "**実測できていないので推定。前提を書く。**"
echo
echo "x54 が返した候補 5 件 のうち **1 件**が物乞い投稿だった。"
echo "この比率が続くなら、生成の **約 20%** が入口で落ちる。"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 入口で落とす処理そのもの | **\$0**（文字列の一致だけ。LLM を呼ばない） |"
echo "| 浮く分（**推定**・生成の 20%） | 1 日 約 \$0.04 ／ 1 か月 約 **\$1.2** |"
echo
echo "**「5 件 中 1 件」は 1 回の観測。** 比率が違えば額も変わる。"
echo "定時の返信ループ全体は **推定** 1 回 \$0.003 ／ 1 日 約 \$0.19 ／ 1 か月 約 \$5.8"
echo "（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。"
} > "$OUT" 2>&1

echo "物乞い投稿を入口で落とす / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
