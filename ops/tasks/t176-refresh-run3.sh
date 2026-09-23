#!/bin/bash
# **SDK が入っていることを実測したので、もう一度 走らせる（t176）。**
#
# ## 費用（最上位ルール 2-A・**承認済み**）
#
# | 単位 | 金額 |
# | --- | --- |
# | **この実行 1 回** | **約 $0.07**（推定・Sonnet 5） |
# | 1 日あたり | 約 $0.07（定時は 1 日 1 本） |
# | 1 か月あたり | 約 $2.1 |
#
# **推定の前提**: `claude-sonnet-5`（$2 / $10 per MTok・`claude-api` スキルの料金表）、
# 入力 2 万・出力 3 千トークン。**実額は `ops/data/refresh-state.json` の
# `total_usd` に積まれる。** 推定のままにしない。
#
# **2026-09-23 に利用者の承認を得ている**（「鍵が読めたら初回 1 本を走らせる」）。
#
# ## ここまでの 2 回（**どちらも課金 $0**）
#
# | 回 | 止まった場所 |
# | --- | --- |
# | **t171** | `@anthropic-ai/sdk` の import（`package.json` に宣言が無かった） |
# | **t173** | その SDK を「入れられなかった」（**理由を握りつぶしていた**） |
#
# ## t175 の棚卸しで分かったこと（**推測が外れていた**）
#
# | 測ったもの | 結果 |
# | --- | --- |
# | npm | **PATH に在る**（`/opt/homebrew/bin/npm` v11.12.1）。**「PATH に無い」は誤り** |
# | `@anthropic-ai/sdk` | **`blog/node_modules` に入っている**（`0.128.0`） |
# | `node_modules` | 426 項目・**書き込み可** |
#
# **入れる必要はもう無い。** だから**入れようとしない。**
# 無ければ**理由を書いて止まる**だけにする。
#
# ## なぜ定時を待たないか
#
# 次の定時は翌朝 05:30。**待つ必要がない**（最上位ルール 9）。
# 鍵は t170 で読めることを確認済み（`.env` に在る・長さ 3 桁）。
#
# ## 何をするか
#
# **定時ジョブとまったく同じものを呼ぶ。** 別経路で走らせて
# 「動いた」と言えても、定時が動く証拠にはならない。
#
#   ~/.openclaw/bin/refresh-daily-boot.sh   ← launchd が呼んでいるシム
#
# シムが無ければ `git show origin/main:scripts/refresh-daily.sh | bash` で代替する
# （Mac の作業ツリーは `origin/main` に追従していないため・最上位ルール 14）。
#
# ## 安全側（`refresh-daily.sh` 側で担保されていること）
#
# - **作業ツリーが汚れていたら、触らずに終わる**（人の作業を消さない）
# - **自動マージしない。** PR を作るところまで
# - **本文に当てるのは確度「高」だけ。** 出典 URL が無い指摘は捨てる
# - **鍵の値はログに出さない**
#
# **このタスクも鍵を出力しない。** ログの末尾を出すが、
# `refresh-daily.sh` は「鍵を読めた（値は出さない）」としか書かない。
#
# **300 秒 で打ち切る**（最上位ルール 15）。API 呼び出しは 1 回だけ。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t176-refresh-run3.md"
SHIM="$HOME/.openclaw/bin/refresh-daily-boot.sh"
LOG="$HOME/.openclaw/logs/refresh-daily.log"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"

{
  echo "# リフレッシュ 3 回目（t176）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**費用: この実行 1 回で 約 \$0.07（推定）。** 利用者の承認済み。"
  echo "**実額は \`ops/data/refresh-state.json\` の \`total_usd\` に積まれる。**"
  echo ""
} > "$OUT"

# --- 走らせる前の状態を控える（**あとで差分を見るため**） ---
BEFORE_USD="$( [ -f "$REPO/ops/data/refresh-state.json" ] \
  && python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('total_usd',0))" \
       "$REPO/ops/data/refresh-state.json" 2>/dev/null || echo "?" )"
LOG_BEFORE=0
[ -f "$LOG" ] && LOG_BEFORE=$(wc -l < "$LOG" | tr -d ' ')
case "$LOG_BEFORE" in ''|*[!0-9]*) LOG_BEFORE=0 ;; esac
echo "- 実行前の \`total_usd\`: **${BEFORE_USD}**" >> "$OUT"
echo "" >> "$OUT"

# --- 依存が在るかだけ見る（**入れない**。t175 で在ることを実測済み） ---
if [ -d "$REPO" ]; then
  if ( cd "$REPO" && node -e "require.resolve('@anthropic-ai/sdk/package.json')" >/dev/null 2>&1 ); then
    V="$( cd "$REPO" && node -e "console.log(require('@anthropic-ai/sdk/package.json').version)" 2>/dev/null )"
    echo "- \`@anthropic-ai/sdk\`: ✅ **在る**（${V:-版が読めない}）" >> "$OUT"
  else
    {
      echo "- \`@anthropic-ai/sdk\`: ❌ **無い。**"
      echo "  - node: \`$(command -v node || echo 不明)\` / npm: \`$(command -v npm || echo 不明)\`"
      echo "  - \`PATH\`: \`$PATH\`"
      echo ""
      echo "**t175 では在ると出ていた。** 状況が変わっているので、**走らせずに止める。**"
    } >> "$OUT"
    cat "$OUT"; exit 0
  fi
  echo "" >> "$OUT"
fi

START=$(date +%s)

# --- 定時ジョブと同じ入口で走らせる（**300 秒 で打ち切る**・素の bash） ---
if [ -x "$SHIM" ]; then
  echo "- 入口: \`$SHIM\`（**launchd と同じシム**）" >> "$OUT"
  "$SHIM" >/dev/null 2>&1 &
else
  echo "- ⚠️ シムが無いので \`git show origin/main:scripts/refresh-daily.sh\` で代替" >> "$OUT"
  ( cd "$REPO" && git fetch -q origin main 2>/dev/null; \
    git -C "$REPO" show origin/main:scripts/refresh-daily.sh | bash ) >/dev/null 2>&1 &
fi
PID=$!

# **`timeout` は macOS に無い**（最上位ルール 14）。素の bash で待つ
KILLED=0
while kill -0 "$PID" 2>/dev/null; do
  if [ $(( $(date +%s) - START )) -ge 300 ]; then
    kill "$PID" 2>/dev/null; KILLED=1; break
  fi
  sleep 3
done
wait "$PID" 2>/dev/null
RC=$?
ELAPSED=$(( $(date +%s) - START ))

{
  echo "- 経過 **${ELAPSED} 秒** / 終了コード **$RC**$( [ "$KILLED" = 1 ] && echo "（**300 秒 で打ち切った**）" )"
  echo ""
  echo "> **\`rc=0\` は動いた証拠でしかない**（最上位ルール 13）。"
  echo "> 下の \`total_usd\` と PR の有無で判定する。"
  echo ""
} >> "$OUT"

# --- ログの増えた分だけ出す（**鍵は出ない。「読めた」としか書かれない**） ---
{
  echo "## ログ（この実行で増えた分）"
  echo ""
  echo '```'
} >> "$OUT"
if [ -f "$LOG" ]; then
  LOG_AFTER=$(wc -l < "$LOG" | tr -d ' ')
  case "$LOG_AFTER" in ''|*[!0-9]*) LOG_AFTER=0 ;; esac
  N=$(( LOG_AFTER - LOG_BEFORE ))
  [ "$N" -gt 0 ] && tail -n "$N" "$LOG" | tail -40 >> "$OUT" || echo "（増えていない）" >> "$OUT"
else
  echo "（ログが無い: $LOG）" >> "$OUT"
fi
echo '```' >> "$OUT"
echo "" >> "$OUT"

# --- 実額（**推定ではなくここが実測**） ---
AFTER_USD="$( [ -f "$REPO/ops/data/refresh-state.json" ] \
  && python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('total_usd',0))" \
       "$REPO/ops/data/refresh-state.json" 2>/dev/null || echo "?" )"
{
  echo "## 実額"
  echo ""
  echo "| | |"
  echo "| --- | --- |"
  echo "| 実行前 \`total_usd\` | **${BEFORE_USD}** |"
  echo "| 実行後 \`total_usd\` | **${AFTER_USD}** |"
  echo ""
  echo "**この差が、この 1 回の実測額。** 推定の \$0.07 と突き合わせる。"
  echo ""
} >> "$OUT"

# --- PR ができたか（**これが「やった」証拠**） ---
{
  echo "## 作られたブランチ・PR"
  echo ""
} >> "$OUT"
if [ -d "$REPO" ]; then
  ( cd "$REPO" && git fetch -q origin 2>/dev/null || true )
  BRS="$(git -C "$REPO" branch -r 2>/dev/null | grep -E 'origin/refresh/' | tail -3 | tr -d ' ')"
  if [ -n "$BRS" ]; then
    printf '%s\n' "$BRS" | sed 's/^/- `/; s/$/`/' >> "$OUT"
  else
    echo "- **`refresh/` のブランチは無い。** 変更が無かったか、途中で止まった" >> "$OUT"
  fi
  echo "" >> "$OUT"
  echo "- \`main\` の現在: \`$(git -C "$REPO" log --oneline origin/main -1 2>/dev/null)\`" >> "$OUT"
else
  echo "- ⚠️ リポジトリが無い: \`$REPO\`" >> "$OUT"
fi

{
  echo ""
  echo "---"
  echo ""
  echo "**読み方**"
  echo ""
  echo "- \`total_usd\` が増えていれば、**API を実際に呼んでいる**"
  echo "- \`refresh/\` のブランチが在れば、**PR まで作れている**"
  echo "- どちらも無くてログに「変更が無い」と書いてあれば、"
  echo "  **当てるべき指摘が無かった**ということ（失敗ではない）"
} >> "$OUT"

cat "$OUT"
