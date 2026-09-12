#!/bin/bash
# **「勝手にブラウザが消される」の犯人を、証拠で特定する。費用 $0。読むだけ。**
#
# ## 症状（利用者の報告・2026-09-08）
#
#   > 勝手にブラウザが消されてしまう事象が直近で起きている
#
# ## 前科がある
#
# 2026-08-30 23:57:03 JST に **Jordan のタブが 19 → 1 枚**になった（`t014` / `t015`）。
# **再起動ではない**（当時 uptime 20 日）。**何かが能動的に落とした。**
#
# そのとき `tab-guard.js` は「一括破壊」を検知して自動化を全停止した。
# **つまり tab-guard は「反応した側」であって、タブを消した側とは限らない。**
# 当時、消した本体は特定できていない。**今度は そこを詰める。**
#
# ## 容疑者（先入観を持たず、全部 出す）
#
#   1. **`ensure-chrome.sh`** — 投稿・返信ジョブが毎回 冒頭で呼ぶ。
#      「不健全」と判断したら Chrome を kill して再起動する作りなら、
#      **1 日に何度も走るので、いちばん頻度が高い**
#   2. **`ai.openclaw.chrome-cdp-heal`** — 名前のとおり CDP を「治す」ジョブ。
#      治し方が「Chrome を殺して起動し直す」なら、これも本体になりうる
#   3. **`tab-guard.js`** — 検知側とされているが、**自分でタブを閉じる分岐**があるかもしれない
#   4. **`lib/work-window.js` の `openWorkTab`** — 作業用タブを開く／閉じる係
#   5. **`connectOverCDP` した接続で `browser.close()` を呼んでいるスクリプト**
#      → これは **Chrome 本体を落とす**。Playwright でいちばん多い事故
#   6. OS の再起動・ログアウト（これなら「勝手に」ではない。除外のために確認する）
#
# ## 重要な補足
#
# `ensure-chrome.sh` には **cookie がディスクに永続化できておらず、
# 再起動＝即ログアウト**という但し書きがある（`t050`）。
# **Chrome が落ちること自体が、ログイン切れと投稿失敗に直結する。**
#
# ## やらないこと
#
# **Chrome を触らない。タブを開かない・閉じない。ジョブを触らない。**
# **投稿・返信・フォロー・アンフォローをしない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/who-kills-the-browser.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 誰がブラウザを消しているのか"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 2026-08-30 にも **タブが 19 → 1 枚**になっている（\`t014\`）。"
echo "> そのときは \`tab-guard\` が**反応した**ことまでしか分からなかった。"
echo "> **今回は「消した本体」を特定する。**"
echo
echo "**何も触っていない。読むだけ（\$0）。**"

# ────────────────────────────────────────────────
echo
echo "## 0. まず除外する: OS の再起動かどうか"
echo
echo '```'
echo "  uptime: $(uptime 2>/dev/null | sed 's/^ *//')"
echo "  最後の起動: $(sysctl -n kern.boottime 2>/dev/null)"
echo
echo "  --- 直近の再起動・シャットダウン履歴 ---"
last reboot 2>/dev/null | head -5 | sed 's/^/    /'
last shutdown 2>/dev/null | head -3 | sed 's/^/    /'
echo '```'
echo
echo "**uptime が長ければ、OS の再起動ではない＝何かが能動的に落としている。**"

# ────────────────────────────────────────────────
echo
echo "## 1. Chrome は「いつから」動いているか"
echo
echo "**これが決定打になる。** 起動時刻の直前に走ったジョブが犯人。"
echo
echo '```'
echo "  --- Chrome 本体プロセス（起動時刻つき） ---"
ps -eo pid,ppid,lstart,etime,comm 2>/dev/null \
  | grep -i 'Google Chrome\|Chromium' | grep -v ' grep' | head -6 | sed 's/^/    /'
echo
echo "  --- CDP 付きで起動されたものだけ（--remote-debugging-port） ---"
ps -eo pid,lstart,etime,args 2>/dev/null | grep -- '--remote-debugging-port' \
  | grep -v ' grep' | head -4 | cut -c1-220 | sed 's/^/    /' | clean
echo
echo "  --- 親プロセス（誰が起動したか） ---"
CPID="$(pgrep -f 'Google Chrome.*--remote-debugging-port' 2>/dev/null | head -1)"
if [ -n "$CPID" ]; then
  PP="$(ps -o ppid= -p "$CPID" 2>/dev/null | tr -d ' ')"
  echo "    Chrome pid=$CPID / 親 pid=$PP"
  ps -o pid,lstart,args -p "$PP" 2>/dev/null | tail -1 | cut -c1-200 | sed 's/^/    /' | clean
else
  echo "    **CDP 付きの Chrome が見つからない（いま落ちている可能性）**"
fi
echo '```'
echo
echo "**etime が短ければ、最近 起動し直されている。**"

# ────────────────────────────────────────────────
echo
echo "## 2. \`ensure-chrome.sh\` は Chrome を殺すのか（**全文**）"
echo
echo "投稿・返信ジョブが**毎回 冒頭で呼ぶ**。頻度がいちばん高い容疑者。"
echo
echo '```bash'
if [ -f "$S/ensure-chrome.sh" ]; then
  cat -n "$S/ensure-chrome.sh" 2>/dev/null | clean
else
  echo "  **無い: $S/ensure-chrome.sh**"
fi
echo '```'

# ────────────────────────────────────────────────
echo
echo "## 3. \`chrome-cdp-heal\` の中身とログ"
echo
echo "「治す」方法が「殺して起動し直す」なら、これも本体。"
echo
echo "### 3-a. plist（何を、いつ走らせるか）"
echo '```'
P="$HOME/Library/LaunchAgents/ai.openclaw.chrome-cdp-heal.plist"
if [ -f "$P" ]; then
  plutil -p "$P" 2>/dev/null | grep -iE 'Program|Arguments|Interval|Calendar|Hour|Minute|=>' \
    | head -20 | cut -c1-190 | sed 's/^/  /' | clean
else
  echo "  plist が無い: $P"
fi
echo '```'
echo
echo "### 3-b. 実体スクリプト（**kill / pkill / launch を探す**）"
echo '```bash'
for f in "$S/chrome-cdp-heal.sh" "$S/chrome-cdp-heal.js" "$S/cdp-heal.sh" "$S/cdp-heal.js"; do
  [ -f "$f" ] || continue
  echo "  # ===== $(basename "$f") ====="
  grep -nE 'kill|pkill|killall|quit|open -a|launch|restart|spawn|exec' "$f" 2>/dev/null \
    | head -20 | cut -c1-170 | sed 's/^/  /' | clean
done
echo '```'
echo
echo "### 3-c. ログ（**いつ発火したか**）"
echo '```'
for f in "$W"/logs/chrome-cdp-heal.log "$W"/logs/cdp-heal.log; do
  [ -f "$f" ] || continue
  echo "  [$(basename "$f")]  更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  echo "  --- 日別の発火回数（直近 10 日） ---"
  grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" 2>/dev/null | sort | uniq -c | tail -10 | sed 's/^/    /'
  echo "  --- 直近 30 行 ---"
  tail -30 "$f" 2>/dev/null | cut -c1-190 | sed 's/^/    /' | clean
done
echo '```'

# ────────────────────────────────────────────────
echo
echo "## 4. \`tab-guard.js\` — 検知側か、消した側か"
echo
echo "### 4-a. **自分でタブや Chrome を閉じる分岐があるか**"
echo '```javascript'
if [ -f "$S/tab-guard.js" ]; then
  grep -nE '\.close\(|kill|pkill|quit|closeTab|browser\.close|context\.close|unload' \
    "$S/tab-guard.js" 2>/dev/null | head -20 | cut -c1-170 | sed 's/^/  /' | clean
else
  echo "  **無い: $S/tab-guard.js**"
fi
echo '```'
echo
echo "### 4-b. しきい値と発火条件"
echo '```javascript'
grep -nE 'MAX|MIN|THRESHOLD|LIMIT|tabs?\.length|haltAutomation|一括|>\s*[0-9]{1,3}|<\s*[0-9]{1,3}' \
  "$S/tab-guard.js" 2>/dev/null | head -18 | cut -c1-170 | sed 's/^/  /' | clean
echo '```'
echo
echo "### 4-c. ログ（**タブ数の推移**）"
echo '```'
for f in "$W"/logs/tab-guard.log "$W"/logs/tabguard.log; do
  [ -f "$f" ] || continue
  echo "  [$(basename "$f")]  更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  echo "  --- タブ数の記録・停止イベント（直近 40 行） ---"
  grep -nE 'タブ|tabs|halt|停止|🚨|破壊' "$f" 2>/dev/null | tail -40 | cut -c1-190 | sed 's/^/    /' | clean
done
echo '```'

# ────────────────────────────────────────────────
echo
echo "## 5. \`browser.close()\` を呼んでいるスクリプトを全部 洗う"
echo
echo "**\`connectOverCDP\` した接続で \`browser.close()\` を呼ぶと、Chrome 本体が落ちる。**"
echo "Playwright でいちばん多い事故。**該当があれば、それが犯人。**"
echo
echo '```javascript'
grep -rnE 'browser\.close\(|b\.close\(|\.close\(\)\s*;?\s*//.*browser' "$S" 2>/dev/null \
  | grep -v node_modules | head -25 | cut -c1-170 | clean
echo "  ---（上が空なら browser.close() は無い）---"
echo
echo "  # connectOverCDP を使っているファイル一覧"
grep -rln 'connectOverCDP' "$S" 2>/dev/null | grep -v node_modules | head -20 | sed 's/^/  /'
echo '```'

# ────────────────────────────────────────────────
echo
echo "## 6. \`work-window.js\` はタブをどう扱うか"
echo
echo '```javascript'
F="$S/lib/work-window.js"
if [ -f "$F" ]; then
  grep -nE '\.close\(|newPage|openWorkTab|bringToFront|dispose|cleanup' "$F" 2>/dev/null \
    | head -20 | cut -c1-170 | sed 's/^/  /' | clean
else
  echo "  **無い: $F**"
fi
echo '```'

# ────────────────────────────────────────────────
echo
echo "## 7. 時刻の突き合わせ（**Chrome 起動の直前に何が走ったか**）"
echo
echo "Chrome の起動時刻の前後 10 分に書かれたログ行を集める。"
echo
echo '```'
CSTART="$(ps -eo lstart,args 2>/dev/null | grep -- '--remote-debugging-port' | grep -v ' grep' \
          | head -1 | awk '{print $1,$2,$3,$4,$5}')"
echo "  Chrome の起動時刻: ${CSTART:-(取得できない)}"
echo
if [ -n "$CSTART" ]; then
  CDAY="$(date -j -f '%a %b %e %T %Y' "$CSTART" '+%Y-%m-%d' 2>/dev/null || echo '')"
  CHM="$(date -j -f '%a %b %e %T %Y' "$CSTART" '+%H:%M' 2>/dev/null || echo '')"
  echo "  → $CDAY $CHM 前後のログ行:"
  if [ -n "$CDAY" ]; then
    for f in "$W"/logs/*.log; do
      [ -f "$f" ] || continue
      hits="$(grep -h "$CDAY" "$f" 2>/dev/null | grep -cE "$CHM|$(date -j -v-1M -f '%H:%M' "$CHM" '+%H:%M' 2>/dev/null)" || true)"
      [ "${hits:-0}" -gt 0 ] 2>/dev/null && printf '    %-34s %s 行\n' "$(basename "$f")" "$hits"
    done
  fi
fi
echo '```'

echo
echo "### 直近 24 時間に更新されたログ（**動いていたものが分かる**）"
echo
echo '```'
find "$W/logs" -name '*.log' -mtime -1 2>/dev/null | while read -r f; do
  printf '  %-38s %s\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
done | sort -k2 | tail -25
echo '```'

echo
echo "---"
echo
echo "**Chrome を触っていない。タブも開いていない。ジョブも触っていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
UP="$(grep -m1 -oE 'uptime:.*' "$OUT" 2>/dev/null | cut -c1-60 || echo '')"
BC="$(grep -c 'browser\.close(' "$OUT" 2>/dev/null || echo 0)"
echo "**$(date '+%H:%M') ブラウザ消失の証拠を集めた（変更なし・\$0）** / $UP / browser.close の該当 $BC 件 / $(basename "$OUT")"
