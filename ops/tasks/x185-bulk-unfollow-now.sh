#!/bin/bash
# **まとめてアンフォローする。上限 30 件。理由も 1 件ごとに出す。費用 $0。**
#
# ## 指示（2026-09-28 00 時台）
#
#   > 今の時点でフォロー数が増えすぎてるので、まとめてアンフォロしてよ
#   > ボタンが見つからないってどう言うこと？ それ何かおかしい気がするのですぐに調べて
#
# **刻まない。** 上限 8 件 の段階的な引き上げをやめて、候補ぶん まとめて外す。
#
# ## 「ボタンが見つからない」の 4 通りを、ここで切り分ける
#
# 本番初回（22:46）は 8 件 中 4 件 が「フォロー中のボタンが無い」で飛んだ。
# **4 秒 で終わっていた**（外れた 2 件 は 7〜10 秒）ので ① が濃厚だが、未確認。
#
#   ① 描画前に見に行った        → `x183` で出るまで最大 11 秒 待つようにした
#   ② 凍結・削除               → ボタンは元から無い。**候補から除くべき**
#   ③ ブロックされた           → 同じく外せない
#   ④ 別のジョブが先に外した   → 実害なし（`mutual-prune` 等が載っている）
#
# **1 件ごとに理由を出し、最後に理由別の件数を並べる。** 断定しない。
#
# ## 時間について（最上位ルール 15 の目安を超える）
#
# **1 タスク 5 分 の目安を超える見込み**（判定 約 2 分 ＋ 30 件 × 約 8 秒 ＝ 約 6 分）。
# **まとめて外すという指示なので、分けずに 1 本で回す。** 上限は 480 秒。
# 一覧は取り直さず**キャッシュを使う**（`MODE=decide`）ので、その分 短い。
#
# ## 気をつけること
#
# - **`rc=0` は「外した」証拠にならない**（最上位ルール 13）。
#   状態ファイル `follow-balance-state.json` の**増分**で数える
# - **ハンドルは伏せる**（公開リポジトリに載る）
# - 打ち切られても**そこまでの分は外れている**。状態ファイルに残る
#
# ## 費用（最上位ルール 2-B）
#
# **LLM を呼ばない。** DOM 操作だけ。
#
#   1 回あたり   **$0**
#   1 日あたり   **$0**（このタスクは 1 回しか走らない）
#   1 か月あたり **$0**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
TARGET="$S/follow-balance.js"
ST="$D/follow-balance-state.json"
LF="$D/follow-balance-lists.json"
OUT="${OPS_REPORT_DIR:-/tmp}/bulk-unfollow.md"
RUNLOG="$W/.x185-run.log"

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
echo "# まとめてアンフォローする（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **刻まない。上限 30 件。** 「フォロー数が増えすぎている」との指示。"
echo "> **1 件ごとに理由を出す。** 「ボタンが無い」の正体を切り分ける。"
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
E="$(cnt 'ONEWAY_IGNORE_ENGAGED' "$TARGET")"
F="$(cnt 'process.exit(0)' "$TARGET")"
printf '  出るまで待つ           %s 箇所（1 以上が正）\n' "$A"
printf '  理由を出す             %s 箇所（1 以上が正）\n' "$B"
printf '  固定 3.5 秒 待ちの残り %s 箇所（0 が正）\n' "$C"
printf '  片思いの緩め           %s 箇所（2 以上が正）\n' "$E"
printf '  終了する処理           %s 箇所（5 以上が正）\n' "$F"
echo '```'
if [ "$A" -lt 1 ] || [ "$B" -lt 1 ] || [ "$C" -ne 0 ] || [ "$E" -lt 2 ] || [ "$F" -lt 5 ]; then
  echo
  echo "- **直しが入っていない。まとめて外すのは危険なので走らせない。**"
  echo "  （\`x183\` のレポート follow-balance-install.md を見る）"
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
if [ -f "$LF" ]; then
  node -e '
    const fs = require("fs");
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { console.log("  キャッシュが読めない"); process.exit(0); }
    const f = (j.following || []).length, g = (j.followers || []).length;
    const ageH = (Date.now() - new Date(j.at || 0).getTime()) / 3600000;
    console.log("  一覧のキャッシュ: " + (isFinite(ageH) ? ageH.toFixed(2) : "?") + " 時間 前");
    console.log("  フォロー中 " + f + " / フォロワー " + g + "（差 " + (g - f) + "）");
  ' "$LF" 2>&1
else
  echo "  **キャッシュが無い。取り直しから始まる（その分 遅い）**"
fi
echo '```'

echo
echo "## 3. まとめて外す（上限 30 件・上限 480 秒）"
echo
echo "**キャッシュを使う**（`MODE=decide`）。取り直さないぶん、外す時間に回す。"
echo
echo '```'
T0="$(date +%s)"
if [ -f "$LF" ]; then
  MODE=decide MIN_UNFOLLOW=30 MAX_UNFOLLOW=30 DECIDE_BUDGET_S=120 MAX_PROFILE_READS=30 CACHE_MAX_H=12 \
    run_limited 480 "$RUNLOG" node "$TARGET"
  RC=$?
else
  MIN_UNFOLLOW=30 MAX_UNFOLLOW=30 LIST_BUDGET_S=100 DECIDE_BUDGET_S=110 MAX_PROFILE_READS=30 \
    run_limited 480 "$RUNLOG" node "$TARGET"
  RC=$?
fi
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **480 秒 で打ち切った。そこまでの分は外れている**' || echo '← 自分で終わった' )"
echo
echo "  --- 判定 ---"
grep -hE '片思い:|相互:|今回の上限|① 片思いから|守った内訳|プロフィールを開いた|外す候補' "$RUNLOG" 2>/dev/null \
  | tail -8 | cut -c1-190 | clean | sed 's/^/    /'
echo
echo "  --- 1 件ごと（**理由つき**）---"
grep -hE '✂|ボタンが無い|押したが外れていない|: 例外|=== 外した:' "$RUNLOG" 2>/dev/null \
  | tail -45 | cut -c1-280 | clean | sed 's/^/    /'
echo '```'

echo
echo "## 4. 結果"
echo
echo '```'
OK="$(cnt '— 外れた' "$RUNLOG")"
NB="$(cnt 'ボタンが無い' "$RUNLOG")"
NG="$(cnt '押したが外れていない' "$RUNLOG")"
EX="$(cnt ': 例外' "$RUNLOG")"
S1="$(state_n "$ST")"
printf '  外れた            %s 件\n' "$OK"
printf '  ボタンが無い      %s 件\n' "$NB"
printf '  押したが外れない  %s 件\n' "$NG"
printf '  例外              %s 件\n' "$EX"
echo
printf '  状態ファイル: %s → %s 件（差 **%s**）← **実際に外した数**\n' "$S0" "$S1" "$((S1 - S0))"
echo '```'

echo
echo "## 5. 「ボタンが無い」の正体（**理由別に数える**）"
echo
echo "**ここが今回いちばん知りたいこと。**"
echo
echo '```'
if [ "$NB" = "0" ]; then
  echo "  **1 件も無い。① 描画前に見ていたのが原因だった**（待つようにして解消）"
else
  printf '  ボタンが無い %s 件 の理由別:\n\n' "$NB"
  for k in suspended notfound locked empty; do
    n="$(grep -h 'ボタンが無い' "$RUNLOG" 2>/dev/null | grep -c "\"$k\":true" | head -1)"
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    case "$k" in
      suspended) lbl="② 凍結されている" ;;
      notfound)  lbl="② 削除・存在しない" ;;
      locked)    lbl="③ 鍵アカウント" ;;
      empty)     lbl="① ページが読めていない" ;;
    esac
    printf '    %-24s %s 件\n' "$lbl" "$n"
  done
  echo
  echo "  --- 在ったボタン（**\"フォローする\" なら ④ 既に外れている**）---"
  grep -h 'ボタンが無い' "$RUNLOG" 2>/dev/null | grep -o '"follow_btns":"[^"]*"' \
    | sort | uniq -c | sort -rn | head -6 | sed 's/^/    /'
fi
echo '```'
rm -f "$RUNLOG"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §5 の出方 | 意味 | 次 |"
echo "| --- | --- | --- |"
echo "| ボタンが無い 0 件 | **①だった。** 待つようにして解消 | 上限をこのまま回す |"
echo "| \`凍結\` / \`削除\` が多い | **②。** そのアカウントは元から外せない | **候補から除く条件を足す** |"
echo "| \`follow_btns\` が \"フォローする\" | **④。** 既に外れている | 一覧の取り直しを早める |"
echo "| \`ページが読めていない\` が多い | **①がまだ残る。** 待ちが足りない | 待ちを 11 秒 → 20 秒 に伸ばす |"
echo
echo "**\$0／回・\$0／日・\$0／月。** LLM を呼ばない。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'の正体' "$OUT" 2>/dev/null; then
  echo "まとめて外した / $(basename "$OUT")"
else
  echo "**外せていない。レポートを確認すること** / $(basename "$OUT")"
fi
