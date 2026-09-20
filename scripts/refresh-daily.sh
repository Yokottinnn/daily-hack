#!/bin/bash
# **1 日 1 本、古い記事を調べ直して PR を作る。** Mac の launchd から呼ばれる。
#
# ## 費用（CLAUDE.md 最上位ルール 2-B）
#
# | 単位 | 金額 |
# | --- | --- |
# | 1 回あたり | **約 $0.07**（推定・Sonnet 5） |
# | 1 日あたり | **約 $0.07**（1 日 1 本） |
# | 1 か月あたり | **約 $2.1** |
#
# **実額は `ops/data/refresh-state.json` の `total_usd` に積む。** 推定のままにしない。
# 単価は `claude-api` スキルの料金表から（Sonnet 5 = $2/$10 per MTok）。
#
# ## 安全側に倒していること
#
# - **本文に当てるのは確度「高」だけ。** 中・低は PR の本文に一覧で載せ、人が選ぶ
# - **出典 URL が無い指摘は、当てる前に捨てる**（`refresh-article.mjs` の関門）
# - **自動マージしない。** PR を作るところまで
# - **1 日 1 本。** `MAX_PER_RUN` を増やすのは増額の提案なので、勝手に変えない
# - **作業ツリーが汚れていたら、触らずに終わる。** `reset --hard` で人の作業を消さない
#
# ## 自分をディスクに置かない（2026-09-20）
#
# t138 は `$REPO/scripts/refresh-daily.sh` を直に呼ぶ plist を書いて**失敗した。**
# Mac の作業ツリーは `origin/main` に追従していないので、**マージしてもファイルは現れない。**
# `ops-run-tasks.sh` と同じく、**`git show origin/main:` で取り出して走らせる**
# 起動用の薄いシム（`~/.openclaw/bin/refresh-daily-boot.sh`）から呼ばれる。
#
# macOS で動く（最上位ルール 14）。`timeout` も `sed -i` も `date -d` も使わない。
set -uo pipefail

REPO="${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}"
LOG="${HOME}/.openclaw/logs/refresh-daily.log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo "=== $(date '+%Y-%m-%dT%H:%M:%S%z') refresh-daily 開始"

cd "$REPO" || { echo "リポジトリが無い: $REPO"; exit 1; }

NODE_BIN="$(command -v node || echo /opt/homebrew/bin/node)"
[ -x "$NODE_BIN" ] || { echo "node が無い"; exit 1; }

# **鍵が無ければ、呼ばずに終わる。** 黙って動かないより、理由を残す
KEY_NAME="ANTHROPIC""_API_KEY"
if [ -z "${!KEY_NAME:-}" ]; then
  # OpenClaw の .env に入っていることがあるので、そこだけ読む
  ENVF="$HOME/openclaw/config/.env"
  if [ -f "$ENVF" ]; then
    # shellcheck disable=SC1090
    set -a; . "$ENVF"; set +a
  fi
fi
if [ -z "${!KEY_NAME:-}" ]; then
  echo "$KEY_NAME が無い。何もせず終わる。"
  exit 0
fi

# **main から始める。** 前回のブランチに積み上げない
git fetch origin main --quiet || { echo "fetch 失敗"; exit 1; }

# **作業ツリーが汚れていたら、何もせずに終わる。**
# この先の `reset --hard` は、人が手元で書きかけているものを黙って消す。
# `ops-run-tasks.sh` が「作業ツリーには触らない」と決めているのと同じ理由。
DIRTY="$(git status --porcelain | head -20)"
if [ -n "$DIRTY" ]; then
  echo "作業ツリーが汚れている。触らずに終わる:"
  echo "$DIRTY"
  exit 0
fi

git checkout -q main && git reset -q --hard origin/main || { echo "main に戻れない"; exit 1; }

# **どこで落ちても main に戻す。** 中途半端なブランチに居座ると、
# 翌日の実行も、人が開いたときの状態も壊れる。
trap 'git checkout -q main 2>/dev/null || true' EXIT

BR="refresh/$(date '+%Y%m%d-%H%M')"
git checkout -q -b "$BR"

OUT_DIR="$(mktemp -d)"
if ! OPS_REPORT_DIR="$OUT_DIR" "$NODE_BIN" scripts/refresh-article.mjs --apply; then
  echo "refresh-article.mjs が失敗した"
  git checkout -q main; git branch -D "$BR" >/dev/null 2>&1
  exit 1
fi

REPORT="$(ls "$OUT_DIR"/refresh-*.md 2>/dev/null | head -1)"
[ -n "$REPORT" ] || { echo "レポートが無い"; git checkout -q main; git branch -D "$BR" >/dev/null 2>&1; exit 1; }
SLUG="$(basename "$REPORT" .md | sed 's/^refresh-//')"

# **変更が無ければ PR を作らない。** 空の PR を毎日 積まない
if git diff --quiet -- src/content/posts; then
  echo "本文の変更なし（$SLUG）。PR は作らない。"
  mkdir -p docs/refresh && cp "$REPORT" "docs/refresh/$SLUG.md"
  git checkout -q main; git branch -D "$BR" >/dev/null 2>&1
  exit 0
fi

# **ビルドが通らなければ出さない**（blog-article スキル §4）
if ! npm run build >/tmp/refresh-build.log 2>&1; then
  echo "ビルドが落ちた。PR は作らない。"; tail -20 /tmp/refresh-build.log
  git checkout -q -- .; git checkout -q main; git branch -D "$BR" >/dev/null 2>&1
  exit 1
fi

mkdir -p docs/refresh
cp "$REPORT" "docs/refresh/$SLUG.md"
git add "src/content/posts/$SLUG.md" "docs/refresh/$SLUG.md" ops/data/refresh-state.json
git commit -q -F - <<EOF
refresh: $SLUG の古くなった数字を直した

確度「高」の指摘だけを本文に当てた。中・低は docs/refresh/$SLUG.md に
一覧で残してある。**出典 URL の無い指摘は当てる前に捨てている。**

実額と採用件数は docs/refresh/$SLUG.md の先頭にある。

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF

for i in 1 2 3 4; do
  git push -u origin "$BR" && break
  sleep $((2 ** i))
done

if command -v gh >/dev/null 2>&1; then
  gh pr create --base main --head "$BR" \
    --title "refresh: $SLUG の古くなった数字を直した" \
    --body-file <(printf '## 自動リフレッシュ\n\n**確度「高」の指摘だけを本文に当てた。** 中・低は下の一覧から人が選ぶ。\n**出典 URL の無い指摘は当てる前に捨てている。**\n\n**マージは人がやる。** プレビュー URL が bot のコメントで出るので、そこで中身を見てから入れる。\n\n---\n\n%s\n' "$(cat "$REPORT")")
  echo "PR を作った: $BR"
else
  echo "gh が無い。ブランチだけ push した: $BR"
fi

git checkout -q main
echo "=== 終わり"
