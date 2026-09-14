#!/bin/bash
# **`mutual-prune` を `StartCalendarInterval` に移す。費用 $0。**
#
# ## なぜ（x79 の実測・2026-09-15 01:15 時点）
#
#   StartInterval = 43200 秒（12 時間）
#   ログの最終更新: 2026-09-14 05:10
#   いま          : 2026-09-15 01:15   ← **20 時間 経過**（本来 17:10 頃に 1 回）
#   launchctl の最後の終了コード: **-15**（SIGTERM で落とされている）
#
# **`StartInterval` は Mac が寝ている間の発火を落とす。**
# `StartCalendarInterval` は「その時刻に発火」で、**起きたときに 1 回 発火する。**
#
# 他の 8 本は `x48` で切り替え済み。**`mutual-prune` は `x51` で
# その後に設置したため、変換器を通っていない。**
#
# ## 番人は既に見ている（**追加しない**）
#
# `x47` の `JOBS_CDP` に `mutual-prune` は入っている。番人は「今日 1 回でも
# 走ったか」で判定するので、**保証しているのは 1 日 1 回。**
# 12 時間 ごとの刻みは plist 側の仕事なので、そちらを直す。
#
# ## やること
#
# `x48` の変換器を**そのまま使う**（Mac で実績がある）。
# 12 時間 → **1 日 2 回（6 時 / 18 時）**。**発火回数は変えない。**
#
# ## やらないこと
#
# **上限（MAX_UNFOLLOW=8）を変えない。判定条件を変えない。**
# **いま外さない**（kickstart しない）。**LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/mutual-prune-calendar.md"
NODE_BIN="/usr/local/bin/node"
LABEL="ai.openclaw.mutual-prune"
PLIST="$LA/$LABEL.plist"
UID_NUM="$(id -u)"
STAMP="$(date '+%Y%m%d-%H%M%S')"
CONV="$W/scripts/.x80-convert.js"
trap 'rm -f "$CONV" "$PLIST.json.tmp"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

# ─── x48 の変換器（**そのまま使う**。Mac で実績がある） ───
cat > "$CONV" <<'JSEOF'
const fs = require('fs');
const { execFileSync } = require('child_process');

const p = process.argv[2];
const startAt = Number(process.argv[3] || 0);

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
echo "# \`mutual-prune\` を \`StartCalendarInterval\` に移す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x79 の実測: **20 時間 走っていなかった**（12 時間 間隔のはずが 1 回だけ）。"
echo "> \`StartInterval\` は **Mac が寝ている間の発火を落とす。**"
echo ">"
echo "> 他の 8 本は \`x48\` で切り替え済み。**\`mutual-prune\` は後から設置したので通っていない。**"
echo
echo "**発火回数は変えない（12 時間 → 1 日 2 回）。上限も判定条件も触らない。**"

# ═══════════ 0. 変える前 ═══════════
echo
echo "## 0. 変える前"
echo
echo '```'
LC="$(launchctl list 2>/dev/null || true)"      # **1 回だけ取る**（ルール 13）
if echo "$LC" | awk '{print $3}' | grep -qxF "$LABEL"; then
  echo "  載っている: **はい**"
  echo "$LC" | awk -v l="$LABEL" '$3==l {print "    PID=" $1 "  最後の終了コード=" $2}'
else
  echo "  載っている: **いいえ**"
fi
if [ -f "$PLIST" ]; then
  echo "  plist: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$PLIST" 2>/dev/null)"
  echo "    StartInterval        : $(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$PLIST" 2>/dev/null || echo '(無し)')"
  echo "    StartCalendarInterval: $(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$PLIST" 2>/dev/null | grep -c 'Hour' || echo 0) 個"
else
  echo "  **$PLIST が無い。**"
fi
if [ -f "$L/mutual-prune.log" ]; then
  echo "  ログの最終更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$L/mutual-prune.log" 2>/dev/null)"
fi
echo '```'

# ═══════════ 1. 変える ═══════════
echo
echo "## 1. 変える（**6 時 / 18 時 の 2 回**）"
echo
echo '```'
if [ ! -f "$PLIST" ]; then
  echo "  **対象が無いので何もしない。**"
else
  cp "$PLIST" "$PLIST.bak-$STAMP" && echo "  退避: $(basename "$PLIST").bak-$STAMP"
  R="$("$NODE_BIN" "$CONV" "$PLIST" 6 2>&1)"
  echo "  変換: $R"
  case "$R" in
    CONVERTED*)
      if plutil -lint "$PLIST" >/dev/null 2>&1; then
        echo "  plutil -lint: OK"
        launchctl bootout "gui/${UID_NUM}/${LABEL}" >/dev/null 2>&1 || true
        sleep 1
        BS="$(launchctl bootstrap "gui/${UID_NUM}" "$PLIST" 2>&1)"; BRC=$?
        [ -n "$BS" ] && echo "$BS" | head -3 | sed 's/^/    /' | clean
        echo "  bootstrap rc=$BRC（**rc は載った証拠にならない。下で確かめる**）"
      else
        echo "  **plutil -lint が通らない。戻す。**"
        cp "$PLIST.bak-$STAMP" "$PLIST"
      fi
      ;;
    ALREADY_CALENDAR) echo "  既に StartCalendarInterval。**何もしない**" ;;
    *)                echo "  **変換しなかった。** 載せ直しもしない" ;;
  esac
fi
echo '```'

# ═══════════ 2. 載ったかを別の口で確かめる ═══════════
echo
echo "## 2. 結果（**\`launchctl list\` で確かめる**・ルール 13）"
echo
echo '```'
LC2="$(launchctl list 2>/dev/null || true)"
if echo "$LC2" | awk '{print $3}' | grep -qxF "$LABEL"; then
  echo "  $LABEL: **載っている**"
  echo "$LC2" | awk -v l="$LABEL" '$3==l {print "    PID=" $1 "  最後の終了コード=" $2}'
else
  echo "  $LABEL: **載っていない。** bootstrap が効いていない"
fi
echo
if [ -f "$PLIST" ]; then
  echo "  --- 変えた後の plist ---"
  echo "    StartInterval        : $(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$PLIST" 2>/dev/null || echo '(無し。これでよい)')"
  H="$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$PLIST" 2>/dev/null | grep -oE 'Hour = [0-9]+' | grep -oE '[0-9]+' | tr '\n' ',' | sed 's/,$//')"
  echo "    StartCalendarInterval: ${H:-(無し)} 時"
  echo "    RunAtLoad            : $(/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' "$PLIST" 2>/dev/null || echo '(無し)')"
  echo
  echo "  --- 環境変数が残っているか（**消えていたら困る**） ---"
  for k in MAX_UNFOLLOW INACTIVE_DAYS RATIO ABS_MIN GRACE_DAYS CDP_URL OPS_WS; do
    V="$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables:$k" "$PLIST" 2>/dev/null || echo '(無し)')"
    printf '    %-16s %s\n' "$k" "$V"
  done
fi
echo '```'
echo
echo "**環境変数が 1 つでも消えていたら、退避から戻す。**"
echo "上限や判定条件が既定値に戻ると、外す件数が変わってしまう。"

# ═══════════ 3. 次に走る時刻 ═══════════
echo
echo "## 3. 次に走る時刻"
echo
echo '```'
echo "  6 時 と 18 時（JST）に発火する。**寝ていたら、起きたときに 1 回。**"
echo "  いま: $(date '+%Y-%m-%d %H:%M')"
echo
echo "  番人（daily-supervisor）は 05:00 / 17:00 に走り、"
echo "  **「今日 1 回も走っていない」ものを kickstart する。**"
echo "  mutual-prune は既にその監視対象（x47 の JOBS_CDP）。**追加は不要。**"
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**plist を書き換えて載せ直すだけ。LLM を呼ばない。いま外さない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**\`mutual-prune\` 自体も \$0**（DOM 操作のみ）。**発火回数は変えない**ので、"
echo "外す件数の上限も 1 回 8 件・1 日 16 件 のまま（実績は 2026-09-13 に 6 件）。"
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44。"
} > "$OUT" 2>&1

echo "mutual-prune を StartCalendarInterval へ / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
