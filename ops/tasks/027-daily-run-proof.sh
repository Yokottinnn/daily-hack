#!/bin/bash
# **毎日の定時タスクが実際に走っているかを、直近 7 日ぶんの実績で示す。**
#
# Jordan の問い「いま毎日の定時タスクは実行されている？」
#
# ## 025 の判定にバグがあった
#
# badge-followback は「ログ最終更新 08-23 00:50」なのに「本日の記録 0 行」と出た。
# 予定発火は 00:50 で、判定した時刻は 18:00。**その日に動いているはずなのに 0。**
# 原因は日付照合で、ログの日付書式が `YYYY-MM-DD` 以外の可能性がある。
#
# ここでは**日付を決め打ちで照合しない。**
#   - ログの mtime（最終更新時刻）を第一の証拠にする。書式に依存しない
#   - あわせて直近 7 日ぶん、日ごとの行数を数える
#   - 日付らしき並びを複数の書式で拾う
#
# ## 判定
#
#   mtime が「予定発火の直近の時刻」より新しい → 動いている
#   mtime がそれより古い                        → 動いていない
#
# **曖昧に「稼働」と書かない。** 時刻の差で示す。
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/daily-proof.md"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
now="$(date +%s)"

# label:ログ名:予定発火(JST, カンマ区切り):役割
ROWS="ai.openclaw.comment-warmup:comment-warmup:12:00,16:00,19:00,22:00:返信（検索から）
ai.openclaw.incoming-reply-watcher:incoming-reply-watcher::受信リプへの返信
ai.openclaw.auto-thread-chainifier:auto-thread-chainifier:02:00:① 会話の継続
ai.openclaw.badge-followback:badge-followback:00:50:② フォロー返し
ai.openclaw.auto-detect-and-unfollow-inactive:auto_detect_and_unfollow_inactive:22:30:③ アンフォロー
ai.openclaw.competitor-follower-follow:competitor-follower-follow:11:30,18:30:④ 能動フォロー（競合）
ai.openclaw.hashtag-follow:hashtag-follow:10:15,17:00:④ 能動フォロー（タグ）
ai.openclaw.follower-snapshot:follower-snapshot::フォロワー記録"

{
echo "# 定時タスクは実際に走っているか（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **ロードされている＝動いている、ではない。** ログの更新時刻で判定する。"
echo "> 025 は日付の文字列照合に頼って誤判定した（ログはあるのに「本日 0 行」）。"
echo "> ここでは **mtime（書式に依存しない）** を第一の証拠にする。"

echo
echo "## 一覧"
echo
printf '%-46s %-22s %-10s %s\n' "ジョブ" "ログ最終更新" "経過" "判定"
printf '%-46s %-22s %-10s %s\n' "----" "----" "----" "----"

printf '%s\n' "$ROWS" | while IFS= read -r row; do
  [ -n "$row" ] || continue
  lbl="$(printf '%s' "$row" | cut -d: -f1)"
  name="$(printf '%s' "$row" | cut -d: -f2)"
  times="$(printf '%s' "$row" | cut -d: -f3-)"
  role="${times##*:}"
  times="${times%:*}"

  L="$W/logs/$name.log"
  if [ ! -f "$L" ]; then
    printf '%-46s %-22s %-10s %s\n' "${lbl#ai.openclaw.}" "ログ無し" "-" "**一度も動いていない**"
    continue
  fi
  mts="$(date -r "$L" '+%s' 2>/dev/null || echo 0)"
  mt="$(date -r "$L" '+%m-%d %H:%M' 2>/dev/null)"
  age_min=$(( (now - mts) / 60 ))
  if [ "$age_min" -lt 90 ]; then age="${age_min}分前"
  elif [ "$age_min" -lt 2880 ]; then age="$((age_min/60))時間前"
  else age="$((age_min/1440))日前"; fi

  # 予定発火が無いジョブ（間隔起動）は 24 時間以内なら動いているとみなす
  if [ -z "$times" ] || [ "$times" = "$role" ]; then
    if [ "$age_min" -lt 1440 ]; then v="**動いている**"; else v="**24時間 更新なし**"; fi
  else
    # 直近の予定発火時刻からの経過。1 日分の最大間隔 + 余裕で判定
    if [ "$age_min" -lt 1560 ]; then v="**動いている**"; else v="**$((age_min/1440))日 動いていない**"; fi
  fi
  printf '%-46s %-22s %-10s %s\n' "${lbl#ai.openclaw.}" "$mt" "$age" "$v"
done

echo
echo "## 直近 7 日の実行回数（日ごとのログ行数）"
echo
echo "> 日付の書式を決め打ちしない。3 通りで拾って多い方を採る。"
printf '%s\n' "$ROWS" | while IFS= read -r row; do
  [ -n "$row" ] || continue
  name="$(printf '%s' "$row" | cut -d: -f2)"
  L="$W/logs/$name.log"
  [ -f "$L" ] || continue
  echo
  echo "### $name"
  i=0
  while [ "$i" -lt 7 ]; do
    d="$(date -v-${i}d '+%Y-%m-%d' 2>/dev/null || date -d "$i days ago" '+%Y-%m-%d')"
    d2="$(date -v-${i}d '+%Y/%m/%d' 2>/dev/null || date -d "$i days ago" '+%Y/%m/%d')"
    d3="$(date -v-${i}d '+%m-%d' 2>/dev/null || date -d "$i days ago" '+%m-%d')"
    c1="$(grep -c "$d" "$L" 2>/dev/null || true)"
    c2="$(grep -c "$d2" "$L" 2>/dev/null || true)"
    c3="$(grep -c "$d3" "$L" 2>/dev/null || true)"
    c="$c1"; [ "$c2" -gt "$c" ] 2>/dev/null && c="$c2"; [ "$c3" -gt "$c" ] 2>/dev/null && c="$c3"
    printf '  %s  %s 行\n' "$d" "$c"
    i=$((i+1))
  done
done

echo
echo "## 成果の数字"
echo
/usr/bin/python3 - <<'PY' 2>&1 || echo "（読めない）"
import json, os, re, datetime
w = os.path.expanduser("~/.openclaw/workspace")
log = os.path.join(w, "logs/follower-snapshot.log")
if os.path.exists(log):
    pairs = {}
    for line in open(log, errors="replace"):
        md = re.search(r'(\d{4}-\d{2}-\d{2})', line)
        mc = re.search(r'"count_today":(\d+)', line)
        if md and mc:
            pairs[md.group(1)] = int(mc.group(1))
    items = sorted(pairs.items())[-10:]
    print("- フォロワー推移（記録のある直近10日）:")
    prev = None
    for d, c in items:
        diff = "" if prev is None else f"  ({c-prev:+d})"
        print(f"      {d}  {c}{diff}")
        prev = c
    if len(items) >= 2:
        d0, c0 = items[0]; d1, c1 = items[-1]
        days = (datetime.date.fromisoformat(d1) - datetime.date.fromisoformat(d0)).days or 1
        pace = (c1 - c0) / days
        left = (datetime.date(2026, 9, 30) - datetime.date.fromisoformat(d1)).days
        need = (300 - c1) / left if left > 0 else 0
        print(f"- 実測ペース: {pace:+.2f} 人/日（{d0}→{d1}）")
        print(f"- 目標に必要: +{need:.2f} 人/日（残り {left} 日で 300 人）")
        print(f"- このペースなら 9/30 時点: 約 {c1 + pace*left:.0f} 人")

for pat, label in [("data/followed.json", "フォロー済み"),
                   ("data/reply-followers.json", "返信きっかけのフォロー"),
                   ("data/incoming-reply-state.json", "自動返信の記録")]:
    p = os.path.join(w, pat)
    if os.path.exists(p):
        m = datetime.datetime.fromtimestamp(os.path.getmtime(p)).strftime("%m-%d %H:%M")
        try:
            d = json.load(open(p))
            if isinstance(d, list): n = len(d)
            elif isinstance(d, dict):
                n = next((len(v) for k, v in d.items() if isinstance(v, list)), len(d))
            else: n = "?"
        except Exception:
            n = "読めない"
        print(f"- {label}: {n} 件 / 更新 {m}")
PY

echo
echo "## NG 判定は入っているか"
echo
if [ -f "$W/scripts/reply-ng-check.cjs" ] && [ -f "$W/data/reply-ng-rules.json" ]; then
  echo "- モジュールとルール: **配置済み**"
else
  echo "- モジュールとルール: **未配置**"
fi
if grep -q 'reply-ng-check' "$W/scripts/comment-orchestrator.sh" 2>/dev/null; then
  echo "- comment-orchestrator.sh への組み込み: **済み**"
else
  echo "- comment-orchestrator.sh への組み込み: **まだ。売春垢を弾けていない**"
fi
} > "$OUT" 2>&1

alive="$(grep -c '動いている' "$OUT" 2>/dev/null || true)"
dead="$(grep -cE '動いていない|更新なし' "$OUT" 2>/dev/null || true)"
echo "動いている=${alive} / 止まっている=${dead} / $(basename "$OUT")"
