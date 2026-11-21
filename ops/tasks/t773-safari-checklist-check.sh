#!/bin/bash
# **Mac の Safari（WebKit）で、スマホ幅のチェックリストが縦に折れていないかを測る（t773・2026-11-21）。** LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-21 利用者が iPhone で崩れを指摘 → PR #1853・#1855 で直した。クラウドには WebKit が無いので、利用者がダイアログで「Mac の Safari でも確かめておいて」を選んだ。
# 画面は撮らない（出力は公開リポジトリ）。数字だけ返す。Markdown の箇条書きで書いたチェックリストがある 21 本を見る。
set -uo pipefail
OUTDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$OUTDIR/t773-safari-checklist-check.md"
W="$HOME/.openclaw/workspace"; STAMP="$(date '+%Y%m%d-%H%M%S')"; RUNNER="$W/scripts/.t773-$STAMP.js"
SLUGS="alvark-tokyo-toyosu-events-2026-11,ariake-garden-events-2026-11-late,ariake-garden-parenting-events-2026-11,cruise-expo-tokyo-2026,doubletree-ariake-strawberry-afternoon-tea-2026,gli-harumi-steam-event-2026,hero-prime-international-school-tsukiji-2027,hotel-villa-fontaine-ariake-winter-buffet-2026,kyo-hayashiya-harumi-christmas-cake-2026,minivelo-meet-ariake-2026,penthouse-toyosu-afternoon-tea-2026,pma-tokyo-vol11-bigsight-2026,sakana-japan-festival-odaiba-2026,shutoko-futures-lalaport-toyosu-2026,tokyo-christmas-market-lighting-2026,tokyo-culture-debut-park-toyosu-2026,tokyobay-light-wish-odaiba-2026,toyosu-senkyakubanrai-december-events-2026,toyota-arena-tokyo-winter-light-2026,tsukiji-jogai-year-end-fukubiki-2026,tsukiji-redevelopment-update-2026-11"
descendants() { local root="$1" p kids; kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"; for p in $kids; do echo "$p"; descendants "$p"; done; }
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 & local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do kill -0 "$pid" 2>/dev/null || break; sleep 1; w=$((w + 1)); done
  if kill -0 "$pid" 2>/dev/null; then local victims p; victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done; sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done; wait "$pid" 2>/dev/null || true; return 124; fi
  wait "$pid"; return $?
}
cat > "$RUNNER" <<'JSEOF'
// 1) Playwright の WebKit（iPhone の描画エンジンと同じ）があればそれで、2) 無ければ safaridriver（本物の Safari）で測る
const slugs = process.env.SLUGS.split(',');
const BASE = 'https://daily-hack.fieldbeside.com/posts/';
const MEASURE = `(() => { const out = []; document.querySelectorAll('.post-body .checklist li').forEach((li) => {
  const w = li.getBoundingClientRect().width; let bad = false;
  for (const n of li.childNodes) { let r; if (n.nodeType === 3) { if (!n.textContent.trim()) continue; const rg = document.createRange(); rg.selectNodeContents(n); r = rg.getBoundingClientRect(); } else if (n.nodeType === 1) r = n.getBoundingClientRect(); else continue;
    if (r.width > 0 && r.width < w / 3 && r.height > 70) { bad = true; break; } }
  if (bad) out.push(li.textContent.trim().slice(0, 24)); });
  return { n: document.querySelectorAll('.post-body .checklist li').length, bad: out, vw: innerWidth, wrapped: document.querySelectorAll('.post-body .checklist li > .checklist-text').length, has: CSS.supports('selector(:has(a))'), ua: navigator.userAgent.slice(0, 120) }; })()`;
async function viaPlaywright() {
  let pw; try { pw = require('playwright-core'); } catch (e) { return { skip: 'playwright-core が無い' }; }
  let b; try { b = await pw.webkit.launch(); } catch (e) { return { skip: 'WebKit が入っていない: ' + String(e.message).split('\n')[0].slice(0, 120) }; }
  const ctx = await b.newContext({ ...pw.devices['iPhone 13'] }); const p = await ctx.newPage(); const res = [];
  for (const s of slugs) { try { await p.goto(BASE + s + '/?v=' + Date.now(), { waitUntil: 'load', timeout: 25000 }); res.push({ s, ...(await p.evaluate(MEASURE)) }); } catch (e) { res.push({ s, err: String(e.message).slice(0, 80) }); } }
  await b.close(); return { how: 'Playwright の WebKit（iPhone 13 を再現）', res };
}
async function viaSafari() {
  const { spawn } = require('child_process'); const port = 4473;
  if (!require('fs').existsSync('/usr/bin/safaridriver')) return { skip: 'safaridriver が無い' };
  const sd = spawn('/usr/bin/safaridriver', ['-p', String(port)]); let sdErr = ''; sd.on('error', (e) => { sdErr = String(e.message); }); sd.stderr.on('data', (d) => { sdErr += String(d); }); await new Promise((r) => setTimeout(r, 2000));
  if (sd.exitCode !== null || /error|enable|allow/i.test(sdErr)) { sd.kill(); return { skip: 'safaridriver が起動しない: ' + sdErr.slice(0, 200) }; }
  const call = async (m, path, body) => { const r = await fetch(`http://127.0.0.1:${port}${path}`, { method: m, headers: { 'content-type': 'application/json' }, body: body ? JSON.stringify(body) : undefined }); return r.json(); };
  try {
    const s0 = await call('POST', '/session', { capabilities: { alwaysMatch: { browserName: 'safari' } } });
    const sid = s0.value && s0.value.sessionId; if (!sid) { return { skip: 'safaridriver が使えない: ' + JSON.stringify(s0.value).slice(0, 200) }; }
    await call('POST', `/session/${sid}/window/rect`, { width: 390, height: 900 }); const res = [];
    for (const s of slugs) { try { await call('POST', `/session/${sid}/url`, { url: BASE + s + '/?v=' + Date.now() }); const v = await call('POST', `/session/${sid}/execute/sync`, { script: 'return ' + MEASURE, args: [] }); res.push({ s, ...(v.value || {}) }); } catch (e) { res.push({ s, err: String(e.message).slice(0, 80) }); } }
    await call('DELETE', `/session/${sid}`); return { how: '本物の Safari（safaridriver・窓の幅 390）', res };
  } finally { sd.kill(); }
}
(async () => { let r = await viaPlaywright(); const tried = []; if (r.skip) { tried.push(r.skip); r = await viaSafari(); } if (r.skip) tried.push(r.skip); r.tried = tried; console.log(JSON.stringify(r)); process.exit(0); })().catch((e) => { console.log(JSON.stringify({ fatal: String(e.message).slice(0, 200) })); process.exit(0); });
JSEOF
{
echo "# Safari（WebKit）でチェックリストの崩れを測る（t773・\$0）"; echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"; echo
echo "- macOS: $(sw_vers -productVersion 2>/dev/null) / Safari: $(defaults read /Applications/Safari.app/Contents/Info CFBundleShortVersionString 2>/dev/null) / safaridriver: $(ls /usr/bin/safaridriver 2>/dev/null || echo 無し)"
echo "- WebKit（Playwright）: $(ls -d "$HOME"/Library/Caches/ms-playwright/webkit-* 2>/dev/null | head -2 | tr '\n' ' ' || echo 無し)"; echo
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?; echo "node --check rc=$CRC $(printf '%s' "$CK" | head -1 | cut -c1-120)"
[ "$CRC" -ne 0 ] && { rm -f "$RUNNER"; echo "**構文が通らない。走らせない。**"; exit 1; }
RAW="$W/.t773-out-$STAMP.json"; T0="$(date +%s)"
cd "$W" && SLUGS="$SLUGS" run_limited 240 "$RAW" node "$RUNNER"; RC=$?; echo "rc=$RC / $(( $(date +%s) - T0 )) 秒"; echo
node -e '
  const t = require("fs").readFileSync(process.argv[1], "utf8"); const line = t.trim().split("\n").filter((l) => l.startsWith("{")).pop();
  if (!line) { console.log("**出力が無い**\n```\n" + t.slice(0, 600) + "\n```"); process.exit(0); }
  const j = JSON.parse(line); if (j.fatal) { console.log("**止まった: " + j.fatal + "**"); process.exit(0); }
  if (j.tried && j.tried.length) console.log("試して使えなかったもの: " + j.tried.join(" ／ ") + "\n");
  if (!j.res) { console.log("**測れなかった**"); process.exit(0); }
  console.log("測り方: **" + j.how + "**\n");
  const ok = j.res.filter((r) => !r.err && r.n > 0), bad = ok.filter((r) => r.bad.length);
  console.log("対象 " + j.res.length + " 本 / 測れた " + ok.length + " 本 / **崩れのある記事 " + bad.length + " 本**\n");
  if (ok[0]) console.log("画面の幅 " + ok[0].vw + "px / :has が使える " + ok[0].has + " / UA " + ok[0].ua + "\n");
  console.log("| 記事 | 項目 | 包んだ項目 | 崩れ |\n| --- | --- | --- | --- |");
  for (const r of j.res) console.log("| " + r.s + " | " + (r.err ? "エラー " + r.err : r.n) + " | " + (r.wrapped ?? "") + " | " + (r.bad && r.bad.length ? r.bad.length + "（" + r.bad[0] + "）" : (r.err ? "" : "0")) + " |");
' "$RAW" 2>&1
} > "$OUT" 2>&1
rm -f "$RUNNER" "$RAW"
grep -m1 '崩れのある記事' "$OUT"; echo "$(basename "$OUT")"
