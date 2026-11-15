#!/bin/bash
# **t681 が保存した、ログイン中の利用者の氏名・住所が入ったページの本文を消す（t685）。** 読むだけではなく削除。LLM 不使用・$0。
# 2026-11-15 blog3: t681 で Amazon と楽天の公式ページを Mac の Chrome で開いたところ、ヘッダーに表示される氏名とお届け先（町名・郵便番号）まで
# innerText に入り、reports/t681/amazon.txt と rakuten.txt として公開の ops/heartbeat ブランチに載った。最上位ルール（出力は公開リポジトリに載る・秘密を出さない）に反する。
# ここでは作業フォルダから消すだけ（次の push でブランチの先頭から消える）。過去のコミットに残る分は、利用者の判断で別に扱う。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
n=0
for f in "$RDIR/t681/amazon.txt" "$RDIR/t681/rakuten.txt" "$RDIR/t682/amazonbf.txt"; do
  if [ -f "$f" ]; then rm -f "$f" && n=$((n+1)) && echo "削除: ${f#$RDIR/}"; fi
done
# ほかに氏名か住所が入った t681/t682 のファイルが無いか、数だけ出す（中身は出さない）
left=$(grep -l -E '晴海|104-0053' "$RDIR"/t681/* "$RDIR"/t682/* 2>/dev/null | wc -l | tr -d ' ')
echo "消した数: $n ／ 住所が残っている t681・t682 のファイル: $left"
