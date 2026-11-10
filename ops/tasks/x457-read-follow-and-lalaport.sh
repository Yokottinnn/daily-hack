#!/bin/bash
# x457（2026-11-10・読むだけ・$0）: 利用者「フォローとかアンフォローも（ちゃんと動いてる？）」「12日木曜日の予約投稿ってもうちゃんと決まってる？」。
# ① 11/9〜11/10 の follow-balance（外す）と badge-followback / competitor-follower-follow（フォロー）の結果とヘッダーの数
# ② ららぽーとの 1 回だけの予約ジョブが載っているか・キューに積まれているか。**何も書き換えない・押さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; U="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/x457-read-follow-and-lalaport.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x|twitter)\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1.com/<伏せ>#g'; }
{
echo "# フォロー・外す・11/12 の予約（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## follow-balance（11/9〜11/10）"; echo '```'
for d in 2026-11-09 2026-11-10; do
  s="$(grep -c "^\[$d.*follow-balance start" "$L/follow-balance.log" 2>/dev/null | head -1)"
  u="$(grep "^\[$d" "$L/follow-balance.log" 2>/dev/null | awk '!seen[$0]++' | grep -c '外れた' | head -1)"
  e="$(grep "^\[$d" "$L/follow-balance.log" 2>/dev/null | awk '!seen[$0]++' | grep -c 'CDP に繋がらない' | head -1)"
  printf '%s  起動 %s 回 ／ 外れた %s 件 ／ CDP に繋がらない %s 回\n' "$d" "${s:-0}" "${u:-0}" "${e:-0}"
done
echo "--- 直近の回（末尾 12 行）"
grep -v '^Call log\|<ws' "$L/follow-balance.log" 2>/dev/null | awk '!seen[$0]++' | tail -n 12 | cut -c1-200 | hide
echo '```'
echo; echo "## フォローした件数（11/9〜11/10）"; echo '```'
for f in badge-followback.log competitor-follower-follow.log; do
  for d in 2026-11-09 2026-11-10; do n="$(grep "$d" "$L/$f" 2>/dev/null | grep -ciE 'followed|フォローした|✓ follow|follow ok' | head -1)"; printf '%-34s %s  %s 件\n' "$f" "$d" "${n:-0}"; done
  tail -n 3 "$L/$f" 2>/dev/null | cut -c1-180 | hide
done
echo '```'
echo; echo "## ジョブ"; echo '```'
for lb in ai.openclaw.follow-balance ai.openclaw.mutual-prune ai.openclaw.badge-followback ai.openclaw.competitor-follower-follow; do
  printf '%-44s ' "$lb"; launchctl print "gui/$U/$lb" 2>/dev/null | grep -E '^\s+(state|runs|last exit code) =' | head -3 | tr -s ' \n' ' ' || echo "載っていない"; echo
done
echo '```'
echo; echo "## 11/12（木）12:00 ららぽーとの予約"; echo '```'
LB=com.dailyhack.publish-lalaport-toyosu-black-friday-2026-oneshot
if launchctl print "gui/$U/$LB" >/dev/null 2>&1; then launchctl print "gui/$U/$LB" | grep -E '^\s+(state|runs) =|Month|Day|Hour|Minute' | head -8; echo "  → 載っている"; else echo "  → **載っていない**"; fi
ls -la "$HOME/Library/LaunchAgents/$LB.plist" 2>&1 | sed "s#$HOME#~#"
plutil -p "$HOME/Library/LaunchAgents/$LB.plist" 2>/dev/null | grep -A6 StartCalendarInterval
node -e 'const q=require(process.argv[1]);const r=(Array.isArray(q)?q:(q.queue||q.items||q.posts)).find(x=>x&&x.id==="x-news-20261112-lalaport-bf");console.log(r?JSON.stringify({status:r.status,auto_publish:r.auto_publish,scheduled_at:r.scheduled_at,x_tweet_id:r.x_tweet_id||null,images:(r.image_path||"").split(",").length}):"キューに無い")' "$W/data/post_queue.json" 2>&1
echo '```'
} > "$OUT" 2>&1
grep -E '→' "$OUT" | head -2
exit 0
