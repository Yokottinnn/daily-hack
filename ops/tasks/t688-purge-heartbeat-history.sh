#!/bin/bash
# **ops/heartbeat の履歴を 1 コミットにまとめ、個人情報（利用者の氏名・メールアドレス・お届け先）が入った過去の版を外す（t688）。** LLM 不使用・$0。
# 2026-11-15 blog3: 利用者がダイアログで「履歴から個人情報を消す」を選んだ。t681/t682 の Chrome 本文（氏名・お届け先）と、
# 以前のレポート 14 件（氏名・メールアドレス）が公開ブランチに載っていた。先頭からは t685/t686 で消したが履歴に残っている。
# このブランチは heartbeat もポーラーも「Mac の作業フォルダの HEAD」を force push するため、GitHub 側だけ書き換えても戻る。
# だから Mac の作業フォルダで書き換え、ポーラーの push（このタスクの直後）でそのまま GitHub に出す。
# 氏名そのものを公開リポジトリに書かないよう、確かめる語は base64 で持つ。中身は出さず、数とファイル名だけ出す。
set -uo pipefail
WT="$(dirname "${OPS_REPORT_DIR:?}")"
cd "$WT" || { echo "作業フォルダが無い: $WT"; exit 1; }
br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ "$br" = "ops/heartbeat" ] || { echo "ブランチが $br なので中止"; exit 1; }
n=0
for f in asp-probe/resultshape.md hero-cands/.fetch-commons-photo.py hero-photos/.fetch-commons-photo.py \
         shop-setup/amazon-status.log shop-setup/amazon-status.md t062-rum-sitetag.md t396-shop-mac-setup.md \
         t397-shop-mac-setup.md t398-shop-mac-setup.md t530-shop-mac-setup.md t556-google-login.md \
         t557-adsense-signup-read.md t612-results-shape.md t626-shop-mac-setup.md; do
  if [ -f "reports/$f" ]; then rm -f "reports/$f" && n=$((n+1)); fi
done
P="$(printf '%s' 'bi15b2tvdGF85qiq55Sw5bCa5bex' | base64 -d 2>/dev/null || printf '%s' 'bi15b2tvdGF85qiq55Sw5bCa5bex' | base64 -D)"
[ -n "$P" ] || { echo "確かめる語を戻せなかったので中止（消した $n 件はそのまま）"; exit 1; }
left="$(grep -rlE -i "$P" . --exclude-dir=.git 2>/dev/null)"
nleft="$(printf '%s' "$left" | grep -c . | head -1)"
if [ "${nleft:-0}" != "0" ]; then
  echo "まだ残っている $nleft 件のため、履歴の書き換えは中止: $(printf '%s' "$left" | tr '\n' ' ' | cut -c1-200)"
  exit 1
fi
git add -A >/dev/null 2>&1
git commit -q -m "ops: 個人情報が入ったレポートを消した（t688）" >/dev/null 2>&1 || true
before="$(git rev-list --count HEAD)"
new="$(git commit-tree "HEAD^{tree}" -m "ops: 履歴を 1 コミットにまとめた（個人情報が入った過去の版を外す・t688）")" || { echo "commit-tree に失敗"; exit 1; }
git reset -q --soft "$new" || { echo "reset に失敗"; exit 1; }
after="$(git rev-list --count HEAD)"
echo "消したファイル $n 件 ／ 残り 0 件 ／ コミット数 $before → $after（この直後の push で GitHub に出る）"
