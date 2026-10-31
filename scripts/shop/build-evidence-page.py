#!/usr/bin/env python3
# 使い方: git fetch origin ops/heartbeat → python3 scripts/shop/build-evidence-page.py <出力先>。Artifact「3店ボタンの証跡」https://claude.ai/artifact/9VGFmsTLBooRxm7V8AgCeD の元。LLM 不使用・$0
# 3 店ボタンの確認結果（ops/heartbeat の reports/shop-verify）から証跡ページを作る
import json, os, sys, html, subprocess, re
from PIL import Image

REPO = '/home/user/daily-hack'
OUT = sys.argv[1]  # 出力ディレクトリ
os.makedirs(os.path.join(OUT, 'shots'), exist_ok=True)
ART = [
    ('rechargeable-kairo-comparison-2026', '充電式カイロ', 'rechargeable-kairo'),
    ('mobile-battery-comparison-2026', 'モバイルバッテリー', 'mobile-battery'),
    ('heated-vest-comparison-2026', '電熱ベスト', 'heated-vest'),
]
STORES = [('rakuten', '楽天市場'), ('yahoo', 'Yahoo!ショッピング'), ('amazon', 'Amazon')]

def show(path):
    r = subprocess.run(['git', '-C', REPO, 'show', f'origin/ops/heartbeat:{path}'], capture_output=True)
    return r.stdout if r.returncode == 0 else None

def esc(s): return html.escape(str(s or ''))

rows_all = []
seen_keys = set()
for slug, label, ser in ART:
    data = json.load(open(f'{REPO}/src/data/shop/{ser}.json'))
    for st, stl in STORES:
        raw = show(f'reports/shop-verify/{slug}/result-{st}-v3.json') or show(f'reports/shop-verify/{slug}/result-{st}-v2.json')
        if not raw:
            print('結果なし', slug, st); continue
        res = json.loads(raw)
        for r in res['rows']:
            img = None
            if r.get('shot'):
                b = show(f"reports/shop-verify/{slug}/{r['shot']}")
                if b:
                    fn = f"{slug.split('-')[0]}-{r['shot']}"
                    p = os.path.join(OUT, 'shots', fn)
                    open(p, 'wb').write(b)
                    im = Image.open(p).convert('RGB'); im.thumbnail((1000, 1000)); im.save(p, quality=62)
                    img = f'shots/{fn}'
            r.update(slug=slug, label=label, storeLabel=stl, img=img, generated=res['generated'])
            fin = r.get('fin') or ''
            it = None
            for x in data['items']:
                y = x.get('yahoo') or {}
                if st == 'yahoo' and ((y.get('url') and fin.startswith(y['url'])) or (y.get('keyword') and '/search/' + y['keyword'].replace(' ', '+') + '/' in fin)):
                    it = x
            if it:
                r['name'] = r.get('name') or f"{it.get('brand', '')} {it['name']}".strip()
                if '/search/' in fin:
                    must = (it.get('yahoo') or {}).get('must') or []
                    norm = lambda t: re.sub(r'[\s\-‐－]', '', t.lower())
                    ok = [t for t in (r.get('top') or []) if all(norm(m) in norm(t) for m in must)]
                    r['keys'] = must; r['hits'] = len(ok); r['hitTitles'] = ok
            key = (slug, st, re.sub(r'[?#].*$', '', fin) if st == 'yahoo' else r.get('href'))
            if key in seen_keys: continue
            seen_keys.add(key)
            rows_all.append(r)

def verdict(r):
    if r.get('error'): return ('err', '確認できず')
    aff = not r.get('aff', '').startswith('**')
    fin = r.get('fin') or ''
    product = bool(re.search(r'amazon\.co\.jp/(.*/)?dp/|item\.rakuten\.co\.jp/|\.rakuten\.co\.jp/item/|store\.shopping\.yahoo\.co\.jp/', fin))
    # 商品ページ: 購入ボタンがあれば OK。無ければ「出品者一覧から」（Amazon の購入ボックスが無いページ）
    if product: buy = 'page' if r.get('cart') else 'nocart'
    elif (r.get('hits') or 0) > 0: buy = 'hit'
    else: buy = 'none'
    return (aff, buy)

stat = {}
for r in rows_all:
    s = stat.setdefault(r['store'], {'n': 0, 'aff': 0, 'buy': 0, 'none': 0, 'err': 0})
    s['n'] += 1
    if r.get('error'): s['err'] += 1; continue
    aff, buy = verdict(r)
    s['aff'] += 1 if aff else 0
    if buy == 'page': s['buy'] += 1
    else: s['none'] += 1
json.dump({k: v for k, v in stat.items()}, sys.stdout, ensure_ascii=False); print()
from datetime import datetime, timedelta
jst = lambda g: (datetime.fromisoformat(g.replace('Z','+00:00')) + timedelta(hours=9)).strftime('%Y年%m月%d日 %H:%M') if g else ''
gen = max((r['generated'] for r in rows_all), default='')

cards = []
for slug, label, ser in ART:
    rs = [r for r in rows_all if r['slug'] == slug]
    if not rs: continue
    cards.append(f'<h2 id="{slug}">{esc(label)}<span class="h2sub"><a href="https://daily-hack.fieldbeside.com/posts/{slug}/">記事を開く</a></span></h2>')
    for st, stl in STORES:
        for r in [x for x in rs if x['store'] == st]:
            if r.get('error'):
                cards.append(f'<article class="row bad" data-bad="1"><div class="meta"><span class="chip {st}">{stl}</span><h3>{esc(r.get("name"))}</h3><p class="err">押したが確かめられなかった: {esc(r["error"])}</p></div></article>')
                continue
            aff, buy = verdict(r)
            bad = (not aff) or buy in ('none', 'nocart', 'hit')
            affp = f'<span class="pill ok">紹介の印あり</span>' if aff else '<span class="pill ng">紹介の印なし</span>'
            if buy == 'page': buyp = '<span class="pill ok">その商品のページ・カートあり</span>'
            elif buy == 'hit': buyp = f'<span class="pill ng">検索ページのまま（該当商品 {r["hits"]} 件）</span>'
            elif buy == 'nocart': buyp = '<span class="pill ng">商品ページだがカートのボタンなし（出品者一覧からは買える）</span>'
            else: buyp = f'<span class="pill ng">検索ページのまま（上位の結果に型番が入った商品なし）</span>'
            keys = '・'.join(r.get('keys') or [])
            seen = r.get('hitTitles') or []
            top = r.get('top') or []
            titles = ''
            if buy == 'hit' and seen:
                titles = '<p class="t"><b>見つかった商品:</b> ' + esc(seen[0]) + '</p>'
            elif buy in ('page', 'nocart'):
                titles = '<p class="t"><b>ページの題名:</b> ' + esc(r.get('h1') or r.get('title')) + '</p>'
            elif top:
                titles = '<p class="t"><b>上位に出た商品:</b> ' + ' ／ '.join(esc(x) for x in top[:2]) + '</p>'
            img = f'<a class="shot" href="{r["img"]}" target="_blank" rel="noopener"><img src="{r["img"]}" alt="{esc(stl)}で着いた画面" loading="lazy"></a>' if r.get('img') else '<div class="shot none">写真なし</div>'
            cards.append(f'''<article class="row{' bad' if bad else ''}" data-bad="{1 if bad else 0}" data-store="{st}">
{img}
<div class="meta"><div class="chips"><span class="chip {st}">{stl}</span>{affp}{buyp}</div>
<h3>{esc(r.get("name"))}</h3>
<p class="k">照合した型番: <code>{esc(keys)}</code></p>{titles}
<dl><dt>着いた先</dt><dd><code>{esc(r.get("fin"))}</code></dd><dt>印の根拠</dt><dd>{esc((r.get("aff") or "").replace("**", ""))}</dd></dl></div></article>''')

def tile(st, stl):
    s = stat.get(st, {'n': 0, 'aff': 0, 'buy': 0, 'none': 0, 'err': 0})
    return f'''<div class="tile"><p class="tl">{stl}</p><p class="big">{s["aff"]}<small>/{s["n"]}</small></p><p class="sub">紹介の印あり</p>
<p class="big2 {'warn' if s['none'] else ''}">{s["buy"]}<small>/{s["n"]}</small></p><p class="sub">その商品のページに着き、カートのボタンがある{f"（残り {s['none']} 件は赤の行）" if s['none'] else ''}{f"・{s['err']} 件は確かめられず" if s['err'] else ''}</p></div>'''

page = f'''<title>3店ボタンの証跡</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=M+PLUS+1p:wght@400;700;800&family=IBM+Plex+Mono:wght@400&display=swap">
<style>
/* 1 列の検証台帳: 上に店ごとの集計、下に 1 ボタン 1 行（写真＋判定） */
:root {{ --bg:#f6f7f5; --panel:#ffffff; --fg:#1d2420; --muted:#5d6a63; --line:#d9dfdb; --ok:#1f7a4d; --okbg:#e3f3ea; --ng:#b3261e; --ngbg:#fbe7e5;
  --rk:#bf0000; --yh:#ff0033; --az:#232f3e; --azfg:#ff9900;
  --disp:"M PLUS 1p","Hiragino Sans",sans-serif; --body:"M PLUS 1p","Hiragino Sans","Noto Sans JP",sans-serif; --mono:"IBM Plex Mono",ui-monospace,monospace; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --bg:#141816; --panel:#1c211f; --fg:#e7ece9; --muted:#9aa8a0; --line:#2e3532; --ok:#6fd39f; --okbg:#173326; --ng:#ff8a80; --ngbg:#3a1c1a; color-scheme:dark }} }}
:root[data-theme="dark"] {{ --bg:#141816; --panel:#1c211f; --fg:#e7ece9; --muted:#9aa8a0; --line:#2e3532; --ok:#6fd39f; --okbg:#173326; --ng:#ff8a80; --ngbg:#3a1c1a; color-scheme:dark }}
body {{ background:var(--bg); color:var(--fg); font-family:var(--body); line-height:1.7; padding-left:max(16px,env(safe-area-inset-left,0px)); padding-right:max(16px,env(safe-area-inset-right,0px)); padding-block:24px 64px }}
.wrap {{ max-width:980px; margin:0 auto; display:grid; gap:20px }}
h1 {{ font-family:var(--disp); font-weight:800; font-size:1.7rem; line-height:1.3; margin:0; text-wrap:balance }}
.lead {{ margin:0; color:var(--muted); max-width:65ch }}
.tiles {{ display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:12px }}
@media (max-width:640px) {{ .tiles {{ grid-template-columns:1fr }} }}
.tile {{ background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:14px 16px }}
.tile p {{ margin:0 }} .tl {{ font-weight:700 }}
.big,.big2 {{ font-family:var(--disp); font-weight:800; font-size:2rem; line-height:1.1; margin-top:6px!important; color:var(--ok); font-variant-numeric:tabular-nums }}
.big2.warn {{ color:var(--ng) }}
.big small,.big2 small {{ font-size:1rem; color:var(--muted) }}
.sub {{ font-size:.85rem; color:var(--muted); overflow-wrap:anywhere }}
.how {{ background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:16px 18px }}
.how h2 {{ margin:0 0 8px; font-size:1.1rem }}
.how dl {{ display:grid; grid-template-columns:9em minmax(0,1fr); gap:8px 14px; margin:0 }}
@media (max-width:560px) {{ .how dl {{ grid-template-columns:1fr }} }}
.how dt {{ font-weight:700 }} .how dd {{ margin:0 }}
.note {{ font-size:.9rem; color:var(--muted); margin:10px 0 0 }}
.bar {{ display:flex; gap:8px; flex-wrap:wrap; align-items:center; position:sticky; top:env(safe-area-inset-top,0px); background:var(--bg); padding-block:8px; z-index:2 }}
.bar button {{ font:inherit; border:1px solid var(--line); background:var(--panel); color:var(--fg); border-radius:999px; padding:4px 14px; cursor:pointer }}
.bar button[aria-pressed="true"] {{ background:var(--fg); color:var(--bg); border-color:var(--fg) }}
.bar button:focus-visible {{ outline:2px solid var(--ok); outline-offset:2px }}
h2 {{ font-family:var(--disp); font-size:1.3rem; margin:16px 0 0; display:flex; gap:12px; align-items:baseline; flex-wrap:wrap }}
.h2sub {{ font-size:.85rem; font-weight:400 }} a {{ color:var(--ok) }}
.row {{ display:grid; grid-template-columns:280px minmax(0,1fr); gap:16px; background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:12px }}
.row.bad {{ border-color:var(--ng) }}
@media (max-width:640px) {{ .row {{ grid-template-columns:1fr }} }}
.shot img {{ display:block; width:100%; border-radius:4px; border:1px solid var(--line) }}
.shot.none {{ display:grid; place-items:center; min-height:120px; color:var(--muted); border:1px dashed var(--line); border-radius:4px }}
.meta {{ min-width:0; display:grid; gap:6px; align-content:start }}
.meta h3 {{ margin:0; font-size:1.05rem }} .meta p {{ margin:0 }}
.chips {{ display:flex; gap:6px; flex-wrap:wrap }}
.chip,.pill {{ font-size:.78rem; border-radius:4px; padding:1px 8px; font-weight:700; letter-spacing:.02em }}
.chip.rakuten {{ background:var(--rk); color:#fff }} .chip.yahoo {{ background:var(--yh); color:#fff }} .chip.amazon {{ background:var(--az); color:var(--azfg) }}
.pill.ok {{ background:var(--okbg); color:var(--ok) }} .pill.ng {{ background:var(--ngbg); color:var(--ng) }}
.k,.t {{ font-size:.88rem }} .err {{ color:var(--ng) }}
dl {{ margin:0; display:grid; grid-template-columns:5.5em minmax(0,1fr); gap:2px 10px; font-size:.82rem }}
dt {{ color:var(--muted) }} dd {{ margin:0; min-width:0 }}
code {{ font-family:var(--mono); font-size:.78rem; overflow-wrap:anywhere }}
</style>
<div class="wrap">
<header style="display:grid;gap:8px"><h1>3 店ボタンの証跡｜比較記事 3 本・{len(rows_all)} 商品×店</h1>
<p class="lead">本番の記事でボタンを 1 つずつ実際に押し、着いた先の URL と画面を記録した（同じリンクのボタンは 1 回にまとめた）。カートには入れていない。確認日時 {esc(jst(gen))}（日本時間）。</p></header>
<section class="tiles">{''.join(tile(s, l) for s, l in STORES)}</section>
<section class="how"><h2>何を見たか</h2><dl>
<dt>楽天市場</dt><dd>ボタンは <code>hb.afl.rakuten.co.jp</code>（楽天アフィリエイト）を経由する。着いた先の URL に楽天が付ける <code>scid=af_pc_etc</code> が残っていれば、紹介経由として記録されている。</dd>
<dt>Yahoo!ショッピング</dt><dd>記事のリンクは素の商品 URL だが、押した瞬間にバリューコマースの LinkSwitch（<code>vc_pid=892728470</code>）が成果リンクへ差し替える。途中で <code>valuecommerce.com</code> を通り、着いた先に <code>sc_e=afvc_shp</code> が付く。</dd>
<dt>Amazon</dt><dd>着いた先の URL に、こちらのアソシエイト ID <code>tag=dailyhack-22</code> が残っているか。</dd>
<dt>買えるか</dt><dd>着いた画面の検索結果を 1 件ずつ読み、型番（例: <code>MTL-E030</code>）を含む商品があるかを数えた。商品ページに直接着いたものは、題名に型番があり「カートに入れる」ボタンがあるか。</dd>
</dl><p class="note">2026年10月31日に、楽天と Amazon のボタンを検索ページから商品ページへ張り替えた。その店で型番の商品が見つからなかったものは、検索ページのまま残っている（赤で示した行）。紹介の記録は、楽天は押してから 24 時間、Amazon は 24 時間以内にカートへ入れた商品に付く。実際に報酬が付いたかどうかは、購入が入ったあとに各社の管理画面でしか確かめられない。Amazon は自分の注文を数えない。</p></section>
<nav class="bar" aria-label="絞り込み"><button type="button" id="f-all" aria-pressed="true">すべて</button><button type="button" id="f-bad" aria-pressed="false">問題があるものだけ</button>
<span class="sub">写真を押すと大きく開く</span></nav>
{''.join(cards)}
</div>
<script>
const all=document.getElementById('f-all'),bad=document.getElementById('f-bad');
function f(only){{all.setAttribute('aria-pressed',!only);bad.setAttribute('aria-pressed',only);document.querySelectorAll('.row').forEach(r=>r.hidden=only&&r.dataset.bad!=='1');}}
all.onclick=()=>f(false);bad.onclick=()=>f(true);
</script>
'''
open(os.path.join(OUT, 'index.html'), 'w').write(page)
print('rows', len(rows_all))
