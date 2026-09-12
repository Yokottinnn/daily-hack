#!/bin/bash
# **【復旧】止まった X 自動化を、証拠を取りながら安全に戻す。費用 $0。**
#
# ## いまの状態（2026-09-10 20:48 JST の heartbeat）
#
#   job_count: 7   （元は 61）／ unloaded_count: **67**
#   生き残っている ai.openclaw.* は **tab-guard ただ 1 本**
#   auth: ok=false  「トークンの有効期限を過ぎている」
#   x17 の実行結果: **CDP に繋がらない（ECONNREFUSED 127.0.0.1:18810）**
#
# ## これは `tab-guard` の非常ブレーキ
#
# `t014` に記録がある。`tab-guard.js` は **`ai.openclaw.*` を全部なめて、
# 自分だけ除外して unload する。** 2026-08-30 にも同じことが起きた。
#
#   生き残っていたのがちょうど ai.openclaw.tab-guard だけで、
#   com.dailyhack.*（別の接頭辞）は無傷。**パターンが完全に一致する。**
#
# 今回もその署名どおり。**tab-guard は正しく働いた。**
#
# ## 引き金は分かっている
#
# `chrome-cdp-heal` が 5〜6 分おきに失敗し、そのたび Chrome を落としていた
# （2026-09-08・利用者が Slack のスクリーンショットで特定）。
# **タブの一括消失として観測されれば、tab-guard が発火する。**
#
# **その犯人は 2026-09-08 に利用者が unload 済み。** だから戻してよい。
#
# ## 順番（**これを守る**）
#
#   1. 証拠を採る（何が止まっているか・いつ発火したか）
#   2. **chrome-cdp-heal がまだ止まっていることを確認する**
#      → 動いていたら**何も戻さずに終わる**（また壊される）
#   3. 停止ロックを解除する
#   4. Chrome を CDP つきで用意する
#   5. **CDP が本当に応答することを確かめる**（ポートの LISTEN では足りない）
#   6. X のログイン状態を見る
#   7. **3 ループのジョブだけ**戻す（chrome-cdp-heal は戻さない）
#   8. 戻った結果を確認する
#
# ## 戻さないもの（**意図的に除外**）
#
#   * `chrome-cdp-heal`        — **今回の犯人**
#   * `poll-approvals`         — 2026-08-15 に誤爆した経路
#   * `revenge-unfollow`       — 未検証
#   * `auto-detect-and-unfollow-inactive` / `unfollow-cleanup-*` — 大量アンフォロー
#
# **投稿しない。返信しない。フォロー・アンフォローもしない。LLM を呼ばない。**
# **このタスクがするのは「戻す」ことだけ。実際の動作は次の定時実行から。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/revive-automation.md"
NODE_BIN="/usr/local/bin/node"
CDP="http://127.0.0.1:18810"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

# 戻す対象。**3 ループ（返信・フォロー・アンフォロー）に絞る**
REVIVE="
comment-warmup
competitor-follower-follow
hashtag-follow
badge-followback
reply-followback-check
reply-followers-cleanup
incoming-reply-watcher
pipeline-heartbeat
"
# **絶対に戻さない**
NEVER="chrome-cdp-heal poll-approvals revenge-unfollow auto-detect-and-unfollow-inactive unfollow-cleanup-morning unfollow-cleanup-evening"

{
echo "# 【復旧】止まった X 自動化を戻す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 利用者は PC に触れない状態。**\`ops-poller\` が生きているので、この経路で直す。**"
echo "> \`ai.openclaw.*\` が全滅して **\`tab-guard\` だけ生き残る**のは、"
echo "> \`t014\`（2026-08-30）に記録した **非常ブレーキの署名と一致**する。"

# ═══════════ 1. 証拠 ═══════════
echo
echo "## 1. 止まる前と後（証拠）"
echo
echo '```'
echo "  --- いまロードされているもの ---"
launchctl list 2>/dev/null | awk '{print $3}' | grep -E '^(ai\.openclaw|com\.dailyhack)\.' | sort | sed 's/^/    /'
echo
echo "  ai.openclaw.*  : $(launchctl list 2>/dev/null | awk '{print $3}' | grep -c '^ai\.openclaw\.') 本"
echo "  com.dailyhack.*: $(launchctl list 2>/dev/null | awk '{print $3}' | grep -c '^com\.dailyhack\.') 本"
echo "  plist の総数   : $(ls -1 "$LA"/ai.openclaw.*.plist 2>/dev/null | wc -l | tr -d ' ') 本"
echo '```'
echo
echo "**\`ai.openclaw.*\` が 1 本（tab-guard）だけなら、非常ブレーキが引かれている。**"

echo
echo "### tab-guard はいつ・なぜ発火したか"
echo
echo '```'
for f in "$W"/logs/tab-guard.log "$W"/logs/tabguard.log; do
  [ -f "$f" ] || continue
  echo "  [$(basename "$f")] 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  grep -nE '🚨|halt|停止|一括|破壊|タブが' "$f" 2>/dev/null | tail -12 | cut -c1-175 | sed 's/^/    /' | clean
done
echo '```'

echo
echo "### 停止ロックはどこにあるか"
echo
echo '```'
TG="$S/tab-guard.js"
LOCKS=""
if [ -f "$TG" ]; then
  grep -nE 'LOCK|lock' "$TG" 2>/dev/null | head -8 | cut -c1-160 | sed 's/^/    /' | clean
  LOCKS="$(grep -oE '"[^"]*lock[^"]*"|`[^`]*lock[^`]*`' "$TG" 2>/dev/null | tr -d '"`' | head -5)"
else
  echo "    **tab-guard.js が無い**"
fi
echo '```'

# ═══════════ 2. 犯人がまだ止まっているか ═══════════
echo
echo "## 2. **犯人が止まっていることを先に確かめる**"
echo
echo "\`chrome-cdp-heal\` が動いていたら、戻してもまた壊される。**その場合は何もしない。**"
echo
echo '```'
DANGER=0
for j in $NEVER; do
  if launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j"; then
    printf '  **稼働中** %-40s\n' "$j"
    [ "$j" = "chrome-cdp-heal" ] && DANGER=1
  else
    printf '  止まっている %-40s\n' "$j"
  fi
done
echo '```'
if [ "$DANGER" = "1" ]; then
  echo
  echo "**\`chrome-cdp-heal\` が動いている。戻さずに終わる。**"
  echo "先にこれを止めること: \`launchctl unload $LA/ai.openclaw.chrome-cdp-heal.plist\`"
  exit 0
fi
echo
echo "**犯人は止まっている。戻してよい。**"

# ═══════════ 3. ロック解除 ═══════════
echo
echo "## 3. 停止ロックを解除する"
echo
echo '```'
CLEARED=0
for cand in $LOCKS "$W/data/.halt.lock" "$W/data/halt.lock" "$W/.halt" \
            "$W/data/automation-halt.lock" "/tmp/openclaw-halt"; do
  [ -z "$cand" ] && continue
  case "$cand" in /*) p="$cand" ;; *) p="$W/$cand" ;; esac
  if [ -e "$p" ]; then
    echo "  見つけた: $p"
    echo "    中身: $(head -c 120 "$p" 2>/dev/null | tr '\n' ' ')"
    echo "    更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$p" 2>/dev/null)"
    mv "$p" "$p.cleared-$(date '+%Y%m%d-%H%M%S')" 2>/dev/null \
      && { echo "    → **退避して解除した**"; CLEARED=$((CLEARED+1)); } \
      || echo "    → 解除できない"
  fi
done
[ "$CLEARED" = "0" ] && echo "  ロックファイルは見つからなかった（既に無いか、別の場所）"
echo '```'

# ═══════════ 4. Chrome と CDP ═══════════
echo
echo "## 4. Chrome を CDP つきで用意する"
echo
echo "\`x17\` は **\`ECONNREFUSED 127.0.0.1:18810\`** で失敗した。"
echo "\`chrome-cdp-heal\` を止めたので、**CDP を戻す役がいない。** ここで手当てする。"
echo
echo '```'
echo "  --- 手当て前 ---"
ps -eo pid,etime,args 2>/dev/null | grep -- '--remote-debugging-port' | grep -v ' grep' \
  | head -2 | cut -c1-150 | sed 's/^/    /' | clean
curl -s --max-time 5 "$CDP/json/version" >/dev/null 2>&1 \
  && echo "    CDP: 応答あり" || echo "    **CDP: 応答なし**"
echo
if [ -x "$S/ensure-chrome.sh" ]; then
  echo "  --- ensure-chrome.sh を走らせる ---"
  ( cd "$W" && "$S/ensure-chrome.sh" ) 2>&1 | tail -12 | sed 's/^/    /' | clean
  echo "    (rc=$?)"
else
  echo "  **ensure-chrome.sh が無い・実行できない**"
fi
echo '```'

echo
echo "### CDP が本当に応答するか（**ポートの LISTEN では足りない**）"
echo
echo "ハングした Chrome も \`/json/version\` に 200 を返す。**ページを開けるかで見る。**"
echo
echo '```'
if [ -f "$S/cdp-health.js" ]; then
  "$NODE_BIN" "$S/cdp-health.js" 2>&1 | tail -12 | sed 's/^/  /' | clean
else
  "$NODE_BIN" -e '
const { chromium } = require("playwright-core");
(async () => {
  let b;
  try { b = await chromium.connectOverCDP(process.argv[1], { timeout: 15000 }); }
  catch (e) { console.log("  **CDP に繋がらない: " + e.message.split("\n")[0].slice(0,110) + "**"); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log("  **context が無い**"); return; }
  console.log("  CDP: 接続 OK / context " + b.contexts().length + " 個 / ページ " + ctx.pages().length + " 枚");
})();
' "$CDP" 2>&1 | tail -6 | clean
fi
echo '```'

# ═══════════ 5. ログイン状態 ═══════════
echo
echo "## 5. X にログインできているか"
echo
echo "heartbeat の \`auth\` が **\`ok:false\`（期限切れ）** になっている。"
echo "\`ensure-chrome.sh\` には **cookie が永続化できておらず 再起動＝即ログアウト**の但し書きがある。"
echo
echo '```'
"$NODE_BIN" -e '
const { chromium } = require("playwright-core");
(async () => {
  let b;
  try { b = await chromium.connectOverCDP(process.argv[1], { timeout: 15000 }); }
  catch (e) { console.log("  CDP に繋がらないので確認できない"); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log("  context が無い"); return; }
  const page = await ctx.newPage();
  try {
    await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(3500);
    const url = page.url();
    const out = /login|i\/flow|\/\?logout/.test(url);
    console.log("  /home の URL: " + url);
    console.log("  ログイン: " + (out ? "**切れている（要 再ログイン）**" : "生きている"));
  } catch (e) { console.log("  開けない: " + e.message.split("\n")[0].slice(0,100)); }
  await page.close().catch(()=>{});
})();
' "$CDP" 2>&1 | tail -6 | clean
echo
echo "  --- cookie のバックアップはあるか ---"
ls -1t "$W"/data/cookie-backup* "$W"/data/cookies*.json 2>/dev/null | head -3 | while read -r f; do
  printf '    %-46s %s\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
done
echo '```'

# ═══════════ 6. ジョブを戻す ═══════════
echo
echo "## 6. 3 ループのジョブを戻す"
echo
echo "**返信・フォロー・アンフォローに必要なものだけ。** 危険なものは戻さない。"
echo
echo '```'
OK=0; NG=0
for j in $REVIVE; do
  [ -z "$j" ] && continue
  lbl="ai.openclaw.$j"; P="$LA/$lbl.plist"
  if launchctl list 2>/dev/null | grep -qF "$lbl"; then
    printf '  既にロード済み %-38s\n' "$j"; continue
  fi
  if [ ! -f "$P" ]; then
    printf '  **plist が無い** %-36s\n' "$j"; NG=$((NG+1)); continue
  fi
  if ! plutil -lint "$P" >/dev/null 2>&1; then
    printf '  **plist が壊れている** %-30s （戻さない）\n' "$j"; NG=$((NG+1)); continue
  fi
  if launchctl load -w "$P" 2>/dev/null; then
    printf '  **戻した** %-42s\n' "$j"; OK=$((OK+1))
  else
    printf '  戻せない %-44s\n' "$j"; NG=$((NG+1))
  fi
done
echo
echo "  戻した: ${OK} 本 / 戻せなかった: ${NG} 本"
echo '```'

# ═══════════ 7. 結果 ═══════════
echo
echo "## 7. 戻った結果"
echo
echo '```'
echo "  --- ai.openclaw.* のロード状況 ---"
for j in $REVIVE; do
  [ -z "$j" ] && continue
  line="$(launchctl list 2>/dev/null | grep -F "ai.openclaw.$j" || true)"
  if [ -z "$line" ]; then printf '  **未ロード** %-38s\n' "$j"
  else printf '%s\n' "$line" | awk -v j="$j" '{printf "  ロード      %-38s PID=%-8s 最後のrc=%s\n", j, $1, $2}'; fi
done
echo
echo "  合計 ai.openclaw.*: $(launchctl list 2>/dev/null | awk '{print $3}' | grep -c '^ai\.openclaw\.') 本"
echo '```'
echo
echo "**「ロード済み」は「働いた」ではない**（CLAUDE.md 最上位ルール 11）。"
echo "**次の定時実行の結果をキューで数えるまで、動いたとは言わない。**"

echo
echo "---"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク自体**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| フォロー・アンフォロー（DOM 操作） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（戻したあと・実績 1 件/日・実測） | \$0.003 | \$0.003 | 約 \$0.09 |"
echo "| 返信（\`x23\` 適用後・**推定**） | 約 \$0.0022 | — | — |"
echo
echo "**戻しただけで、投稿・返信・フォロー・アンフォローはしていない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
N="$(grep -m1 -oE '戻した: [0-9]+ 本' "$OUT" 2>/dev/null || echo '戻し数 不明')"
L="$(grep -m1 -oE 'ログイン: .*' "$OUT" 2>/dev/null | cut -c1-40 || echo '')"
C="$(grep -m1 -oE 'CDP: (接続 OK|応答あり)|\*\*CDP に繋がらない' "$OUT" 2>/dev/null || echo 'CDP 不明')"
echo "**$(date '+%H:%M') 自動化を復旧（\$0）** / $N / $C / $L / $(basename "$OUT")"
