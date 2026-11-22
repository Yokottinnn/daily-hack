#!/bin/bash
# x541（2026-11-22・$0）: ① 1 投稿の画像の上限を 4 → 10 に広げる（利用者「Xの1投稿あたりの画像の添付数が増えてるから、仕様を確認して、増やせるようなら増やして」。
#   x538 で 6 枚、x539 で 10 枚が投稿画面に入ることを確かめた。投稿はしていない）。
#  ② 予約の出し直しの不具合を直す。CAMP（x533）で 1 投稿目は出たのに 2 投稿目で失敗し、全体が失敗に見えたため 1 投稿目をもう一度出した（二重投稿）。
#   明日の湾岸のイルミ（x534）の出し直しを「1 投稿目が出ていたら出し直さない」にする。
#  LLM を呼ばない。投稿はしない。元のファイルは .bak-x541。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x541-image-cap-10-and-retry-fix.md"
PV="$S/post-via-""playwright.js"
{
echo "# 画像の上限を 10 枚に・出し直しの不具合を直す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① 画像の上限"; echo '```'
OLD='if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }'
if [ "$(grep -cF "$OLD" "$PV")" = "1" ]; then
  cp -p "$PV" "$PV.bak-x541"; TMP="$S/.x541-pv.js"
  "$NODE_BIN" -e 'const fs=require("fs");const[f,t,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");s=s.replace(o,"if (imagePaths.length > 10) { console.error(\"[post-via-playwright] max 10 images (2026-11-22 x541: confirmed 10 in the composer), got \" + imagePaths.length); process.exit(1); }");fs.writeFileSync(t,s)' "$PV" "$TMP" "$OLD"
  if "$NODE_BIN" --check "$TMP" 2>/dev/null && grep -q 'max 10 images' "$TMP"; then mv "$TMP" "$PV"; echo "書き換えた（元は .bak-x541）"; grep -n 'max 10 images' "$PV" | cut -c1-160; else rm -f "$TMP"; echo "**node --check を通らない。触らない**"; fi
else echo "**書き換える行が 1 か所に決まらない（$(grep -cF "$OLD" "$PV") か所）。触らない**"; grep -n 'max 4\|max 10' "$PV" | cut -c1-160; fi
echo '```'
echo; echo "## ② 出し直しの不具合（明日の湾岸のイルミの予約）"; echo '```'
R="$S/publish-wangan-illumination-oneshot.sh"
if [ -f "$R" ] && grep -q 'if \[ -z "\$TID" \]; then' "$R"; then
  cp -p "$R" "$R.bak-x541"
  perl -0pi -e 's/if \[ -z "\$TID" \]; then/if [ -z "\$TID" ] && ! printf "%s" "\$OUTP" | grep -q "\\"role\\":\\"hook\\",\\"ok\\":true"; then/' "$R"
  bash -n "$R" && echo "直した（元は .bak-x541）" || { cp -p "$R.bak-x541" "$R"; echo "**bash -n を通らない。元に戻した**"; }
  grep -n 'TID' "$R" | cut -c1-200
else echo "**ランナーが無い・形が違う。触らない**"; ls -la "$R" 2>&1 | tail -1; fi
echo '```'
echo; echo "**投稿はしていない。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '書き換えた|直した|触らない|戻した' "$OUT" | head -4
exit 0
