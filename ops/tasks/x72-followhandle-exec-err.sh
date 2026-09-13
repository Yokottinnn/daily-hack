#!/bin/bash
# **`follow-handle.js` が落ちている 28 件 の中身を読む。測るだけ。費用 $0。**
#
# ## なぜ（x69 の実測・弾かれた理由の上位）
#
#    94 follower count out of range     ← 判定して弾いた（正常）
#    28 exec err: Command failed: /usr/local/bin/node /Users/ny/.ope   ← **落ちている**
#    25 random-looking handle           ← 判定して弾いた（正常）
#    24 inactive
#
# **2 番目に多いのが「判定」ではなく「落ちた」。** 落ちた分は
# フォローもしなければ理由も残らない。**丸ごと機会を損している。**
#
# ## ログが切れている
#
# 呼び出し側は `e.message.slice(0, 150)` で切っている。
#
#   log(`  @${p.author}: ❌ exec err: ${e.message.slice(0, 150)}`);
#
# **肝心の stderr が見えない。** 切れていない場所（`.err` ログ・stderr の行）を探す。
#
# ## 読むところ
#
#   1. exec err の全文（切れていない記録がどこかに在るか）
#   2. いつ起きているか（特定の時間帯・特定のジョブに偏っていないか）
#   3. `follow-handle.js` の落ちうる箇所（例外を投げる行・timeout の値）
#   4. 呼び出し側の `execSync` の条件（timeout 60000 / maxBuffer）
#
# ## やらないこと
#
# **直さない。フォローしない。設定を変えない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（ログとソースを読むだけ・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/followhandle-exec-err.md"
FH="$S/follow-handle.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# \`follow-handle.js\` が落ちている 28 件"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 弾かれた理由の 2 番目が「判定」ではなく **「落ちた」**。"
echo "> \`28 exec err: Command failed\`"
echo ">"
echo "> **落ちた分はフォローもしなければ理由も残らない。** 丸ごと機会を損している。"
echo
echo "**測るだけ。直さない。**"

# ═══════════ 1. 全文を探す ═══════════
echo
echo "## 1. exec err の全文（**切れていない記録を探す**）"
echo
echo '```'
echo "  --- 切れている記録（呼び出し側は slice(0,150)） ---"
for f in hashtag-follow.log competitor-follower-follow.log comment-orchestrator.log; do
  P="$L/$f"; [ -f "$P" ] || continue
  c="$(grep -c 'exec err' "$P" 2>/dev/null || echo 0)"
  printf '    %-34s %4s 件\n' "$f" "$c"
done
echo
echo "  --- 直近 8 件（切れたまま） ---"
grep -h 'exec err' "$L"/hashtag-follow.log "$L"/competitor-follower-follow.log 2>/dev/null \
  | tail -8 | cut -c1-200 | sed 's/^/    /' | clean
echo
echo "  --- .err / .out に全文が残っていないか ---"
for f in hashtag-follow.err hashtag-follow.out competitor-follower-follow.err \
         competitor-follower-follow.out comment-warmup-err.log comment-warmup.out; do
  P="$L/$f"; [ -f "$P" ] || continue
  printf '    %-34s %8s bytes / %s\n' "$f" "$(wc -c < "$P" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)"
  grep -nE 'Error|error|Timeout|timeout|ECONN|ENOENT|Target closed|Protocol error|browser' "$P" 2>/dev/null \
    | tail -6 | cut -c1-200 | sed 's/^/      /' | clean
  echo
done
echo '```'

# ═══════════ 2. いつ起きているか ═══════════
echo
echo "## 2. いつ起きているか（**偏りを見る**）"
echo
echo '```'
echo "  --- 日ごと ---"
grep -h 'exec err' "$L"/hashtag-follow.log "$L"/competitor-follower-follow.log 2>/dev/null \
  | grep -oE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' | sort | uniq -c | tail -12 | sed 's/^/    /'
echo
echo "  --- 時刻ごと（UTC の時） ---"
grep -h 'exec err' "$L"/hashtag-follow.log "$L"/competitor-follower-follow.log 2>/dev/null \
  | grep -oE 'T[0-9][0-9]:' | sort | uniq -c | sort -rn | head -10 | sed 's/^/    /'
echo
echo "  --- ジョブごと ---"
for f in hashtag-follow.log competitor-follower-follow.log; do
  P="$L/$f"; [ -f "$P" ] || continue
  printf '    %-34s %4s 件 / 全 ❌ %4s 件\n' "$f" \
    "$(grep -c 'exec err' "$P" 2>/dev/null || echo 0)" \
    "$(grep -c '❌' "$P" 2>/dev/null || echo 0)"
done
echo '```'
echo
echo "**時刻に偏っていれば Chrome か CDP の状態が疑わしい。**"
echo "**ばらけていれば個別の相手（削除・鍵・ブロック）が疑わしい。**"

# ═══════════ 3. 落ちうる箇所 ═══════════
echo
echo "## 3. \`follow-handle.js\` の落ちうる箇所"
echo
echo '```'
if [ ! -f "$FH" ]; then
  echo "  **$FH が無い。**"
else
  echo "  $(wc -l < "$FH" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$FH" 2>/dev/null)"
  echo
  echo "  --- 例外を投げる／握りつぶす箇所 ---"
  grep -nE 'throw|catch|process.exit|timeout|waitFor|goto|connectOverCDP|browser' "$FH" 2>/dev/null \
    | head -20 | cut -c1-190 | sed 's/^/    /' | clean
  echo
  echo "  --- 待ち時間の設定 ---"
  grep -nE 'timeout: *[0-9]+|waitForTimeout\([0-9]+|setTimeout' "$FH" 2>/dev/null \
    | head -10 | cut -c1-190 | sed 's/^/    /' | clean
fi
echo '```'

# ═══════════ 4. 呼び出し側の条件 ═══════════
echo
echo "## 4. 呼び出し側の \`execSync\` の条件"
echo
echo '```'
for f in hashtag-follow.js competitor-follower-follow.js comment-orchestrator.sh; do
  P="$S/$f"; [ -f "$P" ] || continue
  echo "  ══ $f"
  grep -nE 'execSync|FOLLOW_HANDLE|maxBuffer|timeout' "$P" 2>/dev/null \
    | head -8 | cut -c1-190 | sed 's/^/    /' | clean
  echo
done
echo '```'
echo
echo "**\`timeout: 60000\` を超えると \`Command failed\` になる。**"
echo "プロフィールの描画が遅いだけなら、**待ち方を変えれば拾える。**"

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**ログとソースを読むだけ。LLM を呼ばない。ブラウザも触らない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**直す場合も \$0**（フォローは DOM 操作で LLM を呼ばない）。"
echo "返信ループの実績は 1 回 \$0.003 ／ 1 日 \$0.027 ／ 1 か月 約 \$0.81"
echo "（x68 適用後の上限は 1 日 \$0.048 ／ 1 か月 \$1.44）。"
} > "$OUT" 2>&1

echo "follow-handle が落ちる原因 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
