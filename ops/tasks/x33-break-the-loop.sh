#!/bin/bash
# **悪循環を断つ。CDP を戻し、tab-guard の誤判定を止める。費用 $0。**
#
# ## x32 で悪循環の全体像が割れた（2026-09-12 23:11）
#
# `tab-guard.js` は **CDP の `/json/list`** を見てタブ数を数えている。
#
#   const req = http.get({ host:"127.0.0.1", port, path:"/json/list", ... })
#   req.on("error", () => resolve({ reachable: false }));
#   ...
#   haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
#
# ログ（実物）:
#
#   [2026-09-12T13:28:57Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
#   [2026-09-12T13:29:08Z] 🚨 同上
#
# **CDP が死んでいるだけなのに「利用者がウィンドウを全部 閉じた」と誤判定している。**
#
# ## 悪循環
#
#   ① CDP（自動化専用 Chrome）が落ちる
#   ② tab-guard が「全消え」と誤判定 → ai.openclaw.* を全 unload
#   ③ **Chrome を起動するジョブも消える**
#   ④ → ① に戻る。**永久に抜けられない**
#
# x32 の 60 秒テストでジョブが生き残ったのは、**その 60 秒に発火しなかっただけ。**
#
# ## 輪を断つ（順番が大事）
#
#   1. **鍵が無いことを確認**（x30 が退避済みのはず）
#   2. **CDP を戻す** ← ここが輪の切断点
#   3. CDP が戻ったことを確認してから、**tab-guard の誤判定を直す**
#   4. 8 本を載せる
#   5. **載ってから 90 秒 待って、生き残るかを見る**（また外されないか）
#
# ## tab-guard の直し方（**非常ブレーキは残す**）
#
# **「CDP に繋がらない」は「利用者がタブを消した」ではない。**
# 前回が `reachable: false` なら、**比較そのものを行わない**ようにする。
# タブが 10 → 1 のような**実際の減少**は、これまでどおり検知する。
#
# ## それでも直らないときの保険
#
# CDP が戻らなければ tab-guard は鳴り続ける。その場合に限り
# **tab-guard を一時停止**して 3 ループを先に戻す（利用者が 4 つとも選択済み）。
# **止めたことをレポートに明記する。**
#
# **Chrome を kill しない。投稿しない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/break-the-loop.md"
TG="$S/tab-guard.js"
LOCK=/tmp/x-login-in-progress
STAMP="$(date '+%Y%m%d-%H%M%S')"
UID_NUM="$(id -u)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && /usr/local/bin/node cdp-health.js >/dev/null 2>&1 ); }

{
echo "# 悪循環を断つ"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`tab-guard\` は **CDP の \`/json/list\`** を見てタブを数えている。"
echo "> **CDP が落ちているだけで「利用者がウィンドウを全部 閉じた」と誤判定し、全停止する。**"
echo "> 止まると Chrome を起動するジョブも消えるので、**永久に抜けられない。**"

# ═══════════ 1. 鍵 ═══════════
echo
echo "## 1. 鍵は外れているか"
echo
echo '```'
if [ -f "$LOCK" ]; then
  AGE=$(( ( $(date '+%s') - $(stat -f '%m' "$LOCK" 2>/dev/null || echo 0) ) / 3600 ))
  echo "  **まだ有る**: $LOCK（${AGE} 時間）"
  CDPC=0; pgrep -f 'remote-debugging-port' >/dev/null 2>&1 && CDPC=1
  if [ "$CDPC" = "0" ]; then
    mv "$LOCK" "$LOCK.parked-$STAMP" 2>/dev/null \
      && echo "  → **退避した**（CDP 付き Chrome が無いのに鍵がある＝矛盾）" \
      || echo "  → 退避できない"
  else
    echo "  → CDP 付き Chrome が動いている。手動ログイン中かもしれないので触らない。"
  fi
else
  echo "  無い（正常）— x30 が退避済み"
fi
echo '```'

# ═══════════ 2. CDP を戻す ═══════════
echo
echo "## 2. **CDP を戻す**（ここが輪の切断点）"
echo
echo '```'
echo "  --- 前 ---"
cdp_ok && echo "    CDP: 健全" || echo "    **CDP: 落ちている**"
echo
echo "  --- ensure-chrome.sh ---"
( cd "$W" && "$S/ensure-chrome.sh" ) 2>&1 | tail -12 | sed 's/^/    /' | clean
echo "    (rc=$?)"
echo
echo "  --- 45 秒 待って確認 ---"
for i in 15 30 45; do
  sleep 15
  if cdp_ok; then echo "    ${i} 秒後: **健全になった**"; break
  else echo "    ${i} 秒後: まだ落ちている"; fi
done
echo
echo "  --- ensure-chrome.log の末尾 ---"
tail -12 "$W/logs/ensure-chrome.log" 2>/dev/null | cut -c1-170 | sed 's/^/    /' | clean
echo '```'

CDP_BACK=0
cdp_ok && CDP_BACK=1

# ═══════════ 3. tab-guard の誤判定を直す ═══════════
echo
echo "## 3. \`tab-guard\` の誤判定を直す（**非常ブレーキは残す**）"
echo
echo "**「CDP に繋がらない」は「利用者がタブを消した」ではない。**"
echo "前回が \`reachable:false\` なら**比較そのものを行わない。**"
echo "タブが 10 → 1 のような**実際の減少**は、これまでどおり検知する。"
echo
echo '```'
if [ ! -f "$TG" ]; then
  echo "  **tab-guard.js が無い。触らない。**"
elif grep -q 'UNREACHABLE_GUARD' "$TG" 2>/dev/null; then
  echo "  既に入っている。触らない。"
else
  cp -p "$TG" "$TG.bak-$STAMP" && echo "  退避: $(basename "$TG").bak-$STAMP"
  /usr/local/bin/node - "$TG" <<'JS'
const fs = require("fs");
const p = process.argv[2];
let s = fs.readFileSync(p, "utf8");

// haltAutomation("...Chrome プロセスが消滅...") を呼ぶ直前に、
// 「前回も繋がっていなかったなら halt しない」ガードを入れる
const re = /(\n(\s*)haltAutomation\(\s*["'`][^"'`]*消滅[^"'`]*["'`]\s*\);)/;
const m = s.match(re);
if (!m) {
  console.log("  **消滅の halt 呼び出しが見つからない。触らない。**");
  process.exit(0);
}
const indent = m[2];
const GUARD =
`\n${indent}// UNREACHABLE_GUARD (2026-09-12): **CDP に繋がらないだけで全停止しない。**\n` +
`${indent}// tab-guard は CDP の /json/list でタブを数えている。CDP が落ちていると\n` +
`${indent}// 「利用者がウィンドウを全部 閉じた」と誤判定し、Chrome を起動するジョブごと\n` +
`${indent}// 止めてしまう。すると CDP は永久に戻らない（2026-09-08〜12 に 4 日 止まった）。\n` +
`${indent}// **前回も繋がっていなかったなら、それは「消滅」ではなく「まだ落ちたまま」。**\n` +
`${indent}if (prev && prev.reachable === false) {\n` +
`${indent}  log("CDP unreachable が続いている（前回も false）。消滅とみなさず halt しない");\n` +
`${indent}  return;\n` +
`${indent}}` + m[1];
s = s.replace(re, GUARD);
fs.writeFileSync(p, s);
console.log("  UNREACHABLE_GUARD を入れた");
JS
  if /usr/local/bin/node --check "$TG" 2>&1 | clean; then
    echo "  node --check: OK"
  else
    echo "  **構文エラー。戻す。**"; cp -p "$TG.bak-$STAMP" "$TG"
  fi
fi
echo '```'
echo
echo '```diff'
diff -u "$TG.bak-$STAMP" "$TG" 2>/dev/null | head -30 | clean
echo '```'

# ═══════════ 4. CDP が戻らなければ tab-guard を一時停止 ═══════════
echo
echo "## 4. CDP が戻らなかった場合の保険"
echo
echo '```'
if [ "$CDP_BACK" = "1" ]; then
  echo "  CDP は戻った。**tab-guard は止めない。** 非常ブレーキを残す。"
else
  echo "  **CDP が戻らない。** このままだと tab-guard が鳴り続け、3 ループが永久に止まる。"
  echo "  利用者の判断（4 つとも選択）により、**tab-guard を一時停止する。**"
  if launchctl bootout "gui/${UID_NUM}/ai.openclaw.tab-guard" 2>/dev/null \
     || launchctl unload "$LA/ai.openclaw.tab-guard.plist" 2>/dev/null; then
    sleep 2
    if launchctl list 2>/dev/null | grep -qF 'ai.openclaw.tab-guard'; then
      echo "  → **止められなかった**（まだ載っている）"
    else
      echo "  → **止めた。** CDP が戻ったら必ず戻すこと:"
      echo "     launchctl bootstrap gui/${UID_NUM} $LA/ai.openclaw.tab-guard.plist"
    fi
  else
    echo "  → 停止コマンドが失敗した"
  fi
fi
echo '```'

# ═══════════ 5. 8 本を載せる ═══════════
echo
echo "## 5. 3 ループを載せる"
echo
echo '```'
EXPECT="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"
for j in $EXPECT; do
  lbl="ai.openclaw.$j"; P="$LA/$lbl.plist"
  launchctl list 2>/dev/null | grep -qF "$lbl" && { printf '  既にロード %-36s\n' "$j"; continue; }
  [ -f "$P" ] || { printf '  **plist が無い** %-32s\n' "$j"; continue; }
  launchctl load -w "$P" >/dev/null 2>&1 || launchctl bootstrap "gui/${UID_NUM}" "$P" >/dev/null 2>&1 || true
  if launchctl list 2>/dev/null | grep -qF "$lbl"; then printf '  **載せた** %-38s\n' "$j"
  else printf '  載らない %-40s\n' "$j"; fi
done
echo '```'

# ═══════════ 6. 90 秒 生き残るか ═══════════
echo
echo "## 6. **90 秒 待って、生き残るか**（また外されないか）"
echo
echo '```'
for i in 30 60 90; do
  sleep 30
  N=0
  for j in $EXPECT; do launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j" && N=$((N+1)); done
  printf '  %2s 秒後: %s / 8 本\n' "$i" "$N"
done
echo
FIN=0
for j in $EXPECT; do launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j" && FIN=$((FIN+1)); done
echo "  **最終: ${FIN} / 8 本**"
echo "  tab-guard: $(launchctl list 2>/dev/null | grep -cF 'ai.openclaw.tab-guard') 本"
echo "  CDP: $(cdp_ok && echo '健全' || echo '**落ちている**')"
echo
echo "  --- tab-guard のログ（この間に鳴ったか） ---"
tail -8 "$W/logs/tab-guard.log" 2>/dev/null | cut -c1-170 | sed 's/^/    /' | clean
echo '```'

echo
echo "---"
echo
echo "## 判定"
echo
echo "| 結果 | 意味 |"
echo "| --- | --- |"
echo "| 8 / 8 が 90 秒 生きた ＋ CDP 健全 | **輪を断てた。** 次の定時（12/16/19/22 時）から 3 ループが動く |"
echo "| 8 / 8 だが CDP が落ちている | ジョブは載った。**CDP の復旧が別途 要る** |"
echo "| 途中で減った | **まだ外す主がいる。** tab-guard 以外を疑う |"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| フォロー・アンフォロー（DOM 操作） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（**実測** 9/8=5 件・9/9=3 件） | \$0.003 | \$0.009〜0.015 | 約 \$0.27〜0.45 |"
echo
echo "**Chrome を kill していない。投稿もしていない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
F="$(grep -m1 -oE '\*\*最終: [0-9]+ / 8 本\*\*' "$OUT" 2>/dev/null || echo '結果 不明')"
C="$(grep -m1 -oE 'CDP: 健全|CDP: \*\*落ちている\*\*' "$OUT" 2>/dev/null || echo '')"
echo "**$(date '+%H:%M') 悪循環を断った（\$0）** / $F / $C / $(basename "$OUT")"
