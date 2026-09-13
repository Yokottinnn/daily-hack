#!/bin/bash
# **サウナ／ドローンのどちらが出たか ＋ 止まったキューの中身を読む。測るだけ。費用 $0。**
#
# ## 1 つ目: 2026-08-27 の依頼は記事 2 本
#
#   ① https://daily-hack.com/posts/sauna-openings-2026/
#   ② https://daily-hack.com/posts/odaiba-drone-show-2026/
#
# x74 の実測では **1 本 だけ出ている。**
#
#   blog-promo-sauna-20260830-225430  → 2094061373584208194（2026-08-30 13:55）出た
#   sauna-x-20260830-223943           → status=skipped_unspecified        出ていない
#
# **id の名前だけでは、どちらの記事の分か判別できない。**
# 本文に入っている URL を見れば確定する。**推測で「サウナが出た」と書かない。**
#
# ## 2 つ目: 承認待ちのまま止まっているもの
#
# x74 で `awaiting_approval` が 2026-08〜09 分で 10 件 以上 残っていた。
#
#   grok-comment-20260801-2302-0 … 20260907-1502-1
#   trend-20260908-1 / trend-20260909-1 など
#
# **承認 TTL 7 日 を実装済みのはずなのに残っている。**
# 8/15 の事故（5 日 止まった後に 8 日前の滞留を投稿した）と同じ形なので、
# **なぜ失効していないのかを先に見る。掃除はその後。**
#
# ## やらないこと
#
# **キューを書き換えない。削除しない。投稿しない。LLM を呼ばない（$0）。**
# **ブラウザを触らない**（JSON を読むだけ・ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/sauna-and-stuck-queue.md"
NODE_BIN="/usr/local/bin/node"
Q="$D/post_queue.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# サウナ／ドローンのどちらが出たか ＋ 止まったキュー"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 2026-08-27 の依頼は記事 2 本（サウナ新店 / お台場ドローンショー）。"
echo "> x74 の実測では **1 本 だけ出ている。**"
echo ">"
echo "> **id の名前だけでは、どちらの記事の分か判別できない。** 本文の URL を見る。"
echo
echo "**測るだけ。書き換えない。**"

# ═══════════ 1. どちらが出たか ═══════════
echo
echo "## 1. どちらの記事が出たか（**本文の URL で確定する**）"
echo
echo '```'
if [ ! -f "$Q" ]; then
  echo "  **$Q が無い。**"
else
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const q = Array.isArray(j.queue) ? j.queue : [];
const hit = q.filter((x) => x && /sauna|drone|odaiba/i.test(String(x.id) + " " + String(x.text || "")));
console.log("  該当エントリ: " + hit.length + " 件");
console.log("");
for (const x of hit) {
  const id = x.x_tweet_id || x.tweet_id || null;
  const at = x.posted_at || x.approved_at || x.created_at || "";
  console.log("  ══ " + x.id);
  console.log("     いつ   : " + String(at).slice(0, 19));
  console.log("     状態   : " + (id ? "**出た** " + id : "出ていない（status=" + (x.status || "?") + "）"));
  const urls = String(x.text || "").match(/https?:\/\/[^\s]+/g) || [];
  console.log("     URL    : " + (urls.length ? urls.join(" ") : "（本文に URL 無し）"));
  console.log("     画像   : " + (x.image_path || x.images || "（無し）"));
  console.log("     本文   : " + String(x.text || "").replace(/\n/g, " / ").slice(0, 220));
  if (Array.isArray(x.thread_chain) && x.thread_chain.length) {
    console.log("     スレッド: " + x.thread_chain.length + " 本");
    x.thread_chain.forEach((t, i) => {
      const tu = String(t.text || t).match(/https?:\/\/[^\s]+/g) || [];
      console.log("       [" + (i + 2) + "] " + String(t.text || t).replace(/\n/g, " / ").slice(0, 160)
        + (tu.length ? "  URL=" + tu.join(" ") : ""));
    });
  }
  console.log("");
}
' "$Q" 2>&1 | clean
fi
echo '```'
echo
echo "**本文に \`/posts/sauna-openings-2026/\` が在れば、出たのはサウナ。**"
echo "**\`/posts/odaiba-drone-show-2026/\` が在れば、出たのはドローン。**"
echo "どちらも無ければ、**記事の告知ではなく別の投稿**だったということ。"

# ═══════════ 2. 記事側の実在確認 ═══════════
echo
echo "## 2. 記事の画像が残っているか（**残りを作るときに要る**）"
echo
echo '```'
REPO="/Users/ny/projects/anta-baka-x/blog"
for slug in sauna-openings-2026 odaiba-drone-show-2026 tokyo-discount-supermarket-2026; do
  P="$REPO/public/images/$slug"
  if [ -d "$P" ]; then
    echo "  $slug: 在る（$(ls -1 "$P" 2>/dev/null | wc -l | tr -d ' ') 件）"
    ls -1 "$P" 2>/dev/null | head -6 | sed 's/^/      /'
    [ -d "$P/photos" ] && echo "      photos/: $(ls -1 "$P/photos" 2>/dev/null | wc -l | tr -d ' ') 件"
  else
    echo "  $slug: **無い**（$P）"
  fi
done
echo
echo "  --- X カードの JSON（既に作ってあるか） ---"
XC="$REPO/ops/data/x-cards"
if [ -d "$XC" ]; then
  ls -1t "$XC" 2>/dev/null | head -10 | sed 's/^/    /'
else
  echo "    $XC が無い"
fi
echo '```'

# ═══════════ 3. 止まったキュー ═══════════
echo
echo "## 3. 承認待ちのまま止まっているもの（**なぜ失効していないか**）"
echo
echo '```'
if [ -f "$Q" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const q = Array.isArray(j.queue) ? j.queue : [];
const stuck = q.filter((x) => x && !(x.x_tweet_id || x.tweet_id) && /awaiting/i.test(String(x.status || "")));
console.log("  承認待ちのまま: " + stuck.length + " 件");
console.log("");
const now = Date.now();
const g = {};
for (const x of stuck) {
  const at = x.approved_at || x.created_at || x.enqueued_at || "";
  const days = at ? Math.floor((now - Date.parse(at)) / 86400000) : -1;
  const kind = String(x.id).replace(/-?[0-9]{8}.*$/, "") || "(不明)";
  (g[kind] = g[kind] || []).push({ id: x.id, at: String(at).slice(0, 16), days, status: x.status, approved: !!x.approved_at });
}
for (const k of Object.keys(g).sort()) {
  const rows = g[k];
  console.log("  ══ " + k + ": " + rows.length + " 件");
  for (const r of rows.slice(0, 8)) {
    console.log("     " + r.at.padEnd(17) + r.days + " 日前  " + (r.approved ? "承認済み" : "未承認  ")
      + "  " + r.id);
  }
  console.log("");
}
console.log("  --- 失効の判定に使われるフィールド ---");
const sample = stuck[0];
if (sample) console.log("  " + JSON.stringify(Object.keys(sample)));
' "$Q" 2>&1 | clean
fi
echo '```'
echo
echo "**\`approved_at\` が無いものは「承認されていない」ので、TTL の対象外かもしれない。**"
echo "TTL は「**承認から** 7 日」なので、**承認されないまま残るものは永遠に残る。**"
echo "下でその実装を確かめる。"

# ═══════════ 4. TTL の実装 ═══════════
echo
echo "## 4. 承認 TTL の実装（**実物**）"
echo
echo '```'
for f in poll-approvals.js queue-manager.js; do
  P="$S/$f"; [ -f "$P" ] || { echo "  $f: **無い**"; continue; }
  echo "  ══ $f（$(wc -l < "$P" | tr -d ' ') 行 / $(stat -f '%Sm' -t '%m-%d %H:%M' "$P" 2>/dev/null)）"
  grep -nE 'TTL|7 ?\* ?24|expired|approved_at|失効|86400000|604800' "$P" 2>/dev/null \
    | head -12 | cut -c1-190 | sed 's/^/    /' | clean
  echo
done
echo '```'
echo
echo "**掃除の前に、消していいものかを判断する材料がここに出る。**"
echo "未承認のまま古いものは、**投稿されない代わりに一覧を汚している**だけかもしれない。"

# ═══════════ 5. 費用 ═══════════
echo
echo "## 5. 費用"
echo
echo "**JSON とソースを読むだけ。LLM を呼ばない。投稿もしない。書き換えもしない。**"
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

echo "サウナの残りと止まったキュー / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
