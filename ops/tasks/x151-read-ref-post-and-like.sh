#!/bin/bash
# **参考投稿の中身を取り、同時に「返信するときに いいねもしているか」を読む。読むだけ。費用 $0。**
#
# ## なぜ 1 本にまとめるか
#
# **クラウドセッションからは X に出られない**（`cdn.syndication.twimg.com:443
# connect_rejected`）。往復のたびに利用者を待たせる（最上位ルール 9）。
# **どちらも読むだけで数秒なので、1 本で取る。**
#
# ## ① 参考投稿（利用者が指定したもの）
#
#   https://x.com/<伏せ>/status/2103310568597954820
#
# **「この投稿を参考にして、アプリの紹介メッセージを作成して」**と言われている。
# **中身を見ずに書けない。** 型（書き出し・改行・絵文字・煽りの強さ・招待コードの置き方）を写す。
#
# ## ② いま返信するときに「いいね」もしているか
#
# **していなければセットで付けたい**という指示。まず**しているかどうかを確かめる。**
# 経路は `comment-orchestrator.sh` → `post-comment.js`（`x149` で確定）。
#
#   探すもの: data-testid="like" / unlike / favorite / likeBtn / いいね
#
# ## やらないこと
#
# **いいねを押さない。投稿しない。書き換えない。LLM も呼ばない（$0）。**
# **付けるかどうかは、いま付いていないことを確かめてから。**
set -uo pipefail

REF_ID="2103310568597954820"
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/ref-post-and-like.md"
RAW="$W/.x151-ref.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(xoxb-)[A-Za-z0-9-]+#\1<MASKED>#g' \
         -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

{
echo "# 参考投稿の中身と、いいねの有無（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** いいねも押していない。投稿もしていない。"

echo
echo "## 1. 参考投稿の実物（**型を写すために、1 文字も直さず出す**）"
echo
CODE="$(curl -s -m 25 -o "$RAW" -w '%{http_code}' \
  "https://cdn.syndication.twimg.com/tweet-result?id=$REF_ID&lang=ja&token=x" 2>/dev/null)"
echo '```'
printf '  HTTP %s   %s bytes\n' "$CODE" "$( [ -f "$RAW" ] && wc -c < "$RAW" | tr -d ' ' || echo 0 )"
echo '```'
echo
if [ "$CODE" = "200" ] && [ -s "$RAW" ]; then
  echo "### 本文（行番号つき）"
  echo
  echo '```'
  node -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const t = d.text || "";
    const w = (s) => { let n = 0; for (const c of s) n += c.codePointAt(0) < 0x80 ? 1 : 2; return n; };
    t.split("\n").forEach((line, i) => console.log(String(i + 1).padStart(3) + " | " + line));
    console.log("");
    console.log("  文字数: " + [...t].length + "   X の重み: " + w(t) + " / 280");
  ' "$RAW" 2>&1 | clean | sed 's/^/  /'
  echo '```'
  echo
  echo "### 付帯情報（**どう作られた投稿か**）"
  echo
  echo '```'
  node -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const p = (k, v) => console.log("  " + String(k).padEnd(14) + String(v));
    p("投稿時刻", d.created_at || "-");
    p("画像", (d.photos || []).length + " 枚");
    p("動画", d.video ? "あり" : "なし");
    p("親", d.in_reply_to_status_id_str || "（なし）");
    p("リンク", ((d.entities && d.entities.urls) || []).map((u) => u.expanded_url).join(" , ") || "（なし）");
    p("ハッシュタグ", ((d.entities && d.entities.hashtags) || []).map((h) => "#" + h.text).join(" ") || "（なし）");
    p("いいね", d.favorite_count);
  ' "$RAW" 2>&1 | clean | sed 's/^/  /'
  echo '```'
else
  echo "- **取れなかった（HTTP $CODE）。** 消えているか、非公開か、経路の問題"
fi
rm -f "$RAW"

echo
echo "## 2. 返信するときに「いいね」もしているか"
echo
echo "経路は \`comment-orchestrator.sh\` → \`post-comment.js\`（\`x149\` で確定）。"
echo "**いいねに触れている箇所が 1 つも無ければ、押していない。**"
echo
echo '```'
tot=0
for f in "$S/post-comment.js" "$S/comment-orchestrator.sh" "$S/post-via-playwright.js" "$S/comment-state.js"; do
  [ -f "$f" ] || { printf '  %-30s **無い**\n' "$(basename "$f")"; continue; }
  n=0
  for k in 'data-testid="like"' "testid.*like" "unlike" "favorite" "いいね" "likeBtn" "doLike"; do
    m="$(cnt "$k" "$f")"
    n=$((n + m))
  done
  tot=$((tot + n))
  printf '  %-30s いいね関連 %2s 箇所\n' "$(basename "$f")" "$n"
done
printf '  ---\n  合計 %s 箇所\n' "$tot"
echo '```'
echo
if [ "$tot" -gt 0 ]; then
  echo "**当たった行**（何をしているかを見る）:"
  echo
  echo '```javascript'
  for f in "$S/post-comment.js" "$S/comment-orchestrator.sh" "$S/post-via-playwright.js" "$S/comment-state.js"; do
    [ -f "$f" ] || continue
    grep -n -E 'data-testid="like"|testid.*like|unlike|favorite|いいね|likeBtn|doLike' "$f" 2>/dev/null \
      | head -20 | cut -c1-240 | clean | sed "s|^|  $(basename "$f"):|"
  done
  echo '```'
else
  echo "- **1 箇所も無い。いいねは押していない。** 付けるなら実装から"
fi
echo
echo "ほかのスクリプトに いいねの実装が在るか（**在れば書き方を写せる**）:"
echo
echo '```'
grep -l -E 'data-testid="like"|"unlike"' "$S"/*.js 2>/dev/null | head -10 | sed 's|.*/|  |' || echo "  （無い）"
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §2 の出方 | 次の一手 |"
echo "| --- | --- |"
echo "| いいねが **0 箇所** | **実装する。** 返信の直前か直後に \`[data-testid=\"like\"]\` を押す |"
echo "| いいねが在るのに押されていない | **条件で飛んでいる。** その条件を読む |"
echo "| 別のスクリプトに実装が在る | **その書き方を写す**（セレクタと待ちに実績がある） |"
echo
echo "> **いいね自体は DOM 操作なので LLM を呼ばない。** 付けても課金は増えない。"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'HTTP 200' "$OUT" 2>/dev/null; then
  echo "参考投稿といいねの有無を読んだ / $(basename "$OUT")"
else
  echo "**参考投稿が取れていない。レポートを確認すること** / $(basename "$OUT")"
fi
