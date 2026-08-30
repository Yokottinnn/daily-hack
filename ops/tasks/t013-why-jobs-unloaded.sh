#!/bin/bash
# **なぜ 14 件のジョブが一斉に未ロードになったのかを調べる。読むだけ。**
#
# ## 事実
#
#   2026-08-30 14:44 UTC  20 件 稼働
#   2026-08-30 15:14 UTC   6 件 稼働   ← 30 分のあいだに 14 件 落ちた
#
# 残っていたのは `com.dailyhack.*` の 4 件と `ai.openclaw.tab-guard` だけ。
# **`ai.openclaw.*` がほぼ全滅している**という偏りがある。
#
# ## 何も直さない
#
# 利用者の判断は「**原因を特定してから戻す**」。返信・フォローの 3 件は `t012` で
# 戻したが、**残りは触らない。** このタスクは `launchctl` を一切変更しない。
#
# **当て推量で結論を書かない。** 取れなかったものは「取れなかった」と書く。
#
# ## 見るもの
#
#   1. 再起動・ログアウトがあったか（あれば RunAtLoad 依存のジョブが落ちる）
#   2. plist が書き換えられていないか（mtime）
#   3. **誰かが bootout / unload を呼んでいないか**（workspace のスクリプトを grep）
#   4. launchd 自身のログ
#   5. 落ちたものと残ったものの違い
#
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/why-jobs-unloaded.md"
UID_N="$(id -u)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# なぜ 14 件が一斉に未ロードになったのか（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> **読むだけ。\`launchctl\` は一切変更しない。**"
echo "> 落ちた時間帯は **2026-08-30 14:44〜15:14 UTC（23:44〜00:14 JST）**。"

echo
echo "## 1. 再起動・ログアウトがあったか"
echo
echo '```'
echo "uptime: $(uptime 2>/dev/null)"
echo "boottime: $(sysctl -n kern.boottime 2>/dev/null)"
echo "--- last reboot ---"
last reboot 2>/dev/null | head -3
echo "--- 現在のログインセッション開始 ---"
who -b 2>/dev/null || true
echo '```'
echo
echo "**再起動していれば**、`RunAtLoad` を持たない／`launchctl load` で手動投入されただけの"
echo "ジョブは落ちる。そこが分かれ目になる。"

echo
echo "## 2. plist が書き換えられていないか（mtime の新しい順）"
echo
echo '```'
ls -lt "$LA"/*.plist 2>/dev/null | head -20 | awk '{print $6, $7, $8, $9}' | sed "s#$LA/##"
echo '```'
echo
echo "**23:00〜00:30 JST 付近に更新されたものがあれば、書き換えが疑われる。**"

echo
echo "## 3. bootout / unload を呼んでいるものを探す（**これがいちばん効く**）"
echo
echo "### workspace のスクリプト"
echo '```'
grep -rlnE 'launchctl (bootout|unload|remove)' "$W/scripts" 2>/dev/null | head -15 | sed "s#$W/#workspace/#"
echo '```'
echo
echo "### 実際の行（先頭 20 件）"
echo '```'
grep -rnE 'launchctl (bootout|unload|remove)' "$W/scripts" 2>/dev/null \
  | head -20 | cut -c1-160 | sed "s#$W/#workspace/#" | mask
echo '```'
echo
echo "### リポジトリ側（ops/tasks と scripts）"
echo '```'
grep -rnE 'launchctl (bootout|unload|remove)' "${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}/ops" \
  "${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}/scripts" 2>/dev/null \
  | grep -vE 't008-install-poller|t010-fix-poller|t003-heartbeat' \
  | head -15 | cut -c1-160 | mask
echo '```'
echo
echo "> \`t008\` / \`t010\` は \`ops-poller\` だけを bootout する（自分で入れたもの）。"
echo "> **それ以外に \`ai.openclaw.*\` を落としうるものがあるかを見る。**"

echo
echo "## 4. その時間帯に走ったジョブのログ"
echo
echo '```'
for f in "$HOME/.openclaw/logs"/*.log "$W/logs"/*.log; do
  [ -f "$f" ] || continue
  m="$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
  case "$m" in
    "08-30 23:"*|"08-31 00:"*) echo "$m  $(basename "$f")" ;;
  esac
done | sort | head -20
echo '```'
echo
echo "**この時間帯に書き込まれたログが、落ちた原因に近い。**"

echo
echo "## 5. launchd 自身のログ（取れれば）"
echo
echo '```'
log show --last 3h --predicate 'process == "launchd"' --style compact 2>/dev/null \
  | grep -aiE 'openclaw|bootout|unload|removed|exited' | head -20 | mask \
  || echo "(log show が使えない／権限が無い)"
echo '```'

echo
echo "## 6. 落ちたものと残ったものの違い"
echo
echo "### いま載っているもの"
echo '```'
launchctl list 2>/dev/null | awk 'NR==1 || /dailyhack|openclaw/ {print}' | head -20 | mask
echo '```'
echo
echo "### 未ロードのものの RunAtLoad / KeepAlive"
echo
echo "| ラベル | RunAtLoad | KeepAlive | StartInterval |"
echo "| --- | --- | --- | --- |"
n=0
for f in "$LA"/ai.openclaw.*.plist; do
  [ -f "$f" ] || continue
  b="$(basename "$f" .plist)"
  launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$b" && continue
  ral="$(plutil -extract RunAtLoad raw -o - "$f" 2>/dev/null || echo '-')"
  ka="$(plutil -extract KeepAlive raw -o - "$f" 2>/dev/null || echo '-')"
  si="$(plutil -extract StartInterval raw -o - "$f" 2>/dev/null || echo '-')"
  echo "| \`$b\` | ${ral:--} | ${ka:--} | ${si:--} |"
  n=$((n+1)); [ "$n" -ge 20 ] && break
done
echo
echo "> **\`plutil -extract\` には \`-o -\` を付けてある。** 付けないと plist を壊す"
echo "> （2026-08-22 に 56 個 破壊した）。"

echo
echo "## 7. 分かったこと / 分からなかったこと"
echo
echo "**この節は人が読んで埋める。** タスクは事実を並べるだけで、結論は書かない。"
echo "上の 1〜6 から、次のどれに当たるかを判断すること。"
echo
echo "- (a) 再起動／ログアウトで落ちた → 恒久ロード（\`bootstrap\` 済み）にすれば直る"
echo "- (b) 何かが \`bootout\` を呼んだ → 3 章で犯人が挙がっているはず"
echo "- (c) plist が壊れた／書き換えられた → 2 章の mtime に痕跡が出る"
echo "- (d) 判断できない → **戻さない。** さらに証拠を集める"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "原因調査を出した（変更なし）/ $(basename "$OUT")"
