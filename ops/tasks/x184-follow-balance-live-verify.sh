#!/bin/bash
# **直したボタン待ちが効いたかを、本番 1 回 で確かめる。上限 8 件。費用 $0。**
#
# ## 何を確かめるか
#
# 本番初回（22:46）は **8 件 中 4 件 しか外れなかった。**
#
#   外れた 2 件    約 7〜10 秒
#   飛ばした 4 件  **約 4 秒**（描画を待たずに「ボタンが無い」と判定）
#
# `x183` で **出るまで最大 12 回（約 11 秒）待つ**ようにし、
# 無いときは**理由を出す**（凍結 / 削除 / 鍵 / 空ページ / 在るボタン）ようにした。
#
# **効いたなら成功率が上がる。** 上がらないなら、理由の出力で本当の原因が分かる。
#
# ## 走らせる前の門（**1 つでも欠ければ走らせない**）
#
#   `w < 12`                  出るまで待つ処理（1 箇所）
#   `suspended:`              理由を出す処理（1 箇所）
#   `waitForTimeout(3500)`    固定待ちの残り（**0 箇所**）
#
# ## やらないこと
#
# **plist を触らない**（`x183` が置いた）。**上限も上げない**（8 件 のまま）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
TARGET="$S/follow-balance.js"
ST="$D/follow-balance-state.json"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-verify.md"
RUNLOG="$W/.x184-run.log"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

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

state_n() {
  node -e '
    const fs = require("fs");
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { process.stdout.write("0"); process.exit(0); }
    process.stdout.write(String(Object.keys(j || {}).length));
  ' "$1" 2>/dev/null
}

{
echo "# 直したボタン待ちを本番で確かめる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **上限 8 件 のまま。** plist は触らない。"
echo "> **LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"

echo
echo "## 1. 門（直しが入っているか）"
echo
echo '```'
if [ ! -f "$TARGET" ]; then
  echo "  **follow-balance.js が無い。走らせない。**"
  echo '```'
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
A="$(cnt 'w < 12' "$TARGET")"
B="$(cnt 'suspended:' "$TARGET")"
C="$(cnt 'waitForTimeout(3500)' "$TARGET")"
printf '  出るまで待つ処理       %s 箇所（1 以上が正）\n' "$A"
printf '  理由を出す処理         %s 箇所（1 以上が正）\n' "$B"
printf '  固定 3.5 秒 待ちの残り %s 箇所（0 が正）\n' "$C"
echo '```'
if [ "$A" -lt 1 ] || [ "$B" -lt 1 ] || [ "$C" -ne 0 ]; then
  echo
  echo "- **直しが入っていない。本番で走らせない。**（\`x183\` のレポートを見る）"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 2. 走らせる前"
echo
echo '```'
S0="$(state_n "$ST")"
printf '  これまでに外した記録: %s 件\n' "$S0"
echo '```'

echo
echo "## 3. 本番で 1 回（上限 8 件）"
echo
echo '```'
T0="$(date +%s)"
MIN_UNFOLLOW=8 MAX_UNFOLLOW=8 LIST_BUDGET_S=110 DECIDE_BUDGET_S=120 MAX_PROFILE_READS=30 \
  run_limited 400 "$RUNLOG" node "$TARGET"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **400 秒 で打ち切った**' || echo '← 自分で終わった' )"
echo
echo "  --- アンフォローの 1 件ごと（**時刻の差を見る**）---"
grep -hE '✂|ボタンが無い|押したが外れていない|: 例外|=== 外した:' "$RUNLOG" 2>/dev/null \
  | tail -24 | cut -c1-260 | clean | sed 's/^/    /'
echo '```'

echo
echo "## 4. 前回との差（**ここが答え**）"
echo
echo '```'
OK="$(cnt '— 外れた' "$RUNLOG")"
NB="$(cnt 'ボタンが無い' "$RUNLOG")"
NG="$(cnt '押したが外れていない' "$RUNLOG")"
EX="$(cnt ': 例外' "$RUNLOG")"
S1="$(state_n "$ST")"
printf '  今回  外れた %s / ボタンが無い %s / 押したが外れない %s / 例外 %s\n' "$OK" "$NB" "$NG" "$EX"
printf '  前回  外れた 4 / ボタンが無い 4 / 押したが外れない 0 / 例外 0\n'
echo
printf '  状態ファイル: %s → %s 件（差 %s）← **実際に外した数**\n' "$S0" "$S1" "$((S1 - S0))"
echo '```'
echo
echo "**\`ボタンが無い\` が残っていたら、その行に理由が出ている**（凍結 / 削除 / 鍵 / 空 / 在るボタン）。"
rm -f "$RUNLOG"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §4 の出方 | 意味 |"
echo "| --- | --- |"
echo "| **外れた 8 / ボタンが無い 0** | **直った。** 上限を 8 → 27 に上げてよい |"
echo "| 外れた 5〜7 | **改善した。** 残りの理由を見て詰める |"
echo "| 外れた 4 のまま ＋ 理由が \`suspended\` / \`notfound\` | **待ちの問題ではない。** そのアカウントは元から外せない。**候補から除く** |"
echo "| 外れた 4 のまま ＋ 理由が \`empty\` | **ページが読めていない。** 待ちをさらに伸ばす |"
echo
echo "**\$0／回・\$0／日・\$0／月。** LLM を呼ばない。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '前回との差' "$OUT" 2>/dev/null; then
  echo "直したボタン待ちを本番で確かめた / $(basename "$OUT")"
else
  echo "**確かめられていない。レポートを確認すること** / $(basename "$OUT")"
fi
