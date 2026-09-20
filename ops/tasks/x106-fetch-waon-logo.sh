#!/bin/bash
# **WAON POINT のロゴを Mac 経由で取る。費用 $0（LLM を呼ばない）。**
#
# ## なぜ Mac 経由なのか
#
# クラウドセッションからは**外部への HTTPS が全部 塞がれている。**
#
#   ryan-dream.com:443        connect_rejected
#   www.waon.net / www.aeon.co.jp / upload.wikimedia.org   → すべて 000
#
# `x-post-images` スキルにも「Commons はクラウドの egress ポリシーで塞がれている。
# **どうしても実物が要るなら `ops/tasks` 経由で Mac に取らせる**（Mac からは届く）」
# と書いてある。その経路をそのまま使う。
#
# ## なぜ必要か
#
# 記事の一番の結論は「**確実に入る最高額は WAON ポイントの年365円**」。
# 告知画像の 2 枚目はそこを見せる枚で、**利用者から WAON POINT のロゴを指定された。**
#
# リポジトリにある `waon.png` と `point-waon.png` は**電子マネー WAON の
# ワードマーク**で、**WAON POINT の別のマーク**。記事の数字はポイントの話なので、
# ここを取り違えると中身と合わない。
#
# ## 取り方
#
# **base64 にしてレポートへ入れる。** バイナリを直接 commit する経路が無いため。
# クラウド側でデコードして `public/images/walk-poikatsu-2026/` に置く。
# **大きすぎたら入れない**（レポートは公開リポジトリに載る）。
#
# ## やらないこと
#
# **投稿しない。画像を作らない。LLM を呼ばない（$0）。**
set -uo pipefail

URL="https://ryan-dream.com/wp-content/uploads/2024/11/IMG_WAON-POINT30.png"
OUT="${OPS_REPORT_DIR:-/tmp}/waon-logo.md"
TMP="${TMPDIR:-/tmp}/.x106-waon.png"
MAX_BYTES=200000

{
echo "# WAON POINT のロゴを取る"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> クラウドからは外部 HTTPS が**全部 塞がれている**（\`connect_rejected\` / 000）。"
echo "> \`x-post-images\` スキルの「**Mac に取らせる**」経路をそのまま使う。"
echo
echo "**取るだけ。投稿しない。画像も作らない。**"

echo
echo "## 1. 取得"
echo
echo '```'
rm -f "$TMP" 2>/dev/null || true
CODE="$(curl -sSL --max-time 30 -o "$TMP" -w '%{http_code}' "$URL" 2>/dev/null || echo 000)"
echo "  HTTP $CODE"
if [ ! -s "$TMP" ]; then
  echo "  **取れなかった。** Mac からも届いていない。"
  echo "  代わりの入手先を探すか、利用者にファイルを置いてもらう必要がある。"
else
  SZ="$(wc -c < "$TMP" | tr -d ' ')"
  echo "  大きさ: $SZ bytes"
  echo "  種類  : $(file -b "$TMP" 2>/dev/null | cut -c1-90)"
  # **PNG かどうかを実物で確かめる。** 拡張子を信じない
  if head -c 8 "$TMP" | od -An -tx1 2>/dev/null | tr -d ' \n' | grep -qi '^89504e470d0a1a0a'; then
    echo "  PNG の署名: **在る**"
  else
    echo "  PNG の署名: **無い**（HTML のエラーページかもしれない）"
    head -c 200 "$TMP" | tr -d '\0' | sed 's/^/    /'
  fi
fi
echo '```'

echo
echo "## 2. base64"
echo
if [ ! -s "$TMP" ]; then
  echo "**取れていないので出さない。**"
elif [ "$(wc -c < "$TMP" | tr -d ' ')" -gt "$MAX_BYTES" ] 2>/dev/null; then
  echo "**$MAX_BYTES bytes を超えているのでレポートには入れない。**"
  echo "（レポートは公開リポジトリに載るため、無闇に大きいものを積まない）"
else
  echo "クラウド側で次のように戻す。"
  echo
  echo '```bash'
  echo "git show origin/ops/heartbeat:reports/waon-logo.md \\"
  echo "  | sed -n '/^BEGIN_B64\$/,/^END_B64\$/p' | sed '1d;\$d' | tr -d '\\n' \\"
  echo "  | base64 -d > public/images/walk-poikatsu-2026/waon-point.png"
  echo '```'
  echo
  echo '```'
  echo "BEGIN_B64"
  base64 "$TMP" 2>/dev/null
  echo "END_B64"
  echo '```'
fi

echo
echo "## 3. 扱いの注意"
echo
echo "**これはイオンの商標。** 記事とその告知で WAON POINT を指すために使う"
echo "（このリポジトリでは他の記事でも各社のロゴを同じ形で使っている）。"
echo "**CC の写真とは扱いが違うので、\`credit\` は「出典」ではなく商標の表記にする。**"

echo
echo "## 4. 費用"
echo
echo "**1 ファイル 取るだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループは \`MAX_PICKS\` 6 で **約 \$0.95/月（推定）**。実測は明日 確かめる。"
} > "$OUT" 2>&1

rm -f "$TMP" 2>/dev/null || true
echo "WAON POINT ロゴ / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
