#!/bin/bash
# **フォローの的を認証済み（青バッジ）アカウントに寄せる。費用 $0。**
#
# ## なぜ（2026-10-12・docs/growth-strategy.md）
#
#   利用者が Premium を購入し「青バッジが既に付いているアカウントをフォローして、フォローバックを受けることが非常に重要」と指示。
#   収益化（オリジナルコンテンツ報酬）の条件は **認証済みフォロワー 500**（いま 122）。
#   x273 でフォロー系の全文を読んだうえで、**4 か所だけ**直す（推測で書かない・最上位ルール 20）。
#
#   ① follow-handle.js  : 相手のプロフィールで **青バッジの有無（verified）を読む**。
#                          環境変数 FOLLOW_REQUIRE_VERIFIED=1 のときだけ、未認証を「filtered」で弾く
#   ② competitor-follower-follow.js : 競合のフォロワー一覧を **/verified_followers（認証済みだけ）から取る**。記録に verified を残す
#   ③ hashtag-follow.js : **認証済みの投稿者だけをフォローする**（FOLLOW_REQUIRE_VERIFIED=1 を付けて呼ぶ）。記録に verified を残す
#                          ※ この経路のフォロバ率は 10.6%（全経路で最低）で、上限 90 は「今日の合計」の空き枠を埋める役
#   ④ mutual-prune.js   : **触らない。** 認証済みの相互は既に外さない（203 行目「認証済み」）
#
#   **総量は増やさない**（上限はどれも据え置き）。未認証を弾くぶん、1 日のフォロー数は減りうる。比率（最上位ルール 19）は良くなる方向。
#   フォロバの猶予 24 時間（follow-balance の GRACE_DAYS=1）も変えない。
#
# ## 安全
#
#   - 書き換える前に .bak-x278 を残す。**文字列が 1 か所ずつ完全一致しなければ、何も書かずに止める**
#   - 書いたあと `node --check`（拡張子 .js のまま隠しファイルにコピーして・最上位ルール 14）。通らなければ .bak から戻す
#   - フォローは実行しない（次の定時から効く。hashtag 10:15/17:00・competitor 11:30/18:30）
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。** 1 分で終わる。
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-verified.md"
PATCH="$W/.x278-patch.js"

cat > "$PATCH" <<'PATCHJS'
const fs = require("fs");
const { execFileSync } = require("child_process");
const S = process.argv[2];
// 字下げに依存しない: 「その文字列を含む行」を 1 行だけ探し、その行の字下げで前後に足す・置き換える
// [含む文字列, 種類("before"|"after"|"replace"), 足す行（字下げ無し・複数行可）, 置き換え時の (行)=>新しい行]
const edits = {
  "follow-handle.js": [
    ["last_post_age_days: lastPostAge,", "after", "// 2026-10-12 x278: 青バッジ（認証済み）か。UserName の中のバッジのアイコンで見る\nverified: !!document.querySelector('[data-testid=\"UserName\"] [data-testid=\"icon-verified\"]'),"],
    ["// Common: follower count range", "before", "// 2026-10-12 x278: 呼び出し側が求めたときだけ、未認証を弾く（青バッジのアカウントに寄せる）\nif (process.env.FOLLOW_REQUIRE_VERIFIED === \"1\" && profile.verified === false) {\n  return { ok: false, reason: \"not verified (FOLLOW_REQUIRE_VERIFIED)\", phase };\n}"],
  ],
  "competitor-follower-follow.js": [
    ["await page.goto(`https://x.com/${competitor}/followers`,", "replace", "// 2026-10-12 x278: 認証済みフォロワーだけの一覧から取る（COMPETITOR_VERIFIED_ONLY=0 で従来どおり）\nconst listPath = process.env.COMPETITOR_VERIFIED_ONLY === \"0\" ? \"followers\" : \"verified_followers\";", (l) => l.replace("/${competitor}/followers`", "/${competitor}/${listPath}`")],
    ["source: `competitor-follower:${competitor}`,", "after", "verified: (r.profile && typeof r.profile.verified === \"boolean\") ? r.profile.verified : null,"],
  ],
  "hashtag-follow.js": [
    ["execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: \"utf8\", timeout: 60000, maxBuffer: 2 * 1024 * 1024 });", "replace", "// 2026-10-12 x278: 認証済みの投稿者だけをフォローする（HASHTAG_REQUIRE_VERIFIED=0 で従来どおり）", (l) => l.replace("maxBuffer: 2 * 1024 * 1024 });", "maxBuffer: 2 * 1024 * 1024, env: Object.assign({}, process.env, { FOLLOW_REQUIRE_VERIFIED: process.env.HASHTAG_REQUIRE_VERIFIED === \"0\" ? \"\" : \"1\" }) });")],
    ["source: \"hashtag-follow\",", "after", "verified: (r.profile && typeof r.profile.verified === \"boolean\") ? r.profile.verified : null,"],
  ],
};
function apply(src, f) {
  let lines = src.split("\n");
  for (const [needle, kind, add, rep] of edits[f]) {
    const hits = lines.map((l, i) => l.includes(needle) ? i : -1).filter((i) => i >= 0);
    if (hits.length !== 1) throw new Error(f + ": 「" + needle.slice(0, 60) + "」を含む行が " + hits.length + " 行（1 行でなければ書かない）");
    const i = hits[0], ind = lines[i].match(/^\s*/)[0];
    const extra = add.split("\n").map((x) => ind + x);
    if (kind === "after") lines.splice(i + 1, 0, ...extra);
    else if (kind === "before") lines.splice(i, 0, ...extra);
    else { const nl = rep(lines[i]); if (nl === lines[i]) throw new Error(f + ": 置き換えが効かない"); lines.splice(i, 1, ...extra, nl); }
  }
  return lines.join("\n");
}
const report = [];
const plan = {};
for (const f of Object.keys(edits)) {
  const p = S + "/" + f;
  let src = fs.readFileSync(p, "utf8");
  if (src.includes("x278")) { report.push(f + ": もう当たっている（x278 の印あり）。触らない"); continue; }
  try { plan[f] = apply(src, f); }
  catch (e) { console.log(JSON.stringify({ ok: false, error: e.message })); process.exit(0); }
}
// 全部の一致を確かめてから書く
for (const [f, src] of Object.entries(plan)) {
  const p = S + "/" + f;
  fs.copyFileSync(p, p + ".bak-x278");
  fs.writeFileSync(p, src);
  const chk = S + "/.x278-check-" + f;   // 拡張子 .js のまま（最上位ルール 14）
  fs.copyFileSync(p, chk);
  try { execFileSync(process.execPath, ["--check", chk], { stdio: "pipe" }); report.push(f + ": 書いた・node --check 通過"); }
  catch (e) { fs.copyFileSync(p + ".bak-x278", p); report.push(f + ": **node --check に落ちたので .bak から戻した** " + String(e.stderr || e.message).slice(0, 200)); }
  finally { try { fs.unlinkSync(chk); } catch {} }
}
console.log(JSON.stringify({ ok: true, report }));
PATCHJS

{
echo "# フォローの的を認証済みに寄せる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・フォローは実行していない）"
echo
echo '```json'
cd "$W" && node "$PATCH" "$S" 2>&1 | tail -3
echo '```'
echo
echo "## 当たった行（印 x278 の前後）"
echo
echo '```javascript'
for f in follow-handle.js competitor-follower-follow.js hashtag-follow.js; do
  echo "// --- $f"
  grep -n -A3 "x278" "$S/$f" 2>/dev/null | head -14
done
echo '```'
echo
echo "**フォローは実行していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 戻すときは各ファイルの .bak-x278。"
} > "$OUT" 2>&1
rm -f "$PATCH"
if grep -q '"ok":true' "$OUT"; then echo "フォローの的を認証済みに寄せた / $(basename "$OUT")"; else echo "**当てられなかった（何も書いていない）** / $(basename "$OUT")"; fi
