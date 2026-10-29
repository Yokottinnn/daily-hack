#!/bin/bash
# **関所（X の通信を止めて中身を見る仕組み）を全ジョブから外し、返信の入力欄が開くかを押さずに確かめる（x372）。$0。**
# 利用者が「外して確かめる」を選んだ（2026-10-30）。10/26 以降 返信 0 件・告知 4 回失敗。関所の導入（10/25 23:59）が最有力の原因。
# 開けば $W/data/.x372-ok を作る（続く x373 の告知はこれがあるときだけ出す）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x372-remove-guard.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PB=/usr/libexec/PlistBuddy; UIDN=$(id -u)
rm -f "$W/data/.x372-ok"
unset NODE_OPTIONS
{
echo "# 関所を外して確かめる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## 1. plist から関所を外す"; echo '```'
n=0; r=0; run=""
for P in "$HOME"/Library/LaunchAgents/ai.openclaw.*.plist "$HOME"/Library/LaunchAgents/com.dailyhack.*.plist; do
  [ -f "$P" ] || continue
  cur=$($PB -c "Print :EnvironmentVariables:NODE_OPTIONS" "$P" 2>/dev/null || true)
  case "$cur" in *x-action-guard.cjs*) ;; *) continue ;; esac
  L=$(basename "$P" .plist); n=$((n+1))
  new=$(printf '%s' "$cur" | sed -E 's#--require [^ ]*x-action-guard\.cjs##g; s/^ +| +$//g')
  if [ -z "$new" ]; then $PB -c "Delete :EnvironmentVariables:NODE_OPTIONS" "$P"; else $PB -c "Set :EnvironmentVariables:NODE_OPTIONS $new" "$P"; fi
  st=$(launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -m1 -E '^[[:space:]]*state = ' | awk '{print $3}')
  if [ -z "$st" ]; then continue; fi
  if [ "$st" = "running" ]; then run="$run $L"; continue; fi
  launchctl bootout "gui/$UIDN/$L" 2>/dev/null; launchctl bootstrap "gui/$UIDN" "$P" 2>/dev/null
  launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -q 'x-action-guard' && echo "$L: **まだ関所が残っている**" || r=$((r+1))
done
echo "外した plist: $n 本 / 読み込み直して関所が消えたのを確かめた: $r 本"
echo "動いている最中で後回し:${run:- なし}"
echo '```'
echo; echo "## 2. いま動いている node（X に触っていそうなもの・経過時間）"; echo '```'
ps -axo pid,etime,command | grep -E 'node .*scripts/' | grep -v grep | cut -c1-160
echo '```'
echo; echo "## 3. 返信の入力欄が開くか（自分の固定の投稿を開くだけ・押さない）"; echo '```'
PROBE="$W/.x372-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  await p.goto("https://x.com/heng_ji31590/status/2113412348195283225", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]', { timeout: 25000 }).then(() => r.textarea = true).catch(() => r.textarea = false);
  r.errorText = await p.evaluate(() => /問題が発生しました/.test(document.body.innerText));
  await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r)); process.exit(0); })();
PJS
RES=$(cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -1); echo "$RES"; rm -f "$PROBE"
echo '```'
case "$RES" in *'"textarea":true'*) date -u +%Y-%m-%dT%H:%M:%SZ > "$W/data/.x372-ok"; echo "**入力欄は開いた。**";; *) echo "**入力欄は開かなかった。告知は出さない。**";; esac
} > "$OUT" 2>&1
echo "x372 / $(basename "$OUT")"
