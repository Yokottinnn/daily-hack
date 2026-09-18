#!/bin/bash
# **返し率 0% の原因 ＋ 今日の実投稿数。測るだけ。費用 $0。**
#
# ## 1 つ目: 帯ごとの返し率が全部 0%
#
#   followback_bands: with_count 81 / mature 40 / **mature_back 0**
#     1000-4999 n=29 mature=14 rate=0    5000-49999 n=22 mature=13 rate=0
#     0-99      n=15 mature=7  rate=0    300-999    n=14 mature=5  rate=0
#
# **x61 の実測は全体 16.2%（56/346）。** 新規分だけ一律 0% は不自然で、
# **`follows_back` を更新する経路が新規分を見ていない疑いが濃い。**
#
# x61 は `/followers` を一括で読んで書いた。**それ以降その更新を誰が回しているのか、
# 確認していない。** 分母（記録）は育ったが、分子（返し）が止まっている可能性。
#
# **判定の前に、更新経路を確かめる。** しきい値の議論はその後。
#
# ## 2 つ目: 今日の実投稿数
#
# `heartbeat.json` の `posted_today: 32` は**ログの行数**で二重計上する（ルール 11）。
# **一次情報はキューの `x_tweet_id`。** 認証が 20:42 JST に切れたので、
# **切れるまでに何件 出たか**を確定させる。
#
# ## やらないこと
#
# **投稿しない。フォローしない。書き換えない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（JSON とログを読むだけ・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
S="$W/scripts"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/followback-zero-and-today.md"
NODE_BIN="/usr/local/bin/node"
RF="$D/reply-followers.json"
Q="$D/post_queue.json"

# **`@` 付きだけでは漏れる**（2026-09-14 に実際に漏らした）。カンマ区切りの列も畳む
hide() {
  sed -E -e 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g' \
         -e 's/[A-Za-z0-9_]{3,15}(,[A-Za-z0-9_]{3,15}){1,}/<伏せ・ハンドル列>/g'
}
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 返し率 0% の原因 ＋ 今日の実投稿数"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`followback_bands\` は **mature 40 件 に対して \`mature_back\` が全帯 0**。"
echo "> x61 の実測は全体 **16.2%**（56/346）。**新規分だけ一律 0% は不自然。**"
echo ">"
echo "> **分母（記録）は育ったが、分子（返し）が止まっている疑い。**"
echo
echo "**測るだけ。しきい値を触らない。**"

# ═══════════ 1. 誰が follows_back を書くのか ═══════════
echo
echo "## 1. 誰が \`follows_back\` を書くのか（**実物**）"
echo
echo '```'
echo "  --- scripts/ で follows_back を書いている箇所 ---"
grep -rln 'follows_back' "$S" 2>/dev/null | grep -v '\.bak' | head -8 | while IFS= read -r f || [ -n "$f" ]; do
  [ -n "$f" ] || continue
  echo "    ══ $(basename "$f")（$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)）"
  grep -n 'follows_back' "$f" 2>/dev/null | head -4 | cut -c1-170 | sed 's/^/      /' | clean
done
echo
echo "  --- 関係しそうなジョブのログ ---"
for f in reply-followback-check.log badge-followback.log reply-followers-cleanup.log; do
  P="$L/$f"; [ -f "$P" ] || { echo "    $f: **無い**"; continue; }
  printf '    %-32s %10s bytes / 最終更新 %s\n' "$f" "$(wc -c < "$P" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
done
echo
echo "  --- reply-followback-check の直近 12 行 ---"
[ -f "$L/reply-followback-check.log" ] && tail -12 "$L/reply-followback-check.log" 2>/dev/null \
  | cut -c1-180 | sed 's/^/      /' | clean
echo '```'

# ═══════════ 2. いつまで更新されているか ═══════════
echo
echo "## 2. \`follows_back\` はいつまで更新されているか"
echo
echo '```'
if [ ! -f "$RF" ]; then
  echo "  **$RF が無い。**"
else
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const rows = Object.entries(j).map(([k, v]) => (v && typeof v === "object" ? { handle: k, ...v } : { handle: k }));
console.log("  全体: " + rows.length + " 件");
const hasFB = rows.filter((r) => r.follows_back !== undefined);
const isTrue = rows.filter((r) => r.follows_back === true);
console.log("  follows_back を持つ : " + hasFB.length + " 件");
console.log("  follows_back = true : **" + isTrue.length + " 件**");
console.log("");
// 更新の打刻がどこまで進んでいるか
for (const k of ["checked_at", "followback_judgment_at", "late_followback_at"]) {
  const v = rows.map((r) => r[k]).filter(Boolean).sort();
  console.log("  " + k.padEnd(24) + ": " + v.length + " 件  最新 " + (v.slice(-1)[0] || "-").slice(0, 19));
}
console.log("");
// 9/13（x61 の一括更新）の前後で分ける
const CUT = "2026-09-14";
const old = rows.filter((r) => (r.followed_at || "") < CUT);
const nw  = rows.filter((r) => (r.followed_at || "") >= CUT);
const rate = (a) => { const t = a.filter((r) => r.follows_back === true).length; return t + "/" + a.length + "（" + (a.length ? (t * 100 / a.length).toFixed(1) : "0") + "%）"; };
console.log("  --- x61 の一括更新（9/13）の前後で分ける ---");
console.log("    9/14 より前にフォロー: " + rate(old));
console.log("    9/14 以降にフォロー  : **" + rate(nw) + "**");
console.log("");
console.log("  → 後者が 0% なら、**新規分を誰も見ていない**ということ。");
console.log("     フォロー直後は返ってこないので低く出るが、**72 時間 経った分が 0 は説明がつかない。**");
' "$RF" 2>&1 | clean
fi
echo '```'

# ═══════════ 3. 今日の実投稿数 ═══════════
echo
echo "## 3. 今日の実投稿数（**キューの \`x_tweet_id\`**・ルール 11）"
echo
echo '```'
if [ ! -f "$Q" ]; then
  echo "  **$Q が無い。**"
else
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const q = Array.isArray(j.queue) ? j.queue : [];
// JST の今日
const now = new Date(Date.now() + 9 * 3600 * 1000);
const today = now.toISOString().slice(0, 10).replace(/-/g, "");
const mine = q.filter((x) => x && x.id && String(x.id).indexOf("comment-" + today) === 0);
const posted = mine.filter((x) => x.x_tweet_id || x.tweet_id);
console.log("  今日（JST " + today + "）の comment- エントリ: " + mine.length + " 件");
console.log("  そのうち **x_tweet_id を持つ（＝出た）: " + posted.length + " 件**");
console.log("");
for (const x of posted.slice(-10)) console.log("    " + x.id + "  " + (x.x_tweet_id || x.tweet_id));
const pend = mine.filter((x) => !(x.x_tweet_id || x.tweet_id));
if (pend.length) {
  console.log("");
  console.log("  まだ出ていない: " + pend.length + " 件");
  for (const x of pend.slice(-5)) console.log("    " + x.id + "  status=" + (x.status || "?"));
}
console.log("");
console.log("  ※ heartbeat の posted_today はログの行数で二重計上する。**上の件数が実数。**");
' "$Q" 2>&1 | clean
fi
echo '```'

# ═══════════ 4. 今日のフォロー数 ═══════════
echo
echo "## 4. 今日フォローした数（**状態ファイル**）"
echo
echo '```'
if [ -f "$RF" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const rows = Object.values(j).filter((v) => v && typeof v === "object");
const today = new Date().toISOString().slice(0, 10);
const t = rows.filter((r) => (r.followed_at || "").startsWith(today));
console.log("  今日フォローした: " + t.length + " 件");
const bySrc = {};
for (const r of t) { const s = String(r.source || "?").split(":")[0]; bySrc[s] = (bySrc[s] || 0) + 1; }
for (const k of Object.keys(bySrc)) console.log("    " + k.padEnd(24) + bySrc[k] + " 件");
const withN = t.filter((r) => typeof r.followers_at_follow === "number");
console.log("");
console.log("  フォロワー数を記録できた: " + withN.length + " / " + t.length + " 件");
' "$RF" 2>&1 | clean
fi
echo '```'

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**JSON とログを読むだけ。LLM を呼ばない。投稿もフォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44"
echo "（\`MAX_PICKS\` は 4 のまま）。フォロー・アンフォロー系は \$0（DOM 操作のみ）。"
} > "$OUT" 2>&1

echo "返し率 0% と今日の実数 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
