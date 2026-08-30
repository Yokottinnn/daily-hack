#!/bin/bash
# **戻した 3 件が「ロード済み」なだけでなく、実際に働いているかを確かめる。読むだけ。**
#
# ## 分かったこと（t014）
#
#   [2026-08-30T14:57:03.141Z] 🚨 Jordan のタブが 19 → 1 枚（一括破壊） → 自動化を全停止
#
# **23:57:03 JST に tab-guard が発火した。** 故障ではなく、**設計どおりの安全装置**である。
# `haltAutomation()` は 3 つのことをする。
#
#   1. **ロックファイルを書く**       fs.writeFileSync(LOCK, "tab-guard")
#   2. `ai.openclaw.*` を unload      （tab-guard 自身は除外）
#   3. 走っている js を pkill
#
# `t012` で 2 は戻した。**しかし 1 のロックは残っているかもしれない。**
#
# > **「ロード済み」と「働いている」は別。** 今日 2 回 これで外している
# > （ポーラーが `last exit code = 127` だった件、`origin/main` と作業ツリーの取り違え）。
#
# ## 見るもの
#
#   1. ロックファイルはどこか（tab-guard.js から読む）。**残っているか**
#   2. Chrome は今どうなっているか（プロセス・タブ数）
#   3. 戻した 3 件は、戻したあと**実際にログを書いたか**
#
# **何も変更しない。ロックも消さない。** 消してよいかは人が決める
# （タブが 1 枚のままなら、解除しても同じことが起きる）。
#
# **ハンドルは伏せる。トークンは出さない。LLM を呼ばない（費用 $0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/halt-lock-and-proof.md"
TG="$W/scripts/tab-guard.js"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -cx "$1" || true; }

{
echo "# 停止ロックと、戻した 3 件が本当に働いているか（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo
echo "> \`23:57:03 JST\` に **タブが 19 → 1 枚**になり、tab-guard が全自動化を停止した。"
echo "> **設計どおりの安全装置。** 故障ではない。"
echo
echo "> **「ロード済み」と「働いている」は別。** 今日 2 回 これで外している。"

echo
echo "## 1. 停止ロックは残っているか"
echo
echo "### tab-guard.js が使うロックの定義"
echo '```javascript'
grep -nE 'LOCK\s*=|HALT|lock' "$TG" 2>/dev/null | head -8 | cut -c1-150 | mask
echo '```'
echo
LOCKS="$(grep -oE '"[^"]*lock[^"]*"|`[^`]*lock[^`]*`' "$TG" 2>/dev/null | tr -d '"`' | head -5)"
FOUND=0
for cand in $LOCKS "$W/data/.halt.lock" "$W/data/halt.lock" "$W/.halt" "/tmp/openclaw-halt"; do
  [ -z "$cand" ] && continue
  case "$cand" in /*) p="$cand" ;; *) p="$W/$cand" ;; esac
  if [ -e "$p" ]; then
    echo "- **残っている**: \`$p\`"
    echo "  - 更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$p" 2>/dev/null)"
    echo "  - 中身: \`$(head -c 100 "$p" 2>/dev/null | tr -d '\n' | mask)\`"
    FOUND=1
  fi
done
[ "$FOUND" = "0" ] && echo "- 上の候補にロックは**見つからなかった**（定義を読み違えている可能性もある）"

echo
echo "## 2. Chrome は今どうなっているか"
echo
if pgrep -f 'remote-debugging-port' >/dev/null 2>&1; then
  echo "- Chrome プロセス: **生きている**"
else
  echo "- Chrome プロセス: **見つからない** ← この状態では自動化は働けない"
fi
PORT="$(grep -oE 'USER_PORT\s*=\s*[0-9]+' "$TG" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
echo "- 監視ポート: \`${PORT:-不明}\`"
if [ -n "$PORT" ]; then
  N="$(curl -s --max-time 5 "http://127.0.0.1:$PORT/json/list" 2>/dev/null \
       | grep -c '"type": *"page"' || echo "?")"
  echo "- **いま開いているタブ: ${N} 枚**（発火時は 19 → 1）"
  echo
  if [ "$N" = "?" ] || [ "${N:-0}" -le 1 ] 2>/dev/null; then
    echo "⚠️ **まだ 1 枚以下、または CDP に届かない。**"
    echo "この状態でロックを外しても、**tab-guard がまた発火するだけ**である。"
  else
    echo "✅ タブは戻っている。**ロックを外す判断ができる状態。**"
  fi
fi

echo
echo "## 3. 戻した 3 件は、戻したあと実際に働いたか"
echo
echo "> \`t012\` が戻したのは **$(date '+%Y-%m-%d') の 01:0x JST 頃**。"
echo "> **それ以降にログが書かれていれば、働いている。**"
echo
echo "| ジョブ | ロード | ログの最終更新 |"
echo "| --- | --- | --- |"
for L in ai.openclaw.comment-warmup ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow; do
  short="${L#ai.openclaw.}"
  lg=""
  for f in "$HOME/.openclaw/logs/$short".*log "$W/logs/$short".*log "$W/logs/$short.log"; do
    [ -f "$f" ] && lg="$f" && break
  done
  if [ -n "$lg" ]; then
    echo "| \`$short\` | $(loaded "$L") | $(stat -f '%Sm' -t '%m-%d %H:%M' "$lg" 2>/dev/null) |"
  else
    echo "| \`$short\` | $(loaded "$L") | **ログが見つからない** |"
  fi
done

echo
echo "### 直近に更新された openclaw のログ（上位 12）"
echo '```'
ls -lt "$HOME/.openclaw/logs"/*.log "$W/logs"/*.log 2>/dev/null \
  | head -12 | awk '{print $6, $7, $8, $9}' | sed "s#$HOME/.openclaw/logs/##; s#$W/logs/##"
echo '```'

echo
echo "## 4. 次の判断"
echo
echo "**何も変更していない。ロックも消していない。**"
echo
echo "- タブが戻っていて、Chrome も生きている → **ロックを外して本格再開してよい**"
echo "- **タブがまだ 1 枚**／Chrome が居ない → **外さない。** また同じことが起きる。"
echo "  先に Chrome を開き直す（＝人がやるほうが早い領域）"
echo "- ロックが見つからない → 定義の読み違い。2 章の \`USER_PORT\` と 1 章の grep を見直す"
echo
echo "**根本の疑問は「なぜタブが 19 → 1 になったか」であり、まだ分かっていない。**"
echo "23:57 JST 前後に何が動いていたかを、次に調べること。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '✅ タブは戻っている' "$OUT" 2>/dev/null; then
  echo "タブは復旧。ロック解除の判断待ち / $(basename "$OUT")"
elif grep -q 'まだ 1 枚以下' "$OUT" 2>/dev/null; then
  echo "⚠️ **タブがまだ戻っていない。ロックは外さないこと** / $(basename "$OUT")"
else
  echo "状態を出した / $(basename "$OUT")"
fi
