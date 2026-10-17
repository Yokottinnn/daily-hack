#!/bin/bash
# **ops/heartbeat の履歴から、利用者の氏名と保有ポイントが写った画像を消す。費用 $0。**
# 利用者の選択「履歴からも氏名の画像を消す」（2026-10-17）。
# x307 が reports/x307-logo/rakuten-top-header.png（と rakuten-logo-el.png）を push した（コミット d41e1918）。
# x308 で今の状態からは消したが履歴に残っている。heartbeat は Mac の worktree の履歴を毎回 force push するので、
# **Mac の worktree の履歴を書き換える**（クラウドで書き換えても次の push で戻る）。
# 範囲は d41e1918 の親から HEAD まで（6 コミット程度）。終わったら refs/original と reflog を消して gc で実体を消す。
# **GitHub 側に残る孤立コミット（SHA を知っていれば開ける）は、この経路では消せない**ことを報告に書く。
set -uo pipefail
WT="${OPS_HEARTBEAT_WORKTREE:-$HOME/.openclaw/ops-heartbeat-wt}"
BRANCH="${OPS_HEARTBEAT_BRANCH:-ops/heartbeat}"
OUT="${OPS_REPORT_DIR:-/tmp}/purge-header-shot.md"
BAD="d41e1918d6782f5c0f6b7616fbf4e9c8d3d790f0"
F1="reports/x307-logo/rakuten-top-header.png"; F2="reports/x307-logo/rakuten-logo-el.png"
{
echo "# 氏名の写った画像を ops/heartbeat の履歴から消す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'
cd "$WT" || { echo "worktree が無い"; exit 0; }
if ! git cat-file -e "$BAD" 2>/dev/null; then echo "対象のコミットが手元に無い（もう書き換え済みかもしれない）"; fi
before="$(git rev-list --all -- "$F1" "$F2" 2>/dev/null | wc -l | tr -d ' ')"
echo "書き換え前: 画像を含むコミット $before 件 / HEAD $(git rev-parse --short HEAD)"
if [ "$before" != "0" ] && git cat-file -e "$BAD" 2>/dev/null; then
  FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --index-filter "git rm -q --cached --ignore-unmatch '$F1' '$F2'" -- "$BAD^..HEAD" 2>&1 | tail -3
  git for-each-ref --format='%(refname)' refs/original/ | while IFS= read -r r || [ -n "$r" ]; do git update-ref -d "$r"; done
  git reflog expire --expire=now --all 2>&1 | tail -1
  git gc -q --prune=now 2>&1 | tail -1
fi
after="$(git rev-list HEAD -- "$F1" "$F2" 2>/dev/null | wc -l | tr -d ' ')"
echo "書き換え後: HEAD から辿れる、画像を含むコミット $after 件 / HEAD $(git rev-parse --short HEAD)"
git push -q --force origin "HEAD:$BRANCH" 2>&1 | tail -1; echo "push rc=$?"
echo '```'
echo
echo "- **GitHub 側には、書き換え前のコミット（d41e1918 など）が孤立した状態で残る。** SHA を知っていれば URL で開ける。完全に消すには GitHub のサポートに依頼が要る"
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "氏名の写った画像を ops/heartbeat の履歴から消した / $(basename "$OUT")"
