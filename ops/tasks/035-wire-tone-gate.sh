#!/bin/bash
# **出口の検査を comment-orchestrator.sh に差し込む。**
#
# ここまでで揃っているもの。
#   - tone-gate.cjs / reply-tone-check.cjs / reply-tone-rules.json（#242 でマージ済み）
#   - 実際に X へ出た 15 件で判定を検証済み
#
# ## 差し込む場所
#
#   GEN_OUT=$(echo "$GEN_INPUT" | RECENT_TEMPLATE_IDS=... node scripts/asuka-fill.js 2>&1)
#           ← ここの直後に 1 行入れる
#   （中略）
#   ENQ_RES=$(echo "$ENQUEUE_PAYLOAD" | node scripts/queue-manager.js enqueue 2>&1)
#
# **変数名を決め打ちしない。** asuka-fill.js を呼んでいる行から代入先の変数名を
# 読み取って、その変数を通す。インデントも元の行に合わせる。
#
# ## 2>&1 で stderr が混ざる件は解決済み
#
# 呼び出し元は `asuka-fill.js 2>&1` なので、入力は「ログの雑音 + JSON」になりうる。
# tone-gate は**末尾の釣り合った { … } を探して、そこだけを判定・差し替える**ので、
# 前後の雑音は保たれる。丸ごと JSON.parse して常に素通し、にはならない。
#
# ## 安全側の作り（028 と同じ）
#
#   - **既に入っていれば何もしない**（二重挿入しない）
#   - 触る前に .pre-tonegate.<時刻> へ退避する
#   - 挿入後に bash -n を通す。**通らなければ即座に元へ戻す**
#   - 挿入行がちょうど 1 行でなければ元へ戻す
#   - tone-gate 自体が**設備の故障では素通し**する設計。ここで例外を投げると
#     返信ジョブごと落ちるため、判定できないときは入力をそのまま返す
#
# **弾き漏らしはまた拾えるが、ジョブが落ちると何も動かなくなる。**
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
# **plutil -extract は使わない。** LLM を呼ばない（費用 $0）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/wire-tone-gate.md"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
S="$W/scripts/comment-orchestrator.sh"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# 出口の検査を差し込む（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> ng-filter が入口なら、これが出口。**紹介コードはここで止まる。**"

echo
echo "## 1. 部品を配る"
echo
for pair in "ops/data/reply-tone-rules.json:$W/data/reply-tone-rules.json" \
            "ops/lib/reply-tone-check.cjs:$W/scripts/reply-tone-check.cjs" \
            "ops/lib/tone-gate.cjs:$W/scripts/tone-gate.cjs"; do
  src="${pair%%:*}"; dst="${pair#*:}"
  if git -C "$REPO" show "origin/main:$src" > "$dst.tmp" 2>/dev/null && [ -s "$dst.tmp" ]; then
    mv "$dst.tmp" "$dst"
    echo "- $(basename "$dst"): 配置（$(wc -c < "$dst" | tr -d ' ') B）"
  else
    rm -f "$dst.tmp"
    echo "- $(basename "$dst"): **取り出せない**"
  fi
done

# tone-gate は ../data/reply-tone-rules.json を見る。実機は scripts/ と data/ が
# 兄弟なので、その相対関係はそのまま成立する
echo
echo "配置先の関係: scripts/tone-gate.cjs → ../data/reply-tone-rules.json"
[ -f "$W/data/reply-tone-rules.json" ] && echo "  ルール: 有り" || echo "  ルール: **無い**"

echo
echo "## 2. 単体で動くか（差し込む前に）"
echo
echo '```'
printf '%s' 'trend: 7 candidates
{"ok":true,"text":"紹介コード ZOAQ61 入力してで頑張りなさいよ💪","template_id":"T11"}' \
  | "$NODE_BIN" "$W/scripts/tone-gate.cjs" 2>&1 | mask | cut -c1-140 | head -6
echo "--- 通るはずの文 ---"
printf '%s' '{"ok":true,"text":"コツコツ積立買い😉 大事よね","template_id":"T30"}' \
  | "$NODE_BIN" "$W/scripts/tone-gate.cjs" 2>&1 | mask | cut -c1-140 | head -4
echo '```'

echo
echo "## 3. comment-orchestrator.sh への挿入"
echo
if [ ! -f "$S" ]; then
  echo "**$S が無いので中止。**"
  exit 1
fi

if grep -q 'tone-gate' "$S"; then
  echo "**既に組み込まれている。何もしない。**"
  echo
  grep -n 'tone-gate' "$S" | mask | sed 's/^/    /'
else
  # asuka-fill.js を呼んでいる行から代入先の変数名を取る。決め打ちしない
  VAR="$(grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\$\(.*asuka-fill\.js' "$S" 2>/dev/null \
        | head -1 | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/')"
  if [ -z "$VAR" ]; then
    echo "- **asuka-fill.js への代入行が見つからないので中止し、元のまま残す。**"
    echo
    echo "asuka-fill を含む行:"
    grep -n 'asuka-fill' "$S" | mask | cut -c1-150 | sed 's/^/    /'
  else
    echo "- 代入先の変数: \`$VAR\`"
    cp "$S" "$S.pre-tonegate.$STAMP"
    echo "- 退避: $(basename "$S").pre-tonegate.$STAMP"

    TMPF="${TMPDIR:-/tmp}/orch-tg.$$"
    awk -v var="$VAR" '
      { print }
      !done && $0 ~ /asuka-fill\.js/ && $0 ~ ("^[ \t]*" var "=") {
        # 元の行のインデントに合わせる
        match($0, /^[ \t]*/)
        ind = substr($0, 1, RLENGTH)
        print ind "# 2026-08-28: 紹介コード・URL・見下しなどを送る前に弾く。判定できないときは素通しする"
        print ind var "=$(printf %s \"$" var "\" | /usr/local/bin/node scripts/tone-gate.cjs 2>>\"$LOG\")"
        done = 1
      }
    ' "$S" > "$TMPF"

    ins="$(grep -c 'tone-gate' "$TMPF" || true)"
    if [ "$ins" != "1" ]; then
      echo "- **挿入行が ${ins} 行（想定 1 行）。中止し、元のまま残す。**"
      rm -f "$TMPF"
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
      grep -n -B3 -A3 'tone-gate' "$S" | mask | cut -c1-150
      echo '```'
    fi
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
grep -q 'tone-gate' "$S" && echo "- 出口の検査: **組み込み済み**" || echo "- 出口の検査: **未**"
grep -q 'ng-filter-candidates' "$S" && echo "- 入口の検査: **組み込み済み**" || echo "- 入口の検査: **未**"
echo "- comment-warmup の稼働: $(launchctl list 2>/dev/null | awk '{print $3}' | grep -qx ai.openclaw.comment-warmup && echo 稼働 || echo '**未ロード**')"

echo
echo "## 5. 次の発火で確認すること"
echo
echo "12:00 / 16:00 / 19:00 / 22:00 JST の発火で、ログに次のどれかが出れば効いている。"
echo
echo '```'
echo '  tone-gate: 通過'
echo '  tone-gate: 送るが記録する (command=なさいよ)'
echo '  tone-gate: **送らない** (referral=紹介コード)'
echo '```'
echo
echo "直近のログ末尾:"
tail -8 "$W/logs/comment-warmup.log" 2>/dev/null | mask | cut -c1-140 | sed 's/^/    /'
} > "$OUT" 2>&1

if grep -q '出口の検査: \*\*組み込み済み\*\*' "$OUT" 2>/dev/null; then
  echo "出口の検査を組み込んだ / $(basename "$OUT")"
else
  echo "**組み込めていない** / $(basename "$OUT")"
fi
