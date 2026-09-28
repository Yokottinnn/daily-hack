#!/bin/bash
# **記事リフレッシュのロックを外す（t201）。$0（API は呼ばない）。**
#
# ## 何が起きていたか（t200 で特定）
#
# `refresh-daily.sh` は **指摘 0 件の日に PR を作らない**ので、
# `ops/data/refresh-state.json` を変更したまま commit せずに終わっていた。
# 翌日から汚れガードに毎日 当たり、**9/24〜9/28 の 5 日 連続で空振り。**
#
#     作業ツリーが汚れている。触らずに終わる:
#      M ops/data/refresh-state.json
#
# ## 直した側（main に入っている）
#
# **状態ファイルをリポジトリの外へ出した。**
# `refresh-article.mjs` が `REFRESH_STATE` を見るようにし、
# `refresh-daily.sh` が `~/.openclaw/state/refresh-state.json` を渡す。
# これで作業ツリーは汚れず、ガードは本来の役目（人の作業を守る）だけになる。
#
# ## このタスクがやること
#
#   ① いま汚れている状態ファイルの中身を **`~/.openclaw/state/` へ引き継ぐ**
#      （$0.0443 の累計と done の記録を捨てない）
#   ② `git checkout --` で作業ツリーを戻す
#   ③ **掃除できたことを別の口で確かめる**（`rc=0` は証拠にならない・最上位ルール 13）
#   ④ **`--dry-run` で配線を確かめる**（API は呼ばないので $0）
#
# **追跡ファイルが状態ファイル以外にも汚れていたら、何もしない。**
# 人の書きかけを消さないため。
#
# 180 秒 で打ち切る。LLM 不使用。**$0/回・$0/日・$0/月。**

set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t201-refresh-unlock.md"
STATE_OUT="$HOME/.openclaw/state/refresh-state.json"
TRACKED="ops/data/refresh-state.json"
mkdir -p "$RDIR"

{
  echo "# 記事リフレッシュのロックを外す（t201・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

[ -d "$REPO/.git" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
cd "$REPO" || { echo "⚠️ **cd できない**" >> "$OUT"; cat "$OUT"; exit 0; }

# ── 汚れているのが状態ファイルだけかを確かめる ──────────────
DIRTY="$(git status --porcelain --untracked-files=no)"
OTHER="$(printf '%s\n' "$DIRTY" | grep -v "$TRACKED" | grep -c . | head -1)"
case "$OTHER" in ''|*[!0-9]*) OTHER=0 ;; esac
{
  echo "## 作業ツリーの汚れ"
  echo ""
  echo '```text'
  printf '%s\n' "$DIRTY" | head -20
  echo '```'
  echo ""
  echo "- 状態ファイル以外の汚れ: **${OTHER} 件**"
  echo ""
} >> "$OUT"

if [ "$OTHER" != "0" ]; then
  {
    echo "⚠️ **状態ファイル以外も汚れているので、何もしない。**"
    echo "人が手元で書きかけている可能性がある。中身を見てから決めること。"
  } >> "$OUT"
  cat "$OUT"; exit 0
fi

# ── ① 引き継ぐ ──────────────────────────────────────────────
mkdir -p "$(dirname "$STATE_OUT")"
if [ -f "$STATE_OUT" ]; then
  echo "- \`$STATE_OUT\` は既に在る（上書きしない）" >> "$OUT"
elif [ -f "$TRACKED" ]; then
  cp "$TRACKED" "$STATE_OUT"
  echo "- **引き継いだ**: \`$TRACKED\` → \`$STATE_OUT\`" >> "$OUT"
else
  echo "- ⚠️ \`$TRACKED\` が無い" >> "$OUT"
fi
{
  echo ""
  echo "引き継いだ中身:"
  echo ""
  echo '```json'
  head -c 600 "$STATE_OUT" 2>/dev/null
  echo
  echo '```'
  echo ""
} >> "$OUT"

# **JSON として読めるかを自分で確かめる**（最上位ルール 13）
NODE_BIN="$(command -v node || echo /opt/homebrew/bin/node)"
if [ -x "$NODE_BIN" ] && [ -f "$STATE_OUT" ]; then
  if "$NODE_BIN" -e "JSON.parse(require('fs').readFileSync('$STATE_OUT','utf8'))" 2>/dev/null; then
    echo "- JSON として読める **✅**" >> "$OUT"
  else
    echo "- ⚠️ **JSON が壊れている。ここで止める。**" >> "$OUT"
    cat "$OUT"; exit 0
  fi
fi

# ── ② 作業ツリーを戻す ──────────────────────────────────────
git checkout -- "$TRACKED" 2>/dev/null || true
echo "" >> "$OUT"

# ── ③ 別の口で確かめる ──────────────────────────────────────
AFTER="$(git status --porcelain --untracked-files=no | grep -c . | head -1)"
case "$AFTER" in ''|*[!0-9]*) AFTER=0 ;; esac
git fetch -q origin main 2>/dev/null || true
BEHIND="$(git rev-list --count HEAD..origin/main 2>/dev/null | head -1)"
case "$BEHIND" in ''|*[!0-9]*) BEHIND="?" ;; esac
{
  echo "## 掃除のあと"
  echo ""
  echo "| 見たこと | 結果 |"
  echo "| --- | --- |"
  echo "| 追跡ファイルの汚れ | **${AFTER} 件** $([ "$AFTER" = "0" ] && echo '✅' || echo '❌') |"
  echo "| origin/main からの遅れ | ${BEHIND} コミット |"
  echo ""
} >> "$OUT"

if [ "$AFTER" != "0" ]; then
  {
    echo "⚠️ **まだ汚れている。**"
    echo ""
    echo '```text'
    git status --porcelain --untracked-files=no | head -10
    echo '```'
  } >> "$OUT"
  cat "$OUT"; exit 0
fi

# ── ④ 配線を確かめる（API は呼ばない＝$0） ──────────────────
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 3
  done
  wait "$pid" 2>/dev/null
}

{
  echo "## 配線の確認（\`--dry-run\`・**API は呼ばない**）"
  echo ""
} >> "$OUT"

if [ -x "$NODE_BIN" ]; then
  # **main の最新を取り出して走らせる。** クローンは遅れていることがある
  SC="${TMPDIR:-/tmp}/t201-refresh-article.mjs"
  if git show origin/main:scripts/refresh-article.mjs > "$SC" 2>/dev/null; then
    DRY="${TMPDIR:-/tmp}/t201-dry.txt"
    REFRESH_STATE="$STATE_OUT" run_limited 60 "$NODE_BIN" "$SC" --dry-run > "$DRY" 2>&1
    {
      echo '```text'
      tail -8 "$DRY"
      echo '```'
      echo ""
    } >> "$OUT"
    # 引き継いだ done の記事を**選んでいない**ことが、状態が効いている証拠
    if grep -q 'mens-hairremoval-comparison-2026' "$DRY"; then
      echo "- ⚠️ **9/23 に調べた記事をまた選んでいる。** 状態が効いていない" >> "$OUT"
    else
      echo "- **9/23 に調べた記事は選ばれていない ✅**（状態が効いている）" >> "$OUT"
    fi
    rm -f "$SC" "$DRY"
  else
    echo "⚠️ origin/main からスクリプトを取り出せない" >> "$OUT"
  fi
else
  echo "⚠️ node が無い" >> "$OUT"
fi

{
  echo ""
  echo "---"
  echo ""
  echo "> **次の定時は明朝 05:30。** そこで初めて「直った」と言える。"
  echo "> このタスクは API を呼んでいない。**\$0/回・\$0/日・\$0/月。**"
} >> "$OUT"

cat "$OUT"
