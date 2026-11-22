#!/bin/bash
# **Yahoo!ショッピングの検索結果の「1 件ずつの箱」と広告枠の作りを読む（t981・読むだけ・LLM 不使用）。**
# t980 で、今の道具のセレクタ（[class*="SearchResult"] li）が検索結果のページ全体の li#searchResults1 を 1 件として拾い、
# その中のいちばん長い行（先頭の広告の題名）を商品名にしていたと分かった。その中の 1 件ずつの箱と、広告の箱を見分ける印を読む。
# 出すのは数・クラス名・属性名・リンクのホスト・短い印（PR・広告など）だけ。**画面の写真・本文・商品名は出さない**。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t981-yahoo-search-cards-read.md"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# Yahoo! の検索結果の 1 件ずつの箱（t981・読むだけ・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
[ -n "$NODE_BIN" ] || { echo "⚠️ node が無い" >> "$OUT"; cat "$OUT"; exit 0; }
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
JS="$RDIR/.t981-read.cjs"
cat > "$JS" <<'JSEOF'
const fs = require('fs'), path = require('path'), os = require('os');
const PW = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')].find((d) => fs.existsSync(path.join(d, 'playwright-core')));
if (!PW) { console.log('playwright-core が無い'); process.exit(0); }
const { chromium } = require(path.join(PW, 'playwright-core'));
const QS = [['象印 炎舞炊き NX-AB10', 'NX-AB10'], ['象印 圧力IH NW-YD10', 'NW-YD10']];
(async () => {
  const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
  const ctx = b.contexts()[0] || (await b.newContext());
  for (const [q, key] of QS) {
    const p = await ctx.newPage();
    try {
      await p.goto(`https://shopping.yahoo.co.jp/search?p=${encodeURIComponent(q)}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await p.waitForTimeout(5000);
      const r = await p.evaluate((key) => {
        const norm = (s) => (s || '').toLowerCase().replace(/[\s\-‐－]/g, '');
        const cls = (e) => (typeof e.className === 'string' ? e.className : (e.getAttribute && e.getAttribute('class')) || '').split(/\s+/).filter(Boolean).slice(0, 3).join('.');
        const tag = (x) => x.tagName.toLowerCase() + (x.id ? '#' + x.id : '') + (cls(x) ? '.' + cls(x) : '');
        const attrs = (e) => [...e.attributes].filter((a) => a.name.startsWith('data-') || a.name === 'role' || a.name === 'aria-label').map((a) => a.name + (/^(data-(ad|pr|is|type|cl|sc|pos|beacon)|role)/.test(a.name) ? '=' + a.value.slice(0, 30) : '')).join(',');
        const root = document.querySelector('#searchResults') || document.body;
        // 商品のリンク（store.shopping.yahoo.co.jp/<店>/<品>.html）。リンクの href から店/品の組を作る
        const itemKey = (a) => { try { const u = new URL(a.href); const m = u.pathname.match(/^\/([^/]+)\/([^/]+?)\.html/); return u.hostname === 'store.shopping.yahoo.co.jp' && m ? m[1] + '/' + m[2] : ''; } catch { return ''; } };
        const anchors = [...root.querySelectorAll('a[href]')].filter((a) => itemKey(a));
        // 1 件の箱: その品のリンクだけを含む、いちばん外側の祖先
        const cards = new Map();
        for (const a of anchors) {
          const k = itemKey(a); let box = a;
          while (box.parentElement && box.parentElement !== root) {
            const ks = new Set([...box.parentElement.querySelectorAll('a[href]')].map(itemKey).filter(Boolean));
            if (ks.size > 1) break; box = box.parentElement;
          }
          if (!cards.has(box)) cards.set(box, k);
        }
        const list = [...cards.keys()];
        const marks = (e) => [...new Set([...e.querySelectorAll('*')].filter((x) => x.children.length === 0).map((x) => (x.textContent || '').trim()).filter((t) => t.length <= 8 && /PR|広告|スポンサー|Sponsored|ストアの広告/i.test(t)))].join('/');
        const imgAlt = (e) => [...new Set([...e.querySelectorAll('img[alt]')].map((i) => i.alt.trim()).filter((t) => t.length <= 8 && /PR|広告/i.test(t)))].join('/');
        const hostsOf = (e) => [...new Set([...e.querySelectorAll('a[href]')].map((a) => { try { const u = new URL(a.href); return u.hostname; } catch { return ''; } }).filter(Boolean))].join(' ');
        const rows = list.slice(0, 45).map((e, i) => {
          const anc = []; let x = e.parentElement; for (let j = 0; j < 3 && x && x !== root; j++, x = x.parentElement) anc.push(tag(x));
          const allA = [...e.querySelectorAll('a[href]')];
          const q = allA.map((a) => { try { return [...new URL(a.href).searchParams.keys()].join('&'); } catch { return ''; } }).filter(Boolean);
          return { i, box: tag(e), attrs: attrs(e), anc: anc.join(' < '), marks: marks(e), alt: imgAlt(e), hosts: hostsOf(e), qkeys: [...new Set(q)].slice(0, 3).join(' | ').slice(0, 120), key: key ? norm(e.innerText).includes(norm(key)) : null, len: (e.innerText || '').length };
        });
        const g = {}; for (const r of rows) { const k = r.box.replace(/\.[^.]*$/, '') + ' < ' + r.anc.split(' < ')[0]; g[k] = (g[k] || 0) + 1; }
        return { anchors: anchors.length, cards: list.length, rows, g };
      }, key);
      console.log(`\n## 検索: ${q}（型番 ${key}）`);
      console.log(`- 商品のリンク: ${r.anchors} 本 / 1 件ずつの箱: ${r.cards} 個`);
      console.log('- 箱の形ごとの数:'); for (const [k, v] of Object.entries(r.g)) console.log(`  - ${v} 件: \`${k}\``);
      console.log('- 箱 1 つずつ（順番・型番を含むか・印・属性・リンクのホスト・リンクの引数名）:');
      for (const x of r.rows) console.log(`  - ${x.i} key=${x.key ? 1 : 0} marks=${x.marks || '-'} alt=${x.alt || '-'} attrs=${x.attrs || '-'} len=${x.len} hosts=${x.hosts} q=${x.qkeys || '-'}\n    \`${x.box}\` < \`${x.anc}\``);
    } catch (e) { console.log(`- ⚠️ ${q}: ${String(e).split('\n')[0].slice(0, 160)}`); }
    await p.close().catch(() => {});
  }
  process.exit(0);
})();
JSEOF
( run_limited 120 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$OUT"
