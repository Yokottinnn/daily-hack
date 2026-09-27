#!/bin/bash
# **投稿が落ちたことに気づく番人を入れる。＋ 真因を追うためにコードを写す。費用 $0。**
#
# ## なぜ要るか
#
# 9/27、**PAY ID スレッドの [2/3] が 12:00 に落ちたのに、16:41 まで誰も気づかなかった。**
# 利用者が X を見て気づいた。**4 時間 半 のあいだ、壊れたスレッドが出たままだった。**
#
# `heartbeat.json` も `ops-watchdog.yml` も**この形の故障を見ていない。**
#
# ## 何で検知するか（**実物に残っていた痕跡だけを使う**）
#
# **キューの `thread_chain` の id では検知できない。** 今回 [1/3] は X 上に在ったのに
# キューには id が 1 本も入っていなかった。**だから id の有無は信用できない。**
#
#   **A** ログに `"ok":false` ＋ `step` が `thread-reply-*` / `thread-*`
#         → 12:00:30 に実際に出ていた
#   **B** `auto_publish:true` の行が `scheduled_at` を **30 分** 過ぎても
#         `posted` にならない → 15:44 でも `awaiting_approval` のままだった
#
# **B なら 12:30 に鳴っていた。** これが今回いちばん効く。
#
# ## やること
#
#   ① `scripts/thread-guard.js` を置く（**LLM を呼ばない**）
#   ② 30 分ごとの plist を置いて `bootstrap` し、**`launchctl print` で載ったか確かめる**
#   ③ **1 回 手で走らせて**、鳴るか・鳴りすぎないかを見る
#   ④ **publisher のエラー処理を写す**（`post-comment.js` の stderr が
#      ログに落ちていない。次のタスクで直すための材料）
#
# ## やらないこと
#
# **投稿しない。キューを触らない。既存のジョブを消さない。**
# `autoload-jobs.txt` への追加は**このタスクでは やらない**——plist が載ったことを
# 確かめてから足す（先に足すと「載っていない」の空振り警報が鳴る）。
#
# ## 費用（最上位ルール 2-B）
#
# **番人は LLM を呼ばない。** ファイルを読んで、異常があれば Slack に curl するだけ。
#
#   1 回あたり   **$0**
#   1 日あたり   **$0**（30 分ごと ＝ 48 回／日）
#   1 か月あたり **$0**
#
# Slack への通知も API クレジットではない（ボットトークンの投稿）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
LABEL="ai.openclaw.thread-guard"
TARGET="$S/thread-guard.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
# **拡張子は `.js` のまま保つ**（`x163` がこれで置けなかった）
TMPJS="$S/.thread-guard-install-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/thread-guard-install.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
# **トークンは絶対に出さない**（公開リポジトリに載る）
secret() { sed -E 's/(xox[abprs]-[A-Za-z0-9-]+)/<トークン伏せ>/g; s/(OPENCLAW_BOT_TOKEN=)[^ "]*/\1<伏せ>/g'; }
clean() { hide | secret; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

cat > "$TMPJS" <<'JSEOF'
// 投稿が落ちたことに気づく番人。
//
// **LLM を呼ばない。** ファイルを読んで、異常があれば Slack に出すだけ。
//
// 2026-09-27、PAY ID スレッドの [2/3] が 12:00 に落ちたのに 16:41 まで
// 誰も気づかなかった。利用者が X を見て気づいた。それを防ぐために置く。
//
//   A  ログに {"ok":false, step:"thread-..."} が出た
//   B  auto_publish の行が scheduled_at を過ぎても posted にならない
//
// **B が今回いちばん効く。** キューの thread_chain の id は、
// 実際に出ているのに空のことがあったので信用しない。
"use strict";

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const HOME = process.env.HOME;
const W = path.join(HOME, ".openclaw", "workspace");
const D = path.join(W, "data");
const L = path.join(W, "logs");
const STATE = path.join(D, "thread-guard-state.json");

const LATE_MIN   = Number(process.env.THREAD_GUARD_LATE_MIN   || "30");  // B の猶予
const RENOTIFY_H = Number(process.env.THREAD_GUARD_RENOTIFY_H || "6");   // 再通知の間隔
const LOG_TAIL   = Number(process.env.THREAD_GUARD_LOG_TAIL    || "400"); // A で見る行数
const DRY        = process.env.DRY_RUN === "1";
const CHANNEL    = process.env.THREAD_GUARD_CHANNEL || "C0B4CJHH797"; // #fun_reward-hack_blog

const now = Date.now();
const jst = (t) => new Date(t + 9 * 3600 * 1000).toISOString().replace("T", " ").slice(0, 19);
const say = (...a) => console.error("[thread-guard]", ...a);

// --- 状態（同じことを鳴らし続けない） --------------------------------------
let state = {};
try { state = JSON.parse(fs.readFileSync(STATE, "utf8")) || {}; } catch (e) { state = {}; }
const alreadyTold = (key) => {
  const t = state[key];
  return !!t && (now - t) < RENOTIFY_H * 3600 * 1000;
};
const remember = (key) => { state[key] = now; };

// --- Slack のトークンを読む（**出力しない**） -------------------------------
function botToken() {
  if (process.env.OPENCLAW_BOT_TOKEN) return process.env.OPENCLAW_BOT_TOKEN;
  for (const p of [path.join(HOME, "openclaw", "config", ".env"),
                   path.join(W, "config", ".env"),
                   path.join(W, ".env")]) {
    let txt;
    try { txt = fs.readFileSync(p, "utf8"); } catch (e) { continue; }
    const m = txt.match(/^\s*OPENCLAW_BOT_TOKEN\s*=\s*["']?([^"'\s]+)/m);
    if (m) return m[1];
  }
  return null;
}

function tell(text) {
  if (DRY) { say("DRY なので Slack へ出さない:", text.slice(0, 120)); return "dry"; }
  const tok = botToken();
  if (!tok) { say("**トークンが無いので Slack へ出せない**"); return "no-token"; }
  try {
    // **`curl` に引数でトークンを渡さない**（ps に出る）。stdin から流す
    const body = JSON.stringify({ channel: CHANNEL, text });
    const res = execFileSync("/usr/bin/curl", [
      "-sS", "-X", "POST", "https://slack.com/api/chat.postMessage",
      "-H", "Content-Type: application/json; charset=utf-8",
      "-H", "Authorization: Bearer " + tok,
      "--data-binary", "@-",
    ], { input: body, encoding: "utf8", timeout: 20000 });
    let ok = false;
    try { ok = !!JSON.parse(res).ok; } catch (e) { ok = false; }
    say("Slack:", ok ? "出た" : "**出ていない** " + String(res).slice(0, 120));
    return ok ? "sent" : "failed";
  } catch (e) {
    say("**Slack で例外**:", String((e && e.message) || e).slice(0, 120));
    return "error";
  }
}

// --- A: ログに ok:false の thread 系が出ていないか --------------------------
function signalA() {
  const hits = [];
  let files = [];
  try { files = fs.readdirSync(L).filter((f) => /\.log$/.test(f) && /publish|publisher/i.test(f)); }
  catch (e) { return hits; }
  for (const f of files) {
    const p = path.join(L, f);
    let lines;
    try { lines = fs.readFileSync(p, "utf8").split("\n"); } catch (e) { continue; }
    let mtime = 0;
    try { mtime = fs.statSync(p).mtimeMs; } catch (e) {}
    for (const line of lines.slice(-LOG_TAIL)) {
      const i = line.indexOf('{"ok":false');
      if (i < 0) continue;
      let o;
      try { o = JSON.parse(line.slice(i)); } catch (e) { o = null; }
      const step = o ? String(o.step || "") : "";
      if (!/thread/i.test(step)) continue;
      hits.push({ file: f, step, error: String((o && o.error) || "").slice(0, 160), mtime });
    }
  }
  return hits;
}

// --- B: 出るはずの時刻を過ぎても posted になっていない ----------------------
function signalB() {
  const late = [];
  let j;
  try { j = JSON.parse(fs.readFileSync(path.join(D, "post_queue.json"), "utf8")); }
  catch (e) { say("**post_queue.json が読めない**:", String(e.message).slice(0, 80)); return late; }
  const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
  if (!Array.isArray(rows)) return late;
  for (const r of rows) {
    if (!r || typeof r !== "object") continue;
    if (r.auto_publish !== true) continue;
    const st = String(r.status || "");
    if (/^(posted|published|done|cancelled|canceled|expired|failed_final)$/i.test(st)) continue;
    const at = new Date(r.scheduled_at || 0).getTime();
    if (!Number.isFinite(at) || at <= 0) continue;
    const lateMin = Math.floor((now - at) / 60000);
    if (lateMin < LATE_MIN) continue;
    late.push({ id: String(r.id || "?"), status: st, scheduled_at: r.scheduled_at, lateMin });
  }
  return late;
}

// --- 実行 ------------------------------------------------------------------
const A = signalA();
const B = signalB();
say("A（ログの ok:false / thread 系）:", A.length, "件");
say("B（出る時刻を過ぎても posted でない）:", B.length, "件");

const told = [];
for (const h of B) {
  const key = "B:" + h.id;
  if (alreadyTold(key)) { say("  B 既報:", h.id); continue; }
  const msg = [
    "🚨 *予約投稿が出ていない*",
    "• id: `" + h.id + "`",
    "• status: `" + h.status + "`（`posted` になっていない）",
    "• 出るはずだった時刻: " + h.scheduled_at + "（**" + h.lateMin + " 分 遅れ**）",
    "",
    "スレッドの 2 本目以降が落ちると、壊れたまま残る。**X を見て確かめること。**",
  ].join("\n");
  say("  B 通知:", h.id, h.lateMin + " 分 遅れ");
  const r = tell(msg);
  if (r === "sent" || r === "dry") { remember(key); told.push("B:" + h.id); }
}
for (const h of A) {
  const key = "A:" + h.file + ":" + h.step;
  if (alreadyTold(key)) { say("  A 既報:", h.step); continue; }
  const msg = [
    "🚨 *スレッドの投稿が途中で落ちた*",
    "• ログ: `" + h.file + "`",
    "• step: `" + h.step + "`",
    "• error: ```" + h.error.replace(/`/g, "'") + "```",
    "",
    "**1 本目だけ出て続きが無い状態になりうる。X を見て確かめること。**",
  ].join("\n");
  say("  A 通知:", h.step);
  const r = tell(msg);
  if (r === "sent" || r === "dry") { remember(key); told.push("A:" + h.step); }
}

try {
  fs.writeFileSync(STATE, JSON.stringify(state, null, 2));
  // **書いた JSON を自分で読み直して確かめる**（最上位ルール 13）
  JSON.parse(fs.readFileSync(STATE, "utf8"));
} catch (e) {
  say("**状態ファイルを書けない**:", String(e.message).slice(0, 100));
}

console.log(JSON.stringify({
  ok: true, at: jst(now), dry: DRY,
  a_count: A.length, b_count: B.length, notified: told,
}));
JSEOF

{
echo "# 落ちたことに気づく番人を入れる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。キューも触らない。** 番人は LLM を呼ばない（\$0／回・\$0／日・\$0／月）。"

echo
echo "## 1. 置く前の確認"
echo
echo '```'
printf '  既に在るか: %s\n' "$( [ -f "$TARGET" ] && echo 'あり（上書き。バックアップを取る）' || echo '無い（新規）' )"
printf '  書いたもの: %s bytes / %s 行\n' "$(wc -c < "$TMPJS" | tr -d ' ')" "$(wc -l < "$TMPJS" | tr -d ' ')"
printf '  一時ファイル名: %s\n' "$(basename "$TMPJS")"
echo '```'
echo
echo "**\`node --check\` を、置く名前と同じ拡張子で通す**（\`x163\` の教訓）。"
echo
echo '```'
CHK="$(node --check "$TMPJS" 2>&1)"; CRC=$?
printf '  rc=%s\n' "$CRC"
[ -n "$CHK" ] && printf '%s\n' "$CHK" | cut -c1-200 | sed 's/^/  /'
echo '```'
if [ "$CRC" -ne 0 ]; then
  echo
  echo "- **構文が通らない。置かずに終わる。**"
  rm -f "$TMPJS"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
[ -f "$TARGET" ] && cp -p "$TARGET" "$TARGET.bak-$STAMP"
mv "$TMPJS" "$TARGET"
echo '```'
printf '  置いた: %s（%s 行）\n' "$(basename "$TARGET")" "$(wc -l < "$TARGET" | tr -d ' ')"
echo '```'

echo
echo "## 2. まず DRY で 1 回（**鳴るか・鳴りすぎないか**）"
echo
echo "**Slack へは出さない。** 何件 引っかかるかだけ見る。"
echo
echo '```'
DRY_RUN=1 node "$TARGET" 2>&1 | tail -30 | cut -c1-220 | clean | sed 's/^/  /'
echo '```'

echo
echo "## 3. 本番で 1 回（**実際に Slack へ出す**）"
echo
echo "**いま壊れているものが在れば、ここで鳴る。** 無ければ静かに終わる。"
echo
echo '```'
node "$TARGET" 2>&1 | tail -30 | cut -c1-220 | clean | sed 's/^/  /'
echo '```'

echo
echo "## 4. 30 分ごとの plist を置いて載せる"
echo
cat > "$LA/$LABEL.plist" <<PLEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>$TARGET</string>
  </array>
  <key>WorkingDirectory</key><string>$W</string>
  <key>StartInterval</key><integer>1800</integer>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$L/thread-guard.log</string>
  <key>StandardErrorPath</key><string>$L/thread-guard.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
</dict></plist>
PLEOF
echo '```'
# **`load` ではなく `bootstrap`**（最上位ルール 13）
launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
BS="$(launchctl bootstrap "gui/$UID_N" "$LA/$LABEL.plist" 2>&1)"; BRC=$?
printf '  bootstrap rc=%s %s\n' "$BRC" "$(printf '%s' "$BS" | cut -c1-120)"
echo "  （**2 回目が rc=5 なら「もう載っている」の出方**。消えた証拠ではない）"
echo
echo "  --- 載ったかの証拠（\`list | grep\` では足りない）---"
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
    | grep -E '^[[:space:]]+(state|runs|path|program|last exit code) ' | sed 's/^/    /'
  echo "    → **載っている**"
else
  echo "    → **載っていない**"
fi
echo '```'

echo
echo "## 5. \`post-comment.js\` の stderr が落ちていない箇所（**次に直す材料**）"
echo
echo "12:00 の失敗は \`Command failed: node scripts/post-comment.js \"<base64>\"\` だけで、"
echo "**本当のエラーが記録されていない。** どこで捨てているかを写す。"
echo
echo '```javascript'
HIT=""
for f in "$S"/*.js "$S"/*.sh; do
  [ -f "$f" ] || continue
  c="$(cnt 'post-comment.js' "$f")"
  [ "$c" = "0" ] && continue
  HIT="yes"
  printf '  ===== %s（%s 行・post-comment.js が %s 箇所）=====\n' "$(basename "$f")" "$(wc -l < "$f" | tr -d ' ')" "$c"
  grep -n -B6 -A14 'post-comment\.js' "$f" 2>/dev/null | head -60 | cut -c1-200 | clean | sed 's/^/    /'
  echo
done
[ -z "$HIT" ] && echo "  **post-comment.js を呼んでいる箇所が見つからない**"
echo '```'
echo
echo '```javascript'
echo "  --- execSync / execFileSync の catch で stderr を捨てていないか ---"
grep -n -A6 -E 'catch[[:space:]]*\((e|err|error)\)' "$S"/run-publish.sh "$S"/auto-x-publisher.js 2>/dev/null \
  | grep -E 'message|stderr|stdout|error' | head -25 | cut -c1-200 | clean | sed 's/^/    /' \
  || echo "    （該当ファイルが無い）"
echo '```'

echo
echo "---"
echo
echo "## 次の一手"
echo
echo "| §4 の出方 | 次 |"
echo "| --- | --- |"
echo "| **載っている** | \`ops/data/autoload-jobs.txt\` に足す（tab-guard に外されても戻る） |"
echo "| 載っていない | \`bootstrap\` の出力を読む。**足す前に直す**（空振り警報が鳴る） |"
echo
echo "| §2・§3 の出方 | 意味 |"
echo "| --- | --- |"
echo "| \`b_count\` が 1 以上 | **出るはずの投稿が止まっている。** いま鳴ったのは正しい |"
echo "| どちらも 0 | いま壊れているものは無い。**静かなのが正常** |"
echo "| \`b_count\` が 10 以上 | **鳴りすぎ。** 期限切れの扱いを足す（TTL で失効した行を除く） |"
echo
echo "**番人の費用: \$0／回・\$0／日（30 分ごと＝48 回）・\$0／月。** LLM を呼ばない。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '30 分ごとの plist' "$OUT" 2>/dev/null; then
  echo "番人を入れた / $(basename "$OUT")"
else
  echo "**入れられていない。レポートを確認すること** / $(basename "$OUT")"
fi
