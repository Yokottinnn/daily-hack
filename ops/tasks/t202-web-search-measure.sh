#!/bin/bash
# **web 検索ありのリフレッシュを 1 回だけ実測する（t202）。**
#
# ## 承認済み（最上位ルール 2-A）
#
# 2026-09-28 にダイアログで「**1 回だけ実測する**」を選んでもらった。
# **見込みは 1 回 $0.09〜$0.29。** これは**この 1 回きり**で、定時実行の既定は
# 変えない（`refresh-daily.sh` は `USE_WEB_SEARCH` を付けない）。
#
# ## なぜ実測が要るか
#
# 単価は一次情報で確定した（**$10 / 1,000 searches ＝ $0.01/回**）。
# だが月額の見込みが **$2.6〜$8.5 と 3 倍 ぶれる。** 幅の元は 1 つだけ:
#
# > Web search results retrieved throughout a conversation are counted as input tokens,
# > **in search iterations executed during a single turn** and in subsequent turns.
#
# **検索結果のトークンが反復のたびに再送されるか**が、実測しないと分からない。
# 入力トークンの実数が出れば、そこで決まる。
#
# ## 何を測るか
#
#   ・**入力 / 出力トークン**（再送されているかはここに出る）
#   ・**`server_tool_use.web_search_requests`**（実際の検索回数。`max_uses: 6` は上限）
#   ・**トークン代と検索代の内訳**
#
# ## やらないこと
#
#   ・**`--apply` を付けない。** 本文は触らない（測るものと直すものを分ける・ルール 15）
#   ・**定時の状態ファイルを触らない。** 別ファイル（`refresh-measure.json`）に書く
#   ・**鍵の値を出さない。** 読めたかどうかだけ（出力は公開リポジトリに載る）
#
# ## 題材
#
# `amazon-prime-day-rakuten-ss-2026`。**web 検索がいちばん効く題材**を選んだ。
# `check-stale-wording.py` が 86 日 前から挙げている 1 箇所がこれ:
#
#   > 楽天スーパーSALEの9月開催は、例年の四半期開催パターンからの見込み（正式日程は楽天の告知待ち）
#
# **今日は 9/28。** 9 月開催は終わっているはずで、web 検索なしでは埋められない。
# 検索が効くなら確定日程が出る。**効かなければ、それも結果。**
#
# **240 秒 で打ち切る**（1 タスク 5 分 以内・ルール 15）。**この 1 回だけ課金する。**

set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t202-web-search-measure.md"
SLUG="amazon-prime-day-rakuten-ss-2026"
MSTATE="$HOME/.openclaw/state/refresh-measure.json"
T="${TMPDIR:-/tmp}/t202"
mkdir -p "$RDIR"

{
  echo "# web 検索ありの実測（t202・**承認済みの 1 回**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')** / 題材: \`$SLUG\`"
  echo ""
} > "$OUT"

[ -d "$REPO/.git" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
cd "$REPO" || { echo "⚠️ **cd できない**" >> "$OUT"; cat "$OUT"; exit 0; }

NODE_BIN="$(command -v node || echo /opt/homebrew/bin/node)"
[ -x "$NODE_BIN" ] || { echo "⚠️ **node が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

# ── 鍵を読む（refresh-daily.sh と同じ順。**値は出さない**） ──
KEY_NAME="ANTHROPIC""_API_KEY"
if [ -z "${!KEY_NAME:-}" ]; then
  ENVF="$HOME/openclaw/config/.env"
  # shellcheck disable=SC1090
  [ -f "$ENVF" ] && { set -a; . "$ENVF"; set +a; }
fi
if [ -z "${!KEY_NAME:-}" ]; then
  # **`launchctl getenv` は未設定でも rc=0。** 値が空でないことまで見る（ルール 13）
  _v="$(launchctl getenv "$KEY_NAME" 2>/dev/null)"
  [ -n "$_v" ] && export "$KEY_NAME=$_v"
  unset _v
fi
if [ -z "${!KEY_NAME:-}" ]; then
  for _p in "$HOME/Library/LaunchAgents/com.bubblesnow.remote.plist" \
            "$HOME/Library/LaunchAgents/com.bubblesnow.remote.daily-hack.plist" \
            "$HOME/Library/LaunchAgents/com.bubblesnow.remote.daily-hack-blog.plist"; do
    [ -f "$_p" ] || continue
    _v="$(plutil -extract "EnvironmentVariables.$KEY_NAME" raw -o - "$_p" 2>/dev/null)"
    if [ -n "$_v" ]; then export "$KEY_NAME=$_v"; break; fi
  done
  unset _p _v
fi
if [ -z "${!KEY_NAME:-}" ]; then
  echo "⚠️ **鍵が無い。呼ばずに終わる**（環境変数・.env・launchctl・plist のどれにも）。" >> "$OUT"
  cat "$OUT"; exit 0
fi
_K="${!KEY_NAME}"
echo "- 鍵: **読めた**（桁数 ${#_K}。**値は出さない**）" >> "$OUT"
unset _K

# ── SDK が入っているか（入口で見る。`<pkg>/package.json` は exports に無い） ──
if ! "$NODE_BIN" -e "require.resolve('@anthropic-ai/sdk')" >/dev/null 2>&1; then
  echo "- ⚠️ **\`@anthropic-ai/sdk\` が無い。** 入れずに終わる（このタスクは測るだけ）" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- SDK: **在る**" >> "$OUT"

# ── 作業場を作る ────────────────────────────────────────────
# **クローンは origin/main から遅れている**ので、記事もスクリプトも
# `git show origin/main:` で取り出す（t201 と同じ）。
# `import` は**スクリプトの置き場所**から解決されるので、
# スクリプトはリポジトリ内（隠しファイル）に置き、**cwd だけ作業場に向ける。**
# **拡張子は保つ**（`.new` を付けると `ERR_UNKNOWN_FILE_EXTENSION`・ルール 14）。
git fetch -q origin main 2>/dev/null || true
rm -rf "$T"; mkdir -p "$T/src/content/posts"
SC="$REPO/.t202-refresh-article.mjs"
if ! git show "origin/main:scripts/refresh-article.mjs" > "$SC" 2>/dev/null; then
  echo "- ⚠️ **スクリプトを取り出せない**" >> "$OUT"; cat "$OUT"; exit 0
fi
if ! git show "origin/main:src/content/posts/$SLUG.md" > "$T/src/content/posts/$SLUG.md" 2>/dev/null; then
  echo "- ⚠️ **記事を取り出せない**: \`$SLUG\`" >> "$OUT"; rm -f "$SC"; cat "$OUT"; exit 0
fi
{
  echo "- 記事: **$(wc -c < "$T/src/content/posts/$SLUG.md" | tr -d ' ') bytes** を origin/main から取り出した"
  echo ""
} >> "$OUT"

# ── 走らせる（**素の bash で打ち切る。`timeout` は macOS に無い**） ──
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 3
  done
  wait "$pid" 2>/dev/null
}

LOG="$T/run.txt"
T0=$(date +%s)
( cd "$T" && REFRESH_STATE="$MSTATE" OPS_REPORT_DIR="$T" USE_WEB_SEARCH=1 \
    run_limited 240 "$NODE_BIN" "$SC" --slug "$SLUG" > "$LOG" 2>&1 )
RC=$?
EL=$(( $(date +%s) - T0 ))
rm -f "$SC"

{
  echo "## 実行"
  echo ""
  echo "| | |"
  echo "| --- | --- |"
  echo "| 終了コード | **${RC}** $([ "$RC" = "124" ] && echo '（**打ち切り**）' || true) |"
  echo "| かかった時間 | **${EL} 秒** |"
  echo ""
} >> "$OUT"

# ── 実測値を出す（**`rc=0` は証拠にならない**・ルール 13） ────
{
  echo "## 実測値"
  echo ""
  echo '```text'
  grep -E '入力 |web 検索 |判定: |累計:' "$LOG" | head -8
  echo '```'
  echo ""
} >> "$OUT"

if [ -f "$MSTATE" ] && "$NODE_BIN" -e "JSON.parse(require('fs').readFileSync('$MSTATE','utf8'))" 2>/dev/null; then
  {
    echo "状態ファイル（**これが一次情報**）:"
    echo ""
    echo '```json'
    "$NODE_BIN" -e "const s=JSON.parse(require('fs').readFileSync('$MSTATE','utf8'));console.log(JSON.stringify(s.last,null,2))"
    echo '```'
    echo ""
    # **月額まで出す**（最上位ルール 2-B。1 回だけ出して終わらせない）
    "$NODE_BIN" -e "
      const s=JSON.parse(require('fs').readFileSync('$MSTATE','utf8')).last||{};
      const c=s.cost_usd||0, b=0.0443;
      console.log('| 単位 | web 検索あり（実測） | なし（9/23 実測） | 倍率 |');
      console.log('| --- | --- | --- | --- |');
      console.log('| 1 回 | **\$'+c.toFixed(4)+'** | \$0.0443 | '+(b?(c/b).toFixed(1):'?')+' 倍 |');
      console.log('| 1 日（1 本） | **\$'+c.toFixed(4)+'** | \$0.0443 | 同じ |');
      console.log('| **1 か月** | **約 \$'+(c*30).toFixed(2)+'** | 約 \$1.33 | '+(b?(c/b).toFixed(1):'?')+' 倍 |');
    "
    echo ""
  } >> "$OUT"
else
  echo "⚠️ **状態ファイルが無い／壊れている。** 課金まで届かなかった可能性がある。" >> "$OUT"
fi

# ── 指摘の中身（**検索が効いたかはここで分かる**） ──────────
{
  echo "## 出てきた指摘"
  echo ""
  # **柵は 4 本。** レポートの中に ``` が入っているので 3 本だと途中で閉じる
  echo '````markdown'
  if [ -f "$T/refresh-$SLUG.md" ]; then
    head -c 2500 "$T/refresh-$SLUG.md"
  else
    tail -25 "$LOG"
  fi
  echo
  echo '````'
  echo ""
} >> "$OUT"

# ── 作業ツリーを汚していないことを確かめる ──────────────────
DIRTY="$(git status --porcelain --untracked-files=no | grep -c . | head -1)"
case "$DIRTY" in ''|*[!0-9]*) DIRTY=0 ;; esac
{
  echo "---"
  echo ""
  echo "- 作業ツリーの汚れ: **${DIRTY} 件** $([ "$DIRTY" = "0" ] && echo '✅' || echo '❌ **明日の定時が空振りする**')"
  echo "- 定時の状態ファイルは触っていない（書いたのは \`refresh-measure.json\`）"
  echo ""
  echo "> **課金したのはこの 1 回だけ。** 定時実行の既定は変えていない。"
  echo "> 有効化するかは、上の実測値を見てから決める（増額なので承認が要る・ルール 2-B）。"
} >> "$OUT"

# **heartbeat に載るのは末尾 5 行の先頭 300 字だけ。**
# ここに数字を置かないと、一目で見える場所に何も出ない
SUM="rc=$RC"
if [ -f "$MSTATE" ]; then
  SUM="$("$NODE_BIN" -e "
    try{const s=JSON.parse(require('fs').readFileSync('$MSTATE','utf8')).last||{};
      console.log('searches='+(s.searches??'?')+' token_usd='+(s.token_usd??'?')
        +' search_usd='+(s.search_usd??'?')+' total='+(s.cost_usd??'?')
        +' month=~'+((s.cost_usd||0)*30).toFixed(2));
    }catch(e){console.log('state unreadable');}
  " 2>/dev/null || echo 'state unreadable')"
fi
{
  echo ""
  echo "STDOUT_MEASURE rc=$RC ${EL}s $SUM"
} >> "$OUT"

rm -rf "$T"
cat "$OUT"
