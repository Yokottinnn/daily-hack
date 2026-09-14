#!/bin/bash
# **滞留 58 件 を片付けるための実態を読む。測るだけ。費用 $0。**
#
# ## なぜ（x61 の実測・2026-09-13）
#
#   期限到来: **58 件**（30 日 以上 放置が 19 件）
#   ※ 前は 328 件 だったが、実際にフォローしているかを見ていなかったための水増し
#
# アンフォロー自体は `x60` で **3/3 外れる**ことを確認済み。
# **外す仕組みは直っている。あとは滞留を流し切るだけ。**
#
# ## 読むところ（**直さない。上限を上げない**）
#
#   1. いま滞留は何件か（**もう一度 数える**。9/13 の数字は古い）
#   2. どのジョブが外すのか（`reply-followers-cleanup`）
#   3. **1 回に何件 外す設定か**（plist の環境変数・スクリプトの既定値）
#   4. どの間隔で走るか（`StartCalendarInterval` か `StartInterval` か）
#   5. 直近の実績（1 回あたり実際に何件 外せているか）
#
# **「上限 N 件 × 1 日 M 回 なら X 日 で終わる」を出す。**
# 上げるかどうかは、その数字を見てから決める（推測で上げない）。
#
# ## やらないこと
#
# **外さない。上限を変えない。kickstart しない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
S="$W/scripts"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/cleanup-backlog.md"
NODE_BIN="/usr/local/bin/node"
RF="$D/reply-followers.json"
LABEL="ai.openclaw.reply-followers-cleanup"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 滞留を片付けるための実態"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x61 の実測（2026-09-13）: 期限到来 **58 件**（30 日 以上 放置が 19 件）。"
echo "> アンフォロー自体は x60 で **3/3 外れる**ことを確認済み。"
echo ">"
echo "> **外す仕組みは直っている。あとは流し切るだけ。**"
echo
echo "**測るだけ。上限を上げない。**"

# ═══════════ 1. いま何件か ═══════════
echo
echo "## 1. いま滞留は何件か（**数え直す**。9/13 の数字は古い）"
echo
echo '```'
if [ ! -f "$RF" ]; then
  echo "  **$RF が無い。**"
else
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const rows = Object.entries(j).map(([k, v]) => (v && typeof v === "object" ? { handle: k, ...v } : { handle: k }));
const now = Date.now();
const alive = rows.filter((r) => r.still_following === true && !r.unfollowed_at);
const due = alive.filter((r) => r.scheduled_unfollow_at && Date.parse(r.scheduled_unfollow_at) <= now);
const old30 = due.filter((r) => (now - Date.parse(r.scheduled_unfollow_at)) / 86400000 >= 30);
console.log("  状態ファイル全体            : " + rows.length + " 件");
console.log("  いまフォロー中の扱い        : " + alive.length + " 件");
console.log("  **期限到来（滞留）**        : **" + due.length + " 件**");
console.log("  そのうち 30 日 以上 放置    : " + old30.length + " 件");
console.log("");
const back = due.filter((r) => r.follows_back === true).length;
console.log("  滞留のうち相互（返してくれている）: " + back + " 件");
console.log("  → **相互は外すか残すかで方針が分かれる。** ここで分けて出す");
console.log("");
console.log("  --- いちばん古い 5 件 ---");
due.sort((a, b) => String(a.scheduled_unfollow_at).localeCompare(String(b.scheduled_unfollow_at)));
for (const r of due.slice(0, 5)) {
  const d = Math.floor((now - Date.parse(r.scheduled_unfollow_at)) / 86400000);
  console.log("    期限 " + String(r.scheduled_unfollow_at).slice(0, 10) + "（" + d + " 日 超過）"
    + "  相互=" + (r.follows_back === true ? "はい" : "いいえ")
    + "  source=" + String(r.source || "?").split(":")[0]);
}
' "$RF" 2>&1 | clean
fi
echo '```'

# ═══════════ 2. どのジョブが外すのか ═══════════
echo
echo "## 2. 外すジョブ（**設定の実物**）"
echo
echo '```'
LC="$(launchctl list 2>/dev/null || true)"      # **1 回だけ取る**（ルール 13）
for lbl in ai.openclaw.reply-followers-cleanup ai.openclaw.reply-followback-check ai.openclaw.badge-followback; do
  if echo "$LC" | awk '{print $3}' | grep -qxF "$lbl"; then
    echo "  $lbl: **載っている**"
    echo "$LC" | awk -v l="$lbl" '$3==l {print "    PID=" $1 "  最後の終了コード=" $2}'
  else
    echo "  $lbl: **載っていない**"
  fi
done
echo
P="$LA/$LABEL.plist"
if [ -f "$P" ]; then
  echo "  --- $LABEL.plist ---"
  echo "    更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  echo "    StartInterval        : $(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$P" 2>/dev/null || echo '(無し)')"
  H="$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$P" 2>/dev/null | grep -oE 'Hour = [0-9]+' | grep -oE '[0-9]+' | tr '\n' ',' | sed 's/,$//')"
  echo "    StartCalendarInterval: ${H:-(無し)} 時"
  echo "    --- 環境変数 ---"
  awk '/EnvironmentVariables/,/<\/dict>/' "$P" 2>/dev/null \
    | grep -oE '<key>[A-Za-z_]+</key>|<string>[^<]*</string>' \
    | sed 's/<[^>]*>//g' | paste - - 2>/dev/null | head -12 | sed 's/^/      /' | clean
else
  echo "  **$P が無い。**"
fi
echo '```'

# ═══════════ 3. 1 回に何件 外す設定か ═══════════
echo
echo "## 3. 1 回に何件 外す設定か（**スクリプトの実物**）"
echo
echo '```'
for f in reply-followers-cleanup.js reply-followers-cleanup.sh; do
  PP="$S/$f"; [ -f "$PP" ] || continue
  echo "  ══ $f（$(wc -l < "$PP" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%m-%d %H:%M' "$PP" 2>/dev/null)）"
  grep -nE 'MAX|CAP|LIMIT|slice\(|process.env|GRACE|DAYS' "$PP" 2>/dev/null \
    | head -14 | cut -c1-190 | sed 's/^/    /' | clean
  echo
done
ls -1 "$S" 2>/dev/null | grep -iE 'cleanup|unfollow' | sed 's/^/    scripts: /'
echo '```'

# ═══════════ 4. 直近の実績 ═══════════
echo
echo "## 4. 直近の実績（**1 回あたり実際に何件 外せているか**）"
echo
echo '```'
CL="$L/reply-followers-cleanup.log"
if [ -f "$CL" ]; then
  echo "  $(wc -c < "$CL" | tr -d ' ') bytes / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$CL" 2>/dev/null)"
  echo
  echo "  --- 直近 25 行 ---"
  tail -25 "$CL" 2>/dev/null | cut -c1-190 | sed 's/^/    /' | clean
  echo
  echo "  --- 日ごとの外した数 ---"
  awk '
    match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { d = substr($0, RSTART, RLENGTH) }
    d == "" { next }
    /外れた|unfollowed|✂/ { u[d]++ }
    /start|=== /          { s[d]++ }
    { seen[d] = 1 }
    END {
      n = 0
      for (k in seen) ks[n++] = k
      for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (ks[i] > ks[j]) { t = ks[i]; ks[i] = ks[j]; ks[j] = t }
      st = (n > 10 ? n - 10 : 0)
      printf("    %-12s %6s %8s\n", "日付", "起動", "外した")
      for (i = st; i < n; i++) { k = ks[i]; printf("    %-12s %6d %8d\n", k, s[k], u[k]) }
    }
  ' "$CL" 2>/dev/null | clean
else
  echo "  **$CL が無い。**"
  ls -1 "$L" 2>/dev/null | grep -iE 'cleanup|unfollow' | sed 's/^/    logs: /'
fi
echo '```'

# ═══════════ 5. 何日で終わるか ═══════════
echo
echo "## 5. 何日で終わるか"
echo
echo "**上限 × 頻度 で割るだけ。** 実績が上限に届いていないなら、そちらで割る。"
echo
echo "| | 計算 |"
echo "| --- | --- |"
echo "| 上限どおりに流れた場合 | 滞留 ÷（1 回の上限 × 1 日 の回数） |"
echo "| 実績どおりなら | 滞留 ÷ 直近の 1 日 あたり実績 |"
echo
echo "**この 2 つは別物。** 上限を実績のように出さない（最上位ルール 2-B）。"
echo "数字は上の 1〜4 章から入れる。"

# ═══════════ 6. 費用 ═══════════
echo
echo "## 6. 費用"
echo
echo "**JSON・plist・ログを読むだけ。LLM を呼ばない。外さない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**アンフォロー自体も \$0**（DOM 操作のみ・LLM を呼ばない）。"
echo "上限を上げても API 課金は増えない。増えるのは Mac の CPU 時間と通信だけ。"
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44。"
} > "$OUT" 2>&1

echo "滞留の実態 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
