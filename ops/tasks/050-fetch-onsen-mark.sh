#!/bin/bash
# **温泉マーク（♨）の実物を Wikimedia Commons から取る。**
#
# Jordan の指示: 「温泉マークも取得してきて」→「Commons の実物を Mac に取らせる」
#
# ## なぜ Mac に頼むのか
#
# クラウドセッションからは egress ポリシーで届かない。
#
#   commons.wikimedia.org:443 — connect_rejected
#     (the egress proxy denied the CONNECT (organization policy))
#
# **Mac からは届く**（記事の写真は全部この経路で取っている）。
#
# ## 取り方
#
# `scripts/fetch-commons-photo.py` を使う。**手で URL を叩かない。**
# このスクリプトは `_manifest.json` に artist / lic / page を記録するので、
# **出典を後から確実に書ける。** 手作業で拾うと台帳が欠ける。
#
# ## 当て推量でファイルを作らない
#
# 候補が見つからなければ、検索結果を並べて `exit 1` する。
# **「たぶんこれ」で別の画像を置かない。**
#
# **出力は公開リポジトリに載る。** 秘密は出さない。**LLM を呼ばない（費用 $0）。**
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/onsen-mark.md"
DIR="public/images/common/marks"
BR="ops/onsen-mark-$(date -u +%Y%m%d-%H%M%S)"
PY="$(command -v python3.11 || command -v python3)"

{
echo "# 温泉マークを Commons から取る（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> クラウド側は egress ポリシーで Commons に届かない。**Mac から取る。**"
echo "> \`fetch-commons-photo.py\` を使うので \`_manifest.json\` に出典が残る。"

cd "$REPO" 2>/dev/null || { echo "**$REPO へ移動できない。中止。**"; exit 1; }
git fetch -q origin main 2>/dev/null && git checkout -q -B "$BR" origin/main 2>/dev/null \
  || { echo "**ブランチを作れない。中止。**"; exit 1; }
echo
echo "- 作業ブランチ: \`$BR\`"
echo "- python: $PY"

echo
echo "## 1. 候補を探す"
echo
echo '```'
"$PY" scripts/fetch-commons-photo.py --search "Japanese Map symbol Hot spring" --limit 10 2>&1 | head -20
echo '```'

echo
echo "## 2. 取得する"
echo
mkdir -p "$DIR"
# **狙いは JIS の地図記号（パブリックドメイン）。** 順に試して最初に取れたものを使う
GOT=""
for f in "File:Japanese Map symbol (Hot spring).svg" \
         "File:Hot spring symbol.svg" \
         "File:Japanese Map symbol (Hot spring) w.svg"; do
  echo "- 試す: \`$f\`"
  if "$PY" scripts/fetch-commons-photo.py --file "$f" --key onsen --dir "$DIR" >/dev/null 2>&1; then
    if ls "$DIR"/onsen.* >/dev/null 2>&1; then
      GOT="$(ls "$DIR"/onsen.* | head -1)"
      echo "  → **取れた**: \`$GOT\`（$(wc -c < "$GOT" | tr -d ' ') B）"
      break
    fi
  fi
  echo "  → 取れない"
done

if [ -z "$GOT" ]; then
  echo
  echo "**どれも取れなかった。当て推量で別の画像を置かない。**"
  echo "上の検索結果から、使えそうなファイル名を人が選んで指定すること。"
  exit 1
fi

echo
echo "## 3. 出典（\`_manifest.json\` に記録された内容）"
echo
echo '```json'
cat "$DIR/_manifest.json" 2>/dev/null | head -20
echo '```'
echo
echo "**この artist / lic / page を画像の中に焼き込む**（X では画像だけが独り歩きする）。"

echo
echo "## 4. push"
echo
git add "$DIR" 2>/dev/null
if git diff --cached --quiet 2>/dev/null; then
  echo "- 差分が無い。push しない"
else
  git -c user.name=ops-heartbeat -c user.email=ops@daily-hack.local \
      commit -q -m "chore: 温泉マーク（♨）を Commons から取得

クラウドセッションからは egress ポリシーで commons.wikimedia.org に届かないため、
Mac 側の ops/tasks で取得した。fetch-commons-photo.py を使ったので
_manifest.json に artist / lic / page が記録されている。

X 告知画像の右上に置く。出典は画像の中に焼き込む。" 2>&1 | tail -2
  if git push -q -u origin "$BR" 2>&1 | tail -2; then
    echo "- **push した**: \`$BR\`"
  else
    echo "- **push に失敗**"
  fi
fi

echo
echo "## 5. 次にすること"
echo
echo "- \`$BR\` から PR を作ってマージする"
echo "- \`scripts/gen-x-cards.mjs\` の \`ONSEN_MARK\`（SVG 直書き）を、取得した画像に差し替える"
echo "- **出典表記を画像に入れる。** SVG 直書きのときは不要だったが、Commons の実物には要る"
} > "$OUT" 2>&1

if grep -q '取れた' "$OUT" 2>/dev/null; then
  echo "温泉マークを取得した / $(basename "$OUT")"
else
  echo "**取得できていない** / $(basename "$OUT")"
fi
