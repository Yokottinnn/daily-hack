#!/bin/bash
# **`2103379894306750770` が何者かを一次情報で特定する。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# 利用者から「この投稿ってなに？ ちゃんと文章になってないしミスかな？」と
# **実物の URL 付きで**指摘された。
#
#   https://x.com/<伏せ>/status/2103379894306750770
#
# **クラウドセッションからは X に出られない**（`cdn.syndication.twimg.com:443
# connect_rejected`）。**Mac からは出られる。**
#
# ## 推測で答えない（最上位ルール 11）
#
# **一次情報は 2 つだけ。** キューの `x_tweet_id` / `tweet_id` と、**投稿の実物**。
# ログの grep 件数も、過去のレポートも、一次情報ではない。
#
# **出すのは 3 つ。**
#
#   ① **投稿の実物**（syndication。cookie を送らない公開エンドポイント）
#      → 本文が本当に壊れているのか、壊れているなら どこで切れているのか
#   ② **どのジョブが出したか**（キューとログを id で引く）
#   ③ **承認を通ったのか**（通っていないなら、それ自体が事故）
#
# ## やらないこと
#
# **消さない。直さない。投稿しない。ジョブも触らない。LLM も呼ばない（$0）。**
#
# **消すかどうかは利用者が決める。** 勝手に消すと、何が起きたか分からなくなる。
set -uo pipefail

ID="2103379894306750770"
W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/identify-tweet.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(xoxb-)[A-Za-z0-9-]+#\1<MASKED>#g' \
         -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
         -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

RAW="$W/.x145-tweet.json"

{
echo "# \`$ID\` は何者か（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。消していない。直していない。**"
echo "> 消すかどうかは利用者が決める。勝手に消すと何が起きたか分からなくなる。"

echo
echo "## 1. 投稿の実物（**一次情報**）"
echo
echo "cookie を送らない公開エンドポイントで取る。**ログイン状態に左右されない。**"
echo
CODE="$(curl -s -m 25 -o "$RAW" -w '%{http_code}' \
  "https://cdn.syndication.twimg.com/tweet-result?id=$ID&lang=ja&token=x" 2>/dev/null)"
echo '```'
printf '  HTTP %s   %s bytes\n' "$CODE" "$( [ -f "$RAW" ] && wc -c < "$RAW" | tr -d ' ' || echo 0 )"
echo '```'
echo
if [ "$CODE" = "200" ] && [ -s "$RAW" ]; then
  echo "### 本文（**改行も含めてそのまま。1 文字も直していない**）"
  echo
  echo '```'
  node -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const t = d.text || "";
    const w = s => { let n = 0; for (const c of s) n += c.codePointAt(0) < 0x80 ? 1 : 2; return n; };
    t.split("\n").forEach((line, i) => {
      console.log(String(i + 1).padStart(3) + " | " + line);
    });
    console.log("");
    console.log("  文字数: " + [...t].length + "   X の重み: " + w(t) + " / 280");
  ' "$RAW" 2>&1 | clean | sed 's/^/  /'
  echo '```'
  echo
  echo "### そのほか"
  echo
  echo '```'
  node -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const p = (k, v) => console.log("  " + String(k).padEnd(16) + String(v));
    p("投稿時刻", d.created_at || "(なし)");
    p("画像", (d.photos || []).length + " 枚");
    p("動画", d.video ? "あり" : "なし");
    p("親", d.in_reply_to_status_id_str || "（なし＝スレッドの返信ではない）");
    p("引用", d.quoted_tweet ? d.quoted_tweet.id_str : "（なし）");
    p("リンク", ((d.entities && d.entities.urls) || []).map(u => u.expanded_url).join(" , ") || "（なし）");
    p("いいね", d.favorite_count);
    p("会話id", d.conversation_count != null ? d.conversation_count : "-");
  ' "$RAW" 2>&1 | clean | sed 's/^/  /'
  echo '```'
else
  echo "- **取れなかった（HTTP $CODE）。** 消されているか、非公開か、経路が塞がれている"
  echo
  echo '```'
  [ -f "$RAW" ] && head -c 500 "$RAW" | clean | sed 's/^/  /'
  echo '```'
fi

echo
echo "## 2. どのジョブが出したか（**id で引く**）"
echo
echo "キューとログの両方を id で引く。**当たった行がどのファイルに在るかが答え。**"
echo
echo '```'
found=0
for f in "$D"/*.json "$D"/*.jsonl "$L"/*.log; do
  [ -f "$f" ] || continue
  n="$(grep -c -- "$ID" "$f" 2>/dev/null | head -1)"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -gt 0 ]; then
    found=1
    printf '  %-40s %3s 行  更新 %s\n' "$(basename "$f")" "$n" \
      "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
  fi
done
[ "$found" -eq 0 ] && echo "  **どこにも無い。** 自動投稿の経路を通っていない可能性がある"
echo '```'

if [ "$found" -eq 1 ]; then
  echo
  echo "当たった行（**前後 2 行。秘密とハンドルは伏せる**）:"
  echo
  echo '```'
  for f in "$D"/*.json "$D"/*.jsonl "$L"/*.log; do
    [ -f "$f" ] || continue
    grep -q -- "$ID" "$f" 2>/dev/null || continue
    echo "  ===== $(basename "$f") ====="
    grep -n -C2 -- "$ID" "$f" 2>/dev/null | head -40 | cut -c1-300 | clean | sed 's/^/    /'
    echo
  done
  echo '```'
fi

echo
echo "## 3. その時刻に動いていたジョブ"
echo
echo "id で当たらなかったときの手がかり。**投稿時刻の前後に書き込みが在るログ**を出す。"
echo
echo '```'
for f in "$L"/*.log; do
  [ -f "$f" ] || continue
  sz="$(wc -c < "$f" | tr -d ' ')"
  [ "$sz" -gt 0 ] || continue
  m="$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
  case "$m" in
    09-2[45]*) printf '  %-40s 更新 %s  (%s bytes)\n' "$(basename "$f")" "$m" "$sz" ;;
  esac
done
echo '```'

echo
echo "## 4. 承認を通ったか"
echo
echo "**通っていないなら、それ自体が事故。** 8/15 に同じことが起きている。"
echo
echo '```'
for q in "$D"/post_queue.json "$D"/queue.json "$D"/approval*.json; do
  [ -f "$q" ] || continue
  printf '  %-34s %8s bytes  更新 %s\n' "$(basename "$q")" "$(wc -c < "$q" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%m-%d %H:%M' "$q" 2>/dev/null)"
done
echo '```'

rm -f "$RAW"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §1 の本文 | 意味 |"
echo "| --- | --- |"
echo "| 途中で切れている | **重み 280 の超過か、生成側の打ち切り。** §2 でどちらか分かる |"
echo "| プレースホルダが残っている | **テンプレの埋め込みが失敗**。生成側の不具合 |"
echo "| 文としては通っている | 文面の質の問題。**スキルの §6 に指摘を写す話**になる |"
echo "| HTTP 404 | **もう消えている**（利用者が消したか、X が消したか） |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'HTTP 200' "$OUT" 2>/dev/null; then
  echo "投稿の実物を取って出所を引いた / $(basename "$OUT")"
else
  echo "**実物が取れていない。レポートを確認すること** / $(basename "$OUT")"
fi
