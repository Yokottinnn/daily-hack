# **表のセルにロゴを差す。** `find-missing-logos.mjs` が挙げた箇所を実際に埋める側。
#
#   python3 scripts/add-cell-logos.py <slug>                    # 試しに見るだけ
#   python3 scripts/add-cell-logos.py <slug> --apply            # 書く
#   python3 scripts/add-cell-logos.py <slug> --borrow --apply   # **他記事の在庫も使う**
#
# `--borrow` は他記事の `logos/` から複製し、`_manifest.json` に
# **取得元をそのまま引き継ぐ**（`copied_from` も残す）。最上位ルール 17 は
# 「どこから取ったか言えない画像は使わない」と決めているため、出所なしの複製はしない。
#
# ## 入れない箇所（機械で弾いている）
#
# - **セルの中でブランド名が脇役のとき**（文字数の 5 割 未満）。
#   「松屋アプリ事前注文 × d払い」のような説明文に差さない
# - **並列のセル**（`楽天・d・PayPay・現金`）。どれか 1 つに差すと誤解を招く
# - **1 セルに 2 ブランド以上** が主役で並ぶとき
#
# ## 機械では弾けないこと（**必ず目で見る**）
#
# - **運営会社を子ブランドに当てていないか**（三井不動産 ≠ 三井アウトレットパーク）
# - **括弧の中のブランドを拾っていないか**。実際に
#   `楽天トラベル（楽天ふるさと納税）` で後ろを拾い、手で直した
#
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

own = entries_of(logos) if manp.exists() else []
pool = list(own)
if borrow:
    for d in sorted(pathlib.Path('public/images').iterdir()):
        ld = d / 'logos'
        if d.name == slug or not (ld / '_manifest.json').exists(): continue
        for b, f, v in entries_of(ld):
            if any(b == ob for ob, _, _ in pool): continue
            pool.append((b, f, dict(v, _from=str(ld / f))))
pool.sort(key=lambda x: -len(x[0]))

def strip(s):
    s = re.sub(r'<[^>]*>', ' ', s)
    s = re.sub(r'\]\([^)]*\)', '] ', s)
    s = re.sub(r'https?://\S+', ' ', s)
    s = re.sub(r'[*_`#|]', ' ', s)
    s = ''.join(' ' if unicodedata.category(c) == 'So' else c for c in s)
    return re.sub(r'\s+', ' ', s).strip()

norm = lambda s: re.sub(r'[\s　・()（）]', '', s).lower()
used = {}

def match(inner):
    """セルの中身を見て、ブランドが主役なら (file, brand, meta) を返す"""
    if 'cell-brand' in inner or 'brand-logo' in inner: return None
    t = strip(inner); tn = norm(t)
    if not tn: return None
    # **「楽天・d・PayPay・現金」のような並列は、どれか 1 つに差すと誤解を招く。**
    # `norm()` が中黒を落とすので、落とす前に見る
    listy = '・' in t or '／' in t
    hit = []
    for b, f, v in pool:
        bn = norm(b)
        if len(bn) < 2 or bn not in tn: continue
        if len(bn) / len(tn) < 0.5: continue
        # **既に採ったブランドの部分文字列は同じものと見なす**（「楽天トラベル」と「楽天」）
        if any(bn in norm(pb) or norm(pb) in bn for pb, _, _ in hit): continue
        if listy and '・' not in b and '／' not in b:
            print(f'  ?? 見送り（並列のセル）: {t[:55]}  -> {b}')
            continue
        hit.append((b, f, v))
    if not hit: return None
    if len(hit) > 1:
        # **1 セルに 2 つ以上のブランドが並んでいる。** どれか 1 つだけ差すのは誤解を招く
        print(f'  ?? 見送り（{len(hit)} ブランド）: {t[:55]}  -> ' + ' / '.join(b for b, _, _ in hit))
        return None
    b, f, v = hit[0]
    return (f, b, v)

def tag(inner, f):
    return (f'<span class="cell-brand"><img class="brand-logo-sm" '
            f'src="/images/{slug}/logos/{f}" alt="" loading="lazy" />{inner}</span>')

lines = md.read_text(encoding='utf-8').split('\n')
CELL = re.compile(r'(<t[dh]\b[^>]*>)(.*?)(</t[dh]>)', re.S)
n = 0
for i, line in enumerate(lines):
    t = line.strip()
    # ① HTML の表
    if '<t' in line:
        def fix(m):
            global n
            r = match(m.group(2))
            if not r: return m.group(0)
            f, b, v = r; n += 1; used[f] = (b, v)
            print(f'  {i+1}: [{b}] {strip(m.group(2))[:55]}')
            return m.group(1) + tag(m.group(2), f) + m.group(3)
        lines[i] = CELL.sub(fix, line)
        continue
    # ② Markdown の表（区切り行は触らない）
    if t.startswith('|') and t.endswith('|') and not re.fullmatch(r'\|[\s:|-]+\|', t):
        cells = t.split('|')
        for j in range(1, len(cells) - 1):
            r = match(cells[j])
            if not r: continue
            f, b, v = r; n += 1; used[f] = (b, v)
            print(f'  {i+1}: [{b}] {strip(cells[j])[:55]}')
            cells[j] = ' ' + tag(cells[j].strip(), f) + ' '
        lines[i] = '|'.join(cells)

print(f'\n{slug}: {n} セル / ロゴ {len(used)} 種' + ('（書いた）' if apply_ else '（試しに見ただけ）'))
if not apply_ or not n: sys.exit(0)

for f, (b, v) in used.items():
    src = v.get('_from')
    if src and not (logos / f).exists():
        shutil.copy(src, logos / f)
        print(f'  複製: {src} -> {logos / f}')
    if f not in man:
        e = {k: val for k, val in v.items() if not k.startswith('_')}
        if src: e['copied_from'] = src
        man[f] = e
manp.write_text(json.dumps(man, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
md.write_text('\n'.join(lines), encoding='utf-8')
