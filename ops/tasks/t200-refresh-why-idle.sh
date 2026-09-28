#!/bin/bash
# **記事リフレッシュが毎日 空振りしている理由を取る（t200）。読むだけ・LLM 不使用・$0。**
#
# ## 分かっていること（2026-09-28・一次情報）
#
#   ・`com.dailyhack.refresh-daily` は **載っている**（heartbeat の jobs に在る）
#   ・しかし **PR が 1 本も出ていない**（`refresh:` の PR は 5 月の別物 1 件だけ）
#   ・**`docs/refresh/` が main に存在しない**＝レポートが一度も残っていない
#   ・**`ops/data/refresh-state.json` は `{done:{}, total_usd:0}`** のまま
#   ・heartbeat の `clone` が **`behind: 215` / `dirty: 1`**。
#     9/27 23:05 と 9/28 13:40 で**まったく同じ値**＝動いていない
#
# ## 疑っているところ
#
# `scripts/refresh-daily.sh` の 133〜138 行。
#
#     DIRTY="$(git status --porcelain --untracked-files=no | head -20)"
#     if [ -n "$DIRTY" ]; then
#       echo "作業ツリーが汚れている。触らずに終わる:"; echo "$DIRTY"; exit 0
#     fi
#
# `ops-heartbeat.sh:337` の `dirty` も **`grep -vc '^??'` で未追跡を除いて**数えている。
# **同じ条件**なので、`dirty: 1` ならこのガードに毎日 当たっているはず。
# `ops-heartbeat.sh:162` も同じ理由で早送りを拒否するので、**クローンが 215 遅れ**も説明がつく。
#
# **だが「はず」で直さない。** 汚れているのが何かを見てから決める。
# 人が手元で書きかけているものなら、勝手に捨ててはいけない。
#
# ## 出すもの
#
#   ① 汚れている追跡ファイルの**名前と差分の大きさ**
#   ② 差分の先頭（**中身を全部は出さない**。公開リポジトリに載るため）
#   ③ クローンの位置（HEAD・origin/main からの遅れ）
#   ④ **refresh-daily のログの末尾**（「触らずに終わる」が出ていれば確定）
#
# **これは測るだけ。直すのは別タスク**（最上位ルール 15）。
#
# 180 秒 で打ち切る。LLM 不使用。**$0/回・$0/日・$0/月。**

set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t200-refresh-why-idle.md"
mkdir -p "$RDIR"

{
  echo "# 記事リフレッシュが空振りしている理由（t200・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

if [ ! -d "$REPO/.git" ]; then
  echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0
fi

# ── ① 汚れている追跡ファイル ────────────────────────────────
{
  echo "## ① 汚れている追跡ファイル"
  echo ""
  echo '```text'
  git -C "$REPO" status --porcelain --untracked-files=no | head -40
  echo '```'
  echo ""
} >> "$OUT"

N="$(git -C "$REPO" status --porcelain --untracked-files=no | grep -c . | head -1)"
case "$N" in ''|*[!0-9]*) N=0 ;; esac
echo "**追跡ファイルの汚れ: ${N} 件**" >> "$OUT"
echo "" >> "$OUT"

if [ "$N" = "0" ]; then
  {
    echo "> **汚れていない。** ガードは原因ではない。④ のログを見ること。"
    echo ""
  } >> "$OUT"
fi

# 未追跡も参考に出す（ガードは数えないが、状況の把握に要る）
U="$(git -C "$REPO" ls-files --others --exclude-standard | grep -c . | head -1)"
case "$U" in ''|*[!0-9]*) U=0 ;; esac
{
  echo "参考: 未追跡ファイルは **${U} 件**（ガードは数えない）"
  echo ""
  echo '```text'
  git -C "$REPO" ls-files --others --exclude-standard | head -15
  echo '```'
  echo ""
} >> "$OUT"

# ── ② 差分の大きさと先頭 ────────────────────────────────────
{
  echo "## ② 差分"
  echo ""
  echo '```text'
  git -C "$REPO" diff --stat | tail -20
  echo '```'
  echo ""
  echo "先頭 40 行だけ（**公開リポジトリに載るので全部は出さない**）:"
  echo ""
  echo '```diff'
  git -C "$REPO" diff | head -40
  echo '```'
  echo ""
} >> "$OUT"

# ── ③ クローンの位置 ────────────────────────────────────────
git -C "$REPO" fetch -q origin main 2>/dev/null || true
BEHIND="$(git -C "$REPO" rev-list --count HEAD..origin/main 2>/dev/null | head -1)"
case "$BEHIND" in ''|*[!0-9]*) BEHIND="?" ;; esac
{
  echo "## ③ クローンの位置"
  echo ""
  echo "- ブランチ: \`$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)\`"
  echo "- HEAD: \`$(git -C "$REPO" log --oneline -1 2>/dev/null | head -c 100)\`"
  echo "- **origin/main から ${BEHIND} コミット 遅れ**"
  echo ""
} >> "$OUT"

# ── ④ refresh-daily のログ ──────────────────────────────────
{
  echo "## ④ refresh-daily のログ"
  echo ""
} >> "$OUT"

FOUND=0
for d in "$HOME/.openclaw/workspace/logs" "$HOME/.openclaw/logs" "$HOME/logs" "/tmp"; do
  [ -d "$d" ] || continue
  # **`find -printf` は macOS に無い。** 名前で拾って `ls -t` に任せる
  for f in $(ls -t "$d" 2>/dev/null | grep -i refresh | head -4); do
    p="$d/$f"
    [ -f "$p" ] || continue
    FOUND=1
    sz="$(wc -c < "$p" | tr -d ' ')"
    {
      echo "### \`$p\`（${sz} bytes / 更新 $(date -r "$p" '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null)）"
      echo ""
      echo '```text'
      tail -40 "$p"
      echo '```'
      echo ""
    } >> "$OUT"
  done
done
[ "$FOUND" = "1" ] || {
  echo "⚠️ **ログが見つからない。** 探した場所:" >> "$OUT"
  echo '' >> "$OUT"
  echo '```text' >> "$OUT"
  for d in "$HOME/.openclaw/workspace/logs" "$HOME/.openclaw/logs" "$HOME/logs" "/tmp"; do
    echo "  $d $([ -d "$d" ] && echo '(在る)' || echo '(無い)')" >> "$OUT"
  done
  echo '```' >> "$OUT"
  echo '' >> "$OUT"
}

# ── ⑤ 起動スクリプトと plist ────────────────────────────────
{
  echo "## ⑤ 起動の口"
  echo ""
  B="$HOME/.openclaw/bin/refresh-daily-boot.sh"
  echo "- \`$B\`: $([ -f "$B" ] && echo "在る（$(wc -c < "$B" | tr -d ' ') bytes）" || echo '**無い**')"
  P="$HOME/Library/LaunchAgents/com.dailyhack.refresh-daily.plist"
  echo "- \`$P\`: $([ -f "$P" ] && echo '在る' || echo '**無い**')"
  echo "- \`launchctl print\`:"
  echo ""
  echo '```text'
  launchctl print "gui/$(id -u)/com.dailyhack.refresh-daily" 2>&1 \
    | grep -E 'state|runs|last exit code|program|path' | head -12
  echo '```'
  echo ""
} >> "$OUT"

{
  echo "---"
  echo ""
  echo "> **① が 1 件 以上で、④ に「作業ツリーが汚れている。触らずに終わる」が出ていれば確定。**"
  echo "> その場合、直すのは**汚れているファイルの扱いを決めてから**（人の書きかけかもしれない）。"
  echo ""
  echo "LLM 不使用。**\$0/回・\$0/日・\$0/月。**"
} >> "$OUT"

cat "$OUT"
