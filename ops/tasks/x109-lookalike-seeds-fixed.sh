#!/bin/bash
# **x108 のセレクタを直して取り直す。測るだけ。費用 $0（DOM 読み取りのみ）。**
#
# ## x108 は 2 つの意味で失敗した
#
#   home            6 人   ← **X 自身のサイドバー**。アカウントではない
#   explore         6 人   ← 同上
#   notifications   6 人   ← 同上
#   game8jp / mouse_computer / GTUNE_NEXTGEAR / db_legends_jp / animatetimes …
#
# ### ① セレクタが広すぎた
#
# `a[role="link"][href^="/"]` は**ナビゲーションのリンクも全部 拾う。**
# **`[data-testid="UserCell"]` の中に限る。**
#
# ### ② ノイズを除いても、候補がゲーム・アニメ・PC ブランドばかりだった
#
# `himawari56757`（返り率 26.0%）から返してくれた人の関心が、
# **ポイ活・節約ではない可能性がある。** 返ってきたのは
# 「相互フォローを返す習慣のある人」かもしれない。
#
# **ただし 6 人 × 1 画面 だけの標本だった。** 今回は人数を増やして、
# **拾えた件数も出す**（0 件 なら 0 件 と分かるように）。それで傾向がはっきりする。
#
# ## 人のハンドルは出さない
#
# **辿る相手（こちらのフォロワー）の名前は 1 件も出さない。**
# 出すのは**集計後の候補（公開アカウント）と件数だけ。**
#
# ## 時間
#
# 1 人 1 画面。**経過 200 秒 で打ち切る**（`timeout` は macOS に無い）。
#
# ## やらないこと
#
# **フォローしない。種を触らない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/lookalike-seeds-2.md"
RUNNER="$S/.x109-lookalike.js"

cat > "$RUNNER" <<'JSEOF'
// x109: 良い種から返してくれた人を辿り、次の種の候補を数える。$0。
// **x108 との違い**: UserCell に限定し、拾えた件数も出す。
const fs = require("fs");
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const RF = process.env.HOME + "/.openclaw/workspace/data/reply-followers.json";
const SEED = "competitor-follower:himawari56757";
const BUDGET_MS = 200 * 1000;
const MAX_PEOPLE = 13;
const t0 = Date.now();

const isBack = (r) => r.follows_back === true
  || String(r.followback_status || "").toLowerCase() === "yes";

let pool = [];
try {
  const j = JSON.parse(fs.readFileSync(RF, "utf8"));
  pool = Object.entries(j)
    .filter(([, v]) => v && typeof v === "object")
    .filter(([, v]) => String(v.source || "") === SEED && isBack(v))
    .map(([k]) => String(k).replace(/^@/, ""));
} catch (e) {
  console.log(JSON.stringify({ fatal: "reply-followers が読めない: " + e.message.slice(0, 100) }));
  process.exit(1);
}
const people = pool.slice(0, MAX_PEOPLE);
const EXCLUDE = new Set(["himawari56757", "haiji_doctor", "okamiler_pn", "tokufree3",
  "ukk_hx", "money_yossy", "POIKATSU_OTAKE", "heng_ji31590"]);

(async () => {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const count = {};
  const perPerson = [];
  let read = 0, skipped = 0;
  for (const h of people) {
    if (Date.now() - t0 > BUDGET_MS) { skipped++; continue; }
    try {
      await p.goto("https://x.com/" + h + "/following", { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(5000);
      const r = await p.evaluate(() => {
        // **UserCell の中のリンクだけを見る。** ナビ（/home /explore …）を拾わない
        const cells = document.querySelectorAll('[data-testid="UserCell"]');
        const out = [];
        for (const c of cells) {
          for (const a of c.querySelectorAll('a[href^="/"]')) {
            const m = a.getAttribute("href").match(/^\/([A-Za-z0-9_]{2,15})$/);
            if (m) { out.push(m[1]); break; }   // 1 セル 1 ハンドル
          }
        }
        return { cells: cells.length, handles: [...new Set(out)] };
      });
      read++;
      perPerson.push({ cells: r.cells, got: r.handles.length });
      for (const x of r.handles) {
        if (EXCLUDE.has(x)) continue;
        count[x] = (count[x] || 0) + 1;
      }
    } catch (e) { skipped++; }
  }
  await p.close(); await b.close();
  const top = Object.entries(count).sort((a, b) => b[1] - a[1]).slice(0, 30);
  console.log(JSON.stringify({
    elapsed_sec: Math.round((Date.now() - t0) / 1000),
    pool: pool.length, target: people.length, read, skipped,
    per_person: perPerson,
    distinct: Object.keys(count).length,
    top: top.map(([h, n]) => ({ handle: h, n })),
  }, null, 1));
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e.message).slice(0, 200) }));
  process.exit(1);
});
JSEOF

{
echo "# 次の種の候補（セレクタを直して取り直し）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x108 は \`a[role=\"link\"][href^=\"/\"]\` が広すぎて、"
echo "> **X 自身のサイドバー（/home /explore /notifications）を拾っていた。**"
echo "> 今回は **\`[data-testid=\"UserCell\"]\` の中に限る。**"
echo ">"
echo "> あわせて**人数を 6 → 13 に増やし、拾えた件数も出す**（0 件 なら 0 件 と分かるように）。"
echo
echo "**辿る相手の名前は 1 件も出さない。**"

echo
echo "## 1. 結果"
echo
echo '```'
if ! /usr/local/bin/node --check "$RUNNER" >/dev/null 2>&1; then
  echo "  **構文エラーなので走らせない。**"
else
  RES="${TMPDIR:-/tmp}/.x109-result.json"
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
const cells = d.per_person.map((x) => x.cells);
console.log("  1 人 あたりに見えた UserCell: " + (cells.length ? cells.join(" / ") : "（無し）"));
const zero = cells.filter((c) => c === 0).length;
if (zero) console.log("  **UserCell が 0 件 だった人: " + zero + " 人**（非公開か、読み込めていない）");
console.log("  重複を除いた候補: " + d.distinct + " 件");
console.log("");
if (!d.top.length) { console.log("  **候補が 1 件も出なかった。**"); process.exit(0); }
console.log("    候補                    何人が フォローしているか");
console.log("    " + "-".repeat(52));
for (const r of d.top) {
  console.log("    " + r.handle.padEnd(22) + String(r.n).padStart(3) + " 人  " + "#".repeat(Math.min(r.n, 20)));
}
' "$RES" 2>&1
  rm -f "$RES" 2>/dev/null || true
fi
echo '```'
echo
echo "**ナビが消えているかを最初に見る。** \`home\` \`explore\` \`notifications\` が"
echo "残っていたら、セレクタがまだ効いていない。"
echo
echo "**そのうえで、候補の顔ぶれがポイ活・節約に寄っているかを見る。**"
echo "x108 ではゲーム・アニメ・PC ブランドばかりだった。同じ傾向が出るなら、"
echo "**「返してくれた人 ＝ 狙う層」という前提そのものが崩れる。**"
echo "その場合は種を増やすより、**返り率の高い相手をどう選ぶか**に戻る必要がある。"

echo
echo "## 2. 選ぶ基準（実測で確定している）"
echo
echo '```'
echo "    ① 規模では選ばない — okamiler_pn 18.2%/平均 7757 と ukk_hx 4.2%/平均 6993 が"
echo "       ほぼ同規模で 4 倍 違った"
echo "    ② ただし実証済みの帯から出ない — いまの種は 3.8 万〜9 万"
echo "    ③ ブランド公式より個人"
echo
echo "    いまの 4 種: himawari56757 26.0% / haiji_doctor 20.8%"
echo "                 okamiler_pn   18.2% / tokufree3    16.2%"
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
echo "**種を足すのも \$0。** 返信ループは \`MAX_PICKS\` 6 で **約 \$0.95/月（推定）**。"
echo "実測は次の 24 時間 の \`cost_24h_usd\` で確かめる。"
} > "$OUT" 2>&1

rm -f "$RUNNER" 2>/dev/null || true
echo "次の種の候補（直したもの） / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
