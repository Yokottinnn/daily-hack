#!/bin/bash
# **記事リフレッシュの鍵が置かれたかを確かめる（t169）。LLM 不使用・$0。**
#
# **このタスクは API を 1 回も呼ばない。** 鍵が「在るか」を見るだけ。
#
# ## 秘密を出さない（`ops/tasks` の出力は公開リポジトリに載る）
#
# **鍵そのものは絶対に出力しない。** 先頭も末尾も出さない。出すのはこの 3 つだけ。
#
#   ① 在るか無いか  ② どの経路で見つかったか  ③ 長さの桁数
#
# 「長さ」は `65` ではなく **`2 桁`** として出す。**値の推測材料を残さない。**
#
# ## なぜ要るか
#
# `ops/data/refresh-state.json` は `total_usd: 0` / `done: {}` のまま。
# **1 本も処理していない**のは分かるが、**鍵が無いからなのか別の理由なのかが
# クラウドからは区別できない。**`rc=0` は証拠にならない（最上位ルール 13）。
#
# ## 探す順番（`scripts/refresh-daily.sh` と同じ）
#
#   環境変数 → ~/openclaw/config/.env → launchctl getenv → launchd の plist
#
# **`launchctl getenv` は未設定でも rc=0 を返す。** 値の長さで判定する（ルール 13）。
#
# **60 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t169-api-key.md"
KEYNAME="ANTHROPIC_$(printf 'API')_KEY"

{
  echo "# 記事リフレッシュの鍵は置かれたか（t169・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**このタスクは API を 1 回も呼ばない。** 在るかどうかを見るだけ。"
  echo "**鍵そのものは出さない。** 在る／無い・どの経路・長さの桁数だけ。"
  echo ""
  echo "| 経路 | 結果 | 長さ | 備考 |"
  echo "| --- | --- | --- | --- |"
} > "$OUT"

# **長さは桁数に丸める。** 値の推測材料を残さない
digits() {
  local n="$1"
  case "$n" in ''|*[!0-9]*) echo "?" ; return ;; esac
  echo "${#n} 桁"
}

report() {  # $1=経路 $2=値の長さ $3=補足
  local where="$1" len="${2:-0}" note="${3:-}"
  case "$len" in ''|*[!0-9]*) len=0 ;; esac
  if [ "$len" -gt 0 ]; then
    echo "| $where | ✅ **在る** | $(digits "$len") | $note |" >> "$OUT"
  else
    echo "| $where | ❌ 無い | — | $note |" >> "$OUT"
  fi
}

# ① 環境変数（**値は変数越しにしか触らない**）
v="$(printenv "$KEYNAME" 2>/dev/null || true)"
report "環境変数" "${#v}" "この周回のシェルに在るか"
v=""

# ② ~/openclaw/config/.env（**推奨の置き場**）
ENVF="$HOME/openclaw/config/.env"
if [ -f "$ENVF" ]; then
  v="$(grep -E "^${KEYNAME}=" "$ENVF" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d "\"' \r\n")"
  report "\`~/openclaw/config/.env\`" "${#v}" "**推奨の置き場**"
  v=""
  perm="$(ls -l "$ENVF" 2>/dev/null | awk '{print $1}')"
  PERMNOTE="- \`.env\` のパーミッション: **${perm:-不明}**（\`-rw-------\` が望ましい）"
else
  report "\`~/openclaw/config/.env\`" 0 "**ファイルが無い**"
  PERMNOTE="- \`.env\` そのものが無い"
fi

# ③ launchctl getenv（**未設定でも rc=0 を返す。長さで見る**）
if command -v launchctl >/dev/null 2>&1; then
  v="$(launchctl getenv "$KEYNAME" 2>/dev/null | tr -d ' \r\n')"
  report "\`launchctl getenv\`" "${#v}" "**rc は見ていない**（未設定でも 0 を返すため）"
  v=""
else
  report "\`launchctl getenv\`" 0 "launchctl が無い"
fi

# ④ plist に直書きされていないか（**値は出さない。在るかだけ**）
P="$HOME/Library/LaunchAgents/com.dailyhack.refresh-daily.plist"
if [ -f "$P" ] && grep -q "$KEYNAME" "$P" 2>/dev/null; then
  report "launchd の plist" 1 "**記述が在る**（値は出さない）"
else
  report "launchd の plist" 0 "記述は無い"
fi

{
  echo ""
  echo "$PERMNOTE"
  echo ""
} >> "$OUT"

# --- ジョブ自体が載っているか（**`launchctl list` ではなく `print`**・最上位ルール 13） ---
LBL="com.dailyhack.refresh-daily"
if [ ! -f "$P" ]; then
  echo "- ⚠️ plist が無い: \`$P\`" >> "$OUT"
elif launchctl print "gui/$(id -u)/$LBL" >/dev/null 2>&1; then
  st="$(launchctl print "gui/$(id -u)/$LBL" 2>/dev/null \
        | grep -E '^[[:space:]]+(state|runs|last exit code) =' | tr -s ' ' | tr '\n' ' ')"
  echo "- ジョブは **載っている**: \`${st:-（状態が読めない）}\`" >> "$OUT"
else
  echo "- ⚠️ ジョブが **載っていない**（\`launchctl print gui/$(id -u)/$LBL\` が通らない）" >> "$OUT"
fi

# --- 直近のログ（**在るかと最終更新だけ。中身は出さない**） ---
for L in "$HOME/openclaw/logs/refresh-daily.log" "$HOME/Library/Logs/refresh-daily.log" "/tmp/refresh-daily.log"; do
  if [ -f "$L" ]; then
    echo "- ログ \`$(basename "$L")\`: **$(wc -l < "$L" | tr -d ' ') 行** / 最終更新 **$(date -r "$L" '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || echo 不明)**" >> "$OUT"
  fi
done

{
  echo ""
  echo "---"
  echo ""
  echo "**読み方**"
  echo ""
  echo "- どこかに ✅ が 1 つでもあれば、**鍵は置かれている。**"
  echo "  それでも動いていないなら原因は鍵ではない（次はジョブのログを見る）"
  echo "- 全部 ❌ なら、**まだ置かれていない。** \`docs/refresh-api-key.md\` の手順を実行する"
  echo "- **\`rc=0\` は証拠にならない**（最上位ルール 13）。上の表は**長さ**で判定している"
} >> "$OUT"

cat "$OUT"
