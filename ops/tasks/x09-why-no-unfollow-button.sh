#!/bin/bash
# **「アンフォローのボタンが見つからない」の原因を、実際の画面で切り分ける。費用 $0。**
#
# ## 何が起きたか（x08 の実測）
#
#   due 197 → 上限 5 件に絞る
#   due unfollows: 5 → （5 アカウント）
#   @…: unfollow failed (no unfollow button)   × 5 件 全部
#
#   unfollowed 16 → 16 ／ 期限到来 197 → 197 ／ **外した数 0 件**
#
# **5 件すべてが同じ失敗。** 個別の事情ではなく共通原因がある。
#
# ## candidate（まだ どれか確定していない）
#
#   1. **そもそも既にフォローしていない。** 状態ファイルが古く、画面には
#      「フォローする」しか無い（＝ボタンが見つからないのは正しい挙動）
#   2. **X の DOM が変わってセレクタが効かない**
#   3. ログインが切れている（ただし本日 16:45 に投稿が成功しているので薄い）
#
# ## やること（**押さない。見るだけ**）
#
#   1. `unfollow-handle.js` の全文（**どのセレクタで探しているか**）
#   2. 対象 2 件のプロフィールを開き、**ボタンの実際の文字列と data-testid** を出す
#   3. ログイン状態（自分のハンドルが読めるか）
#   4. **実際にフォロー中の一覧**に、その 2 件が居るかどうか
#
# ## やらないこと
#
# **ボタンを押さない。アンフォローしない。フォローしない。投稿しない。**
# **ジョブを触らない。書き換えない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/why-no-unfollow-button.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
STATE="$W/data/reply-followers.json"
CDP="http://127.0.0.1:18810"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# なぜアンフォローのボタンが見つからないのか（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **5 件すべてが同じ失敗。** 個別の事情ではなく共通原因がある。"
echo "> **押さない。見るだけ。**"

echo
echo "## 1. \`unfollow-handle.js\` の全文"
echo
F="$S/unfollow-handle.js"
if [ -f "$F" ]; then
  echo "- $(wc -l < "$F" | tr -d ' ') 行 / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$F" 2>/dev/null)"
  echo
  echo '```javascript'
  cat -n "$F" 2>/dev/null | clean
  echo '```'
else
  echo "- **無い**（\`$F\`）"
fi

echo
echo "## 2. 対象のプロフィールを開いて、ボタンの実物を見る"
echo
echo "**押さない。** 文字列と \`data-testid\` を読むだけ。"
echo
TARGETS="$("$NODE_BIN" -e '
const fs=require("fs");
try{
  const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const now=Date.now(); const out=[];
  for(const [h,e] of Object.entries(s)){
    if(!e||!e.scheduled_unfollow_at) continue;
    if(new Date(e.scheduled_unfollow_at).getTime()>now) continue;
    out.push(h); if(out.length>=2) break;
  }
  console.log(out.join(" "));
}catch(e){ console.log(""); }
' "$STATE")"
echo "- 対象: $(printf '%s' "$TARGETS" | wc -w | tr -d ' ') 件（ハンドルは伏せる）"
echo
echo '```'
"$NODE_BIN" -e '
const { chromium } = require("playwright");
(async () => {
  const handles = process.argv[2].split(/\s+/).filter(Boolean);
  if (!handles.length) { console.log("  対象が取れない"); return; }
  let b;
  try { b = await chromium.connectOverCDP(process.argv[3], { timeout: 15000 }); }
  catch (e) { console.log("  CDP に繋がらない: " + e.message.slice(0,120)); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log("  context が無い"); return; }
  const page = await ctx.newPage();
  // ログイン状態
  try {
    await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(3000);
    const url = page.url();
    console.log("  /home の URL: " + url);
    console.log("  ログイン: " + (/login|i\/flow/.test(url) ? "**切れている**" : "生きている"));
  } catch (e) { console.log("  /home を開けない: " + e.message.slice(0,100)); }

  for (const h of handles) {
    console.log("");
    console.log("  --- @<伏せ> のプロフィール ---");
    try {
      await page.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      await page.waitForTimeout(4000);
      const info = await page.evaluate(() => {
        const btns = Array.from(document.querySelectorAll("button,[role=button]"));
        const rows = btns.slice(0, 60).map(b => ({
          t: (b.getAttribute("data-testid") || "").slice(0, 60),
          x: (b.innerText || "").trim().replace(/\s+/g, " ").slice(0, 24),
          a: (b.getAttribute("aria-label") || "").slice(0, 50)
        })).filter(r => r.t || r.x);
        const follow = rows.filter(r =>
          /follow|unfollow/i.test(r.t) || /フォロー|Follow/i.test(r.x) || /フォロー|Follow/i.test(r.a));
        return { total: btns.length, follow, title: document.title.slice(0,60) };
      });
      console.log("  title: " + info.title);
      console.log("  ボタン総数: " + info.total);
      if (!info.follow.length) console.log("  **フォロー関係のボタンが 1 つも無い**");
      info.follow.slice(0, 8).forEach(r =>
        console.log("    testid=" + (r.t||"-") + " / 文字=" + (r.x||"-") + " / aria=" + (r.a||"-")));
    } catch (e) { console.log("  開けない: " + e.message.slice(0, 120)); }
  }
  await page.close().catch(()=>{});
})();
' -- "$TARGETS" "$CDP" 2>&1 | clean
echo '```'
echo
echo "**\`Follow\` / \`フォロー\` しか無ければ「既に外れている」。**"
echo "**\`Following\` / \`フォロー中\` があるのに掴めていないなら「セレクタが古い」。**"

echo
echo "## 3. 期限到来 197 件の古さ"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const now=Date.now(); const b={}; let oldest=null, n=0;
  for(const e of Object.values(s)){
    if(!e||!e.scheduled_unfollow_at) continue;
    const t=new Date(e.scheduled_unfollow_at).getTime();
    if(t>now) continue;
    n++;
    const d=Math.floor((now-t)/86400000);
    const k=d<7?"0〜6日":d<14?"7〜13日":d<30?"14〜29日":"30日以上";
    b[k]=(b[k]||0)+1;
    if(oldest===null||t<oldest) oldest=t;
  }
  console.log("  期限到来: "+n+" 件");
  ["0〜6日","7〜13日","14〜29日","30日以上"].forEach(k=>{ if(b[k]) console.log("    "+k.padEnd(10)+b[k]+" 件 放置"); });
  if(oldest) console.log("  いちばん古い期限: "+new Date(oldest).toISOString().slice(0,10));
}catch(e){ console.log("  読めない"); }
' "$STATE" 2>&1 | clean
echo '```'
echo
echo "**30 日以上 放置が多ければ、その間に手で外している可能性がある。**"

echo
echo "---"
echo
echo "**ボタンを押していない。アンフォローもフォローもしていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**ボタンが無い理由を実画面で切り分けた（変更なし・\$0）** / $(basename "$OUT")"
