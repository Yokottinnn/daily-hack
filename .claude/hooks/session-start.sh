#!/bin/bash
# SessionStart フック: 新しいセッションに前回までの状況を自動で引き継ぐ。
# 標準出力がそのままセッションのコンテキストに入る。
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

HANDOFF="docs/session-handoff.md"
REQUESTS="docs/cross-session-requests.md"

echo "=== 前回までの引き継ぎ情報（自動読み込み） ==="
echo

if [ -f "$HANDOFF" ]; then
  # 履歴（セッション記録）は注入しない。理由はコンテキスト量ではなく位置にある。
  # この出力はコンテキスト先頭付近に入るため、内容が変わるとプロンプトキャッシュの
  # プレフィックスが丸ごと無効化される。全文を注入していた頃は npm run handoff で
  # 1 行追記するたびに再書き込みが発生し、キャッシュ書き込みが最大の費目になっていた。
  # 要約部分だけに絞れば、記録を追記しても注入内容は変わらずキャッシュが効き続ける。
  awk '/<!-- session-log:start -->/ { exit } { print }' "$HANDOFF"

  entries=$(grep -c '^### ' "$HANDOFF" 2>/dev/null || echo 0)
  echo "（過去の作業履歴 ${entries} 件は $HANDOFF の「セッション記録」にある。"
  echo "  経緯を知る必要があるときだけ同ファイルを読むこと）"
else
  echo "$HANDOFF がまだ無い。作業内容は同ファイルに記録すること。"
fi

# 相手セッションからの依頼を、開始時に必ず目に入れる。役割が分かれている以上、
# 自分宛の仕事が相手のブランチではなくこの表に置かれる（docs/session-roles.md）。
# 注入内容が変わるのは表が更新されたときだけなので、プロンプトキャッシュは効き続ける。
if [ -f "$REQUESTS" ]; then
  pending=$(awk -F'|' '
    /^\|/ && $5 ~ /未対応|対応中/ {
      gsub(/^[ \t]+|[ \t]+$/, "", $2); gsub(/^[ \t]+|[ \t]+$/, "", $3)
      gsub(/^[ \t]+|[ \t]+$/, "", $4); gsub(/^[ \t]+|[ \t]+$/, "", $5)
      printf "- [%s] %s %s: %s\n", $5, $2, $3, substr($4, 1, 120)
    }' "$REQUESTS")
  if [ -n "$pending" ]; then
    echo
    echo "--- 未決の依頼（$REQUESTS）---"
    printf '%s\n' "$pending"
    echo "自分の役割宛のものが自分の仕事。役割分担は docs/session-roles.md を参照。"
  fi
fi

echo
echo "--- リポジトリの現在状態 ---"
echo "ブランチ: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

echo "直近のコミット:"
git log --oneline -5 2>/dev/null || echo "  (取得できず)"

changes=$(git status --short 2>/dev/null)
if [ -n "$changes" ]; then
  echo "未コミットの変更:"
  printf '%s\n' "$changes" | head -n 20
  count=$(printf '%s\n' "$changes" | wc -l)
  if [ "$count" -gt 20 ]; then
    echo "  ... 他 $((count - 20)) 件"
  fi
else
  echo "未コミットの変更: なし"
fi

echo
echo "--- このセッションでの約束事 ---"
echo "作業を終える前に、次のコマンドで引き継ぎ記録を更新すること:"
echo '  npm run handoff -- "やったこと" --next "次にやること"'
echo "会話の中だけに状況を残さない。環境が消えると読めなくなる。"

exit 0
