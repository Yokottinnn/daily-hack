#!/bin/bash
# フォロー施策の棚卸し。
#
# 「実装が無い」と判断して仕様書を書いたが、実物は揃っていた。
# **何が動いていて、何が止まっていて、数字がどう動いているか**を持ち帰る。
#
# **秘密を出力しないこと。** 件数と状態だけ。ハンドル名は出さない。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-inventory.md"

j() { # $1=file $2=python式（dに辞書が入る）
  python3 -c "
import json
try:
    d=json.load(open('$W/data/$1'))
    print($2)
except Exception as e:
    print('読めない')
" 2>/dev/null
}

{
  echo "# フォロー施策の棚卸し（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "## 1. ジョブがロードされているか"
  echo '```'
  launchctl list 2>/dev/null | grep -E 'openclaw|dailyhack' | awk '{print $1"\t"$2"\t"$3}'
  echo '```'
  echo
  echo "## 2. フォロー関連スクリプトの plist が存在するか"
  for s in badge-followback auto_detect_and_unfollow_inactive audit-wrong-unfollows \
           auto-thread-chainifier follower-snapshot follower-target-monitor comment-warmup; do
    p=$(ls "$HOME/Library/LaunchAgents" 2>/dev/null | grep -i "$s" | head -1)
    loaded=$(launchctl list 2>/dev/null | grep -c "$s")
    echo "- ${s}: plist=${p:-無し} / launchctl=${loaded}件"
  done
  echo
  echo "## 3. 数字（件数のみ・ハンドル名は出さない）"
  echo "- followed.json: $(j followed.json "'followed=%d件' % len(d.get('followed',[]))")"
  echo "- refollow-blacklist: $(j refollow-blacklist.json "'%d件 / last_updated=%s' % (len(d.get('handles',[])), d.get('last_updated'))")"
  echo "- unfollow-whitelist: $(j unfollow-whitelist.json "'%d件' % len(d.get('whitelist',[]))")"
  echo "- unfollow-cleanup: $(j unfollow-cleanup-state.json "'phase=%s / current_ratio=%s / unfollow_log=%d件 / halt_flags=%s' % (d.get('phase'), d.get('current_ratio'), len(d.get('unfollow_log',[])), d.get('halt_flags'))")"
  echo "- incoming-replies-handled: $(j incoming-replies-handled.json "'handled=%d件 / chain_counts=%s' % (len(d.get('handled',[])), str(d.get('chain_counts'))[:120])")"
  echo "- incoming-reply-state: $(j incoming-reply-state.json "'auto_replies=%s / seen=%d件 / replied_24h=%d件' % (d.get('auto_replies'), len(d.get('seen_reply_ids',[])), len(d.get('replied_authors_24h',[])))")"
  echo "- reply-followers: $(j reply-followers.json "'%d件' % len(d)")"
  echo
  echo "## 4. フォロワー数の推移（直近10件）"
  python3 -c "
import json
try:
    d=json.load(open('$W/data/follower-history.json'))
    s=d.get('snapshots',[])
    print('総スナップショット数: %d' % len(s))
    for x in s[-10:]:
        if isinstance(x,dict):
            print('  ', x.get('date') or x.get('at') or '?', '->', x.get('followers') or x.get('count') or x)
except Exception as e:
    print('読めない:', type(e).__name__)
" 2>/dev/null
  echo
  echo "## 5. 目標設定"
  echo "- $(j follower-target-config.json "'target=%s / deadline=%s / baseline=%s (%s)' % (d.get('target'), d.get('deadline'), d.get('baseline_count'), d.get('baseline_date'))")"
  echo
  echo "## 6. フォロー系ログの直近（値は伏せる）"
  for l in badge-followback auto_detect_and_unfollow_inactive follower-snapshot; do
    f="$W/logs/${l}.log"
    echo "### ${l}.log"
    if [ -f "$f" ]; then
      echo "最終更新: $(date -r "$f" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
      tail -3 "$f" 2>/dev/null | sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g' | cut -c1-100
    else
      echo "（ログ無し＝一度も動いていない可能性）"
    fi
  done
} > "$OUT" 2>&1

echo "書き出した: $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
