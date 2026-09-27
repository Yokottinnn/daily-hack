#!/bin/bash
# **本番で 1 回だけ走らせる。上限 8 件。plist はまだ置かない。費用 $0。**
#
# ## 承認の範囲（2026-09-27）
#
# 利用者が「**27 件 のまま本番にする**」を選んだ。その選択肢の説明にこう書いてある。
#
#   > 猶予 7 日 は触らない（フォロバされる時間を潰したくない）。
#   > **初回は上限を低くして段階的に上げます。**
#
# **だから初回は 8 件。** いきなり 27 件 外さない。
# **plist はこのタスクでは置かない。** 結果を見てから次で置く。
#
# ## DRY で確かめ済みのこと（2026-09-27 22:01）
#
#   rc=0 / 103 秒 ← **自分で終わった**（終了バグは直った）
#   フォロー中 274 / フォロワー 311 ／ 片思い 100 / 相互 174
#   ① 片思いから 23 件 → プロフィール 40 件 → **外す候補 合計 27 件**
#   守った内訳: ホワイトリスト 2 / 反応をくれた人 50 / 猶予 81
#
# ## これは取り消せる操作である（ただし外向き）
#
# アンフォローは**やり直せる**（フォローし直せる）が、**相手に見える**。
# だから **8 件 に絞り、1 件ごとに「本当に外れたか」を確かめる**作りのまま使う。
#
# ## 気をつけること
#
# - **`rc=0` は「外した」証拠にならない**（最上位ルール 13）。
#   ログの `外れた` 行と **状態ファイル `follow-balance-state.json`** で数える
# - **ハンドルは伏せる**（公開リポジトリに載る）
# - **一覧は取り直す**（`MODE` 未指定＝通し）。22:01 のキャッシュは古くなりうる
#
# ## 費用（最上位ルール 2-B）
#
# **LLM を呼ばない。** DOM 操作だけ。
#
#   1 回あたり   **$0**
#   1 日あたり   **$0**（このタスクは 1 回しか走らない）
#   1 か月あたり **$0**
#
# 定期化したあとも **$0／回・$0／日・$0／月**（`follow-balance.js` は LLM を使わない）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
TARGET="$S/follow-balance.js"
ST="$D/follow-balance-state.json"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-live-first.md"
RUNLOG="$W/.x181-run.log"

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
echo "# 本番で 1 回だけ（上限 8 件・$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **初回なので上限 8 件。** いきなり 27 件 外さない。"
echo "> **plist はこのタスクでは置かない。** 結果を見てから次で置く。"
echo "> **LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"

echo
echo "## 1. 直しが入っているか（**走らせる前に確かめる**）"
echo
echo '```'
if [ ! -f "$TARGET" ]; then
  echo "  **follow-balance.js が無い。走らせない。**"
  echo '```'
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
printf '  %s 行 / 更新 %s\n' "$(wc -l < "$TARGET" | tr -d ' ')" "$(stat -f '%Sm' -t '%m-%d %H:%M:%S' "$TARGET" 2>/dev/null)"
A="$(cnt 'ONEWAY_IGNORE_ENGAGED' "$TARGET")"
B="$(cnt 'process.exit(0)' "$TARGET")"
C="$(cnt 'page.close(); return' "$TARGET")"
printf '  ONEWAY_IGNORE_ENGAGED %s 箇所（2 以上が正）\n' "$A"
printf '  process.exit(0)       %s 箇所（10 が正）\n' "$B"
printf '  page.close(); return  %s 箇所（0 が正）\n' "$C"
echo '```'
if [ "$A" -lt 2 ] || [ "$B" -lt 5 ] || [ "$C" -ne 0 ]; then
  echo
  echo "- **直しが入っていない。本番で走らせない。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 2. 走らせる前の状態"
echo
echo '```'
S0="$(state_n "$ST")"
printf '  これまでに外した記録: %s 件\n' "$S0"
if [ -f "$D/follow-balance-lists.json" ]; then
  printf '  一覧のキャッシュ: 更新 %s（**今回は取り直す**）\n' "$(stat -f '%Sm' -t '%H:%M:%S' "$D/follow-balance-lists.json" 2>/dev/null)"
fi
echo '```'

echo
echo "## 3. 本番で 1 回（**上限 8 件・\`DRY_RUN\` は付けない**）"
echo
echo "**一覧は取り直す**（`MODE` 未指定＝通し）。上限 420 秒 で打ち切る。"
echo
echo '```'
T0="$(date +%s)"
MIN_UNFOLLOW=8 MAX_UNFOLLOW=8 LIST_BUDGET_S=110 DECIDE_BUDGET_S=150 MAX_PROFILE_READS=40 \
  run_limited 420 "$RUNLOG" node "$TARGET"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **420 秒 で打ち切った**' || echo '← 自分で終わった' )"
echo
tail -60 "$RUNLOG" 2>/dev/null | cut -c1-200 | clean | sed 's/^/  /'
echo '```'

echo
echo "## 4. 何件 外れたか（**\`rc\` ではなく数で見る**）"
echo
echo '```'
if [ -f "$RUNLOG" ]; then
  OK="$(cnt '— 外れた' "$RUNLOG")"
  NG="$(cnt '押したが外れていない' "$RUNLOG")"
  EX="$(cnt ': 例外' "$RUNLOG")"
  printf '  外れた            %s 件\n' "$OK"
  printf '  押したが外れない  %s 件\n' "$NG"
  printf '  例外              %s 件\n' "$EX"
  echo
  grep -hE '=== 外した:|外す候補 合計|片思い:|今回の上限' "$RUNLOG" 2>/dev/null | tail -6 | cut -c1-190 | clean | sed 's/^/  /'
else
  echo "  **ログが無い**"
fi
echo
S1="$(state_n "$ST")"
printf '  状態ファイルの記録: %s → %s 件（差 %s）\n' "$S0" "$S1" "$((S1 - S0))"
echo "  ※ **状態ファイルが増えた数が、実際に外した数**（最上位ルール 13）"
echo '```'
rm -f "$RUNLOG"

echo
echo "## 5. いまのフォロー数（**一覧のキャッシュに今回の実測が入っている**）"
echo
echo '```json'
node -e '
  const fs = require("fs");
  let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
  catch (e) { console.log("  **キャッシュが読めない**"); process.exit(0); }
  const f = (j.following || []).length, g = (j.followers || []).length;
  console.log("  at " + j.at);
  console.log("  フォロー中 " + f + " / フォロワー " + g + "（差 " + (g - f) + "）");
  console.log("  ※ **外す前の数**。外したぶんは次回の取得で反映される");
' "$D/follow-balance-lists.json" 2>&1
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §4 の出方 | 次の一手 |"
echo "| --- | --- |"
echo "| **外れた 8 件 / 押したが外れない 0** | **成功。** 次で plist を置き、上限を段階的に上げる |"
echo "| 外れた < 8 で「押したが外れない」が在る | **DOM が変わっている。** ボタンの判定を見直す |"
echo "| 外れた 0 件 | **1 件も押せていない。** ログの末尾で理由を見る |"
echo "| rc=124 | 打ち切った。**上限 8 でも時間が足りない**なら段を分ける |"
echo
echo "**この 1 回の費用: \$0／回・\$0／日・\$0／月。** 定期化後も \$0（LLM を使わない）。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '何件 外れたか' "$OUT" 2>/dev/null; then
  echo "本番で 1 回 走らせた（上限 8 件） / $(basename "$OUT")"
else
  echo "**走らせられていない。レポートを確認すること** / $(basename "$OUT")"
fi
