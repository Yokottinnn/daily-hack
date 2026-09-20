#!/bin/bash
# **種の候補 14 件 のフォロワー数とプロフィールを測る。測るだけ。費用 $0。**
#
# ## なぜ 54 件 ではなく 14 件 なのか
#
# **必要なのは 3 つ だけ。** 54 件 全部 測る理由が無い。
# 1 件 あたり 6 秒 待つ作りなので、54 件 だと待ちだけで 324 秒。
# **5 分 を超えて heartbeat ごと止める**（最上位ルール 15）。
#
# 絞り方は「**返信が繰り返し選んでいる人**」。x97 の実測で、
# `comment-orchestrator` の picker が何度もジャンル判定を通した相手が分かっている。
# 返信経路は **21.9%（n=146）** で競合の平均より高く、**選別が効いている証拠がある。**
#
# ## 外したもの
#
#   bicsim_official   92000  **ブランド公式**（フォロワーが一般層）
#   inami_furusato    hashtag-follow が `inactive (last post 162d ago)` で弾いた
#   osusume999        hashtag-follow が `off-niche bio` で 5 回 弾いた
#
# ## 取り方は `check-follower-v2.js` を写す（**推測しない**）
#
# x103 で実物が読めた。**自分のアカウント固定で引数を取らない作り**だったので
# そのままは使えないが、**取り方の正解は全部 書いてある。**
#
#   playwright-core / connectOverCDP / contexts()[0].newPage()
#   goto(..., { waitUntil: "domcontentloaded" }) → waitForTimeout(6000)
#   text.match(/([\d,]+)\s*フォロワー/)
#
# **セレクタを新しく考えない。** 動いているものを写す。
#
# ## 自分で時間を切る
#
# **`timeout` は macOS に無い**（最上位ルール 14）。
# スクリプト側で**経過 200 秒 を超えたらそこで止める。**
# 途中で止まっても、測れたぶんはレポートに出る。
#
# ## やらないこと
#
# **フォローしない。種を触らない。設定を変えない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/seed-candidate-stats.md"
RUNNER="$S/.x104-measure-candidates.js"

secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }

# **一時ファイルの拡張子は `.js` のまま**（`.new` を付けると macOS の node が弾く）
cat > "$RUNNER" <<'JSEOF'
// x104: 種の候補のフォロワー数とプロフィールを測る。$0（LLM を呼ばない）。
// 取り方は check-follower-v2.js を写した。**セレクタを新しく考えない。**
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const BUDGET_MS = 200 * 1000;           // **自分で時間を切る**
const HANDLES = process.argv.slice(2);
const t0 = Date.now();

(async () => {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const ctx = b.contexts()[0];
  const p = await ctx.newPage();
  const out = [];
  for (const h of HANDLES) {
    if (Date.now() - t0 > BUDGET_MS) { out.push({ handle: h, skipped: "時間切れ" }); continue; }
    try {
      await p.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(6000);
      const r = await p.evaluate(() => {
        const text = document.body.innerText;
        const m1 = text.match(/([\d,]+)\s*フォロワー/);
        const m2 = text.match(/([\d,]+)\s*フォロー中/);
        // bio は名前とハンドルの直後に出る。**長すぎる本文は取らない**
        const bio = text.split("\n").slice(0, 18).join(" / ").slice(0, 160);
        return {
          followers: m1 ? m1[1] : null,
          following: m2 ? m2[1] : null,
          bio,
          missing: /このアカウントは存在しません|アカウントは凍結されています/.test(text),
        };
      });
      out.push({ handle: h, ...r });
    } catch (e) {
      out.push({ handle: h, error: String(e.message).slice(0, 100) });
    }
  }
  await p.close();
  await b.close();
  console.log(JSON.stringify({ elapsed_sec: Math.round((Date.now() - t0) / 1000), rows: out }, null, 1));
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e.message).slice(0, 200) }));
  process.exit(1);
});
JSEOF

{
echo "# 種の候補 14 件 のフォロワー数とプロフィール"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **必要なのは 3 つ だけ。** 54 件 全部 測る理由が無い。"
echo "> 1 件 6 秒 待つ作りなので、54 件 だと待ちだけで 324 秒 かかり、"
echo "> **5 分 を超えて heartbeat ごと止める**（最上位ルール 15）。"
echo ">"
echo "> 絞り方は「**返信が繰り返し選んでいる人**」。返信経路は **21.9%（n=146）** で"
echo "> 競合の平均より高く、**picker の選別が効いている証拠がある。**"
echo
echo "**測るだけ。フォローしない。種を触らない。**"

echo
echo "## 0. 取り方"
echo
echo '```'
echo "  \`check-follower-v2.js\` を写した（x103 で実物を読んだ）。"
echo "  **セレクタを新しく考えていない。**"
echo
if [ -f "$RUNNER" ]; then
  echo "  一時スクリプト: $(basename "$RUNNER")（**拡張子は .js のまま**）"
  /usr/local/bin/node --check "$RUNNER" >/dev/null 2>&1 \
    && echo "  node --check: **通った**" \
    || echo "  node --check: **落ちた。走らせない。**"
fi
echo "  **経過 200 秒 を超えたらスクリプト側で止める**（macOS に timeout は無い）。"
echo '```'

echo
echo "## 1. 結果"
echo
echo '```'
if ! /usr/local/bin/node --check "$RUNNER" >/dev/null 2>&1; then
  echo "  **構文エラーなので走らせない。**"
else
  RES="${TMPDIR:-/tmp}/.x104-result.json"
  ( cd "$S" && /usr/local/bin/node "$(basename "$RUNNER")" \
      fxmeitantei mao_otk_tw coupon_gorilla1 1xQ12jhpZeUJBRD \
      sa51545199 x1qnsd t_sh_30143 rmonsukikamo \
      HarrysShare toshi00213591 goriyama49676 Kimama_FIRE \
      NISA_kansoku roomrakutentoku ) > "$RES" 2>&1
  RC=$?
  echo "  実行 rc=$RC （**rc は証拠にならない。中身を見る**）"
  echo
  /usr/local/bin/node -e '
const fs = require("fs");
let d; try { d = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) {
  console.log("  **結果が読めない。生の出力を出す。**");
  try { console.log(fs.readFileSync(process.argv[1], "utf8").slice(0, 1200)); } catch {}
  process.exit(0);
}
if (d.fatal) { console.log("  **落ちた: " + d.fatal + "**"); process.exit(0); }
console.log("  経過 " + d.elapsed_sec + " 秒 / " + d.rows.length + " 件");
console.log("");
const num = (s) => (s ? Number(String(s).replace(/,/g, "")) : null);
const rows = d.rows.map((r) => ({ ...r, f: num(r.followers), g: num(r.following) }));
rows.sort((a, b) => (b.f ?? -1) - (a.f ?? -1));
console.log("    " + "ハンドル".padEnd(20) + "フォロワー  フォロー中   判定");
console.log("    " + "-".repeat(72));
for (const r of rows) {
  if (r.skipped) { console.log("    " + r.handle.padEnd(20) + "  " + r.skipped); continue; }
  if (r.error)   { console.log("    " + r.handle.padEnd(20) + "  **取れない: " + r.error + "**"); continue; }
  if (r.missing) { console.log("    " + r.handle.padEnd(20) + "  **存在しない／凍結**"); continue; }
  let v = "";
  if (r.f === null) v = "**数が読めない**";
  else if (r.f < 3000) v = "小さい（種としては母数不足）";
  else if (r.f <= 90000) v = "**実証済みの帯（3千〜9万）**";
  else v = "帯の外（9 万 超）";
  console.log("    " + r.handle.padEnd(20) + String(r.f ?? "?").padStart(9)
    + String(r.g ?? "?").padStart(11) + "   " + v);
}
console.log("");
console.log("  --- プロフィールの冒頭（**ジャンルの近さを見る**）---");
for (const r of rows) {
  if (!r.bio) continue;
  console.log("    ══ " + r.handle);
  console.log("      " + String(r.bio).replace(/\s+/g, " ").slice(0, 150));
}
' "$RES" 2>&1 | secrets
  rm -f "$RES" 2>/dev/null || true
fi
echo '```'

echo
echo "## 2. 選ぶ基準（**x96・x99・x101 で確定した**）"
echo
echo '```'
echo "    ① **規模では選ばない** — okamiler_pn 18.2%/平均 7757 と ukk_hx 4.2%/平均 6993 は"
echo "       ほぼ同じ規模で 4 倍 違った"
echo "    ② **ただし実証済みの帯から出ない** — いまの種は 3.8 万〜9 万。"
echo "       25〜34 万 のブランド公式は範囲の外"
echo "    ③ **ブランド公式より個人** — 種は「その人のフォロワーを追う」入口。"
echo "       ブランド公式のフォロワーは一般層で、自分で選んでフォローした人ではない"
echo "    ④ **休眠と機械的なハンドルが多い相手は避ける** — 9/18〜9/20 の弾き理由は"
echo "       inactive 26 回 / random-looking handle 25 回 で、悪い種の特徴だった"
echo '```'

echo
echo "## 3. いまの 4 種（**戻すときの比較用**）"
echo
echo '```'
echo "    himawari56757  26.0%     haiji_doctor  20.8%"
echo "    okamiler_pn    18.2%     tokufree3     16.2%"
echo
echo "    外した 3 つ: ukk_hx 4.2% / money_yossy 8.6% / POIKATSU_OTAKE 10.0%"
echo "    退避は competitor-follower-follow.js.bak-* にある"
echo '```'

echo
echo "## 4. 費用"
echo
echo "**プロフィールを DOM で読むだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**種を入れ替えるのも \$0。** \`competitor-follower-follow\` は DOM 操作のみ。"
echo "返信ループは \`MAX_PICKS\` を 6 にしたため **約 \$0.95/月（推定）**。"
echo "**実測は次の 24 時間 の \`cost_24h_usd\` で確かめる。推定のままにしない。**"
} > "$OUT" 2>&1

rm -f "$RUNNER" 2>/dev/null || true
echo "候補 14 件 の実数 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
