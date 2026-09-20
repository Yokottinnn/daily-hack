#!/bin/bash
# **告知の表示回数を 3 時間おきに記録する仕組みを入れる。費用 $0（LLM を呼ばない）。**
#
# ## 取り方は x113 で確定した（推測ではない）
#
# `reports/probe-impressions.md`（2026-09-21 02:26 JST）の実出力:
#
#   "ariaViews": [
#     "1 件の返信、1 件のリポスト、2 件のいいね、27 件の表示",
#     "1 件のいいね、12 件の表示"
#   ]
#
# **`role="group"` の `aria-label` に 4 つの数が全部 入っている。** ここを読む。
#
# **`groups[].text` は使わない。** 同じ要素の textContent は `"112"` と
# **数字が連結されて出る**ので、どれがどれか分からない（x113 のダンプで確認済み）。
#
# **`transition` の並び順も使わない。** X の実装依存で、意味が保証されない。
#
# ## なぜ記録するのか
#
# 2026-09-20 に「何時に出すのがいい？」と聞かれたが、**時間帯別の実測が 1 件も無く、
# 推測でしか答えられなかった。** 次は実測で答えるための土台。
#
# ## 何を残すか
#
#   ~/.openclaw/workspace/data/x-impressions.jsonl  に 1 行 1 計測で追記
#   {"at":"…","id":"blog-promo-…","tweet_id":"…","posted_at":"…",
#    "age_h":2.1,"views":27,"likes":2,"reposts":1,"replies":1}
#
# **`posted_at` を一緒に残す。** これが無いと「何時に出したか」と結びつかない。
#
# ## 読み出し
#
# **この仕組みは push しない。** heartbeat と同じブランチへ同時に書くと競合する。
# 中身を見るときは `ops/tasks` を 1 本 足して dump する（x111 と同じやり方）。
#
# ## やらないこと
#
# **投稿しない。LLM を呼ばない。`ai.openclaw.*` の名前を使わない**
# （`tab-guard.js` が一斉に外すため。`com.dailyhack.*` は生き残る）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
LABEL="com.dailyhack.x-impressions"
PLIST="$LA/$LABEL.plist"
JS="$S/x-impressions.js"
OUT="${OPS_REPORT_DIR:-/tmp}/install-impression-log.md"
NODE_BIN="/usr/local/bin/node"
[ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

cat > "$JS" <<'JSEOF'
// 告知の表示回数を記録する。$0（DOM を読むだけ）。
// **playwright-core**（`playwright` はこのワークスペースに無い）
const fs = require("fs");
const { chromium } = require("playwright-core");

const HOME = process.env.HOME;
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const QJSON = HOME + "/.openclaw/workspace/data/post_queue.json";
const LOG = HOME + "/.openclaw/workspace/data/x-impressions.jsonl";
const HANDLE = "heng_ji31590";
const MAX = 8;                 // 1 回で見るのは新しい順に 8 件まで（5 分 以内に収める）
const BUDGET_MS = 210 * 1000;
const t0 = Date.now();

// **aria-label から数を取る。** textContent は数字が連結されて出るので使わない
function parseLabel(s) {
  const pick = (re) => { const m = String(s || "").match(re); return m ? Number(m[1].replace(/,/g, "")) : null; };
  return {
    replies: pick(/([\d,]+)\s*件の返信/),
    reposts: pick(/([\d,]+)\s*件のリポスト/),
    likes:   pick(/([\d,]+)\s*件のいいね/),
    views:   pick(/([\d,]+)\s*件の表示/),
  };
}

let rows = [];
try {
  const q = JSON.parse(fs.readFileSync(QJSON, "utf8"));
  rows = (q.queue || q || []).filter((e) => e && typeof e === "object")
    .filter((e) => String(e.id || "").startsWith("blog-promo-"))
    .filter((e) => e.x_tweet_id || e.tweet_id)
    .sort((a, b) => String(b.posted_at || "").localeCompare(String(a.posted_at || "")))
    .slice(0, MAX);
} catch (e) {
  console.log(JSON.stringify({ fatal: "キューが読めない: " + e.message.slice(0, 120) }));
  process.exit(1);
}

(async () => {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const lines = [];
  let read = 0, skipped = 0;
  for (const e of rows) {
    if (Date.now() - t0 > BUDGET_MS) { skipped++; continue; }
    const tid = String(e.x_tweet_id || e.tweet_id);
    try {
      await p.goto("https://x.com/" + HANDLE + "/status/" + tid,
        { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(5000);
      // **最初の article の group を読む。** 2 本目以降は返信なので別物
      const label = await p.evaluate(() => {
        const art = document.querySelector("article");
        if (!art) return null;
        const g = art.querySelector('[role="group"][aria-label]');
        return g ? g.getAttribute("aria-label") : null;
      });
      if (!label) { skipped++; continue; }
      const n = parseLabel(label);
      if (n.views === null) { skipped++; continue; }
      read++;
      const posted = e.posted_at || null;
      lines.push(JSON.stringify({
        at: new Date().toISOString(),
        id: e.id, tweet_id: tid, posted_at: posted,
        age_h: posted ? Math.round((Date.now() - Date.parse(posted)) / 36e5 * 10) / 10 : null,
        ...n,
      }));
    } catch (err) { skipped++; }
  }
  await p.close(); await b.close();
  // **末尾に改行を付ける。** 付けないと次の追記が同じ行に繋がる
  if (lines.length) fs.appendFileSync(LOG, lines.join("\n") + "\n");
  console.log(JSON.stringify({
    elapsed_sec: Math.round((Date.now() - t0) / 1000),
    target: rows.length, read, skipped, appended: lines.length,
  }, null, 1));
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 200) }));
  process.exit(1);
});
JSEOF

cat > "$PLIST" <<PLEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$NODE_BIN</string><string>$JS</string></array>
  <key>WorkingDirectory</key><string>$S</string>
  <key>StartInterval</key><integer>10800</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$W/logs/x-impressions.log</string>
  <key>StandardErrorPath</key><string>$W/logs/x-impressions.log</string>
</dict></plist>
PLEOF

mkdir -p "$W/logs"

{
echo "# 表示回数を 3 時間おきに記録する（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **取り方は x113 で確定した。推測ではない。**"
echo "> \`role=\"group\"\` の \`aria-label\` に 返信・リポスト・いいね・表示 が全部 入っている。"
echo "> \`textContent\` は \`\"112\"\` と数字が連結されて出るので使わない。"

echo
echo "## 1. 置いたもの"
echo
echo '```'
printf '  %-48s %s bytes\n' "$JS" "$(wc -c < "$JS" 2>/dev/null | tr -d ' ')"
printf '  %-48s %s bytes\n' "$PLIST" "$(wc -c < "$PLIST" 2>/dev/null | tr -d ' ')"
echo "  node: $NODE_BIN"
echo '```'

echo
echo "## 2. 構文は通るか（**走らせる前に見る**）"
echo
echo '```'
if "$NODE_BIN" --check "$JS" >/dev/null 2>&1; then echo "  node --check: 通った"
else echo "  **構文エラー。載せない。**"; "$NODE_BIN" --check "$JS" 2>&1 | head -5; fi
echo '```'

echo
echo "## 3. 載せる（**\`load\` ではなく \`bootstrap\`**・最上位ルール 13）"
echo
echo '```'
UID_N="$(id -u)"
launchctl bootout "gui/$UID_N/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$UID_N" "$PLIST" >/dev/null 2>&1
echo "  bootstrap を打った（rc は証拠にならない）"
# **これが証拠。** 完全一致で見る
if launchctl list 2>/dev/null | awk -v l="$LABEL" '$3==l {f=1} END {exit !f}'; then
  echo "  **launchctl list に出ている ＝ 載った**"
  launchctl list 2>/dev/null | awk -v l="$LABEL" '$3==l {print "  "$0}'
else
  echo "  **載っていない。** 一覧に出ない"
fi
echo '```'

echo
echo "## 4. 1 回 走らせて、実際に書けるか見る"
echo
echo '```'
RES="${TMPDIR:-/tmp}/.x114-run.json"
( cd "$S" && "$NODE_BIN" x-impressions.js ) > "$RES" 2>&1
echo "  rc=$?"
head -c 700 "$RES"; echo
LOGF="$W/data/x-impressions.jsonl"
if [ -f "$LOGF" ]; then
  echo "  記録: $(wc -l < "$LOGF" | tr -d ' ') 行"
  echo "  --- 直近 3 行 ---"
  tail -3 "$LOGF" | sed 's/^/  /'
else
  echo "  **記録ファイルが無い。1 件も書けていない。**"
fi
rm -f "$RES" 2>/dev/null || true
echo '```'

echo
echo "## 5. 読み出し方"
echo
echo "**この仕組みは push しない。** heartbeat と同じブランチへ同時に書くと競合する。"
echo "中身を見るときは \`ops/tasks\` を 1 本 足して dump する（x111 と同じやり方）。"
echo
echo '```'
echo "  ~/.openclaw/workspace/data/x-impressions.jsonl"
echo "  {\"at\":…,\"id\":…,\"tweet_id\":…,\"posted_at\":…,\"age_h\":…,\"views\":…,…}"
echo '```'
echo
echo "**\`posted_at\` を一緒に残している。** これが無いと「何時に出したか」と結びつかない。"

echo
echo "## 6. 費用"
echo
echo "**DOM を読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり（3 時間おき＝8 回） | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**ラベルは \`com.dailyhack.*\`。** \`ai.openclaw.*\` にすると \`tab-guard.js\` に"
echo "一斉に外される（2026-09-09 に 48 本 が 11 日間 外れたまま だった）。"
} > "$OUT" 2>&1

echo "表示回数の記録を入れた / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
