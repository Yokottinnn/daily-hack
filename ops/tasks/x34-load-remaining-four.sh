#!/bin/bash
# **載らなかった 4 本を載せる。とくに `comment-warmup`。費用 $0。**
#
# ## x33 の成果と、残った穴（2026-09-12 23:22）
#
#   CDP: **15 秒後に健全化** ← 悪循環は断てた
#   UNREACHABLE_GUARD: 入った（node --check OK）
#   tab-guard: **止めずに残した**（CDP が戻ったため）
#   ジョブ: **4 / 8 本**（90 秒 経過後も維持＝もう外されていない）
#
# **載らなかった 4 本。**
#
#   comment-warmup            ← **返信の本体。いちばん痛い**
#   reply-followers-cleanup   ← アンフォローの実行役
#   incoming-reply-watcher
#   pipeline-heartbeat
#
# ## なぜ載らないのか（まだ分かっていない）
#
# x33 は `load -w || bootstrap` を打って、直後に `launchctl list` で確認した。
# **4 本は確認に出なかった。** 理由は出力していない。
#
#   * plist が壊れている（`plutil -lint` が通らない）
#   * plist が無い
#   * 既にロード済みで `load` が失敗し、かつ list の grep が効いていない
#   * launchd が拒否している（Disabled、権限、パス不正）
#
# **今度は理由まで出す。**
#
# ## やること
#
#   1. 4 本それぞれの plist を `plutil -lint` で検査し、中身を出す
#   2. **`launchctl print gui/<uid>/<label>`** で launchd 側の言い分を読む
#   3. `launchctl load -w` と `bootstrap` を**それぞれ実行し、エラー全文を残す**
#   4. Disabled になっていないか（`launchctl print-disabled gui/<uid>`）
#   5. 載ったら 60 秒 生き残るかを見る
#
# **Chrome を kill しない。投稿しない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/load-remaining-four.md"
UID_NUM="$(id -u)"
FOUR="comment-warmup reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"
ALL8="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 載らなかった 4 本を載せる"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x33\` で **CDP は 15 秒で健全化**し、**悪循環は断てた。**"
echo "> ジョブは **4 / 8 本**で、90 秒 経っても減っていない（＝もう外されていない）。"
echo "> **残り 4 本が載らない理由を、今度は全部 出す。**"

echo
echo "## 0. いまの状態"
echo
echo '```'
N=0
for j in $ALL8; do
  if launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j"; then
    printf '  ロード   %-34s\n' "$j"; N=$((N+1))
  else
    printf '  **未**   %-34s\n' "$j"
  fi
done
echo "  → ${N} / 8 本"
echo
echo "  CDP: $( [ -f "$S/cdp-health.js" ] && ( cd "$S" && /usr/local/bin/node cdp-health.js >/dev/null 2>&1 ) && echo '健全' || echo '**落ちている**')"
echo "  tab-guard: $(launchctl list 2>/dev/null | grep -cF 'ai.openclaw.tab-guard' || true) 本"
echo '```'

echo
echo "## 1. 無効化されていないか"
echo
echo '```'
launchctl print-disabled "gui/${UID_NUM}" 2>/dev/null | grep -E 'ai\.openclaw\.(comment-warmup|reply-followers-cleanup|incoming-reply-watcher|pipeline-heartbeat)' \
  | sed 's/^/  /' || echo "  print-disabled が読めない"
echo "  ---（\"=> true\" なら **無効化されている**）---"
echo '```'

echo
echo "## 2. 4 本それぞれを、理由つきで載せる"
for j in $FOUR; do
  lbl="ai.openclaw.$j"; P="$LA/$lbl.plist"
  echo
  echo "### \`$j\`"
  echo
  echo '```'
  if launchctl list 2>/dev/null | grep -qF "$lbl"; then
    echo "  既にロード済み。触らない。"
    echo '```'
    continue
  fi
  if [ ! -f "$P" ]; then
    echo "  **plist が無い: $P**"
    echo "  --- 似た名前のファイル ---"
    ls -1 "$LA" 2>/dev/null | grep -i "$(echo "$j" | cut -c1-8)" | head -5 | sed 's/^/    /'
    echo '```'
    continue
  fi
  echo "  plist: $P"
  echo "  更新 : $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null) / $(wc -c < "$P" | tr -d ' ') B"
  echo
  echo "  --- plutil -lint ---"
  plutil -lint "$P" 2>&1 | sed 's/^/    /' | clean
  echo
  echo "  --- 中身（要点） ---"
  plutil -p "$P" 2>/dev/null | grep -iE 'Label|Program|Arguments|Interval|Calendar|Disabled|RunAtLoad|=> ' \
    | head -14 | cut -c1-165 | sed 's/^/    /' | clean
  echo
  echo "  --- launchctl の言い分（print） ---"
  launchctl print "gui/${UID_NUM}/$lbl" 2>&1 | head -8 | sed 's/^/    /' | clean
  echo
  echo "  --- (a) launchctl load -w（エラー全文） ---"
  launchctl load -w "$P" 2>&1 | head -5 | sed 's/^/    /' | clean
  echo "    → 載ったか: $(launchctl list 2>/dev/null | grep -cF "$lbl" || true) 本"
  echo
  echo "  --- (b) launchctl bootstrap（エラー全文） ---"
  launchctl bootstrap "gui/${UID_NUM}" "$P" 2>&1 | head -5 | sed 's/^/    /' | clean
  echo "    → 載ったか: $(launchctl list 2>/dev/null | grep -cF "$lbl" || true) 本"
  echo
  echo "  --- (c) enable してから bootstrap ---"
  launchctl enable "gui/${UID_NUM}/$lbl" 2>&1 | head -3 | sed 's/^/    /' | clean
  launchctl bootstrap "gui/${UID_NUM}" "$P" 2>&1 | head -3 | sed 's/^/    /' | clean
  echo "    → 載ったか: $(launchctl list 2>/dev/null | grep -cF "$lbl" || true) 本"
  echo '```'
done

echo
echo "## 3. 60 秒 待って、生き残るか"
echo
echo '```'
for i in 20 40 60; do
  sleep 20
  M=0
  for j in $ALL8; do launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j" && M=$((M+1)); done
  printf '  %2s 秒後: %s / 8 本\n' "$i" "$M"
done
echo
FIN=0
for j in $ALL8; do
  if launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j"; then
    printf '  ロード   %-34s\n' "$j"; FIN=$((FIN+1))
  else
    printf '  **未**   %-34s\n' "$j"
  fi
done
echo
echo "  **最終: ${FIN} / 8 本**"
echo "  CDP: $( [ -f "$S/cdp-health.js" ] && ( cd "$S" && /usr/local/bin/node cdp-health.js >/dev/null 2>&1 ) && echo '健全' || echo '**落ちている**')"
echo
echo "  --- tab-guard のログ（この間に鳴ったか） ---"
tail -6 "$W/logs/tab-guard.log" 2>/dev/null | cut -c1-170 | sed 's/^/    /' | clean
echo '```'

echo
echo "---"
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
echo "**$(date '+%H:%M') 残り 4 本を理由つきで載せた（\$0）** / $F / $(basename "$OUT")"
