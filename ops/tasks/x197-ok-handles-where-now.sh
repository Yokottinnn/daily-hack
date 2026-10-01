#!/bin/bash
# **「✅ が付いた相手」がいま どこに居るのかを、全部の記録に当てて決める。読むだけ。費用 $0。**
#
# ## `x196` で分かったこと と、私の集計の誤り
#
# **① ログは 1 行 を 2 回 書いている。**
# plist の `StandardOutPath` と `StandardErrorPath` が同じファイルを指しているため。
#
#   [2026-09-28T09:47:31.740Z] === end: 1/30 OK ===
#   === end: 1/30 OK ===                              ← 同じ行がもう一度
#
# **`x194` / `x196` のファネルはすべて 2 倍 で出ていた。** 真値は次のとおり。
#
#   competitor が通した数  **4〜11 件/日**（10 日 で **71 件**）  ← 142 ではない
#   試した数               **30 件/回 × 2 回 = 60 件/日**        ← 180 ではない
#   記録（全経路）          **19 件/10 日**
#   → 差は 10 倍 ではなく **約 3.7 倍**
#
# **② 「✅」の書き方が分かった。** `  @<ハンドル>: ✅` の 1 行だけ。
# `x196` は広いパターンで拾ったので **22 件 は多すぎる**（16 件 のはず）。ここで締める。
#
# ## 決めること
#
# **✅ が付いた相手は、いま どこに居るのか。**
#
# | 見つかった場所 | 意味 |
# | --- | --- |
# | **フォロー中の一覧に居る** | **押せている。記録が漏れているだけ** |
# | `follow-balance-state.json` に居る | **押せていた。こちらが外した**（自作自演） |
# | `follow-balance-notfollowing.json` に居る | **押せていなかった**（門が気づいた） |
# | `refollow-blacklist.json` に居る | 過去に手で外した相手 |
# | **どこにも居ない** | **押せていない。ここが本丸** |
#
# **「どこにも居ない」が多ければ、毎日 60 回 試して実らせていないことになる。**
#
# ## やらないこと
#
# **フォローしない。外さない。設定も触らない。ブラウザも触らない**（ファイル読みだけ・数秒）。
# **LLM も呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
CL="$L/competitor-follower-follow.log"
OUT="${OPS_REPORT_DIR:-/tmp}/ok-handles-where-now.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"
XJS="$W/.x197-where-$STAMP.js"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cat > "$XJS" <<'XEOF'
const fs = require("fs");
const [, , logPath, dataDir] = process.argv;

const rd = (p) => { try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch (e) { return null; } };
const setOf = (v) => {
  const s = new Set();
  const push = (h) => { if (typeof h === "string" && /^@?[A-Za-z0-9_]{1,15}$/.test(h)) s.add(h.replace(/^@/, "").toLowerCase()); };
  if (Array.isArray(v)) v.forEach(push);
  else if (v && typeof v === "object") Object.keys(v).forEach(push);
  return s;
};

let txt = "";
try { txt = fs.readFileSync(logPath, "utf8"); } catch (e) { console.log("  ログが読めない"); process.exit(0); }

// **「✅」の行はこの形だけ**（x196 の §1-B で実物を確認した）
//   `  @<ハンドル>: ✅`   先頭に `[時刻] ` が付く版と付かない版が 1 行ずつ出る
const okRe = /^\s*(?:\[[^\]]*\]\s*)?@([A-Za-z0-9_]{2,15}):\s*✅\s*$/;
const dayRe = /\d{4}-\d{2}-\d{2}/;

let lastDay = "";
const byDay = new Map();        // 日 → Set(handle)
let rawOkLines = 0;
for (const l of txt.split("\n")) {
  const d = (l.match(dayRe) || [])[0];
  if (d) lastDay = d;
  const m = l.match(okRe);
  if (!m) continue;
  rawOkLines++;
  const day = lastDay || "?";
  if (!byDay.has(day)) byDay.set(day, new Set());
  byDay.get(day).add(m[1].toLowerCase());
}

const days = [...byDay.keys()].sort();
console.log("  ✅ の行（重複込み）: " + rawOkLines + " 行");
console.log("  **1 行 が 2 回 書かれるので、実数はおよそ半分**");
console.log("");
console.log("  日ごとの ✅（ハンドルで重複を潰した数）:");
let total = 0;
for (const d of days.slice(-10)) { console.log("    " + d + "  " + String(byDay.get(d).size).padStart(3) + " 件"); total += byDay.get(d).size; }
console.log("    " + "直近 10 日 合計".padEnd(12) + String(total).padStart(3) + " 件");

// 直近 3 日 を突き合わせる
const recent = days.slice(-3);
const targets = new Set();
for (const d of recent) for (const h of byDay.get(d)) targets.add(h);

const lists = rd(dataDir + "/follow-balance-lists.json") || {};
const following = setOf(lists.following);
const followers = setOf(lists.followers);
const unfollowed = setOf(rd(dataDir + "/follow-balance-state.json"));
const notFollowing = setOf(rd(dataDir + "/follow-balance-notfollowing.json"));
const blacklist = setOf(rd(dataDir + "/refollow-blacklist.json"));
const cleanup = setOf(rd(dataDir + "/unfollow-cleanup-state.json"));

console.log("");
console.log("  === 突き合わせ（直近 3 日: " + recent.join(" ") + "）===");
console.log("  対象 " + targets.size + " 件");
console.log("");
console.log("  参照した記録の大きさ:");
console.log("    フォロー中の一覧            " + following.size + " 件");
console.log("    follow-balance-state        " + unfollowed.size + " 件（こちらが外した）");
console.log("    follow-balance-notfollowing " + notFollowing.size + " 件（押せていなかった）");
console.log("    refollow-blacklist          " + blacklist.size + " 件");
console.log("    unfollow-cleanup-state      " + cleanup.size + " 件");

const bucket = { inFollowing: 0, weUnfollowed: 0, wasNotFollowing: 0, blacklisted: 0, cleaned: 0, nowhere: 0 };
const nowhereList = [];
for (const h of targets) {
  if (following.has(h)) bucket.inFollowing++;
  else if (unfollowed.has(h)) bucket.weUnfollowed++;
  else if (notFollowing.has(h)) bucket.wasNotFollowing++;
  else if (cleaned(h)) bucket.cleaned++;
  else if (blacklist.has(h)) bucket.blacklisted++;
  else { bucket.nowhere++; nowhereList.push(h); }
}
function cleaned(h) { return cleanup.has(h); }

console.log("");
console.log("  いま フォロー中 に居る            " + String(bucket.inFollowing).padStart(3) + " 件  → 押せている（記録の漏れ）");
console.log("  こちらが外した記録に在る          " + String(bucket.weUnfollowed).padStart(3) + " 件  → 押せていた（自作自演）");
console.log("  「押せていなかった」の記録に在る  " + String(bucket.wasNotFollowing).padStart(3) + " 件  → 押せていない");
console.log("  cleanup が外した記録に在る        " + String(bucket.cleaned).padStart(3) + " 件  → 押せていた");
console.log("  refollow-blacklist に在る         " + String(bucket.blacklisted).padStart(3) + " 件");
console.log("  **どこにも居ない**                " + String(bucket.nowhere).padStart(3) + " 件  ← **ここが本丸**");

const accountedFor = bucket.inFollowing + bucket.weUnfollowed + bucket.cleaned;
const pct = targets.size ? Math.round((accountedFor / targets.size) * 100) : 0;
console.log("");
console.log("  「実際にフォローできていた」と言える割合: **" + pct + "%**（" + accountedFor + " / " + targets.size + "）");
console.log("");
if (pct >= 70) console.log("  → **B。押せている。`followed.json` の書き込みが漏れているだけ**");
else if (pct <= 30) console.log("  → **A。押せていない。毎日 60 回 が実っていない**");
else console.log("  → **混在している（" + pct + "%）。** 母数を増やして見直す");

if (nowhereList.length) {
  console.log("");
  console.log("  どこにも居ない相手（伏せて " + Math.min(8, nowhereList.length) + " 件 まで）:");
  for (const h of nowhereList.slice(0, 8)) console.log("    @" + h);
}
XEOF

{
echo "# ✅ が付いた相手は、いま どこに居るのか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **私の集計に誤りがあった。** ログは **1 行 を 2 回** 書いている"
echo "> （plist の \`StandardOutPath\` と \`StandardErrorPath\` が同じファイル）。"
echo "> **\`x194\` / \`x196\` のファネルはすべて 2 倍 だった。**"
echo "> 真値は competitor が **4〜11 件/日**、試したのは **60 件/日**。"
echo "> **読むだけ。フォローも外しもしない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"

echo
echo "## 0. 二重出力の裏取り（**plist を見る**）"
echo
echo '```'
P="$LA/ai.openclaw.competitor-follower-follow.plist"
if [ -f "$P" ]; then
  O="$(/usr/libexec/PlistBuddy -c "Print :StandardOutPath" "$P" 2>/dev/null)"
  E="$(/usr/libexec/PlistBuddy -c "Print :StandardErrorPath" "$P" 2>/dev/null)"
  printf '  StandardOutPath    %s\n' "${O:-（未設定）}"
  printf '  StandardErrorPath  %s\n' "${E:-（未設定）}"
  if [ -n "$O" ] && [ "$O" = "$E" ]; then
    echo "  → **同じファイル。二重に出る条件がそろっている**"
  else
    echo "  → 別のファイル。**二重出力の原因は別にある**（スクリプト側で 2 回 書いている）"
  fi
else
  echo "  plist が無い"
fi
echo '```'

echo
echo "## 1. ✅ を数え直して、全部の記録に当てる"
echo
echo '```'
if [ -f "$CL" ]; then
  node "$XJS" "$CL" "$D" 2>&1 | clean
else
  echo "  **ログが無い: $CL**"
fi
echo '```'
rm -f "$XJS"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 「フォローできていた」割合 | どれか | 次にやること |"
echo "| --- | --- | --- |"
echo "| **70% 以上** | **B. 記録の漏れ** | \`followed.json\` の書き込みを直す。**実害は小さい** |"
echo "| **30% 以下** | **A. 押せていない** | **毎日 60 回 が実っていない。** ここを直すのが最優先 |"
echo "| 30〜70% | 混在 | 母数を増やす（直近 3 日 → 7 日）|"
echo
echo "**「どこにも居ない」が多い場合、可能性は 2 つ。**"
echo "① ✅ を出した後に X 側で弾かれている（\`follow button click didn't change\` が 50 件 ある）"
echo "② 相手が こちらを ブロック／削除した"
echo
echo "**フォローしていない。外していない。設定も変えていない。**"
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$XJS"

if grep -aq 'どこに居るのか' "$OUT" 2>/dev/null; then
  echo "✅ の相手の行方を突き合わせた / $(basename "$OUT")"
else
  echo "**突き合わせできていない。レポートを確認すること** / $(basename "$OUT")"
fi
