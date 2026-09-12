#!/bin/bash
# **誰が `/tmp/x-login-in-progress` を作り続けているのかを突き止める。費用 $0。読むだけ。**
#
# ## 2026-09-12 21:48 の実測（x26）
#
#   **有る**: /tmp/x-login-in-progress
#     経過  : **0 時間**
#
# **4 日 刺さり続けているのに mtime が「0 時間」。**
# ＝ **何かが定期的に touch し直している。**
#
# だから「6 時間 経ったら外す」という時間だけの判定では**永久に外れない。**
# 番人（x28）は「Chrome が動いていないのに鍵がある＝矛盾」で外すよう直したが、
# **作っている主を止めないと、外してもすぐ戻る。**
#
# ## 探すもの
#
#   1. 鍵を `touch` / `> ` / `echo >` しているスクリプト（workspace 全体）
#   2. そのスクリプトを呼ぶジョブ（plist）と、そのロード状態
#   3. 鍵の中身（誰が書いたか分かる情報が入っているかも）
#   4. 鍵を**消す側**のコード（正常なら誰かが消すはず。その経路が壊れている）
#   5. ログから、鍵が作られた前後の行
#
# **投稿しない。Chrome を触らない。ジョブを触らない。鍵も消さない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/who-writes-login-lock.md"
LOCK=/tmp/x-login-in-progress

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 誰が \`/tmp/x-login-in-progress\` を作り続けているのか"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 4 日 刺さり続けているのに **mtime が 0 時間**。"
echo "> **何かが定期的に touch し直している。** 時間だけの判定では永久に外れない。"

echo
echo "## 1. 鍵のいまの状態"
echo
echo '```'
if [ -f "$LOCK" ]; then
  echo "  有る: $LOCK"
  echo "    作成(ctime): $(stat -f '%Sc' -t '%Y-%m-%d %H:%M:%S' "$LOCK" 2>/dev/null)"
  echo "    更新(mtime): $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$LOCK" 2>/dev/null)"
  echo "    所有者     : $(stat -f '%Su:%Sg' "$LOCK" 2>/dev/null)"
  echo "    大きさ     : $(wc -c < "$LOCK" 2>/dev/null | tr -d ' ') B"
  echo "    中身       :"
  head -c 400 "$LOCK" 2>/dev/null | sed 's/^/      /' | clean
  echo
  echo "  --- いま誰か開いているか ---"
  lsof "$LOCK" 2>/dev/null | head -5 | sed 's/^/    /' || echo "    誰も開いていない"
else
  echo "  無い（いまは外れている）"
fi
echo
echo "  --- 退避済みのもの ---"
ls -1t /tmp/x-login-in-progress.parked-* 2>/dev/null | head -5 | while read -r f; do
  printf '    %-52s %s\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
done
echo '```'

echo
echo "## 2. 鍵を**作っている**コード"
echo
echo '```bash'
grep -rn 'x-login-in-progress' "$S" "$HOME/openclaw" 2>/dev/null \
  | grep -v node_modules | grep -v '\.bak' | head -25 | cut -c1-175 | clean
echo "  ---（上が全部。作る側と消す側の両方が入っている）---"
echo '```'

echo
echo "### そのうち **作る** 行だけ"
echo
echo '```bash'
grep -rn 'x-login-in-progress' "$S" "$HOME/openclaw" 2>/dev/null \
  | grep -v node_modules | grep -v '\.bak' \
  | grep -E 'touch|> *"?\$?\{?LOCK|echo .*>' | head -12 | cut -c1-175 | clean
echo '```'
echo
echo "### そのうち **消す** 行だけ（**これが動いていないのが問題**）"
echo
echo '```bash'
grep -rn 'x-login-in-progress' "$S" "$HOME/openclaw" 2>/dev/null \
  | grep -v node_modules | grep -v '\.bak' \
  | grep -E 'rm |unlink|trap' | head -12 | cut -c1-175 | clean
echo '```'

echo
echo "## 3. それを呼ぶジョブは動いているか"
echo
echo '```'
FILES="$(grep -rl 'x-login-in-progress' "$S" 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head -8)"
for f in $FILES; do
  b="$(basename "$f")"
  echo "  [$b]"
  hits="$(grep -l "$b" "$LA"/*.plist 2>/dev/null | head -3)"
  if [ -z "$hits" ]; then
    echo "    どの plist からも直接 呼ばれていない（別スクリプト経由の可能性）"
  else
    for p in $hits; do
      lbl="$(basename "$p" .plist)"
      st="$(launchctl list 2>/dev/null | grep -F "$lbl" | awk '{print "PID="$1" rc="$2}')"
      printf '    %-44s %s\n' "$lbl" "${st:-**未ロード**}"
    done
  fi
done
echo '```'

echo
echo "## 4. いま走っているプロセスに、鍵を触りそうなものはあるか"
echo
echo '```'
ps -eo pid,etime,args 2>/dev/null | grep -iE 'x-login|login\.js|openclaw' | grep -v ' grep' \
  | head -10 | cut -c1-165 | sed 's/^/  /' | clean
echo "  ---（空なら、いま走っているものは無い）---"
echo '```'

echo
echo "## 5. ログから、鍵が作られた前後を見る"
echo
echo '```'
for f in "$W"/logs/ensure-chrome.log "$W"/logs/x-login.log "$W"/logs/listener.log; do
  [ -f "$f" ] || continue
  echo "  [$(basename "$f")] 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  grep -nE 'login|lock|guard' "$f" 2>/dev/null | tail -12 | cut -c1-170 | sed 's/^/    /' | clean
  echo
done
echo '```'

echo
echo "---"
echo
echo "## 直し方の見当"
echo
echo "| 分かったこと | 直し方 |"
echo "| --- | --- |"
echo "| 作る側が特定できた ＋ 消す側が無い/壊れている | **消す側に \`trap ... EXIT\` を足す** |"
echo "| 作る側のジョブが未ロード | **誰も作っていない＝残骸。番人が外せば終わり** |"
echo "| 作る側が常駐している | **その常駐を直す。番人が外しても戻される** |"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（読むだけ・LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo
echo "**何も変更していない。鍵も消していない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**$(date '+%H:%M') 鍵を作っている主を調べた（変更なし・\$0）** / $(basename "$OUT")"
