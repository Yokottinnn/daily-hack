#!/bin/bash
# **①番人の鳴りすぎを直す ②`run-publish.sh` が捨てている stdout を残す。費用 $0。**
#
# ## ① 番人が 14 件 鳴った（`x170` の DRY で判明）
#
#   b_count: 14  ← うち 13 件は **2026-05 / 06 の放置行**（最大 99 日 遅れ）
#
# **上限が無かったのが原因。** 48 時間 を超えたものは「落ちた」ではなく「放置」なので、
# **数えるが鳴らさない。** あわせて 1 回で鳴らす上限を 3 件にする。
#
# ### さらに悪い穴が 1 つ在った
#
# **DRY が状態ファイルを書いていた。** `x170` では DRY の 14 件が「既報」として記録され、
# **直後の本番実行が全部 黙った**（`notified: []`）。今回 Slack が埋まらなかったのは
# 偶然そのおかげで、**裏を返せば DRY を 1 回 走らせるだけで本番の警報が 6 時間 止まる。**
# さらに DRY は `{}` で**上書き**するので、本番の抑止を消して鳴り直させることもできた。
#
# **DRY は状態ファイルに一切 触らないようにする。**
#
# ## ② `run-publish.sh` は `e.stdout` を捨てている（**真因が見えない理由**）
#
#   const out = execSync(cmd, { encoding: 'utf8' });          ← post-comment.js の JSON は stdout
#   } catch (e) {
#     console.log(JSON.stringify({ ..., error: e.message, ... })); return;   ← **e.stdout を捨てる**
#
# `execSync` の `e.message` は `Command failed: <コマンド>` だけ。
# **`post-comment.js` が出した判定（`ok:false` と `step`）は `e.stdout` に入っている。**
#
# **だから「ログを grep して text-mismatch が 0 件」は、働いていない証拠にならない。**
# stdout はログに現れないので、**構造上 見えるはずがなかった。**
# `x170` のレポートでそう書いたのは誤りで、ここで塞ぐ。
#
# ## やらないこと
#
# **投稿しない。キューを触らない。放置行を消さない**（消すのは利用者が決めること）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
UID_N="$(id -u)"
LABEL="ai.openclaw.thread-guard"
TARGET="$S/thread-guard.js"
RP="$S/run-publish.sh"
STAMP="$(date '+%Y%m%d-%H%M%S')"
# **拡張子は保つ**（`x163` の教訓）
TMPJS="$S/.thread-guard-fix-$STAMP.js"
PATCHER="$S/.rp-patch-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/thread-guard-fix.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
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

const LATE_MIN   = Number(process.env.THREAD_GUARD_LATE_MIN   || "30");   // B の猶予
// **上限が無いと 99 日 前の放置行まで鳴る**（2026-09-27 に 14 件 鳴った）。
// 48 時間 を超えたものは「落ちた」ではなく「放置」なので、数えるが鳴らさない
const STALE_MIN  = Number(process.env.THREAD_GUARD_STALE_MIN  || "2880");
// **1 回で鳴らす上限。** 全体が壊れたときに Slack を埋めない
const MAX_ALERTS = Number(process.env.THREAD_GUARD_MAX_ALERTS || "3");
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
// **DRY は状態を書かない。** 書くと DRY を 1 回 走らせただけで
// 本番の警報が RENOTIFY_H のあいだ黙る（2026-09-27 に実際にそうなった）
const remember = (key) => { if (!DRY) state[key] = now; };

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
const stale = [];
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
    const row = { id: String(r.id || "?"), status: st, scheduled_at: r.scheduled_at, lateMin };
    // **放置は鳴らさない。** 数えるだけ（消すのは利用者が決めること）
    if (lateMin > STALE_MIN) { stale.push(row); continue; }
    late.push(row);
  }
  return late;
}

// --- 実行 ------------------------------------------------------------------
const A = signalA();
const B = signalB();
say("A（ログの ok:false / thread 系）:", A.length, "件");
say("B（出る時刻を過ぎても posted でない）:", B.length, "件");
say("放置（" + STALE_MIN + " 分 超。鳴らさない）:", stale.length, "件");
for (const h of stale.slice(0, 5)) say("  放置:", h.id, Math.floor(h.lateMin / 1440) + " 日 遅れ");

const told = [];
let sent = 0;
const capped = () => {
  if (sent < MAX_ALERTS) return false;
  say("  **上限 " + MAX_ALERTS + " 件に達した。残りは鳴らさない**（次の周回で出る）");
  return true;
};
for (const h of B) {
  if (capped()) break;
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
  if (r === "sent" || r === "dry") { remember(key); told.push("B:" + h.id); sent++; }
}
for (const h of A) {
  if (capped()) break;
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
  if (r === "sent" || r === "dry") { remember(key); told.push("A:" + h.step); sent++; }
}

// **DRY は状態ファイルに一切 触らない。** `{}` で上書きすると
// 本番の抑止が消え、同じ警報が鳴り直す
if (DRY) say("DRY なので状態ファイルは書かない");
try {
  if (DRY) throw { skip: true };
  fs.writeFileSync(STATE, JSON.stringify(state, null, 2));
  // **書いた JSON を自分で読み直して確かめる**（最上位ルール 13）
  JSON.parse(fs.readFileSync(STATE, "utf8"));
} catch (e) {
  if (!(e && e.skip)) say("**状態ファイルを書けない**:", String((e && e.message) || e).slice(0, 100));
}

console.log(JSON.stringify({
  ok: true, at: jst(now), dry: DRY,
  a_count: A.length, b_count: B.length, stale_count: stale.length, notified: told,
}));
JSEOF

# --- `run-publish.sh` を直す道具（**拡張子は .js のまま**） -------------------
cat > "$PATCHER" <<'PATCHEOF'
// run-publish.sh の 2 箇所で捨てている e.stdout / e.stderr を残す。
// **置換は literal。** 正規表現にしないのは、シェルのヒアドキュメント内の
// エスケープ（\` や \${}）を壊さないため。
"use strict";
const fs = require("fs");
const file = process.argv[2];
let s = fs.readFileSync(file, "utf8");
const before = s;

const ADD = "child_stdout: String(e.stdout || '').slice(-700), child_stderr: String(e.stderr || '').slice(-700), ";

const pairs = [
  ["{ ok: false, step: 'thread-reply-' + i + '-exec', error: e.message, thread_results: results }",
   "{ ok: false, step: 'thread-reply-' + i + '-exec', error: e.message, " + ADD + "thread_results: results }"],
  ["{ ok: false, step: 'thread-main-exec', error: e.message, thread_results: results }",
   "{ ok: false, step: 'thread-main-exec', error: e.message, " + ADD + "thread_results: results }"],
];

const report = [];
for (const [from, to] of pairs) {
  const n = s.split(from).length - 1;
  if (n === 0) { report.push({ from: from.slice(0, 56), found: 0, note: "見つからない" }); continue; }
  if (s.indexOf(to) >= 0) { report.push({ from: from.slice(0, 56), found: n, note: "すでに直っている" }); continue; }
  s = s.split(from).join(to);
  report.push({ from: from.slice(0, 56), found: n, note: "直した" });
}

// **`$` とバックティックと二重引用符を入れていないことを自分で確かめる。**
// ヒアドキュメント内なので、入れるとシェルが壊れる
const bad = ADD.match(/[$`"\\]/);
if (bad) { console.log(JSON.stringify({ ok: false, error: "足す文に危ない文字が在る: " + bad[0] })); process.exit(1); }

const changed = s !== before;
if (changed) fs.writeFileSync(file, s);
console.log(JSON.stringify({ ok: true, changed, report }, null, 2));
PATCHEOF

{
echo "# 番人の鳴りすぎと、捨てられていた stdout を直す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。キューも放置行も触らない。** LLM を呼ばない（\$0／回・\$0／日・\$0／月）。"

echo
echo "## 1. 12:00 の失敗ログを、切らずに出す"
echo
echo "**\`x165\` は 300 字、\`x170\` は 400 字 で切っていた。** 全部 出す。"
echo
echo '```'
F="$L/publish-payid-oneshot.log"
if [ -f "$F" ]; then
  awk '/thread-reply-1-exec/{print; exit}' "$F" 2>/dev/null | clean | fold -w 180 | sed 's/^/  /'
  echo
  echo "  --- その前 20 行（どこまで進んだか）---"
  grep -n -B20 'thread-reply-1-exec' "$F" 2>/dev/null | head -21 | cut -c1-190 | clean | sed 's/^/  /'
else
  echo "  **ログが無い**"
fi
echo '```'
echo
echo "**\`child_stdout\` が無いのが今の姿。** §4 で足す。"

echo
echo "## 2. 番人を直したものに差し替える"
echo
echo '```'
printf '  書いたもの: %s bytes / %s 行\n' "$(wc -c < "$TMPJS" | tr -d ' ')" "$(wc -l < "$TMPJS" | tr -d ' ')"
CHK="$(node --check "$TMPJS" 2>&1)"; CRC=$?
printf '  node --check rc=%s（打つ名前: %s）\n' "$CRC" "$(basename "$TMPJS")"
[ -n "$CHK" ] && printf '%s\n' "$CHK" | cut -c1-200 | sed 's/^/  /'
echo '```'
if [ "$CRC" -ne 0 ]; then
  echo
  echo "- **構文が通らない。差し替えずに終わる。**"
  rm -f "$TMPJS" "$PATCHER"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
[ -f "$TARGET" ] && cp -p "$TARGET" "$TARGET.bak-$STAMP"
mv "$TMPJS" "$TARGET"
echo '```'
printf '  差し替えた: %s（%s 行）\n' "$(basename "$TARGET")" "$(wc -l < "$TARGET" | tr -d ' ')"
printf '  上限が入ったか: STALE_MIN %s 箇所 / MAX_ALERTS %s 箇所\n' "$(cnt 'STALE_MIN' "$TARGET")" "$(cnt 'MAX_ALERTS' "$TARGET")"
echo '```'

echo
echo "## 3. 汚れた状態ファイルを捨てる"
echo
echo "**\`x170\` の DRY が 14 件を「既報」にした。** 消さないと本番が黙り続ける。"
echo
echo '```'
if [ -f "$D/thread-guard-state.json" ]; then
  printf '  在った: %s bytes / キー %s 件\n' "$(wc -c < "$D/thread-guard-state.json" | tr -d ' ')" \
    "$(node -e 'try{console.log(Object.keys(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))).length)}catch(e){console.log("読めない")}' "$D/thread-guard-state.json")"
  mv "$D/thread-guard-state.json" "$D/thread-guard-state.json.bak-$STAMP"
  echo "  → 退避した（消さずにリネーム）"
else
  echo "  無い（消すものが無い）"
fi
echo '```'

echo
echo "## 4. \`run-publish.sh\` の 2 箇所を直す"
echo
echo '```json'
if [ ! -f "$RP" ]; then
  echo "  **run-publish.sh が無い**"
else
  printf '  直す前: %s 行 / e.message が %s 箇所 / child_stdout が %s 箇所\n' \
    "$(wc -l < "$RP" | tr -d ' ')" "$(cnt 'error: e.message' "$RP")" "$(cnt 'child_stdout' "$RP")"
  cp -p "$RP" "$RP.bak-$STAMP"
  node "$PATCHER" "$RP" 2>&1 | cut -c1-200 | clean | sed 's/^/  /'
  echo
  printf '  直した後: %s 行 / child_stdout が %s 箇所\n' \
    "$(wc -l < "$RP" | tr -d ' ')" "$(cnt 'child_stdout' "$RP")"
  echo
  echo "  --- シェルとして壊れていないか ---"
  if bash -n "$RP" 2>&1 | head -5 | sed 's/^/    /'; then
    echo "    bash -n OK"
  else
    echo "    **bash -n が落ちた。戻す。**"
    cp -p "$RP.bak-$STAMP" "$RP"
    echo "    戻した"
  fi
fi
echo '```'

echo
echo "## 5. 直した番人を 1 回 走らせる（**DRY → 本番**）"
echo
echo "**DRY は状態ファイルに触らない。** 触っていないことも確かめる。"
echo
echo '```'
echo "  --- DRY ---"
DRY_RUN=1 node "$TARGET" 2>&1 | tail -20 | cut -c1-220 | clean | sed 's/^/    /'
echo
printf '  DRY の後に状態ファイルが在るか: %s\n' "$( [ -f "$D/thread-guard-state.json" ] && echo '**在る（誤り）**' || echo '無い（正しい）' )"
echo
echo "  --- 本番（実際に Slack へ出す。上限 3 件）---"
node "$TARGET" 2>&1 | tail -20 | cut -c1-220 | clean | sed 's/^/    /'
echo '```'

echo
echo "## 6. ジョブがまだ載っているか"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
    | grep -E '^[[:space:]]+(state|runs|last exit code) ' | sed 's/^/    /'
  echo "    → **載っている**"
else
  echo "    → **載っていない**"
fi
echo '```'

rm -f "$PATCHER"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §5 の出方 | 意味 |"
echo "| --- | --- |"
echo "| \`b_count\` が 1〜3 ／ \`stale_count\` が 13 前後 | **狙いどおり。** 放置は数えるだけ |"
echo "| DRY の後に状態ファイルが在る | **直っていない。** もう一度 直す |"
echo "| 本番で \`notified\` に 1 件 以上 | **Slack に出た。** 実物を見て文面を確かめる |"
echo
echo "| §4 の \`child_stdout\` | 意味 |"
echo "| --- | --- |"
echo "| 2 箇所 | **直った。** 次に同じ形で落ちたら真因がログに出る |"
echo "| 0 箇所 ／ \`見つからない\` | **当たらなかった。** §1 の実物を見てアンカーを作り直す |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'run-publish.sh` の 2 箇所' "$OUT" 2>/dev/null; then
  echo "番人の上限と stdout の捨て漏れを直した / $(basename "$OUT")"
else
  echo "**直せていない。レポートを確認すること** / $(basename "$OUT")"
fi
