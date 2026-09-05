#!/bin/bash
# **動いている 2 本が「フォロバ無し → 外す」をやっているかを確かめる。費用 $0。**
#
# ## なぜこれが先なのか
#
# アンフォロー 8 本のうち **2 本は動いている**。
#
#   reply-followback-check              稼働（rc=0・1:15 と 13:15）
#   auto-detect-and-unfollow-inactive   稼働（22:30）
#
# `reply-followback-check` は 7 日／14 日の定数を持っていた。
# **「フォロバ無し → 外す」の本体がここなら、失敗している 6 本は直さなくてよい。**
#
# **だがこれは私の推測。中身をまだ読んでいない。**
# 推測で「要件を満たしています」と報告するのが一番まずい。**先に読む。**
#
# ## 出すもの（すべて無料・LLM を呼ばない）
#
#   1. `reply-followback-check.js` の**全文**（何日で判定し、実際に unfollow するか）
#   2. `auto-detect-and-unfollow-inactive` が叩くスクリプトの**判定部分**
#   3. 失敗している 6 本が**何を叩く設定か**（機能が重複しているか）
#   4. 直近の実行ログ（**実際にアンフォローした形跡があるか**）
#
# 1 で「unfollow を実行する」コードが見つかれば、**6 本は不要**と判断できる。
# 見つからなければ、6 本のどれが本体かが 3 で分かる。
#
# ## やらないこと
#
# **フォローしない。アンフォローしない。投稿しない。書き換えない。LLM も呼ばない。**
#
# **API キーは値を出さない。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/unfollow-logic.md"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

RFC="$W/scripts/reply-followback-check.js"

{
echo "# アンフォローの本体はどれか（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> 8 本のうち **2 本は動いている**。\`reply-followback-check\` が"
echo "> 「フォロバ無し → 外す」の本体なら、**失敗している 6 本は直さなくてよい。**"
echo "> **推測で「満たしています」と言わない。先に読む。**"
echo "> **書き換えない。フォローもアンフォローもしない。**"

echo
echo "## 1. \`reply-followback-check.js\` 全文"
echo
if [ ! -f "$RFC" ]; then
  echo "- **無い**（$RFC）"
else
  echo "- $(wc -l < "$RFC" | tr -d ' ') 行 / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$RFC" 2>/dev/null)"
  echo
  echo '```javascript'
  cat -n "$RFC" 2>/dev/null | cut -c1-190 | hide | mask
  echo '```'
  echo
  echo "### **実際に unfollow しているか**（判定の要）"
  echo
  echo '```'
  if grep -qiE 'unfollow|フォロー解除|removeFollow' "$RFC" 2>/dev/null; then
    echo "unfollow らしき語: あり"
    grep -niE 'unfollow|フォロー解除|removeFollow' "$RFC" 2>/dev/null | head -12 | cut -c1-170 | mask
  else
    echo "**unfollow らしき語は無い＝この本は判定・記録のみの可能性が高い**"
  fi
  echo '```'
fi

echo
echo "## 2. \`auto-detect-and-unfollow-inactive\` の判定部分"
echo
P="$LA/ai.openclaw.auto-detect-and-unfollow-inactive.plist"
S=""
[ -f "$P" ] && S="$(plutil -extract ProgramArguments json -o - "$P" 2>/dev/null | grep -oE '/[^" ]+\.(js|cjs|sh)' | head -1 || true)"
if [ -n "${S:-}" ] && [ -f "$S" ]; then
  echo "- \`$(basename "$S")\` / $(wc -l < "$S" | tr -d ' ') 行"
  echo
  echo '```javascript'
  grep -nE 'unfollow|DRY_RUN|CAP|LIMIT|DAYS|inactive|followback|フォロバ' "$S" 2>/dev/null \
    | head -25 | cut -c1-180 | hide | mask
  echo '```'
else
  echo "- スクリプトを特定できない"
fi

echo
echo "## 3. 失敗している 6 本は何を叩く設定か（**機能が重複していないか**）"
echo
echo '```'
for j in ai.openclaw.follow-watchdog ai.openclaw.unfollow-daily ai.openclaw.unfollow-evening \
         ai.openclaw.unfollow-cleanup-morning ai.openclaw.unfollow-cleanup-evening ai.openclaw.revenge-unfollow; do
  P="$LA/$j.plist"
  if [ ! -f "$P" ]; then printf '%-38s %s\n' "${j#ai.openclaw.}" "plist なし"; continue; fi
  s="$(plutil -extract ProgramArguments json -o - "$P" 2>/dev/null | grep -oE '/[^" ]+\.(js|cjs|sh)' | head -1 || true)"
  printf '%-38s %s\n' "${j#ai.openclaw.}" "$(basename "${s:-（不明）}")"
done
echo '```'

echo
echo "## 4. 実際にアンフォローした形跡（ログ）"
echo
for f in "$W"/logs/*unfollow*.log "$W"/logs/*followback*.log "$W"/logs/*watchdog*.log; do
  [ -f "$f" ] || continue
  echo "### \`$(basename "$f")\` — 最終更新 **$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)** / $(wc -l < "$f" | tr -d ' ') 行"
  echo
  echo '```'
  tail -10 "$f" 2>/dev/null | cut -c1-170 | hide | mask
  echo '```'
  echo
done

echo
echo "## 5. 状態ファイルにアンフォローの記録があるか"
echo
echo '```'
for f in "$W"/data/*unfollow*.json "$W"/data/reply-followers.json "$W"/data/followed.json; do
  [ -f "$f" ] || continue
  n=$(grep -oc 'unfollow' "$f" 2>/dev/null || echo 0)
  echo "$(basename "$f"): unfollow を含む行 ${n} / 更新 $(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
done
echo '```'

echo
echo "---"
echo
echo "**何も変えていない（\$0）。** 1 で unfollow の実行コードが見つかれば **6 本は不要**。"
echo "見つからなければ、3 の一覧からどれが本体かを決めて直す。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**アンフォローの本体を調べた（変更なし・\$0）** / $(basename "$OUT")"
