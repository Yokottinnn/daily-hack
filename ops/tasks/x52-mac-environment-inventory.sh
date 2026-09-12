#!/bin/bash
# **Mac で何が使えるかを 1 回 棚卸しして、リポジトリに残す。費用 $0（LLM 不使用）。**
#
# ## なぜ必要か（2026-09-13 に 2 回 転んだ）
#
# クラウドセッションは **Linux**、実行先は **macOS**。別物である。
# 「ローカルで検証した」と書いたものが Mac で動かないことが 1 日で 2 回 起きた。
#
#   timeout: command not found                          ← 番人が初回実行に失敗
#   ERR_UNKNOWN_FILE_EXTENSION: Unknown ".new"          ← mutual-prune.js が未設置
#
# **どちらも黙って壊れた。** レポートを読むまで気づけなかった。
#
# **推測の元を絶つ。** 使えるものを実測して `docs/mac-environment.md` に残す。
# 以後、タスクを書く前にそれを読む（CLAUDE.md 最上位ルール 14）。
#
# ## このタスクは何も変更しない
#
# **読むだけ。** ジョブを触らない。ファイルを書き換えない。Chrome を触らない。
# LLM を呼ばない（**$0**）。
#
# 出力は公開リポジトリに載るので、**環境変数の値は出さない。名前だけ出す。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/mac-environment.md"

secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(AKIA|ghp_|xoxb-)[A-Za-z0-9_-]+#\1<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide | secrets; }

have() { command -v "$1" >/dev/null 2>&1 && echo "在る（$(command -v "$1")）" || echo "**無い**"; }

{
echo "# Mac で使えるもの（実測）"
echo
echo "**この一覧は \`ops/tasks/x52-mac-environment-inventory.sh\` が実測したもの。**"
echo "**推測で書かない。** タスクを書く前にここを読む（CLAUDE.md 最上位ルール 14）。"
echo
echo "測った時刻: **$(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "## 0. 素性"
echo
echo '```'
echo "  OS       : $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
echo "  arch     : $(uname -m 2>/dev/null)"
echo "  shell    : $SHELL"
echo "  bash     : $(/bin/bash --version 2>/dev/null | head -1)"
echo "  ホーム   : $HOME"
echo "  ワークスペース: $W $( [ -d "$W" ] && echo '（在る）' || echo '（**無い**）')"
echo '```'

echo
echo "## 1. コマンドの有無（**ここで転んだ**）"
echo
echo "| コマンド | 状態 | 備考 |"
echo "| --- | --- | --- |"
printf '| `timeout` | %s | **無ければ素の bash で打ち切る** |\n' "$(have timeout)"
printf '| `gtimeout` | %s | coreutils を入れていれば在る |\n' "$(have gtimeout)"
printf '| `gnu-sed / gsed` | %s | macOS の `sed -i` は `-i ""` が要る |\n' "$(have gsed)"
printf '| `pkill` | %s | |\n' "$(have pkill)"
printf '| `pgrep` | %s | |\n' "$(have pgrep)"
printf '| `plutil` | %s | plist の検証に使う |\n' "$(have plutil)"
printf '| `PlistBuddy` | %s | |\n' "$( [ -x /usr/libexec/PlistBuddy ] && echo '在る（/usr/libexec/PlistBuddy）' || echo '**無い**')"
printf '| `launchctl` | %s | |\n' "$(have launchctl)"
printf '| `caffeinate` | %s | スリープ抑止。**sudo 不要** |\n' "$(have caffeinate)"
printf '| `pmset` | %s | **変更には sudo が要る** |\n' "$(have pmset)"
printf '| `jq` | %s | 無ければ node で JSON を扱う |\n' "$(have jq)"
printf '| `curl` | %s | |\n' "$(have curl)"
printf '| `git` | %s | |\n' "$(have git)"
printf '| `tmux` | %s | |\n' "$(have tmux)"
printf '| `python3` | %s | |\n' "$(have python3)"
printf '| `perl` | %s | |\n' "$(have perl)"
printf '| `flock` | %s | 無ければ mkdir でロックする |\n' "$(have flock)"

echo
echo "## 2. node"
echo
echo '```'
for n in /usr/local/bin/node /opt/homebrew/bin/node "$(command -v node 2>/dev/null)"; do
  [ -n "$n" ] && [ -x "$n" ] && printf '  %-28s %s\n' "$n" "$("$n" --version 2>/dev/null)"
done
echo
echo "  --- node --check は拡張子を見るか（**ここで転んだ**） ---"
T="${TMPDIR:-/tmp}/envcheck.$$"
printf 'const a=1;\n' > "$T.js"
printf 'const a=1;\n' > "$T.js.new"
for f in "$T.js" "$T.js.new"; do
  if /usr/local/bin/node --check "$f" >/dev/null 2>&1; then
    printf '    %-12s 通る\n' "$(basename "$f" | sed 's/^[^.]*//')"
  else
    printf '    %-12s **弾く**\n' "$(basename "$f" | sed 's/^[^.]*//')"
  fi
done
rm -f "$T.js" "$T.js.new"
echo '```'

echo
echo "## 3. ワークスペースの node_modules（**推測しない**）"
echo
echo '```'
if [ -d "$W/node_modules" ]; then
  echo "  --- playwright 系 ---"
  ls -1 "$W/node_modules" 2>/dev/null | grep -i playwright | sed 's/^/    /' || echo "    無し"
  echo
  echo "  --- 主要なもの（先頭 25 件） ---"
  ls -1 "$W/node_modules" 2>/dev/null | grep -v '^\.' | head -25 | sed 's/^/    /'
  echo
  echo "  合計: $(ls -1 "$W/node_modules" 2>/dev/null | wc -l | tr -d ' ') 件"
else
  echo "  **$W/node_modules が無い**"
fi
echo '```'

echo
echo "## 4. 稼働中スクリプトが実際に読んでいるパッケージ"
echo
echo "**\`require\` 行を読む。** 2026-09-12 に \`playwright\` と書いて 4 回 連続で落とした。"
echo
echo '```'
for f in post-via-playwright.js unfollow-handle.js post-comment.js mutual-prune.js \
         cdp-health.js trend-detect.js asuka-reply.cjs; do
  P="$S/$f"
  [ -f "$P" ] || { printf '  %-26s **無い**\n' "$f"; continue; }
  R="$(grep -m2 -oE "require\([\"'][^\"']+[\"']\)" "$P" 2>/dev/null | tr '\n' ' ')"
  printf '  %-26s %s\n' "$f" "${R:-（require 無し）}"
done
echo '```'

echo
echo "## 5. 日付・ファイル情報の方言（**Linux と違う**）"
echo
echo '```'
echo "  stat -f '%Sm'  : $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$HOME" 2>/dev/null || echo '**使えない**')"
echo "  stat -c '%y'   : $(stat -c '%y' "$HOME" 2>/dev/null || echo '**使えない（macOS はこちら）**')"
echo "  date -v-1d     : $(date -v-1d '+%Y-%m-%d' 2>/dev/null || echo '**使えない**')"
echo "  date -d '1 day ago': $(date -d '1 day ago' '+%Y-%m-%d' 2>/dev/null || echo '**使えない（macOS はこちら）**')"
echo "  TZ=Asia/Tokyo  : $(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S')"
echo "  grep -P        : $(echo x | grep -qP 'x' 2>/dev/null && echo '使える' || echo '**使えない**')"
echo "  sed -i（引数なし）: $(t="${TMPDIR:-/tmp}/sedt.$$"; echo a > "$t"; if sed -i 's/a/b/' "$t" 2>/dev/null; then echo '使える'; else echo '**使えない（-i "" が要る）**'; fi; rm -f "$t" "$t"'' 2>/dev/null)"
echo '```'

echo
echo "## 6. PATH（launchd から走るときは最小限になる）"
echo
echo '```'
echo "  いまの PATH: $PATH"
echo
echo "  **plist では明示すること:**"
echo "    /usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
echo '```'

echo
echo "## 7. 環境変数の**名前だけ**（値は出さない）"
echo
echo "公開リポジトリに載るため、**値は絶対に出さない。**"
echo
echo '```'
env 2>/dev/null | sed -E 's/=.*$//' | sort | grep -iE 'key|token|secret|password|auth' \
  | head -12 | sed 's/^/    （秘密らしきもの）/' | clean
echo "    ---"
env 2>/dev/null | sed -E 's/=.*$//' | sort | grep -ivE 'key|token|secret|password|auth' \
  | head -25 | sed 's/^/    /' | clean
echo '```'

echo
echo "## 8. ディスクとメモリ"
echo
echo '```'
df -h / "$HOME" 2>/dev/null | head -3 | sed 's/^/  /'
echo
echo "  ロードアベレージ: $(uptime 2>/dev/null | sed 's/.*load averages*://')"
echo '```'

echo
echo "## 使い方"
echo
echo "**タスクを書く前にこの一覧を読む。** 載っていないものを使うなら、"
echo "タスクの先頭で \`command -v\` を確かめ、**無ければ代替に切り替えるか、理由を書いて止まる。**"
echo
echo "この一覧が古くなったら、\`x52\` と同じ内容のタスクを番号を変えて置けば取り直せる。"
} > "$OUT" 2>&1

echo "Mac 環境の棚卸し / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
