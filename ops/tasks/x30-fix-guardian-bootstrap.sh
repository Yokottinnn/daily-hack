#!/bin/bash
# **番人の「戻した」が嘘だった。launchctl の使い方を直す。費用 $0。**
#
# ## x28 の実測（2026-09-12 22:21）
#
#   番人のログ : [22:21:20] reloaded hashtag-follow   ← load -w が rc=0
#   実際の結果 : **未ロード** hashtag-follow          ← 載っていない
#                ロード済み: 0 / 8
#
# **`launchctl load -w` は成功を返すのに、実際には載らない。**
#
# macOS の新しい launchd では `load` / `unload` は **deprecated** で、
# 黙って何もしないことがある。正しいのは
#
#   launchctl bootstrap gui/$(id -u) <plist>
#   launchctl bootout   gui/$(id -u)/<label>
#
# Slack の復旧案内にもこう書いてあった。**そこに答えがあった。**
#
#   ssh home-mac 'launchctl bootstrap gui/501 ~/Library/LaunchAgents/com.dailyhack.openclaw.listener.plist'
#
# ## もう 1 つの誤判定
#
# 鍵の判定に `pgrep -f 'Google Chrome'` を使っていたが、これは
# **利用者が普段使っている Chrome も拾う。** 見るべきは
# **CDP 付きの自動化専用 Chrome** だけ。
#
#   pgrep -f 'remote-debugging-port'     ← これで絞る
#
# 実際 x28 は「chrome running」と判定して鍵を残したが、
# 同じレポートの CDP 欄は `Chrome not running` だった。**矛盾していた。**
#
# ## 鍵を作っているコードは存在しない（x29 の結論）
#
# `touch /tmp/x-login-in-progress` の出現は 2 箇所とも
# **Slack に出す「手順の案内文」の文字列**であって、実行コードではない。
#
#   ensure-x-login.js:248  lines.push("先に `ssh home-mac 'touch ...'` (cron 抑止) → ...")
#   lib/slack-notify.js:18 // { label: "B", description: "... command: "先に touch ..." }
#
# **＝ 人が手で作った残骸。** 外せば戻らない。
#
# ## この タスクがやること
#
#   1. 番人を **bootstrap 方式**に書き換える（load はフォールバックに残す）
#   2. **ロードした「つもり」を検証する** — 載っていなければ失敗として扱う
#   3. 鍵の判定を **CDP 付き Chrome** に絞る
#   4. その場で 1 回 走らせて、**実際に何本 載ったか**を出す
#
# **Chrome を kill しない。投稿しない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-guardian-bootstrap.md"
GUARD="$S/x-loop-guardian.sh"
LABEL="ai.openclaw.x-loop-guardian"
PLIST="$LA/$LABEL.plist"
STAMP="$(date '+%Y%m%d-%H%M%S')"
UID_NUM="$(id -u)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 番人の「戻した」は嘘だった — launchctl の使い方を直す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`launchctl load -w\` が **rc=0 を返すのに載らない。**"
echo "> 正しくは \`launchctl bootstrap gui/${UID_NUM} <plist>\`。"
echo "> **Slack の復旧案内に最初から書いてあった。**"

# ═══════════ 1. まず両方式を実地で比べる ═══════════
echo
echo "## 1. \`load\` と \`bootstrap\` を実地で比べる"
echo
echo "**1 本で試す。** どちらが実際に載るかを見る。"
echo
echo '```'
T="comment-warmup"
P="$LA/ai.openclaw.$T.plist"
if [ ! -f "$P" ]; then
  echo "  **plist が無い: $P**"
else
  echo "  対象: $T"
  echo "  いま: $(launchctl list 2>/dev/null | grep -cF "ai.openclaw.$T") 本"
  echo
  echo "  --- (a) launchctl load -w ---"
  launchctl load -w "$P" 2>&1 | head -3 | sed 's/^/    /'
  echo "    rc=$? / 載ったか: $(launchctl list 2>/dev/null | grep -cF "ai.openclaw.$T") 本"
  echo
  echo "  --- (b) launchctl bootstrap gui/${UID_NUM} ---"
  launchctl bootstrap "gui/${UID_NUM}" "$P" 2>&1 | head -3 | sed 's/^/    /'
  echo "    rc=$? / 載ったか: $(launchctl list 2>/dev/null | grep -cF "ai.openclaw.$T") 本"
fi
echo '```'

# ═══════════ 2. 番人を書き換える ═══════════
echo
echo "## 2. 番人を書き換える"
echo
echo '```'
if [ ! -f "$GUARD" ]; then
  echo "  **番人が無い: $GUARD** — x28 が失敗している。ここで終わる。"
else
  cp -p "$GUARD" "$GUARD.bak-$STAMP" && echo "  退避: $(basename "$GUARD").bak-$STAMP"

  # --- A: ロードを bootstrap 方式＋検証つきに ---
  python3 - "$GUARD" "$UID_NUM" <<'PY'
import re, sys
p, uid = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()

OLD = '''  if launchctl load -w "$P" 2>/dev/null; then
    log "reloaded $j"; FIXED=$((FIXED+1))
  else
    PROBLEMS="$PROBLEMS load-failed:$j"
  fi'''

NEW = '''  # **load -w は rc=0 を返すのに載らないことがある**（2026-09-12 実測）。
  # macOS の新しい launchd では load/unload は deprecated。bootstrap を先に使う。
  # **そして「載ったつもり」を信じない。必ず launchctl list で確かめる。**
  launchctl bootstrap "gui/$UID_NUM" "$P" >/dev/null 2>&1 \\
    || launchctl load -w "$P" >/dev/null 2>&1 || true
  if launchctl list 2>/dev/null | grep -qF "$lbl"; then
    log "reloaded $j"; FIXED=$((FIXED+1))
  else
    PROBLEMS="$PROBLEMS load-failed:$j"     # **rc ではなく、実際に載ったかで判定**
  fi'''

assert OLD in s, "A: 置換元が見つからない"
s = s.replace(OLD, NEW)

# UID を頭で定義
s = s.replace('LOCK=/tmp/x-login-in-progress',
              'LOCK=/tmp/x-login-in-progress\nUID_NUM="$(id -u)"')

# --- B: 鍵の判定を CDP 付き Chrome に絞る ---
OLD2 = """  pgrep -f 'Google Chrome' >/dev/null 2>&1 && CHROME_UP=1"""
NEW2 = """  # **利用者の普段使いの Chrome を数えない。** 自動化専用（CDP 付き）だけを見る。
  # 2026-09-12、'Google Chrome' で拾って「chrome running」と誤判定し、
  # 同じレポートの CDP 欄は "Chrome not running" だった（矛盾していた）。
  pgrep -f 'remote-debugging-port' >/dev/null 2>&1 && CHROME_UP=1"""
assert OLD2 in s, "B: 置換元が見つからない"
s = s.replace(OLD2, NEW2)

open(p, "w", encoding="utf-8").write(s)
print("  bootstrap 方式＋載ったか検証＋CDP 付き Chrome 判定 に書き換えた")
PY

  if bash -n "$GUARD" 2>&1 | clean; then
    echo "  bash -n: OK"
  else
    echo "  **構文エラー。戻す。**"
    cp -p "$GUARD.bak-$STAMP" "$GUARD"
  fi
fi
echo '```'

echo
echo "### 入った差分"
echo
echo '```diff'
diff -u "$GUARD.bak-$STAMP" "$GUARD" 2>/dev/null | head -50 | clean
echo '```'

# ═══════════ 3. 番人自身を bootstrap で載せ直す ═══════════
echo
echo "## 3. 番人自身を \`bootstrap\` で載せ直す"
echo
echo "\`x28\` は \`**ロードした**\` と出したが \`番人: 0 本\` だった。**同じ罠。**"
echo
echo '```'
if [ -f "$PLIST" ]; then
  launchctl bootout "gui/${UID_NUM}/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/${UID_NUM}" "$PLIST" 2>&1 | head -3 | sed 's/^/  /'
  echo "  載ったか: $(launchctl list 2>/dev/null | grep -cF "$LABEL") 本"
else
  echo "  **番人の plist が無い: $PLIST**"
fi
echo '```'

# ═══════════ 4. 鍵を外す ═══════════
echo
echo "## 4. 鍵を外す（**作っているコードは存在しない**）"
echo
echo "\`x29\` の結論: \`touch\` の出現は 2 箇所とも **Slack の案内文の文字列**。"
echo "実行コードではない。**＝ 人が手で作った残骸。外せば戻らない。**"
echo
echo '```'
LOCK=/tmp/x-login-in-progress
if [ -f "$LOCK" ]; then
  CDPCHROME=0
  pgrep -f 'remote-debugging-port' >/dev/null 2>&1 && CDPCHROME=1
  echo "  鍵: 有る / CDP 付き Chrome: $([ "$CDPCHROME" = 1 ] && echo '動いている' || echo '**動いていない**')"
  if [ "$CDPCHROME" = "0" ]; then
    mv "$LOCK" "$LOCK.parked-$STAMP" 2>/dev/null \
      && echo "  → **退避した**（CDP 付き Chrome が無いのに鍵がある＝矛盾）" \
      || echo "  → 退避できない"
  else
    echo "  → 手動ログイン中の可能性。触らない。"
  fi
else
  echo "  鍵: 無い（正常）"
fi
echo '```'

# ═══════════ 5. その場で番人を 1 回 ═══════════
echo
echo "## 5. 番人をその場で 1 回 走らせる"
echo
echo '```'
[ -f "$GUARD" ] && bash "$GUARD" 2>&1 | tail -8 | sed 's/^/  /' | clean
echo "  --- ログ末尾 ---"
tail -12 "$W/logs/x-loop-guardian.log" 2>/dev/null | sed 's/^/    /' | clean
echo '```'

# ═══════════ 6. 結果 ═══════════
echo
echo "## 6. 実際に何本 載ったか（**rc ではなく実測**）"
echo
echo '```'
EXPECT="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"
OKN=0
for j in $EXPECT; do
  line="$(launchctl list 2>/dev/null | grep -F "ai.openclaw.$j" || true)"
  if [ -z "$line" ]; then printf '  **未ロード** %-36s\n' "$j"
  else printf '%s\n' "$line" | awk -v j="$j" '{printf "  ロード      %-36s rc=%s\n", j, $2}'; OKN=$((OKN+1)); fi
done
echo
echo "  **ロード済み: ${OKN} / 8**"
echo "  番人: $(launchctl list 2>/dev/null | grep -cF "$LABEL") 本"
echo
echo "  --- CDP ---"
[ -f "$S/cdp-health.js" ] && ( cd "$S" && /usr/local/bin/node cdp-health.js ) 2>&1 | head -c 200 | sed 's/^/  /' | clean
echo '```'

echo
echo "---"
echo
echo "## 今回 学んだこと"
echo
echo "| 誤り | 正しくは |"
echo "| --- | --- |"
echo "| \`launchctl load -w\` の rc を信じた | **\`bootstrap\` を使い、\`launchctl list\` で載ったか確かめる** |"
echo "| \`pgrep -f 'Google Chrome'\` で判定 | **\`remote-debugging-port\` で自動化専用だけ見る** |"
echo "| 「戻した」とログに書いた | **書く前に確かめる。rc は証拠にならない** |"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| 番人（15 分ごと・96 回/日・LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（**実測** 9/8=5 件・9/9=3 件） | \$0.003 | \$0.009〜0.015 | 約 \$0.27〜0.45 |"
echo
echo "**Chrome を kill していない。投稿もしていない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
N="$(grep -m1 -oE '\*\*ロード済み: [0-9]+ / 8\*\*' "$OUT" 2>/dev/null || echo 'ロード数 不明')"
echo "**$(date '+%H:%M') launchctl を bootstrap に直した（\$0）** / $N / $(basename "$OUT")"
