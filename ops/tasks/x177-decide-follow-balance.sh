#!/bin/bash
# **キャッシュから判定して DRY で出す。1 件も外さない。費用 $0。**
#
# ## これは `x176` の続き
#
# `x176` が `data/follow-balance-lists.json` に一覧を書く。**ここでは取り直さない。**
# 分けた理由は、まとめて走らせると 900 秒 の上限に当たって
# **出力が 1 行も残らなかった**こと（`x164`・最上位ルール 15）。
#
# ## 何を見たいか
#
# **守る条件が効きすぎていないか / 効かなすぎていないか。** どちらも DRY で分かる。
#
#   外す順   ① 片思い（フォロバが無い）← いま誰も担当していない
#            ② 休眠（最終投稿が INACTIVE_DAYS より前）
#            ③ 大きいアカウント（フォロワーが BIG_FOLLOWERS 以上）
#   守る     反応をくれた人 ／ フォローから 7 日 未満 ／ 既存のホワイトリスト
#   上限     その日にフォローした数以上（読めなければ MIN_UNFOLLOW＝30）
#
# ## `DRY_RUN=1`。**1 件も外さない**
#
# 出力を見てから本番に切り替える。**このタスクでは切り替えない。**
#
# ## やらないこと
#
# **アンフォローしない。フォローもしない。一覧も取り直さない。plist も置かない。**
# **LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
TARGET="$S/follow-balance.js"
LF="$D/follow-balance-lists.json"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-decide.md"
RUNLOG="$W/.x177-run.log"

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

{
echo "# キャッシュから判定して DRY で出す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **DRY。1 件も外していない。** 一覧も取り直していない。"

echo
echo "## 1. 入力（\`x176\` が書いたキャッシュ）"
echo
echo '```'
if [ ! -f "$LF" ]; then
  echo "  **キャッシュが無い。判定できない。**"
  echo "  → \`x176\` のレポート（follow-lists-collect.md）を先に見る"
  echo '```'
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
node -e '
  const fs = require("fs");
  let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
  catch (e) { console.log("  **読めない: " + e.message + "**"); process.exit(0); }
  const f = j.following || [], g = j.followers || [];
  const ageH = (Date.now() - new Date(j.at || 0).getTime()) / 3600000;
  console.log("  at        " + j.at + "（" + (isFinite(ageH) ? ageH.toFixed(2) : "?") + " 時間 前）");
  console.log("  フォロー中 " + f.length + " 件 / フォロワー " + g.length + " 件");
  const lower = new Set(g.map((h) => String(h).toLowerCase()));
  const one = f.filter((h) => !lower.has(String(h).toLowerCase()));
  console.log("  片思い " + one.length + " 件 / 相互 " + (f.length - one.length) + " 件");
  console.log("");
  console.log("  **フォロー中 " + f.length + " ／ フォロワー " + g.length + "** ← 収支そのもの");
' "$LF" 2>&1 | clean
echo '```'

echo
echo "## 2. \`MODE=decide\` ＋ \`DRY_RUN=1\` で判定する"
echo
echo "**上限 260 秒 で打ち切る**（プロフィールを開く側は 200 秒 の持ち時間つき）。"
echo
echo '```'
T0="$(date +%s)"
MODE=decide DRY_RUN=1 DECIDE_BUDGET_S=200 MAX_PROFILE_READS=40 \
  run_limited 260 "$RUNLOG" node "$TARGET"
RC=$?
T1="$(date +%s)"
printf '  rc=%s / かかった秒数 %s %s\n' "$RC" "$((T1 - T0))" \
  "$( [ "$RC" = "124" ] && echo '← **260 秒 で打ち切った**' )"
echo
cat "$RUNLOG" 2>/dev/null | tail -70 | cut -c1-210 | clean | sed 's/^/  /'
echo '```'

echo
echo "## 3. 数を並べる（**守りが効きすぎていないか**）"
echo
echo '```'
if [ -f "$RUNLOG" ]; then
  for k in "フォロー中:" "フォロワー:" "片思い" "相互" "今回の上限" "プロフィールを開いた" "外す候補" "守った" "ホワイトリスト"; do
    grep -h "$k" "$RUNLOG" 2>/dev/null | tail -2 | cut -c1-190 | clean | sed 's/^/  /'
  done
else
  echo "  **ログが無い**"
fi
echo '```'
rm -f "$RUNLOG"

echo
echo "## 4. 本番に切り替えたら何件 外れるか"
echo
echo "**フォロー側は \`COMPETITOR_FOLLOW_DAILY_CAP=30\` で 1 日 2 回 撃つ。**"
echo "**追いつくには 1 日 30 件 以上 外せる必要がある。**"
echo
echo "| | |"
echo "| --- | --- |"
echo "| いまの \`mutual-prune\` | \`MAX_UNFOLLOW=8\`。しかも候補が 0 件 続き |"
echo "| \`follow-balance\` の上限 | その日のフォロー数以上（下限 30 / 絶対上限 60） |"
echo
echo "**§3 の「外す候補」が 30 に届いていなければ、守りか順位の条件を緩める必要がある。**"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §3 の「外す候補」 | 次の一手 |"
echo "| --- | --- |"
echo "| **30 件 以上** | **そのまま本番に切り替えてよい**（\`DRY_RUN\` を外す） |"
echo "| 1〜29 件 | **足りない。** 片思いの扱いと \`GRACE_DAYS\` を見る |"
echo "| **0 件** | **守りが効きすぎている。** 何が守ったかを §2 のログで見る |"
echo "| rc=124 で途中 | **持ち時間が足りない。** \`MAX_PROFILE_READS\` を下げるか 2 回に分ける |"
echo
echo "**1 件も外していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '数を並べる' "$OUT" 2>/dev/null; then
  echo "DRY で判定した（1 件も外していない） / $(basename "$OUT")"
else
  echo "**判定できていない。レポートを確認すること** / $(basename "$OUT")"
fi
