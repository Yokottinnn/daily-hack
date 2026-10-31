#!/bin/bash
# **外す処理（unfollow-handle.js）が毎回 120 秒で打ち切られる理由を調べる（x382）。$0。**
# x381: 10/31 の夜中、146 回すべて ETIMEDOUT で外した 0 件。毎時 同じ先頭 20 件を打ち直していた。
# 10/29 には Page.handleJavaScriptDialog の例外も出ている（x379）。どの段で止まるかを Playwright の API ログ（DEBUG=pw:api）で見る。
# 1 件だけ走らせる（本来の仕事そのもの。外せたら 1 件 外れる）。最大 130 秒で打ち切る。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/x382-why-unfollow-times-out.md"
SHOT_DIR="${OPS_REPORT_DIR:-/tmp}/x382"; mkdir -p "$SHOT_DIR"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
CDP="${CHROME_CDP_URL:-http://127.0.0.1:18810}"
H="mao_otk_tw"   # 10/31 の夜中に毎回 先頭だった 1 件
LOG="$(mktemp -t x382)"
mask() { sed -E "s/$H/<伏せ>/g; s/@[A-Za-z0-9_]{3,15}/@<伏せ>/g"; }
{
echo "# 外す処理が打ち切られる理由（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"

echo; echo "## 1. いま Chrome に開いているページ（種類と行き先のホストだけ）"; echo '```'
curl -s -m 5 "$CDP/json/list" | "$NODE_BIN" -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const a=JSON.parse(s);
console.log("ページ数 "+a.filter(t=>t.type==="page").length+" ／ 全部 "+a.length);
for(const t of a){let h="";try{h=new URL(t.url).host+new URL(t.url).pathname.split("/").slice(0,2).join("/")}catch{h=t.url.slice(0,40)}
 if(/x\.com|twitter/.test(h)||t.type!=="page")console.log(t.type+"\t"+h.replace(/\/[A-Za-z0-9_]{3,15}$/,"/<伏せ>"));}}catch(e){console.log("読めない: "+e.message+" / "+s.slice(0,200))}})'
echo '```'

echo; echo "## 2. 間隔の台帳（直近 30 分）"; echo '```'
"$NODE_BIN" "$W/lib/x-action-pacer.cjs" status 2>&1
echo '```'

echo; echo "## 3. unfollow-handle.js を 1 件だけ走らせる（DEBUG=pw:api・最大 130 秒）"; echo '```'
ps -axo pid,etime,command | grep -E 'reply-followers-cleanup|unfollow-handle' | grep -v grep | sed 's/^/同時に動いている: /' | mask
T0=$(date +%s)
DEBUG=pw:api "$NODE_BIN" "$S/unfollow-handle.js" "$H" >"$LOG" 2>&1 &
P=$!
while kill -0 "$P" 2>/dev/null; do
  [ $(( $(date +%s) - T0 )) -ge 130 ] && break
  sleep 2
done
if kill -0 "$P" 2>/dev/null; then
  KIDS="$(pgrep -P "$P" 2>/dev/null | tr '\n' ' ')"
  kill -TERM "$P" $KIDS 2>/dev/null; sleep 2; kill -KILL "$P" $KIDS 2>/dev/null
  echo "→ 130 秒で終わらなかったので止めた"
else
  wait "$P"; echo "→ 終わった rc=$? 経過 $(( $(date +%s) - T0 )) 秒"
fi
echo "--- 出力（$(wc -l < "$LOG" | tr -d ' ') 行）の最後 70 行"
tail -70 "$LOG" | cut -c1-260 | mask
echo '```'

echo; echo "## 4. X のページの画面（最大 25 秒）"; echo '```'
cat > "$SHOT_DIR/.shot.js" <<'JS'
const { chromium } = require(process.env.HOME + "/.openclaw/workspace/node_modules/playwright-core");
setTimeout(() => { console.log("25 秒で打ち切った"); process.exit(2); }, 25000).unref();
(async () => {
  const b = await chromium.connectOverCDP(process.argv[2], { timeout: 10000 });
  let n = 0;
  for (const c of b.contexts()) for (const p of c.pages()) {
    const u = p.url();
    if (!/x\.com/.test(u)) continue;
    n++;
    try { await p.screenshot({ path: `${process.argv[3]}/page-${n}.png`, timeout: 8000 }); console.log(`page-${n}.png 撮れた`); }
    catch (e) { console.log(`page-${n}: 撮れない ${e.message.split("\n")[0]}`); }
    if (n >= 4) break;
  }
  console.log("X のページ " + n + " 枚");
  process.exit(0);
})().catch(e => { console.log("つなげない: " + e.message.split("\n")[0]); process.exit(1); });
JS
"$NODE_BIN" "$SHOT_DIR/.shot.js" "$CDP" "$SHOT_DIR" 2>&1 | mask
rm -f "$SHOT_DIR/.shot.js"
for f in "$SHOT_DIR"/*.png; do [ -f "$f" ] && echo "$(basename "$f") $(wc -c < "$f" | tr -d ' ') bytes"; done
echo '```'

echo; echo "## 5. unfollow-handle.js の中身（先頭 100 行）"; echo '```'
head -100 "$S/unfollow-handle.js" | cut -c1-240 | mask
echo '```'
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。外す操作は 1 件だけ（本来の仕事）。**"
} > "$OUT" 2>&1
rm -f "$LOG"
echo "x382 / $(basename "$OUT")"
