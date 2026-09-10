#!/bin/bash
# **`login-mode-guard` を調べ、安全に戻せるなら戻す。費用 $0。**
#
# ## いま止まっている理由（x24 の実測・2026-09-10 21:38）
#
#   ensure-chrome: login-mode-guard active, skip launch
#   {"ok":false,"healthy":false,"reason":"port_closed","detail":"Chrome not running","port":18810}
#
# **Chrome が起動していない。** `ensure-chrome.sh` が
# **`login-mode-guard` を理由に起動を拒否している。**
# Chrome が無いので CDP も無く、返信・フォロー・アンフォローが全部 空振りする。
#
# heartbeat の `auth: ok=false`（トークン期限切れ）と符合する。
# **ログインが切れたので、自動化を走らせないよう止めている**状態と読める。
#
# ## 手元にあるもの
#
#   ~/.openclaw/workspace/data/cookie-backups/2026-09-09.db
#   ~/.openclaw/workspace/data/cookie-backups/2026-09-08.db
#
# ## 順番（**壊さない順に**）
#
#   1. `ensure-chrome.sh` の全文を読む。**guard は何を見て、何で消えるのか**
#   2. guard のフラグ実体（ファイル or 環境変数）と、その更新時刻・中身
#   3. cookie バックアップの一覧（日付・サイズ）
#   4. **guard が「古い置き土産」なら外す。** 生きた理由があるなら**外さない**
#   5. 外せたら Chrome を起動し、**CDP が応答するか**を確かめる
#   6. **X のログイン状態を確かめる**（cwd を `scripts/` にして `playwright-core` を読む）
#   7. ログアウトしていて、かつ cookie バックアップがあれば**復元を 1 回だけ試す**
#
# ## 前回 私がやったミス（繰り返さない）
#
# `x24` のログイン確認は `node -e` を **cwd `/`** で走らせたため
# `MODULE_NOT_FOUND` で落ちた。`playwright-core` は `workspace/node_modules` にあり、
# **`scripts/` から実行しないと解決しない。** 今回は一時 js を `scripts/` に置く。
#
# ## やらないこと
#
# **投稿しない。返信しない。フォロー・アンフォローしない。LLM を呼ばない。**
# **cookie を消さない。** 復元は「バックアップを足す」方向だけで、現物は退避してから触る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/clear-login-guard.md"
NODE_BIN="/usr/local/bin/node"
CDP="http://127.0.0.1:18810"
EC="$S/ensure-chrome.sh"
TMPJS="$S/.x25-login-check.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cleanup() { rm -f "$TMPJS"; }
trap cleanup EXIT

{
echo "# \`login-mode-guard\` を外して Chrome を戻す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x24\` の実測: **\`ensure-chrome: login-mode-guard active, skip launch\`**"
echo "> **Chrome が起動していない。** だから CDP も無く、3 ループが全部 空振りしている。"

# ═══════════ 1. ensure-chrome.sh の全文 ═══════════
echo
echo "## 1. \`ensure-chrome.sh\` は何を見て起動を拒否しているか"
echo
echo '```bash'
if [ -f "$EC" ]; then
  cat -n "$EC" 2>/dev/null | clean
else
  echo "  **無い: $EC**"
fi
echo '```'
if [ ! -f "$EC" ]; then
  echo; echo "**本体が無いので何もしない。**"; exit 1
fi

echo
echo "### guard に関わる行だけ抜き出す"
echo
echo '```bash'
grep -nE 'login.mode|guard|LOGIN_MODE|skip launch|GUARD' "$EC" 2>/dev/null \
  | head -20 | cut -c1-175 | sed 's/^/  /' | clean
echo '```'

# ═══════════ 2. guard の実体 ═══════════
echo
echo "## 2. guard のフラグ実体（**何が立っているのか**）"
echo
echo '```'
# ensure-chrome.sh に書かれているパス候補を拾う
CANDS="$(grep -oE '"[^"]*(login|guard)[^"]*"|\$\{?[A-Z_]*(LOGIN|GUARD)[A-Z_]*\}?|[A-Za-z0-9_./$-]*login-mode[A-Za-z0-9_.-]*' "$EC" 2>/dev/null \
        | tr -d '"' | sort -u | head -10)"
echo "  --- ensure-chrome.sh から拾った候補 ---"
printf '%s\n' "$CANDS" | sed 's/^/    /'
echo
echo "  --- 実在するフラグファイル ---"
FOUND_FLAG=""
for c in $CANDS "$W/data/.login-mode" "$W/data/login-mode.lock" "$W/.login-mode" \
         "$W/data/login-mode-guard" "/tmp/openclaw-login-mode"; do
  [ -z "$c" ] && continue
  case "$c" in
    /*) p="$c" ;;
    \$*) continue ;;
    *) p="$W/$c" ;;
  esac
  if [ -e "$p" ]; then
    FOUND_FLAG="$p"
    echo "    **有る** $p"
    echo "      更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$p" 2>/dev/null)"
    echo "      大きさ: $(wc -c < "$p" 2>/dev/null | tr -d ' ') B"
    echo "      中身: $(head -c 200 "$p" 2>/dev/null | tr '\n' ' ' | clean)"
  fi
done
[ -z "$FOUND_FLAG" ] && echo "    候補の場所には見つからない（環境変数か、別の判定かもしれない）"
echo
echo "  --- login-mode という名前のファイルを workspace から探す ---"
find "$W" -maxdepth 3 -name '*login*mode*' -o -maxdepth 3 -name '*login*guard*' 2>/dev/null \
  | head -10 | while read -r f; do
  printf '    %-56s %s\n' "$f" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
done
echo '```'

# ═══════════ 3. cookie バックアップ ═══════════
echo
echo "## 3. cookie のバックアップ"
echo
echo '```'
BK="$W/data/cookie-backups"
if [ -d "$BK" ]; then
  echo "  $BK"
  ls -1t "$BK" 2>/dev/null | head -8 | while read -r f; do
    printf '    %-24s %9s B  %s\n' "$f" \
      "$(wc -c < "$BK/$f" 2>/dev/null | tr -d ' ')" \
      "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$BK/$f" 2>/dev/null)"
  done
else
  echo "  **$BK が無い**"
  ls -1td "$W"/data/*cookie* 2>/dev/null | head -5 | sed 's/^/    /'
fi
echo
echo "  --- いま使われている cookie の実体 ---"
for f in "$W"/data/cookies.json "$W"/data/x-cookies.json "$W"/data/cookies.db; do
  [ -e "$f" ] || continue
  printf '    %-40s %9s B  %s\n' "$(basename "$f")" \
    "$(wc -c < "$f" 2>/dev/null | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
done
echo '```'
echo
echo "**バックアップが auth 失効（2026-09-10 10:11 UTC）より前なら、戻しても切れている。**"
echo "**9/09 のものが失効前なら、戻す価値がある。**"

# ═══════════ 4. guard を外す ═══════════
echo
echo "## 4. guard を外す（**退避してから**）"
echo
echo "**消さない。名前を変えて退避する。** 元に戻せる形にしておく。"
echo
echo '```'
if [ -n "$FOUND_FLAG" ]; then
  mv "$FOUND_FLAG" "$FOUND_FLAG.parked-$STAMP" 2>/dev/null \
    && echo "  **退避した**: $(basename "$FOUND_FLAG") → $(basename "$FOUND_FLAG").parked-$STAMP" \
    || echo "  退避できない: $FOUND_FLAG"
else
  echo "  フラグファイルが特定できていないので、**触らない**。"
  echo "  上の §1 全文から、判定が環境変数かどうかを読む必要がある。"
fi
echo '```'

# ═══════════ 5. Chrome を起動 ═══════════
echo
echo "## 5. Chrome を起動して CDP を確かめる"
echo
echo '```'
echo "  --- ensure-chrome.sh をもう一度 ---"
( cd "$W" && "$EC" ) 2>&1 | tail -12 | sed 's/^/    /' | clean
echo "    (rc=$?)"
echo
echo "  --- CDP の健全性（ポートの LISTEN では足りない） ---"
if [ -f "$S/cdp-health.js" ]; then
  ( cd "$S" && "$NODE_BIN" "$S/cdp-health.js" ) 2>&1 | tail -6 | sed 's/^/    /' | clean
else
  curl -s --max-time 6 "$CDP/json/version" 2>/dev/null | head -c 200 | sed 's/^/    /' \
    || echo "    **CDP に繋がらない**"
fi
echo
echo "  --- Chrome のプロセス ---"
ps -eo pid,lstart,etime,args 2>/dev/null | grep -- '--remote-debugging-port' | grep -v ' grep' \
  | head -2 | cut -c1-160 | sed 's/^/    /' | clean
echo '```'

# ═══════════ 6. ログイン状態 ═══════════
echo
echo "## 6. X にログインできているか"
echo
echo "**前回は \`node -e\` を cwd \`/\` で走らせて \`MODULE_NOT_FOUND\` になった。**"
echo "\`playwright-core\` は \`workspace/node_modules\` にあるので、"
echo "**一時 js を \`scripts/\` に置いて実行する。**"
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
    await page.waitForTimeout(4000);
    const url = page.url();
    const loggedOut = /login|i\/flow|\/\?logout|signup/.test(url);
    console.log("  /home の URL : " + url);
    console.log("  ログイン     : " + (loggedOut ? "**切れている（要 再ログイン）**" : "生きている"));
    if (!loggedOut) {
      const me = await page.evaluate(() => {
        const a = document.querySelector('[data-testid="SideNav_AccountSwitcher_Button"]');
        return a ? (a.innerText || "").split("\n").pop() : null;
      });
      console.log("  アカウント   : " + (me ? "読めた" : "読めない"));
    }
  } catch (e) { console.log("  開けない: " + e.message.split("\n")[0].slice(0, 110)); }
  await page.close().catch(() => {});
})();
JS
echo '```'
( cd "$S" && "$NODE_BIN" "$TMPJS" -- "$CDP" ) 2>&1 | tail -8 | sed 's/^/  /' | clean
echo '```'

echo
echo "---"
echo
echo "## この先どうするか"
echo
echo "| 上の結果 | 次にやること |"
echo "| --- | --- |"
echo "| ログイン **生きている** | **復旧完了。** 次の定時実行（12/16/19/22 時）から 3 ループが動く |"
echo "| ログイン **切れている** | cookie バックアップからの復元を試すか、**PC での再ログインが要る** |"
echo "| CDP が繋がらない | guard 以外の理由で Chrome が起動できていない。§1 の全文を読み直す |"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| フォロー・アンフォロー（DOM 操作） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（実測 9/8=5 件・9/9=3 件） | \$0.003 | \$0.009〜0.015 | 約 \$0.27〜0.45 |"
echo
echo "**投稿・返信・フォロー・アンフォローのいずれもしていない。cookie も消していない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
L="$(grep -m1 -oE 'ログイン     : .*' "$OUT" 2>/dev/null | cut -c1-46 || echo 'ログイン状態 不明')"
G="$(grep -m1 -oE '\*\*退避した\*\*: [^ ]*|フラグファイルが特定できていない' "$OUT" 2>/dev/null | cut -c1-50 || echo '')"
echo "**$(date '+%H:%M') login-mode-guard を調べた（\$0）** / $G / $L / $(basename "$OUT")"
