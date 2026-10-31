#!/usr/bin/env python3
"""YouTube だけ先に入れた「声と動画」の節に、あとから X の投稿を足す（2026-10-31）。
使い方: python3 scripts/embeds/add-x.py <候補 all.json> <picks.json>（picks は {slug: {"x": [[id, 一言], ...]}}）"""
import json, re, sys, html, pathlib, datetime
cands = json.load(open(sys.argv[1])); picks = json.load(open(sys.argv[2]))
def jdate(iso):
    d = datetime.datetime.fromisoformat(iso.replace('Z', '+00:00')) + datetime.timedelta(hours=9)
    return f'{d.year}年{d.month}月{d.day}日'
OLD = '<p class="source-note">埋め込んだ YouTube は、2026年10月31日に oEmbed でタイトルと投稿者を照合し、実在を確かめたもの。投稿した人の個人の感想・撮影時点の内容で、この記事の数字とは別のもの。</p>'
NEW = '<p class="source-note">引用した X の投稿は、2026年10月31日に本文・投稿者・日付を確かめたもの。埋め込んだ YouTube は oEmbed でタイトルと投稿者を照合し、実在を確かめたもの。どちらも投稿した人の個人の感想・撮影時点の内容で、この記事の数字とは別のもの。</p>'
for slug, pk in picks.items():
    p = pathlib.Path(f'src/content/posts/{slug}.md'); s = p.read_text()
    if 'class="twitter-tweet' in s: print('skip', slug); continue
    m = re.search(r'^## [^\n]*の声と動画[^\n]*\n\n[^\n]+\n\n', s, re.M)
    if not m: print('no section', slug); continue
    xs = {x['id']: x for x in cands[slug]['x']}; out = []
    for xid, note in pk['x']:
        x = xs[xid]; t = html.escape(x['text'])
        if len(x['text']) >= 300: t += '…'
        t = re.sub(r'\s*https://t\.co/\S+', '', t)
        out += [f'<blockquote class="twitter-tweet" data-lang="ja"><p lang="ja">{t}</p>&mdash; {html.escape(x["name"] or "")} (@{x["sn"]}) <a href="https://twitter.com/{x["sn"]}/status/{xid}">{jdate(x["at"])}</a></blockquote>', '', note, '']
    out += ['<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>', '', '']
    s = s[:m.end()] + '\n'.join(out) + s[m.end():]
    s = s.replace(OLD, NEW, 1)
    s = re.sub(r'^(## [^\n]*の声と動画[^\n]*\n\n)[^\n]*動画で[^\n]*\n', lambda mm: mm.group(1) + '実際に使っている人の投稿と動画で補っておく。\n', s, count=1, flags=re.M)
    p.write_text(s); print('ok', slug, len(pk['x']))
