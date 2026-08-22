#!/bin/bash
# フォロワー目標を再設定する。
#
# 旧設定は target=200 / deadline=2026-07-31 / baseline=161(7/04) で、
# **既に達成済み（現在 207）かつ期限切れ**。追う数字が無い状態だった。
#
# 新目標: 2026-09-30 までに 300 人（Jordan の指定）
#
# **baseline は決め打ちしない。** follower-snapshot.log の最新 count_today を読む。
# 今日までに、推測で値を書いて 3 回外している。
#
# **秘密を出力しないこと。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
CFG="$W/data/follower-target-config.json"
LOG="$W/logs/follower-snapshot.log"

[ -f "$CFG" ] || { echo "設定ファイルが無い: data/follower-target-config.json"; exit 1; }

# 最新の実測フォロワー数を取り出す
latest="$(grep -o '"count_today":[0-9]*' "$LOG" 2>/dev/null | tail -1 | grep -oE '[0-9]+' || true)"
if [ -z "$latest" ]; then
  echo "follower-snapshot.log から現在値を読めない"
  exit 1
fi

python3 - "$CFG" "$latest" <<'PY'
import json, sys, datetime, shutil
cfg, latest = sys.argv[1], int(sys.argv[2])
shutil.copy(cfg, cfg + ".bak")          # 上書き前に必ず退避する
d = json.load(open(cfg))
old = dict(d)
d["target"] = 300
d["deadline"] = "2026-09-30"
d["baseline_count"] = latest
d["baseline_date"] = datetime.date.today().isoformat()
json.dump(d, open(cfg, "w"), ensure_ascii=False, indent=2)
days = (datetime.date(2026, 9, 30) - datetime.date.today()).days
need = 300 - latest
print("旧: target=%s deadline=%s baseline=%s" % (old.get("target"), old.get("deadline"), old.get("baseline_count")))
print("新: target=300 deadline=2026-09-30 baseline=%d (%s)" % (latest, d["baseline_date"]))
print("必要: +%d 人 / %d 日 = 1日あたり %.1f 人" % (need, days, need / days if days else 0))
PY

# **監視ジョブは勝手に戻さない。** 2026-07-04 に意図的に .bak 化された可能性がある。
# 中身だけ報告し、戻すかどうかは人が決める。
BAK="$(ls "$HOME/Library/LaunchAgents"/ai.openclaw.follower-target-monitor.plist.bak.* 2>/dev/null | head -1)"
if [ -n "$BAK" ]; then
  echo "monitor の .bak: $(basename "$BAK")"
  echo "  program: $(plutil -p "$BAK" 2>/dev/null | awk '/ProgramArguments/,/\)/' | grep -oE '"[^"]+"' | tr -d '"' | grep -v ProgramArguments | tr '\n' ' ' | cut -c1-160)"
  echo "  interval: $(plutil -extract StartInterval raw "$BAK" 2>/dev/null || echo '無し')"
else
  echo "monitor の .bak は見つからない"
fi
