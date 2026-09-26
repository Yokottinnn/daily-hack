#!/bin/bash
# **PAY ID の画像素材を取って base64 で持ち帰る。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# 告知画像を作るのに素材が無い。**使ってよい素材は決まっている**
# （`x-post-images` スキル §3・最上位ルール 8）。
#
#   使ってよい: **CC0 / ロゴ（商標・識別目的） / App Store 掲載素材 / 自作**
#   使わない  : CC BY / CC BY-SA / 出典表記が要るもの
#
# **PAY ID はアプリなので、App Store 掲載素材（アイコン・スクリーンショット）が使える。**
# 出所の行を出さずに済む（最上位ルール 8「告知画像に出所の行を出さない」）。
#
# **クラウドからは `itunes.apple.com` に出られない**（HTTP 000・connect_rejected）。
#
# ## 踏まないようにする穴（最上位ルール 14）
#
#   `base64 <file>` は macOS で**引数のファイル名を受け付けない**。→ **`base64 < file`**
#   2026-09-20 に、HTTP 200 で 10,265 bytes 取れていたのに **base64 が 1 行も出ず**、
#   レポートだけ正常に見えた。**だから長さを必ず出す。**
#
# ## 取るもの
#
#   ① アプリのアイコン（512px）
#   ② スクリーンショット **先頭 2 枚**（大きすぎるものは飛ばす）
#
# ## やらないこと
#
# **登録しない。投稿しない。書き換えない。LLM も呼ばない（$0）。**
set -uo pipefail

OUT="${OPS_REPORT_DIR:-/tmp}/payid-assets.md"
W="$HOME/.openclaw/workspace"
T="$W/.x153"
MAXB=420000     # 1 ファイルの上限。これを超えたら飛ばす（レポートが膨らむため）

mkdir -p "$T"

{
echo "# PAY ID の画像素材（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **App Store 掲載素材。** 出所の行を出さずに使える（\`x-post-images\` スキル §3）。"

echo
echo "## 1. どの URL を取るか"
echo
C="$(curl -sL -m 25 -o "$T/app.json" -w '%{http_code}' \
  "https://itunes.apple.com/search?term=PAY%20ID&country=jp&entity=software&limit=8" 2>/dev/null)"
echo '```'
printf '  lookup HTTP %s   %s bytes\n' "$C" "$( [ -f "$T/app.json" ] && wc -c < "$T/app.json" | tr -d ' ' || echo 0 )"
echo '```'
if [ "$C" != "200" ] || [ ! -s "$T/app.json" ]; then
  echo
  echo "- **取れなかった。ここで止まる。**"
  rm -rf "$T"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

node -e '
  const fs = require("fs");
  const d = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const r = (d.results || []).find((x) => /^PAY ID/i.test(x.trackName || ""));
  if (!r) { console.error("NOTFOUND"); process.exit(1); }
  const list = [];
  if (r.artworkUrl512) list.push(["icon", r.artworkUrl512]);
  (r.screenshotUrls || []).slice(0, 2).forEach((u, i) => list.push(["shot" + (i + 1), u]));
  fs.writeFileSync(process.argv[2], list.map((p) => p.join("\t")).join("\n") + "\n");
  console.log(list.map((p) => "  " + p[0].padEnd(6) + " " + p[1]).join("\n"));
' "$T/app.json" "$T/urls.tsv" > "$T/urls.txt" 2>"$T/urls.err"
echo
echo "取る URL:"
echo
echo '```'
[ -s "$T/urls.txt" ] && cat "$T/urls.txt" || { echo "  **URL が組めない**"; cat "$T/urls.err" 2>/dev/null | sed 's/^/  /'; }
echo '```'
[ -s "$T/urls.tsv" ] || { echo; echo "- **止まる。**"; rm -rf "$T"; echo; echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"; exit 1; }

echo
echo "## 2. 取得と base64"
echo
echo "> **\`base64 < file\`（stdin）で渡す。** macOS は引数のファイル名を受け付けない。"
echo "> **長さを必ず出す**（rc は証拠にならない・最上位ルール 13）。"
echo
# **末尾に改行が無い最後の 1 行も読む**（最上位ルール 14）
while IFS=$'\t' read -r name url || [ -n "${name:-}" ]; do
  [ -n "${name:-}" ] || continue
  f="$T/$name.bin"
  hc="$(curl -sL -m 30 -o "$f" -w '%{http_code}' "$url" 2>/dev/null)"
  sz=0; [ -f "$f" ] && sz="$(wc -c < "$f" | tr -d ' ')"
  echo "### \`$name\`"
  echo
  echo '```'
  printf '  HTTP %s   %s bytes\n' "$hc" "$sz"
  if [ "$hc" != "200" ] || [ "$sz" -eq 0 ]; then
    echo "  **取れていない。飛ばす。**"
  elif [ "$sz" -gt "$MAXB" ]; then
    printf '  **大きすぎる（上限 %s bytes）。飛ばす。**\n' "$MAXB"
  else
    b64="$(base64 < "$f" | tr -d '\n')"
    printf '  base64 の長さ: %s 文字\n' "${#b64}"
    if [ "${#b64}" -lt 100 ]; then
      echo "  **base64 が空か短すぎる。別の口を試すこと。**"
    fi
  fi
  echo '```'
  if [ "$hc" = "200" ] && [ "$sz" -gt 0 ] && [ "$sz" -le "$MAXB" ]; then
    echo
    echo '```base64'
    printf '%s\n' "$b64" | fold -w 120
    echo '```'
  fi
  echo
done < "$T/urls.tsv"

rm -rf "$T"

echo
echo "---"
echo
echo "## 使い方"
echo
echo "\`\`\`bash"
echo "  # レポートの base64 ブロックを 1 本の文字列にして decode する"
echo "  base64 -d < payid-icon.b64 > public/images/payid-invite/src/icon.png"
echo "\`\`\`"
echo
echo "- **アイコンは商標。改変しない**（余白を落とすのは可）。最上位ルール 17"
echo "- **スクリーンショットは App Store 掲載素材。** 出所の行は出さない"
echo "- \`_manifest.json\` に**取得元 URL と取得日**を残す"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q '```base64' "$OUT" 2>/dev/null; then
  echo "PAY ID の素材を取った / $(basename "$OUT")"
else
  echo "**素材が取れていない。レポートを確認すること** / $(basename "$OUT")"
fi
