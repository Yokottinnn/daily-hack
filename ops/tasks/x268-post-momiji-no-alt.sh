#!/bin/bash
# **紅葉 2026 の告知スレッドを ALT 無しで出す。費用 $0。**
#
# ## 利用者の指示（2026-10-11）
#
#   > じゃあALTは無視してすぐ投稿しろ　出所書かなくていいから早くしろ
#
#   ALT を付けようとして x264〜x266 の 3 回止まった（3 回とも投稿はしていない）。**今回は ALT を付けずに出す。**
#   post-via-playwright.js の ALT の処理は ALT_TEXTS_FILE があるときだけ動くので、渡さなければ従来どおり出る。
#   （以下は x266 の記録。経緯として残す）
#
# ## x265 で分かったこと（2026-10-11 22:02）
#
#   また投稿せずに止まった（X には何も出ていない）。**原因はこちらの書き間違い。**
#   差し替えに使った String.replace は置換後の文字列の `$$` を `$` に縮める。
#   そのため `page.$$eval`（全部取る）が `page.$eval`（1 つ取る）に化け、`xs.map is not a function` で止まった。
#   → **置換は関数で渡す（`$$` を縮めない）。化けた 3 行は完全一致で `$$eval` に戻す。**
#   → **積み直すエントリは最初から `auto_publish:false`**（run-publish.sh は ID で直接出すので要らない）
#
# ## x264 で分かったこと（2026-10-11 21:56）
#
#   **ALT を付けられず、決めたとおり投稿せずに止まった。** X には何も出ていない。
#   画像を 4 枚 添付すると「件の説明を追加」（altTextWrapper）は**画像ごとではなく 1 個にまとまる。**
#   x263 は 1 枚だけで読んだので、この違いに気づけなかった。
#
#   さらにキューのエントリが `auto_publish:true` のまま残った。**自動投稿に拾われると ALT 無しで出る**ので、
#   **このタスクは最初にそれを false にする。**
#
# ## 直し方
#
#   altTextWrapper が 1 個なら、それを押して編集画面を開き、**「次へ」で i 枚目まで送る。**
#   送った先が i 枚目かは、**添付のサムネイルの src と編集画面の画像の src を突き合わせて確かめる。**
#   確かめられなければ投稿しない（そのとき画面の作りをレポートに出す）。
#
# ## 承認の状態
#
# **文面 2 本・画像 4 枚とも実物を見たうえで承認済み**（2026-10-11「内容これでいいので投稿して」）。
# 文面は `scripts/image-review/posts.lock.json` の momiji[0] / momiji[1] とハッシュで照合してから出す（最上位ルール 18）。
#
# ## ALT（画像の説明）
#
# 2 枚目（1b-spots.jpg）は記事の CC BY / CC BY-SA の写真で組んだ。**撮影者名とライセンスは ALT に書く**（最上位ルール 8・2026-10-11 の指示）。
# 投稿経路に ALT の処理が無かったので、x263 で投稿画面の実物を読んだうえで post-via-playwright.js に足す。
#
#   - 添付ごとに `[data-testid="altTextWrapper"]`（「件の説明を追加」）がある → i 枚目を押す
#   - 開いた画面の textarea に書く。無ければ「画像の説明を編集」（ALT タブ）を押してから探す
#   - 書けたか読み返し、`endEditingButton`（保存）を押す
#   - **どこかで失敗したら throw → 投稿ボタンを押さずに ok:false で終わる**（ALT 無しで出すとライセンス違反）
#   - 動くのは環境変数 `ALT_TEXTS_FILE` があるときだけ。ほかの投稿には影響しない
#
# ## 出たあと（同じタスクで読む）
#
#   permalink を開き、[1/2] の画像の alt 属性を読む。**2 枚目の alt に撮影者名が入っていれば付いている。**
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/post-momiji-4.md"
LOCK="$W/data/.x268-momiji.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-momiji-2026-kanto"
SRCDIR="public/images/momiji-2026-kanto/x"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
HEALTH="$W/scripts/cdp-health.js"
PVP="$W/scripts/post-via-playwright.js"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261011-momiji"
ALTF="$W/data/.x264-alts.json"
ME="heng_ji31590"

hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

posted_count() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{ const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  console.log((q.queue||[]).filter(e=>e&&e.id===process.argv[2]&&(e.status==="posted"||e.x_tweet_id||e.tweet_id)).length);
}catch(e){ console.log(-1); }' "$QJSON" "$ID" 2>/dev/null || echo -1
}

{
echo "# 紅葉 2026 の告知スレッドを投稿する（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> **[1/2] 画像 4 枚（2 枚目に ALT）・[2/2] 記事の紹介。** 文面は承認済みのものを 1 文字も変えていない（最上位ルール 18）。"

echo
echo "## 00. 残っているエントリの自動投稿を止める（ALT 無しで出る芽を摘む）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"); const [qp,id]=process.argv.slice(1);
try{ const q=JSON.parse(fs.readFileSync(qp,"utf8")); const e=(q.queue||[]).find(x=>x&&x.id===id);
  if(!e){ console.log("  エントリは無い"); process.exit(0); }
  console.log("  いま: status="+e.status+" auto_publish="+e.auto_publish+" x_tweet_id="+(e.x_tweet_id||null));
  if(e.auto_publish!==false && !e.x_tweet_id){ e.auto_publish=false; fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2)); fs.renameSync(qp+".tmp",qp); console.log("  → auto_publish を false にした"); }
}catch(err){ console.log("  読めない: "+err.message); }' "$QJSON" "$ID" 2>&1
echo '```'

echo
echo "## 0. もう出ていないか"
echo
BEFORE="$(posted_count)"
echo "- 投稿済みエントリ: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then echo "- **キューが読めない。何もしない。**"; exit 1; fi
if [ "${BEFORE:-0}" -gt 0 ] 2>/dev/null; then echo "- → **既に出ている。何もしない。**"; exit 0; fi
if [ -f "$LOCK" ]; then echo "- **ロックがある（$(cat "$LOCK")）。二重に走らせない。**"; exit 0; fi
mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"

echo
echo "## 1. 文面を origin/main から取り、ロックのハッシュと照合する"
echo
git -C "$REPO" fetch -q origin main 2>/dev/null || true
TXT="$W/data/.x264-texts.json"
git -C "$REPO" show origin/main:scripts/image-review/posts.json > "$W/data/.x264-posts.json" 2>/dev/null
git -C "$REPO" show origin/main:scripts/image-review/posts.lock.json > "$W/data/.x264-lock.json" 2>/dev/null
git -C "$REPO" show origin/main:ops/data/x-cards/momiji-2026-kanto.panels.json > "$W/data/.x264-panels.json" 2>/dev/null
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"),crypto=require("crypto");
const [pp,lp,cp,out,altf]=process.argv.slice(1);
const p=JSON.parse(fs.readFileSync(pp,"utf8")).momiji, l=JSON.parse(fs.readFileSync(lp,"utf8")).locked;
const sha=s=>crypto.createHash("sha256").update(s,"utf8").digest("hex");
const w=s=>{let n=0;for(const c of s.replace(/https?:\/\/\S+/g,"#".repeat(23)))n+=c.codePointAt(0)<0x80?1:2;return n};
let ok=true;
p.forEach((t,i)=>{const L=l["momiji["+i+"]"]; const m=L&&L.sha256===sha(t); console.log("  ["+(i+1)+"/2] ロック "+(m?"一致":"**不一致**")+" ／ 重み "+w(t)+" / 280"); if(!m||w(t)>280) ok=false;});
const panels=JSON.parse(fs.readFileSync(cp,"utf8")).panels;
const order=["1-calendar.jpg","1b-spots.jpg","2-takao.jpg","4-nikko.jpg"];
const alts=order.map(f=>((panels.find(x=>x.file===f)||{}).alt)||"");
console.log("  ALT: "+alts.map((a,i)=>(i+1)+"枚目 "+(a?a.length+"字":"なし")).join(" ／ "));

fs.writeFileSync(out, JSON.stringify(p)); fs.writeFileSync(altf, JSON.stringify(alts));
if(!ok){ console.log("  **出さない**"); process.exit(2); }' "$W/data/.x264-posts.json" "$W/data/.x264-lock.json" "$W/data/.x264-panels.json" "$TXT" "$ALTF" 2>&1
RC=$?
echo '```'
if [ "$RC" != "0" ]; then echo "- **文面か ALT が揃わない。出さない。**"; rm -f "$LOCK"; exit 1; fi
T1="$("$NODE_BIN" -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))[0])' "$TXT")"
T2="$("$NODE_BIN" -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))[1])' "$TXT")"

echo
echo "## 2. ALT は付けない（利用者の指示）。post-via-playwright.js は触らない"
echo
echo "## 3. 画像 4 枚を origin/main から取り出す"
echo
mkdir -p "$IMGDIR"; IMGS=""; N=0
echo '```'
for f in 1-calendar.jpg 1b-spots.jpg 2-takao.jpg 4-nikko.jpg; do
  TMP="$IMGDIR/.dl-$f"
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$TMP" 2>/dev/null && [ "$(wc -c < "$TMP" | tr -d ' ')" -ge 20000 ]; then
    mv "$TMP" "$IMGDIR/$f"; printf '  取得  %-16s %s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    IMGS="${IMGS:+$IMGS,}$IMGDIR/$f"; N=$((N + 1))
  else printf '  **取れない** %s\n' "$f"; rm -f "$TMP"; fi
done
printf '  対象 4 枚 / 取れた %s 枚\n' "$N"
echo '```'
if [ "$N" != "4" ]; then echo "- **画像が 4 枚 揃わない。出さない。**"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 4. キューに積む（x264 のエントリが残っていれば消してから積み直す）"
echo
echo '```json'
"$NODE_BIN" -e '
const fs=require("fs"); const [qp,id]=process.argv.slice(1);
const q=JSON.parse(fs.readFileSync(qp,"utf8")); const before=(q.queue||[]).length;
q.queue=(q.queue||[]).filter(x=>!(x&&x.id===id&&!x.x_tweet_id&&x.status!=="posted"));
if(q.queue.length!==before){ fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2)); fs.renameSync(qp+".tmp",qp); console.log("{\"removed_old\":"+(before-q.queue.length)+"}"); }' "$QJSON" "$ID" 2>&1
"$NODE_BIN" -e '
const [id,t1,t2,csv]=process.argv.slice(1);
console.log(JSON.stringify({ id, kind:"thread", text:t1, image_path:csv, auto_publish:false,
  scheduled_at:new Date(Date.now()-60000).toISOString(),
  thread_chain:[ {text:t1, role:"hook", image_path:csv}, {text:t2, role:"link"} ] }));
' "$ID" "$T1" "$T2" "$IMGS" | "$NODE_BIN" "$Q" enqueue 2>&1 | head -10 | clean
echo '```'

echo
echo "## 5. Chrome は健全か"
echo
echo '```'
"$NODE_BIN" "$HEALTH" 2>&1 | clean; echo "(rc=$?)"
echo '```'

echo
echo "## 6. 出す（ALT は渡さない）"
echo
PUB="$(env -u ALT_TEXTS_FILE "$RUNPUB" "$ID" 2>&1)"; PRC=$?
echo '```'
printf '%s\n' "$PUB" | tail -60 | clean
echo "(rc=$PRC)"
echo '```'

echo
echo "## 7. 出たか。出たならキューに書き戻す"
echo
echo '```'
printf '%s' "$PUB" | "$NODE_BIN" -e '
const fs=require("fs");
let raw=""; process.stdin.on("data",d=>raw+=d).on("end",()=>{
  const [qp,id]=process.argv.slice(1);
  const line=raw.split(/\r?\n/).filter(l=>l.trim().startsWith("{")).pop();
  if(!line){ console.log("  出力に JSON が無い。書き戻さない。"); return; }
  let r; try{ r=JSON.parse(line); }catch(e){ console.log("  JSON が読めない: "+e.message); return; }
  if(!r.ok){ console.log("  ok:false。書き戻さない。 step="+(r.step||"-")+" error="+(r.error||"")); return; }
  const t1=r.tweet_id||null, rs=r.thread_results||[], t2=(rs[1]&&(rs[1].reply_tweet_id||rs[1].tweet_id))||null;
  console.log("  [1/2] tweet_id = "+(t1||"取れていない")); console.log("  [2/2] tweet_id = "+(t2||"**取れていない**"));
  if(!t1) return;
  const q=JSON.parse(fs.readFileSync(qp,"utf8")); const e=(q.queue||[]).find(x=>x&&x.id===id); if(!e) return;
  e.status="posted"; e.x_tweet_id=t1; e.posted_at=new Date().toISOString();
  if(Array.isArray(e.thread_chain)){ if(e.thread_chain[0]) e.thread_chain[0].x_tweet_id=t1; if(e.thread_chain[1]&&t2) e.thread_chain[1].x_tweet_id=t2; }
  fs.writeFileSync(qp+".tmp", JSON.stringify(q,null,2)); fs.renameSync(qp+".tmp", qp);
  console.log("  キューを posted に書き戻した");
});' "$QJSON" "$ID" 2>&1 | clean
echo '```'

echo
echo "## 8. 実物を読む（プロフィール → permalink。画像の枚数と alt）"
echo
PROBE="$W/.x264-proof.js"
cat > "$PROBE" <<'PROBEJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [me, outdir] = process.argv.slice(2);
const read = (page) => page.$$eval('article[data-testid="tweet"]', (arts) => arts.slice(0, 6).map((a) => {
  const t = a.querySelector("time"); const p = t && t.closest("a"); const tx = a.querySelector('[data-testid="tweetText"]');
  return { href: p ? p.getAttribute("href") : null, at: t ? t.getAttribute("datetime") : null, text: tx ? tx.innerText : null,
    photos: [...a.querySelectorAll('[data-testid="tweetPhoto"] img')].map((i) => i.getAttribute("alt") || "") };
}));
(async () => {
  const r = {};
  try {
    const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await b.contexts()[0].newPage();
    await page.setViewportSize({ width: 900, height: 1700 });
    await page.goto("https://x.com/" + me, { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {});
    await page.waitForTimeout(6000);
    const hit = (await read(page)).find((x) => x.text && /見どころ10選/.test(x.text));
    if (hit && hit.href) {
      r.t1 = (hit.href.match(/status\/(\d+)/) || [])[1];
      await page.goto("https://x.com" + hit.href, { waitUntil: "domcontentloaded", timeout: 40000 });
      await page.waitForSelector('article[data-testid="tweet"]', { timeout: 15000 }).catch(() => {});
      await page.waitForTimeout(7000);
      r.thread = await read(page);
      await page.screenshot({ path: outdir + "/x268-thread.png" });
    }
    await page.close().catch(() => {});
  } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r)); process.exit(0);
})();
PROBEJS
rm -f "$OUTDIR"/x268-*.png
cd "$W" && "$NODE_BIN" "$PROBE" "$ME" "$OUTDIR" > "$W/.x264-proof.json" 2>&1
"$NODE_BIN" -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
if (j.error) console.log("**エラー: " + j.error + "**\n");
if (!j.t1) { console.log("**プロフィールに紅葉の投稿が見つからない**"); process.exit(0); }
const me = process.argv[2]; let self = null; const replies = [];
for (const x of j.thread || []) { if (!x.href || x.href.includes("/status/" + j.t1)) self = x; else if (x.href.startsWith("/" + me + "/status/")) replies.push(x); }
if (self) {
  console.log("### [1/2] https://x.com/" + me + "/status/" + j.t1 + "  画像 " + self.photos.length + " 枚\n");
  self.photos.forEach((a, i) => console.log("- " + (i + 1) + " 枚目の alt: " + (a ? a.slice(0, 120) + (a.length > 120 ? "…（" + a.length + "字）" : "") : "（空）")));
}
for (const x of replies) console.log("\n### [2/2] https://x.com" + x.href + "\n\n```\n" + (x.text || "") + "\n```");
const altOk = self && self.photos[1] && /Dick Thomas Johnson/.test(self.photos[1]);
console.log("\n**判定: [1/2] " + (self ? "在る（画像 " + self.photos.length + " 枚）" : "無い") + " ／ 2 枚目の ALT（今回は付けない） " + (altOk ? "付いている" : "なし") + " ／ [2/2] " + (replies.length ? "在る" : "**見えない**") + "**");
' "$W/.x264-proof.json" "$ME" 2>&1 | clean
rm -f "$PROBE" "$W/.x264-proof.json" "$TXT" "$ALTF" "$W/data/.x264-posts.json" "$W/data/.x264-lock.json" "$W/data/.x264-panels.json"
echo
echo "画面: $(ls "$OUTDIR"/x268-*.png 2>/dev/null | xargs -n1 basename 2>/dev/null)"
echo
echo "**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q 'キューを posted に書き戻した' "$OUT" 2>/dev/null; then echo "**紅葉の告知を出した** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then echo "既に出ていたので何もしていない / $(basename "$OUT")"
else echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"; fi
