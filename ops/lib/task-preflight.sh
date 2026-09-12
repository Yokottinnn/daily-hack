# ops/tasks の先頭で読み込む自己検査。**Mac に無いものを推測で使わないための雛形。**
#
#   source ができないので、タスクの中にこの内容を貼るか、
#   必要な関数だけ写して使う（ops/tasks はリポジトリから `git show` で
#   取り出して単体で走るため、他のファイルを読めない）。
#
# ## なぜ在るか（2026-09-13 に 2 回 転んだ）
#
# クラウドは Linux、実行先は macOS。「ローカルで検証した」が Mac で動かないことが
# 1 日で 2 回 起きた。
#
#   timeout: command not found                  ← 番人が初回実行に失敗
#   ERR_UNKNOWN_FILE_EXTENSION: Unknown ".new"  ← mutual-prune.js が未設置
#
# **どちらも黙って壊れた。** 使えるものの一覧は `docs/mac-environment.md`。
# CLAUDE.md 最上位ルール 14 も参照。

# ─────────────────────────────────────────────────────────────
# 1. 前提チェック。**無ければ理由を書いて止まる。当て推量で進めない。**
# ─────────────────────────────────────────────────────────────
#
#   need_cmd node plutil launchctl || exit 1
need_cmd() {
  local miss="" c
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || miss="$miss $c"; done
  if [ -n "$miss" ]; then
    echo "**前提が無い:$miss** — 代替に切り替えるか、ここで止まる（docs/mac-environment.md）" >&2
    return 1
  fi
  return 0
}

# ─────────────────────────────────────────────────────────────
# 2. `timeout` を使わない打ち切り
# ─────────────────────────────────────────────────────────────
#
# **`timeout` は macOS に無い。** `gtimeout` も入っていない。
#
# **プロセスグループ指定（`kill -TERM -$pid`）は使わない。**
# 子がグループリーダーでなければ、**呼び出し側のグループごと落ちる。**
# 2026-09-13 の検証でテスト用シェルが実際に死んだ（exit 144）。
#
# **落とす前に子孫の PID を控える。** TERM を撃つと孫は親を失って付け替わり、
# KILL の時点ではもう辿れない。実際に `sleep` が 1 件 生き残った。

descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}

# run_limited <秒> <出力先ファイル> <コマンド...>
#   戻り値: コマンドの rc。打ち切ったときは 124
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
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

# ─────────────────────────────────────────────────────────────
# 3. JS を安全に置き換える
# ─────────────────────────────────────────────────────────────
#
# **一時ファイルの拡張子を変えない。** `node --check foo.js.new` は
# `ERR_UNKNOWN_FILE_EXTENSION` で弾かれる（Mac の Node v24）。
# 隠しファイル名にして `.js` を保つ。
#
#   install_js "$S/mutual-prune.js" <<'EOF'
#   ...中身...
#   EOF
install_js() {
  local dest="$1"
  local dir; dir="$(dirname "$dest")"
  local base; base="$(basename "$dest")"
  local tmp="$dir/.${base%.js}-install.js"     # **`.js` のまま**
  local node_bin="${NODE_BIN:-/usr/local/bin/node}"
  cat > "$tmp"
  if ! "$node_bin" --check "$tmp" 2>/dev/null; then
    echo "**構文エラー。置かない。**" >&2
    "$node_bin" --check "$tmp" 2>&1 | head -5 >&2
    rm -f "$tmp"; return 1
  fi
  [ -f "$dest" ] && cp "$dest" "$dest.bak-$(date '+%Y%m%d-%H%M%S')"
  mv "$tmp" "$dest" && chmod +x "$dest"
  return 0
}

# ─────────────────────────────────────────────────────────────
# 4. 「載った」を rc で判定しない（最上位ルール 13）
# ─────────────────────────────────────────────────────────────
#
# **`launchctl list` に出るかだけが証拠。**
# スナップショットを 1 回だけ取り、3 列目のラベル完全一致で見る。
# ジョブごとに `launchctl list` を呼び直すと取りこぼし、
# **載っているのに「未ロード」と誤判定する**（2026-09-13 に 4 日 間 誤報した）。

lc_snapshot() {
  local s
  s="$(launchctl list 2>/dev/null | awk '{print $3}')"
  [ -z "$s" ] && { sleep 2; s="$(launchctl list 2>/dev/null | awk '{print $3}')"; }
  printf '%s\n' "$s"
}

lc_loaded() {  # lc_loaded "<スナップショット>" <ラベル>
  printf '%s\n' "$1" | grep -qxF "$2"
}

# ─────────────────────────────────────────────────────────────
# 5. 出力を公開リポジトリに載せる前の掃除
# ─────────────────────────────────────────────────────────────
#
# `ops/tasks` の出力は**公開リポジトリに載る。** 秘密を出さない。

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(AKIA|ghp_|xoxb-)[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
