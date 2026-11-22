#!/bin/bash
# **ops/heartbeat から、3 店ボタンの確認で撮った店の画面の写真を消し、履歴を 1 コミットにまとめる（t890）。** LLM 不使用・$0。
# 2026-11-22 blog3: スマートウォッチの記事のリンク確認で、楽天の画面の写真のヘッダーにログイン中の利用者の氏名と保有ポイントが写り、
# 公開ブランチ（reports/shop-verify/・reports/shop-pages/）に載っていた（CLAUDE.md「ログインが要るページの画面をレポートに保存しない」に反する）。
# 撮る道具（scripts/shop/verify-buttons.mjs・find-product-pages.mjs）は同じ PR で、写真を Mac の手元（private-shots）にだけ置くよう直した。
# 作りは t688 と同じ: このブランチは heartbeat もポーラーも Mac の作業フォルダの HEAD を force push するので、Mac の作業フォルダで書き換える。
# 消した写真は Mac の手元（~/.openclaw/workspace/private-shots/purged-<日時>/）に移して残す（確認の証跡は手元で見られる）。中身は出さず数だけ出す。
set -uo pipefail
WT="$(dirname "${OPS_REPORT_DIR:?}")"
cd "$WT" || { echo "作業フォルダが無い: $WT"; exit 1; }
br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ "$br" = "ops/heartbeat" ] || { echo "ブランチが $br なので中止"; exit 1; }
KEEP="$HOME/.openclaw/workspace/private-shots/purged-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$KEEP"
n=0
while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  mkdir -p "$KEEP/$(dirname "$f")" && mv "$f" "$KEEP/$f" && n=$((n+1))
done < <(find reports/shop-verify reports/shop-pages -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null)
left="$(find reports/shop-verify reports/shop-pages -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | grep -c . | head -1)"
[ "${left:-0}" = "0" ] || { echo "写真がまだ $left 件残っているので履歴の書き換えは中止（移した $n 件はそのまま）"; exit 1; }
# 文字のレポートにも氏名が無いことを確かめる（t688 と同じ語。公開リポジトリに氏名を書かないよう base64 で持つ）
P="$(printf '%s' 'bi15b2tvdGF85qiq55Sw5bCa5bex' | base64 -d 2>/dev/null || printf '%s' 'bi15b2tvdGF85qiq55Sw5bCa5bex' | base64 -D)"
[ -n "$P" ] || { echo "確かめる語を戻せなかったので中止（移した $n 件はそのまま）"; exit 1; }
txt="$(grep -rlE -i "$P" . --exclude-dir=.git 2>/dev/null)"
ntxt="$(printf '%s' "$txt" | grep -c . | head -1)"
if [ "${ntxt:-0}" != "0" ]; then
  echo "文字のレポートに氏名などが $ntxt 件残っているので、履歴の書き換えは中止: $(printf '%s' "$txt" | tr '\n' ' ' | cut -c1-200)"
  git add -A >/dev/null 2>&1; git commit -q -m "ops: 店の画面の写真を消した（t890・履歴の書き換えは中止）" >/dev/null 2>&1 || true
  exit 1
fi
git add -A >/dev/null 2>&1
git commit -q -m "ops: 店の画面の写真を消した（t890）" >/dev/null 2>&1 || true
before="$(git rev-list --count HEAD)"
new="$(git commit-tree "HEAD^{tree}" -m "ops: 履歴を 1 コミットにまとめた（ログイン中の氏名が写った店の画面の写真を外す・t890）")" || { echo "commit-tree に失敗"; exit 1; }
git reset -q --soft "$new" || { echo "reset に失敗"; exit 1; }
after="$(git rev-list --count HEAD)"
echo "手元に移して公開から外した写真 $n 件 ／ 残り 0 件 ／ 文字のレポートの氏名 0 件 ／ コミット数 $before → $after（この直後の push で GitHub に出る）"
