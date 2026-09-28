#!/bin/bash
# **アンフォローが 4 秒 で終わる理由を読む。読むだけ。費用 $0。最優先。**
#
# ## 何が起きたか
#
# `x189` は **rc=0 / 4 秒** で終わり、**1 件も外していない。**
#
#   --- 走査と判定 ---
#   （空）
#   外した記録: 17 → 17 件（差 0）
#
# **一覧の取得だけで 60 秒 かかる。4 秒 は起動直後に抜けた印。**
#
# ## 理由が見えないのは、私のレポートの絞り込みが原因
#
# `x189` の `grep` は**成功時の語だけ**を拾っていた。
#
#   覚えている未フォロー|走査 .* から|フォロー中:|片思い:|相互:|…
#
# **早期に抜けるときの語が 1 つも入っていない。**
#
#   「CDP に繋がらない」「context が無い」
#   「**ログインが切れている。何もしない。**」
#   「**自分のハンドルが読めない。何もしない。**」
#   「/home を開けない」「0 件しか読めない」
#
# **どれも `process.exit(0)` なので rc も 0。** だから何も分からなかった。
#
# ## 何を見るか
#
#   ① 定期実行のログ `logs/follow-balance.log`（**11:45 と 18:45 が走ったはず**）
#   ② ジョブが載っているか（`launchctl print`）
#   ③ **いま手で 1 回 走らせて、抜ける理由をそのまま出す**（外さない・DRY）
#   ④ Chrome / CDP が生きているか
#   ⑤ 状態ファイルと、覚えた未フォローの件数
#
# ## やらないこと
#
# **外さない（DRY）。設定も plist も触らない。LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
UID_N="$(id -u)"
LABEL="ai.openclaw.follow-balance"
TARGET="$S/follow-balance.js"
ST="$D/follow-balance-state.json"
NF="$D/follow-balance-notfollowing.json"
OUT="${OPS_REPORT_DIR:-/tmp}/why-unfollow-stopped.md"
RUNLOG="$W/.x190-run.log"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    local victims p
    victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

jn() {
  node -e '
    const fs = require("fs");
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { process.stdout.write("0"); process.exit(0); }
    process.stdout.write(String(Array.isArray(j) ? j.length : Object.keys(j || {}).length));
  ' "$1" 2>/dev/null
}

{
echo "# アンフォローが 4 秒 で終わる理由（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **外さない（DRY）。** 設定も plist も触らない。"
echo "> **今回は早期に抜けるときの語も全部 拾う**（\`x189\` はそれを入れ忘れて何も見えなかった）。"

echo
echo "## 1. 定期実行は走ったか（11:45 / 18:45）"
echo
echo '```'
F="$L/follow-balance.log"
if [ ! -f "$F" ]; then
  echo "  **follow-balance.log が無い。定期実行が一度も走っていない可能性。**"
  ls -1 "$L" 2>/dev/null | grep -i follow | sed 's/^/    /' || true
else
  printf '  更新 %s / %s bytes\n\n' "$(stat -f '%Y-%m-%d %H:%M:%S' "$F" 2>/dev/null || stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$F" 2>/dev/null)" "$(wc -c < "$F" | tr -d ' ')"
  echo "  --- 今日の start 行 ---"
  grep -a "$(date '+%Y-%m-%d')" "$F" 2>/dev/null | grep -a 'follow-balance start' | tr -d '\000' | cut -c1-190 | clean | sed 's/^/    /'
  echo
  echo "  --- 末尾 30 行（**そのまま**）---"
  tail -30 "$F" 2>/dev/null | tr -d '\000' | cut -c1-200 | clean | sed 's/^/    /'
fi
echo '```'

echo
echo "## 2. ジョブは載っているか"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
    | grep -E '^[[:space:]]+(state|runs|path|last exit code) ' | sed 's/^/    /'
  echo "    → **載っている**"
else
  echo "    → **載っていない**"
fi
echo '```'

echo
echo "## 3. Chrome と CDP は生きているか"
echo
echo '```'
if command -v lsof >/dev/null 2>&1; then
  if lsof -nP -iTCP:18810 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "  18810 は LISTEN している（**これだけでは足りない**）"
  else
    echo "  **18810 が LISTEN していない**"
  fi
fi
V="$(curl -sS --max-time 8 http://127.0.0.1:18810/json/version 2>/dev/null | tr -d '\000' | head -c 200)"
if [ -n "$V" ]; then
  printf '  /json/version: %s\n' "$(printf '%s' "$V" | cut -c1-160)"
else
  echo "  **/json/version が返らない。CDP に繋がっていない**"
fi
echo '```'

echo
echo "## 4. いま 1 回 走らせて、抜ける理由をそのまま出す（**DRY・外さない**）"
echo
echo '```'
T0="$(date +%s)"
MODE=collect DRY_RUN=1 LIST_BUDGET_S=60 run_limited 180 "$RUNLOG" node "$TARGET"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s\n' "$RC" "$((T1 - T0))"
echo
echo "  --- 早期に抜ける理由（**今回はこれを拾う**）---"
grep -a -hE 'CDP に繋がらない|context が無い|ログインが切れている|自分のハンドルが読めない|/home を開けない|0 件しか読めない|キャッシュ|一覧を書' "$RUNLOG" 2>/dev/null \
  | tr -d '\000' | tail -10 | cut -c1-240 | clean | sed 's/^/    /'
echo
echo "  --- 出力 全部（**絞り込まない**）---"
cat "$RUNLOG" 2>/dev/null | tr -d '\000' | tail -30 | cut -c1-240 | clean | sed 's/^/    /'
echo '```'
rm -f "$RUNLOG"

echo
echo "## 5. いまの数"
echo
echo '```'
printf '  外した記録            %s 件\n' "$(jn "$ST")"
printf '  覚えた未フォロー      %s 件\n' "$(jn "$NF")"
printf '  follow-balance.js     %s 行 / 更新 %s\n' "$(wc -l < "$TARGET" 2>/dev/null | tr -d ' ')" \
  "$(stat -f '%Sm' -t '%m-%d %H:%M' "$TARGET" 2>/dev/null)"
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §4 に出た語 | 意味 | 次 |"
echo "| --- | --- | --- |"
echo "| **ログインが切れている** | X からログアウトされた | **人が入り直す**。自動では戻せない |"
echo "| **CDP に繋がらない** / \`/json/version\` が空 | Chrome が落ちている | \`ensure-chrome.sh\` を確かめる |"
echo "| **自分のハンドルが読めない** | ページは開くが DOM が違う | 待ちを伸ばす |"
echo "| 0 件しか読めない | 走査が当たっていない | セレクタを実物で直す |"
echo "| 何も出ず正常に終わる | **§1 の定期実行のログに答えが在る** |  |"
echo
echo "**外していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -aq '抜ける理由をそのまま出す' "$OUT" 2>/dev/null; then
  echo "止まっている理由を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
