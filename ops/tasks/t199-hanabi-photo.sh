#!/bin/bash
# **花火記事の元写真を取り直す（t199）。$0。**
#
# ## なぜ要るか
#
# `tokyo-bay-hanabi-2026` のアイキャッチに **「中央区民の抽選 7/6開始」**
# という**もう終わった日付**が焼き込まれている。開催は 10/24 で、
# いま検索する人に関係あるのは一般先着のほう。9 月は**表示 88・クリック 0** だった。
#
# **記事本文とタイトルは直した**が、画像は作り直すしかない。
# ところが `public/images/tokyo-bay-hanabi-2026/` に**元写真が無い**
# （完成した eyecatch.jpg しか残っていない）。
#
# **画像の中だけで直そうとして 3 回 失敗した。**
#
#   ① 縦方向に補間      → 花火の軌跡が**縦線**になった
#   ② 帯を平坦化        → **四角いもや**として見えた
#   ③ 暗幕を重ねる      → **古い文字が透けた**（最悪）
#
# 全強度で覆おうとすると**花火そのものを消す**ことになる。だから元写真を取る。
#
# ## 取るもの
#
# 記事の source-note に出典が残っている。**当て推量しない。**
#
#   File:Tokyo_bay_fireworks_2015.jpg  （河田 貫成 / CC BY-SA 4.0）
#
# `scripts/fetch-commons-photo.py` がライセンス台帳（`_manifest.json`）ごと記録する。
# **CC BY-SA なので表記は必須**（アイキャッチの左下に出ている行がそれ）。
#
# 取れたら **PR を作らずブランチへ push** する。合成はクラウド側でやる
# （Pillow と IPA ゴシックが在るので 1 往復で済む）。
#
# LLM 不使用・Commons は無料。**$0。** 240 秒 で打ち切る。

set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t199-hanabi-photo.md"
BR="ops/hanabi-photo"
mkdir -p "$RDIR"

{
  echo "# 花火記事の元写真を取り直す（t199・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

[ -d "$REPO/.git" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "⚠️ **Python 3.10 以上が無い**" >> "$OUT"; cat "$OUT"; exit 0; }
"$PY" -c 'import PIL' 2>/dev/null || { echo "⚠️ **Pillow が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

cd "$REPO" || { echo "⚠️ **cd できない**" >> "$OUT"; cat "$OUT"; exit 0; }
git fetch -q origin main 2>/dev/null
git checkout -q -B "$BR" origin/main 2>/dev/null || {
  echo "⚠️ **ブランチを作れない**" >> "$OUT"; cat "$OUT"; exit 0; }

DIR="public/images/tokyo-bay-hanabi-2026/photos"
mkdir -p "$DIR"

run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 3
  done
  wait "$pid" 2>/dev/null
}

LOG="${TMPDIR:-/tmp}/t199-fetch.log"
run_limited 200 "$PY" scripts/fetch-commons-photo.py \
  --file "File:Tokyo_bay_fireworks_2015.jpg" --key hero --dir "$DIR" > "$LOG" 2>&1
RC=$?
{ echo "取得の終了コード **$RC**"; echo ""; echo '```'; head -c 900 "$LOG"; echo; echo '```'; echo ""; } >> "$OUT"

# **rc=0 は取れた証拠にならない**（最上位ルール 13）。実体を見る
F=""
for cand in "$DIR/hero.jpg" "$DIR/hero.jpeg" "$DIR/hero.png"; do
  [ -f "$cand" ] && F="$cand" && break
done
if [ -z "$F" ]; then
  echo "⚠️ **ファイルが無い。** ディレクトリの中身:" >> "$OUT"
  ls -la "$DIR" >> "$OUT" 2>&1
  cat "$OUT"; exit 0
fi
SZ=$(wc -c < "$F" | tr -d ' ')
case "$SZ" in ''|*[!0-9]*) SZ=0 ;; esac
DIM=$("$PY" -c "from PIL import Image;im=Image.open('$F');print(f'{im.size[0]}x{im.size[1]}')" 2>&1)
echo "- 取れた: \`$F\` **${SZ} bytes** / **${DIM}**" >> "$OUT"
# アイキャッチは 1600x900 に切るので、横 1600 以上 無いと拡大になる
W=$(echo "$DIM" | cut -dx -f1)
case "$W" in ''|*[!0-9]*) W=0 ;; esac
if [ "$W" -lt 1600 ]; then
  echo "- ⚠️ **横 ${W}px しかない。** 1600 に満たないので拡大になる" >> "$OUT"
else
  echo "- 横 ${W}px。1600 以上 あるので切り出しで足りる" >> "$OUT"
fi
echo "- ライセンス台帳:" >> "$OUT"
{ echo '```json'; head -c 700 "$DIR/_manifest.json" 2>/dev/null; echo; echo '```'; } >> "$OUT"

git add "$DIR"
if git diff --cached --quiet; then
  echo "" >> "$OUT"; echo "変化なし（もう入っている）。" >> "$OUT"
else
  git -c user.name=openclaw -c user.email=openclaw@local commit -q \
    -m "assets: 花火記事の元写真を Commons から取り直す（t199・CC BY-SA 4.0）"
  ok=0
  for i in 1 2 3 4; do
    git push -q -u origin "$BR" 2>>"$OUT" && ok=1 && break
    sleep $((2 ** i))
  done
  [ "$ok" = "1" ] && echo "" >> "$OUT" && echo "**\`$BR\` へ push した。**" >> "$OUT" \
    || { echo "" >> "$OUT"; echo "⚠️ **push できなかった**" >> "$OUT"; }
fi
git checkout -q main 2>/dev/null || true

{
  echo ""
  echo "---"
  echo ""
  echo "> 合成はクラウド側でやる（Pillow ＋ IPA ゴシックが在る）。"
  echo "> **PR は作っていない。** ブランチに写真を置くところまで。"
  echo ""
  echo "LLM 不使用。Commons は無料。**\$0/回・\$0/日・\$0/月。**"
} >> "$OUT"
cat "$OUT"
