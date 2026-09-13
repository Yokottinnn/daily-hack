#!/bin/bash
# **告知として実際に出た投稿を、キューの実物から洗い出す。測るだけ。費用 $0。**
#
# ## なぜ（2026-09-13 に利用者から指摘された）
#
# > ちなみにIKEA豊洲は投稿してるよ
# > https://x.com/heng_ji31590/status/2096512177930903788
#
# **`docs/cross-session-requests.md` は「対応中」のままだった。**
# 9/06 に出ていたのに、1 週間 気づかずに「止まっている」と報告した。
#
# 同じ表に「対応中」のまま残っているものが他にもある（サウナ 2 記事・8/27）。
# **出たかどうかは、キューの `x_tweet_id` を見れば分かる**（最上位ルール 11）。
#
# ## 出すもの
#
#   - `blog-promo-` / `thread` 系のエントリを**全部**、日付と `x_tweet_id` 付きで
#   - 記事の slug ごとにまとめる（どの記事の告知が出たか）
#   - **出ていないもの**（`x_tweet_id` が無い）も分けて出す
#
# ## やらないこと
#
# **投稿しない。キューを書き換えない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（JSON を読むだけ・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/promo-posts.md"
NODE_BIN="/usr/local/bin/node"
Q="$D/post_queue.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 告知として実際に出た投稿（**キューの実物**）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 2026-09-13 に利用者から指摘された。"
echo "> **IKEA豊洲は 9/06 に出ていたのに、依頼一覧は 1 週間「対応中」のままだった。**"
echo ">"
echo "> 出たかどうかは **キューの \`x_tweet_id\`** を見れば分かる（最上位ルール 11）。"
echo
echo "**測るだけ。投稿しない。**"

echo
echo "## 1. 告知系のエントリ（**出た順**）"
echo
echo '```'
if [ ! -f "$Q" ]; then
  echo "  **$Q が無い。**"
else
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const q = Array.isArray(j.queue) ? j.queue : [];

// 返信（comment-）以外＝告知・スレッド系
const promo = q.filter((x) => x && x.id && !String(x.id).startsWith("comment-"));
console.log("  キュー全体: " + q.length + " 件 / 返信以外: " + promo.length + " 件");
console.log("");

const at = (x) => x.posted_at || x.approved_at || x.created_at || x.enqueued_at || "";
promo.sort((a, b) => String(at(a)).localeCompare(String(at(b))));

const posted = promo.filter((x) => x.x_tweet_id || x.tweet_id);
const notPosted = promo.filter((x) => !(x.x_tweet_id || x.tweet_id));

console.log("  === 出たもの: " + posted.length + " 件 ===");
for (const x of posted.slice(-40)) {
  const id = x.x_tweet_id || x.tweet_id;
  console.log("    " + String(at(x)).slice(0, 16).padEnd(17) + String(x.id).slice(0, 40).padEnd(42)
    + " https://x.com/heng_ji31590/status/" + id);
}
console.log("");
console.log("  === 出ていないもの: " + notPosted.length + " 件 ===");
for (const x of notPosted.slice(-20)) {
  console.log("    " + String(at(x)).slice(0, 16).padEnd(17) + String(x.id).slice(0, 40).padEnd(42)
    + " status=" + (x.status || "?"));
}
' "$Q" 2>&1 | clean
fi
echo '```'

echo
echo "## 2. 記事の slug ごと（**どの記事の告知が出たか**）"
echo
echo '```'
if [ -f "$Q" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const q = Array.isArray(j.queue) ? j.queue : [];
const promo = q.filter((x) => x && x.id && !String(x.id).startsWith("comment-"));

// 本文の URL から slug を拾う。id が blog-promo-<slug>-... の形のこともある
const slugOf = (x) => {
  const t = [x.text, x.id, x.url].filter(Boolean).join(" ");
  const m = t.match(/\/posts\/([a-z0-9-]+)/);
  if (m) return m[1];
  const m2 = String(x.id || "").match(/^blog-promo-([a-z0-9-]+?)(-[0-9]+)?$/);
  return m2 ? m2[1] : "(slug 不明)";
};
const g = {};
for (const x of promo) {
  const s = slugOf(x);
  const c = g[s] || (g[s] = { n: 0, posted: 0, last: "", ids: [] });
  c.n++;
  if (x.x_tweet_id || x.tweet_id) {
    c.posted++;
    c.ids.push(x.x_tweet_id || x.tweet_id);
  }
  const t = x.posted_at || x.approved_at || x.created_at || "";
  if (t > c.last) c.last = t;
}
const keys = Object.keys(g).sort((a, b) => String(g[b].last).localeCompare(String(g[a].last)));
for (const k of keys.slice(0, 30)) {
  const c = g[k];
  console.log("    " + String(c.last).slice(0, 10) + "  " + k.padEnd(32)
    + " 出た " + c.posted + "/" + c.n + (c.ids.length ? "  " + c.ids.slice(0, 2).join(" ") : ""));
}
' "$Q" 2>&1 | clean
fi
echo '```'
echo
echo "**この一覧と \`docs/cross-session-requests.md\` を突き合わせる。**"
echo "出ているのに「対応中」のままの行は、**その場で閉じる。**"

echo
echo "## 3. 依頼一覧で確認したいもの"
echo
echo "| 依頼 | 日付 | 一覧の状態 | ここで確認すること |"
echo "| --- | --- | --- | --- |"
echo "| IKEA豊洲 | 2026-09-05 | **完了に直した** | \`2096512177930903788\`（利用者から URL をもらった） |"
echo "| サウナ 2 記事 | 2026-08-27 | 対応中 | slug \`sauna-openings-*\` が上の一覧に在るか |"
echo "| 都心の格安スーパー | 2026-09-06 | 未対応 | slug に \`super\` / \`supermarket\` を含むものが在るか |"
echo "| モーニング記事（作り直し） | 2026-09-05 | — | slug \`morning-500-2026\` が在るか |"

echo
echo "## 4. 費用"
echo
echo "**JSON を読むだけ。LLM を呼ばない。投稿もしない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44"
echo "（\`MAX_PICKS\` は 4 のまま・2026-09-13 に利用者が判断）。"
} > "$OUT" 2>&1

echo "告知として出た投稿の一覧 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
