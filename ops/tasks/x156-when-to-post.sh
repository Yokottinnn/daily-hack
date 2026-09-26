#!/bin/bash
# **いつ投稿すべきかを自分の実績から出す。＋ 予約が効く状態かを確かめる。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# 「**いつ投稿するべきかな？ 予約投稿して。**」と言われた。
#
# **一般論で答えない**（最上位ルール 11）。「夜がいい」「朝がいい」は根拠にならない。
# **自分のアカウントの実績**（何時に出したものが何回 見られたか）から出す。
#
# ## 予約の仕組み（契約書 §3）
#
# `auto-x-publisher.js` は **5 つすべての AND** で候補を選ぶ。
#
#   status = awaiting_approval ／ kind = "thread" ／ id の接頭辞 = "blog-promo-"
#   auto_publish = true ／ **scheduled_at が now 以前**
#
# **つまり `scheduled_at` を未来に置けば、その時刻まで出ない。予約はネイティブに効く。**
#
# **ただしジョブが載っていなければ、いつまでも出ない。**（最上位ルール 13）
# `launchctl print` で確かめる。`list | grep` は証拠にならない。
#
# ## 何を出すか
#
#   ① **自分の投稿の時刻ごとの表示回数**（一次情報がある範囲で）
#   ② 予約を実行するジョブが**載っているか**、次にいつ走るか
#   ③ キューの形（`scheduled_at` を実際に使っている行があるか）
#
# ## やらないこと
#
# **積まない。投稿しない。書き換えない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/when-to-post.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

{
echo "# いつ投稿すべきか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 積んでいない。投稿もしていない。"
echo "> **一般論ではなく、自分の実績から出す。**"

echo
echo "## 1. 自分の投稿を時刻ごとに並べる（**一次情報**）"
echo
echo "\`post_queue.json\` の \`posted_at\` と \`x_tweet_id\` を突き合わせる。"
echo "**表示回数が取れているものは一緒に出す。**"
echo
echo '```'
if [ -f "$D/post_queue.json" ]; then
  node -e '
    const fs = require("fs");
    const raw = fs.readFileSync(process.argv[1], "utf8");
    let q; try { q = JSON.parse(raw); } catch (e) { console.log("  **post_queue.json が読めない: " + e.message + "**"); process.exit(0); }
    const rows = Array.isArray(q) ? q : (q.items || q.queue || q.posts || []);
    if (!rows.length) { console.log("  **配列が見つからない。キーは: " + Object.keys(q).join(", ") + "**"); process.exit(0); }
    const posted = rows.filter((r) => r && (r.x_tweet_id || r.tweet_id) && r.posted_at);
    console.log("  キューの行 " + rows.length + " 件 / **実際に出たもの " + posted.length + " 件**");
    console.log("");
    // JST の時 で束ねる
    const byHour = new Map();
    for (const r of posted) {
      const t = new Date(r.posted_at);
      if (isNaN(t)) continue;
      const jst = new Date(t.getTime() + 9 * 3600 * 1000);
      const h = jst.getUTCHours();
      if (!byHour.has(h)) byHour.set(h, []);
      byHour.get(h).push(r);
    }
    const hours = [...byHour.keys()].sort((a, b) => a - b);
    console.log("  時刻（JST）  件数  種類");
    for (const h of hours) {
      const list = byHour.get(h);
      const kinds = [...new Set(list.map((r) => r.kind || "-"))].join(",");
      console.log("  " + String(h).padStart(2, "0") + ":00        " + String(list.length).padStart(3) + "   " + kinds);
    }
    console.log("");
    console.log("  **これは「何時に出したか」であって「何時が効いたか」ではない。** §2 を見る");
  ' "$D/post_queue.json" 2>&1 | clean
else
  echo "  **post_queue.json が無い**"
fi
echo '```'

echo
echo "## 2. 表示回数の実績があるか"
echo
echo "**無ければ「何時が効くか」は自分のデータからは言えない。** そう書く。"
echo
echo '```'
found=0
for f in "$L/x-impressions.log" "$D"/*metric*.json "$D"/*impression*.json "$D"/*analytics*.json; do
  [ -f "$f" ] || continue
  found=1
  printf '  %-34s %9s bytes  更新 %s\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
done
[ "$found" -eq 0 ] && echo "  **表示回数を持っているファイルが無い**"
echo '```'
if [ -f "$L/x-impressions.log" ]; then
  echo
  echo "\`x-impressions.log\` の中身（末尾 30 行）:"
  echo
  echo '```'
  tail -30 "$L/x-impressions.log" 2>/dev/null | cut -c1-240 | clean | sed 's/^/  /'
  echo '```'
fi

echo
echo "## 3. 予約が効く状態か（**ジョブが載っていなければ出ない**）"
echo
echo '```'
for lb in ai.openclaw.auto-x-publisher ai.openclaw.poll-approvals ai.openclaw.x-publisher ai.openclaw.publish-queue; do
  if launchctl print "gui/$UID_N/$lb" >/dev/null 2>&1; then
    nxt="$(launchctl print "gui/$UID_N/$lb" 2>/dev/null | grep -E 'runs =|state =|last exit code =' | tr -s ' ' | tr '\n' ' ')"
    printf '  %-36s **載っている**  %s\n' "$lb" "$nxt"
  else
    printf '  %-36s 載っていない\n' "$lb"
  fi
done
echo
echo "  --- LaunchAgents に在る publisher 系の plist ---"
ls -1 "$LA" 2>/dev/null | grep -iE "publish|approval|queue" | sed 's/^/  /' || echo "  （無い）"
echo '```'
echo
echo "publisher の実体が在るか:"
echo
echo '```'
for f in "$S/auto-x-publisher.js" "$S/poll-approvals.js" "$S/run-publish.sh"; do
  if [ -f "$f" ]; then
    printf '  %-28s %5s 行  更新 %s\n' "$(basename "$f")" "$(wc -l < "$f" | tr -d ' ')" \
      "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
  else
    printf '  %-28s **無い**\n' "$(basename "$f")"
  fi
done
echo '```'

echo
echo "## 4. \`scheduled_at\` を実際に使っている行が在るか"
echo
echo "**在れば書式を写せる。** 無ければ契約書どおりに書く。"
echo
echo '```'
if [ -f "$D/post_queue.json" ]; then
  n="$(grep -c 'scheduled_at' "$D/post_queue.json" 2>/dev/null | head -1)"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  printf '  scheduled_at を含む行: %s\n' "$n"
  [ "$n" -gt 0 ] && grep -n 'scheduled_at' "$D/post_queue.json" 2>/dev/null | head -5 | cut -c1-200 | clean | sed 's/^/    /'
  a="$(grep -c 'auto_publish' "$D/post_queue.json" 2>/dev/null | head -1)"
  case "$a" in ''|*[!0-9]*) a=0 ;; esac
  printf '  auto_publish を含む行: %s\n' "$a"
fi
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 出方 | 何が言えるか |"
echo "| --- | --- |"
echo "| §2 に表示回数が**在る** | **自分の実績で時刻を選べる。** 一般論を使わずに済む |"
echo "| §2 が**空** | **自分のデータでは言えない。** そう言ったうえで、外の一般論しか無いと断る |"
echo "| §3 でジョブが**載っていない** | **予約しても出ない。** 先に載せる話になる |"
echo "| §4 に \`scheduled_at\` の実績が在る | **その書式を写す**（推測しない） |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '実際に出たもの' "$OUT" 2>/dev/null; then
  echo "投稿時刻の実績と予約の可否を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
