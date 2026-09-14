#!/bin/bash
# **週次ブログレポートが、いま何を走らせているのかを測る。**
#
# ## なぜ
#
# 2026-09-14 08:00 に Slack へ届いたレポートに、**変数が展開されないまま**出ていた。
#
#     • CF visits（全パス）: *${ALL_VISITS}* / requests ${ALL_REQ}
#
# このバグは **2026-08-31 に見つかって、9/6 に `scripts/weekly-blog-report.py` を
# Python で書き直して直したことになっている**（スクリプト冒頭にその経緯がある）。
# それでも同じ文字列が出続けている。**つまり走っているのは別のもの。**
#
# 候補は 2 つ。どちらかを当て推量で決めない。
#
#   (a) Mac のクローンが main に追いついていない（t067 で実際に起きた）
#   (b) plist が古いシェル版スクリプトを指したままになっている
#
# ## これは測るだけのタスク。**何も直さない**
#
# plist は tweet2 の所有（docs/session-roles.md）。直し方は結果を見てから決める。
# 測るものと直すものを同じタスクに入れない（最上位ルール 15）。
#
# **秘密は出さない。** 出力は公開リポジトリに載る。
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t080-weekly-report-truth.md"
mkdir -p "$RDIR"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"

{
  echo "# 週次レポートは何を走らせているか（t080）"
  echo
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo
} > "$OUT"

# ---- 1. 週次レポート系の launchd ジョブ ----
{
  echo "## 1. launchd に載っているジョブ"
  echo
  echo '```'
  launchctl list 2>/dev/null | grep -i -E "weekly|report" || echo "(weekly/report を含むジョブは launchctl list に無い)"
  echo '```'
  echo
} >> "$OUT"

# ---- 2. plist の中身（ProgramArguments だけ）----
{
  echo "## 2. plist が実際に叩いているコマンド"
  echo
} >> "$OUT"
found_plist=0
for d in "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons; do
  [ -d "$d" ] || continue
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    found_plist=1
    {
      echo "### \`$(basename "$p")\`"
      echo
      echo '```'
      # **plutil で構造を読む。** grep で XML を拾うと隣の値を掴む
      plutil -extract ProgramArguments json -o - "$p" 2>/dev/null \
        || plutil -p "$p" 2>/dev/null | sed -n '1,40p' \
        || echo "(読めなかった)"
      echo '```'
      echo
      echo "- 実行間隔: \`$(plutil -extract StartInterval raw -o - "$p" 2>/dev/null || echo '-')\`"
      echo "- カレンダー: \`$(plutil -extract StartCalendarInterval json -o - "$p" 2>/dev/null || echo '-')\`"
      echo
    } >> "$OUT"
  done < <(ls "$d"/*.plist 2>/dev/null | xargs -I{} sh -c 'grep -lE "weekly|report" "{}" 2>/dev/null' 2>/dev/null)
done
[ "$found_plist" = 1 ] || echo "(weekly/report に一致する plist が見つからない)" >> "$OUT"

# ---- 3. Mac のクローンが main に追いついているか ----
{
  echo "## 3. Mac のクローンの状態"
  echo
  if [ -d "$REPO/.git" ]; then
    git -C "$REPO" fetch -q origin main 2>/dev/null || true
    echo "| 項目 | 値 |"
    echo "| --- | --- |"
    echo "| パス | \`$REPO\` |"
    echo "| HEAD | \`$(git -C "$REPO" log -1 --format='%h %ci %s' 2>/dev/null | cut -c1-90)\` |"
    echo "| origin/main | \`$(git -C "$REPO" log -1 --format='%h %ci' origin/main 2>/dev/null)\` |"
    echo "| main に対して遅れ | **$(git -C "$REPO" rev-list --count HEAD..origin/main 2>/dev/null || echo '?') コミット** |"
    echo
    echo "### weekly-blog-report.py はあるか"
    echo
    if [ -f "$REPO/scripts/weekly-blog-report.py" ]; then
      echo "- **ある。** 行数 $(wc -l < "$REPO/scripts/weekly-blog-report.py" | tr -d ' ')"
      echo "- \`ALL_VISITS\` を含む行: **$(grep -c 'ALL_VISITS' "$REPO/scripts/weekly-blog-report.py" 2>/dev/null || echo 0)**"
      echo "  （**Python 版は docstring の中でしか触れていないはず。** 本文に出るなら別物）"
    else
      echo "- **無い。** これだけで (a) が確定する"
    fi
  else
    echo "⚠️ \`$REPO\` が git リポジトリとして見つからない"
  fi
  echo
} >> "$OUT"

# ---- 4. 古いシェル版が残っていないか ----
{
  echo "## 4. \${ALL_VISITS} を書いているファイル"
  echo
  echo "**この文字列を持つスクリプトが、いま走っている本体。**"
  echo
  echo '```'
  for d in "$REPO/scripts" "$HOME/openclaw/scripts" "$HOME/.openclaw/workspace/scripts" "$HOME/bin"; do
    [ -d "$d" ] || continue
    grep -rl 'ALL_VISITS' "$d" 2>/dev/null | head -10
  done
  echo '```'
  echo
} >> "$OUT"

{
  echo "## 読み方"
  echo
  echo "- **3 の「遅れ」が 0 でないなら (a)。** クローンを pull すれば直る"
  echo "- **4 に \`.sh\` が出てきたら (b)。** plist がそちらを指している"
  echo "- 両方なら両方 直す必要がある"
} >> "$OUT"

cat "$OUT"
exit 0
