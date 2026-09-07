#!/bin/bash
# **1 件あたりの入力/出力トークンを実測する。推定で設計しない。費用 $0。読むだけ。**
#
# ## なぜ要るか
#
# 「まとめ判定で入力 −70%」「skip 短縮で出力 −70%」と見積もったが、
# **入力と出力の内訳を実測していない。** 単価は
#
#   入力 $1.00/MTok ／ **出力 $5.00/MTok**（Haiku 4.5・claude-api スキルの料金表）
#
# **出力は入力の 5 倍 高い。** どちらを削るべきかは内訳で決まる。
# **推定で設計を決めない。**
#
# ## プロンプトキャッシュが使えるかも、ここで決まる
#
# Haiku 4.5 のキャッシュ最低は **4,096 tok**。プロンプトがこれ未満だと
# `cache_control` を付けても **`cache_creation_input_tokens: 0` で静かに無効**になる。
#
#   Opus 5     512 tok
#   Sonnet 5   1,024 tok
#   Haiku 4.5  **4,096 tok**   ← いま使っているモデル
#
# 2026-08-15 の実測は入力 3,168 tok。**足りない。**
# ただし**まとめ判定で入力が増えれば、4,096 を超えてキャッシュが効くようになる。**
#
# ## 測るもの
#
#   1. 実際の `usage`（`input_tokens` / `output_tokens` / `cache_*`）
#   2. **skip したときの出力トークン**（理由の作文にいくら使っているか）
#   3. 成功したときの出力トークン
#   4. 生成器が組み立てているプロンプトの実サイズ
#   5. **前段で落とせるはずの候補が何件あるか**（hashtag のみ・短文・URL だけ）
#
# **投稿しない。返信しない。LLM を呼ばない。ジョブも Chrome も触らない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/token-split.md"
NODE_BIN="/usr/local/bin/node"
GEN="$S/asuka-reply.cjs"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 1 件あたりの入力/出力トークン（実測）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **推定で設計を決めない。**"
echo "> 単価は 入力 \$1.00/MTok ／ **出力 \$5.00/MTok**（Haiku 4.5）。"
echo "> **出力は入力の 5 倍 高い。** どちらを削るべきかは内訳で決まる。"

# ═══════════ 1. usage の実測 ═══════════
echo
echo "## 1. 実際の \`usage\`（ログに残っていれば）"
echo
echo '```'
FOUND=0
for f in "$W"/logs/*.log; do
  [ -f "$f" ] || continue
  n=$(grep -c 'input_tokens' "$f" 2>/dev/null || echo 0)
  [ "${n:-0}" -gt 0 ] 2>/dev/null || continue
  FOUND=1
  echo "  [$(basename "$f")]  usage の記録 ${n} 件"
  grep -oE '"(input_tokens|output_tokens|cache_creation_input_tokens|cache_read_input_tokens)":[0-9]+' "$f" 2>/dev/null \
    | tail -40 | sed 's/^/    /'
  echo
done
[ "$FOUND" = "0" ] && {
  echo "  **どのログにも usage が記録されていない。**"
  echo "  → 生成器が usage を捨てている。**記録するようにしないと実測できない。**"
}
echo '```'

echo
echo "### 生成器は usage を記録しているか"
echo
echo '```javascript'
if [ -f "$GEN" ]; then
  echo "  # $(basename "$GEN") — $(wc -l < "$GEN" | tr -d ' ') 行"
  grep -nE 'usage|input_tokens|output_tokens|max_tokens|model:|model =|cache_control|temperature' \
    "$GEN" 2>/dev/null | head -20 | cut -c1-160 | sed 's/^/  /' | clean
else
  echo "  **生成器が無い: $GEN**"
fi
echo '```'

# ═══════════ 2. プロンプトの実サイズ ═══════════
echo
echo "## 2. プロンプトの実サイズ（**4,096 tok を超えるか**）"
echo
echo "Haiku 4.5 のキャッシュ最低は **4,096 tok**。未満だと静かに効かない。"
echo
echo '```'
if [ -f "$GEN" ]; then
  echo "  --- 生成器が読み込んでいる固定ファイル ---"
  grep -oE "readFileSync\([^)]*\)|require\(['\"][^'\"]*\.json['\"]\)" "$GEN" 2>/dev/null \
    | head -10 | sed 's/^/    /'
  echo
  echo "  --- その実サイズ（バイト → おおよそのトークン: 日本語は約 1.5 B/tok） ---"
  for f in "$W"/data/reply-style-prompt.json "$W"/data/comment-templates.json \
           "$W"/data/reply-ng-rules.json "$W"/data/brand-voice.json; do
    [ -f "$f" ] || continue
    B=$(wc -c < "$f" | tr -d ' ')
    printf '    %-34s %8s B  ≒ %6s tok\n' "$(basename "$f")" "$B" "$((B/2))"
  done
  echo
  echo "  --- 生成器そのものに埋め込まれた文字列（system プロンプト） ---"
  SB=$(grep -oE '`[^`]{200,}`' "$GEN" 2>/dev/null | wc -c | tr -d ' ')
  echo "    バッククォート内の長文: ${SB} B  ≒ $((SB/2)) tok"
fi
echo '```'
echo
echo "**合計が 4,096 tok 未満なら、いまのままではキャッシュは効かない。**"
echo "**まとめ判定で入力を増やすと、逆にキャッシュが使えるようになる。**"

# ═══════════ 3. skip の出力コスト ═══════════
echo
echo "## 3. skip の理由文は何文字 使っているか（**出力単価は入力の 5 倍**）"
echo
echo '```'
L="$W/logs/comment-warmup.log"
if [ -f "$L" ]; then
  echo "  --- 直近 20 件の skip 理由の長さ ---"
  grep -oE '"reason":"[^"]*"' "$L" 2>/dev/null | tail -20 | while read -r r; do
    n=${#r}
    printf '    %4s 文字 ≒ %4s tok   %s\n' "$n" "$((n/2))" "$(echo "$r" | cut -c1-58)"
  done | clean
  echo
  TOTC=$(grep -oE '"reason":"[^"]*"' "$L" 2>/dev/null | tail -20 | wc -c | tr -d ' ')
  echo "  20 件の合計: ${TOTC} 文字 ≒ $((TOTC/2)) tok"
  echo "  1 件あたり平均: $((TOTC/20)) 文字 ≒ $((TOTC/40)) tok"
  echo
  echo "  **skip をコード 1 語（例 skip:money_advice ≒ 5 tok）にすれば、ここはほぼ 0 になる。**"
fi
echo '```'

# ═══════════ 4. 前段で落とせる候補 ═══════════
echo
echo "## 4. 前段で落とせるはずの候補は何件あるか（**LLM を呼ばずに \$0**）"
echo
echo "いま **LLM を呼んでから** skip している理由のうち、"
echo "**投稿本文を見るだけで判定できるもの**を数える。"
echo
echo '```'
if [ -f "$L" ]; then
  D7="$(grep -oE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}' "$L" | tr -d '[' | sort -u | tail -7 | tr '\n' '|' | sed 's/|$//')"
  TOTAL=$(grep -cE "^\[($D7).*gen failed" "$L" 2>/dev/null || echo 0)
  FREE=$(grep -E "^\[($D7).*gen failed" "$L" 2>/dev/null | grep -c 'LLM を呼ばずに' || echo 0)
  echo "  直近 7 日の gen failed: ${TOTAL} 件"
  echo "    うち LLM を呼ばずに \$0 : ${FREE} 件"
  echo "    **うち課金して 0 件**  : $((TOTAL-FREE)) 件"
  echo
  echo "  --- 課金して skip した理由（前段に移せそうなものを探す） ---"
  grep -E "^\[($D7).*gen failed" "$L" 2>/dev/null | grep -v 'LLM を呼ばずに' \
    | grep -oE '"reason":"[^"]{0,70}' | sed 's/"reason":"//' | cut -c1-56 \
    | sort | uniq -c | sort -rn | head -12 | sed 's/^/    /' | clean
  echo
  echo "  **「hashtag のみ」「本文が短い」「内容がない」は本文を見るだけで判定できる。**"
  echo "  **＝ 前段に移せば LLM 課金がゼロになる。**"
fi
echo '```'

echo
echo "### いまの前段フィルタは何を見ているか"
echo
echo '```javascript'
F="$S/ng-filter-candidates.cjs"
if [ -f "$F" ]; then
  echo "  # $(basename "$F") — $(wc -l < "$F" | tr -d ' ') 行"
  grep -nE 'if |return|length|test\(|includes\(|match\(' "$F" 2>/dev/null \
    | head -25 | cut -c1-160 | sed 's/^/  /' | clean
else
  echo "  **無い: $F**"
fi
echo '```'

echo
echo "---"
echo
echo "## この実測で決まること"
echo
echo "| 測った値 | 決まること |"
echo "| --- | --- |"
echo "| 入力/出力の内訳 | **入力と出力のどちらを削るべきか** |"
echo "| プロンプトの実サイズ | **キャッシュが使えるか**（4,096 tok の壁） |"
echo "| skip 理由の長さ | **コード化でいくら浮くか** |"
echo "| 課金して skip した件数 | **前段フィルタでいくら浮くか** |"
echo
echo "**LLM を呼んでいない。投稿もしていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
U="$(grep -m1 -oE 'usage の記録 [0-9]+ 件|どのログにも usage が記録されていない' "$OUT" 2>/dev/null || echo '')"
echo "**$(date '+%H:%M') トークン内訳を実測（\$0）** / $U / $(basename "$OUT")"
