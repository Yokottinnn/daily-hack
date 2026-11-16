#!/bin/bash
# **A8 の提携中の控えを、11/13 の 394 件の結果から戻す（t699・affiliate）。ファイルを 1 つ置くだけ・ASP に触らない・$0。**
# 11/14 に一覧が 100 件で止まった結果で reports/board/asp-probe/a8partnered.json を上書きし、控え（名前・報酬）が失われた。
# そのため毎朝の読み取りが詳細を 1 日 80 件ずつ開き直し、rows が 396 件中 180（11/15）・260（11/16）だった（blog3 の依頼・依頼表 2026-11-16）。
# ops/heartbeat の 11/13 の朝のコミット（b2d06588）にある 394 件を reports/asp-probe/a8partnered-cache-20261113.json に置く。
# asp-probe.mjs は reports/asp-probe/a8partnered*.json を控えとして読むので、翌朝から詳細を開き直さずに済む。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t699-a8partnered-restore-cache.md"
DEST="$RDIR/asp-probe/a8partnered-cache-20261113.json"
mkdir -p "$RDIR/asp-probe"
{
echo "# A8 の提携中の控えを 11/13 の結果から戻す（$(date '+%Y-%m-%d %H:%M:%S') JST）"
if git -C "$RDIR" show b2d06588:reports/board/asp-probe/a8partnered.json > "$DEST.tmp" 2>/dev/null && [ -s "$DEST.tmp" ]; then
  mv "$DEST.tmp" "$DEST"
  echo "- 置いた: reports/asp-probe/$(basename "$DEST")（$(grep -c '"id"' "$DEST") 件）"
else
  rm -f "$DEST.tmp"
  git -C "$RDIR" fetch -q origin ops/heartbeat 2>/dev/null
  if git -C "$RDIR" show b2d06588:reports/board/asp-probe/a8partnered.json > "$DEST" 2>/dev/null && [ -s "$DEST" ]; then
    echo "- 置いた（fetch のあと）: $(grep -c '"id"' "$DEST") 件"
  else
    rm -f "$DEST"; echo "- ⚠️ コミット b2d06588 が読めなかった（$(git -C "$RDIR" rev-parse --show-toplevel 2>&1 | head -1)）"
  fi
fi
} > "$OUT" 2>&1
echo "t699 / $(basename "$OUT")"
