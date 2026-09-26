#!/bin/bash
# **投稿ごとの表示回数を、投稿した時刻で束ねる。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# 「**いつ投稿するべきかな？**」に答えるため。
#
# `x156` で分かったこと:
#   - `post_queue.json` の時刻別件数は取れたが、**大半が自動返信（comment）**。
#     「何時に出したか」であって「何時が効いたか」ではない
#   - `x-impressions.log` は**実行ログ**（target/read/appended の件数）だけ
#   - **`post-metrics.json`（213KB・更新 2026-08-09）** が残っている
#
# **ここに投稿ごとの表示回数があれば、時刻別に出せる。** 無ければ無いと書く。
#
# ## 気をつけること
#
# - **更新が 2026-08-09 で止まっている。** 古いことを明記する（最上位ルール 11）
# - **自動返信（comment）と自分の投稿（thread など）を混ぜない。**
#   返信は相手の TL に出るので、時刻の効き方が違う
# - **件数が少ない帯の平均は当てにならない。** 母数を必ず併記する
#
# ## やらないこと
#
# **積まない。投稿しない。書き換えない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/metrics-by-hour.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

{
echo "# 表示回数を投稿時刻で束ねる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 積んでいない。投稿もしていない。"

echo
echo "## 1. \`post-metrics.json\` の形"
echo
M="$D/post-metrics.json"
if [ ! -f "$M" ]; then
  echo "- **無い。ここで止まる。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'
printf '  %s bytes   更新 %s\n' "$(wc -c < "$M" | tr -d ' ')" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$M" 2>/dev/null)"
echo '```'
echo
echo "**更新が止まっている日付をそのまま読むこと。** 新しい投稿は入っていない。"
echo
echo '```'
node -e '
  const fs = require("fs");
  let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
  catch (e) { console.log("  **読めない: " + e.message + "**"); process.exit(0); }
  const arr = Array.isArray(j) ? j : (j.items || j.posts || j.metrics || Object.values(j));
  console.log("  トップの型: " + (Array.isArray(j) ? "配列" : "オブジェクト（キー " + Object.keys(j).length + " 個）"));
  console.log("  行数: " + (Array.isArray(arr) ? arr.length : "-"));
  const s = Array.isArray(arr) ? arr.find((x) => x && typeof x === "object") : null;
  if (s) {
    console.log("  1 行のキー:");
    for (const k of Object.keys(s).slice(0, 30)) {
      let v = s[k];
      if (typeof v === "object") v = JSON.stringify(v).slice(0, 60);
      console.log("    " + String(k).padEnd(22) + " " + String(v).slice(0, 60));
    }
  }
' "$M" 2>&1 | clean
echo '```'

echo
echo "## 2. 時刻（JST）ごとの表示回数"
echo
echo "**自分の投稿だけ。** 自動返信（comment）は相手の TL に出るので分けて数える。"
echo
echo '```'
node -e '
  const fs = require("fs");
  const num = (v) => { const n = Number(String(v ?? "").replace(/[,\s]/g, "")); return Number.isFinite(n) ? n : null; };
  let mj, qj;
  try { mj = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch { console.log("  metrics が読めない"); process.exit(0); }
  try { qj = JSON.parse(fs.readFileSync(process.argv[2], "utf8")); } catch { qj = null; }

  const rows = Array.isArray(mj) ? mj : (mj.items || mj.posts || mj.metrics || Object.values(mj));
  if (!Array.isArray(rows)) { console.log("  metrics の配列が取れない"); process.exit(0); }

  // 表示回数らしいキーを探す
  const impKeys = ["impressions", "views", "view_count", "impression_count", "views_count"];
  const idKeys  = ["id", "tweet_id", "x_tweet_id", "rest_id"];
  const timeKeys = ["posted_at", "created_at", "time", "date"];

  // キューから id -> {posted_at, kind} を作る（metrics に時刻が無いとき用）
  const qmap = new Map();
  if (qj) {
    const qr = Array.isArray(qj) ? qj : (qj.items || qj.queue || qj.posts || []);
    for (const r of qr) {
      const id = r && (r.x_tweet_id || r.tweet_id);
      if (id && r.posted_at) qmap.set(String(id), { at: r.posted_at, kind: r.kind || "-" });
    }
  }

  const buckets = new Map();   // kindGroup -> hour -> [imp]
  let used = 0, noImp = 0, noTime = 0;
  for (const r of rows) {
    if (!r || typeof r !== "object") continue;
    let imp = null;
    for (const k of impKeys) if (r[k] != null) { imp = num(r[k]); break; }
    if (imp == null) { noImp++; continue; }
    let id = null;
    for (const k of idKeys) if (r[k] != null) { id = String(r[k]); break; }
    let at = null, kind = r.kind || null;
    for (const k of timeKeys) if (r[k] != null) { at = r[k]; break; }
    if (!at && id && qmap.has(id)) { at = qmap.get(id).at; kind = kind || qmap.get(id).kind; }
    if (!at) { noTime++; continue; }
    const t = new Date(at);
    if (isNaN(t)) { noTime++; continue; }
    const h = new Date(t.getTime() + 9 * 3600 * 1000).getUTCHours();
    const g = /comment|reply/i.test(String(kind || "")) ? "返信" : "自分の投稿";
    if (!buckets.has(g)) buckets.set(g, new Map());
    const bm = buckets.get(g);
    if (!bm.has(h)) bm.set(h, []);
    bm.get(h).push(imp);
    used++;
  }

  console.log("  使えた行 " + used + " 件 / 表示回数なし " + noImp + " 件 / 時刻なし " + noTime + " 件");
  if (!used) { console.log(""); console.log("  **表示回数と時刻が揃う行が 1 件も無い。時刻別のことは言えない。**"); process.exit(0); }
  for (const [g, bm] of buckets) {
    console.log("");
    console.log("  === " + g + " ===");
    console.log("  時刻   母数   中央値   平均");
    const hs = [...bm.keys()].sort((a, b) => a - b);
    for (const h of hs) {
      const v = bm.get(h).slice().sort((a, b) => a - b);
      const med = v[Math.floor(v.length / 2)];
      const avg = Math.round(v.reduce((s, x) => s + x, 0) / v.length);
      console.log("  " + String(h).padStart(2, "0") + ":00  " + String(v.length).padStart(4) +
                  "   " + String(med).padStart(6) + "  " + String(avg).padStart(6) +
                  (v.length < 5 ? "   ← 母数が少ない" : ""));
    }
  }
  console.log("");
  console.log("  **母数 5 未満の帯は当てにしない。**");
' "$M" "$D/post_queue.json" 2>&1 | clean
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 出方 | 何が言えるか |"
echo "| --- | --- |"
echo "| 「自分の投稿」の帯に**母数 5 以上が複数** | **その中で中央値が高い時刻を選ぶ。** 根拠になる |"
echo "| 母数が**どの帯も少ない** | **自分のデータでは決められない。** そう言う |"
echo "| 表示回数と時刻が**揃わない** | **時刻別のことは言えない。** 別の測り方が要る |"
echo
echo "**データの更新が 2026-08-09 で止まっていることを、必ず添えて報告する。**"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '使えた行' "$OUT" 2>/dev/null; then
  echo "表示回数を時刻で束ねた / $(basename "$OUT")"
else
  echo "**束ねられていない。レポートを確認すること** / $(basename "$OUT")"
fi
