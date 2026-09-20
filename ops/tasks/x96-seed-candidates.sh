#!/bin/bash
# **入れ替える種の候補を、実物から出す。測るだけ。費用 $0。**
#
# ## なぜ（x93〜x95 でここまで確定した）
#
#   一覧    `competitor-follower-follow.js:27` の `COMPETITORS`（7 種・直書き）
#   回し方  epoch 日 % 7（1 日 1 種）→ **どの種も等しく 1/7 の枠**
#   返り率  himawari56757 **26.0%** … ukk_hx **4.2%**（**6 倍 の開き**）
#
# 利用者の選択は「**数を保ったまま、悪い 3 つ を良い種に差し替える**」。
# 外すだけだと同じ種を 4 日ごとに触ることになり、**先頭 60 件 の scrape が
# 空振りしやすくなって量が落ちる**（`全 follower 既 follow か対象なし、skip` の経路）。
#
# ## 候補はもう Mac にある
#
# x94 で、7 種すべてが **`data/influencers.json`** に載っていると分かった。
# **まずそこに何件 入っていて、未使用が何件 あるかを見る。**
#
# ## 「良い種」の条件を、当て推量で決めない
#
# **`reply-followers.json` には `source` と `followers_at_follow` が両方ある。**
# 種ごとに「**どんな規模の人を連れてきたか**」を出せば、
# 26% と 4.2% の差が何で説明できるかが分かる。
# 2026-09-13 の帯別では **300-999 が 28.6%、5000-49999 が 6.7%** だった。
# **同じ説明が効くなら、候補は「その帯のフォロワーを多く持つアカウント」になる。**
#
# ## ハンドルを伏せない理由（**意図的な判断**）
#
# 出力は公開リポジトリに載るので、普段はハンドルを伏せている。
# **ここは伏せない。** 理由は 2 つ。
#
#   1. 対象は**公開アカウントの競合一覧**であり、追跡された個人ではない。
#      現行の 7 種はすでに `competitor-follower-follow.js` に直書きされ、
#      このリポジトリに commit 済み
#   2. **伏せると選べない。** どれに差し替えるかを決めるための材料そのもの
#
# **フォローした相手のハンドル（`reply-followers.json` のキー）は出さない。**
# 出すのは種の候補だけ。
#
# ## やらないこと
#
# **配列を書き換えない。フォローしない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/seed-candidates.md"
INF="$D/influencers.json"
RF="$D/reply-followers.json"

secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(xox[bp]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }

{
echo "# 入れ替える種の候補"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 方針は「**数を保ったまま、悪い 3 つ を良い種に差し替える**」。"
echo "> 外すだけだと同じ種を 4 日ごとに触ることになり、"
echo "> **先頭 60 件 の scrape が空振りして量が落ちる。**"
echo
echo "**測るだけ。配列を書き換えない。フォローしない。**"

# ═══════════ 1. 候補プール ═══════════
echo
echo "## 1. \`influencers.json\` に何が入っているか"
echo
echo '```'
if [ ! -f "$INF" ]; then
  echo "  **$INF が無い。** data/ の候補:"
  ls -1 "$D" 2>/dev/null | grep -i -E 'influencer|competitor|target' | head -8 | sed 's/^/    /'
else
  echo "  $(wc -c < "$INF" | tr -d ' ') bytes / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$INF" 2>/dev/null)"
  echo
  /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
catch (e) { console.log("  **読めない: " + e.message.slice(0,120) + "**"); process.exit(0); }
const IN_USE = new Set(["himawari56757","ukk_hx","POIKATSU_OTAKE","tokufree3","okamiler_pn","money_yossy","haiji_doctor"]);
// **構造を当て推量しない。** 何が入っているかを先に出す
if (Array.isArray(j)) {
  console.log("  最上位: 配列 " + j.length + " 件");
  console.log("  --- 先頭 3 件 の実物 ---");
  for (const x of j.slice(0, 3)) console.log("    " + JSON.stringify(x).slice(0, 190));
} else {
  console.log("  最上位: オブジェクト " + Object.keys(j).length + " キー");
  for (const [k, v] of Object.entries(j).slice(0, 14)) {
    const t = Array.isArray(v) ? ("配列 " + v.length + " 件")
      : (v && typeof v === "object" ? ("オブジェクト " + Object.keys(v).length + " キー")
      : JSON.stringify(v));
    console.log("    " + String(k).padEnd(24) + " " + String(t).slice(0, 120));
  }
}
// ハンドルらしき文字列を総ざらいして、使用中かどうかで分ける
const seen = new Map();
const walk = (v, path) => {
  if (typeof v === "string") {
    const m = v.match(/^@?([A-Za-z0-9_]{3,15})$/);
    if (m) seen.set(m[1], path);
  } else if (Array.isArray(v)) v.forEach((x, i) => walk(x, path));
  else if (v && typeof v === "object") {
    for (const [k, x] of Object.entries(v)) {
      const m = String(k).match(/^@?([A-Za-z0-9_]{3,15})$/);
      if (m && x && typeof x === "object") seen.set(m[1], path + "/" + "(キー)");
      walk(x, path + "/" + k);
    }
  }
};
walk(j, "");
const all = [...seen.keys()];
const unused = all.filter((h) => !IN_USE.has(h));
console.log("");
console.log("  ハンドルらしき文字列: " + all.length + " 件");
console.log("  うち **いま使っていないもの: " + unused.length + " 件**");
console.log("");
console.log("  --- 未使用の先頭 30 件 ---");
console.log("    " + unused.slice(0, 30).join("  "));
' "$INF" 2>&1 | secrets
fi
echo '```'
echo
echo "**ここに十分な数があれば、外から探さずに差し替えられる。**"

# ═══════════ 2. 種ごとに「どんな層」を連れてきたか ═══════════
echo
echo "## 2. 種ごとに、**どんな規模の人を連れてきたか**"
echo
echo '```'
if [ -f "$RF" ]; then
  /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { process.exit(0); }
const rows = Object.values(j).filter((v) => v && typeof v === "object");
const MATURE = 72 * 3600 * 1000, now = Date.now();
const isBack = (r) => r.follows_back === true
  || String(r.followback_status || "").toLowerCase() === "yes";
const EDGES = [[0,99],[100,299],[300,999],[1000,4999],[5000,49999],[50000,1e9]];
const band = (n) => { for (const [a,b] of EDGES) if (n >= a && n <= b) return a + "-" + (b >= 1e9 ? "up" : b); return "?"; };
const g = {};
for (const r of rows) {
  const s = String(r.source || "(無し)");
  const c = g[s] || (g[s] = { n: 0, withF: 0, sum: 0, bands: {}, mature: 0, back: 0 });
  c.n++;
  if (typeof r.followers_at_follow === "number") {
    c.withF++; c.sum += r.followers_at_follow;
    const b = band(r.followers_at_follow);
    c.bands[b] = (c.bands[b] || 0) + 1;
  }
  const t = Date.parse(r.followed_at || "");
  if (t && now - t >= MATURE) { c.mature++; if (isBack(r)) c.back++; }
}
const keys = Object.keys(g).sort((a, b) => g[b].n - g[a].n);
for (const s of keys) {
  const c = g[s];
  const rate = c.mature ? (c.back / c.mature * 100).toFixed(1) + "%" : "—";
  const avg = c.withF ? Math.round(c.sum / c.withF) : null;
  console.log("  " + s);
  console.log("    返り率 " + rate.padStart(6) + "（mature " + c.mature + "）"
    + "   規模が記録されている件数 " + c.withF + " / " + c.n
    + (avg !== null ? "   平均フォロワー " + avg : ""));
  const bs = Object.entries(c.bands).sort((a, b) => b[1] - a[1]).map(([k, n]) => k + "=" + n).join("  ");
  if (bs) console.log("    帯: " + bs);
  console.log("");
}
' "$RF" 2>&1 | secrets
else
  echo "  **$RF が無い。**"
fi
echo '```'
echo
echo "**2026-09-13 の帯別では 300-999 が 28.6%、5000-49999 が 6.7% だった。**"
echo "種ごとの帯の偏りが返り率の差と揃っているなら、**選ぶ基準はそこ**になる。"
echo "揃っていなければ、規模ではなく**中身（ジャンルの近さ）**が効いているということ。"

# ═══════════ 3. 外す 3 つ の実績（念のため再掲） ═══════════
echo
echo "## 3. 外す候補 3 つ の実績（**判断の根拠を同じ紙に残す**）"
echo
echo '```'
if [ -f "$RF" ]; then
  /usr/local/bin/node -e '
const fs = require("fs");
let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { process.exit(0); }
const rows = Object.values(j).filter((v) => v && typeof v === "object");
const MATURE = 72 * 3600 * 1000, now = Date.now();
const isBack = (r) => r.follows_back === true
  || String(r.followback_status || "").toLowerCase() === "yes";
const OUTL = ["ukk_hx", "money_yossy", "POIKATSU_OTAKE"];
const KEEP = ["himawari56757", "haiji_doctor", "okamiler_pn", "tokufree3"];
const calc = (list) => {
  let m = 0, b = 0;
  for (const r of rows) {
    const s = String(r.source || "");
    if (!list.some((h) => s === "competitor-follower:" + h)) continue;
    const t = Date.parse(r.followed_at || "");
    if (t && now - t >= MATURE) { m++; if (isBack(r)) b++; }
  }
  return { m, b, rate: m ? (b / m * 100).toFixed(1) : "—" };
};
const o = calc(OUTL), k = calc(KEEP);
console.log("    外す 3 つ : mature " + String(o.m).padStart(3) + " 件 → 返った " + String(o.b).padStart(2) + " 人   " + o.rate + "%");
console.log("    残す 4 つ : mature " + String(k.m).padStart(3) + " 件 → 返った " + String(k.b).padStart(2) + " 人   " + k.rate + "%");
console.log("");
console.log("    同じ " + o.m + " 件 を残す 4 つ 並みに回していれば、"
  + Math.round(o.m * (k.m ? k.b / k.m : 0)) + " 人 返っていた計算（実績 " + o.b + " 人）");
' "$RF" 2>&1
fi
echo '```'
echo
echo "**これは過去の振り返りであって、これから同じだけ増えるという意味ではない。**"
echo "前向きの見積もりは「競合経路 8.5 件/日 × 返り率の差」で出す。"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**JSON を読んで数えるだけ。LLM を呼ばない。フォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**種を差し替える場合も \$0。** \`competitor-follower-follow\` は DOM 操作のみで"
echo "LLM を呼ばないため、**フォロー数を変えても API 費用は動かない。**"
echo "返信ループの実測は 1 回 \$0.003 ／ 1 日 \$0.021 ／ 1 か月 約 \$0.63（別勘定）。"
} > "$OUT" 2>&1

echo "種の候補 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
