#!/bin/bash
# **`mutual-prune` が実際に走って何を外したかを確かめる。測るだけ。費用 $0。**
#
# ## なぜ（**利用者が「今すぐ実装して」と言った常駐ジョブ**）
#
# > お互いにフォローしている場合でも、相手のアカウントがあまり活動していない場合とか、
# > 自分のアカウントと比べた時に大したことない場合にはそっとアンフォローするジョブを
# > 常駐化してほしい。今すぐ実装して。
#
# `x51` で設置し、`launchctl list` にも載っている（heartbeat の `jobs` に在る）。
# **だが「走ったか」「何を外したか」を一度も確かめていない。**
#
# **載っていることは走った証拠にならない**（最上位ルール 13）。
# `launchctl load` が rc=0 でも載っていなかった実例がこの環境にある。
#
# ## 確かめるもの（**状態で見る**）
#
#   1. 載っているか（`launchctl list` の 3 列目・**1 回だけ取る**）
#   2. plist の間隔と `RunAtLoad`
#   3. ログが在るか・最終更新はいつか・**何回 走ったか**
#   4. **実際に外した件数**（ログの判定行と、状態ファイルの `unfollow_source`）
#   5. 候補が 0 件 だった回はなぜか（休眠・格下の条件に当たらない／様子見期間）
#
# ## やらないこと
#
# **外さない。設定を変えない。kickstart しない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（ログと JSON を読むだけ・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
S="$W/scripts"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/verify-mutual-prune.md"
NODE_BIN="/usr/local/bin/node"
LABEL="ai.openclaw.mutual-prune"
MP="$S/mutual-prune.js"
RF="$D/reply-followers.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# \`mutual-prune\` は走ったか、何を外したか"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 利用者が「今すぐ実装して」と言った常駐ジョブ。\`x51\` で設置した。"
echo "> **だが「走ったか」「何を外したか」を一度も確かめていない。**"
echo ">"
echo "> **載っていることは走った証拠にならない**（最上位ルール 13）。"
echo
echo "**測るだけ。外さない。**"

# ═══════════ 1. 載っているか ═══════════
echo
echo "## 1. 載っているか（\`launchctl list\` を **1 回だけ** 取る）"
echo
echo '```'
LC="$(launchctl list 2>/dev/null || true)"
if echo "$LC" | awk '{print $3}' | grep -qxF "$LABEL"; then
  echo "  $LABEL: **載っている**"
  echo "$LC" | awk -v l="$LABEL" '$3==l {print "    PID=" $1 "  最後の終了コード=" $2}'
else
  echo "  $LABEL: **載っていない**"
fi
echo
echo "  --- plist ---"
P="$LA/$LABEL.plist"
if [ -f "$P" ]; then
  echo "    $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null) / $(wc -c < "$P" | tr -d ' ') bytes"
  grep -oE '<key>(StartInterval|RunAtLoad|Label|ProgramArguments)</key>|<integer>[0-9]+</integer>|<(true|false)/>' "$P" 2>/dev/null \
    | tr '\n' ' ' | fold -w 160 | sed 's/^/    /'
  echo
  echo "    --- 渡している環境変数 ---"
  awk '/EnvironmentVariables/,/<\/dict>/' "$P" 2>/dev/null \
    | grep -oE '<key>[A-Za-z_]+</key>|<string>[^<]*</string>' \
    | sed 's/<[^>]*>//g' | paste - - 2>/dev/null | head -10 | sed 's/^/    /'
else
  echo "    **$P が無い**"
fi
echo
echo "  --- 本体 ---"
if [ -f "$MP" ]; then
  echo "    $MP（$(wc -l < "$MP" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$MP" 2>/dev/null)）"
else
  echo "    **$MP が無い**"
fi
echo '```'

# ═══════════ 2. 走ったか ═══════════
echo
echo "## 2. 走ったか（**ログの実物**）"
echo
echo '```'
FOUND=0
for f in mutual-prune.log mutual-prune.out mutual-prune.err; do
  PP="$L/$f"; [ -f "$PP" ] || { echo "  $f: **無い**"; continue; }
  FOUND=1
  printf '  %-22s %8s bytes / 最終更新 %s\n' "$f" "$(wc -c < "$PP" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$PP" 2>/dev/null)"
done
echo
if [ "$FOUND" = "1" ] && [ -f "$L/mutual-prune.log" ]; then
  echo "  --- 走った回数（日ごと） ---"
  awk '
    match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { d = substr($0, RSTART, RLENGTH) }
    d == "" { next }
    /start|=== /        { s[d]++ }
    /unfollow|外し|外す/ { u[d]++ }
    { seen[d] = 1 }
    END {
      n = 0
      for (k in seen) ks[n++] = k
      for (i = 0; i < n; i++) for (j = i + 1; j < n; j++) if (ks[i] > ks[j]) { t = ks[i]; ks[i] = ks[j]; ks[j] = t }
      printf("    %-12s %6s %8s\n", "日付", "起動", "外した行")
      for (i = 0; i < n; i++) { k = ks[i]; printf("    %-12s %6d %8d\n", k, s[k], u[k]) }
    }
  ' "$L/mutual-prune.log" 2>/dev/null | clean
  echo
  echo "  --- 直近 30 行（実物） ---"
  tail -30 "$L/mutual-prune.log" 2>/dev/null | cut -c1-190 | sed 's/^/    /' | clean
else
  echo "  **ログが 1 つも無い。** 一度も走っていない可能性が高い"
  echo
  echo "  --- logs/ に mutual を含むもの ---"
  ls -1 "$L" 2>/dev/null | grep -i mutual | sed 's/^/    /' || echo "    無し"
fi
echo '```'

# ═══════════ 3. 実際に外したか ═══════════
echo
echo "## 3. 実際に外したか（**状態ファイルで数える**・ルール 13）"
echo
echo '```'
if [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const rows = Object.entries(j).map(([k, v]) => (v && typeof v === "object" ? { handle: k, ...v } : { handle: k }));
const src = {};
for (const r of rows) {
  if (!r.unfollowed_at) continue;
  const s = String(r.unfollow_source || "(印なし)");
  (src[s] = src[s] || []).push(r);
}
console.log("  外した記録がある件数: " + Object.values(src).reduce((a, b) => a + b.length, 0) + " 件");
console.log("");
for (const k of Object.keys(src).sort((a, b) => src[b].length - src[a].length)) {
  const rs = src[k];
  const last = rs.map((r) => r.unfollowed_at).sort().slice(-1)[0] || "";
  console.log("    " + k.padEnd(28) + String(rs.length).padStart(4) + " 件   最後: " + String(last).slice(0, 16));
}
const mp = src["mutual-prune"] || [];
console.log("");
if (mp.length) {
  console.log("  === mutual-prune が外したもの（直近 8 件） ===");
  for (const r of mp.slice(-8)) {
    console.log("    " + String(r.unfollowed_at).slice(0, 16)
      + "  followers=" + (r.followers_at_follow === undefined ? "?" : r.followers_at_follow)
      + "  理由=" + (r.unfollow_reason || "(無し)"));
  }
} else {
  console.log("  → **mutual-prune が外した記録は 0 件。**");
  console.log("     ジョブが走っていないか、条件に当たる相手が居なかったかのどちらか");
}
' "$RF" 2>&1 | clean
else
  echo "  **$RF が無い。**"
fi
echo '```'

# ═══════════ 4. 条件に当たる相手が居るのか ═══════════
echo
echo "## 4. そもそも条件に当たる相手が居るのか（**外さずに数えるだけ**）"
echo
echo '判定は `x51` の既定値。**ここでは DOM を見ないので、状態ファイルに在る情報だけで概算する。**'
echo
echo '```'
if [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const rows = Object.entries(j).map(([k, v]) => (v && typeof v === "object" ? { handle: k, ...v } : { handle: k }));
const GRACE = 14, RATIO = 0.20, ABS_MIN = 300;
const now = Date.now();
const alive = rows.filter((r) => r.still_following === true && !r.unfollowed_at);
const mutual = alive.filter((r) => r.follows_back === true);
const young = mutual.filter((r) => r.followed_at && (now - Date.parse(r.followed_at)) / 86400000 < GRACE);
const withCount = mutual.filter((r) => typeof r.followers_at_follow === "number");
console.log("  いまフォロー中（状態ファイル基準）: " + alive.length + " 件");
console.log("  そのうち相互                      : " + mutual.length + " 件");
console.log("  様子見の期間内（" + GRACE + " 日 未満）        : " + young.length + " 件（触らない）");
console.log("  フォロワー数を記録済み            : " + withCount.length + " 件");
console.log("");
console.log("  ※ **休眠（最終投稿 30 日 前より古い）はプロフィールを見ないと分からない。**");
console.log("     ここでは数えられないので、mutual-prune 本体のログで見る。");
console.log("");
console.log("  --- 格下の目安（自分のフォロワー数が要る） ---");
console.log("  自分のフォロワーが 254 なら、閾値は 254 × " + RATIO + " = " + Math.floor(254 * RATIO)
  + " かつ " + ABS_MIN + " 未満");
const low = withCount.filter((r) => r.followers_at_follow < Math.min(Math.floor(254 * RATIO), ABS_MIN));
console.log("  記録済みのうち、この条件に当たるのは: " + low.length + " 件");
' "$RF" 2>&1 | clean
fi
echo '```'
echo
echo "**0 件 なら「壊れている」のではなく「条件に当たる相手が居ない」可能性がある。**"
echo "その場合に条件を緩めるかは、**このレポートを見てから決める**（推測で緩めない）。"

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**ログと JSON を読むだけ。LLM を呼ばない。外さない。ブラウザも触らない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "**\`mutual-prune\` 自体も \$0**（DOM 操作だけで LLM を呼ばない）。"
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44"
echo "（\`MAX_PICKS\` は 4 のまま）。"
} > "$OUT" 2>&1

echo "mutual-prune の実績 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
