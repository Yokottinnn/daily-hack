#!/bin/bash
# **最優先。返信を今すぐ止めて、除外の仕組みを確定させる。**
#
# Jordan から「売春系のアカウントに返信するな。本当に NG。すぐ禁止にして」
# という指示。**フィルタを作るまでの間、1 件も打たせない。**
#
# 順番が大事。
#   1. **先に止める。** 仕組みを調べてから止めるのでは、その間に打たれる
#   2. 止めたことを実体（launchctl）で確認する
#   3. そのうえで除外の仕組みを調べ、次のサイクルでフィルタを入れる
#
# 止めるのは**返信を打つジョブだけ。** フォロー系（②③④）は相手に
# 返信しないので止めない。フォロワー増加を無駄に止めないため。
#
# **止めても失うのは 1 日 8 件の返信だけ。** 誤爆の方が高くつく。
#
# **読み取り部分はハンドル名を出さない。** 結果は公開リポジトリに載る。
# **plutil -extract は使わない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/halt-replies.md"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$1"; }

# 返信を打つジョブ。フォロー系は含めない
REPLY_JOBS="ai.openclaw.comment-warmup ai.openclaw.incoming-reply-watcher ai.openclaw.auto-thread-chainifier"

{
echo "# 返信の緊急停止と、除外の仕組みの確定（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"

echo
echo "## 1. 停止（最優先。調べる前に止める）"
echo
for lbl in $REPLY_JOBS; do
  if ! loaded "$lbl"; then
    echo "- $lbl: 元から未ロード"
    continue
  fi
  launchctl bootout "gui/$UID_N/$lbl" >/dev/null 2>&1
  sleep 1
  if loaded "$lbl"; then
    echo "- $lbl: **停止に失敗（まだ載っている）**"
    launchctl bootout "gui/$UID_N/$lbl" 2>&1 | mask | head -2 | sed 's/^/      /'
  else
    echo "- $lbl: **停止した**"
  fi
done

echo
echo "### 停止の確認（launchctl の実体）"
for lbl in $REPLY_JOBS; do
  printf '  %-42s %s\n' "$lbl" "$(loaded "$lbl" && echo '**まだ稼働**' || echo '停止')"
done

echo
echo "### フォロー系は止めていない（返信を打たないため）"
for lbl in ai.openclaw.badge-followback ai.openclaw.competitor-follower-follow \
           ai.openclaw.hashtag-follow ai.openclaw.auto-detect-and-unfollow-inactive; do
  printf '  %-48s %s\n' "$lbl" "$(loaded "$lbl" && echo 稼働 || echo 未ロード)"
done

echo
echo "### 勝手に戻すジョブがいないか"
echo
echo "> 2026-08-15 に、bootout したはずの comment-warmup が載り続けた実績がある。"
launchctl list 2>/dev/null | awk '{print $3}' \
  | grep -E 'keeper|guard|watchdog|ensure|supervis|heal' | sed 's/^/  - /'

echo
echo "## 2. 除外リストらしき data / state ファイル"
echo
for d in data state config; do
  for f in "$W/$d"/*.json; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in
      *black*|*block*|*ng*|*exclude*|*skip*|*deny*|*mute*|*banned*|*whitelist*|*allow*) ;;
      *) continue ;;
    esac
    n="$(/usr/bin/python3 -c "
import json
try:
    d=json.load(open('$f'))
    if isinstance(d,list): print('list %d件' % len(d))
    elif isinstance(d,dict): print('dict keys=%s' % ', '.join(list(d.keys())[:8]))
    else: print(type(d).__name__)
except Exception: print('読めない')
" 2>/dev/null)"
    echo "- $d/$b: $n  更新=$(date -r "$f" '+%m-%d %H:%M' 2>/dev/null)"
  done
done
echo "（該当なしなら空）"

echo
echo "## 3. 返信対象を選ぶスクリプトの除外判定"
echo
for f in comment-warmup.js comment-orchestrator.sh asuka-fill.js \
         incoming-reply-watcher.js _cmr.js auto-thread-chainifier.js; do
  S="$W/scripts/$f"
  [ -f "$S" ] || { echo "### $f: 存在しない"; echo; continue; }
  echo "### $f（$(wc -l < "$S" | tr -d ' ') 行）"
  echo "除外に関わる行:"
  grep -nE 'blacklist|blocklist|denylist|exclude|skip|ng_|NG_|banned|mute|filter|isSpam|spam' "$S" 2>/dev/null \
    | mask | cut -c1-140 | head -12
  echo "読み込むリスト:"
  grep -oE "(data|state|config)/[A-Za-z0-9._-]+" "$S" 2>/dev/null | sort -u | head -10
  echo
done

echo
echo "## 4. NG 語彙の仕組みが既にあるか"
echo
echo "> 語そのものは出さず、**あるかどうかと件数だけ**。"
found=0
for S in "$W"/scripts/*.js "$W"/scripts/*.sh; do
  [ -f "$S" ] || continue
  hit="$(grep -ciE 'ng_?words|ngword|badwords|forbidden|adult|r18|sensitive|nsfw' "$S" 2>/dev/null || true)"
  [ "$hit" != "0" ] && { echo "- $(basename "$S"): $hit 箇所"; found=1; }
done
[ "$found" = "0" ] && echo "**該当なし＝NG 語彙の仕組みが無い。新しく作る必要がある。**"

echo
echo "## 5. 返信相手をどこから拾っているか"
echo
for S in "$W/scripts/comment-warmup.js" "$W/scripts/comment-orchestrator.sh" "$W/scripts/_cmr.js"; do
  [ -f "$S" ] || continue
  echo "### $(basename "$S")"
  grep -nE 'search|query|targets|candidates|hashtag|timeline|explore' "$S" 2>/dev/null \
    | mask | cut -c1-140 | head -10
  echo
done
} > "$OUT" 2>&1

st=""
for lbl in $REPLY_JOBS; do
  launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$lbl" && st="$st ${lbl#ai.openclaw.}"
done
echo "返信ジョブ停止 / まだ稼働:${st:-なし} / $(basename "$OUT")"
