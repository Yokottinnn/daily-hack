#!/bin/bash
# **comment-warmup を 1 回だけ試す。守りが効くかを見る。常駐には戻さない。**
#
# ## なぜ要るか
#
# `comment-warmup` は **2026-09-25 22:28 JST から止めてある**（`x146`）。
# 壊れた返信を単独投稿として出したため（頭の「アタ」が落ちた文）。
#
# 直しは 2 本 入れて、**置いたことは Mac で確認済み**。
#
#   `x150`  打つ前の守り 3 つ（返信先ページに居るか／フォーカスが載ったか／
#           **打った文が意図した文と一致するか**）。合わなければ**打たずに止まる**
#   `x154`  返信するときに**いいねも付ける**
#
# **だが X に対して一度も発火していない。守りが効くかは未検証。**
# 2026-09-27 に利用者が「**1 回だけ試してから戻す**」を選んだ。
#
# ## このタスクがやること
#
#   ① 無効化した plist から**本当のコマンドと環境変数を読み取る**（推測しない）
#   ② 守り（`x150` / `x154`）が**いま入っているか**を実体で確かめる
#   ③ `tone-gate` / `relevance-gate` が**噛んでいるか**を確かめる
#   ④ **1 回だけ**走らせる（`MAX_PICKS_PER_FIRE=2` に**下げて**）
#   ⑤ 結果を出す。**「見た件数」と「打った件数」を両方**（最上位ルール 14）
#
# ## やらないこと
#
# **plist を戻さない。** リネームも `bootstrap` もしない。
# 常駐に戻すかは、このレポートを見てから利用者が決める。
#
# ## 費用（最上位ルール 2-B）
#
# **`asuka-fill.js` が LLM を呼ぶ。この 1 回だけ課金される。**
#
#   実測単価  **$0.00417/件**（Haiku 4.5・`x-reply-style` スキル §5 の実測）
#   この試走  2 picks なので **最大 $0.0083／回**
#   1 日      **$0.0083**（このタスクは 1 回しか走らない。最上位ルール 1）
#   1 か月    **$0.0083**（同じ。反復しない）
#
# **常駐に戻した場合は別で、実測 $0.081／日・約 $2.43／月**
# （`docs/recurring-job-costs.md` の 2026-09-21 の自己計測）。
# **この試走はその額を発生させない。**
#
# 2026-09-27 にダイアログで承認済み（最上位ルール 2-A）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
LABEL="ai.openclaw.comment-warmup"
PL="$LA/$LABEL.plist.disabled"
OUT="${OPS_REPORT_DIR:-/tmp}/comment-warmup-trial.md"
RUNLOG="$W/.x166-run.log"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

# **`timeout` は Mac に無い**（最上位ルール 14）。素の bash で打ち切る
descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
    w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    # **プロセスグループ指定（`kill -TERM -$pid`）を使わない。** 呼び出し側ごと落ちる
    local victims p
    victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"
  return $?
}

# **`grep -c` は 0 件でも「0」を出したうえで rc=1 を返す。**
# `|| echo 0` を付けると 0 が 2 行 出る（最上位ルール 13）。だから付けない
cnt()  { c="$(grep -c  "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }
cntE() { c="$(grep -cE "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

{
echo "# comment-warmup を 1 回だけ試す（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **常駐には戻していない。** plist はリネームしたまま、\`bootstrap\` もしていない。"
echo "> **この試走の費用は最大 \$0.0083（2 picks × 実測 \$0.00417/件・Haiku 4.5）。**"

echo
echo "## 1. 止まったままか（**戻していないことの確認**）"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  echo "  **載っている。想定と違う。** 誰かが戻した可能性がある"
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | grep -E '^[[:space:]]+(state|runs) ' | sed 's/^/    /'
else
  echo "  載っていない（止まったまま。想定どおり）"
fi
[ -f "$PL" ] && echo "  plist.disabled: あり" || echo "  plist.disabled: **無い**"
[ -f "$LA/$LABEL.plist" ] && echo "  plist（有効な名前）: **在る。載せ直しの対象になってしまう**" || echo "  plist（有効な名前）: 無い（対象外のまま）"
echo '```'

echo
echo "## 2. plist から本当のコマンドを読む（**推測しない**）"
echo
if [ ! -f "$PL" ]; then
  echo "- **\`$LABEL.plist.disabled\` が無い。ここで止まる。**"
  echo
  echo '```'
  ls -1 "$LA" 2>/dev/null | grep -i 'comment' | sed 's/^/  /' || echo "  （comment 系の plist が無い）"
  echo '```'
  echo
  echo "**推測でコマンドを組まない**（最上位ルール 14）。候補を出して終わる。"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'
/usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$PL" 2>/dev/null | clean | sed 's/^/  /'
echo
echo "  --- EnvironmentVariables ---"
/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$PL" 2>/dev/null | clean | sed 's/^/  /'
echo '```'

# ProgramArguments を配列として取り出す。
# **PlistBuddy は `Array {` … `}` で囲む。** 行番号で削ると最初の要素まで落ちる
ARGS_FILE="$W/.x166-args.txt"
/usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$PL" 2>/dev/null \
  | awk '
      /^[[:space:]]*(Array|Dict)?[[:space:]]*\{[[:space:]]*$/ { next }
      /^[[:space:]]*\}[[:space:]]*$/ { next }
      { sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if (length($0)) print }
    ' > "$ARGS_FILE"
# **末尾に改行が無いと最後の 1 行が読まれない**（最上位ルール 14）。awk の print は付ける
NARGS="$(grep -c . "$ARGS_FILE" 2>/dev/null | head -1)"
case "$NARGS" in ''|*[!0-9]*) NARGS=0 ;; esac

echo
echo "## 3. 守りが入っているか（**実体で確かめる**）"
echo
echo "**\`x150\` / \`x154\` は「置いた」ことまでは確認済み。ここでは消えていないかを見る。**"
echo
echo '```'
COMPOSER=""
for c in "$S/engage-via-playwright.js" "$S/reply-via-playwright.js" "$S/comment-post.js"; do
  [ -f "$c" ] && { COMPOSER="$c"; break; }
done
if [ -z "$COMPOSER" ]; then
  echo "  **返信を打つスクリプトが見つからない**"
  ls -1 "$S" 2>/dev/null | grep -iE 'engage|reply|comment' | sed 's/^/    /'
else
  printf '  対象: %s（%s 行）\n' "$(basename "$COMPOSER")" "$(wc -l < "$COMPOSER" | tr -d ' ')"
  echo
  printf '  x150 ① 返信先ページに居るか   %s 箇所\n' "$(cnt '_x150want' "$COMPOSER")"
  printf '  x150 ② フォーカスが載ったか   %s 箇所\n' "$(cnt '_x150focus' "$COMPOSER")"
  printf '  x150 ③ 打った文の照合         %s 箇所\n' "$(cnt 'text-mismatch' "$COMPOSER")"
  printf '  x154    いいねを付ける        %s 箇所\n' "$(cnt '_x154' "$COMPOSER")"
  echo
  printf '  （消えていれば 0 になる。0 が在れば、戻す前に入れ直す）\n'
fi
echo
echo "  --- 出口の検査が噛んでいるか（x-reply-style §4 / §4-B）---"
ORCH=""
for o in "$S/comment-orchestrator.sh" "$S/comment-warmup.sh"; do
  [ -f "$o" ] && { ORCH="$o"; break; }
done
if [ -z "$ORCH" ]; then
  echo "  **orchestrator が見つからない**"
  ls -1 "$S" 2>/dev/null | grep -iE 'orchestrator|warmup' | sed 's/^/    /'
else
  printf '  対象: %s\n' "$(basename "$ORCH")"
  printf '  tone-gate       %s 箇所\n' "$(cnt 'tone-gate' "$ORCH")"
  printf '  relevance       %s 箇所\n' "$(cnt 'relevance' "$ORCH")"
fi
echo '```'

echo
echo "## 4. 1 回だけ走らせる（**\`MAX_PICKS_PER_FIRE=2\` に下げる**）"
echo
echo "**量は上げない**（\`x-reply-style\` §5「量は最後」）。"
echo "確かめたいのは守りが効くかで、件数ではない。"
echo
if [ "$NARGS" -lt 1 ]; then
  echo "- **ProgramArguments が読めない。走らせずに終わる。**"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi
echo '```'
printf '  打つもの: '
tr '\n' ' ' < "$ARGS_FILE" | clean
echo
echo "  環境: MAX_PICKS_PER_FIRE=2 FORCE_RUN=1（plist の値は上書きする）"
echo
# plist の環境変数を引き継ぎつつ picks だけ下げる
ENVF="$W/.x166-env.sh"
: > "$ENVF"
/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$PL" 2>/dev/null \
  | awk '
      /^[[:space:]]*(Array|Dict)?[[:space:]]*\{[[:space:]]*$/ { next }
      /^[[:space:]]*\}[[:space:]]*$/ { next }
      {
        line=$0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line);
        i=index(line, " = ");
        if (i<=0) next;
        k=substr(line,1,i-1); v=substr(line,i+3);
        # picks はこちらで下げる。plist の値は捨てる
        if (k=="MAX_PICKS_PER_FIRE") next;
        gsub(/"/,"\\\"",v);
        printf "export %s=\"%s\"\n", k, v;
      }' >> "$ENVF"
printf 'export MAX_PICKS_PER_FIRE=2\nexport FORCE_RUN=1\n' >> "$ENVF"
printf '  引き継いだ環境変数: %s 件\n' "$(grep -c '^export ' "$ENVF" | head -1)"
echo
echo "  --- 実行（上限 240 秒。超えたら打ち切る）---"
RUNNER="$W/.x166-runner.sh"
{
  echo '#!/bin/bash'
  echo 'set -uo pipefail'
  printf '. %s\n' "$ENVF"
  printf 'cd %s\n' "$W"
  printf 'exec'
  while IFS= read -r a || [ -n "$a" ]; do
    [ -n "$a" ] || continue
    printf ' %s' "'$(printf '%s' "$a" | sed "s/'/'\\\\''/g")'"
  done < "$ARGS_FILE"
  echo
} > "$RUNNER"
chmod +x "$RUNNER"
run_limited 240 "$RUNLOG" /bin/bash "$RUNNER"
RC=$?
printf '  rc=%s%s\n' "$RC" "$( [ "$RC" = "124" ] && echo '  ← **240 秒 で打ち切った**' )"
echo
echo "  --- 出力の末尾 40 行 ---"
tail -40 "$RUNLOG" 2>/dev/null | cut -c1-200 | clean | sed 's/^/    /'
echo '```'

echo
echo "## 5. 見た件数と打った件数（**両方 出す**）"
echo
echo "**数が合わなければ、そこで気づける**（最上位ルール 14）。"
echo
echo '```'
printf '  候補として見た      %s 件\n' "$(cntE 'picked|候補|candidate' "$RUNLOG")"
printf '  生成まで進んだ      %s 件\n' "$(cntE 'asuka-fill|generated|生成' "$RUNLOG")"
printf '  打った（enqueue）   %s 件\n' "$(cntE 'enqueue|queued|積んだ' "$RUNLOG")"
echo
echo "  --- 守りが働いた形跡（**働いたなら、それは成功**）---"
printf '  wrong-page      %s 件\n' "$(cnt 'wrong-page' "$RUNLOG")"
printf '  no-focus        %s 件\n' "$(cnt 'no-focus' "$RUNLOG")"
printf '  text-mismatch   %s 件\n' "$(cnt 'text-mismatch' "$RUNLOG")"
echo
echo "  --- いいね（x154）---"
# **`||` はパイプの最後のコマンドに掛かる。** grep の rc では分岐できないので件数で見る
if [ "$(cnt '\[x154\]' "$RUNLOG")" -gt 0 ]; then
  grep -h '\[x154\]' "$RUNLOG" 2>/dev/null | tail -10 | cut -c1-160 | clean | sed 's/^/    /'
else
  echo "    **x154 の行が 1 本も無い。いいねの処理まで届いていない。**"
fi
echo '```'

echo
echo "## 6. キューに実際に積まれたか（**一次情報**）"
echo
echo "**ログではなくキューを見る**（最上位ルール 11）。"
echo
echo '```json'
node -e '
  const fs = require("fs");
  let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
  catch (e) { console.log("  **post_queue.json が読めない: " + e.message + "**"); process.exit(0); }
  const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
  if (!Array.isArray(rows)) { console.log("  **配列が取れない**"); process.exit(0); }
  const since = Date.now() - 30 * 60 * 1000;
  const recent = rows.filter((r) => {
    if (!r || !/comment|reply/i.test(String(r.kind || ""))) return false;
    const t = new Date(r.created_at || r.enqueued_at || r.scheduled_at || 0).getTime();
    return Number.isFinite(t) && t >= since;
  });
  console.log("  直近 30 分の comment エントリ: " + recent.length + " 件（キュー全体 " + rows.length + " 行）");
  for (const r of recent.slice(0, 6)) {
    console.log("    id=" + String(r.id || "-").slice(0, 40) +
                " status=" + String(r.status || "-") +
                " x_tweet_id=" + String(r.x_tweet_id || r.tweet_id || "**まだ無い**"));
    const t = String(r.text || r.body || "").replace(/\s+/g, " ").slice(0, 100);
    if (t) console.log("      文: " + t);
  }
' "$W/data/post_queue.json" 2>&1 | clean
echo '```'

rm -f "$ENVF" "$RUNNER" "$ARGS_FILE"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| 出方 | 次の一手 |"
echo "| --- | --- |"
echo "| §3 の守りが 4 つとも 1 以上 ／ §5 に壊れた文が無い | **常駐に戻してよい。** plist をリネームし直す |"
echo "| §3 に 0 が在る | **入れ直してから戻す。** 守りが消えている |"
echo "| §5 に \`text-mismatch\` が出た | **守りが働いた。** 打たずに止めたので成功。中身を見る |"
echo "| §6 の文が壊れている | **戻さない。** 生成側にまだ穴がある |"
echo "| §4 が rc=124 | 打ち切った。**Chrome か CDP を先に見る** |"
echo
echo "**この試走の費用: 最大 \$0.0083／回・\$0.0083／日・\$0.0083／月**"
echo "（1 回しか走らないため。常駐に戻すと別途 実測 \$0.081／日・約 \$2.43／月）"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
rm -f "$RUNLOG"

if grep -q '見た件数と打った件数' "$OUT" 2>/dev/null; then
  echo "comment-warmup を 1 回 試した（常駐には戻していない） / $(basename "$OUT")"
else
  echo "**試せていない。レポートを確認すること** / $(basename "$OUT")"
fi
