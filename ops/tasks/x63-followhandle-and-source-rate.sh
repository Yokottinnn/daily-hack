#!/bin/bash
# **`follow-handle.js` が数字を返しているか ＋ source 別のフォロー返し率。測るだけ。費用 $0。**
#
# ## 1 つ目: フォロワー数は誰が持っているのか（x62 で場所が割れた）
#
# `competitor-follower-follow.js` の冒頭コメント:
#
#   * filter: follow-handle.js 経由 (bio mutual-intent / follower-count range)
#
# **フィルタは `follow-handle.js` の中。** 呼び出し側は `followed_at` しか書いていない
# （`competitor-follower-follow.js:151` / `hashtag-follow.js:155`）。
#
# **`follow-handle.js` が戻り値にフォロワー数を入れているなら、呼び出し側に 1 行 足すだけ。**
# 入れていないなら、`follow-handle.js` 側も直す必要がある。**どちらかを実物で確定する。**
#
# ## 2 つ目: source 別のフォロー返し率
#
# x61 が `follows_back` を 346 件 全部に書いた。**帯（フォロワー数）別はまだ出せないが、
# `source` 別なら今すぐ出せる。** 返りの悪い供給元が分かれば、そこを削れる。
#
#   source 例: competitor-follower:<誰か> / hashtag-active / badge-followback / reply-connected
#
# **全体は 16.2%（56 / 346）。** これを source ごとに割る。
#
# ## やらないこと
#
# **フォローしない。アンフォローしない。書き換えない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（JSON とソースを読むだけ。数秒 で終わる・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/followhandle-and-source-rate.md"
NODE_BIN="/usr/local/bin/node"
FH="$S/follow-handle.js"
RF="$D/reply-followers.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# \`follow-handle.js\` の戻り値 ＋ source 別のフォロー返し率"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x62 で場所が割れた。**フィルタは \`follow-handle.js\` の中。**"
echo "> 呼び出し側は \`followed_at\` しか書いていない。"
echo ">"
echo "> **戻り値に数字が入っているなら、呼び出し側に 1 行 足すだけで済む。**"
echo
echo "**測るだけ。直さない。**"

# ═══════════ 1. follow-handle.js の戻り値 ═══════════
echo
echo "## 1. \`follow-handle.js\` は数字を返しているか"
echo
echo '```'
if [ ! -f "$FH" ]; then
  echo "  **$FH が無い。**"
  ls -1 "$S" 2>/dev/null | grep -iE '^follow' | head -10 | sed 's/^/    候補: /'
else
  echo "  $(wc -l < "$FH" | tr -d ' ') 行 / 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$FH" 2>/dev/null)"
  echo
  echo "  --- フォロワー数を取っている行 ---"
  grep -nE 'follower|Follower|フォロワー|count|range|MIN_|MAX_|parseInt|Number\(' "$FH" 2>/dev/null \
    | head -22 | cut -c1-200 | sed 's/^/    /' | clean
  echo
  echo "  --- 戻り値（return / ok: の形） ---"
  grep -nE 'return *\{|return *ok|ok: *(true|false)|reason:|info:' "$FH" 2>/dev/null \
    | head -20 | cut -c1-200 | sed 's/^/    /' | clean
  echo
  echo "  --- しきい値の実物 ---"
  grep -nE '[0-9]{2,}' "$FH" 2>/dev/null \
    | grep -iE 'follower|range|min|max|limit' | head -12 | cut -c1-200 | sed 's/^/    /' | clean
fi
echo '```'
echo
echo "**戻り値に数字が在れば → 呼び出し側に 1 行。**"
echo "**無ければ → \`follow-handle.js\` 側で返すところから直す。** 次のタスクで分岐する。"

# ═══════════ 2. 呼び出し側の書き込み部分（実物） ═══════════
echo
echo "## 2. 呼び出し側が state に書いているところ（**実物の前後**）"
echo
echo '```javascript'
for f in competitor-follower-follow.js hashtag-follow.js; do
  P="$S/$f"; [ -f "$P" ] || continue
  echo "// ══ $f"
  awk 'NR>=140 && NR<=170 {printf("%4d| %s\n", NR, $0)}' "$P" 2>/dev/null | cut -c1-180 | clean
  echo
done
echo '```'

# ═══════════ 3. source 別のフォロー返し率 ═══════════
echo
echo "## 3. source 別のフォロー返し率（**全体 16.2%**（56 / 346）を割る）"
echo
echo '```'
if [ ! -f "$RF" ]; then
  echo "  **$RF が無い。**"
else
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const rows = Array.isArray(j) ? j
  : (j.followed || Object.entries(j).map(([k, v]) => (v && typeof v === "object" ? { handle: k, ...v } : { handle: k })));

const g = {};
let all = 0, allBack = 0, allStill = 0;
for (const r of rows) {
  if (!r) continue;
  // source は "competitor-follower:<誰か>" のように具体名が付く。**供給元でまとめる**
  const src = String(r.source || "(無し)").split(":")[0];
  g[src] = g[src] || { n: 0, back: 0, still: 0, oldest: "", newest: "" };
  const c = g[src];
  c.n++; all++;
  if (r.follows_back === true) { c.back++; allBack++; }
  if (r.still_following === true) { c.still++; allStill++; }
  const t = r.followed_at || "";
  if (t) {
    if (!c.oldest || t < c.oldest) c.oldest = t;
    if (!c.newest || t > c.newest) c.newest = t;
  }
}
const keys = Object.keys(g).sort((a, b) => g[b].n - g[a].n);
console.log("    " + "供給元".padEnd(26) + "  件数   返し   返し率   いま中");
for (const k of keys) {
  const c = g[k];
  const rate = c.n ? (c.back * 100 / c.n).toFixed(1) + "%" : "-";
  console.log("    " + k.padEnd(26) + String(c.n).padStart(6) + String(c.back).padStart(7)
    + rate.padStart(9) + String(c.still).padStart(8));
}
console.log("");
console.log("    合計: " + all + " 件 / 返し " + allBack + " 件 / "
  + (all ? (allBack * 100 / all).toFixed(1) : "0") + "% / いまフォロー中 " + allStill + " 件");
console.log("");
console.log("    --- 供給元ごとの期間（いつ集めたか） ---");
for (const k of keys) {
  const c = g[k];
  console.log("    " + k.padEnd(26) + " " + (c.oldest || "?").slice(0, 10) + " 〜 " + (c.newest || "?").slice(0, 10));
}
' "$RF" 2>&1 | head -40 | clean
fi
echo '```'
echo
echo "**件数の少ない供給元の率は当てにならない。** 20 件 未満は参考値として扱う。"
echo "**期間も見る。** 最近フォローした分は、まだ返ってきていないだけのことがある。"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**読むだけ。LLM を呼ばない。ブラウザを触らない。フォローもアンフォローもしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "参考（**推定**・前提: Haiku 4.5・生成 64 回/日）: 定時の返信ループは"
echo "1 回 \$0.003 ／ 1 日 約 \$0.19 ／ 1 か月 約 \$5.8。"
echo "**今日の実測の通過率は 56%**（picked 16 / enqueue 9）なので、"
echo "捨てる生成が減った分だけ 1 件あたりの単価は下がっている。"
} > "$OUT" 2>&1

echo "follow-handle の戻り値と source 別 返し率 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
