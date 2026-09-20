#!/bin/bash
# **どの経路が何人 連れてきているかを測る。測るだけ。費用 $0。**
#
# ## なぜ
#
# `follower-snapshot` を戻して、**実数が 264 だと分かった**（227 ではなかった）。
#
#   2026-09-08  227
#   2026-09-20  264      → **+37 / 12 日 ＝ 3.08 人/日**
#
# **目標は 9/30 までに 300。** 残り 36 人 / 10 日 ＝ **3.6 人/日** が要る。
# いまのペースの **約 1.17 倍**。どこを伸ばせば届くかを、実物で決める。
#
# ## 伸ばせる余地がある場所は 3 つしかない
#
#   comment-warmup            返信してフォロー（MAX_PICKS_PER_FIRE=4・1 日 4 回）
#   competitor-follower-follow 競合のフォロワーを追う（CAP=30・1 日 2 回）
#   hashtag-follow            ハッシュタグから追う（CAP=90・1 日 2 回）
#
# **量を増やす前に、1 フォローあたり何人 返ってくるかを経路ごとに見る。**
# 返りの悪い経路を増やしても、フォロー数が増えるだけでフォロワーは増えない。
# （実際 2026-09-13 の帯別では 300-999 が 28.6%、5000-49999 が 6.7% で 4 倍 違った）
#
# ## 推測しないための作り
#
# **フィールド名を当て推量しない。** `reply-followers.json` に実際に入っている
# **キーの分布をまず出す。** そのうえで経路（`source` 等）ごとに集計する。
# キーが無ければ「無い」と出す。**それらしい数字を置かない**（最上位ルール 2-B / 11）。
#
# ## やらないこと
#
# **設定を変えない。CAP を触らない。フォローしない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/follower-attribution.md"
RF="$D/reply-followers.json"
FS="$L/follower-snapshot.log"

hide() { sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g' \
                -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){1,}/<伏せ・ハンドル列>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# どの経路が何人 連れてきているか"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`follower-snapshot\` を戻して、**実数が 264** だと分かった（227 ではなかった）。"
echo "> **目標 300 まで 36 人 / 10 日 ＝ 3.6 人/日。** いまのペース 3.08 人/日 の約 1.17 倍。"
echo ">"
echo "> **量を増やす前に、経路ごとの返り率を見る。** 返りの悪い経路を増やしても"
echo "> フォロー数が増えるだけで、フォロワーは増えない。"
echo
echo "**測るだけ。CAP を触らない。フォローしない。**"

# ═══════════ 1. 実際に入っているキー ═══════════
echo
echo "## 1. \`reply-followers.json\` に**実際に入っているキー**（推測しない）"
echo
echo '```'
if [ ! -f "$RF" ]; then
  echo "  **$RF が無い。** data/ の候補:"
  ls -1 "$D" 2>/dev/null | grep -i -E 'follow' | head -10 | sed 's/^/    /'
else
  /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) { console.log("  **読めない: " + e.message.slice(0,120) + "**"); process.exit(0); }
const rows = Object.values(j).filter((v) => v && typeof v === "object");
console.log("  レコード数: " + rows.length);
const keys = {};
for (const r of rows) for (const k of Object.keys(r)) keys[k] = (keys[k] || 0) + 1;
console.log("");
console.log("  --- キーと、値が入っている件数 ---");
for (const [k, n] of Object.entries(keys).sort((a, b) => b[1] - a[1])) {
  console.log("    " + String(k).padEnd(26) + " " + n + " 件");
}
// 経路らしいキーの値の分布も出す（当て推量で 1 つに決めない）
console.log("");
console.log("  --- 経路らしいキーの値 ---");
let found = 0;
for (const k of ["source", "origin", "via", "from", "picked_by", "job"]) {
  if (!keys[k]) continue;
  found++;
  const vals = {};
  for (const r of rows) if (r[k] !== undefined) vals[String(r[k])] = (vals[String(r[k])] || 0) + 1;
  console.log("    " + k + ":");
  for (const [v, n] of Object.entries(vals).sort((a, b) => b[1] - a[1]).slice(0, 12)) {
    console.log("      " + String(v).padEnd(32) + " " + n + " 件");
  }
}
if (!found) console.log("    **経路を示すキーが無い。** 上のキー一覧から代わりになるものを探す");
' "$RF" 2>&1 | clean
fi
echo '```'

# ═══════════ 2. 経路ごとの返り率 ═══════════
echo
echo "## 2. 経路ごとの返り率（**mature ＝ フォローから 72 時間 以上**）"
echo
echo '```'
if [ -f "$RF" ]; then
  /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) { console.log("  **読めない**"); process.exit(0); }
const rows = Object.values(j).filter((v) => v && typeof v === "object");
const MATURE = 72 * 3600 * 1000, now = Date.now();
// `follows_back` は 2026-09-13 に 1 回 書かれたきり。実運用は `followback_status`
const isBack = (r) => r.follows_back === true
  || String(r.followback_status || "").toLowerCase() === "yes";
const srcKey = ["source", "origin", "via", "from", "picked_by", "job"]
  .find((k) => rows.some((r) => r[k] !== undefined)) || null;
if (!srcKey) { console.log("  **経路のキーが無いので、経路別には出せない。**"); }
const g = {};
for (const r of rows) {
  const s = srcKey ? String(r[srcKey] === undefined ? "(無し)" : r[srcKey]) : "(全体)";
  const c = g[s] || (g[s] = { n: 0, mature: 0, back: 0 });
  c.n++;
  const t = Date.parse(r.followed_at || r.at || "");
  if (t && now - t >= MATURE) { c.mature++; if (isBack(r)) c.back++; }
}
console.log("    " + "経路".padEnd(30) + "件数   mature  返った  返り率");
console.log("    " + "-".repeat(66));
for (const [s, c] of Object.entries(g).sort((a, b) => b[1].n - a[1].n)) {
  const rate = c.mature ? (c.back / c.mature * 100).toFixed(1) + "%" : "—";
  const note = c.mature < 20 ? "  ← 件数が足りない。判断しない" : "";
  console.log("    " + s.padEnd(30) + String(c.n).padStart(5) + String(c.mature).padStart(8)
    + String(c.back).padStart(8) + rate.padStart(8) + note);
}
' "$RF" 2>&1 | clean
fi
echo '```'
echo
echo "**mature が 20 件 未満の行は率を信じない。** 1 件の増減で数 % 動く。"

# ═══════════ 3. 直近 14 日 のフォロー実績 ═══════════
echo
echo "## 3. 直近 14 日、**日ごとに何件 フォローしたか**"
echo
echo '```'
if [ -f "$RF" ]; then
  /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { process.exit(0); }
const rows = Object.values(j).filter((v) => v && typeof v === "object");
const srcKey = ["source", "origin", "via", "from", "picked_by", "job"]
  .find((k) => rows.some((r) => r[k] !== undefined));
const since = Date.now() - 14 * 86400000;
const byDay = {};
for (const r of rows) {
  const t = Date.parse(r.followed_at || r.at || "");
  if (!t || t < since) continue;
  const d = new Date(t).toISOString().slice(0, 10);
  const s = srcKey ? String(r[srcKey] === undefined ? "(無し)" : r[srcKey]) : "(全体)";
  const c = byDay[d] || (byDay[d] = {});
  c[s] = (c[s] || 0) + 1;
}
const days = Object.keys(byDay).sort();
if (!days.length) { console.log("    **直近 14 日 のフォロー記録が無い。**"); }
for (const d of days) {
  const parts = Object.entries(byDay[d]).sort((a, b) => b[1] - a[1])
    .map(([s, n]) => s + "=" + n).join("  ");
  const tot = Object.values(byDay[d]).reduce((a, b) => a + b, 0);
  console.log("    " + d + "  計 " + String(tot).padStart(3) + "   " + parts);
}
' "$RF" 2>&1 | clean
fi
echo '```'
echo
echo "**上限（CAP）は安全弁であって実績ではない。** 上の実数と比べて、"
echo "**上限に当たっていないなら「増やす」の余地は上限ではなく候補の数にある。**"

# ═══════════ 4. フォロワーの実推移 ═══════════
echo
echo "## 4. フォロワーの実推移（**一次情報**）"
echo
echo '```'
if [ -f "$FS" ]; then
  grep -oE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][^}]*"count_today":[0-9]+' "$FS" 2>/dev/null \
    | sed -E 's/^([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]).*"count_today":([0-9]+)$/\1 \2/' \
    | awk '{ last[$1] = $2 } END { for (d in last) print d, last[d] }' \
    | sort | tail -10 | awk '{ if (p) printf("    %s  %4d  (%+d)\n", $1, $2, $2-p); else printf("    %s  %4d\n", $1, $2); p=$2 }'
  echo
  echo "  --- 直近の記録に含まれる disappeared / new ---"
  tail -3 "$FS" 2>/dev/null \
    | sed -E 's/.*"today":"([^"]*)".*"count_today":([0-9]+).*"disappeared":([0-9]+),"new":([0-9]+).*/    \1  計 \2  （去った \3 ／ 来た \4）/' \
    | cut -c1-120
else
  echo "    **$FS が無い。**"
fi
echo '```'
echo
echo "**去った数も見る。** 来た数だけ増やしても、去る数が同じだけ増えれば止まる。"

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**JSON とログを読んで数えるだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**量を増やす判断をするときは、増えたあとの月額を必ず出す**（最上位ルール 2-B）。"
echo "いまの実測は 1 回 \$0.003 ／ 1 日 \$0.021 ／ 1 か月 約 \$0.63。"
echo "\`MAX_PICKS\` を 4 → 6 にすると 1 か月 約 \$0.95、4 → 8 で約 \$1.26 になる見込み"
echo "（**推定**。前提は「1 件 \$0.003 × 1 日 4 回 × picks」で、通過率は実績どおりとする）。"
echo "フォロー・アンフォロー系は **\$0**（DOM 操作のみ）なので、"
echo "\`competitor-follower-follow\` と \`hashtag-follow\` を増やしても **API 費用は増えない。**"
} > "$OUT" 2>&1

echo "経路ごとの返り率 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
