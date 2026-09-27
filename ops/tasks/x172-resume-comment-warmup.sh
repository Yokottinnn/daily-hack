#!/bin/bash
# **`comment-warmup` を常駐に戻す。最優先。**
#
# ## 戻してよいと判断した根拠（`x166` の試走・2026-09-27 16:00）
#
#   候補として見た 1 件 / **打った（enqueue）2 件**
#   comment-20260927-1603-0  status=**posted**  x_tweet_id=2104104794084544828
#   comment-20260927-1604-1  status=**posted**  x_tweet_id=2104104877668680175
#
# **どちらも一次情報（キューの `x_tweet_id`）で出たことを確認済み**（最上位ルール 11）。
# 文面も壊れていない。`tone-gate` / `relevance` も噛んでいる（各 1 箇所）。
#
# ### `x166` の §3 が「守りが 0 箇所」と出したのは、見るファイルを間違えたため
#
# `x166` は `engage-via-playwright.js`（176 行）を見ていた。
# **守りが入っているのは `post-comment.js`（361 行）。**
# 12:00 の publisher ログに `[x154] like 付いた` が出ていたのがその証拠
# （あの経路は `post-comment.js` を呼ぶ）。**このタスクで正しいファイルを数え直す。**
#
# ## やること
#
#   ① `.plist.disabled` → `.plist` に戻す
#   ② `bootout` → `bootstrap`。**`launchctl print` で載ったか確かめる**（`list | grep` では足りない）
#   ③ **守りを正しいファイルで数える**（`post-comment.js`）
#   ④ 環境変数を出す（費用の根拠を残す）
#
# `ai.openclaw.comment-warmup` は `ops/data/autoload-jobs.txt` に**既に在る**ので、
# 名前を戻せば 30 分ごとに載せ直され続ける。**一覧への追加は不要。**
#
# ## やらないこと
#
# **量を変えない。** `MAX_PICKS_PER_FIRE` は plist の値（6）のまま。
# **文面もテンプレートも触らない。**
#
# ## 費用（最上位ルール 2-B）
#
# **これは増額である。** 止めていた分が戻る。
#
#   1 回あたり   **$0.00417/件**（Haiku 4.5・`x-reply-style` §5 の実測）
#   1 日あたり   **$0.081**（2026-09-21 の自己計測。6 picks × 4 発火 ＝ 24 picks/日）
#   1 か月あたり **約 $2.43**
#
# 運用全体では **約 $4.5／月**（記事リフレッシュの実測 約 $1.33／月 を含む）。
# 2026-09-27 に利用者が「コメントの再開が最優先」と指示した。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
LABEL="ai.openclaw.comment-warmup"
OUT="${OPS_REPORT_DIR:-/tmp}/resume-comment-warmup.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

{
echo "# comment-warmup を常駐に戻す（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **量は変えない。** \`MAX_PICKS_PER_FIRE\` は plist の値のまま。"
echo "> **費用: \$0.00417／件・実測 \$0.081／日・約 \$2.43／月**（増額。2026-09-27 に指示）"

echo
echo "## 1. 戻す前の状態"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  echo "  **すでに載っている。** 戻す必要が無いか確かめる"
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | grep -E '^[[:space:]]+(state|runs) ' | sed 's/^/    /'
else
  echo "  載っていない（止まったまま。想定どおり）"
fi
for f in "$LABEL.plist" "$LABEL.plist.disabled"; do
  if [ -f "$LA/$f" ]; then
    printf '  %-46s あり（%s bytes）\n' "$f" "$(wc -c < "$LA/$f" | tr -d ' ')"
  else
    printf '  %-46s 無い\n' "$f"
  fi
done
echo '```'

echo
echo "## 2. 守りを**正しいファイル**で数える"
echo
echo "**\`x166\` は \`engage-via-playwright.js\` を見て 0 と出した。** 入っているのは"
echo "\`post-comment.js\` のほう。12:00 の publisher ログの \`[x154] like 付いた\` がその証拠。"
echo
echo '```'
for c in post-comment.js engage-via-playwright.js; do
  f="$S/$c"
  if [ ! -f "$f" ]; then printf '  %-30s **無い**\n' "$c"; continue; fi
  printf '  ===== %s（%s 行）=====\n' "$c" "$(wc -l < "$f" | tr -d ' ')"
  printf '    x150 ① 返信先ページに居るか   %s 箇所\n' "$(cnt '_x150want' "$f")"
  printf '    x150 ② フォーカスが載ったか   %s 箇所\n' "$(cnt '_x150focus' "$f")"
  printf '    x150 ③ 打った文の照合         %s 箇所\n' "$(cnt 'text-mismatch' "$f")"
  printf '    x154    いいねを付ける        %s 箇所\n' "$(cnt '_x154' "$f")"
done
echo '```'
echo
echo "**\`post-comment.js\` 側が 4 つとも 1 以上なら、守りは生きている。**"

echo
echo "## 3. 名前を戻して載せる"
echo
echo '```'
if [ -f "$LA/$LABEL.plist.disabled" ]; then
  mv "$LA/$LABEL.plist.disabled" "$LA/$LABEL.plist"
  echo "  リネーム: $LABEL.plist.disabled -> $LABEL.plist"
elif [ -f "$LA/$LABEL.plist" ]; then
  echo "  すでに $LABEL.plist の名前になっている（リネーム不要）"
else
  echo "  **plist がどちらの名前でも無い。ここで止まる。**"
  ls -1 "$LA" 2>/dev/null | grep -i 'comment' | sed 's/^/    /' || echo "    （comment 系が無い）"
  echo '```'
  echo
  echo "**推測で plist を作らない**（最上位ルール 14）。"
  exit 1
fi
echo
# **`load` ではなく `bootstrap`**（最上位ルール 13）
launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null
BS="$(launchctl bootstrap "gui/$UID_N" "$LA/$LABEL.plist" 2>&1)"; BRC=$?
printf '  bootstrap rc=%s %s\n' "$BRC" "$(printf '%s' "$BS" | cut -c1-120)"
echo "  （**rc=5 Input/output error は「もう載っている」の出方**。消えた証拠ではない）"
echo '```'

echo
echo "## 4. 載ったことの証拠（**\`list | grep\` では足りない**）"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
    | grep -E '^[[:space:]]+(state|runs|path|program|last exit code) ' | sed 's/^/    /'
  echo "    → **載っている。再開した。**"
else
  echo "    → **載っていない。再開していない。**"
  echo
  echo "    bootstrap の出力をもう一度:"
  printf '%s\n' "$BS" | cut -c1-200 | sed 's/^/      /'
fi
echo '```'

echo
echo "## 5. どの設定で動くか（**費用の根拠**）"
echo
echo '```'
/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval" "$LA/$LABEL.plist" 2>/dev/null | sed 's/^/  /' \
  || echo "  （StartCalendarInterval が無い）"
/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$LA/$LABEL.plist" 2>/dev/null | clean | sed 's/^/  /' \
  || echo "  （EnvironmentVariables が無い）"
echo '```'
echo
echo "**\`MAX_PICKS_PER_FIRE\` が 6 で発火が 4 回なら 24 picks/日** ＝ 2026-09-21 の"
echo "自己計測（**実測 \$0.081／日**）と同じ条件。**数字が違っていたら、費用も変わる。**"

echo
echo "## 6. 載せ直しの対象になっているか"
echo
echo "**tab-guard は \`ai.openclaw.*\` を一斉に外す。** 30 分ごとに戻す側に載っているか。"
echo
echo '```'
# 一覧はリポジトリ側にある。heartbeat が origin/main から読む
REPO="${OPS_MAIN_REPO:-/Users/ny/projects/anta-baka-x/blog}"
if git -C "$REPO" show "origin/main:ops/data/autoload-jobs.txt" 2>/dev/null | grep -q "^$LABEL$"; then
  echo "  $LABEL は autoload-jobs.txt に **在る**（30 分ごとに載せ直される）"
else
  echo "  $LABEL は autoload-jobs.txt に **無い**。外されたら戻らない"
fi
echo '```'

echo
echo "## 7. 直近のログ（**戻した直後なので、まだ動いていないのが普通**）"
echo
echo '```'
f="$L/comment-warmup.log"
if [ -f "$f" ]; then
  printf '  更新 %s / %s bytes\n\n' "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)" "$(wc -c < "$f" | tr -d ' ')"
  tail -8 "$f" 2>/dev/null | cut -c1-190 | clean | sed 's/^/  /'
else
  echo "  comment-warmup.log が無い"
fi
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §4 の出方 | 意味 |"
echo "| --- | --- |"
echo "| **載っている** ＋ \`path\` が \`.plist\`（\`.disabled\` でない） | **再開した。** 次の発火時刻から動く |"
echo "| 載っていない | **再開していない。** bootstrap の出力を読む |"
echo
echo "| §2 の出方 | 意味 |"
echo "| --- | --- |"
echo "| \`post-comment.js\` が 4 つとも 1 以上 | **守りは生きている** |"
echo "| \`post-comment.js\` にも 0 が在る | **守りが消えている。** 入れ直しが要る（**戻したことは伝える**） |"
echo
echo "**費用: \$0.00417／件・実測 \$0.081／日・約 \$2.43／月。**"
echo "運用全体では約 \$4.5／月（記事リフレッシュの実測 約 \$1.33／月 を含む）。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '載ったことの証拠' "$OUT" 2>/dev/null; then
  echo "comment-warmup を戻した / $(basename "$OUT")"
else
  echo "**戻せていない。レポートを確認すること** / $(basename "$OUT")"
fi
