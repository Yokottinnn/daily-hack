#!/bin/bash
# **「ロードされている」ではなく「実際に動いて結果を出した」を証明する。**
#
# Jordan の問い: 「これがちゃんと動いていることを証明して」
#
# 私が今まで示したのは launchctl list に載っていることだけ。**それは証明ではない。**
# 7/07〜8/09 の competitor-follower-follow は、ロードされたまま CDP 断で
# **1 件も実行していなかった。** 同じ形を見逃さないため、実行の痕跡で判定する。
#
# ## 証明に使うもの（すべて実機の痕跡）
#
#   1. 各ジョブのログの最終行と時刻   → 予定時刻に発火したか
#   2. launchctl の last exit status  → 実行して何を返したか
#   3. followed.json の件数           → 実際にフォローが増えたか
#   4. unfollow_log の件数            → 実際にアンフォローしたか
#   5. エラー行                       → 実行はしたが失敗していないか
#   6. CDP の応答                     → 動く前提が揃っているか
#
# **予定時刻を過ぎているのにログが無ければ「動いていない」と判定する。**
# 曖昧に「稼働」と書かない。
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
# **plutil -extract は使わない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/prove-loops.md"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

now_epoch="$(date +%s)"
today="$(date +%Y-%m-%d)"
today_utc="$(date -u +%Y-%m-%d)"

# label:短縮名:予定時刻(JST, カンマ区切り)
LOOPS="ai.openclaw.auto-thread-chainifier:auto-thread-chainifier:02:00
ai.openclaw.badge-followback:badge-followback:00:50
ai.openclaw.auto-detect-and-unfollow-inactive:auto_detect_and_unfollow_inactive:22:30
ai.openclaw.competitor-follower-follow:competitor-follower-follow:11:30,18:30
ai.openclaw.hashtag-follow:hashtag-follow:10:15,17:00"

{
echo "# 4 ループが実際に動いたかの証明（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **ロードされていること＝動いていること、ではない。**"
echo "> 7/07〜8/09 の competitor-follower-follow は載ったまま 1 件も実行していなかった。"
echo "> ここでは**実行の痕跡**だけで判定する。"

echo
echo "## 0. 動く前提: Chrome CDP"
echo
if curl -fsS --noproxy '*' --max-time 5 http://127.0.0.1:18810/json/version 2>/dev/null | head -c 120 | mask; then
  echo
  echo "→ **18810 応答あり。** ブラウザ経由の操作は成立しうる。"
else
  echo "→ **18810 が応答しない。載っていても 0 件実行になる。**"
fi

echo
echo "## 1. ジョブごとの実行痕跡"

printf '%s\n' "$LOOPS" | while IFS= read -r row; do
  [ -n "$row" ] || continue
  lbl="${row%%:*}"; rest="${row#*:}"
  name="${rest%%:*}"; times="${rest#*:}"

  echo
  echo "### $lbl"
  echo "- 予定発火（JST）: $times"

  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$lbl"; then
    st="$(launchctl list 2>/dev/null | awk -v l="$lbl" '$3==l {print "pid="$1" last_exit="$2}')"
    echo "- launchctl: 載っている / $st"
  else
    echo "- launchctl: **載っていない**"
  fi

  L="$W/logs/$name.log"
  if [ ! -f "$L" ]; then
    echo "- ログ: **存在しない → 一度も動いていない**"
    continue
  fi
  mt="$(date -r "$L" '+%Y-%m-%d %H:%M' 2>/dev/null)"
  mts="$(date -r "$L" '+%s' 2>/dev/null || echo 0)"
  age_h=$(( (now_epoch - mts) / 3600 ))
  echo "- ログ最終更新: $mt（$age_h 時間前） $(wc -l < "$L" | tr -d ' ') 行"

  # 予定時刻を過ぎているのに今日の記録が無いか
  cnt_today="$(grep -c "$today\|$today_utc" "$L" 2>/dev/null || true)"
  echo "- 本日の記録: ${cnt_today} 行"

  overdue=0
  for t in $(printf '%s' "$times" | tr ',' ' '); do
    h="${t%%:*}"; m="${t##*:}"
    sched=$(( 10#$h * 3600 + 10#$m * 60 ))
    nowsec=$(( $(date '+%H') * 3600 + $(date '+%M') * 60 ))
    [ "$nowsec" -gt "$sched" ] && overdue=1
  done
  if [ "$overdue" = "1" ] && [ "$cnt_today" = "0" ]; then
    echo "- **判定: 予定時刻を過ぎているのに本日の記録が無い → 動いていない**"
  elif [ "$cnt_today" != "0" ]; then
    echo "- **判定: 本日 実行された**"
  else
    echo "- 判定: まだ予定時刻前"
  fi

  echo "- 直近 5 行:"
  tail -5 "$L" 2>/dev/null | mask | cut -c1-150 | sed 's/^/      /'

  E="$W/logs/$name-err.log"
  if [ -f "$E" ] && [ -s "$E" ]; then
    echo "- **エラーログ 直近 3 行:**"
    tail -3 "$E" 2>/dev/null | mask | cut -c1-150 | sed 's/^/      /'
  fi
done

echo
echo "## 2. 結果の数字（動いていれば動く）"
echo
/usr/bin/python3 - <<'PY' 2>&1 || echo "（読めない）"
import json, os, glob, datetime
w = os.path.expanduser("~/.openclaw/workspace")

def n(p):
    try:
        d = json.load(open(p))
        if isinstance(d, list): return len(d)
        if isinstance(d, dict):
            for k in ("followed", "entries", "items", "list", "unfollow_log", "handled"):
                if isinstance(d.get(k), list): return len(d[k])
            return len(d)
    except Exception:
        return None

for pat, label in [("data/followed.json", "フォロー済み"),
                   ("data/unfollow-cleanup.json", "アンフォロー記録"),
                   ("state/unfollow-cleanup.json", "アンフォロー記録(state)"),
                   ("data/incoming-replies-handled.json", "受信リプ処理済み"),
                   ("state/incoming-reply-state.json", "自動返信")]:
    p = os.path.join(w, pat)
    if os.path.exists(p):
        m = datetime.datetime.fromtimestamp(os.path.getmtime(p)).strftime("%m-%d %H:%M")
        print(f"- {label}（{pat}）: {n(p)} 件 / 更新 {m}")

# フォロワー推移
log = os.path.join(w, "logs/follower-snapshot.log")
if os.path.exists(log):
    import re
    pairs = {}
    for line in open(log, errors="replace"):
        md = re.search(r'(\d{4}-\d{2}-\d{2})', line)
        mc = re.search(r'"count_today":(\d+)', line)
        if md and mc:
            pairs[md.group(1)] = int(mc.group(1))
    last = sorted(pairs.items())[-7:]
    print("- フォロワー推移（直近7日分の記録）:")
    for d, c in last:
        print(f"      {d}  {c}")
PY

echo
echo "## 3. 返信ジョブの停止状態（022 が効いたか）"
echo
for lbl in ai.openclaw.comment-warmup ai.openclaw.incoming-reply-watcher \
           ai.openclaw.auto-thread-chainifier; do
  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$lbl"; then
    printf '  %-42s %s\n' "$lbl" "**まだ稼働（停止できていない）**"
  else
    printf '  %-42s %s\n' "$lbl" "停止"
  fi
done
} > "$OUT" 2>&1

ran="$(grep -c '判定: 本日 実行された' "$OUT" 2>/dev/null || true)"
dead="$(grep -c '判定: 予定時刻を過ぎているのに' "$OUT" 2>/dev/null || true)"
echo "本日実行=${ran}件 / 動いていない=${dead}件 / $(basename "$OUT")"
