#!/usr/bin/env python3
"""アクセス分析ページ（Artifact）を作る。読むだけ・LLM 不使用・$0。

    python3 scripts/access-analysis/build.py \\
      --gsc gsc-2026-09.json --pv pv-2026-09.json \\
      --notes notes-2026-09.json --out access-analysis.html

- --gsc   : scripts/gsc-dump.py の出力（ops/heartbeat の reports/gsc-monthly/<YYYY-MM>.json）
- --pv    : ops/pv-archive の data/<YYYY-MM>.json
- --notes : 結論と「ここから言えること」。**数字から書く人（セッション）が毎月書く。**
            {"conclusions": ["…**太字**…", …], "actions": [{"tag": "…", "title": "…", "body": "…"}]}
            無ければ結論の節は数字だけの自動文になる

出力は 1 枚の HTML。Artifact に同じファイルパスで publish し直せば URL は変わらない。
"""
import argparse, collections, datetime, glob, html, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
LAB = {'campaigns': 'キャンペーン速報', 'services': 'サービス紹介', 'comparisons': '比較',
       'roundups': 'まとめ', 'howto': 'ハウツー', 'wangan-life': '湾岸ライフ'}


def posts():
    out = []
    for f in sorted(glob.glob(os.path.join(ROOT, 'src/content/posts/*.md'))):
        s = open(f, encoding='utf-8').read()
        fm = re.match(r'---\n(.*?)\n---', s, re.S).group(1)
        g = lambda k: (re.search(r'^' + k + r':\s*(.*)$', fm, re.M) or [None, ''])[1].strip().strip('"\'')
        if g('draft') == 'true':
            continue
        cat = g('category')
        try:
            c = json.loads(cat)[0] if cat.startswith('[') else cat
        except Exception:
            c = cat
        out.append(dict(slug=os.path.basename(f)[:-3], title=g('title'), date=g('publishDate'), cat=c, catL=LAB.get(c, c)))
    return out


def tot(rows):
    c = sum(r['c'] for r in rows); i = sum(r['i'] for r in rows)
    return c, i, (sum(r['p'] * r['i'] for r in rows) / i if i else 0)


def bold(s):
    s = html.escape(s)
    return re.sub(r'\*\*(.+?)\*\*', r'<b class="k">\1</b>', s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--gsc', required=True); ap.add_argument('--pv', required=True)
    ap.add_argument('--notes'); ap.add_argument('--out', required=True)
    a = ap.parse_args()
    G = json.load(open(a.gsc, encoding='utf-8')); g = G['data']; W = G['windows']
    pv = json.load(open(a.pv, encoding='utf-8'))
    notes = json.load(open(a.notes, encoding='utf-8')) if a.notes and os.path.exists(a.notes) else {}

    pvc = collections.Counter()
    for v in pv.values():
        for t in v.get('top', []):
            pvc[t['path']] += t['v']
    idx = lambda k: {r['keys'][0].split('.com')[-1]: r for r in g[k]}
    A, C, P = idx('pages_90d'), idx('pages_cur'), idx('pages_prev')
    rows = []
    for x in posts():
        u = f"/posts/{x['slug']}/"
        r, rc, rp = A.get(u, {}), C.get(u, {}), P.get(u, {})
        rows.append({**x, 'pv': pvc.get(u, 0), 'i': r.get('i', 0), 'c': r.get('c', 0), 'pos': r.get('p'),
                     'ic': rc.get('i', 0), 'cc': rc.get('c', 0), 'pc': rc.get('p'), 'ip': rp.get('i', 0), 'pp': rp.get('p')})

    days = sorted(pv)
    ym = G.get('month') or days[0][:7]
    y, m = map(int, ym.split('-'))
    weeks = {}
    for r in sorted(g['dates_90d'], key=lambda r: r['keys'][0]):
        dt = datetime.date.fromisoformat(r['keys'][0]); w = dt - datetime.timedelta(days=dt.weekday())
        x = weeks.setdefault(str(w), {'w': str(w), 'i': 0, 'c': 0, 'n': 0}); x['i'] += r['i']; x['c'] += r['c']; x['n'] += 1
    data = dict(rows=rows, weeks=list(weeks.values()),
                daily=[{'d': k, 'h': pv[k].get('human', 0), 'jp': pv[k].get('jp', 0)} for k in days],
                queries=[{'q': r['keys'][0], 'i': r['i'], 'c': r['c'], 'p': r['p']} for r in sorted(g['queries_90d'], key=lambda r: -r['i'])])

    cc, ci, cp = tot(g['pages_cur']); pc, pi, pp = tot(g['pages_prev']); c90, i90, _ = tot(g['pages_90d'])
    human = sum(pv[k].get('human', 0) for k in days); jp = sum(pv[k].get('jp', 0) for k in days)
    allv = sum(pv[k].get('visits', 0) for k in days)
    top = max(g['pages_90d'], key=lambda r: r['i'])
    topslug = top['keys'][0].rstrip('/').split('/')[-1]
    topname = next((p['title'].split('｜')[0] for p in rows if p['slug'] == topslug), topslug)[:18]
    qi = sum(r['i'] for r in g['queries_90d'])
    pct = lambda a_, b_: f"{(a_ - b_) / b_ * 100:+.0f}%" if b_ else '—'
    import calendar
    want = [f"{ym}-{d:02d}" for d in range(1, calendar.monthrange(y, m)[1] + 1)]
    miss = [d for d in want if d not in pv]
    fmt = lambda n: f"{n:,}"
    md = lambda s: f"{int(s[5:7])}/{int(s[8:10])}"

    concl = notes.get('conclusions') or [
        f"**検索での表示は {fmt(ci)} 回、クリックは {cc} 回でした。**前月は表示 {fmt(pi)} 回、クリック {pc} 回です。",
        f"**3 か月の検索表示の {top['i'] * 100 // max(i90, 1)}% は「{topname}」1 本です。**",
    ]
    acts = notes.get('actions') or []
    acts_html = ''
    if acts:
        acts_html = '<section>\n  <h2>ここから言えること</h2>\n  <div class="acts">' + ''.join(
            f'<div class="act"><span class="tag">{html.escape(x.get("tag", ""))}</span><h3>{html.escape(x["title"])}</h3><p>{bold(x["body"])}</p></div>'
            for x in acts) + '</div>\n</section>'

    rep = {
        'MONTH_LABEL': f"{y} 年 {m} 月", 'MONTH_SHORT': f"{m} 月", 'N_POSTS': str(len(rows)),
        'W90': f"{md(W['pages_90d'][0])}〜{md(W['pages_90d'][1])}", 'WCUR': f"{md(W['pages_cur'][0])}〜{md(W['pages_cur'][1])}",
        'WPREV': f"{md(W['pages_prev'][0])}〜{md(W['pages_prev'][1])}",
        'CONCLUSIONS': ''.join(f'<li>{bold(s)}</li>' for s in concl),
        'HUMAN': fmt(human), 'HUMAN_DAY': str(round(human / max(len(days), 1))), 'JP': fmt(jp),
        'IMP_CUR': fmt(ci), 'IMP_PREV': fmt(pi), 'IMP_DELTA': pct(ci, pi), 'IMP_CLS': 'up' if ci >= pi else 'down',
        'CLK_CUR': fmt(cc), 'CLK_PREV': fmt(pc), 'CLK_DELTA': pct(cc, pc), 'CLK_CLS': 'up' if cc >= pc else 'down',
        'POS_CUR': f"{cp:.1f}", 'POS_PREV': f"{pp:.1f}", 'POS_CLS': 'up' if cp <= pp else 'down',
        'ALL_VISITS': fmt(allv), 'BOT_PCT': str(round((1 - human / allv) * 100) if allv else 0),
        'IMP_90': fmt(i90), 'CLK_90': str(c90), 'TOP_NAME': html.escape(topname),
        'TOP_I': str(top['i']), 'TOP_I_F': fmt(top['i']), 'REST_I': str(i90 - top['i']), 'REST_I_F': fmt(i90 - top['i']),
        'TOP_C': str(top['c']), 'REST_C': str(c90 - top['c']),
        'MISSING_DAYS': ('・'.join(md(d) for d in miss) + ' は記録が取れていません。') if miss else '',
        'Q_IMP': fmt(qi), 'Q_PCT': str(round(qi / i90 * 100) if i90 else 0),
        'ACTIONS': acts_html, 'PV_DAYS': str(len(days)), 'GENERATED': G.get('generated', '')[:10],
        'DATA': 'const DATA=' + json.dumps(data, ensure_ascii=False) + ';',
    }
    t = open(os.path.join(HERE, 'template.html'), encoding='utf-8').read()
    for k, v in rep.items():
        t = t.replace('{{' + k + '}}', v)
    left = re.findall(r'\{\{[A-Z0-9_]+\}\}', t)
    if left:
        raise SystemExit(f'埋まっていない差し込み: {sorted(set(left))}')
    open(a.out, 'w', encoding='utf-8').write(t)
    print(f'{a.out}: {len(t):,} bytes / 記事 {len(rows)} / 当月 表示 {ci} クリック {cc}')


if __name__ == '__main__':
    main()
