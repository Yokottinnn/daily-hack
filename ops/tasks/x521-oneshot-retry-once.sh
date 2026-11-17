#!/bin/bash
# x521（2026-11-17・$0）: 予約の実行役に「出なかったら 60 秒おいて 1 回だけ出し直す」を足す。
# 11/17 12:00 の JAL の告知は、画像の説明（ALT）を入れる段で Chrome のタブが閉じられて出なかった（x519）。手で出し直したら 12:28 に出た（x520）。
# 対象: まだ走っていない予約（レインボーライド 11/18・ブラックフライデーまとめ 11/19）。出たかはキューの x_tweet_id で見る（出ていれば何もしない＝二重には出ない）。
# LLM を呼ばない。置く前に bash -n。通らなければ元に戻す。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; D="$W/data"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x521-oneshot-retry-once.md"
{
echo "# 予約の実行役に 1 回だけの出し直しを足す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
for pair in "publish-rainbow-ride-oneshot.sh|x-blog-20261118-rainbow-ride" "publish-bf-matome-oneshot.sh|x-blog-20261119-bf-matome"; do
  F="$S/${pair%%|*}"; ID="${pair#*|}"
  [ -f "$F" ] || { echo "$(basename "$F"): 無い"; continue; }
  if grep -q 'x521' "$F"; then echo "$(basename "$F"): もう入っている"; continue; fi
  cp -p "$F" "$F.bak-x521"
  "$NODE_BIN" - "$F" "$ID" "$D/post_queue.json" <<'JS'
const fs=require("fs");const [f,id,qp]=process.argv.slice(2);let s=fs.readFileSync(f,"utf8");
const lines=s.split("\n");const i=lines.findIndex(l=>l.includes("launchctl bootout"));
if(i<0){console.log("目印（bootout の行）が無い");process.exit(1)}
const run=lines.find(l=>l.startsWith("OUTP="));const wb=lines.find(l=>l.includes("writeback")||l.includes(".publish-")&&l.includes("printf '%s' \"$OUTP\""));
if(!run||!wb){console.log("実行の行が見つからない");process.exit(1)}
const chk=`TID="$(${process.execPath} -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const r=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);const e=r.find(x=>x&&x.id===process.argv[2]);console.log(e&&e.x_tweet_id||"")' "${qp}" "${id}" 2>/dev/null)"`;
const add=["# x521: 出なかったら 60 秒おいて 1 回だけ出し直す（11/17 の JAL はタブが閉じられて出なかった）",chk,'if [ -z "$TID" ]; then echo "[$(date \'+%F %T\')] 出ていない。60 秒後に 1 回だけ出し直す（x521）" >> "'+lines.find(l=>l.includes(">> \"")&&l.includes("start")).match(/>> "([^"]+)"/)[1]+'"; sleep 60; '+run+'; printf \'%s\\n\' "$OUTP" >> "'+lines.find(l=>l.includes(">> \"")&&l.includes("start")).match(/>> "([^"]+)"/)[1]+'"; '+wb.trim()+'; fi'];
lines.splice(i,0,...add);fs.writeFileSync(f,lines.join("\n"));console.log("入れた");
JS
  if bash -n "$F" 2>/dev/null; then echo "$(basename "$F"): 入れた・bash -n 通った"; grep -n 'x521' "$F" | head -2 | cut -c1-120; else cp -p "$F.bak-x521" "$F"; echo "**$(basename "$F"): bash -n が通らない。元に戻した**"; fi
done
echo '```'
echo; echo "**LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '入れた|元に戻した|無い' "$OUT" | head -4
exit 0
