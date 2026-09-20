#!/bin/bash
# **リフレッシュのジョブが `bootstrap` rc=0 なのに載らない。原因を出して、載せ直す（t140）。**
#
# t139 のレポート:
#
#   bootstrap の rc: 0（これは証拠にならない）
#   launchctl list: **載っていない** ← こちらが証拠
#
# **エラー文を捨てていた。** t139 は `>/dev/null 2>&1` で握り潰していたので、
# 何が起きたのか分からない。ここでは**出力を残して**判断する。
#
# 疑っているもの:
#
#   1. **`launchctl print-disabled` の無効リスト。** 一度 disable されたラベルは
#      **bootstrap が rc=0 でも起動しない。** `launchctl enable` が要る
#   2. bootout と bootstrap がぶつかる（37: Operation already in progress）
#   3. plist 自体が読めない（5: Input/output error）
#
# ついでに t139 で分かった 2 つの詰まりも見る。**どちらも触らずに報告だけ。**
#
#   - 作業ツリーに未コミットが 2 件（→ ジョブは何もせずに終わる）
#   - **鍵が見つからない**（→ 走っても何もせずに終わる）
#
# **秘密は出さない。** 鍵は「在るか」と「どのファイルか」だけを出す。**値は出さない。**
# **このタスクに API 課金は無い。**

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t140-refresh-job-diagnose.md"
mkdir -p "$RDIR"
LABEL="com.dailyhack.refresh-daily"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BOOT="$HOME/.openclaw/bin/refresh-daily-boot.sh"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
UID_N="$(id -u)"

{
  echo "# リフレッシュのジョブが載らない（t140）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "## 1) 置いたものは在るか"
  echo ""
  [ -f "$PLIST" ] && echo "- plist: **在る** \`$PLIST\`" || echo "- plist: ⚠️ **無い**"
  [ -f "$BOOT" ] && echo "- シム: **在る** \`$BOOT\`" || echo "- シム: ⚠️ **無い**"
  if [ -f "$PLIST" ]; then
    if plutil -lint "$PLIST" >/dev/null 2>&1; then
      echo "- \`plutil -lint\`: **通る**"
    else
      echo "- \`plutil -lint\`: ⚠️ **通らない** — \`$(plutil -lint "$PLIST" 2>&1 | head -1)\`"
    fi
  fi
  echo ""
  echo "## 2) 無効リストに入っていないか"
  echo ""
} > "$OUT"

DIS="$(launchctl print-disabled "gui/$UID_N" 2>/dev/null | grep -F "$LABEL" | head -1)"
if [ -n "$DIS" ]; then
  echo "- \`print-disabled\`: \`$(echo "$DIS" | tr -d '\t' | head -c 120)\`" >> "$OUT"
else
  echo "- \`print-disabled\`: このラベルの行は無い" >> "$OUT"
fi

# **enable してから載せる。** disable されていると rc=0 でも起動しない
EN_OUT="$(launchctl enable "gui/$UID_N/$LABEL" 2>&1)"; EN_RC=$?
BO_OUT="$(launchctl bootout "gui/$UID_N/$LABEL" 2>&1)"; BO_RC=$?

{
  echo "- \`launchctl enable\`: rc=$EN_RC ${EN_OUT:+— \`$(echo "$EN_OUT" | head -1 | head -c 160)\`}"
  echo "- \`launchctl bootout\`: rc=$BO_RC ${BO_OUT:+— \`$(echo "$BO_OUT" | head -1 | head -c 160)\`}"
  echo ""
  echo "## 3) 載せ直す（**エラー文を残す**）"
  echo ""
} >> "$OUT"

LOADED="**載っていない**"
i=1
while [ "$i" -le 3 ]; do
  BS_OUT="$(launchctl bootstrap "gui/$UID_N" "$PLIST" 2>&1)"; BS_RC=$?
  echo "- $i 回目: rc=$BS_RC ${BS_OUT:+— \`$(echo "$BS_OUT" | head -2 | tr '\n' ' ' | head -c 200)\`}" >> "$OUT"
  if launchctl list | grep -qF "$LABEL"; then LOADED="**載った**"; break; fi
  sleep 3
  i=$((i + 1))
done

{
  echo ""
  echo "- \`launchctl list\`: $LOADED ← **こちらが証拠**"
  echo ""
  if [ "$LOADED" = "**載った**" ]; then
    echo "### 載った後の状態"
    echo ""
    echo '```text'
    launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
      | grep -E 'state|program|path|runs|last exit' | head -8
    echo '```'
  fi
  echo ""
  echo "## 4) 走っても何もしない条件（**触らずに見るだけ**）"
  echo ""
} >> "$OUT"

# --- 鍵 ---------------------------------------------------------------------
KEY_NAME="ANTHROPIC""_API_KEY"
FOUND=""
for f in "$HOME/openclaw/config/.env" "$HOME/.openclaw/config/.env" "$HOME/.openclaw/.env" \
         "$HOME/openclaw/.env" "$REPO/.env" "$HOME/.config/anthropic/.env"; do
  [ -f "$f" ] || continue
  if grep -q "^[[:space:]]*\(export[[:space:]]*\)\?$KEY_NAME=" "$f" 2>/dev/null; then
    FOUND="${FOUND}${FOUND:+, }\`${f/#$HOME/~}\`"
  fi
done
for rc in "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.bash_profile" "$HOME/.profile"; do
  [ -f "$rc" ] || continue
  if grep -q "$KEY_NAME" "$rc" 2>/dev/null; then
    FOUND="${FOUND}${FOUND:+, }\`${rc/#$HOME/~}\`"
  fi
done
if [ -n "${!KEY_NAME:-}" ]; then
  echo "- 鍵: **この環境変数に在る**（値は出さない）" >> "$OUT"
elif [ -n "$FOUND" ]; then
  echo "- 鍵: **ファイルに行が在る** → $FOUND（値は出さない）" >> "$OUT"
else
  echo "- 鍵: ⚠️ **どこにも見つからない。** 05:30 に走っても**何もせずに終わる**" >> "$OUT"
fi

# --- Claude Code の認証（参考・鍵とは別物） ----------------------------------
if [ -f "$HOME/.claude/.credentials.json" ]; then
  echo "- 参考: \`~/.claude/.credentials.json\` は**在る**（サブスク認証。**API 課金の鍵ではない**）" >> "$OUT"
fi

# --- 作業ツリー -------------------------------------------------------------
{
  echo ""
  echo "### 作業ツリーの未コミット（**ファイル名だけ。中身は出さない**）"
  echo ""
  echo '```text'
  git -C "$REPO" status --porcelain 2>/dev/null | head -20
  echo '```'
  echo ""
  echo "- HEAD: \`$(git -C "$REPO" log --oneline -1 2>/dev/null | head -c 120)\`"
  echo "- **これが残っている間、ジョブは何もせずに終わる**（人の書きかけを消さないため）"
} >> "$OUT"

cat "$OUT"
