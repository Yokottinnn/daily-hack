#!/bin/bash
# SessionStart フック: 新しいセッションに前回までの状況を自動で引き継ぐ。
# 標準出力がそのままセッションのコンテキストに入る。
set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

HANDOFF="docs/session-handoff.md"

echo "=== 前回までの引き継ぎ情報（自動読み込み） ==="
echo

if [ -f "$HANDOFF" ]; then
  # 記録が伸び続けてもコンテキストを圧迫しないよう先頭 200 行に制限する。
  head -n 200 "$HANDOFF"
  total=$(wc -l < "$HANDOFF")
  if [ "$total" -gt 200 ]; then
    echo
    echo "（$HANDOFF は全 ${total} 行。以降は必要に応じて直接読むこと）"
  fi
else
  echo "$HANDOFF がまだ無い。作業内容は同ファイルに記録すること。"
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
