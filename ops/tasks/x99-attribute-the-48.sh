#!/bin/bash
# **増えた 48 人 が「どこから来たか」を、スナップショットの差分で出す。測るだけ。費用 $0。**
#
# ## なぜこれができるのか
#
# `follower-snapshot` は 2026-09-09〜09-19 の 11 日間 止まっていたので、
# **日ごとの数は残っていない。** ログ上は 9/8 の 227 の次が 9/20 の 264 で、
# **+37 は 12 日ぶんの塊**にしか見えない。
#
# **だが `data/follower-snapshots/*.json` には「誰がフォロワーか」の実名リストが入っている。**
#
#   2026-09-08.json   227 人
#   2026-09-20.json   264 人
#
# **差分を取れば、増えた人・去った人が特定できる。**
# そのうえで `reply-followers.json`（こちらが先にフォローした人の記録）と突き合わせれば、
# **「どの経路が連れてきたか」「いつのフォローが効いたか」**が出る。
#
# ## これで初めて分かること
#
#   ① 増えたうち、**こちらが先にフォローした人**は何人か（＝フォロー施策の成果）
#   ② **こちらからは何もしていないのに来た人**は何人か（＝返信や投稿の露出の成果）
#   ③ ①の内訳（経路ごと・フォローした日ごと）
#   ④ 去った 11 人 は、こちらがフォローした人だったのか
#
# **②が多ければ、フォロー数を増やすより露出を増やすほうが効く。**
# 逆なら、いま進めている種の差し替えが正しい方向ということになる。
#
# ## ハンドルは出さない
#
# **人数と経路と日付だけを出す。** 対象は「こちらをフォローした個人」であり、
# 公開アカウントの競合一覧（x96〜x98）とは扱いが違う。
# **1 件も実名を出さない。**
#
# ## やらないこと
#
# **何も変えない。フォローしない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
SNAPD="$D/follower-snapshots"
RF="$D/reply-followers.json"
OUT="${OPS_REPORT_DIR:-/tmp}/attribute-48.md"
A="$SNAPD/2026-09-08.json"
B="$SNAPD/2026-09-20.json"

{
echo "# 増えた 48 人 はどこから来たか"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`follower-snapshot\` が 9/09〜9/19 の 11 日間 止まっていたため、**日ごとの数は無い。**"
echo "> だが **スナップショットには「誰がフォロワーか」の実名リストが入っている。**"
echo "> 差分を取れば、**増えた人が誰で、どの経路から来たか**が出せる。"
echo
echo "**人数・経路・日付だけを出す。実名は 1 件も出さない。**"

echo
echo "## 1. 突き合わせに使うファイル"
echo
echo '```'
for f in "$A" "$B" "$RF"; do
  if [ -f "$f" ]; then
    printf '    %-46s %s\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  else
    printf '    %-46s **無い**\n' "$(basename "$f")"
  fi
done
echo '```'

echo
echo "## 2. 差分と、その内訳"
echo
echo '```'
if [ ! -f "$A" ] || [ ! -f "$B" ]; then
  echo "  **スナップショットが揃っていないので差分が取れない。**"
  ls -1 "$SNAPD" 2>/dev/null | sort | tail -6 | sed 's/^/    在るもの: /'
else
  /usr/local/bin/node -e '
const fs = require("fs");
const load = (p) => {
  const j = JSON.parse(fs.readFileSync(p, "utf8"));
  const a = Array.isArray(j) ? j : (j.followers || j.list || j.following || []);
  return new Set(a.map((x) => String(typeof x === "string" ? x : (x && (x.username || x.handle || x.screen_name) || "")).replace(/^@/, "")).filter(Boolean));
};
let before, after;
try { before = load(process.argv[1]); after = load(process.argv[2]); }
catch (e) { console.log("  **スナップショットが読めない: " + e.message.slice(0,140) + "**"); process.exit(0); }

const gained = [...after].filter((h) => !before.has(h));
const lost = [...before].filter((h) => !after.has(h));
console.log("  9/08 " + before.size + " 人 → 9/20 " + after.size + " 人");
console.log("  **増えた " + gained.length + " 人 / 去った " + lost.length + " 人**（差し引き "
  + (gained.length - lost.length >= 0 ? "+" : "") + (gained.length - lost.length) + "）");

let rf = {};
try { rf = JSON.parse(fs.readFileSync(process.argv[3], "utf8")); } catch {}
// キーは大文字小文字がぶれることがあるので、小文字で引けるようにする
const byLower = {};
for (const [k, v] of Object.entries(rf)) if (v && typeof v === "object") byLower[String(k).replace(/^@/, "").toLowerCase()] = v;
const rec = (h) => byLower[h.toLowerCase()] || null;

const fromFollow = gained.filter((h) => rec(h));
const organic = gained.filter((h) => !rec(h));
console.log("");
console.log("  --- 増えた " + gained.length + " 人 の内訳 ---");
console.log("    **こちらが先にフォローした人**      " + String(fromFollow.length).padStart(3) + " 人"
  + "   (" + (gained.length ? Math.round(fromFollow.length / gained.length * 100) : 0) + "%)");
console.log("    **こちらは何もしていないのに来た人** " + String(organic.length).padStart(3) + " 人"
  + "   (" + (gained.length ? Math.round(organic.length / gained.length * 100) : 0) + "%)");

// 経路ごと
const bySrc = {};
for (const h of fromFollow) {
  const s = String(rec(h).source || "(記録なし)");
  bySrc[s] = (bySrc[s] || 0) + 1;
}
console.log("");
console.log("  --- こちらが先にフォローした " + fromFollow.length + " 人 の経路 ---");
for (const [s, n] of Object.entries(bySrc).sort((a, b) => b[1] - a[1])) {
  console.log("    " + String(n).padStart(3) + " 人  " + s);
}

// フォローした日ごと
const byDay = {};
for (const h of fromFollow) {
  const t = Date.parse(rec(h).followed_at || "");
  if (!t) continue;
  const d = new Date(t).toISOString().slice(0, 10);
  byDay[d] = (byDay[d] || 0) + 1;
}
console.log("");
console.log("  --- **いつフォローした人が返ってきたか** ---");
for (const d of Object.keys(byDay).sort()) {
  console.log("    " + d + "  " + String(byDay[d]).padStart(3) + " 人  " + "#".repeat(Math.min(byDay[d], 40)));
}

// 去った人
const lostFollowed = lost.filter((h) => rec(h));
console.log("");
console.log("  --- 去った " + lost.length + " 人 ---");
console.log("    こちらがフォローしていた人   " + String(lostFollowed.length).padStart(3) + " 人");
console.log("    それ以外                     " + String(lost.length - lostFollowed.length).padStart(3) + " 人");
const lostWhy = {};
for (const h of lostFollowed) {
  const r = rec(h);
  const k = r.unfollowed_at ? "こちらが先に外した" : "相手が外した";
  lostWhy[k] = (lostWhy[k] || 0) + 1;
}
for (const [k, n] of Object.entries(lostWhy)) console.log("      " + k + ": " + n + " 人");
' "$A" "$B" "$RF" 2>&1
fi
echo '```'
echo
echo "**「何もしていないのに来た人」が多ければ、フォロー数より露出が効いている。**"
echo "逆なら、いま進めている**種の差し替えが正しい方向**ということになる。"

echo
echo "## 3. この数字の限界"
echo
echo "- **9/09〜9/19 の日ごとの数は無い。** 「直近 数日」の傾向はここからは出せない"
echo "- 出せるのは**フォローした日**の分布であって、**返ってきた日**ではない"
echo "- \`follower-snapshot\` は 2026-09-20 に戻したので、**明日以降は日ごとに出る**"

echo
echo "## 4. 費用"
echo
echo "**JSON を 3 本 読んで突き合わせるだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループの実測は 1 回 \$0.003 ／ 1 日 \$0.021 ／ 1 か月 約 \$0.63（別勘定・変わらない）。"
} > "$OUT" 2>&1

echo "増えた 48 人 の出どころ / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
