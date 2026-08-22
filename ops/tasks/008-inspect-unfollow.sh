#!/bin/bash
# ループ③（フォローバックしてくれない相手のアンフォロー）を調べる。
#
# **ロードはしない。** このジョブは他人のフォローを外す＝取り消せない操作をする。
# 発火条件・1 回あたりの上限・除外リストの効き方が分からないまま載せると、
# 間違えた相手を外しても戻せない。実際に `audit-wrong-unfollows` という
# 監査スクリプト名が実機に見えており、過去に誤アンフォローがあった形跡がある。
#
# 実機の状態: plist が無く、ログも一度も無い＝**一度も動いていない。**
# 現在 followed=153 / フォロワー 207 / current_ratio=1.26 / unfollow_log=49件 / phase=A
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。ハンドル名は出さない。
set -uo pipefail

W="$HOME/.openclaw/workspace"

echo "## スクリプトの所在"
ls -1 "$W/scripts" 2>/dev/null | grep -iE 'unfollow|follow' | head -20

for f in auto_detect_and_unfollow_inactive.js audit-wrong-unfollows.js badge-followback.js; do
  S="$W/scripts/$f"
  echo
  echo "## $f"
  if [ ! -f "$S" ]; then echo "（存在しない）"; continue; fi
  echo "行数: $(wc -l < "$S" | tr -d ' ')"
  echo
  echo "### 上限・待機日数・しきい値（これが安全性を決める）"
  grep -nE '(MAX|LIMIT|CAP|PER_|_PER|DAYS|HOURS|THRESHOLD|RATIO|WHITELIST|BLACKLIST|DRY_RUN|PHASE)[A-Za-z_]*[[:space:]]*[=:]' "$S" 2>/dev/null \
    | sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g' | cut -c1-140 | head -25
  echo
  echo "### 環境変数（キー名のみ）"
  grep -oE 'process\.env\.[A-Z_]+' "$S" 2>/dev/null | sort -u | head -20
  echo
  echo "### 読み書きするファイル"
  grep -oE "(data|state|logs)/[A-Za-z0-9._-]+" "$S" 2>/dev/null | sort -u | head -15
  echo
  echo "### 除外の判定に使っている条件（行のみ）"
  grep -nE 'whitelist|blacklist|skip|exclude|protect' "$S" 2>/dev/null \
    | sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g' | cut -c1-140 | head -12
done

echo
echo "## plist の有無"
for n in auto_detect_and_unfollow_inactive auto-detect-and-unfollow-inactive unfollow audit-wrong-unfollows; do
  hit="$(ls -1 "$HOME/Library/LaunchAgents" 2>/dev/null | grep -i "$n" | tr '\n' ' ')"
  echo "- $n: ${hit:-無し}"
done

echo
echo "## unfollow-cleanup の状態（件数のみ・ハンドル名は出さない）"
python3 - <<'PY' 2>/dev/null || echo "（読めない）"
import json, os, glob
w = os.path.expanduser("~/.openclaw/workspace")
for p in glob.glob(w + "/data/*unfollow*.json") + glob.glob(w + "/state/*unfollow*.json"):
    try:
        d = json.load(open(p))
    except Exception:
        print("- %s: 読めない" % os.path.basename(p)); continue
    if isinstance(d, list):
        print("- %s: list len=%d" % (os.path.basename(p), len(d)))
    else:
        parts = []
        for k, v in list(d.items())[:12]:
            if isinstance(v, (list, dict)):
                parts.append("%s=%d件" % (k, len(v)))
            elif isinstance(v, (int, float, bool)) or v is None:
                parts.append("%s=%s" % (k, v))
            else:
                parts.append("%s=<略>" % k)
        print("- %s: %s" % (os.path.basename(p), " / ".join(parts)))
PY

echo
echo "## ログ（あれば直近3行・先頭100字・20字以上の英数字は伏せる）"
for l in auto_detect_and_unfollow_inactive unfollow-cleanup audit-wrong-unfollows; do
  if [ -f "$W/logs/$l.log" ]; then
    echo "### $l.log"
    tail -3 "$W/logs/$l.log" 2>/dev/null | sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g' | cut -c1-100
  else
    echo "### $l.log: 無し"
  fi
done
