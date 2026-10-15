#!/bin/bash
# **商品紹介記事の表紙用の写真を Wikimedia Commons から取る（t299）。** クラウドからは 429（混雑）で取れないため。LLM 不使用・**$0**。
# 本体は scripts/fetch-commons-photo.py（ライセンス台帳 _manifest.json を一緒に書く）。結果は reports/hero-photos/<slug>/ に置く（CC0・PD・CC BY-SA のみ）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$RDIR/t299-hero-photos.md"; D="$RDIR/hero-photos"; mkdir -p "$D"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PY=""; for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do command -v "$c" >/dev/null 2>&1 && PY="$c" && break; done
S="$D/.fetch-commons-photo.py"; git -C "$REPO" fetch -q origin main; git -C "$REPO" show origin/main:scripts/fetch-commons-photo.py > "$S"
{ echo "# 表紙用の写真（t299・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; echo '```text'; } > "$OUT"
while IFS='|' read -r slug file || [ -n "$slug" ]; do
  [ -z "$slug" ] && continue
  "$PY" "$S" --file "$file" --key hero --dir "$D/$slug" >> "$OUT" 2>&1; echo "$slug rc=$?" >> "$OUT"; sleep 2
done <<'LIST'
pocket-wifi-comparison-2026|File:ZTE WF826A WiFi Router with SIM Card slot.jpg
home-router-wimax-comparison-2026|File:ELECOM WRC-300FEBK WPS WiFi router.jpg
hikari-cashback-comparison-2026|File:Optical fiber cable-01ASD.jpg
overseas-esim-wifi-comparison-2026|File:In flight above scattered clouds (Unsplash).jpg
hotel-booking-sites-2026|File:Japanese hotel room at Hawaiians.jpg
LIST
for q in "Haneda Airport Japan Airlines aircraft" "Luxury handbags shop window" "Smartphones pile used"; do echo "== search: $q" >> "$OUT"; "$PY" "$S" --search "$q" --limit 10 >> "$OUT" 2>&1; sleep 2; done
echo '```' >> "$OUT"; find "$D" -name '*.jpg' | wc -l >> "$OUT"; head -c 3500 "$OUT"
