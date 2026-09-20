#!/bin/bash
# **`check-follower-v2.js` の呼び方を確かめて、3 件 だけ試す。費用 $0。**
#
# ## なぜ 3 件 なのか
#
# 種の候補 58 件 のうち **54 件 がフォロワー数未取得**で、このままでは選べない。
# x101 で **`check-follower-v2.js` が単独で呼べる形**だと分かった。
#
# **だが呼び方を知らない。** 引数の形も、出力の形も、1 件あたりの時間も。
# **54 件 をいきなり回すと、5 分 を超えて heartbeat ごと止める**（最上位ルール 15）。
# 2026-09-13 に `x50` が 15 分 かかって死活監視を 49 分 止めた前例がある。
#
# **先に 3 件 で測る。** 1 件あたりの時間が分かれば、次は何件 ずつ回せるか決まる。
#
# ## やらないこと
#
# **54 件 を回さない。フォローしない。種を触らない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
CF="$S/check-follower-v2.js"
OUT="${OPS_REPORT_DIR:-/tmp}/trial-check-follower.md"

secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(xox[bp]-)[A-Za-z0-9-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }

# **素の bash で打ち切る。** macOS に `timeout` も `gtimeout` も無い（最上位ルール 14）。
#
# **プロセスグループ（`kill -TERM -$pid`）は使わない。** 子がグループリーダーで
# なければ**呼び出し側のグループごと落ちる。** 実際にテスト用シェルが死んだ（exit 144）。
# **単独の PID にだけ撃つ。**
run_bounded() {  # run_bounded <秒> <出力先> <コマンド...>
  local lim="$1" dst="$2"; shift 2
  "$@" > "$dst" 2>&1 &
  local pid=$!
  local i=0
  while [ "$i" -lt "$lim" ]; do
    kill -0 "$pid" 2>/dev/null || { wait "$pid" 2>/dev/null; return 0; }
    sleep 1
    i=$(( i + 1 ))
  done
  echo "  **${lim} 秒 で打ち切った**" >> "$dst"
  kill -TERM "$pid" 2>/dev/null || true
  sleep 2
  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  return 124
}

{
echo "# \`check-follower-v2.js\` の呼び方を確かめる"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 種の候補 58 件 のうち **54 件 がフォロワー数未取得**で、このままでは選べない。"
echo "> x101 で \`check-follower-v2.js\` が**単独で呼べる形**だと分かった。"
echo ">"
echo "> **だが呼び方を知らない。** いきなり 54 件 回すと 5 分 を超えて"
echo "> **heartbeat ごと止める**（2026-09-13 に x50 で 49 分 止めた前例）。"
echo
echo "**先に 3 件 で測る。54 件 は回さない。**"

# ═══════════ 1. 呼び方 ═══════════
echo
echo "## 1. 呼び方（**ソースから読む。推測しない**）"
echo
echo '```javascript'
if [ ! -f "$CF" ]; then
  echo "  **$CF が無い。**"
  ls -1 "$S" 2>/dev/null | grep -i -E 'check-follower|follower-check' | head -6 | sed 's/^/    候補: /'
else
  echo "  $(wc -l < "$CF" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$CF" 2>/dev/null)"
  echo
  echo "  --- 先頭 30 行（用途と使い方が書いてあることが多い）---"
  awk 'NR<=30 {printf("%4d| %s\n", NR, $0)}' "$CF" | cut -c1-190 | sed 's/^/  /' | secrets
  echo
  echo "  --- 引数の取り方 ---"
  grep -n -E 'process\.argv|process\.env\.[A-Z_]+' "$CF" 2>/dev/null | head -10 | cut -c1-190 | sed 's/^/  /'
  echo
  echo "  --- 何を出すか（console.log / 書き出し先）---"
  grep -n -E 'console\.log|writeFileSync' "$CF" 2>/dev/null | head -10 | cut -c1-190 | sed 's/^/  /' | secrets
fi
echo '```'

# ═══════════ 2. 3 件 だけ試す ═══════════
echo
echo "## 2. **3 件 だけ**試す（**時間を測る**）"
echo
echo '```'
if [ ! -f "$CF" ]; then
  echo "  **対象が無いので試さない。**"
elif ! grep -q 'process.argv' "$CF" 2>/dev/null; then
  echo "  **引数を取らない作りに見える。** 上の「引数の取り方」を見て、次のタスクで合わせる。"
  echo "  ここでは走らせない（何をするか分からないものを当て推量で叩かない）。"
else
  # 候補 58 件 のうち、名前から個人アカウントらしいもの 3 件
  cd "$S" || true
  for h in fxmeitantei mao_otk_tw coupon_gorilla1; do
    RES="${TMPDIR:-/tmp}/.x103-$h.out"
    T0="$(date +%s)"
    # **1 件 60 秒 で打ち切る。** 3 件 でも最大 186 秒 で、5 分 に収まる
    run_bounded 60 "$RES" /usr/local/bin/node check-follower-v2.js "$h"
    RC=$?
    T1="$(date +%s)"
    echo "  ══ $h（$(( T1 - T0 )) 秒 / rc=$RC）"
    head -6 "$RES" 2>/dev/null | cut -c1-185 | sed 's/^/    /' | secrets
    rm -f "$RES" 2>/dev/null || true
    echo
  done
fi
echo '```'
echo
echo "**1 件あたりの秒数が分かれば、次は何件 ずつ回せるかが決まる。**"
echo "5 分 = 300 秒 が上限なので、**余裕を見て 1 回 あたり 240 秒 ぶん**にする。"

# ═══════════ 3. 次に回す件数の目安 ═══════════
echo
echo "## 3. 次に回す件数の目安"
echo
echo '```'
echo "    1 件 3 秒 なら  → 1 回 80 件  → **54 件 は 1 回 で終わる**"
echo "    1 件 5 秒 なら  → 1 回 48 件  → 2 回 に分ける"
echo "    1 件 10 秒 なら → 1 回 24 件  → 3 回 に分ける"
echo
echo "    **上限に頼らない。** OPS_TASK_TIMEOUT(900秒) は暴走を止める安全弁であって"
echo "    設計の目標ではない（最上位ルール 15）。"
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**プロフィールを DOM で読むだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**54 件 を回すのも \$0。** 返信ループは \`MAX_PICKS\` を 6 にしたため"
echo "**約 \$0.95/月（推定）**。実測は次の 24 時間 の \`cost_24h_usd\` で確かめる。"
} > "$OUT" 2>&1

echo "check-follower の呼び方 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
