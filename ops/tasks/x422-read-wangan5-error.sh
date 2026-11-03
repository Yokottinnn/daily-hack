#!/bin/bash
# x422（2026-11-04・読むだけ・$0）: x421 の出し直しが thread-main-exec で失敗した（画像 2 枚添付・1 枚目の ALT までは進んだ）。
# エラー文がレポートで切れたので、ログの失敗行を最後まで読む。何も押さない・書き換えない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; LOG="$W/logs/publish-wangan5-oneshot.log"
OUT="${OPS_REPORT_DIR:-/tmp}/x422-wangan5-error.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-)[A-Za-z0-9-]+/<伏せ>/g'; }
{
echo "# 湾岸ニュース5選の出し直しの失敗の中身（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo '```'
grep -n '' "$LOG" | grep -vE '^\s*$' | awk -F: '{print $1}' | tail -1 | xargs -I{} echo "ログ行数: {}"
echo "--- 失敗の JSON（引数の base64 は伏せて、エラーの本文だけ）"
grep '"thread-main-exec"' "$LOG" | tail -1 | "$NODE_BIN" -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let j;try{j=JSON.parse(s)}catch(e){console.log("JSON で読めない: "+s.slice(-1500));return}
let e=String(j.error||""); e=e.replace(/"[A-Za-z0-9+\/=]{40,}"/g,"\"<本文の base64>\""); console.log(e.slice(0,3000));});' 2>&1 | hide
echo "--- post-via-playwright の 1 回分の出力（ログの start 以降・最後の 60 行）"
awk '/08:22:49\] start/{f=1} f' "$LOG" | tail -60 | cut -c1-400 | perl -pe 's/"[A-Za-z0-9+\/=]{40,}"/"<base64>"/g' | hide
echo "--- 失敗時の画面（あれば）"
ls -lt /tmp/*post*png "$W"/logs/*post*png "$W"/data/*post*png 2>/dev/null | head -5 | sed "s#$HOME#~#"
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
