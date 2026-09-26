#!/bin/bash
# **500 円玉の写真を、権利表記の要らないものだけ取ってくる。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# レビューページのコメント「**500円玉の画像を大きく表示して**」は、
# **実物の硬貨の写真**という意味だった（2026-09-26 にダイアログで確認）。
#
# **クラウドからは Commons に出られない**（`commons.wikimedia.org:443 connect_rejected`）。
#
# ## 使ってよい素材は決まっている（`x-post-images` スキル §3・最上位ルール 8）
#
#   使ってよい: **CC0 / パブリックドメイン** / ロゴ（商標） / App Store 掲載素材 / 自作
#   使わない  : **CC BY / CC BY-SA**（表記がライセンスの条件。出所の行を出さない以上 使えない）
#
# **だから、ライセンスを見てから取る。** 取ってから考えない。
#
# ## 何をするか
#
#   ① Commons を "500 yen coin" で検索し、**1 件ずつライセンスを出す**
#   ② **CC0 / PD のものだけ**を base64 で持ち帰る（最大 2 件）
#   ③ CC BY / CC BY-SA しか無ければ、**そう報告して何も取らない**
#
# ## 踏まないようにする穴（最上位ルール 14）
#
#   `base64 <file>` は macOS で**引数のファイル名を受け付けない**。→ **`base64 < file`**
#   **長さを必ず出す**（rc は証拠にならない・最上位ルール 13）
#
# ## やらないこと
#
# **書き換えない。投稿しない。LLM も呼ばない（$0）。**
set -uo pipefail

OUT="${OPS_REPORT_DIR:-/tmp}/coin-500yen.md"
W="$HOME/.openclaw/workspace"
T="$W/.x155"
MAXB=420000
UA="daily-hack-ops/1.0 (https://daily-hack.fieldbeside.com)"

mkdir -p "$T"

{
echo "# 500 円玉の写真（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **CC0 / パブリックドメインのものだけ持ち帰る。**"
echo "> CC BY / CC BY-SA は表記がライセンスの条件なので、出所の行を出さない以上 使えない。"

echo
echo "## 1. 候補とライセンス"
echo
API="https://commons.wikimedia.org/w/api.php"
Q="action=query&generator=search&gsrsearch=500%20yen%20coin&gsrlimit=25&gsrnamespace=6&prop=imageinfo&iiprop=url%7Cextmetadata&iiurlwidth=900&format=json&formatversion=2"
C="$(curl -sL -m 30 -A "$UA" -o "$T/s.json" -w '%{http_code}' "$API?$Q" 2>/dev/null)"
echo '```'
printf '  HTTP %s   %s bytes\n' "$C" "$( [ -f "$T/s.json" ] && wc -c < "$T/s.json" | tr -d ' ' || echo 0 )"
echo '```'
if [ "$C" != "200" ] || [ ! -s "$T/s.json" ]; then
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
  const pages = (d.query && d.query.pages) || [];
  const rows = [];
  for (const p of pages) {
    const ii = (p.imageinfo || [])[0];
    if (!ii) continue;
    const m = ii.extmetadata || {};
    const lic = ((m.LicenseShortName || {}).value || "").replace(/<[^>]+>/g, "").trim();
    const free = /^(CC0|Public domain|PD)/i.test(lic) || /public domain/i.test(lic);
    const w = ii.thumbwidth || ii.width, h = ii.thumbheight || ii.height;
    rows.push({ title: p.title, lic, free, url: ii.thumburl || ii.url, w, h });
  }
  rows.sort((a, b) => (b.free - a.free) || (b.w * b.h - a.w * a.h));
  for (const r of rows) {
    console.log("  " + (r.free ? "使える " : "使わない") + "  " + (r.lic || "(不明)").padEnd(22) + " " + r.w + "x" + r.h + "  " + r.title);
  }
  const ok = rows.filter((r) => r.free).slice(0, 2);
  fs.writeFileSync(process.argv[2], ok.map((r, i) => ["coin" + (i + 1), r.url, r.title, r.lic].join("\t")).join("\n") + (ok.length ? "\n" : ""));
  console.log("  ---");
  console.log("  使えるもの " + ok.length + " 件 / 候補 " + rows.length + " 件");
' "$T/s.json" "$T/pick.tsv" > "$T/list.txt" 2>"$T/err.txt"
echo
echo '```'
[ -s "$T/list.txt" ] && cat "$T/list.txt" || { echo "  **一覧が作れない**"; head -5 "$T/err.txt" 2>/dev/null | sed 's/^/  /'; }
echo '```'

echo
echo "## 2. 取得と base64（**CC0 / PD のものだけ**）"
echo
if [ ! -s "$T/pick.tsv" ]; then
  echo "- **CC0 / パブリックドメインのものが 1 件も無い。何も取っていない。**"
  echo
  echo "  この場合は **自分で描いたコインの図**に切り替えるのが早い（権利表記が要らない）。"
else
  echo "> **\`base64 < file\`（stdin）で渡す。長さを必ず出す。**"
  echo
  # **末尾に改行が無い最後の 1 行も読む**（最上位ルール 14）
  while IFS=$'\t' read -r name url title lic || [ -n "${name:-}" ]; do
    [ -n "${name:-}" ] || continue
    f="$T/$name.bin"
    hc="$(curl -sL -m 40 -A "$UA" -o "$f" -w '%{http_code}' "$url" 2>/dev/null)"
    sz=0; [ -f "$f" ] && sz="$(wc -c < "$f" | tr -d ' ')"
    echo "### \`$name\`"
    echo
    echo '```'
    printf '  %s\n' "$title"
    printf '  ライセンス: %s\n' "$lic"
    printf '  HTTP %s   %s bytes\n' "$hc" "$sz"
    if [ "$hc" != "200" ] || [ "$sz" -eq 0 ]; then
      echo "  **取れていない。飛ばす。**"
    elif [ "$sz" -gt "$MAXB" ]; then
      printf '  **大きすぎる（上限 %s bytes）。飛ばす。**\n' "$MAXB"
    else
      b64="$(base64 < "$f" | tr -d '\n')"
      printf '  base64 の長さ: %s 文字\n' "${#b64}"
      [ "${#b64}" -lt 100 ] && echo "  **base64 が空か短すぎる。**"
    fi
    echo '```'
    if [ "$hc" = "200" ] && [ "$sz" -gt 0 ] && [ "$sz" -le "$MAXB" ]; then
      echo
      echo '```base64'
      printf '%s\n' "$b64" | fold -w 120
      echo '```'
    fi
    echo
  done < "$T/pick.tsv"
fi

rm -rf "$T"

echo
echo "---"
echo
echo "## 使うときの約束"
echo
echo "- **CC0 / PD なので出所の行は要らない。** それでも \`_manifest.json\` に"
echo "  **取得元 URL・ライセンス・取得日**を残す（どこから来たか言えない画像は使わない）"
echo "- **CC BY / CC BY-SA のものは 1 枚も取っていない。** 表記が要るものは使わない"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q '```base64' "$OUT" 2>/dev/null; then
  echo "500 円玉の写真（CC0/PD）を取った / $(basename "$OUT")"
else
  echo "**CC0/PD の写真が取れていない。レポートを確認すること** / $(basename "$OUT")"
fi
