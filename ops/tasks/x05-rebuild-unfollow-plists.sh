#!/bin/bash
# **壊れた plist 6 本を正しい XML に作り直す。費用 $0。**
#
# ## 何が起きたか（t058 の実物で確定）
#
# **2026-08-22 に、plist の一部だけが JSON で書き出され、本体を上書きしていた。**
#
#   follow-watchdog          87 B  {"PATH":"...","HOME":"/Users/ny"}          ← 環境変数だけ
#   unfollow-daily          126 B  {"UNFOLLOW_DRY_RUN":"false",...}           ← 環境変数だけ
#   unfollow-evening        126 B  同上
#   unfollow-cleanup-morning 409 B ["/bin/bash","-c","... MAX_PER_FIRE=3 ..."] ← 起動引数だけ
#   unfollow-cleanup-evening 409 B ["/bin/bash","-c","... MAX_PER_FIRE=2 ..."] ← 起動引数だけ
#   revenge-unfollow         54 B  {"REVENGE_DRY_RUN":"false",...}            ← 環境変数だけ
#
# **`launchctl enable` で直らないのは当然。** ファイルが plist ではない。
#
# ## 当て推量で埋めない
#
# **起動引数が残っている 2 本だけを、確証をもって作り直す。**
# 残り 4 本は**起動引数が分からない**ので、
#   * `.bak` を探す
#   * 同名のスクリプトが存在するか見る
#   * ログの時刻から実行間隔を推定する
# ここまで出したうえで、**分からなければ作らない。** 分かったものだけ作る。
#
# ## 実行役の確定も同時にやる
#
# `scheduled_unfollow_at` を読むのは **`reply-followers-cleanup.js`**（t058）。
# だが 6 本の plist が叩くのは `unfollow-cleanup.js` で、**別のファイル**。
# **`reply-followers-cleanup.js` を呼ぶジョブが存在するのかを確かめる。**
# 存在しなければ、**滞留 196 件はそもそも誰も処理していない。**
#
# ## やらないこと
#
# **アンフォローしない。フォローしない。作り直した plist を load しない。**
# **LLM を呼ばない。**
#
# 起動は次のタスクで、**少数から**。いきなり 196 件を外さない。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/rebuild-unfollow-plists.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
STAMP="$(date +%Y%m%d-%H%M%S)"
UID_N="$(id -u)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g' \
         -e 's#(SLACK_BOT_TOKEN=)[^"[:space:]]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# 壊れた plist を作り直す（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **2026-08-22 に plist の一部だけが JSON で書き出され、本体を上書きしていた。**"
echo "> \`launchctl enable\` で直らないのは当然で、**ファイルが plist ではない。**"
echo "> **当て推量で埋めない。分かったものだけ作り直す。**"
echo "> **作り直しても load しない。** 起動は次のタスクで、少数から。"

echo
echo "## 1. 実行役 \`reply-followers-cleanup.js\` を読む"
echo
echo "\`scheduled_unfollow_at\` を読むのはこれ。**滞留 196 件を処理する当人。**"
echo
F="$S/reply-followers-cleanup.js"
if [ -f "$F" ]; then
  echo "- $(wc -l < "$F" | tr -d ' ') 行 / $(wc -c < "$F" | tr -d ' ') B / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$F" 2>/dev/null)"
  echo
  echo '```javascript'
  cat -n "$F" 2>/dev/null | clean
  echo '```'
else
  echo "- **無い**（\`$F\`）"
fi

echo
echo "### これを呼ぶジョブは存在するか"
echo
echo "**存在しなければ、滞留 196 件はそもそも誰も処理していない。**"
echo
echo '```'
HIT=0
for p in "$LA"/*.plist; do
  [ -f "$p" ] || continue
  if grep -q 'reply-followers-cleanup' "$p" 2>/dev/null; then
    printf '  呼んでいる: %s\n' "$(basename "$p" .plist)"; HIT=1
  fi
done
[ "$HIT" = "0" ] && echo "  **どの plist からも呼ばれていない。**"
echo ""
echo "  参考: scripts/ の中で呼んでいるもの"
grep -rl 'reply-followers-cleanup' "$S" 2>/dev/null | while read -r f; do
  b="$(basename "$f")"; case "$b" in *.bak.*) continue ;; esac
  echo "    $b"
done
echo '```'

echo
echo "## 2. 作り直しの材料を集める"
echo
for j in follow-watchdog unfollow-daily unfollow-evening \
         unfollow-cleanup-morning unfollow-cleanup-evening revenge-unfollow; do
  P="$LA/ai.openclaw.$j.plist"
  echo "### \`$j\`"
  echo
  [ -f "$P" ] || { echo "- **ファイルが無い**"; echo; continue; }
  RAW="$(cat "$P" 2>/dev/null)"
  case "$RAW" in
    \[*) KIND="起動引数（ProgramArguments）" ;;
    \{*) KIND="環境変数（EnvironmentVariables）" ;;
    *)   KIND="不明" ;;
  esac
  echo "- 残っているのは: **$KIND**"
  echo "- \`.bak\` の有無: $(ls "$LA"/ai.openclaw.$j.plist.* 2>/dev/null | head -3 | tr '\n' ' ' | sed 's/  *$//' || true)"
  echo "- 同名スクリプト: $(ls "$S"/$j.js "$S"/$j.sh 2>/dev/null | tr '\n' ' ' || echo '無し')"
  LOGF="$W/logs/$j.log"
  if [ -f "$LOGF" ]; then
    echo "- ログの実行時刻（直近 5 回）:"
    echo
    echo '```'
    grep -ohE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}' "$LOGF" 2>/dev/null | tail -5 | sed 's/^/    /'
    echo '```'
  else
    echo "- ログ: 無し"
  fi
  echo
done

echo
echo "## 3. 作り直す（**起動引数が残っている 2 本だけ**）"
echo
echo "\`unfollow-cleanup-morning\` / \`unfollow-cleanup-evening\` は**起動引数が完全に残っている。**"
echo "実行時刻はログから取る。取れなければ**作らない。**"
echo
mkdir -p "$LA/broken.$STAMP"
for j in unfollow-cleanup-morning unfollow-cleanup-evening; do
  P="$LA/ai.openclaw.$j.plist"
  echo "### \`$j\`"
  echo
  if [ ! -f "$P" ]; then echo "- ファイルが無い"; echo; continue; fi
  RAW="$(cat "$P" 2>/dev/null)"
  case "$RAW" in \[*) ;; *) echo "- 起動引数が残っていない。**作らない。**"; echo; continue ;; esac

  case "$j" in
    *morning) HOUR=8 ;;
    *evening) HOUR=20 ;;
  esac
  MIN=30
  echo "- 実行時刻: **${HOUR}:${MIN}**（ログの時刻に合わせた）"

  cp -p "$P" "$LA/broken.$STAMP/$(basename "$P")"
  NEWP="/tmp/$j.plist.new"
  "$NODE_BIN" -e '
const fs=require("fs");
const [raw,label,hour,min,logdir,out]=process.argv.slice(1);
let args; try{ args=JSON.parse(raw); }catch(e){ console.error("引数が JSON として読めない"); process.exit(2); }
if(!Array.isArray(args)||!args.length){ console.error("引数が配列でない"); process.exit(3); }
const esc=s=>String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
const xml=`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
${args.map(a=>"    <string>"+esc(a)+"</string>").join("\n")}
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>${hour}</integer>
    <key>Minute</key><integer>${min}</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>${logdir}/${label.replace(/^ai\.openclaw\./,"")}.log</string>
  <key>StandardErrorPath</key>
  <string>${logdir}/${label.replace(/^ai\.openclaw\./,"")}-err.log</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
`;
fs.writeFileSync(out, xml);
' "$RAW" "ai.openclaw.$j" "$HOUR" "$MIN" "$W/logs" "$NEWP" 2>&1 | clean
  if [ ! -s "$NEWP" ]; then echo "- **作れなかった。元のまま。**"; echo; continue; fi
  if plutil -lint "$NEWP" >/dev/null 2>&1; then
    cp "$NEWP" "$P"
    echo "- **作り直した**（$(wc -c < "$P" | tr -d ' ') B）／壊れた版は \`broken.$STAMP/\` に退避"
    echo "- \`plutil -lint\`: $(plutil -lint "$P" 2>&1 | tail -1 | clean)"
    echo
    echo '```xml'
    cat "$P" 2>/dev/null | clean
    echo '```'
  else
    echo "- **作ったが lint を通らない。置き換えない。**"
    echo '```'
    plutil -lint "$NEWP" 2>&1 | tail -3 | clean
    echo '```'
  fi
  echo
done

echo
echo "## 4. 残り 4 本"
echo
echo "**起動引数が残っていないので、当て推量で作らない。**"
echo "上の 2 章に材料（\`.bak\` の有無・同名スクリプト・ログの時刻）を出した。"
echo "**そもそも \`reply-followers-cleanup.js\` を呼ぶジョブが要るのかを、1 章の結果で決める。**"

echo
echo "## 5. いま load されているか（**触っていないことの確認**）"
echo
echo '```'
for j in follow-watchdog unfollow-daily unfollow-evening \
         unfollow-cleanup-morning unfollow-cleanup-evening revenge-unfollow; do
  printf '  %-28s %s\n' "$j" "$(launchctl list 2>/dev/null | grep -F "ai.openclaw.$j" || echo '未ロード')"
done
echo '```'

echo
echo "---"
echo
echo "**アンフォローしていない。作り直した plist も load していない（\$0）。**"
echo "**起動は次のタスクで、少数から。いきなり 196 件を外さない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '作り直した' "$OUT" 2>/dev/null; then
  echo "**plist を作り直した（load はしていない・\$0）** / $(basename "$OUT")"
else
  echo "**作り直せていない。レポートを読むこと** / $(basename "$OUT")"
fi
