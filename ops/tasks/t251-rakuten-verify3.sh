#!/bin/bash
# **楽天アフィリエイトの手ログインが OpenClaw の Chrome に残っているか確かめる（t251）。**
# t250 は Mac の DNS（ERR_NAME_NOT_RESOLVED）で楽天まで届かなかったので、名前解決から順に見る。
# あわせて **ログインが何日もつか**（楽天の Cookie の有効期限）を測る。**Cookie の値は出さない**（名前と期限だけ）。
# ログインの自動入力はしない（手ログインを壊さないため）。LLM 不使用・**$0**。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t251-rakuten-verify3.md"
mkdir -p "$RDIR"
{ echo "# 楽天アフィリエイトのログイン確認（t251・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
{
  echo "## 1. 名前解決"
  echo '```text'
  for h in affiliate.rakuten.co.jp grp01.id.rakuten.co.jp login.account.rakuten.com www.rakuten.co.jp; do
    a="$(/usr/bin/dscacheutil -q host -a name "$h" 2>/dev/null | /usr/bin/awk '/ip_address/{print $2}' | head -2 | tr '\n' ' ')"
    c="$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://$h/" 2>/dev/null)"
    echo "$h  ip=[${a:-なし}]  https=${c:-失敗}"
  done
  echo '```'
} >> "$OUT"
JS="$RDIR/.t251.mjs"
cat > "$JS" <<'JSEOF'
import { createRequire } from 'node:module';
import fs from 'node:fs'; import path from 'node:path'; import os from 'node:os';
const d = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')].find((x) => fs.existsSync(path.join(x, 'playwright-core')));
const { chromium } = createRequire(path.join(d, 'x.js'))('playwright-core');
const b = await chromium.connectOverCDP('http://127.0.0.1:18810').catch((e) => { console.log('CDP につながらない: ' + e); process.exit(0); });
const ctx = b.contexts()[0];
console.log('## 2. 楽天の Cookie（値は出さない・名前と期限だけ）'); console.log('```text');
const now = Date.now() / 1000;
const cs = (await ctx.cookies()).filter((c) => /rakuten/.test(c.domain));
for (const c of cs.sort((a, z) => a.domain.localeCompare(z.domain))) {
  const exp = c.expires > 0 ? `${new Date(c.expires * 1000).toISOString().slice(0, 10)}（あと ${((c.expires - now) / 86400).toFixed(1)} 日）` : 'ブラウザを閉じるまで';
  console.log(`${c.domain}  ${c.name}  ${exp}`);
}
console.log(`（計 ${cs.length} 件）`); console.log('```');
// 手ログインしたタブがあれば、そのまま読む
const pages = ctx.pages();
console.log('## 3. 開いているタブ'); console.log('```text');
for (const p of pages) console.log(p.url().slice(0, 120));
console.log('```');
const p = await ctx.newPage();
console.log('## 4. 楽天アフィリエイトを開く'); console.log('```text');
for (const u of ['https://affiliate.rakuten.co.jp/', 'https://affiliate.rakuten.co.jp/report/summary']) {
  let ok = false;
  for (let i = 0; i < 3 && !ok; i++) {
    try { await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }); ok = true; }
    catch (e) { console.log(`試行${i + 1} 失敗: ${String(e).split('\n')[0]}`); await p.waitForTimeout(3000); }
  }
  if (!ok) continue;
  await p.waitForTimeout(3500);
  const s = await p.evaluate(() => {
    const t = document.body.innerText || '';
    return {
      url: location.href, title: document.title,
      pw: !!document.querySelector('input[type=password]'),
      logout: [...document.querySelectorAll('a,button')].some((el) => /ログアウト|logout/i.test(el.innerText || el.href || '')),
      loginCta: /ログインして|ログインする|楽天会員ログイン/.test(t),
      // アフィリエイト ID（公開リンクに必ず入る値。xxxxxxxx.xxxxxxxx.xxxxxxxx.xxxxxxxx の形）
      afid: (t.match(/[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}/) || (document.documentElement.innerHTML.match(/hgc\/([0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8})/) || [])[1] || [])[0] || (document.documentElement.innerHTML.match(/hgc\/([0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8}\.[0-9a-f]{8})/) || [])[1] || '',
    };
  });
  console.log(JSON.stringify(s));
}
console.log('```');
await p.close();
JSEOF
run_limited 150 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
echo "rc=$? / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 3000 "$OUT"
