#!/bin/bash
# **（x248・x247 で比較を直したあとの出し直し。中身は x245 と同じ）**
# **JAL マイル2倍の [2/2] が出ていない。キューを書き戻し、返信が無ければ出す。費用 $0。**
#
# ## 何が起きたか（2026-10-04 19:55〜19:58）
#
#   * x243 が 19:55 に [1/2] を出した（2106699830819258421・画像 4 枚。x244 が実物で確認）
#   * **[2/2] の返信がぶら下がっていない**（x244 のスレッド画面に返信が無い）
#   * x243 は 19:58 にもう一度起動され、ロックで止まった。**そのときレポートが上書きされ、1 回目の出力が残っていない**
#   * キューの書き戻しが走っておらず、**エントリが `pending`・`auto_publish:true` のまま。自動投稿に拾われると [1/2] が二重に出る**
#
# ## やること（この順）
#
#   ① **先にキューを `posted`・`auto_publish:false` に書き戻す**（二重投稿の芽を摘む）
#   ② [1/2] を開き、**自分の返信が既にぶら下がっていれば何もしない**（time の親 a の href で数える・契約書 §3）
#   ③ 無ければ、承認済みの [2/2] を `post-comment.js` で [1/2] にぶら下げる（画像なし）
#   ④ もう一度開いて、**返信の permalink を取る。取れなければ「出た」と言わない**
#   ⑤ 1 回目が [2/2] を出せなかった理由の手がかりとして、run-publish のログの該当行を出す
#
# **[2/2] の文面は承認済みのものを 1 文字も変えない**（posts.lock.json の jal-2x[1]・最上位ルール 18）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。** プローブはワークスペースの中に置く（契約書 §3）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/repair-jal-2x-reply-2.md"
LOCK="$W/data/.x248-jal-2x-reply.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
CMT="$W/scripts/post-comment.js"
HEALTH="$W/scripts/cdp-health.js"
QJSON="$W/data/post_queue.json"
PROBE="$W/.x248-probe.js"
ID="blog-promo-20261004-jal-2x"
T1="2106699830819258421"
ME="heng_ji31590"

hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }
secrets() {
  sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
         -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

# **承認済みの [2/2]。1 文字も変えない**
T2='正直、歩いてポイ活ってアツいのよ。
毎日歩く分が、そのままマイルやポイントになるんだから。

JALは月550円でマイル。無料のアプリでも毎日8,000歩で年365円。
どれを組み合わせるかは、アタシが20アプリ分析してまとめといたわ。

https://daily-hack.fieldbeside.com/posts/walk-poikatsu-2026/'

cat > "$PROBE" <<'PROBEJS'
// x245: 投稿ページを開き、本体の画像枚数と、ぶら下がっている自分の返信の permalink を読む。投稿しない
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
(async () => {
  const [id, me] = process.argv.slice(2);
  const r = { id, exists: false, replies: [] };
  let browser;
  try {
    browser = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await browser.contexts()[0].newPage();
    await page.goto("https://x.com/" + me + "/status/" + id, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForSelector('article[data-testid="tweet"]', { timeout: 15000 }).catch(() => {});
    await page.waitForTimeout(5000);
    const items = await page.$$eval('article[data-testid="tweet"]', (arts) => arts.slice(0, 8).map((a) => {
      const t = a.querySelector("time");
      const p = t && t.closest("a");
      const tx = a.querySelector('[data-testid="tweetText"]');
      return { href: p ? p.getAttribute("href") : null,
               photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length,
               head: tx ? tx.innerText.split("\n")[0].slice(0, 26) : null };
    }));
    r.articles = items.length;
    for (const it of items) {
      if (!it.href || it.href.includes("/status/" + id)) { r.exists = true; r.photos = it.photos; r.head = it.head; }
      else if (it.href.startsWith("/" + me + "/status/")) r.replies.push(it);
    }
    await page.close().catch(() => {});
  } catch (e) { r.error = String(e && e.message).slice(0, 160); }
  console.log(JSON.stringify(r));
  process.exit(0);
})();
PROBEJS

field() { "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);const f=process.argv[1];
  if(f==="exists")console.log(o.exists?1:0);else if(f==="mine")console.log((o.replies||[]).length);else if(f==="href")console.log(((o.replies||[])[0]||{}).href||"");}catch(e){console.log(f==="href"?"":-1)}})' "$1" 2>/dev/null; }

writeback() {  # $1 = [2/2] の tweet id（無ければ空）
  "$NODE_BIN" -e '
const fs=require("fs");const [qp,id,t1,t2]=process.argv.slice(1);
let q; try{ q=JSON.parse(fs.readFileSync(qp,"utf8")); }catch(e){ console.log("  キューが読めない: "+e.message); process.exit(0); }
const e=(q.queue||[]).find(x=>x&&x.id===id);
if(!e){ console.log("  エントリが無い（積まれていない）"); process.exit(0); }
const before={status:e.status,auto_publish:e.auto_publish,x_tweet_id:e.x_tweet_id||null};
e.status="posted"; e.x_tweet_id=t1; e.auto_publish=false; e.posted_at=e.posted_at||new Date().toISOString();
if(Array.isArray(e.thread_chain)){ if(e.thread_chain[0]) e.thread_chain[0].x_tweet_id=t1; if(e.thread_chain[1]&&t2) e.thread_chain[1].x_tweet_id=t2; }
fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2)); JSON.parse(fs.readFileSync(qp+".tmp","utf8")); fs.renameSync(qp+".tmp",qp);
console.log("  前: "+JSON.stringify(before));
console.log("  後: "+JSON.stringify({status:e.status,auto_publish:e.auto_publish,x_tweet_id:e.x_tweet_id,reply:t2||null}));
' "$QJSON" "$ID" "$T1" "${1:-}" 2>&1
}

{
echo "# JAL マイル2倍の [2/2] を出す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
if [ -f "$LOCK" ]; then echo "- **ロックがある（$(cat "$LOCK" 2>/dev/null)）。何もしない。**"; exit 0; fi
mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"

echo "## ① キューを先に書き戻す（[1/2] の二重投稿を防ぐ）"
echo
echo '```'
writeback "" | clean
echo '```'

echo
echo "## ② [1/2] の実物と、ぶら下がっている自分の返信"
echo
echo '```'
if [ -f "$HEALTH" ]; then "$NODE_BIN" "$HEALTH" 2>&1 | tail -2 | clean; fi
cd "$W" && R1="$("$NODE_BIN" "$PROBE" "$T1" "$ME" 2>&1 | tail -1)"
printf '%s\n' "$R1" | clean
echo '```'
EX="$(printf '%s' "$R1" | field exists)"; MINE="$(printf '%s' "$R1" | field mine)"
if [ "$EX" != "1" ]; then echo; echo "- **[1/2] が開けない。ぶら下げる先が無いので何もしない。**"; rm -f "$PROBE"; exit 1; fi
if [ "${MINE:-0}" -gt 0 ] 2>/dev/null; then
  H="$(printf '%s' "$R1" | field href)"
  echo; echo "- **自分の返信が既に ${MINE} 件 ある（https://x.com${H}）。二重投稿になるので出さない。**"
  echo; echo '```'; writeback "$(printf '%s' "$H" | sed -E 's#.*/status/([0-9]+).*#\1#')" | clean; echo '```'
  rm -f "$PROBE"; exit 0
fi
echo
echo "- [1/2] は在る。**自分の返信は無い。出す。**"

echo
echo "## ③ [2/2] を出す（\`post-comment.js\` を直接・画像なし）"
echo
echo '```'
B64="$("$NODE_BIN" -e 'process.stdout.write(Buffer.from(process.argv[1],"utf8").toString("base64"))' "$T2")"
cd "$W" && RES="$("$NODE_BIN" "$CMT" "$B64" "https://x.com/$ME/status/$T1" "null" 2>&1)"; PRC=$?
printf '%s\n' "$RES" | tail -30 | clean
echo "(rc=$PRC)"
echo '```'

echo
echo "## ④ 出たかを実物で確かめる（返り値の ID は信用しない）"
echo
sleep 8
echo '```'
cd "$W" && R2="$("$NODE_BIN" "$PROBE" "$T1" "$ME" 2>&1 | tail -1)"
printf '%s\n' "$R2" | clean
echo '```'
MINE2="$(printf '%s' "$R2" | field mine)"; H2="$(printf '%s' "$R2" | field href)"
echo
if [ "${MINE2:-0}" -gt 0 ] 2>/dev/null && [ -n "$H2" ]; then
  echo "**[2/2] が在る → https://x.com${H2}**"
  echo; echo '```'; writeback "$(printf '%s' "$H2" | sed -E 's#.*/status/([0-9]+).*#\1#')" | clean; echo '```'
else
  echo "**まだ見えない。** 上の出力の全文を見ること。rc は証拠にならない（最上位ルール 13）"
fi

echo
echo "## ⑤ 1 回目（19:55）が [2/2] を出せなかった手がかり"
echo
echo '```'
for f in "$W"/logs/*publish*.log "$W"/logs/*comment*.log; do
  [ -f "$f" ] || continue
  n="$(grep -c -E 'jal-2x|2106699830819258421|thread_results|cta' "$f" 2>/dev/null | head -1)"
  [ "${n:-0}" -gt 0 ] 2>/dev/null || continue
  echo "  --- $(basename "$f")（該当 ${n} 行・末尾 12 行）"
  grep -E 'jal-2x|2106699830819258421|thread_results|cta|error|ok' "$f" 2>/dev/null | tail -12 | cut -c1-260 | clean | sed 's/^/    /'
done
echo '```'
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

rm -f "$PROBE"
[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '\[2/2\] が在る →' "$OUT" 2>/dev/null; then echo "**[2/2] を出した。実物で確認済み** / $(basename "$OUT")"
elif grep -q '二重投稿になるので出さない' "$OUT" 2>/dev/null; then echo "[2/2] は既にあった / $(basename "$OUT")"
else echo "**[2/2] を出せていない。レポート全文を読むこと** / $(basename "$OUT")"; fi
