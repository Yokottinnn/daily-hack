#!/bin/bash
# **良い種から辿って、次の種の候補を出す。測るだけ。費用 $0（DOM 読み取りのみ）。**
#
# ## なぜこの辿り方なのか
#
# x104 で候補プールが尽きた。`influencers.json` は 7 件、
# `comment-state.json` の 58 件 は**小さいアカウント中心**で種に使えない
# （帯に入るのは roomrakutentoku 5,264 のみ）。
#
# **手元のリストは全部 見た。外から取るしかない。**
#
# そこで**いちばん確かな信号から辿る**。`himawari56757`（返り率 26.0%）から
# フォローして、**実際に返してくれた人**は「こちらの狙う層」そのもの。
# **その人たちが他に誰をフォローしているか**を数えれば、
# 同じ層を抱えたアカウントが浮く。
#
# ## 選ぶ基準（これまでの実測で確定している）
#
#   ① **規模では選ばない** — okamiler_pn 18.2%/平均 7757 と ukk_hx 4.2%/平均 6993 が
#      ほぼ同規模で 4 倍 違った
#   ② **ただし実証済みの帯から出ない** — いまの種は 3.8 万〜9 万
#   ③ **ブランド公式より個人**
#
# ## 人のハンドルは出さない
#
# **辿る相手（こちらのフォロワー）の名前は 1 件も出さない。**
# 出すのは**集計後の候補アカウント（公開アカウント）と件数だけ。**
#
# ## 時間
#
# **1 人 あたり 1 画面 だけ読む。**深くスクロールしない。
# **経過 200 秒 を超えたらスクリプト側で止める**（`timeout` は macOS に無い）。
#
# ## やらないこと
#
# **フォローしない。種を触らない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/lookalike-seeds.md"
RUNNER="$S/.x108-lookalike.js"

# **一時ファイルの拡張子は `.js` のまま**（`.new` だと macOS の node が弾く）
cat > "$RUNNER" <<'JSEOF'
// x108: 良い種から返してくれた人を辿り、次の種の候補を数える。$0。
// 取り方は check-follower-v2.js / competitor-follower-follow.js を写した。
const fs = require("fs");
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const RF = process.env.HOME + "/.openclaw/workspace/data/reply-followers.json";
const SEED = "competitor-follower:himawari56757";
const BUDGET_MS = 200 * 1000;
const MAX_PEOPLE = 6;
const t0 = Date.now();

const isBack = (r) => r.follows_back === true
  || String(r.followback_status || "").toLowerCase() === "yes";

let rows = [];
try {
  const j = JSON.parse(fs.readFileSync(RF, "utf8"));
  rows = Object.entries(j)
    .filter(([, v]) => v && typeof v === "object")
    .filter(([, v]) => String(v.source || "") === SEED && isBack(v))
    .map(([k]) => String(k).replace(/^@/, ""));
} catch (e) {
  console.log(JSON.stringify({ fatal: "reply-followers が読めない: " + e.message.slice(0, 100) }));
  process.exit(1);
}
const people = rows.slice(0, MAX_PEOPLE);
// **いまの種と、自分自身は候補から外す**
const EXCLUDE = new Set(["himawari56757", "haiji_doctor", "okamiler_pn", "tokufree3",
  "ukk_hx", "money_yossy", "POIKATSU_OTAKE", "heng_ji31590"]);

(async () => {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const count = {};
  let read = 0, skipped = 0;
  for (const h of people) {
    if (Date.now() - t0 > BUDGET_MS) { skipped++; continue; }
    try {
      await p.goto("https://x.com/" + h + "/following", { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(5000);
      const hs = await p.evaluate(() => {
        const out = [];
        for (const a of document.querySelectorAll('a[role="link"][href^="/"]')) {
          const m = a.getAttribute("href").match(/^\/([A-Za-z0-9_]{3,15})$/);
          if (m) out.push(m[1]);
        }
        return [...new Set(out)];
      });
      read++;
      for (const x of hs) {
        if (EXCLUDE.has(x)) continue;
        count[x] = (count[x] || 0) + 1;
      }
    } catch (e) { skipped++; }
  }
  await p.close(); await b.close();
  const top = Object.entries(count).sort((a, b) => b[1] - a[1]).slice(0, 30);
  console.log(JSON.stringify({
    elapsed_sec: Math.round((Date.now() - t0) / 1000),
    // **対象 N / 読んだ M を必ず両方 出す**（最上位ルール 14）
    target: people.length, read, skipped,
    pool: rows.length,
    top: top.map(([h, n]) => ({ handle: h, n })),
  }, null, 1));
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e.message).slice(0, 200) }));
  process.exit(1);
});
JSEOF

{
echo "# 良い種から辿った、次の種の候補"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x104 で**手元の候補プールは尽きた。** \`influencers.json\` は 7 件、"
echo "> \`comment-state.json\` の 58 件 は小さいアカウント中心で種に使えない。"
echo ">"
echo "> そこで**いちばん確かな信号から辿る。** \`himawari56757\`（返り率 26.0%）から"
echo "> フォローして**実際に返してくれた人**が、他に誰をフォローしているかを数える。"
echo
echo "**辿る相手の名前は 1 件も出さない。** 出すのは集計後の候補と件数だけ。"

echo
echo "## 1. 実行"
echo
echo '```'
if ! /usr/local/bin/node --check "$RUNNER" >/dev/null 2>&1; then
  echo "  **構文エラーなので走らせない。**"
else
  echo "  node --check: 通った"
  RES="${TMPDIR:-/tmp}/.x108-result.json"
  ( cd "$S" && /usr/local/bin/node "$(basename "$RUNNER")" ) > "$RES" 2>&1
  echo "  rc=$? （**rc は証拠にならない。中身を見る**）"
  echo
  /usr/local/bin/node -e '
const fs = require("fs");
let d; try { d = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) {
  console.log("  **結果が読めない。生の出力:**");
  try { console.log(fs.readFileSync(process.argv[1], "utf8").slice(0, 900)); } catch {}
  process.exit(0);
}
if (d.fatal) { console.log("  **落ちた: " + d.fatal + "**"); process.exit(0); }
console.log("  経過 " + d.elapsed_sec + " 秒");
console.log("  返してくれた人: " + d.pool + " 人 / **対象 " + d.target
  + " 人 → 読めた " + d.read + " 人 / 読めなかった " + d.skipped + " 人**");
console.log("");
if (!d.top.length) { console.log("  **候補が 1 件も出なかった。**"); process.exit(0); }
console.log("    候補                    何人が フォローしているか");
console.log("    " + "-".repeat(52));
for (const r of d.top) {
  const bar = "#".repeat(Math.min(r.n, 20));
  console.log("    " + r.handle.padEnd(22) + String(r.n).padStart(3) + " 人  " + bar);
}
' "$RES" 2>&1
  rm -f "$RES" 2>/dev/null || true
fi
echo '```'
echo
echo "**複数人が共通してフォローしている先ほど、同じ層を抱えている可能性が高い。**"
echo "ただし**これは候補の入口であって、決定ではない。**"
echo "フォロワー数と中身を見てから選ぶ（規模では選ばないが、9 万 以下の帯から出ない）。"

echo
echo "## 2. いまの 4 種（比較用）"
echo
echo '```'
echo "    himawari56757  26.0%     haiji_doctor  20.8%"
echo "    okamiler_pn    18.2%     tokufree3     16.2%"
echo
echo "    外した 3 つ: ukk_hx 4.2% / money_yossy 8.6% / POIKATSU_OTAKE 10.0%"
echo "    群で見ると 外した 3 つ 7.9% / 残した 4 つ 21.1%（2.7 倍）"
echo '```'

echo
echo "## 3. 費用"
echo
echo "**フォロー一覧を DOM で読むだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**種を足すのも \$0。** \`competitor-follower-follow\` は DOM 操作のみ。"
echo "返信ループは \`MAX_PICKS\` 6 で **約 \$0.95/月（推定）**。実測は明日 確かめる。"
} > "$OUT" 2>&1

rm -f "$RUNNER" 2>/dev/null || true
echo "次の種の候補 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
