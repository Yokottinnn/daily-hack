#!/bin/bash
# **NG 判定を comment-orchestrator.sh に組み込む。**
#
# ここまでで揃っているもの。
#   - reply-ng-rules.json / reply-ng-check.cjs は実機に配置済み（026 で確認）
#   - 差し込み位置は特定済み。CANDIDATES を作った直後、N= の直前
#
#     CANDIDATES=$(echo "$DETECT_OUT" | node -e "...o.candidates...")
#             ← ここに 1 行入れる
#     N=$(echo "$CANDIDATES" | node -e "...length...")
#
# ## 安全側の作り
#
#   - **既に入っていれば何もしない**（二重挿入しない）
#   - 触る前に .pre-ngfilter.<時刻> へ退避する
#   - 挿入後に bash -n を通す。**通らなければ即座に元へ戻す**
#   - 挿入行が 1 行も入らなかった場合も元へ戻す
#   - フィルタ本体は**壊れたら素通し**する設計。ここで例外を投げると
#     返信ジョブごと落ちるため、判定できないときは候補をそのまま返す
#
# **弾き漏らしはまた拾えるが、ジョブが落ちると何も動かなくなる。**
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/wire-ng.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
S="$W/scripts/comment-orchestrator.sh"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# NG 判定の組み込み（$(date '+%Y-%m-%d %H:%M') JST）"

echo
echo "## 1. 部品を配る"
for pair in "ops/data/reply-ng-rules.json:$W/data/reply-ng-rules.json" \
            "ops/lib/reply-ng-check.cjs:$W/scripts/reply-ng-check.cjs" \
            "ops/lib/ng-filter-candidates.cjs:$W/scripts/ng-filter-candidates.cjs"; do
  src="${pair%%:*}"; dst="${pair#*:}"
  if git -C "$REPO" show "origin/main:$src" > "$dst.tmp" 2>/dev/null && [ -s "$dst.tmp" ]; then
    mv "$dst.tmp" "$dst"
    echo "- $(basename "$dst"): 配置（$(wc -c < "$dst" | tr -d ' ') B）"
  else
    rm -f "$dst.tmp"
    echo "- $(basename "$dst"): **取り出せない**"
  fi
done

NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

echo
echo "## 2. フィルタ単体の動作確認（組み込む前に）"
echo '```'
printf '%s' '[{"id":1,"text":"今日のポイ活の成果"},{"id":2,"text":"パパ活募集中 条件のいい方DMで"},{"id":3,"text":"節約情報 https://lin.ee/abc"},{"id":4,"text":"ふるさと納税の返礼品"}]' \
  | "$NODE_BIN" "$W/scripts/ng-filter-candidates.cjs" 2>&1 >/tmp/ngout.$$ | head -6
echo "残った候補: $("$NODE_BIN" -e "try{console.log(JSON.parse(require('fs').readFileSync('/tmp/ngout.$$','utf8')).length+' 件')}catch(e){console.log('読めない')}")"
rm -f "/tmp/ngout.$$"
echo '```'

echo
echo "## 3. comment-orchestrator.sh への挿入"
echo
if [ ! -f "$S" ]; then
  echo "**$S が無いので中止。**"
  exit 1
fi

if grep -q 'ng-filter-candidates' "$S"; then
  echo "**既に組み込まれている。何もしない。**"
  echo
  echo "該当行:"
  grep -n 'ng-filter-candidates' "$S" | mask | sed 's/^/    /'
else
  cp "$S" "$S.pre-ngfilter.$STAMP"
  echo "- 退避: $(basename "$S").pre-ngfilter.$STAMP"

  # N=$(echo "$CANDIDATES" ... の行の直前に 1 行入れる
  TMPF="${TMPDIR:-/tmp}/orch.$$"
  awk '
    !done && /^N=\$\(echo "\$CANDIDATES"/ {
      print "# 2026-08-27: 売春系などへの返信を弾く。判定できないときは素通しする（ジョブを落とさない）"
      print "CANDIDATES=$(echo \"$CANDIDATES\" | /usr/local/bin/node scripts/ng-filter-candidates.cjs 2>>\"$LOG\")"
      done = 1
    }
    { print }
  ' "$S" > "$TMPF"

  ins="$(grep -c 'ng-filter-candidates' "$TMPF" || true)"
  if [ "$ins" != "1" ]; then
    echo "- **挿入行が ${ins} 行（想定 1 行）。アンカーが見つからないので中止し、元のまま残す。**"
    rm -f "$TMPF"
    echo
    echo "アンカー候補（N= で始まる行）:"
    grep -n '^N=' "$S" | mask | sed 's/^/    /'
  elif ! /bin/bash -n "$TMPF" 2>/dev/null; then
    echo "- **挿入後に構文エラー。元のまま残す。**"
    /bin/bash -n "$TMPF" 2>&1 | mask | head -3 | sed 's/^/    /'
    rm -f "$TMPF"
  else
    cp "$TMPF" "$S"
    rm -f "$TMPF"
    echo "- **組み込んだ**（bash -n 通過）"
    echo
    echo "挿入箇所の前後:"
    echo '```bash'
    grep -n -B3 -A3 'ng-filter-candidates' "$S" | mask | cut -c1-140
    echo '```'
  fi
fi

echo
echo "## 4. 組み込み後の確認"
echo
if /bin/bash -n "$S" 2>/dev/null; then
  echo "- comment-orchestrator.sh の構文: **正常**"
else
  echo "- comment-orchestrator.sh の構文: **エラー。退避から戻すこと**"
fi
if grep -q 'ng-filter-candidates' "$S"; then
  echo "- NG 判定の組み込み: **済み**"
else
  echo "- NG 判定の組み込み: **未**"
fi
echo "- comment-warmup の稼働: $(launchctl list 2>/dev/null | awk '{print $3}' | grep -qx ai.openclaw.comment-warmup && echo 稼働 || echo '**未ロード**')"

echo
echo "## 5. 次の発火で確認すること"
echo
echo "comment-warmup が次に発火したとき、ログに次の行が出れば効いている。"
echo
echo '```'
echo '  ng-filter: N 件すべて通過'
echo '  ng-filter: N 件中 M 件を弾いた (hard=1 link=1)'
echo '```'
echo
echo "直近のログ末尾:"
tail -5 "$W/logs/comment-warmup.log" 2>/dev/null | mask | cut -c1-140 | sed 's/^/    /'
} > "$OUT" 2>&1

if grep -q '組み込み: \*\*済み\*\*' "$OUT" 2>/dev/null; then
  echo "NG判定を組み込んだ / $(basename "$OUT")"
else
  echo "**組み込めていない** / $(basename "$OUT")"
fi
