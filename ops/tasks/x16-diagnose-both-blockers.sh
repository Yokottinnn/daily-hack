#!/bin/bash
# **2 つの詰まりを、実物を見て切り分ける。費用 $0。**
#
# ## 詰まり ①: 返信が「no candidates」で 9 回 連続 空振り
#
#   [23:43:42] === comment orchestrator start (max_picks=4, reply_follow_cap=10) ===
#   [23:46:43] no candidates
#
# **9 回とも同じ。** 生成器の配線も 1 回の件数も直したが、
# **詰まっているのはその手前**で、設定を 4 にしても拾う候補が 0 なら 0 のまま。
#
# 候補は複数段を通る。**どの段で 0 になるのかを、段ごとに数える。**
#
#   trend-detect.js  →  ng-filter-candidates.cjs  →  cooldown/既返信の除外  →  asuka-reply.cjs
#
# ## 詰まり ②: アンフォローが `Cannot find module 'playwright'`
#
#   Error: Cannot find module 'playwright'
#   Require stack: /Users/ny/.openclaw/workspace/scripts/.x13-fresh-unfollow.js
#   Node.js v24.14.0
#
# **`/usr/local/bin/node` に固定しても同じだった。** v24 にも playwright は無い。
# 「node のバージョン違いが原因」という診断は**外れ**。
#
# **稼働中のスクリプトがどう解決しているのかを、推測せずに実物で見る。**
#
# ## やらないこと
#
# **投稿しない。返信しない。アンフォローしない。フォローしない。**
# **ジョブを触らない。ファイルを書き換えない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/diagnose-both-blockers.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 2 つの詰まりを実物で切り分ける"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **推測を書かない。** 実際の出力だけを載せる。"
echo "> 何も変更していない。LLM も呼んでいない（\$0）。"

# ────────────────────────────────────────────────────────────
echo
echo "## ① 返信: どの段で候補が 0 になるのか"
echo

echo "### 1-a. \`comment-orchestrator.sh\` の候補取得まわり"
echo
echo '```bash'
grep -nE 'trend-detect|ng-filter|no candidates|CANDS|PICK|candidates=|MAX_PICKS' "$S/comment-orchestrator.sh" 2>/dev/null \
  | head -40 | clean
echo '```'

echo
echo "### 1-b. \`trend-detect.js\` を単体で走らせて、生の件数を見る"
echo
echo "**これは検知だけ。投稿もしないし LLM も呼ばない。**"
echo
echo '```'
if [ -f "$S/trend-detect.js" ]; then
  # macOS に timeout は無い。**自前で 120 秒で切る**（ポーラーを詰まらせない）
  TD_LOG="$(mktemp)"
  ( cd "$W" && /usr/local/bin/node "$S/trend-detect.js" >"$TD_LOG" 2>&1 ) &
  TD_PID=$!
  for _ in $(seq 1 120); do kill -0 "$TD_PID" 2>/dev/null || break; sleep 1; done
  if kill -0 "$TD_PID" 2>/dev/null; then
    kill -9 "$TD_PID" 2>/dev/null
    echo "  **120 秒で切った（ハングしている）**"
  fi
  wait "$TD_PID" 2>/dev/null; TD_RC=$?
  tail -40 "$TD_LOG" | clean
  echo "(rc=$TD_RC)"
  rm -f "$TD_LOG"
else
  echo "  **trend-detect.js が無い**"
  ls -1 "$S" 2>/dev/null | grep -iE 'trend|detect|candidate' | sed 's/^/  候補: /'
fi
echo '```'

echo
echo "### 1-c. 検知の出力ファイルは何件 入っているか"
echo
echo '```'
for f in "$W"/data/trend-candidates.json "$W"/data/candidates.json \
         "$W"/data/trends.json "$W"/data/comment-candidates.json; do
  [ -f "$f" ] || continue
  echo "  [$(basename "$f")]  更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)  $(wc -c < "$f" | tr -d ' ') B"
  /usr/local/bin/node -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const arr=Array.isArray(d)?d:(d.candidates||d.items||d.trends||d.queue||[]);
  console.log("    件数: "+(Array.isArray(arr)?arr.length:"(配列でない)"));
  if(Array.isArray(arr)&&arr.length){
    console.log("    先頭: "+JSON.stringify(arr[0]).slice(0,200));
  }
}catch(e){ console.log("    読めない: "+e.message.slice(0,80)); }
' "$f" 2>&1
done
echo '```'

echo
echo "### 1-d. \`comment-warmup.log\` の今日と昨日の \`no candidates\` の出方"
echo
echo "**いつから 0 件 続きなのか。**"
echo
echo '```'
L="$W/logs/comment-warmup.log"
if [ -f "$L" ]; then
  echo "  日付ごとの no candidates 回数（直近 10 日）:"
  grep -oE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}' "$L" 2>/dev/null | tr -d '[' | sort -u | tail -10 | while read -r d; do
    nc=$(grep -c "^\[$d.*no candidates" "$L" 2>/dev/null || echo 0)
    st=$(grep -c "^\[$d.*orchestrator start" "$L" 2>/dev/null || echo 0)
    printf '    %s  起動 %-3s 回 / no candidates %-3s 回\n' "$d" "$st" "$nc"
  done
  echo
  echo "  直近 30 行:"
  tail -30 "$L" | sed 's/^/    /' | clean
else
  echo "  **ログが無い: $L**"
fi
echo '```'

echo
echo "### 1-e. 検知の取得元（何を見に行っているか）"
echo
echo '```javascript'
if [ -f "$S/trend-detect.js" ]; then
  grep -nE 'http|url|search|query|hashtag|goto|selector|list|\.json' "$S/trend-detect.js" 2>/dev/null \
    | head -30 | clean
else
  echo "  ファイルが無い"
fi
echo '```'

# ────────────────────────────────────────────────────────────
echo
echo "## ② アンフォロー: playwright はどこにあるのか"
echo
echo "**「node のバージョン違い」は外れだった。** 実物で探す。"

echo
echo "### 2-a. node は何本 あるか"
echo
echo '```'
for n in /usr/local/bin/node /opt/homebrew/bin/node "$(command -v node 2>/dev/null)"; do
  [ -x "$n" ] || continue
  printf '  %-32s %s\n' "$n" "$("$n" -v 2>/dev/null)"
done
echo "  command -v node → $(command -v node 2>/dev/null || echo '(無い)')"
echo "  NODE_PATH       → ${NODE_PATH:-(未設定)}"
echo '```'

echo
echo "### 2-b. playwright の実体を探す"
echo
echo '```'
for d in "$W/node_modules/playwright" "$S/node_modules/playwright" \
         "$HOME/node_modules/playwright" \
         /usr/local/lib/node_modules/playwright \
         /opt/homebrew/lib/node_modules/playwright \
         "$W/node_modules/playwright-core" "$W/node_modules/puppeteer" \
         "$W/node_modules/puppeteer-core"; do
  if [ -e "$d" ]; then echo "  **有る** $d"; else echo "  無い   $d"; fi
done
echo
echo "  --- find（深さ 4 まで・playwright / puppeteer のディレクトリ） ---"
find "$W" "$HOME/.npm-global" /usr/local/lib/node_modules /opt/homebrew/lib/node_modules \
  -maxdepth 4 -type d \( -name 'playwright' -o -name 'playwright-core' -o -name 'puppeteer*' \) \
  2>/dev/null | head -20 | sed 's/^/  /'
echo '```'

echo
echo "### 2-c. **稼働中のスクリプトは何を require しているか**"
echo
echo "\`post-via-playwright.js\` は実際に投稿を成功させている。**その 1 行目が答え。**"
echo
echo '```javascript'
for f in "$S/post-via-playwright.js" "$S/unfollow-handle.js" "$S/post-comment.js"; do
  [ -f "$f" ] || { echo "  // $(basename "$f") は無い"; continue; }
  echo "  // ===== $(basename "$f") ====="
  grep -nE "require\(|import .* from|chromium|connectOverCDP" "$f" 2>/dev/null | head -8 | sed 's/^/  /' | clean
done
echo '```'

echo
echo "### 2-d. 実際に require できるか（3 通り 試す）"
echo
echo '```'
for base in "$W" "$S" "$HOME"; do
  printf '  cwd=%-46s → ' "$base"
  ( cd "$base" 2>/dev/null && /usr/local/bin/node -e \
    'try{console.log("OK "+require.resolve("playwright"))}catch(e){console.log("NG "+e.code)}' 2>&1 ) | tail -1
done
printf '  %-52s → ' "NODE_PATH を workspace に向けた場合"
NODE_PATH="$W/node_modules" /usr/local/bin/node -e \
  'try{console.log("OK "+require.resolve("playwright"))}catch(e){console.log("NG "+e.code)}' 2>&1 | tail -1
printf '  %-52s → ' "playwright-core で試す"
( cd "$S" 2>/dev/null && /usr/local/bin/node -e \
  'try{console.log("OK "+require.resolve("playwright-core"))}catch(e){console.log("NG "+e.code)}' 2>&1 ) | tail -1
echo '```'

echo
echo "### 2-e. 稼働ジョブの plist が環境変数を渡していないか"
echo
echo '```'
P="$HOME/Library/LaunchAgents/ai.openclaw.reply-followers-cleanup.plist"
if [ -f "$P" ]; then
  plutil -p "$P" 2>/dev/null | grep -iE 'NODE_PATH|PATH|WorkingDirectory|Program' | head -12 | sed 's/^/  /'
else
  echo "  plist が無い: $P"
fi
echo '```'

echo
echo "---"
echo
echo "**何も変更していない。投稿・返信・アンフォロー・フォローのいずれもしていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
PW="$(grep -m1 -E '^  cwd=.*OK ' "$OUT" 2>/dev/null | sed 's/^ *//' | cut -c1-60 || echo 'playwright は 3 通りとも NG')"
echo "**$(date '+%H:%M') 診断のみ・\$0** / $PW / $(basename "$OUT")"
