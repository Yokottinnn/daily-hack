#!/bin/bash
# **どのタグが何を連れてくるかを測る。測るだけ。費用 $0。**
#
# ## なぜ
#
# `hashtag-follow` は **上限 90 に対して 1 日 0〜4 件**しか拾えていない（x101）。
# しかも拾った分も大手ブランド公式で弾かれている。
#
#   @rakutenplay     ❌ follower count out of range (102000)
#   @tsuruhaofficial ❌ follower count out of range (297000)
#   @GinzaKawaii     ❌ off-niche bio
#   @inami_furusato  ❌ inactive (last post 162d ago)
#
# **上限ではなく入口の問題。** 上限を上げても増えない。
# **どのタグが公式ばかり連れてくるのかを特定してから入れ替える。**
#
# ## やらないこと
#
# **タグを変えない。フォローしない。LLM を呼ばない（$0）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; L="$W/logs"; D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/hashtag-tags.md"
HF="$L/hashtag-follow.log"
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }
{
echo "# どのタグが何を連れてくるか"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`hashtag-follow\` は**上限 90 に対して 1 日 0〜4 件**（x101）。"
echo "> **上限ではなく入口の問題。** 上限を上げても増えない。"
echo
echo "**測るだけ。タグを変えない。**"
echo
echo "## 1. いま使っているタグ（**実物**）"
echo
echo '```'
F="$(grep -rl 'hashtag' "$S" 2>/dev/null | grep -v '\.bak' | grep -iE 'hashtag-follow' | head -1)"
if [ -z "$F" ]; then
  echo "  **hashtag-follow の実体が見つからない。**"
  ls -1 "$S" 2>/dev/null | grep -i hashtag | sed 's/^/    候補: /'
else
  echo "  $F（$(wc -l < "$F" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$F" 2>/dev/null)）"
  echo
  echo "  --- タグの一覧を持っていそうな箇所 ---"
  grep -n -E 'TAGS|HASHTAGS|タグ|const .*= *\[' "$F" 2>/dev/null | head -10 | cut -c1-185 | sed 's/^/    /'
  echo
  LN="$(grep -n -E 'TAGS|HASHTAGS' "$F" 2>/dev/null | head -1 | cut -d: -f1)"
  if [ -n "$LN" ]; then
    A=$(( LN > 3 ? LN - 3 : 1 )); B=$(( LN + 16 ))
    awk -v a="$A" -v b="$B" 'NR>=a && NR<=b {printf("%4d| %s\n", NR, $0)}' "$F" | cut -c1-190 | sed 's/^/    /'
  fi
  echo
  echo "  --- 環境変数で渡せるか ---"
  grep -n -E 'process\.env\.[A-Z_]+' "$F" 2>/dev/null | head -8 | cut -c1-185 | sed 's/^/    /'
fi
echo '```'
echo
echo "**環境変数で渡せるなら plist を書き換えるだけで済む。** 戻すのも簡単。"
echo
echo "## 2. タグごとの成績（**ログから**）"
echo
echo '```'
if [ -f "$HF" ]; then
  echo "  --- タグを出している行の形を見る ---"
  grep -oE '#[^ ]{2,20}' "$HF" 2>/dev/null | sort | uniq -c | sort -rn | head -20 \
    | awk '{ printf("    %4d 回  %s\n", $1, $2) }'
  echo
  echo "  --- 直近 30 回 の拾い件数 ---"
  grep -E 'picks: [0-9]+ authors' "$HF" 2>/dev/null | tail -30 \
    | grep -oE 'picks: [0-9]+' | awk '{ s+=$2; n++; printf("") } END { if (n) printf("    平均 %.1f 件/回（%d 回 ぶん）\n", s/n, n) }'
  echo
  echo "  --- 弾いた理由（全期間）---"
  grep -oE '❌ [^(]{4,60}' "$HF" 2>/dev/null | sed -E 's/[0-9]+//g' | sort | uniq -c | sort -rn | head -12 \
    | awk '{ n=$1; $1=""; printf("    %5d 回 %s\n", n, $0) }'
  echo
  echo "  --- **実際にフォローできた件数**（弾かれなかったもの）---"
  grep -cE '✅|followed @|follow ok' "$HF" 2>/dev/null | head -1 | sed 's/^/    /'
else
  echo "  **$HF が無い。**"
fi
echo '```'
echo
echo "**「大きすぎる」で弾かれる割合が高いタグは、公式アカウントが集まるタグ。**"
echo "個人の投稿が多いタグに入れ替えると、拾える数が増える見込み。"
echo
echo "## 3. 費用"
echo
echo "**ログとソースを読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**タグを入れ替えるのも \$0**（DOM 操作のみ）。"
echo "返信ループは \`MAX_PICKS\` 6 で **約 \$0.95/月（推定）**。実測は明日 確かめる。"
} > "$OUT" 2>&1
echo "タグの成績 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
