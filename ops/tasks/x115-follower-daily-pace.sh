#!/bin/bash
# **フォロワーの日次記録を全部 出す。測るだけ。費用 $0（ファイルを読むだけ）。**
#
# ## なぜ
#
# `heartbeat.json` の `followers` は **2 点しか無い。**
#
#   {"now":266,"prev":227,"prev_date":"2026-09-08","span_days":12,"target":300,...}
#
# これで出せるのは **12 日 平均 3.25 人/日** だけ。
# **その 12 日 には、48 本 のジョブが外れていた期間が丸ごと入っている**
# （2026-09-09 に外れ、2026-09-20 に気づいた）。
# **平均で見ると、止まっていた日と動いていた日が混ざって実態が消える。**
#
# 9/30 に 300 人 まで **残り 34 人 ・ 9 日**。必要なのは **3.78 人/日。**
# 平均 3.25 のままだと **295 人 で 5 人 足りない。**
# **直近が上がっているのか下がっているのかで、打つ手が変わる。**
#
# ## 探し方
#
# **当て推量でファイルを作らない**（見つからなければ候補を挙げて終わる）。
# `follower-snapshot` が書いているものを、名前で当たる。
#
# ## やらないこと
#
# **フォローしない。設定を変えない。LLM を呼ばない。読むだけ。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/follower-daily-pace.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

{
echo "# フォロワーの日次記録（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`heartbeat\` は **2 点しか持っていない**ので 12 日 平均しか出せない。"
echo "> **その 12 日 には、48 本 のジョブが外れていた期間が丸ごと入っている。**"
echo "> 平均で見ると、止まっていた日と動いていた日が混ざって実態が消える。"
echo
echo "9/30 に 300 人 まで **残り 34 人・9 日 ＝ 3.78 人/日 が必要**。"
echo "12 日 平均の 3.25 のままだと **295 人 で 5 人 足りない。**"

echo
echo "## 1. 記録がどこにあるか"
echo
echo '```'
FOUND=""
for f in "$D/follower-history.json" "$D/followers.json" "$D/follower-snapshot.json" \
         "$D/follower-counts.jsonl" "$D/follower-history.jsonl" "$L/follower-snapshot.out"; do
  if [ -f "$f" ]; then
    printf '  在る    %-46s %s bytes / %s 行\n' "$f" \
      "$(wc -c < "$f" | tr -d ' ')" "$(wc -l < "$f" | tr -d ' ')"
    FOUND="${FOUND:+$FOUND }$f"
  else
    printf '  無い    %s\n' "$f"
  fi
done
echo
echo "  --- data/ で follow を含むもの ---"
ls -1 "$D" 2>/dev/null | grep -i follow | sed 's/^/    /' || echo "    （無し）"
echo "  --- logs/ で follow を含むもの ---"
ls -1 "$L" 2>/dev/null | grep -i follow | sed 's/^/    /' || echo "    （無し）"
echo '```'

if [ -z "$FOUND" ]; then
  echo
  echo "- **既知の置き場に記録が無い。** 上の一覧から実体を選んで、次のタスクで読む。"
fi

echo
echo "## 2. 日次の推移"
echo
echo '```'
"$NODE_BIN" -e '
const fs = require("fs");
const files = process.argv.slice(1).filter((f) => fs.existsSync(f));
if (!files.length) { console.log("  読めるファイルが無い"); process.exit(0); }

// 「日付 → 人数」を取れるだけ取る。**形は決め打ちしない**
const byDate = new Map();
const eat = (date, n) => {
  if (!date || !Number.isFinite(n)) return;
  const d = String(date).slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(d)) return;
  // 同じ日が複数あれば**最後の値**を採る
  byDate.set(d, n);
};

for (const f of files) {
  const raw = fs.readFileSync(f, "utf8");
  // ① JSON まるごと
  try {
    const j = JSON.parse(raw);
    const rows = Array.isArray(j) ? j : (j.history || j.records || j.days || null);
    if (Array.isArray(rows)) {
      for (const r of rows) eat(r.date || r.day || r.at || r.t,
        Number(r.followers ?? r.count ?? r.n ?? r.value));
    } else if (j && typeof j === "object") {
      for (const [k, v] of Object.entries(j)) {
        if (typeof v === "number") eat(k, v);
        else if (v && typeof v === "object") eat(k, Number(v.followers ?? v.count ?? v.n));
      }
    }
    continue;
  } catch (e) { /* JSON でなければ次 */ }
  // ② 1 行 1 JSON
  let ok = 0;
  for (const line of raw.split(/\r?\n/)) {
    const t = line.trim(); if (!t.startsWith("{")) continue;
    try { const r = JSON.parse(t);
      eat(r.date || r.day || r.at || r.t, Number(r.followers ?? r.count ?? r.n));
      ok++;
    } catch (e) { /* 読めない行は飛ばす */ }
  }
  if (ok) continue;
  // ③ ログから「日付 … 数字」を拾う
  for (const line of raw.split(/\r?\n/)) {
    const d = line.match(/(\d{4}-\d{2}-\d{2})/);
    const n = line.match(/followers?[^0-9]{0,12}(\d{2,6})/i) || line.match(/(\d{2,6})\s*人/);
    if (d && n) eat(d[1], Number(n[1]));
  }
}

const days = [...byDate.entries()].sort((a, b) => a[0].localeCompare(b[0]));
if (!days.length) { console.log("  日付つきの人数を 1 件も取れなかった"); process.exit(0); }
console.log("  日付        人数    前日比");
console.log("  " + "-".repeat(34));
let prev = null;
for (const [d, n] of days) {
  const diff = prev === null ? "" : (n - prev >= 0 ? "+" : "") + (n - prev);
  console.log("  " + d + "  " + String(n).padStart(5) + "  " + String(diff).padStart(6));
  prev = n;
}
console.log("");
const last = days[days.length - 1];
const pick = (k) => {
  if (days.length <= k) return null;
  const a = days[days.length - 1 - k], b = last;
  const dd = (Date.parse(b[0]) - Date.parse(a[0])) / 86400000;
  return dd > 0 ? { span: dd, pace: (b[1] - a[1]) / dd } : null;
};
for (const k of [3, 5, 7, 12]) {
  const r = pick(k);
  if (r) console.log("  直近 " + String(r.span).padStart(2) + " 日: "
    + r.pace.toFixed(2) + " 人/日");
}
console.log("");
// **9/30 まで 9 日。残り 34 人 なら 3.78 人/日**
const need = 300 - last[1];
const left = Math.round((Date.parse("2026-09-30") - Date.parse(last[0])) / 86400000);
console.log("  最新 " + last[0] + " = " + last[1] + " 人");
if (left > 0) {
  console.log("  9/30 まで " + left + " 日 / 残り " + need + " 人 → **"
    + (need / left).toFixed(2) + " 人/日 が必要**");
  const r = pick(5) || pick(3);
  if (r) console.log("  直近ペースのまま: " + Math.round(last[1] + r.pace * left) + " 人");
}
' $FOUND 2>&1
echo '```'

echo
echo "## 3. 読み方"
echo
echo "- **平均ではなく直近を見る。** 12 日 平均にはジョブが止まっていた期間が入っている"
echo "- **前日比がマイナスの日**は、相互フォロー外し（\`mutual-prune\`）の影響かもしれない。"
echo "  増えた数だけでなく**減った数**も見る"
echo "- **記録が飛んでいる日**は、そこでジョブが止まっていた合図"

echo
echo "## 4. 費用"
echo
echo "**ファイルを読んで並べるだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "フォロワーの日次ペース / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
