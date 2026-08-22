#!/bin/bash
# ループ④（こちらから新規にフォローしに行く＝能動フォロー）を調べる。
#
# **スクリプト名を決め打ちしない。** ②③と違い、実機に何があるのか未確認。
# 今日までに「無い」と決めつけて外し、「これだ」と決めつけて外している。
# まず follow を含むものを全部並べ、先頭のコメントで用途を見分ける。
#
# **ロードはしない。** フォロー操作は相手に通知が飛ぶ。
# 上限を知らないまま載せると、1 日に何百件も打ちうる。
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。ハンドル名は出さない。
set -uo pipefail

W="$HOME/.openclaw/workspace"
mask() { sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g'; }

echo "## follow を含むスクリプト（全部）"
ls -1 "$W/scripts" 2>/dev/null | grep -i follow

echo
echo "## それぞれの用途（先頭のコメント 6 行）"
for S in "$W"/scripts/*follow*; do
  [ -f "$S" ] || continue
  echo
  echo "### $(basename "$S")  $(wc -l < "$S" | tr -d ' ') 行"
  head -12 "$S" 2>/dev/null | grep -E '^\s*(//|/\*|\*|#)' | head -6 | mask | cut -c1-120
done

echo
echo "## 上限らしき定数（能動フォローは、ここを知らずに載せられない）"
for S in "$W"/scripts/*follow*; do
  [ -f "$S" ] || continue
  hits="$(grep -nE '(MAX|LIMIT|CAP|PER_|_PER|DAILY|HOURLY|INTERVAL|DELAY|THRESHOLD)[A-Za-z_]*[[:space:]]*[=:][[:space:]]*[0-9]' "$S" 2>/dev/null | mask | cut -c1-120 | head -8)"
  [ -n "$hits" ] && { echo; echo "### $(basename "$S")"; printf '%s\n' "$hits"; }
done

echo
echo "## follow を含む plist（ロード状態つき）"
for P in "$HOME/Library/LaunchAgents"/*follow*; do
  [ -f "$P" ] || continue
  n="$(basename "$P")"
  lbl="${n%.plist}"
  loaded="$(launchctl list 2>/dev/null | grep -c "$lbl" || true)"
  echo "- $n / launchctl=${loaded}件 / StartInterval=$(plutil -extract StartInterval raw "$P" 2>/dev/null || echo '無し')"
done
ls "$HOME/Library/LaunchAgents"/*follow* >/dev/null 2>&1 || echo "（follow を含む plist は無い）"

echo
echo "## 対象リストらしき data ファイル（件数のみ・中身は出さない）"
python3 - <<'PY' 2>/dev/null || echo "（読めない）"
import json, os, glob
w = os.path.expanduser("~/.openclaw/workspace")
seen = set()
for p in sorted(glob.glob(w + "/data/*.json") + glob.glob(w + "/state/*.json")):
    b = os.path.basename(p)
    if not any(k in b.lower() for k in ("follow", "target", "candidate", "queue")):
        continue
    if b in seen:
        continue
    seen.add(b)
    try:
        d = json.load(open(p))
    except Exception:
        print("- %s: 読めない" % b); continue
    if isinstance(d, list):
        print("- %s: list len=%d" % (b, len(d)))
    else:
        parts = []
        for k, v in list(d.items())[:10]:
            if isinstance(v, (list, dict)):
                parts.append("%s=%d件" % (k, len(v)))
            elif isinstance(v, (int, float, bool)) or v is None:
                parts.append("%s=%s" % (k, v))
            else:
                parts.append("%s=<略>" % k)
        print("- %s: %s" % (b, " / ".join(parts)))
PY

echo
echo "## ログ（follow を含むもの・直近2行・先頭100字）"
for L in "$W"/logs/*follow*; do
  [ -f "$L" ] || continue
  echo "### $(basename "$L")  更新=$(date -r "$L" -u +%Y-%m-%dT%H:%MZ 2>/dev/null || echo '不明')"
  tail -2 "$L" 2>/dev/null | mask | cut -c1-100
done
ls "$W"/logs/*follow* >/dev/null 2>&1 || echo "（follow を含むログは無い）"
