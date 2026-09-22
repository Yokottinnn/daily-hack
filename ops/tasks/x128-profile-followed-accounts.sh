#!/bin/bash
# **最近フォローした相手の素性を見る。測るだけ。費用 $0（記録と DOM を読むだけ）。**
#
# ## なぜ
#
# 2026-09-22 に指摘された。
#
#   「まだ一部対象としておかしい人をフォローしてる。
#     たとえば、何かのサービスとか店舗の公式アカウントなど。
#     フォロバされるはずないのでやめよう。」
#
# **いまの入口フィルタに「公式・企業アカウントを弾く」条件が 1 つも無い**
# （`x122` のログで確認済み）。
#
#   inactive / off-niche bio / low-density bio / random-looking handle
#   / follower count out of range
#
# ## なぜ推測で書かないか
#
# **「公式」の字面だけで弾くと、個人まで巻き込む。**
# ポイ活系の個人が「公式LINEはこちら」と書いているだけで落ちる。
#
# **どの信号なら公式アカウントだけをきれいに分けられるか**を、実データで見る。
#
# ## 見る信号（**どれが効くかは出してから決める**）
#
#   * 認証バッジの種類（**金＝ビジネス** / 青＝個人の課金 / 無し）
#   * 名前・ハンドル（株式会社 / (株) / Inc / Corp / _official / _jp / _pr）
#   * bio（公式 / オフィシャル / official / 営業時間 / 店舗 / お問い合わせ）
#   * **フォロー数とフォロワー数の比**（公式はほとんど誰もフォローしない）
#   * **返ってきたか**（`followed_back`）
#
# ## やらないこと
#
# **フォローしない。外さない。設定を変えない。LLM を呼ばない。**
# 直すのは次のタスク（最上位ルール 15・測るものと直すものを分ける）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/profile-followed-accounts.md"
RUNNER="$S/.x128-profile.js"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

# **出力は公開リポジトリに載る。** ハンドルは伏せる
mask() { "$NODE_BIN" -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  // **ハンドルは頭 2 文字だけ残す。** 誰を狙っているかを公開リポジトリに晒さない
  process.stdout.write(s.replace(/"handle"\s*:\s*"([A-Za-z0-9_]{1,15})"/g,
    (m,h)=>`"handle":"${h.slice(0,2)}…(${h.length})"`)
    .replace(/@([A-Za-z0-9_]{2,15})/g,(m,h)=>"@"+h.slice(0,2)+"…"));
});' 2>/dev/null || cat; }
secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }

{
echo "# 最近フォローした相手の素性（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 「サービスや店舗の公式アカウントをフォローしている。フォロバされるはずない」"
echo "> と指摘された（2026-09-22）。**入口に公式を弾く条件が 1 つも無い。**"
echo ">"
echo "> **「公式」の字面だけで弾くと個人まで巻き込む**（ポイ活の人が"
echo "> 「公式LINEはこちら」と書いているだけで落ちる）。**実データで信号を選ぶ。**"
echo
echo "**ハンドルは頭 2 文字だけにしてある。** 出力は公開リポジトリに載るため。"

echo
echo "## 1. フォローの記録はどこか"
echo
echo '```'
FOUND=""
for f in "$D/followed.json" "$D/follow-log.json" "$D/follow-history.json" \
         "$D/competitor-followed.json" "$D/hashtag-followed.json"; do
  if [ -f "$f" ]; then
    printf '  在る  %-44s %s bytes\n' "$f" "$(wc -c < "$f" | tr -d ' ')"
    FOUND="${FOUND:+$FOUND }$f"
  else
    printf '  無い  %s\n' "$f"
  fi
done
echo
echo "  --- data/ で follow を含むもの ---"
ls -1 "$D" 2>/dev/null | grep -i follow | sed 's/^/    /' || echo "    （無し）"
echo '```'
if [ -z "$FOUND" ]; then
  echo
  echo "- **既知の置き場に記録が無い。** 上の一覧から実体を選んで次のタスクで読む。"
fi

echo
echo "## 2. 記録に何が入っているか（**形を決め打ちしない**）"
echo
echo '```json'
"$NODE_BIN" -e '
const fs=require("fs");
const files=process.argv.slice(1).filter(f=>fs.existsSync(f));
if(!files.length){ console.log("  読めるファイルが無い"); process.exit(0); }
for(const f of files){
  let j; try{ j=JSON.parse(fs.readFileSync(f,"utf8")); }catch(e){
    console.log("  "+f+" は JSON として読めない: "+e.message); continue; }
  const rows=Array.isArray(j)?j:(j.followed||j.records||j.entries||Object.values(j));
  if(!Array.isArray(rows)){ console.log("  "+f+" は配列を取り出せない。キー: "+Object.keys(j).slice(0,8).join(",")); continue; }
  console.log("  ===== "+require("path").basename(f)+" : "+rows.length+" 件 =====");
  const last=rows.filter(r=>r&&typeof r==="object").slice(-1)[0];
  if(last) console.log("  最後の 1 件のキー: "+Object.keys(last).join(", "));
}
' $FOUND 2>&1
echo '```'
echo
echo "**\`followers_at_follow\` が入っているはず**（\`x122\` でソースに在るのを見た）。"
echo "bio や名前まで残っていれば、DOM を見に行かずに済む。"

echo
echo "## 3. 直近 30 件を、記録から並べる"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"), path=require("path");
const files=process.argv.slice(1).filter(f=>fs.existsSync(f));
const all=[];
for(const f of files){
  let j; try{ j=JSON.parse(fs.readFileSync(f,"utf8")); }catch(e){ continue; }
  const rows=Array.isArray(j)?j:(j.followed||j.records||j.entries||Object.values(j));
  if(!Array.isArray(rows)) continue;
  for(const r of rows){ if(r&&typeof r==="object") all.push({src:path.basename(f), ...r}); }
}
if(!all.length){ console.log("  1 件も取れなかった"); process.exit(0); }
const at=(r)=>r.at||r.followed_at||r.date||r.ts||"";
all.sort((a,b)=>String(at(a)).localeCompare(String(at(b))));
const last=all.slice(-30);
const h=(r)=>{ const x=r.handle||r.username||r.screen_name||r.id||"?";
  return String(x).slice(0,2)+"…"; };
console.log("  いつ                 ﾌｫﾛﾜｰ数  返った  相手        由来");
console.log("  "+"-".repeat(66));
for(const r of last){
  const fw=r.followers_at_follow ?? r.followers ?? r.follower_count ?? null;
  const back=(r.followed_back===true)?"○":((r.followed_back===false)?"×":"-");
  console.log("  "+String(at(r)).slice(0,19).padEnd(21)
    +String(fw??"-").padStart(8)+"  "+back.padStart(4)+"    "
    +h(r).padEnd(10)+"  "+String(r.src||"").replace(".json",""));
}
console.log("");
const withFw=last.filter(r=>Number.isFinite(Number(r.followers_at_follow??r.followers??r.follower_count)));
console.log("  直近 30 件 のうちフォロワー数が記録されているもの: "+withFw.length+" 件");
' $FOUND 2>&1 | secrets
echo '```'

echo
echo "## 4. 実際のプロフィールを見る（**最大 12 件・公式かどうかの信号**）"
echo
echo "**記録に bio や名前が無いので、実物を見る。** 5 分 に収めるため 12 件まで。"
echo
cat > "$RUNNER" <<'JSEOF'
// x128: フォローした相手が公式アカウントかを見分ける信号を集める。$0。
// **playwright-core**（`playwright` はこのワークスペースに無い）
const fs = require("fs");
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const MAX = 12;
const BUDGET_MS = 200 * 1000;
const t0 = Date.now();

const files = process.argv.slice(2).filter((f) => fs.existsSync(f));
const all = [];
for (const f of files) {
  let j; try { j = JSON.parse(fs.readFileSync(f, "utf8")); } catch (e) { continue; }
  const rows = Array.isArray(j) ? j : (j.followed || j.records || j.entries || Object.values(j));
  if (!Array.isArray(rows)) continue;
  for (const r of rows) if (r && typeof r === "object") all.push(r);
}
const at = (r) => r.at || r.followed_at || r.date || r.ts || "";
all.sort((a, b) => String(at(a)).localeCompare(String(at(b))));
const handles = [];
for (const r of all.slice(-40).reverse()) {
  const h = r.handle || r.username || r.screen_name;
  if (h && !handles.includes(h)) handles.push(h);
  if (handles.length >= MAX) break;
}

(async () => {
  if (!handles.length) { console.log(JSON.stringify({ note: "ハンドルが取れなかった" })); return; }
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const out = [];
  for (const h of handles) {
    if (Date.now() - t0 > BUDGET_MS) { out.push({ handle: h, skipped: "時間切れ" }); continue; }
    try {
      await p.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(3500);
      const g = await p.evaluate(() => {
        const q = (s) => document.querySelector(s);
        const txt = (s) => { const e = q(s); return e ? e.innerText.replace(/\s+/g, " ").trim() : null; };
        const nameEl = q('[data-testid="UserName"]');
        const bio = txt('[data-testid="UserDescription"]');
        // **バッジの種類。** 金＝ビジネス（公式）／青＝個人の課金
        let badge = "none";
        if (nameEl) {
          const svgs = [...nameEl.querySelectorAll("svg")];
          for (const s of svgs) {
            const lab = (s.getAttribute("aria-label") || "") + " " + (s.parentElement?.getAttribute("aria-label") || "");
            if (/認証済み組織|Verified Organization|ビジネス/i.test(lab)) { badge = "gold"; break; }
            if (/認証済み|Verified/i.test(lab)) badge = "blue";
          }
          // 金バッジは四角い枠で描かれる。色でも見る
          if (badge !== "gold" && nameEl.innerHTML.includes("#E2B719")) badge = "gold";
        }
        // フォロー数 / フォロワー数
        const nums = {};
        for (const a of document.querySelectorAll('a[href$="/following"], a[href$="/verified_followers"], a[href$="/followers"]')) {
          const href = a.getAttribute("href") || "";
          const n = (a.innerText || "").replace(/\s+/g, " ").trim();
          if (/\/following$/.test(href)) nums.following = n;
          else if (/\/followers$/.test(href)) nums.followers = n;
        }
        return {
          name: nameEl ? nameEl.innerText.split("\n")[0] : null,
          bio: bio ? bio.slice(0, 160) : null,
          badge,
          following: nums.following || null,
          followers: nums.followers || null,
          // 公式にだけ出る要素
          hasProfessional: !!q('[data-testid="UserProfessionalCategory"]'),
          category: txt('[data-testid="UserProfessionalCategory"]'),
        };
      });
      out.push({ handle: h, ...g });
    } catch (e) { out.push({ handle: h, error: String(e && e.message).slice(0, 100) }); }
  }
  await p.close(); await b.close();
  console.log(JSON.stringify(out, null, 1));
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 200) }, null, 1));
  process.exit(1);
});
JSEOF
echo '```json'
if ! "$NODE_BIN" --check "$RUNNER" >/dev/null 2>&1; then
  echo "  **構文エラーなので走らせない**"
  "$NODE_BIN" --check "$RUNNER" 2>&1 | head -4
else
  RES="${TMPDIR:-/tmp}/.x128-result.json"
  ( cd "$S" && "$NODE_BIN" "$(basename "$RUNNER")" $FOUND ) > "$RES" 2>&1
  echo "  rc=$? （**rc は証拠にならない。中身を見る**）"
  head -c 6000 "$RES" | mask | secrets
  echo
  rm -f "$RES" 2>/dev/null || true
fi
echo '```'

echo
echo "## 5. どの信号で弾くかを決める材料"
echo
echo "| 信号 | 公式だけを分けられるか |"
echo "| --- | --- |"
echo "| **\`badge: gold\`**（認証済み組織） | **いちばん強い。** 個人は金バッジを持てない |"
echo "| \`hasProfessional\` / \`category\` | 「ビジネス」「小売」等。個人事業主も付けられるので単独では弱い |"
echo "| \`following\` が極端に少ない | 公式は誰もフォローしない。**数字の取り方が表記依存**（1.2万 等） |"
echo "| 名前に 株式会社 / (株) / Inc / Corp | 強いが、取りこぼす（カタカナ社名など） |"
echo "| bio に 公式 / オフィシャル | **単独で使わない。** 個人が「公式LINE」と書く |"
echo
echo "**組み合わせを決めるのは次のタスク。** ここでは材料を出すだけ。"
echo
echo "**\`返った\` の列と突き合わせる。** 公式に分類したものが本当に返っていなければ、"
echo "その信号は正しい。返っているものが混ざっていれば、弾きすぎ。"

echo
echo "## 6. 費用"
echo
echo "**記録を読んで、プロフィールを 12 件 開くだけ。LLM を呼ばない。**"
echo "**フォローの判定自体も DOM だけなので、条件を足しても課金は増えない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

rm -f "$RUNNER" 2>/dev/null || true
echo "フォローした相手の素性を見た / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
