#!/bin/bash
# **載せた直後に誰が外しているのかを、実地で捕まえる。費用 $0。**
#
# ## x30 の実測で矛盾が出た（2026-09-12 22:29）
#
#   §1 launchctl load -w   rc=0 / **載ったか: 1 本**   ← 載っている
#   §6 最終確認            **ロード済み: 0 / 8**       ← 消えている
#
# **load は成功していた。載った直後に、何かが外している。**
# ルール 13 に「load は載らない」と書いたが、**それも正確ではなかった。**
# 正しくは **「載るが、すぐ外される」。**
#
# ## 生き残っているのは `tab-guard` ただ 1 本
#
# `t014`（2026-08-30）にこう記録がある。
#
#   tab-guard.js は `ai.openclaw.*` を全部なめて、**自分だけ除外**して unload する。
#   生き残っていたのがちょうど ai.openclaw.tab-guard だけで、com.dailyhack.* は無傷。
#
# **いまの状態と完全に一致する。**（ai.openclaw.* が 1 本 = tab-guard のみ）
#
# ## だから実地で捕まえる
#
#   1. `tab-guard.js` の**全文**を読む（halt の条件・ロックの実体・除外リスト）
#   2. **1 本 載せて、60 秒 待って、生きているかを見る**
#      → 消えていれば **tab-guard が犯人で確定**
#   3. `tab-guard` のログで、その 60 秒の間に何が起きたかを見る
#   4. halt の根拠になっている状態（ロックファイル等）を出す
#
# ## この タスクでは まだ tab-guard を止めない
#
# **非常ブレーキを外すのは、犯人だと確定してから。**
# 確定させる材料を揃えるのが、この タスクの仕事。
#
# **投稿しない。Chrome を触らない。tab-guard を unload しない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/tab-guard-is-unloading.md"
TG="$S/tab-guard.js"
UID_NUM="$(id -u)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 載せた直後に誰が外しているのか"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x30\` の実測で矛盾が出た。"
echo "> **§1: load -w rc=0 / 載ったか 1 本** → **§6: ロード済み 0 / 8**"
echo "> **load は成功していた。載った直後に、何かが外している。**"
echo
echo "生き残っている \`ai.openclaw.*\` は **\`tab-guard\` ただ 1 本**。"
echo "\`t014\`（2026-08-30）の署名と一致する。**実地で捕まえる。**"

# ═══════════ 1. tab-guard の全文 ═══════════
echo
echo "## 1. \`tab-guard.js\` の全文"
echo
echo "推測しない。**halt の条件・ロックの実体・除外リストを全部 読む。**"
echo
echo '```javascript'
if [ -f "$TG" ]; then
  echo "  // $(basename "$TG") — $(wc -l < "$TG" | tr -d ' ') 行 / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$TG" 2>/dev/null)"
  cat -n "$TG" 2>/dev/null | clean
else
  echo "  **無い: $TG**"
fi
echo '```'

# ═══════════ 2. 実地テスト ═══════════
echo
echo "## 2. **1 本 載せて 60 秒 待つ**（これが決定打）"
echo
echo "消えていれば **tab-guard が犯人で確定**。"
echo
echo '```'
T="comment-warmup"
P="$LA/ai.openclaw.$T.plist"
if [ ! -f "$P" ]; then
  echo "  **plist が無い: $P**"
else
  echo "  対象: $T"
  echo "  載せる前: $(launchctl list 2>/dev/null | grep -cF "ai.openclaw.$T") 本"
  launchctl load -w "$P" >/dev/null 2>&1 || true
  sleep 2
  A="$(launchctl list 2>/dev/null | grep -cF "ai.openclaw.$T")"
  echo "  載せた直後（2 秒後）: **${A} 本**"
  echo
  echo "  --- 60 秒 待つ ---"
  for i in 10 20 30 40 50 60; do
    sleep 10
    N="$(launchctl list 2>/dev/null | grep -cF "ai.openclaw.$T")"
    printf '    %2s 秒後: %s 本\n' "$i" "$N"
    if [ "$N" = "0" ] && [ "$A" != "0" ]; then
      echo "    → **消えた。誰かが外している。**"
      break
    fi
  done
  echo
  B="$(launchctl list 2>/dev/null | grep -cF "ai.openclaw.$T")"
  if [ "$A" != "0" ] && [ "$B" = "0" ]; then
    echo "  **結論: 載るが、外される。** tab-guard が有力。"
  elif [ "$A" != "0" ] && [ "$B" != "0" ]; then
    echo "  **結論: 載ったまま生きている。** 外している主は別（または今回は起きなかった）。"
  else
    echo "  **結論: そもそも載らない。** load 自体が効いていない。"
  fi
fi
echo '```'

# ═══════════ 3. その間に tab-guard は何をしたか ═══════════
echo
echo "## 3. その 60 秒に \`tab-guard\` は何をしたか"
echo
echo '```'
for f in "$W"/logs/tab-guard.log "$W"/logs/tabguard.log; do
  [ -f "$f" ] || continue
  echo "  [$(basename "$f")] 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$f" 2>/dev/null)"
  echo "  --- 末尾 25 行 ---"
  tail -25 "$f" 2>/dev/null | cut -c1-175 | sed 's/^/    /' | clean
  echo
done
echo "  --- tab-guard のロード状態 ---"
launchctl list 2>/dev/null | grep -F 'ai.openclaw.tab-guard' \
  | awk '{printf "    PID=%s 最後のrc=%s\n", $1, $2}' || echo "    **未ロード**"
echo
echo "  --- 発火間隔 ---"
PG="$LA/ai.openclaw.tab-guard.plist"
[ -f "$PG" ] && plutil -p "$PG" 2>/dev/null | grep -iE 'Interval|Calendar|Hour|Minute|Program|=>' | head -12 | sed 's/^/    /'
echo '```'

# ═══════════ 4. halt の根拠 ═══════════
echo
echo "## 4. \`tab-guard\` は何を見て halt し続けているのか"
echo
echo '```'
echo "  --- タブ数の記録（いま何枚だと思っているか） ---"
for f in "$W"/data/tab-guard-state.json "$W"/data/tab-state.json "$W"/data/.tab-guard*; do
  [ -e "$f" ] || continue
  echo "  [$(basename "$f")] 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  head -c 400 "$f" 2>/dev/null | sed 's/^/    /' | clean
  echo
done
echo
echo "  --- tab-guard.js が参照するファイル ---"
grep -oE '"[^"]*\.(json|lock|txt)"|`[^`]*\.(json|lock|txt)`' "$TG" 2>/dev/null \
  | tr -d '"`' | sort -u | head -10 | while read -r c; do
  case "$c" in /*) p="$c" ;; *) p="$W/$c" ;; esac
  if [ -e "$p" ]; then printf '    **有る** %-46s %s\n' "$c" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$p" 2>/dev/null)"
  else printf '    無い    %s\n' "$c"; fi
done
echo
echo "  --- いま Chrome のタブは何枚 開いているか ---"
curl -s --max-time 5 http://127.0.0.1:18810/json/list 2>/dev/null \
  | grep -c '"type": *"page"' | sed 's/^/    CDP から見えるページ数: /' \
  || echo "    CDP に繋がらないので数えられない"
echo '```'

echo
echo "---"
echo
echo "## 次にやること（**この結果で決まる**）"
echo
echo "| §2 の結論 | 次の手 |"
echo "| --- | --- |"
echo "| 載るが外される | **tab-guard の halt 状態を解除する**（§1 の全文から解除条件を読む） |"
echo "| 載ったまま生きる | 外していたのは別。**§3 のログで直前に何が動いたかを見る** |"
echo "| そもそも載らない | plist か launchd の問題。**plutil -lint と権限を見る** |"
echo
echo "**tab-guard を止めるのは、犯人だと確定してから。** 非常ブレーキは軽々に外さない。"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（**実測** 9/8=5 件・9/9=3 件） | \$0.003 | \$0.009〜0.015 | 約 \$0.27〜0.45 |"
echo
echo "**tab-guard を unload していない。Chrome も触っていない。投稿もしていない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
C="$(grep -m1 -oE '\*\*結論: [^*]*\*\*' "$OUT" 2>/dev/null | cut -c1-46 || echo '結論 不明')"
echo "**$(date '+%H:%M') 載せた直後に外す主を実地で捕まえた（\$0）** / $C / $(basename "$OUT")"
