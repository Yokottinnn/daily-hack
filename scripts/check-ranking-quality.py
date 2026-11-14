#!/usr/bin/env python3
"""ランキング記事の質の下限を数える（2026-11-14 利用者「ららぽーとの記事のようなクオリティは絶対に維持」）。
下限は CLAUDE.md 最上位ルール 6 の表。使い方: python3 scripts/check-ranking-quality.py <slug> [<slug> ...]
引数なしなら、category に rankings を含む 2026-11-14 以降の記事を全部見る。"""
import re, sys, pathlib
MIN = {'本文の字数': 15000, '対象ごとの節(h3)': 10, '表': 6, '写真(figure)': 10, 'Xの実投稿': 3, 'YouTube': 3}
def measure(md):
    t = md.split('---', 2)[2]
    plain = re.sub(r'<[^>]+>', '', t)
    plain = re.sub(r'^\|.*\|$', '', plain, flags=re.M)
    plain = re.sub(r'[#*`>|]', '', plain)
    return {
        '本文の字数': len(re.sub(r'\s', '', plain)),
        '対象ごとの節(h3)': len(re.findall(r'^### |<h3', t, flags=re.M)),
        '表': len(re.findall(r'^\| ?---|<table', t, flags=re.M)),
        '写真(figure)': len(re.findall(r'<figure', t)),
        'Xの実投稿': len(re.findall(r'twitter-tweet', t)),
        'YouTube': len(re.findall(r'youtube(-nocookie)?\.com/embed/', t)),
    }
args = sys.argv[1:]
posts = pathlib.Path('src/content/posts')
if not args:
    for f in sorted(posts.glob('*.md')):
        s = f.read_text(encoding='utf-8')
        if re.search(r'^category:.*"rankings"', s, re.M) and (m := re.search(r'^publishDate:\s*(\S+)', s, re.M)) and m.group(1) >= '2026-11-14':
            args.append(f.stem)
bad = 0
for slug in args:
    m = measure((posts / f'{slug}.md').read_text(encoding='utf-8'))
    ng = [f'{k} {v}/{MIN[k]}' for k, v in m.items() if v < MIN[k]]
    print(('✗ ' if ng else '✓ ') + slug + ('  不足: ' + '・'.join(ng) if ng else ''))
    bad += bool(ng)
print(f'\n{len(args)} 本中 {bad} 本が下限に届いていない' if bad else f'\n{len(args)} 本すべて下限を満たす')
sys.exit(1 if bad else 0)
