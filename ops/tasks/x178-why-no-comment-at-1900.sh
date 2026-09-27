#!/bin/bash
# **19:00 の発火でコメントが 0 件 だった理由と、トークン失効の実体を読む。読むだけ。$0。**
#
# ## 分かっていること（21:29 の heartbeat）
#
#   last_reply.at  2026-09-27T08:23:19Z ＝ **17:23:19 JST**（手で撃った分の最後）
#   auth           **ok: false / 「トークンの有効期限を過ぎている」**
#                  expires_at 12:10:00Z ＝ **21:10 JST**
#   cdp            healthy: true（port 18810）
#   x_jobs         loaded 8 / expected 8 / halted false / missing []
#   autoload       target 14 / tried 0 / loaded 0 ＝ **外れていない**
#
# **載っているのに出ていない。** 19:00 の発火が
#   ① そもそも走っていない
#   ② 走ったが候補が 0 件（17:19 の時点で `from 4 candidates` まで減っていた）
#   ③ 走って候補も在ったが、投稿で落ちた
# のどれかを**ログで切り分ける。推測で決めない。**
#
# ## トークンのほうも実体を見る
#
# `auth.ok` を**何から測っているのか**、**誰が更新するのか**を特定する。
# **分からないままでは直せない。** heartbeat のスクリプトを読めば分かる。
#
# ## やらないこと
#
# **撃たない。トークンを触らない。設定も変えない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
L="$W/logs"
UID_N="$(id -u)"
LABEL="ai.openclaw.comment-warmup"
OUT="${OPS_REPORT_DIR:-/tmp}/why-no-comment-1900.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secret() { sed -E 's/(xox[abprs]-[A-Za-z0-9-]+)/<トークン伏せ>/g; s/([A-Za-z_]*TOKEN[A-Za-z_]*=)[^ "]*/\1<伏せ>/g; s/(Bearer )[A-Za-z0-9._-]{8,}/\1<伏せ>/g' ; }
clean() { hide | secret; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

{
echo "# 19:00 でコメントが 0 件 だった理由（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 撃っていない。トークンも触っていない。"

echo
echo "## 1. 19:00 と 22:00 の発火はあったか"
echo
echo "**\`runs\` は載せ直しで 0 に戻るので、これ単体では足りない。** ログと併せて見る。"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
    | grep -E '^[[:space:]]+(state|runs|last exit code|path) ' | sed 's/^/    /'
else
  echo "    **載っていない**"
fi
echo '```'
echo
echo '```'
OLOG="$L/comment-orchestrator.log"
WLOG="$L/comment-warmup.log"
TODAY="$(date '+%Y-%m-%d')"
for f in "$OLOG" "$WLOG"; do
  [ -f "$f" ] || { printf '  %-28s **ログが無い**\n' "$(basename "$f")"; continue; }
  printf '  ===== %s（更新 %s）=====\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%m-%d %H:%M:%S' "$f" 2>/dev/null)"
  echo "    --- 今日の start / picked / candidates ---"
  grep -E "^\[$TODAY" "$f" 2>/dev/null \
    | grep -E 'start|picked|candidate|候補|skip|no ' | tail -20 | cut -c1-200 | clean | sed 's/^/      /'
  echo
  echo "    --- 18:30 以降の全部（ここに答えが在る）---"
  awk -v d="$TODAY" '$0 ~ ("^\\[" d "T(18:[3-5]|19|2[0-3])")' "$f" 2>/dev/null \
    | tail -40 | cut -c1-200 | clean | sed 's/^/      /'
  echo
done
echo '```'
echo
echo "**\`start\` が無ければ①、\`from 0 candidates\` なら②、\`picked\` の後で落ちていれば③。**"

echo
echo "## 2. 候補が枯れているのか（**②の裏取り**）"
echo
echo "候補の条件は \`MIN_LIKES=2\` / \`MAX_AGE_HOURS=18\`。"
echo "**すでに返信した相手は外れる**ので、同じ日に何度も撃つと枯れる。"
echo
echo '```'
for f in ng-filter reply-ng tone-gate relevance; do
  g="$L/$f.log"
  [ -f "$g" ] && printf '  %-22s 更新 %s / %s bytes\n' "$f" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$g" 2>/dev/null)" "$(wc -c < "$g" | tr -d ' ')"
done
echo
echo "  --- 今日 弾いた数（入口・出口）---"
for f in "$OLOG" "$WLOG"; do
  [ -f "$f" ] || continue
  printf '  %-28s ng %s / tone %s / relevance %s / 既に返信 %s\n' "$(basename "$f")" \
    "$(cnt 'ng-filter\|ng_filter\|NG' "$f")" "$(cnt 'tone' "$f")" \
    "$(cnt 'relevance' "$f")" "$(cnt '既に\|already\|dup' "$f")"
done
echo '```'

echo
echo "## 3. トークンは何で測っていて、誰が更新するのか"
echo
echo "**\`auth.ok\` の出どころを特定する。** 分からないままでは直せない。"
echo
echo '```'
HB=""
for c in "$S/ops-heartbeat.sh" "$W/scripts/ops-heartbeat.sh" "$HOME/ops-heartbeat.sh"; do
  [ -f "$c" ] && { HB="$c"; break; }
done
if [ -z "$HB" ]; then
  echo "  **ops-heartbeat.sh が見つからない**"
  ls -1 "$S" 2>/dev/null | grep -i heartbeat | sed 's/^/    /'
else
  printf '  %s（%s 行）\n\n' "$(basename "$HB")" "$(wc -l < "$HB" | tr -d ' ')"
  grep -n -B3 -A10 -E 'expires_at|有効期限|"auth"' "$HB" 2>/dev/null | head -50 | cut -c1-200 | clean | sed 's/^/    /'
fi
echo '```'
echo
echo '```'
echo "  --- トークンの実体が入っているファイル（**中身は出さない**）---"
for f in "$D/x-auth.json" "$D/auth.json" "$D/token.json" "$D/x-token.json" "$D/session.json" "$W/config/.env"; do
  if [ -f "$f" ]; then
    printf '  %-34s %8s bytes / 更新 %s\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
  fi
done
echo
echo "  --- data/ の中で expires を持つ JSON（**キー名だけ**）---"
for f in "$D"/*.json; do
  [ -f "$f" ] || continue
  c="$(grep -c 'expires' "$f" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac
  [ "$c" = "0" ] && continue
  printf '  %-34s expires %s 箇所 / 更新 %s\n' "$(basename "$f")" "$c" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
done
echo
echo "  --- 更新しているらしいスクリプト ---"
grep -l -E 'refresh.*token|token.*refresh|expires_at' "$S"/*.js "$S"/*.sh 2>/dev/null | sed 's|.*/|    |' || echo "    （無い）"
echo '```'

echo
echo "## 4. 失効しても投稿できているのか（**切り分け**）"
echo
echo "**\`auth\` は API 用のトークンで、コメントは Playwright の DOM 操作。**"
echo "**別物なら、失効しても投稿はできる。** そこを混同しない。"
echo
echo '```'
echo "  comment-orchestrator が API トークンを使っているか:"
for f in "$S/comment-orchestrator.sh" "$S/post-comment.js" "$S/asuka-fill.js"; do
  [ -f "$f" ] || continue
  printf '    %-28s TOKEN %s 箇所 / Bearer %s 箇所 / playwright %s 箇所\n' "$(basename "$f")" \
    "$(cnt 'TOKEN' "$f")" "$(cnt 'Bearer' "$f")" "$(cnt 'playwright' "$f")"
done
echo
echo "  --- 17:23 より後に投稿ログが伸びているか ---"
for f in "$OLOG" "$WLOG" "$L/auto-reply.log"; do
  [ -f "$f" ] || continue
  printf '    %-28s 更新 %s\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%m-%d %H:%M:%S' "$f" 2>/dev/null)"
done
echo '```'

echo
echo "## 5. キューの実物（**一次情報**）"
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
  const mine = [];
  for (const r of rows) {
    if (!r || !/comment|reply/i.test(String(r.kind || ""))) continue;
    const ts = [r.posted_at, r.created_at, r.enqueued_at, r.scheduled_at]
      .map((x) => new Date(x || 0).getTime()).filter((t) => Number.isFinite(t) && t > 0);
    const t = ts.length ? Math.max(...ts) : 0;
    if (t && jstDay(t) === today) mine.push({ r, t });
  }
  mine.sort((a, b) => a.t - b.t);
  const jst = (t) => new Date(t + 9 * 3600 * 1000).toISOString().slice(11, 19);
  console.log("  今日（JST）の comment エントリ: " + mine.length + " 件");
  console.log("");
  for (const { r, t } of mine) {
    const tid = r.x_tweet_id || r.tweet_id;
    console.log("  " + jst(t) + "  status=" + String(r.status || "-") +
                "  " + (tid ? "tweet_id=" + tid : "**tweet_id なし**"));
  }
  console.log("");
  console.log("  → **19:00 以降の行が在るか**が答え。無ければ発火しても積まれていない");
' "$D/post_queue.json" 2>&1 | clean
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §1 の出方 | 原因 | 次 |"
echo "| --- | --- | --- |"
echo "| 19:00 の \`start\` が**無い** | ① 発火していない | plist の \`StartCalendarInterval\` と `launchd` を見る |"
echo "| \`from 0 candidates\` | ② 候補切れ | **故障ではない。** \`MAX_AGE_HOURS\` を伸ばすか、対象を広げる |"
echo "| \`picked N\` の後で落ちている | ③ 投稿で落ちた | §4 でトークンと Playwright を切り分ける |"
echo
echo "| §3・§4 の出方 | 意味 |"
echo "| --- | --- |"
echo "| コメント側に \`TOKEN\` / \`Bearer\` が 0 箇所 | **失効はコメントに関係ない。** 別の原因 |"
echo "| \`TOKEN\` を使っている | **失効が直接の原因。** 更新の口を探す（§3） |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'トークンは何で測っていて' "$OUT" 2>/dev/null; then
  echo "19:00 で出なかった理由を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
