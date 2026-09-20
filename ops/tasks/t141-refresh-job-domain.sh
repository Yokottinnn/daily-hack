#!/bin/bash
# **`launchctl list` に出ないだけで、実は載っているのではないか（t141）。**
#
# t140 の結果:
#
#   1 回目: rc=0                      ← **載った**
#   2 回目: rc=5 Input/output error   ← **「もう載っている」ときの出方**
#   3 回目: rc=5 同上
#   launchctl list: 載っていない
#
# **`launchctl list` は呼び出し側のドメインしか見ない。**
# `bootstrap` は `gui/$UID` に入れたが、ops のジョブが `user/$UID`（Background）で
# 動いていれば、**載っているのに list には出ない。**
#
# ここでは**ドメインを名指しして** `launchctl print` で確かめる。
# **`print` が通れば載っている。** これが `list` より強い証拠（最上位ルール 13 の更新）。
#
# 見つからなければ、**ops-heartbeat が居るドメインに入れ直す。**
#
# **このタスクに API 課金は無い。**

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t141-refresh-job-domain.md"
mkdir -p "$RDIR"
LABEL="com.dailyhack.refresh-daily"
REF="com.dailyhack.ops-heartbeat"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
U="$(id -u)"

state_of() {  # $1=ドメイン $2=ラベル
  launchctl print "$1/$2" 2>/dev/null | awk '/^[[:space:]]*state = /{print $3; exit}'
}

{
  echo "# ジョブはどのドメインに居るのか（t141）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "## 1) ドメインを名指しして見る"
  echo ""
  echo "| ラベル | \`gui/$U\` | \`user/$U\` | \`launchctl list\` |"
  echo "| --- | --- | --- | --- |"
} > "$OUT"

for L in "$LABEL" "$REF"; do
  G="$(state_of "gui/$U" "$L")"; [ -n "$G" ] || G="—"
  S="$(state_of "user/$U" "$L")"; [ -n "$S" ] || S="—"
  if launchctl list | grep -qF "$L"; then LS="出る"; else LS="**出ない**"; fi
  echo "| \`$L\` | $G | $S | $LS |" >> "$OUT"
done

{
  echo ""
  echo "（\`—\` は そのドメインに**居ない**。値が出ていれば **\`print\` が通った＝載っている**）"
  echo ""
  echo "## 2) 足りないほうに入れ直す"
  echo ""
} >> "$OUT"

# **ops-heartbeat が居るドメインを正とする。** そこで動いている実績があるので
TARGET=""
for D in "gui/$U" "user/$U"; do
  [ -n "$(state_of "$D" "$REF")" ] && { TARGET="$D"; break; }
done
if [ -z "$TARGET" ]; then TARGET="gui/$U"; fi
echo "- 正とするドメイン: \`$TARGET\`（\`$REF\` が居るほう）" >> "$OUT"

if [ -n "$(state_of "$TARGET" "$LABEL")" ]; then
  echo "- **すでにそこに居る。** 入れ直さない" >> "$OUT"
else
  launchctl enable "$TARGET/$LABEL" >/dev/null 2>&1 || true
  BS_OUT="$(launchctl bootstrap "$TARGET" "$PLIST" 2>&1)"; BS_RC=$?
  echo "- \`bootstrap $TARGET\`: rc=$BS_RC ${BS_OUT:+— \`$(echo "$BS_OUT" | head -2 | tr '\n' ' ' | head -c 200)\`}" >> "$OUT"
fi

ST="$(state_of "$TARGET" "$LABEL")"
{
  echo ""
  if [ -n "$ST" ]; then
    echo "### ✅ \`launchctl print $TARGET/$LABEL\` が通る（state = **$ST**）← **これが証拠**"
    echo ""
    echo '```text'
    launchctl print "$TARGET/$LABEL" 2>/dev/null \
      | grep -E 'state =|program =|path =|runs =|last exit code' | head -8
    echo '```'
  else
    echo "### ⚠️ \`print\` も通らない。**本当に載っていない**"
  fi
  echo ""
  echo "## 3) 次の実行予定"
  echo ""
  echo "- **毎日 05:30。** \`RunAtLoad\` は false なので、いま走ることはない"
  echo "- 鍵が無いままなら**何もせずに終わる**（t140 の通り）"
} >> "$OUT"

cat "$OUT"
