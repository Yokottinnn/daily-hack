# **見出しにロゴを差す。** `find-missing-logos.mjs` が挙げた見出しを実際に埋める側。
# 表のセルは `add-cell-logos.py` のほう。
#
#   npm run build                                     # ← **先に必要**（id を dist から読む）
#   python3 scripts/add-heading-logos.py <slug>              # 試しに見るだけ
#   python3 scripts/add-heading-logos.py <slug> --apply      # 書く
#   python3 scripts/add-heading-logos.py <slug> --borrow --apply
#
# ## Markdown の見出しを HTML にすると、id が消える
#
# `### 楽天でんき` には **rehype が自動で id を付ける**が、
# `<h3 class="brand-h">…</h3>` と生の HTML で書くと **id が付かない。**
# 記事内のアンカー（`#-サウナ蒸薪53埼玉` など）が黙って切れる。
#
# **だから `dist` の HTML から id を読んで、書き写す。**
# ビルドしていないと id が分からないので、その場合は**その見出しを飛ばす**。
#
# 生の HTML の見出し（`<h3>楽天モバイル</h3>`）は**もともと id が付かない**ので、
# 書き写すものが無い。クラスと img を足すだけ。
#
# ## 入れない見出し（機械で弾いている）
#
# - **ブランド名が脇役のとき**（文字数の 5 割 未満）。
#   `### Q. ahamoとLINEMO、結局どっち？` のような FAQ に差さない
# - **1 見出しに 2 ブランド以上**が主役で並ぶとき
#
# ## 機械では弾けないこと（**必ず目で見る**）
#
# - 運営会社を子ブランドに当てていないか（三井不動産 ≠ 三井アウトレットパーク）
# - 括弧の中のブランドを拾っていないか
import html as htmllib
import json, re, sys, pathlib, shutil, unicodedata

slug = sys.argv[1]
apply_ = '--apply' in sys.argv
borrow = '--borrow' in sys.argv
md = pathlib.Path(f'src/content/posts/{slug}.md')
logos = pathlib.Path(f'public/images/{slug}/logos')
logos.mkdir(parents=True, exist_ok=True)
manp = logos / '_manifest.json'
man = json.loads(manp.read_text(encoding='utf-8')) if manp.exists() else {
    '_note': '識別目的で使うロゴ。**商標であり自由ライセンスではない。** 改変しない（CSS の枠は可）。'
}

def entries_of(d):
    m = json.loads((d / '_manifest.json').read_text(encoding='utf-8'))
    out = []
    for k, v in m.items():
        if not isinstance(v, dict) or k.startswith('_'): continue
        f = v.get('file') or (k if '.' in k else None)
        if not f or not (d / f).exists(): continue
        b = (v.get('brand') or '').strip()
        if b: out.append((b, f, v))
    return out

pool = entries_of(logos) if manp.exists() else []
if borrow:
    for d in sorted(pathlib.Path('public/images').iterdir()):
        ld = d / 'logos'
        if d.name == slug or not (ld / '_manifest.json').exists(): continue
        for b, f, v in entries_of(ld):
            if any(b == ob for ob, _, _ in pool): continue
            pool.append((b, f, dict(v, _from=str(ld / f))))
pool.sort(key=lambda x: -len(x[0]))

# --- dist から「見出しの文字 -> id」を読む（**書き写すため**） ---
ids = {}
dist = pathlib.Path(f'dist/posts/{slug}/index.html')
if dist.exists():
    for m in re.finditer(r'<h([234])\s+id="([^"]+)"[^>]*>(.*?)</h\1>', dist.read_text(encoding='utf-8'), re.S):
        txt = re.sub(r'<[^>]*>', '', m.group(3))
        ids[htmllib.unescape(txt).strip()] = m.group(2)
else:
    print('  ⚠️ dist が無い。**Markdown の見出しは飛ばす**（id を書き写せないため）。先に npm run build')

def strip(s):
    s = re.sub(r'<[^>]*>', ' ', s)
    s = re.sub(r'\]\([^)]*\)', '] ', s)
    s = re.sub(r'https?://\S+', ' ', s)
    s = re.sub(r'[*_`#]', ' ', s)
    s = ''.join(' ' if unicodedata.category(c) == 'So' else c for c in s)
    return re.sub(r'\s+', ' ', s).strip()

norm = lambda s: re.sub(r'[\s　・()（）]', '', s).lower()

def match(text):
    t = strip(text); tn = norm(t)
    if not tn: return None
    if re.search(r'[・／]| / ', t): return None
    hit = []
    for b, f, v in pool:
        bn = norm(b)
        if len(bn) < 2 or bn not in tn: continue
        if len(bn) / len(tn) < 0.5: continue
        if any(bn in norm(pb) or norm(pb) in bn for pb, _, _ in hit): continue
        hit.append((b, f, v))
    if len(hit) != 1:
        if hit: print(f'  ?? 見送り（{len(hit)} ブランド）: {t[:55]}')
        return None
    return hit[0]

lines = md.read_text(encoding='utf-8').split('\n')
MD_H = re.compile(r'^(#{2,4})\s+(.*\S)\s*$')
HTML_H = re.compile(r'^(\s*)<h([234])>(.*?)</h\2>\s*$')
n = 0
used = {}
for i, line in enumerate(lines):
    if 'brand-h' in line: continue
    mmd = MD_H.match(line)
    mh = HTML_H.match(line)
    if not mmd and not mh: continue
    text = mmd.group(2) if mmd else mh.group(3)
    r = match(text)
    if not r: continue
    b, f, v = r
    lvl = len(mmd.group(1)) if mmd else int(mh.group(2))
    indent = '' if mmd else mh.group(1)
    if mmd:
        key = htmllib.unescape(strip(text))
        hid = ids.get(key)
        if not hid:
            print(f'  ?? 見送り（id が dist に無い）: {key[:55]}')
            continue
        idattr = f' id="{hid}"'
    else:
        idattr = ''          # 生の HTML の見出しは、もともと id が付かない
    n += 1; used[f] = (b, v)
    print(f'  {i+1}: [{b}] {strip(text)[:55]}' + (f'  id={idattr.strip()}' if idattr else ''))
    lines[i] = (f'{indent}<h{lvl} class="brand-h"{idattr}>'
                f'<img class="brand-logo" src="/images/{slug}/logos/{f}" alt="{b}のロゴ" loading="lazy" />'
                f'<span>{text}</span></h{lvl}>')

print(f'\n{slug}: 見出し {n} 本 / ロゴ {len(used)} 種' + ('（書いた）' if apply_ else '（試しに見ただけ）'))
if not apply_ or not n: sys.exit(0)
for f, (b, v) in used.items():
    src = v.get('_from')
    if src and not (logos / f).exists():
        shutil.copy(src, logos / f); print(f'  複製: {src} -> {logos / f}')
    if f not in man:
        e = {k: val for k, val in v.items() if not k.startswith('_')}
        if src: e['copied_from'] = src
        man[f] = e
manp.write_text(json.dumps(man, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
md.write_text('\n'.join(lines), encoding='utf-8')
