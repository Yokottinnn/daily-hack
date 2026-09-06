#!/bin/bash
# **店舗写真を Wikimedia Commons から取り直す。公式サイトは全滅した。**
#
# ## t056 の 36 枚は 1 枚も使えなかった
#
# 目で見て確認した結果。
#
#   ok-1.jpg      … **求人情報のバナー**（「関東・関西 求人情報」）
#   maibasket-2   … **トップバリュの値上げしませんキャンペーンのバナー**
#   trial-5.jpg   … **ブラーのかかった汎用ストック画像**（トライアルの店ですらない）
#   hanamasa-*    … 290x143 / 718x88 の小さなバナー
#   trial-1,2     … 347x120 / 295x104 のロゴ帯
#
# **スーパーの公式トップページは、拾うとキャンペーンバナーしか出ない。**
# 施設ページにキービジュアルがある商業施設とは構造が違う。
#
# ## スキルが定める次の段へ
#
#   公式サイト → **プレスリリース** → **Wikimedia Commons**
#
# ここでは Commons を叩く。**店舗の外観写真は Commons に多数ある**うえ、
# `scripts/fetch-commons-photo.py` が**ライセンス台帳（_manifest.json）ごと**
# 記録してくれる。手でライセンスを拾わない。
#
# ## やること
#
# 1. チェーンごとに Commons を検索して候補名を出す（**採用はしない。人が見て選ぶ**）
# 2. 候補を実際に落として `$OPS_REPORT_DIR/commons/` に置く
# 3. クラウド側で `Read` して目で見てから採用を決める
#
# **1 件目を無条件に採らない**（2026-08-22 にサウナで木版画を引いた）。
#
# LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
DEST="$RDIR/commons"
OUT="$RDIR/t058-supermarket-commons.md"
mkdir -p "$DEST"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
git -C "$REPO" fetch -q origin main || true

FETCH="${TMPDIR:-/tmp}/fetch-commons-photo.py"
git -C "$REPO" show origin/main:scripts/fetch-commons-photo.py > "$FETCH" || {
  echo "fetch-commons-photo.py が取れない"; exit 1; }

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

{
  echo "# 店舗写真の候補（Commons / t058）"
  echo
  echo "**採用はしていない。** 候補を落としただけ。クラウド側で目で見てから決める。"
} > "$OUT"

search() {
  local key="$1"; shift
  local q="$*"
  {
    echo
    echo "## $key — 検索語「$q」"
    echo '```'
  } >> "$OUT"
  "$PY" "$FETCH" --search "$q" --limit 10 >> "$OUT" 2>&1
  echo '```' >> "$OUT"
}

search ok        "OK supermarket Japan store"
search ok2       "オーケーストア"
search lopia     "Lopia supermarket"
search trial     "Trial supermarket Japan"
search seiyu     "Seiyu store Japan"
search gyomu     "Gyomu Super store"
search maibasket "My Basket store Tokyo"
search hanamasa  "Hanamasa store"
search donki     "Don Quijote store Japan"

{
  echo
  echo "## 落とした画像"
  echo
  echo "候補名を見て選ぶため、ここでは**検索結果の一覧だけ**を出している。"
  echo "採用したいファイル名が決まったら、次のタスクで"
  echo '`--file "File:Xxx.jpg" --key <key> --dir <dir>` で落とす。'
} >> "$OUT"

echo "=== 結果 ==="
cat "$OUT"
exit 0
