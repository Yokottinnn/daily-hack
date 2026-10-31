#!/usr/bin/env python3
"""比較記事に X の実投稿と YouTube を差し込む（2026-10-31 利用者「Xの投稿記事とかYoutubeの動画は私の記事だとマスト」）。
候補は ops/tasks の embed-search（syndication と oEmbed で照合済み）の JSON。選んだ ID と一言は picks JSON に書く。
使い方: python3 scripts/embeds/insert-voices.py <候補 all.json> <picks.json>
"""
import json, re, sys, html, pathlib, datetime

cands = json.load(open(sys.argv[1]))
picks = json.load(open(sys.argv[2]))

def jdate(iso):
    d = datetime.datetime.fromisoformat(iso.replace('Z', '+00:00')) + datetime.timedelta(hours=9)
    return f'{d.year}年{d.month}月{d.day}日'

for slug, pk in picks.items():
    p = pathlib.Path(f'src/content/posts/{slug}.md')
    s = p.read_text()
    if 'class="twitter-tweet' in s or 'class="yt-embed' in s:
        print('skip (already has embeds)', slug); continue
    c = cands[slug]
    xs = {x['id']: x for x in c['x']}
    ys = {y['id']: y for y in c['yt']}
    out = [f"## {pk['heading']}", '', pk['lead'], '']
    for xid, note in pk.get('x', []):
        x = xs[xid]
        t = html.escape(x['text']).replace('\n', '<br>')
        if len(x['text']) >= 300: t += '…'
        t = re.sub(r'\s*https://t\.co/\S+', '', t)
        out += [f'<blockquote class="twitter-tweet" data-lang="ja"><p lang="ja">{t}</p>&mdash; {html.escape(x["name"] or "")} (@{x["sn"]}) <a href="https://twitter.com/{x["sn"]}/status/{xid}">{jdate(x["at"])}</a></blockquote>', '', note, '']
    if pk.get('x'):
        out += ['<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>', '']
    for yid, note in pk.get('yt', []):
        y = ys[yid]
        title = html.escape(f"{y['oTitle']}（{y['oAuthor']}）", quote=True)
        out += ['<div class="yt-embed">', f'<iframe src="https://www.youtube-nocookie.com/embed/{yid}" title="{title}" loading="lazy" allowfullscreen allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"></iframe>', '</div>', '', note, '']
    out += ['<p class="source-note">引用した X の投稿は、2026年10月31日に本文・投稿者・日付を確かめたもの。埋め込んだ YouTube は oEmbed でタイトルと投稿者を照合し、実在を確かめたもの。どちらも投稿した人の個人の感想・撮影時点の内容で、この記事の数字とは別のもの。</p>', '']
    block = '\n'.join(out) + '\n'
    hs = [m.start() for m in re.finditer(r'^## ', s, re.M)]
    target = next((m.start() for m in re.finditer(r'^## .*(まとめ|よくある質問|FAQ|Q&A)', s, re.M)), None)
    if target is None: target = hs[-1] if hs else len(s)
    s = s[:target] + block + '\n' + s[target:]
    p.write_text(s)
    print('ok', slug, len(pk.get('x', [])), len(pk.get('yt', [])))
