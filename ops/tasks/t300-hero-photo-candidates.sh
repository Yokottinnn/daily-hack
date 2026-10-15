#!/bin/bash
# **表紙の写真の候補を多めに取る（t300）。** t299 のうち 2 枚は表紙に向かなかった（製造番号のラベル・細長いケーブル）。
# 検索ごとに横長の上位 4 枚を取り、クラウドで目で見て選ぶ。CC0・PD・CC BY・CC BY-SA のみ（スクリプトが非フリーを弾く）。LLM 不使用・**$0**。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$RDIR/t300-hero-candidates.md"; D="$RDIR/hero-cands"; mkdir -p "$D"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PY=""; for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do command -v "$c" >/dev/null 2>&1 && PY="$c" && break; done
S="$D/.fetch-commons-photo.py"; git -C "$REPO" fetch -q origin main; git -C "$REPO" show origin/main:scripts/fetch-commons-photo.py > "$S"
{ echo "# 表紙の写真の候補（t300・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; echo '```text'; } > "$OUT"
while IFS='|' read -r key q || [ -n "$key" ]; do
  [ -z "$key" ] && continue
  echo "== $key: $q" >> "$OUT"
  "$PY" "$S" --search "$q" --limit 15 > "$D/.s.txt" 2>&1; cat "$D/.s.txt" >> "$OUT"
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    f="$(printf '%s' "$line" | grep -o 'File:.*$')"; wh="$(printf '%s' "$line" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+x[0-9]+$/) print $i}')"
    [ -z "$f" ] && continue; w="${wh%x*}"; h="${wh#*x}"; [ -n "$w" ] && [ -n "$h" ] && [ "$w" -gt "$h" ] || continue
    n=$((n+1)); "$PY" "$S" --file "$f" --key "c$n" --dir "$D/$key" >> "$OUT" 2>&1; sleep 2
    [ "$n" -ge 4 ] && break
  done < "$D/.s.txt"
done <<'LIST'
pocket-wifi|Mobile hotspot device
pocket-wifi2|Portable Wi-Fi router Japan
hikari|Fiber optic illuminated
hikari2|Optical fibre bundle light
flight|Japan Airlines Boeing 777 Haneda
kaitori|Leather handbags display
LIST
echo '```' >> "$OUT"; find "$D" -name '*.jpg' | wc -l >> "$OUT"; head -c 3500 "$OUT"
