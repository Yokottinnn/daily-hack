#!/bin/bash
# **PAY ID の一次情報を取る。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# 「**スレッドでアプリの魅力を紹介して**」と言われている。
# だが いま手元にある事実は、参考投稿から読めた **「500円分」** と
# 「食品が多そう」という印象だけ。**これでは魅力を 1 スレッド ぶん書けない。**
#
# **推測で書かない**（最上位ルール 11 / `x-post-copy` スキル §4「記事に無い数字を書かない」）。
# 紹介文で事実を外すと、招待コード経由で入った人が いちばん先に気づく。
#
# ## クラウドからは出られない
#
#   payid.jp        → HTTP 000（egress で塞がれている）
#   s.payid.jp      → HTTP 000
#
# **Mac からは出られる。**
#
# ## 何を取るか
#
#   ① 公式サイト（`payid.jp`）の本文テキスト
#   ② **App Store の掲載情報**（iTunes Search API。説明文・カテゴリ・評価・更新日）
#   ③ 招待リンクの飛び先（`s.payid.jp/...`）— **何が書いてあるページか**
#
# **②が一番 硬い。** 各社が自分で書いた説明文で、機械可読で返る。
#
# ## やらないこと
#
# **登録しない。投稿しない。書き換えない。LLM も呼ばない（$0）。**
set -uo pipefail

INV="https://s.payid.jp/nNE1nwcd"
OUT="${OPS_REPORT_DIR:-/tmp}/payid-facts.md"
W="$HOME/.openclaw/workspace"
T="$W/.x152"

mkdir -p "$T"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

# HTML からテキストを抜く（script/style を落としてタグを剥がす）
detag() {
  node -e '
    let s = "";
    process.stdin.on("data", (d) => (s += d)).on("end", () => {
      s = s.replace(/<script[\s\S]*?<\/script>/gi, " ")
           .replace(/<style[\s\S]*?<\/style>/gi, " ")
           .replace(/<[^>]+>/g, "\n")
           .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
           .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"");
      const lines = s.split("\n").map((l) => l.trim()).filter((l) => l.length > 1);
      const seen = new Set();
      const outl = [];
      for (const l of lines) { if (!seen.has(l)) { seen.add(l); outl.push(l); } }
      console.log(outl.join("\n"));
    });
  ' 2>/dev/null
}

{
echo "# PAY ID の一次情報（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 登録も投稿もしていない。"
echo "> **ここに出ていることしか紹介文に書かない。**"

echo
echo "## 1. App Store の掲載情報（**一番 硬い。各社が自分で書いた説明文**）"
echo
C="$(curl -sL -m 25 -o "$T/app.json" -w '%{http_code}' \
  "https://itunes.apple.com/search?term=PAY%20ID&country=jp&entity=software&limit=8" 2>/dev/null)"
echo '```'
printf '  HTTP %s   %s bytes\n' "$C" "$( [ -f "$T/app.json" ] && wc -c < "$T/app.json" | tr -d ' ' || echo 0 )"
echo '```'
echo
if [ "$C" = "200" ] && [ -s "$T/app.json" ]; then
  echo '```'
  node -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const hit = (d.results || []).filter((r) =>
      /PAY ID|ペイアイディー/i.test(r.trackName || "") || /BASE/i.test(r.sellerName || ""));
    const list = hit.length ? hit : (d.results || []).slice(0, 3);
    for (const r of list) {
      console.log("  ── " + r.trackName);
      console.log("     提供      : " + r.sellerName);
      console.log("     カテゴリ   : " + (r.genres || []).join(" / "));
      console.log("     評価      : " + (r.averageUserRating != null ? r.averageUserRating.toFixed(2) : "-") +
                  "（" + (r.userRatingCount || 0) + " 件）");
      console.log("     現行版     : " + r.version + "  更新 " + String(r.currentVersionReleaseDate || "").slice(0, 10));
      console.log("     価格      : " + (r.formattedPrice || "-"));
      console.log("     説明文:");
      console.log(String(r.description || "").split("\n").filter((l) => l.trim())
        .slice(0, 40).map((l) => "       " + l.trim()).join("\n"));
      console.log("");
    }
    if (!list.length) console.log("  **該当が無い**");
  ' "$T/app.json" 2>&1 | clean
  echo '```'
else
  echo "- **取れなかった（HTTP $C）。**"
fi

echo
echo "## 2. 公式サイト \`payid.jp\`"
echo
C2="$(curl -sL -m 25 -A 'Mozilla/5.0' -o "$T/site.html" -w '%{http_code}' "https://payid.jp/" 2>/dev/null)"
echo '```'
printf '  HTTP %s   %s bytes\n' "$C2" "$( [ -f "$T/site.html" ] && wc -c < "$T/site.html" | tr -d ' ' || echo 0 )"
echo '```'
echo
if [ "$C2" = "200" ] && [ -s "$T/site.html" ]; then
  echo '```'
  detag < "$T/site.html" | head -60 | clean | sed 's/^/  /'
  echo '```'
else
  echo "- **取れなかった（HTTP $C2）。**"
fi

echo
echo "## 3. 招待リンクの飛び先（**何が書いてあるページか**）"
echo
C3="$(curl -sL -m 25 -A 'Mozilla/5.0' -o "$T/inv.html" -w '%{http_code}|%{url_effective}' "$INV" 2>/dev/null)"
echo '```'
printf '  HTTP %s\n' "$(printf '%s' "$C3" | cut -d'|' -f1)"
printf '  飛び先 %s\n' "$(printf '%s' "$C3" | cut -d'|' -f2-)"
printf '  %s bytes\n' "$( [ -f "$T/inv.html" ] && wc -c < "$T/inv.html" | tr -d ' ' || echo 0 )"
echo '```'
echo
if [ -s "$T/inv.html" ]; then
  echo '```'
  detag < "$T/inv.html" | head -40 | clean | sed 's/^/  /'
  echo '```'
fi

rm -rf "$T"

echo
echo "---"
echo
echo "## 使い方（**このタスクでは書かない**）"
echo
echo "- **ここに出ている文言・数字だけを紹介文に使う。** 出ていないものは書かない"
echo "- **「500円分」は招待の定型文が根拠**（参考投稿にも同じ文が入っている）"
echo "- 機能を並べるときは **App Store の説明文の語をそのまま**使う。言い換えない"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '説明文:' "$OUT" 2>/dev/null; then
  echo "PAY ID の一次情報を取った / $(basename "$OUT")"
else
  echo "**取れていない。レポートを確認すること** / $(basename "$OUT")"
fi
