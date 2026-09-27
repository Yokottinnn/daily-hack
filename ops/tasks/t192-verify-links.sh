#!/bin/bash
# **リンクの死活を取り直し、怪しいものは実ブラウザで裏を取る（t192）。LLM 不使用・$0。**
#
# ## t191 の結果は、そのままでは報告できない
#
# 「切れている 43 件」と出たが、**生きているサイトが混ざっていた。**
#
# | 出た判定 | 実際 |
# | --- | --- |
# | `https://www.furusato-tax.jp/` → 404 | **ふるさとチョイスは生きている** |
# | `https://ahamo.com/` → つながらない | **ahamo は生きている** |
# | `https://www.paypay-card.co.jp/` → 404 | **PayPayカードは生きている** |
#
# WAF が bot に 404 を返しているだけ。**curl の判定だけで「切れている」と書かない**
# （最上位ルール 11）。
#
# ## もう 1 つ、抽出が壊れていた
#
# **括弧つきの URL が途中で切れて、生きているのに 404 に見えていた。**
# Commons の `File:LaLaport_AICHI_TOGO_(1),_…` など 6 本。
# `scripts/check-external-links.mjs` の抽出を直した（Markdown リンクと href を先に見る）。
#
# ## この回でやること
#
#   ① **取り直す**（抽出を直した版で全件）
#   ② **怪しいものだけ実ブラウザで開いて title を見る**
#      `403` は最初から除く（bot を弾いているだけで、開いても同じ）
#
# **判定は title で行う。** HTTP の番号より、ページが何と名乗っているかのほうが確か。
# `bang.co.jp/auto/` はこれで "404 Not Found" だと分かった。
#
# ## X 運用の Chrome を借りるだけ
#
# 新しいタブを開いて必ず閉じる。**`browser.close()` を呼ばない**（利用者の Chrome ごと落ちる）。
#
# **540 秒 で打ち切る。** ①と②の 2 段あるので長め。**それでも 1 タスク 5 分 の目安は超える**ので、
# ②は自分の予算（260 秒）で畳み、残りは次の回に回す作りにしてある。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t192-verify-links.md"
JSON="$RDIR/external-links.json"
VJSON="$RDIR/external-links-verified.json"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
PORT="${CDP_PORT:-18810}"

{
  echo "# リンクの死活を取り直す ＋ 実ブラウザで裏を取る（t192・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**curl の判定だけで「切れている」と書かない**（最上位ルール 11）。"
  echo "t191 では **生きているサイトが 404 として並んだ**（WAF が bot に返していた）。"
  echo ""
} > "$OUT"

[ -d "$REPO" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
command -v node >/dev/null 2>&1 || { echo "⚠️ **node が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

get() {  # $1=リポジトリ内のパス $2=保存先
  ( cd "$REPO" && git show "origin/main:$1" ) > "$2" 2>/dev/null
  local n; n=$(wc -c < "$2" | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  [ "$n" -ge 1500 ]
}
( cd "$REPO" && git fetch -q origin main 2>/dev/null ) || true
S1="$RDIR/.t192-check.mjs"; S2="$RDIR/.t192-verify.mjs"
get scripts/check-external-links.mjs "$S1" || { echo "⚠️ **check スクリプトを取り出せない**" >> "$OUT"; cat "$OUT"; exit 0; }
get scripts/verify-dead-links.mjs   "$S2" || { echo "⚠️ **verify スクリプトを取り出せない**" >> "$OUT"; cat "$OUT"; exit 0; }

START=$(date +%s)
# **`env -C` を使わない**（macOS に在るか確かめていない・最上位ルール 14）。
# サブシェルの `cd` なら確実。`timeout` も macOS に無いので素の bash で待つ
run_limited() {  # $1=秒 $2=作業ディレクトリ …残り=コマンド
  local lim="$1" wd="$2"; shift 2
  ( cd "$wd" && "$@" ) &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 3
  done
  wait "$pid" 2>/dev/null
}

# --- ① 取り直す（**抽出を直した版**） ---
rm -f "$JSON"
{ echo "## ① curl で全件（抽出を直した版）"; echo ""; echo '```'; } >> "$OUT"
run_limited 280 "$REPO" node "$S1" --budget=260 --conc=8 --out="$JSON" >> "$OUT" 2>&1
echo '```' >> "$OUT"

# --- ② 怪しいものだけ実ブラウザで ---
{ echo ""; echo "## ② 実ブラウザで裏を取る（**403 は除く**）"; echo ""; } >> "$OUT"
VER="$(curl -sS --max-time 5 "http://127.0.0.1:$PORT/json/version" 2>/dev/null || true)"
PWDIR=""
for d in "$REPO/node_modules" "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do
  [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }
done
if [ -z "$VER" ] || [ -z "$PWDIR" ] || [ ! -f "$JSON" ]; then
  echo "- **CDP か playwright-core か ① の結果が無いので、この段は通していない**" >> "$OUT"
else
  { echo '```'; } >> "$OUT"
  PW_DIR="$PWDIR" CDP_PORT="$PORT" \
    run_limited 280 "$REPO" node "$S2" --in="$JSON" --out="$VJSON" --budget=260 >> "$OUT" 2>&1
  echo '```' >> "$OUT"
fi
rm -f "$S1" "$S2"

# --- **`rc=0` を証拠にしない**（最上位ルール 13）。JSON を parse して数える ---
say() {  # $1=ラベル $2=JSON $3=数える式
  if [ -f "$2" ]; then
    node -e "try{const d=JSON.parse(require('fs').readFileSync('$2','utf8'));console.log('$1: '+($3))}catch(e){console.log('$1: parse-error')}" 2>/dev/null \
      || echo "$1: 読めない"
  else
    echo "$1: **出ていない**"
  fi
}
{
  echo ""
  echo "---"
  echo ""
  say "curl で見た件数" "$JSON" "d.results.length+'/'+d.total" 
  say "実ブラウザで見た件数" "$VJSON" "d.out.length+'/'+d.suspects"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "**DEAD と書かれたものだけが「切れている」。** ALIVE は curl の誤判定なので記事は直さない。"
  echo "**OPEN_FAILED は生死が分からない**（そう書く。切れていることにしない）。"
} >> "$OUT"

cat "$OUT"
