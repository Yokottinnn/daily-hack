#!/bin/bash
# **`/tmp/x-login-in-progress` を外して Chrome を戻す。費用 $0。**
#
# ## 原因が確定した（x25 が `ensure-chrome.sh` の全文を出した）
#
#   LOCK=/tmp/x-login-in-progress
#   if [ -f "$LOCK" ]; then
#     echo "ensure-chrome: login-mode-guard active, skip launch" >&2
#     exit 0        # ← **意図的な no-op。だから何も起きずに成功扱いになる**
#   fi
#
# コメントにこうある。
#
#   2026-07-11 login-mode guard: lock 存在時 は Chrome 起動もしない
#   (**user 手動 login 中は Chrome を触らない**)
#
# **人が手で X にログインしている最中、自動化に邪魔されないための鍵。**
# その鍵が**消し忘れで残っている。**
#
# ## なぜ「消し忘れ」と断定できるか
#
#   * **利用者はいま PC に触れない**と明言している。手動ログインは進行していない
#   * `x25` は候補を 10 個 探したが `/tmp/x-login-in-progress` が入っていなかった
#     （**私の探索漏れ**。`$W/data/` ばかり見て `/tmp` を 1 つしか見ていなかった）
#   * この鍵がある限り `ensure-chrome.sh` は **rc=0 で何もしない**。
#     呼び出し側からは成功に見えるので、**26 本のジョブ全部が静かに空振りする**
#
# ## 朗報: 自動再ログインが組み込まれている
#
# `ensure-chrome.sh` には既にこれがある。
#
#   logged out after restart — running x-login.js
#   re-login OK / re-login FAILED — manual login required
#
# **鍵さえ外せば、Chrome を起動し、ログアウトしていれば自分で入り直す。**
#
# ## 順番
#
#   1. 鍵の実在・更新時刻・中身を出す（**何時間 放置されていたか**）
#   2. **6 時間 より新しければ触らない**（本当に手動ログイン中かもしれない）
#   3. 古ければ**退避**（消さない。`.parked-<日時>` に改名）
#   4. `ensure-chrome.sh` を走らせる（**自動再ログインが動くはず**）
#   5. CDP の健全性を確かめる
#   6. X のログイン状態を確かめる（**cwd を `scripts/` にする**）
#   7. だめなら cookie バックアップの状態を出して、次の手を示す
#
# **投稿しない。返信しない。フォロー・アンフォローしない。LLM を呼ばない。**
# **cookie を消さない。鍵も消さずに改名するだけ。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/unlock-x-login.md"
NODE_BIN="/usr/local/bin/node"
CDP="http://127.0.0.1:18810"
EC="$S/ensure-chrome.sh"
LOCK="/tmp/x-login-in-progress"
TMPJS="$S/.x26-login-check.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
STALE_HOURS=6

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cleanup() { rm -f "$TMPJS"; }
trap cleanup EXIT

{
echo "# \`/tmp/x-login-in-progress\` を外して Chrome を戻す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x25\` が \`ensure-chrome.sh\` の全文を出して、原因が確定した。"
echo "> **\`/tmp/x-login-in-progress\` があると Chrome を起動せず \`exit 0\` する。**"
echo "> rc=0 なので**呼び出し側からは成功に見える。26 本のジョブが静かに空振りする。**"

# ═══════════ 1. 鍵の状態 ═══════════
echo
echo "## 1. 鍵は何時間 放置されているか"
echo
echo '```'
if [ -f "$LOCK" ]; then
  MT="$(stat -f '%m' "$LOCK" 2>/dev/null || echo 0)"
  NOW="$(date '+%s')"
  AGE=$(( (NOW - MT) / 3600 ))
  echo "  **有る**: $LOCK"
  echo "    更新  : $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$LOCK" 2>/dev/null)"
  echo "    経過  : **${AGE} 時間**"
  echo "    大きさ: $(wc -c < "$LOCK" 2>/dev/null | tr -d ' ') B"
  echo "    中身  : $(head -c 200 "$LOCK" 2>/dev/null | tr '\n' ' ' | clean)"
else
  echo "  **無い**: $LOCK"
  echo "  → 鍵は既に外れている。別の理由で止まっている可能性がある。"
  AGE=-1
fi
echo '```'

# ═══════════ 2. 外してよいか ═══════════
echo
echo "## 2. 外してよいか判断する"
echo
echo "**${STALE_HOURS} 時間 より新しければ触らない。** 本当に手動ログイン中かもしれない。"
echo
echo '```'
PARKED=0
if [ ! -f "$LOCK" ]; then
  echo "  鍵が無いので何もしない。"
elif [ "${AGE:-0}" -lt "$STALE_HOURS" ] 2>/dev/null; then
  echo "  **${AGE} 時間しか経っていない。触らない。**"
  echo "  手動ログインが進行中の可能性がある。"
else
  echo "  ${AGE} 時間 放置されている（しきい値 ${STALE_HOURS} 時間）。"
  echo "  **利用者は PC に触れないと明言している。手動ログインは進行していない。**"
  if mv "$LOCK" "$LOCK.parked-$STAMP" 2>/dev/null; then
    echo "  → **退避した**: $LOCK.parked-$STAMP"
    PARKED=1
  else
    echo "  → 退避できない（権限？）"
  fi
fi
echo '```'

# ═══════════ 3. Chrome を起動 ═══════════
echo
echo "## 3. Chrome を起動する（**自動再ログインが動くはず**）"
echo
echo "\`ensure-chrome.sh\` には \`x-login.js\` を呼ぶ経路が既にある。"
echo
echo '```'
echo "  --- ensure-chrome.sh ---"
( cd "$W" && "$EC" ) 2>&1 | tail -20 | sed 's/^/    /' | clean
echo "    (rc=$?)"
echo
echo "  --- ensure-chrome.log の末尾（再ログインの記録） ---"
tail -20 "$W/logs/ensure-chrome.log" 2>/dev/null | cut -c1-175 | sed 's/^/    /' | clean
echo '```'

# ═══════════ 4. CDP ═══════════
echo
echo "## 4. CDP は応答するか"
echo
echo '```'
if [ -f "$S/cdp-health.js" ]; then
  ( cd "$S" && "$NODE_BIN" "$S/cdp-health.js" ) 2>&1 | tail -6 | sed 's/^/  /' | clean
else
  curl -s --max-time 6 "$CDP/json/version" 2>/dev/null | head -c 200 | sed 's/^/  /' \
    || echo "  **CDP に繋がらない**"
fi
echo
echo "  --- Chrome のプロセス ---"
ps -eo pid,lstart,etime,args 2>/dev/null | grep -- '--remote-debugging-port' | grep -v ' grep' \
  | head -2 | cut -c1-150 | sed 's/^/  /' | clean
echo '```'

# ═══════════ 5. ログイン ═══════════
echo
echo "## 5. X にログインできているか"
echo
cat > "$TMPJS" <<'JS'
const { chromium } = require("playwright-core");
(async () => {
  let b;
  try { b = await chromium.connectOverCDP(process.argv[2], { timeout: 15000 }); }
  catch (e) { console.log("  CDP に繋がらない: " + e.message.split("\n")[0].slice(0, 110)); return; }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log("  context が無い"); return; }
  const page = await ctx.newPage();
  try {
    await page.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(4500);
    const url = page.url();
    const out = /login|i\/flow|\/\?logout|signup/.test(url);
    console.log("  /home の URL : " + url);
    console.log("  ログイン     : " + (out ? "**切れている**" : "**生きている**"));
    if (!out) {
      const ok = await page.evaluate(() =>
        !!document.querySelector('[data-testid="SideNav_AccountSwitcher_Button"]'));
      console.log("  アカウント欄 : " + (ok ? "読めた（確定）" : "読めない"));
    }
  } catch (e) { console.log("  開けない: " + e.message.split("\n")[0].slice(0, 110)); }
  await page.close().catch(() => {});
})();
JS
echo '```'
( cd "$S" && "$NODE_BIN" "$TMPJS" -- "$CDP" ) 2>&1 | tail -8 | sed 's/^/  /' | clean
echo '```'

# ═══════════ 6. だめだった場合の材料 ═══════════
echo
echo "## 6. まだログアウトしている場合の材料"
echo
echo '```'
echo "  --- cookie バックアップ ---"
ls -1t "$W/data/cookie-backups" 2>/dev/null | head -4 | while read -r f; do
  printf '    %-20s %9s B  %s\n' "$f" \
    "$(wc -c < "$W/data/cookie-backups/$f" 2>/dev/null | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$W/data/cookie-backups/$f" 2>/dev/null)"
done
echo
echo "  --- 自動再ログインの本体はあるか ---"
for f in "$S/x-login.js" "$S/cookie-restore.sh" "$S/restore-cookies-and-relaunch.sh"; do
  if [ -f "$f" ]; then printf '    有る  %-44s %s\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
  else printf '    無い  %s\n' "$(basename "$f")"; fi
done
echo
echo "  --- 再ログインのスロットル状態 ---"
for f in /tmp/x-relogin-stamp "$W/data/.relogin-stamp" "$W/data/relogin-stamp"; do
  [ -e "$f" ] && echo "    $f  更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$f" 2>/dev/null)"
done
echo '```'

echo
echo "---"
echo
echo "## 判定"
echo
echo "| 結果 | 意味 |"
echo "| --- | --- |"
echo "| ログイン **生きている** | **復旧完了。** 次の定時（12/16/19/22 時）から 3 ループが動く |"
echo "| ログイン **切れている** ＋ \`re-login OK\` のログ | 少し待てば入る。次の発火で確認 |"
echo "| ログイン **切れている** ＋ \`manual login required\` | **PC での再ログインが要る** |"
echo "| CDP が繋がらない | 鍵以外の理由。\`ensure-chrome.log\` を読む |"
echo
echo "## 再発防止（**この鍵は消し忘れると全部 止まる**）"
echo
echo "\`/tmp/x-login-in-progress\` があると **26 本のジョブが rc=0 のまま静かに空振りする。**"
echo "**エラーが出ないので気づけない。** 今回は 2 日 気づけなかった。"
echo "**heartbeat にこの鍵の有無を出すべき。**"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| フォロー・アンフォロー（DOM 操作） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（**実測** 9/8=5 件・9/9=3 件） | \$0.003 | \$0.009〜0.015 | 約 \$0.27〜0.45 |"
echo
echo "**投稿・返信・フォロー・アンフォローのいずれもしていない。cookie も消していない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
P="$(grep -m1 -oE '\*\*退避した\*\*|触らない|鍵が無いので' "$OUT" 2>/dev/null || echo '')"
L="$(grep -m1 -oE 'ログイン     : .*' "$OUT" 2>/dev/null | cut -c1-42 || echo 'ログイン状態 不明')"
echo "**$(date '+%H:%M') x-login ロックを外した（\$0）** / $P / $L / $(basename "$OUT")"
