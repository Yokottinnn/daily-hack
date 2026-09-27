#!/bin/bash
# **22:00 の発火の結果を確定させる。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# 19:00 は**正常に動いて 0 件**だった（候補 6 → picked 2 → 2 件 とも生成側が skip）。
# **故障ではない。** だが「出ていない」状態が続くと、意味がない。
#
# **22:00 が同じなら 2 回 連続。** そこを見る。
#
# ## 待ち方（同じ間違いを 3 回 しない）
#
# `x173` は `runs` の変化で抜け（**起動を見た**）、`x174` は待たずに読んだ
# （**picked の 2 秒後を見た**）。**`pending` が捌けるまで待ってから読む**（`x175` の作り）。
#
# ## 既にある警報との関係（**新しく足す前に確かめた**）
#
# `ops-heartbeat.sh` は **`last_reply` が 8 時間 出ていなければ Slack に 🚨** を出す。
# 仕組みは在る。**ただし閾値が発火間隔と噛み合っていない。**
#
#   発火は 12:00 / 16:00 / 19:00 / 22:00
#   22:00 の次は翌 12:00 ＝ **14 時間 空く**
#   → **22:00 が skip で終わると、毎晩 8 時間 を超えて鳴る**（誤報）
#   → 逆に日中 2 回 連続で skip しても 8 時間 未満なら鳴らない（見逃し）
#
# **閾値を触るかは利用者が決める。** このタスクでは触らない。
#
# ## やらないこと
#
# **撃たない。設定を変えない。閾値も触らない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
L="$W/logs"
Q="$W/data/post_queue.json"
UID_N="$(id -u)"
LABEL="ai.openclaw.comment-warmup"
OUT="${OPS_REPORT_DIR:-/tmp}/comment-2200.md"
ME="heng_ji31590"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide | sed -E "s#@<伏せ>/status#@$ME/status#g"; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

pending_n() {
  node -e '
    const fs = require("fs");
    // **`node -e` のトップレベルで `return` は使えない**（Illegal return statement）
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { process.stdout.write("-1"); process.exit(0); }
    const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
    if (!Array.isArray(rows)) { process.stdout.write("-1"); process.exit(0); }
    const since = Date.now() - 120 * 60 * 1000;
    let n = 0;
    for (const r of rows) {
      if (!r || !/comment|reply/i.test(String(r.kind || ""))) continue;
      const ts = [r.posted_at, r.created_at, r.enqueued_at, r.scheduled_at]
        .map((x) => new Date(x || 0).getTime()).filter((t) => Number.isFinite(t) && t > 0);
      const t = ts.length ? Math.max(...ts) : 0;
      if (t < since) continue;
      if (/^(pending|queued|publishing|awaiting_publish)$/i.test(String(r.status || ""))) n++;
    }
    process.stdout.write(String(n));
  ' "$Q" 2>/dev/null
}

{
echo "# 22:00 の発火の結果（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 撃っていない。閾値も触っていない。"

echo
echo "## 1. 落ち着くまで待つ（最大 240 秒）"
echo
echo '```'
WT=0
P="$(pending_n)"; [ -n "$P" ] || P=-1
printf '  はじめの pending: %s 件\n' "$P"
while [ "$WT" -lt 240 ]; do
  P="$(pending_n)"; [ -n "$P" ] || P=-1
  [ "$P" = "0" ] && break
  [ "$P" = "-1" ] && break
  sleep 10; WT=$((WT + 10))
done
P="$(pending_n)"; [ -n "$P" ] || P=-1
printf '  待った秒数: %s / いまの pending: %s 件 %s\n' "$WT" "$P" \
  "$( [ "$P" = "0" ] && echo '← 落ち着いた' || echo '← **まだ残っている**' )"
echo '```'

echo
echo "## 2. 今日の発火 4 回 の内訳（**picked と出た数を並べる**）"
echo
echo '```'
TODAY="$(date '+%Y-%m-%d')"
OLOG="$L/comment-orchestrator.log"
if [ -f "$OLOG" ]; then
  grep -E "^\[$TODAY" "$OLOG" 2>/dev/null \
    | grep -E 'orchestrator start|picked |orchestrator done|gen failed|生成側が skip' \
    | cut -c1-200 | clean | sed 's/^/  /'
else
  echo "  **comment-orchestrator.log が無い**"
fi
echo '```'
echo
echo "**\`gen failed\` の実体は \`skip\`。** ラベルが誤解を招くが、故障ではない。"

echo
echo "## 3. 実際に出たもの（**一次情報：キューの \`x_tweet_id\`**）"
echo
echo '```json'
node -e '
  const fs = require("fs");
  let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
  catch (e) { console.log("  **読めない: " + e.message + "**"); process.exit(0); }
  const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
  if (!Array.isArray(rows)) { console.log("  **配列が取れない**"); process.exit(0); }
  const jstDay = (t) => new Date(t + 9 * 3600 * 1000).toISOString().slice(0, 10);
  const today = jstDay(Date.now());
  const pick = [];
  for (const r of rows) {
    if (!r || !/comment|reply/i.test(String(r.kind || ""))) continue;
    const ts = [r.posted_at, r.created_at, r.enqueued_at, r.scheduled_at]
      .map((x) => new Date(x || 0).getTime()).filter((t) => Number.isFinite(t) && t > 0);
    const t = ts.length ? Math.max(...ts) : 0;
    if (t && jstDay(t) === today) pick.push({ r, t });
  }
  pick.sort((a, b) => a.t - b.t);
  const jst = (t) => new Date(t + 9 * 3600 * 1000).toISOString().slice(11, 19);
  let posted = 0, stuck = 0;
  console.log("  今日（JST）の comment エントリ: " + pick.length + " 件");
  console.log("");
  for (const { r, t } of pick) {
    const tid = r.x_tweet_id || r.tweet_id;
    if (tid) posted++; else stuck++;
    console.log("  " + jst(t) + "  status=" + String(r.status || "-"));
    console.log("    " + (tid ? "https://x.com/heng_ji31590/status/" + tid : "**tweet_id が無い**"));
  }
  console.log("");
  console.log("  → **出た " + posted + " 件 / 出ていない " + stuck + " 件**");
  console.log("  → **22:00 以降の行が在るか**が今回の答え");
' "$Q" 2>&1 | clean
echo '```'

echo
echo "## 4. 既にある警報はいま何と言っているか"
echo
echo "**\`last_reply\` が 8 時間 を超えると Slack に 🚨。** いまの値を出す。"
echo
echo '```'
node -e '
  const fs = require("fs");
  let q; try { q = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); } catch (e) { console.log("  読めない"); process.exit(0); }
  const rows = (q.queue || (Array.isArray(q) ? q : [])).filter((e) => e && /comment|reply/.test(String(e.kind||"")) && (e.x_tweet_id || e.tweet_id));
  const t = rows.map((e) => new Date(e.posted_at || e.created_at || 0).getTime()).filter((n) => n > 0);
  if (!t.length) { console.log("  返信の記録が無い"); process.exit(0); }
  const last = Math.max(...t);
  const ageH = (Date.now() - last) / 3600000;
  const jst = new Date(last + 9 * 3600 * 1000).toISOString().slice(0, 19).replace("T", " ");
  console.log("  最後の返信: " + jst + " JST");
  console.log("  経過: " + ageH.toFixed(1) + " 時間 → stale = " + (ageH >= 8 ? "**true（鳴る）**" : "false（鳴らない）"));
  console.log("");
  console.log("  **22:00 が 0 件 なら、翌 12:00 まで 14 時間 空く。** 01:00 ごろに 8 時間 を超えて鳴る");
' "$Q" 2>&1
echo
printf '  警報の印（/tmp/.x-reply-stale-alerted）: %s\n' "$( [ -f /tmp/.x-reply-stale-alerted ] && echo '**在る（もう鳴った）**' || echo '無い（まだ鳴っていない）' )"
echo '```'

echo
echo "## 5. ジョブは載ったままか"
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

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §3 の出方 | 意味 |"
echo "| --- | --- |"
echo "| 22:00 以降の行が在り \`x_tweet_id\` 付き | **出た。** 2 回 連続にはならなかった |"
echo "| 22:00 以降の行が無く §2 が \`skip\` | **2 回 連続で 0 件。** 候補の質か検査の厳しさを見る |"
echo "| 22:00 の \`start\` すら無い | **発火していない。** plist を見る |"
echo
echo "| §4 の出方 | 次 |"
echo "| --- | --- |"
echo "| \`stale = true\` | **もう鳴る状態。** 閾値（8 時間）を発火間隔に合わせるか判断する |"
echo "| 印が在る | **既に鳴った。** Slack の \`C0B4CJHH797\` を見る |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '今日の発火 4 回' "$OUT" 2>/dev/null; then
  echo "22:00 の結果を確定させた / $(basename "$OUT")"
else
  echo "**確定できていない。レポートを確認すること** / $(basename "$OUT")"
fi
