#!/bin/bash
# **返信の新しい部品を Mac に入れる。置くだけ。費用 $0。**
#
# ## 番号について
#
# **`t0NN` は blog3 と衝突する**（同じ日に t056/t057/t058/t059 を両方が作った）。
# ファイル名が違うので実行は衝突しないが紛らわしいので、
# **tweet2 のタスクは以後 `x` 始まりにする。**
#
# ## これは何をするか
#
# リポジトリの `ops/lib/*.cjs` と `ops/data/reply-*.json` を
# **`~/.openclaw/workspace/` へ配置する。**
#
#   ops/lib/asuka-reply.cjs            → scripts/asuka-reply.cjs
#   ops/lib/reply-relevance-check.cjs  → scripts/reply-relevance-check.cjs
#   ops/lib/tone-gate.cjs              → scripts/tone-gate.cjs
#   ops/lib/reply-tone-check.cjs       → scripts/reply-tone-check.cjs
#   ops/lib/ng-filter-candidates.cjs   → scripts/ng-filter-candidates.cjs
#   ops/lib/reply-ng-check.cjs         → scripts/reply-ng-check.cjs
#   ops/data/reply-style-prompt.json   → data/reply-style-prompt.json
#   ops/data/reply-*-rules.json        → data/
#
# ## なぜ置くだけで安全なのか
#
# **`comment-warmup` は未ロードのまま。** このタスクはジョブを触らない。
# 置いたファイルは、`comment-orchestrator.sh` が呼ばない限り 1 行も実行されない。
# **配線は次のタスクで、実物を読んだうえで行う。**
#
# ## 上書きする前に必ず退避する
#
# 既にあるものは `.bak.<日時>` に退避してから置く。**元に戻せる状態を残す。**
# 中身が同一なら**何もしない**（無駄な .bak を作らない）。
#
# ## やらないこと
#
# **返信を生成しない。投稿しない。ジョブを load しない。LLM を呼ばない。**
# **`comment-orchestrator.sh` を書き換えない**（配線は次のタスク）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/install-reply-parts.md"
STAMP="$(date +%Y%m%d-%H%M%S)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

# 置く: $1=リポジトリ内パス  $2=置き先の絶対パス
place() {
  local src="$1" dst="$2" name; name="$(basename "$dst")"
  local tmp="$dst.new.$STAMP"
  if ! git -C "$REPO" show "origin/main:$src" > "$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then
    printf '  **取れない**  %-34s（origin/main:%s）\n' "$name" "$src"
    rm -f "$tmp"; return 1
  fi
  if [ -f "$dst" ] && cmp -s "$dst" "$tmp"; then
    printf '  同一・据置    %-34s %s B\n' "$name" "$(wc -c < "$dst" | tr -d ' ')"
    rm -f "$tmp"; return 0
  fi
  if [ -f "$dst" ]; then
    cp -p "$dst" "$dst.bak.$STAMP"
    printf '  **置換**      %-34s %s → %s B（退避 .bak.%s）\n' \
      "$name" "$(wc -c < "$dst.bak.$STAMP" | tr -d ' ')" "$(wc -c < "$tmp" | tr -d ' ')" "$STAMP"
  else
    printf '  **新規**      %-34s %s B\n' "$name" "$(wc -c < "$tmp" | tr -d ' ')"
  fi
  mv "$tmp" "$dst"
  return 0
}

{
echo "# 返信の部品を Mac に入れる（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **置くだけ。** ジョブは触らない（\`comment-warmup\` は未ロードのまま）。"
echo "> 置いたファイルは \`comment-orchestrator.sh\` が呼ばない限り 1 行も実行されない。"
echo "> **配線は次のタスクで、実物を読んだうえで行う。**"
echo "> 既存は \`.bak.$STAMP\` に退避する。**元に戻せる状態を残す。**"

echo
echo "## 0. 置く前の状態"
echo
echo '```'
for f in asuka-reply.cjs reply-relevance-check.cjs tone-gate.cjs \
         reply-tone-check.cjs ng-filter-candidates.cjs reply-ng-check.cjs; do
  if [ -f "$S/$f" ]; then
    printf '  有り  scripts/%-32s %6s B  更新 %s\n' "$f" "$(wc -c < "$S/$f" | tr -d ' ')" \
      "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$S/$f" 2>/dev/null)"
  else
    printf '  **無し** scripts/%-29s\n' "$f"
  fi
done
for f in reply-style-prompt.json reply-relevance-rules.json reply-ng-rules.json reply-tone-rules.json; do
  if [ -f "$D/$f" ]; then
    printf '  有り  data/%-35s %6s B  更新 %s\n' "$f" "$(wc -c < "$D/$f" | tr -d ' ')" \
      "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$D/$f" 2>/dev/null)"
  else
    printf '  **無し** data/%-32s\n' "$f"
  fi
done
echo '```'

echo
echo "## 1. リポジトリを最新にする"
echo
git -C "$REPO" fetch -q origin main 2>/dev/null || true
echo '```'
echo "  origin/main: $(git -C "$REPO" log --oneline -1 origin/main 2>/dev/null | cut -c1-70)"
echo '```'

echo
echo "## 2. 置く"
echo
mkdir -p "$S" "$D"
echo '```'
FAIL=0
for f in asuka-reply.cjs reply-relevance-check.cjs tone-gate.cjs \
         reply-tone-check.cjs ng-filter-candidates.cjs reply-ng-check.cjs; do
  place "ops/lib/$f" "$S/$f" || FAIL=1
done
for f in reply-style-prompt.json reply-relevance-rules.json reply-ng-rules.json reply-tone-rules.json; do
  place "ops/data/$f" "$D/$f" || FAIL=1
done
echo '```'

echo
echo "## 3. 置いたものが壊れていないか（**構文を通す**）"
echo
echo "**置いただけで安心しない。** 読み込めないファイルは、呼ばれた瞬間に落ちる。"
echo
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
echo '```'
for f in asuka-reply.cjs reply-relevance-check.cjs tone-gate.cjs \
         reply-tone-check.cjs ng-filter-candidates.cjs reply-ng-check.cjs; do
  [ -f "$S/$f" ] || { printf '  —      %s（無い）\n' "$f"; continue; }
  if "$NODE_BIN" --check "$S/$f" 2>/dev/null; then
    printf '  構文OK  %s\n' "$f"
  else
    printf '  **構文NG** %s\n' "$f"; FAIL=1
    "$NODE_BIN" --check "$S/$f" 2>&1 | head -3 | sed 's/^/      /' | clean
  fi
done
for f in reply-style-prompt.json reply-relevance-rules.json reply-ng-rules.json reply-tone-rules.json; do
  [ -f "$D/$f" ] || { printf '  —      %s（無い）\n' "$f"; continue; }
  if "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$D/$f" 2>/dev/null; then
    printf '  JSON OK %s\n' "$f"
  else
    printf '  **JSON NG** %s\n' "$f"; FAIL=1
  fi
done
echo '```'

echo
echo "## 4. \`asuka-reply.cjs\` が要るものは揃っているか"
echo
echo "**require の相手が無ければ、呼ばれた瞬間に落ちる。**"
echo
echo '```'
if [ -f "$S/asuka-reply.cjs" ]; then
  grep -oE 'require\("\./[^"]+"\)' "$S/asuka-reply.cjs" 2>/dev/null | sed 's/require("\.\///; s/")//' | sort -u | while read -r r; do
    if [ -f "$S/$r" ]; then printf '  有り  %s\n' "$r"; else printf '  **無し** %s\n' "$r"; fi
  done
  echo ""
  echo "  参照している data:"
  grep -oE '"[^"]*data/[^"]+"' "$S/asuka-reply.cjs" 2>/dev/null | tr -d '"' | sort -u | while read -r r; do
    b="$(basename "$r")"
    if [ -f "$D/$b" ]; then printf '  有り  data/%s\n' "$b"; else printf '  **無し** data/%s\n' "$b"; fi
  done
else
  echo "  asuka-reply.cjs が無い"
fi
echo '```'

echo
echo "## 5. ジョブは触っていないことの確認"
echo
echo '```'
echo "  comment-warmup: $(launchctl list 2>/dev/null | grep -F 'comment-warmup' || echo '**未ロード（触っていない）**')"
echo '```'

echo
echo "---"
echo
if [ "$FAIL" = "0" ]; then
  echo "**部品はすべて置けて、構文も通った。** 次は配線（\`comment-orchestrator.sh\`）。"
else
  echo "**置けなかった／壊れているものがある。** 上を読むこと。**配線に進まない。**"
fi
echo
echo "**返信を生成していない。投稿していない。ジョブも触っていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '部品はすべて置けて' "$OUT" 2>/dev/null; then
  echo "**返信の部品を Mac に入れた（構文OK・ジョブ未起動・\$0）** / $(basename "$OUT")"
else
  echo "**部品を入れきれていない。レポートを読むこと** / $(basename "$OUT")"
fi
