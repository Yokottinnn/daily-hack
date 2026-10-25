#!/bin/bash
# **3 店ボタンの Mac 側の準備・10 回目（t343・affiliate）。** 2026-10-25 に利用者の指示で blog3 から affiliate が引き取った。LLM 不使用・**$0**。
#   ① 楽天: t341 でアイコンを押しても伏せ字のまま → アイコンはコピーのボタンとみて、クリップボードから読む（値は Keychain に入れるだけ）
#   ② もしも: t341 で daily-hack がメディアとして未登録と分かった → 「メディアを登録する」を押し、登録の画面の欄と選択肢を読む（**送らない**）
#   ③ Yahoo!: 利用者がログインしたかを読む（送らない）
# 本体は scripts/shop/mac-setup.mjs（origin/main から取り出す）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t343-shop-mac-setup.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# 3 店ボタンの Mac 側の準備・10 回目（t343・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
[ -n "$NODE_BIN" ] || { echo "⚠️ node が無い" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
SYNC="$RDIR/.asp-sync.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
JS="$RDIR/.shop-mac-setup.mjs"; git -C "$REPO" show origin/main:scripts/shop/mac-setup.mjs > "$JS"
[ -s "$JS" ] || { echo "⚠️ scripts/shop/mac-setup.mjs が main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
echo '```text' >> "$OUT"
# ログインを保つ（切れていれば Keychain で入り直す）
# macOS の /bin/bash 3.2 でも子に渡るよう、サブシェルで export する
( export ASP_ONLY=rakuten,moshimo OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=100000; run_limited 120 "$NODE_BIN" "$SYNC" ) >> "$OUT" 2>&1
echo '```' >> "$OUT"
mkdir -p "$RDIR/shop-setup"
for m in rakuten moshimo-media; do
  rm -f "$RDIR/shop-setup/$m.md"  # 前の回の出力を今回の結果と取り違えない
  ( export SHOP_SETUP="$m" OPS_REPORT_DIR="$RDIR"; run_limited 300 "$NODE_BIN" "$JS" ) > "$RDIR/shop-setup/$m.log" 2>&1
  echo "- $m: rc=$?" >> "$OUT"
  [ -s "$RDIR/shop-setup/$m.log" ] && { echo "  - ログの末尾:"; tail -n 6 "$RDIR/shop-setup/$m.log" | sed "s/[A-Za-z0-9_-]\{24,\}/［伏せた］/g" | sed "s/^/    /"; } >> "$OUT"
  cat "$RDIR/shop-setup/$m.md" >> "$OUT" 2>/dev/null || echo "（$m の出力が無い）" >> "$OUT"
  echo "" >> "$OUT"
done
echo "rc=0 / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 7000 "$OUT"
