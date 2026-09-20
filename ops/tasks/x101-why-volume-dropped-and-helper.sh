#!/bin/bash
# **① フォロー量が 9/18 以降 落ちた理由 ② プロフィールのフォロワー数を取る既存ヘルパー。測るだけ。$0。**
#
# ## ① なぜ量が落ちたのか
#
# x93 の日別実績。
#
#   9/13  15 件    9/16  13 件    9/19   4 件
#   9/14  23 件    9/17  19 件    9/20   5 件
#   9/15  15 件    9/18   6 件
#
# **9/17 の 19 件 から 9/18 の 6 件 へ、3 分の 1 に落ちている。**
# x99 では、返ってきた 27 人 のうち 17 人 が 9/13・9/16・9/17 のフォローだった。
# **量が落ちた日は、そのまま成果が落ちる。**
#
# 落ちた理由は 3 つ のどれか。**ログで確定させる。**
#
#   a) 上限（CAP=30）に当たっている  → 上限を上げれば増える
#   b) 候補が尽きている              → **種を差し替えないと増えない**
#   c) 途中で落ちている              → 直せば戻る
#
# **a と b では打つ手が正反対。** 推測で CAP をいじらない。
#
# ## ② 既存ヘルパーを探す
#
# 種の候補 58 件 のうち **54 件 がフォロワー数未取得**で、このままでは選べない。
# `hashtag-follow` は `follower count out of range (102000, ...)` と出せているので、
# **プロフィールからフォロワー数を取る仕組みはすでに在る。**
#
# **新しくセレクタを書かない**（最上位ルール 15）。在るものを特定して、次でそれを呼ぶ。
#
# ## やらないこと
#
# **CAP を変えない。種を触らない。フォローしない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/volume-and-helper.md"

secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(xox[bp]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
hide() { sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# フォロー量が落ちた理由 ＋ フォロワー数を取るヘルパー"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **9/17 の 19 件 から 9/18 の 6 件 へ、3 分の 1 に落ちている。**"
echo "> x99 では、返ってきた 27 人 のうち 17 人 が 9/13・9/16・9/17 のフォローだった。"
echo "> **量が落ちた日は、そのまま成果が落ちる。**"
echo
echo "**測るだけ。CAP を変えない。種を触らない。**"

# ═══════════ 1. 競合フォローのログ ═══════════
echo
echo "## 1. \`competitor-follower-follow\` は 9/18 以降 何をしていたか"
echo
echo '```'
CF="$L/competitor-follower-follow.log"
if [ ! -f "$CF" ]; then
  echo "  **$CF が無い。**"
  ls -1 "$L" 2>/dev/null | grep -i competitor | head -6 | sed 's/^/    /'
else
  echo "  ログ: $(wc -l < "$CF" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$CF" 2>/dev/null)"
  echo
  echo "  --- 各回の開始行（**どの種をいつ使ったか**）---"
  grep -E 'competitor-follower start' "$CF" 2>/dev/null | tail -14 | cut -c1-185 | sed 's/^/    /' | secrets
  echo
  echo "  --- 各回の締め（**何件 打ったか**）---"
  grep -iE 'done|完了|followed [0-9]+|total|summary|cap' "$CF" 2>/dev/null | tail -14 | cut -c1-185 | sed 's/^/    /' | hide | secrets
  echo
  echo "  --- 9/18〜9/20 の全行から、弾いた理由だけ数える ---"
  grep -E '2026-09-(18|19|20)' "$CF" 2>/dev/null \
    | grep -oE '❌ [^(]{4,60}' | sed -E 's/[0-9]+//g' | sort | uniq -c | sort -rn | head -12 \
    | awk '{ n=$1; $1=""; printf("    %4d 回 %s\n", n, $0) }'
  echo
  echo "  --- 「もう全員フォロー済み」で終わった回があるか（**候補が尽きた印**）---"
  grep -cE '全 follower 既 follow|already follow|対象なし|no target' "$CF" 2>/dev/null | head -1 | sed 's/^/    該当行: /'
  grep -E '全 follower 既 follow|already follow|対象なし|no target' "$CF" 2>/dev/null | tail -5 | cut -c1-185 | sed 's/^/    /' | hide | secrets
fi
echo '```'
echo
echo "**\`cap\` で止まっているなら上限の問題。**"
echo "**「もう全員フォロー済み」なら候補の問題で、上限を上げても増えない。**"
echo "後者なら、**種の差し替えが唯一の手**ということになる。"

# ═══════════ 2. ハッシュタグ側 ═══════════
echo
echo "## 2. \`hashtag-follow\` 側（**上限 90 に対して 1 日 3 件**）"
echo
echo '```'
HF="$L/hashtag-follow.log"
if [ -f "$HF" ]; then
  echo "  --- 9/18〜9/20 の弾いた理由 ---"
  grep -E '2026-09-(18|19|20)' "$HF" 2>/dev/null \
    | grep -oE '❌ [^(]{4,60}' | sed -E 's/[0-9]+//g' | sort | uniq -c | sort -rn | head -10 \
    | awk '{ n=$1; $1=""; printf("    %4d 回 %s\n", n, $0) }'
  echo
  echo "  --- 1 回あたり何件 拾えているか ---"
  grep -E 'picks: [0-9]+ authors' "$HF" 2>/dev/null | tail -12 | sed 's/^/    /'
else
  echo "  **$HF が無い。**"
fi
echo '```'
echo
echo "**拾えている数（picks）が小さいなら、上限ではなく入口の問題。**"
echo "タグを変えないと増えない。"

# ═══════════ 3. フォロワー数を取るヘルパー ═══════════
echo
echo "## 3. **プロフィールのフォロワー数を取る仕組み**はどこにあるか"
echo
echo "\`hashtag-follow\` は \`follower count out of range (102000, ...)\` と出せている。"
echo "**すでに在るものを特定する。新しくセレクタを書かない。**"
echo
echo '```'
echo "  --- 「follower count」を出している箇所 ---"
grep -rn -F 'follower count' "$S" 2>/dev/null | grep -v '\.bak' | head -8 | cut -c1-185 | sed 's/^/    /' | secrets
echo
echo "  --- フォロワー数を読んでいそうな関数 ---"
grep -rn -E 'function [a-zA-Z_]*[Ff]ollower|const [a-zA-Z_]*[Ff]ollowerCount|getFollowerCount|fetchProfile|profileStats' "$S" 2>/dev/null \
  | grep -v '\.bak' | head -10 | cut -c1-185 | sed 's/^/    /' | secrets
echo
echo "  --- 単独で呼べる形になっているスクリプト ---"
ls -1 "$S" 2>/dev/null | grep -iE 'profile|follower-count|check-follower|user-info' | head -10 | sed 's/^/    /'
echo
echo "  --- CDP への繋ぎ方（**写して使う**）---"
grep -rn -F 'connectOverCDP' "$S" 2>/dev/null | grep -v '\.bak' | head -5 | cut -c1-185 | sed 's/^/    /'
echo
echo "  --- playwright-core を使っているか（**playwright ではない**）---"
grep -rhoE 'require\("playwright[^"]*"\)' "$S" 2>/dev/null | sort | uniq -c | sed 's/^/    /'
echo '```'
echo
echo "**単独で呼べるものが在れば、次のタスクは 54 件 を回すだけで済む。**"
echo "無ければ、既存の呼び出し方を写して 1 本 書く（それでも \$0）。"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**ログとソースを読むだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**フォロワー数を DOM で取るのも \$0**（LLM を呼ばない）。"
echo "返信ループは \`MAX_PICKS\` を 6 にしたため **約 \$0.95/月（推定）** になる見込み。"
echo "実測は次の 24 時間 の \`cost_24h_usd\` で確かめる。"
} > "$OUT" 2>&1

echo "量が落ちた理由とヘルパー / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
