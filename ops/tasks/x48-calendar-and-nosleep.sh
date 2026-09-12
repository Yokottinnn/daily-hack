#!/bin/bash
# **スリープで消えない起動方式にする ＋ Mac を寝かせない。費用 $0（LLM 不使用）。**
#
# ## なぜ必要か
#
# `StartInterval` は「**前回の発火から N 秒**」で数える。
# **Mac が寝ていた／電源が落ちていた分は、そのまま消える。**
# 12:00 / 16:00 / 19:00 / 22:00 のつもりでも、寝ていれば 1 日 分 まるごと飛ぶ。
#
# `StartCalendarInterval` は「**その時刻に発火**」で、
# **発火時刻を過ぎて起動した場合は、起きた直後に 1 回 まとめて発火する。**
# これが「毎日 必ず走る」に効く。
#
# ## 2 段で塞ぐ
#
#   ① **起動方式**: 定時のものを `StartCalendarInterval` に寄せる
#      → 寝ていても、起きたときに走る
#   ② **そもそも寝かせない**: `caffeinate` を常駐させる
#      → 寝なければ ① の出番も減る
#
# **どちらか一方では足りない。** ②だけだと蓋を閉じた時・電源断で無力、
# ①だけだと「起きるまで走らない」。両方 入れる。
#
# ## `caffeinate` を選ぶ理由（`pmset` ではなく）
#
# `sudo pmset -a sleep 0` は**管理者パスワードが要る**ので、
# `ops/tasks` の無人実行では使えない。
#
# `/usr/bin/caffeinate -dimsu` は**sudo が要らない。**
#
#   -d  ディスプレイを寝かせない
#   -i  アイドルスリープを抑える
#   -m  ディスク のアイドルを抑える
#   -s  **電源に繋がっているとき**のシステムスリープを抑える
#   -u  ユーザーが操作中だと宣言する
#
# **正直に書くと、これで防げるのは「アイドルで勝手に寝る」だけ。**
# 蓋を閉じた／手で スリープ／電源を抜いてバッテリー切れ は防げない。
# だから ① が要る。
#
# ## やらないこと
#
# **ジョブの中身を書き換えない。しきい値を触らない。Chrome を kill しない。**
# **発火の回数は変えない。** 12:00/16:00/19:00/22:00 のものは、その 4 回のまま
# カレンダーに移すだけ。**1 日の実行回数が増えないので API 課金も増えない。**
#
# ## 費用
#
# **LLM を一切 呼ばない。** 起動方式を変えるだけなので、
# **1 回 $0 ／ 1 日 $0 ／ 1 か月 $0。**
#
# 返信ループの発火回数は変えていないので、定時の推定
# （1 日 約 $0.19 ／ 1 か月 約 $5.8・前提 Haiku 4.5・通過率 25%・生成 64 回/日）も**変わらない。**
# 寝ていて飛んでいた分が飛ばなくなるぶん、**実額は推定値に近づく方向**に動く。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/calendar-and-nosleep.md"
UID_NUM="$(id -u)"
STAMP="$(date '+%Y%m%d-%H%M%S')"
CAF_LABEL="ai.openclaw.caffeinate"
CAF_PLIST="$LA/$CAF_LABEL.plist"
CONV="$(mktemp -t conv).js"
trap 'rm -f "$CONV"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

JOBS="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat mutual-prune"

# ─── StartInterval → StartCalendarInterval の変換器 ───
# **発火回数を変えない。** 間隔から「1 日 何回か」を出し、その回数ぶんの時刻を等間隔に置く。
cat > "$CONV" <<'JSEOF'
// plist の StartInterval を、同じ頻度の StartCalendarInterval に置き換える。
// **回数を増やさない。** 6 時間ごと → 1 日 4 回、12 時間ごと → 1 日 2 回。
//
// 既に StartCalendarInterval なら何もしない。
// 1 日 より長い間隔（> 86400）は触らない（日次より粗いものを日次にしない）。
// 1 時間 より短い間隔も触らない（分刻みのものをカレンダーにすると回数が激減する）。
const fs = require('fs');
const { execFileSync } = require('child_process');

const p = process.argv[2];
const startAt = Number(process.argv[3] || 0); // 何時から始めるか（分散用）

function plistToJson(f) {
  const out = execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', f], { encoding: 'utf8' });
  return JSON.parse(out);
}

let d;
try { d = plistToJson(p); }
catch (e) { console.log('READ_FAIL ' + String(e.message).slice(0, 80)); process.exit(0); }

if (d.StartCalendarInterval) { console.log('ALREADY_CALENDAR'); process.exit(0); }
const iv = Number(d.StartInterval);
if (!isFinite(iv) || iv <= 0) { console.log('NO_INTERVAL'); process.exit(0); }
if (iv > 86400) { console.log('SKIP_TOO_LONG ' + iv); process.exit(0); }
if (iv < 3600) { console.log('SKIP_TOO_SHORT ' + iv); process.exit(0); }

const times = Math.max(1, Math.round(86400 / iv));
const step = Math.max(1, Math.floor(24 / times));
const hours = [];
for (let k = 0; k < times; k++) hours.push((startAt + k * step) % 24);

delete d.StartInterval;
d.StartCalendarInterval = hours.map((h) => ({ Hour: h, Minute: 0 }));

const tmp = p + '.json.tmp';
fs.writeFileSync(tmp, JSON.stringify(d));
try {
  execFileSync('/usr/bin/plutil', ['-convert', 'xml1', '-o', p, tmp]);
  fs.unlinkSync(tmp);
  console.log('CONVERTED ' + iv + 's -> ' + times + ' times/day at ' + hours.join(',') + ' 時');
} catch (e) {
  try { fs.unlinkSync(tmp); } catch (x) {}
  console.log('WRITE_FAIL ' + String(e.message).slice(0, 80));
}
JSEOF

{
echo "# スリープで消えない起動方式にする ＋ Mac を寝かせない"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`StartInterval\` は「**前回の発火から N 秒**」で数える。"
echo "> **Mac が寝ていた／電源が落ちていた分は、そのまま消える。**"
echo ">"
echo "> \`StartCalendarInterval\` は「その時刻に発火」で、"
echo "> **発火時刻を過ぎて起動した場合は、起きた直後に 1 回 まとめて発火する。**"

# ═══════════ 1. いまの起動方式 ═══════════
echo
echo "## 1. いまの起動方式"
echo
echo '```'
for j in $JOBS; do
  P="$LA/ai.openclaw.$j.plist"
  if [ ! -f "$P" ]; then printf '  %-28s plist 無し\n' "$j"; continue; fi
  IV="$(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$P" 2>/dev/null || echo '')"
  CAL="$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$P" 2>/dev/null | grep -c 'Hour' || true)"
  CAL=$(printf '%s' "${CAL:-0}" | tr -dc '0-9'); [ -z "$CAL" ] && CAL=0
  if [ "$CAL" -gt 0 ]; then printf '  %-28s カレンダー %s 回/日\n' "$j" "$CAL"
  elif [ -n "$IV" ]; then printf '  %-28s StartInterval %s 秒（= 1 日 %s 回）\n' "$j" "$IV" "$(( 86400 / IV ))"
  else printf '  %-28s どちらも無し\n' "$j"; fi
done
echo '```'

# ═══════════ 2. 変換する ═══════════
echo
echo "## 2. \`StartCalendarInterval\` に移す（**発火回数は変えない**）"
echo
echo "間隔から「1 日 何回か」を出し、**その回数ぶんの時刻を等間隔に置く。**"
echo "6 時間ごと → 1 日 4 回、12 時間ごと → 1 日 2 回。**回数が増えないので API 課金も増えない。**"
echo
echo "触らないもの: 既にカレンダーのもの ／ **1 日 より長い間隔** ／ **1 時間 より短い間隔**"
echo "（分刻みのものをカレンダーにすると回数が激減してしまう）"
echo
echo '```'
OFF=0
for j in $JOBS; do
  P="$LA/ai.openclaw.$j.plist"
  [ -f "$P" ] || { printf '  %-28s plist 無し\n' "$j"; continue; }
  cp -p "$P" "$P.bak-$STAMP"
  R="$(/usr/local/bin/node "$CONV" "$P" "$OFF" 2>&1 | head -1)"
  case "$R" in
    CONVERTED*)
      if plutil -lint "$P" >/dev/null 2>&1; then
        printf '  %-28s %s\n' "$j" "$R"
        launchctl bootout "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
        launchctl enable "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
        launchctl bootstrap "gui/${UID_NUM}" "$P" >/dev/null 2>&1 || true
      else
        printf '  %-28s **plist が壊れた。戻す。**\n' "$j"
        cp -p "$P.bak-$STAMP" "$P"
      fi
      ;;
    *) printf '  %-28s %s\n' "$j" "$R" ;;
  esac
  OFF=$(( (OFF + 1) % 3 ))   # ジョブごとに開始時刻を 1 時間ずつ ずらして集中を避ける
done
echo '```'
echo
echo '```'
echo "  --- 変換後 ---"
SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"
for j in $JOBS; do
  P="$LA/ai.openclaw.$j.plist"
  [ -f "$P" ] || continue
  H="$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$P" 2>/dev/null | grep -oE 'Hour = [0-9]+' | grep -oE '[0-9]+' | tr '\n' ',' | sed 's/,$//')"
  L=$(printf '%s\n' "$SNAP" | grep -qxF "ai.openclaw.$j" && echo 'ロード済み' || echo '**未ロード**')
  printf '  %-28s %-24s %s\n' "$j" "${H:-（カレンダー無し）} 時" "$L"
done
echo '```'

# ═══════════ 3. 寝かせない ═══════════
echo
echo "## 3. \`caffeinate\` を常駐させる（**sudo なし**）"
echo
echo "\`sudo pmset -a sleep 0\` は**管理者パスワードが要る**ので、無人実行では使えない。"
echo "\`/usr/bin/caffeinate -dimsu\` は **sudo が要らない。**"
echo
echo "| 旗 | 意味 |"
echo "| --- | --- |"
echo "| \`-d\` | ディスプレイを寝かせない |"
echo "| \`-i\` | アイドルスリープを抑える |"
echo "| \`-m\` | ディスクのアイドルを抑える |"
echo "| \`-s\` | **電源に繋がっているとき**のシステムスリープを抑える |"
echo "| \`-u\` | ユーザーが操作中だと宣言する |"
echo
echo "**正直に書くと、これで防げるのは「アイドルで勝手に寝る」だけ。**"
echo "**蓋を閉じた ／ 手でスリープ ／ 電源を抜いてバッテリー切れ は防げない。**"
echo "だから §2 のカレンダー化が要る。**片方では足りない。**"
echo
echo '```xml'
[ -f "$CAF_PLIST" ] && cp -p "$CAF_PLIST" "$CAF_PLIST.bak-$STAMP"
cat > "$CAF_PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$CAF_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/caffeinate</string>
    <string>-dimsu</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>$W/logs/caffeinate.out</string>
  <key>StandardErrorPath</key><string>$W/logs/caffeinate.err</string>
</dict>
</plist>
PLISTEOF
cat "$CAF_PLIST" | clean
echo '```'
echo
echo '```'
if plutil -lint "$CAF_PLIST" >/dev/null 2>&1; then
  echo "  plutil -lint: OK"
  launchctl bootout "gui/${UID_NUM}/$CAF_LABEL" >/dev/null 2>&1 || true
  launchctl enable "gui/${UID_NUM}/$CAF_LABEL" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/${UID_NUM}" "$CAF_PLIST" 2>&1 | head -3 | sed 's/^/    /' | clean
  sleep 3
  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qxF "$CAF_LABEL"; then
    echo "  **載った（\`launchctl list\` に出た）** ← rc は見ない"
    echo "  --- 実際に caffeinate が動いているか ---"
    pgrep -fl 'caffeinate' 2>/dev/null | head -3 | sed 's/^/    /' || echo "    **プロセスが見つからない**"
  else
    echo "  **載っていない。**"
    launchctl print "gui/${UID_NUM}/$CAF_LABEL" 2>&1 | head -6 | sed 's/^/    /' | clean
  fi
else
  echo "  **plist が壊れている。ロードしない。**"
  [ -f "$CAF_PLIST.bak-$STAMP" ] && cp -p "$CAF_PLIST.bak-$STAMP" "$CAF_PLIST"
fi
echo
echo "  --- いまの電源設定（参考・変更はしていない） ---"
pmset -g 2>/dev/null | grep -E 'sleep|displaysleep|disksleep|hibernatemode|Sleep Prevented|standby' \
  | head -8 | sed 's/^/    /'
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**LLM を一切 呼ばない。** 起動方式を変えるだけ。"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**返信ループの発火回数は変えていない**ので、定時の推定"
echo "（1 日 約 \$0.19 ／ 1 か月 約 \$5.8・前提 Haiku 4.5・通過率 25%・生成 64 回/日）も**変わらない。**"
echo "寝ていて飛んでいた分が飛ばなくなるぶん、**実額は推定値に近づく方向**に動く。"
echo
echo "## 5. 戻すには"
echo
echo '```'
echo "  # 起動方式を戻す（plist は .bak-$STAMP に退避してある）"
echo "  cp ~/Library/LaunchAgents/ai.openclaw.<名前>.plist.bak-$STAMP \\"
echo "     ~/Library/LaunchAgents/ai.openclaw.<名前>.plist"
echo "  launchctl bootout gui/\$(id -u)/ai.openclaw.<名前>"
echo "  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/ai.openclaw.<名前>.plist"
echo
echo "  # 寝かせない設定を止める"
echo "  launchctl bootout gui/\$(id -u)/$CAF_LABEL"
echo '```'
} > "$OUT" 2>&1

echo "カレンダー化とスリープ抑止 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
