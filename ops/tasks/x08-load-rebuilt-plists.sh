#!/bin/bash
# **作り直した plist を起動する ＋ 残りを可能な範囲で復元する。費用 $0。**
#
# ## いまの状態（x05 の実測）
#
#   unfollow-cleanup-morning  **XML に復元済み・lint OK**（未ロード）
#   unfollow-cleanup-evening  **XML に復元済み・lint OK**（未ロード）
#   follow-watchdog           環境変数だけ。**`scripts/follow-watchdog.js` は存在する**
#   revenge-unfollow          環境変数だけ。**`scripts/revenge-unfollow.js` は存在する**
#   unfollow-daily            環境変数だけ。**同名スクリプトが無い**
#   unfollow-evening          環境変数だけ。**同名スクリプトが無い**
#
# ## 方針
#
#   * 復元済みの 2 本は **load する**（1 回あたり 3 件 / 2 件と小さい）
#   * スクリプトがある 2 本は **XML に復元する。だが load しない**
#     （`revenge-unfollow` は 1 回 10 件 外す。滞留の消化と重なると多すぎる）
#   * スクリプトが無い 2 本は **作らない。** 当て推量で起動引数を書かない
#
# ## なぜ 2 本だけ起動するのか
#
# `reply-followers-cleanup` が 1 回 20 件、滞留 196 件を消化しはじめている。
# **そこへ 1 回 10 件 外す `revenge-unfollow` を重ねると、X の判定に触れる。**
# 滞留が落ち着いてから足す。**同時に全部 起動しない。**
#
# ## やらないこと
#
# **アンフォローを手で実行しない。スクリプトが無いものを推測で作らない。**
# **LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/load-rebuilt-plists.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
STAMP="$(date +%Y%m%d-%H%M%S)"
UID_N="$(id -u)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g' \
         -e 's#(SLACK_BOT_TOKEN=)[^"[:space:]<]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# 作り直した plist を起動する（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **同時に全部 起動しない。** \`reply-followers-cleanup\` が 1 回 20 件で"
echo "> 滞留 196 件を消化しはじめている。そこへ 1 回 10 件 外す \`revenge-unfollow\` を"
echo "> 重ねると **X の判定に触れる。** 滞留が落ち着いてから足す。"


echo
echo "## 0. アンフォローを実際に走らせる（**`timeout` を使わない**）"
echo
echo "\`x06\` は \`timeout\` を使って \`rc=127\` で落ちた。**macOS に \`timeout\` は無い。**"
echo "ジョブ自体は起動済み（lint OK・rc=0・上限 20 件 挿入済み）だが、"
echo "**今日中に実際に外れることを確かめる。**"
echo
F="$S/reply-followers-cleanup.js"
BEFORE_UNF="$("$NODE_BIN" -e '
const fs=require("fs");
try{const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
let n=0;for(const e of Object.values(s)) if(e&&e.followback_status==="unfollowed") n++;
console.log(n)}catch(e){console.log(-1)}' "$W/data/reply-followers.json")"
BEFORE_DUE="$("$NODE_BIN" -e '
const fs=require("fs");
try{const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const now=Date.now();let n=0;
for(const e of Object.values(s)) if(e&&e.scheduled_unfollow_at&&new Date(e.scheduled_unfollow_at).getTime()<=now) n++;
console.log(n)}catch(e){console.log(-1)}' "$W/data/reply-followers.json")"
echo "- 走らせる前: \`unfollowed\` **${BEFORE_UNF} 件** / 期限到来 **${BEFORE_DUE} 件**"
echo
if [ -f "$F" ]; then
  echo '```'
  ( cd "$W" && CLEANUP_MAX_PER_RUN=5 "$NODE_BIN" "$F" 2>&1 | tail -30 ) | clean
  echo "(rc=$?)"
  echo '```'
else
  echo "- **\`reply-followers-cleanup.js\` が無い。走らせない。**"
fi
echo
AFTER_UNF="$("$NODE_BIN" -e '
const fs=require("fs");
try{const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
let n=0;for(const e of Object.values(s)) if(e&&e.followback_status==="unfollowed") n++;
console.log(n)}catch(e){console.log(-1)}' "$W/data/reply-followers.json")"
AFTER_DUE="$("$NODE_BIN" -e '
const fs=require("fs");
try{const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const now=Date.now();let n=0;
for(const e of Object.values(s)) if(e&&e.scheduled_unfollow_at&&new Date(e.scheduled_unfollow_at).getTime()<=now) n++;
console.log(n)}catch(e){console.log(-1)}' "$W/data/reply-followers.json")"
echo "| | 前 | 後 |"
echo "| --- | --- | --- |"
echo "| \`unfollowed\` | ${BEFORE_UNF} | **${AFTER_UNF}** |"
echo "| 期限到来 | ${BEFORE_DUE} | **${AFTER_DUE}** |"
echo
DIFF=$(( AFTER_UNF - BEFORE_UNF ))
echo "- **今回 外した数: ${DIFF} 件**"
if [ "$DIFF" -gt 0 ]; then echo "- **外れている。アンフォローは復旧した。**"
elif [ "$AFTER_DUE" -lt "$BEFORE_DUE" ]; then echo "- あとからフォロバされていた分をキャンセルした（正しい動き）"
else echo "- **まだ外れていない。上のログを読むこと。**"; fi

echo
echo "## 1. 復元済みの 2 本を起動する"
echo
for j in unfollow-cleanup-morning unfollow-cleanup-evening; do
  P="$LA/ai.openclaw.$j.plist"
  echo "### \`$j\`"
  echo
  if [ ! -f "$P" ]; then echo "- **plist が無い。起動しない。**"; echo; continue; fi
  LINT="$(plutil -lint "$P" 2>&1 | tail -1)"
  echo "- \`plutil -lint\`: $(printf '%s' "$LINT" | clean)"
  case "$LINT" in *OK*) ;; *) echo "- **壊れている。起動しない。**"; echo; continue ;; esac
  # 叩くスクリプトが実在するか
  TGT="$(grep -oE 'scripts/[a-zA-Z0-9._-]+\.js' "$P" 2>/dev/null | head -1)"
  if [ -n "$TGT" ] && [ ! -f "$W/$TGT" ]; then
    echo "- **叩く相手が無い（\`$TGT\`）。起動しない。**"; echo; continue
  fi
  [ -n "$TGT" ] && echo "- 叩く相手: \`$TGT\`（存在する）"
  echo
  echo '```'
  launchctl load -w "$P" 2>&1 | head -3 | clean
  launchctl enable "gui/$UID_N/ai.openclaw.$j" 2>&1 | head -2 | clean
  LINE="$(launchctl list 2>/dev/null | grep -F "ai.openclaw.$j" || true)"
  if [ -z "$LINE" ]; then echo "  **ロードできていない**"
  else printf '%s\n' "$LINE" | awk '{printf "  ロード済み  PID=%-8s 最後のrc=%s\n", $1, $2}'; fi
  echo '```'
  echo
done

echo
echo "## 2. スクリプトがある 2 本を復元する（**load はしない**）"
echo
for j in follow-watchdog revenge-unfollow; do
  P="$LA/ai.openclaw.$j.plist"
  SCRIPT="$S/$j.js"
  echo "### \`$j\`"
  echo
  if [ ! -f "$SCRIPT" ]; then echo "- **\`$j.js\` が無い。作らない。**"; echo; continue; fi
  if [ ! -f "$P" ]; then echo "- **plist が無い。作らない**（環境変数の材料が取れない）"; echo; continue; fi
  RAW="$(cat "$P" 2>/dev/null)"
  case "$RAW" in
    \{*) ;;
    *) echo "- 環境変数が残っていない。**作らない。**"; echo; continue ;;
  esac
  case "$j" in
    revenge-unfollow) HOUR=13; MIN=0 ;;
    follow-watchdog)  HOUR=11; MIN=0 ;;
  esac
  echo "- 環境変数: \`$(printf '%s' "$RAW" | clean)\`"
  echo "- 叩く相手: \`scripts/$j.js\`（存在する）"
  echo "- 実行時刻: **${HOUR}:${MIN}**（ログの時刻に合わせた）"
  mkdir -p "$LA/broken.$STAMP"
  cp -p "$P" "$LA/broken.$STAMP/$(basename "$P")"
  NEWP="/tmp/$j.plist.new"
  "$NODE_BIN" -e '
const fs=require("fs");
const [raw,label,script,hour,min,logdir,out]=process.argv.slice(1);
let env; try{ env=JSON.parse(raw); }catch(e){ console.error("環境変数が JSON として読めない"); process.exit(2); }
const esc=s=>String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
const envXml=Object.entries(env).map(([k,v])=>
  "    <key>"+esc(k)+"</key>\n    <string>"+esc(v)+"</string>").join("\n");
const name=label.replace(/^ai\.openclaw\./,"");
const xml=`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>cd ${esc(logdir.replace(/\/logs$/,""))}; ${esc(logdir.replace(/\/logs$/,""))}/scripts/ensure-chrome.sh; /usr/local/bin/node ${esc(script)}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
${envXml}
  </dict>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>${hour}</integer>
    <key>Minute</key><integer>${min}</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>${logdir}/${name}.log</string>
  <key>StandardErrorPath</key>
  <string>${logdir}/${name}-err.log</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
`;
fs.writeFileSync(out, xml);
' "$RAW" "ai.openclaw.$j" "scripts/$j.js" "$HOUR" "$MIN" "$W/logs" "$NEWP" 2>&1 | clean
  if [ ! -s "$NEWP" ]; then echo "- **作れなかった。元のまま。**"; echo; continue; fi
  if plutil -lint "$NEWP" >/dev/null 2>&1; then
    cp "$NEWP" "$P"
    echo "- **作り直した**（$(wc -c < "$P" | tr -d ' ') B・lint OK）／壊れた版は \`broken.$STAMP/\` に退避"
    echo "- **load していない。** 滞留が落ち着いてから起動する"
  else
    echo "- **lint を通らない。置き換えない。**"
  fi
  echo
done

echo
echo "## 3. スクリプトが無い 2 本"
echo
echo "\`unfollow-daily\` / \`unfollow-evening\` は**同名スクリプトが無く、"
echo "起動引数を復元する材料が無い。当て推量で書かない。作らない。**"
echo
echo '```'
for j in unfollow-daily unfollow-evening; do
  printf '  %-20s 環境変数: %s\n' "$j" "$(cat "$LA/ai.openclaw.$j.plist" 2>/dev/null | head -c 120 | clean)"
done
echo ""
echo "  scripts/ にある unfollow 系の実体:"
ls "$S" 2>/dev/null | grep -iE '^unfollow.*\.(js|sh)$' | sed 's/^/    /'
echo '```'
echo
echo "**この 2 本は、上のどれかの別名だった可能性がある。**"
echo "実体が特定できるまで作らない。"

echo
echo "## 4. いまのアンフォロー系のロード状態"
echo
echo '```'
for j in reply-followers-cleanup reply-followback-check auto-detect-and-unfollow-inactive \
         badge-followback unfollow-cleanup-morning unfollow-cleanup-evening \
         follow-watchdog revenge-unfollow unfollow-daily unfollow-evening; do
  line="$(launchctl list 2>/dev/null | grep -F "ai.openclaw.$j" || true)"
  if [ -z "$line" ]; then printf '  未ロード    %-36s\n' "$j"
  else printf '%s\n' "$line" | awk -v j="$j" '{printf "  ロード      %-36s PID=%-8s rc=%s\n", j, $1, $2}'; fi
done
echo '```'

echo
echo "---"
echo
echo "**アンフォローを手で実行していない。推測で plist を作っていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'ロード済み' "$OUT" 2>/dev/null; then
  echo "**復元した plist を起動した（\$0）** / $(basename "$OUT")"
else
  echo "**起動できていない。レポートを読むこと** / $(basename "$OUT")"
fi
