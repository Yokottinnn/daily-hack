# -*- coding: utf-8 -*-
"""6 枚のタイルを全部見せる表紙をつくる。

左に見出し帯（不透明）、右に 2 列 × 3 行のタイル。
gen-mosaic-hero.py は 3×2 の上に見出しを重ねるため左 2 枚が潰れる。
**6 枚とも見せたいときはこちらを使う。**

    python3 scripts/gen-tile6-hero.py OUT.jpg KICKER T1 T2 SUB CREDIT img1 … img6 [label1 … label6]

**見出しは帯の中に必ず収まる。** 文字数に応じて自動で縮める（2026-09-04）。
以前は 96px 固定だったため、8 文字の見出しがタイル側にはみ出して読めなくなっていた。

**タイルに札を出せる。** img6 のうしろにラベルを 6 つ渡すと、各タイルの左下に
帯付きで名前が入る。「どのチェーンの写真か」が表紙だけで分かるようにするためのもの。
"""
import sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
KICKER, T1, T2, SUB, CREDIT = sys.argv[2:7]
IMGS = sys.argv[7:13]
LABELS = sys.argv[13:19]

W, H = 1600, 900
PANEL = 596        # 左の見出し帯
GAP = 8
GX = PANEL + GAP   # タイル領域の左端
TW = (W - GX - GAP) // 2
TH = (H - GAP * 2) // 3
PAD_L = 48         # 帯の左余白
PAD_R = 40         # 帯の右余白（ここを越えたらはみ出し）
MAXW = PANEL - PAD_L - PAD_R

# Linux（クラウドセッション）は IPA ゴシック、macOS はヒラギノ
CAND = ["/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
        "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"]
import os
F = next((c for c in CAND if os.path.exists(c)), None)
if F is None:
    raise SystemExit("日本語フォントが見つからない: " + " / ".join(CAND))
def f(sz): return ImageFont.truetype(F, sz)

canvas = Image.new("RGB", (W, H), (14, 14, 18))
LABEL_BH = 50   # 札の帯の高さ（札を出したときに実測値で上書きされる）


def fit(path, w, h):
    im = Image.open(path).convert("RGB")
    r = max(w / im.width, h / im.height)
    im = im.resize((max(w, int(im.width * r)), max(h, int(im.height * r))), Image.LANCZOS)
    left = (im.width - w) // 2
    top = int((im.height - h) * 0.42)
    return im.crop((left, top, left + w, top + h))


for i, p in enumerate(IMGS[:6]):
    col, row = i % 2, i // 2
    x = GX + col * (TW + GAP)
    y = row * (TH + GAP)
    canvas.paste(fit(p, TW, TH), (x, y))

d = ImageDraw.Draw(canvas)

# --- タイルの札（どのチェーンの写真かを表紙で示す） ---
# **表紙は一覧で縮小されて出る。** 小さくすると読めないので、帯を敷いて文字を大きく保つ。
for i, name in enumerate(LABELS[:6]):
    if not name:
        continue
    col, row = i % 2, i // 2
    x = GX + col * (TW + GAP)
    y = row * (TH + GAP)
    size = 30
    fnt = f(size)
    while size > 18 and d.textlength(name, font=fnt) > TW - 44:
        size -= 2
        fnt = f(size)
    tw = d.textlength(name, font=fnt)
    bh = size + 20
    LABEL_BH = bh
    d.rectangle([x, y + TH - bh, x + TW - 1, y + TH - 1], fill=(17, 17, 22))
    d.rectangle([x, y + TH - bh, x + 6, y + TH - 1], fill=(233, 30, 99))
    d.text((x + 18, y + TH - bh + 9), name, font=fnt, fill=(255, 255, 255))

# --- 左帯（不透明） ---
d.rectangle([0, 0, PANEL - 1, H], fill=(17, 17, 22))

# ロゴ
d.rounded_rectangle([48, 44, 306, 106], radius=31, fill=(255, 255, 255))
d.ellipse([70, 63, 96, 89], fill=(233, 30, 99))
d.text((108, 60), "Daily Hack", font=f(30), fill=(24, 24, 28))


def shrink(text, start, floor=22):
    """帯の幅に収まる最大の文字サイズを返す。**はみ出させない。**"""
    size = start
    while size > floor and d.textlength(text, font=f(size)) > MAXW:
        size -= 2
    return size


def wrap(text, size, lines=2):
    """帯の幅で折り返す。lines 行に収まらなければ諦めて 1 行で返す。"""
    fnt = f(size)
    if d.textlength(text, font=fnt) <= MAXW:
        return [text]
    out, cur = [], ""
    for ch in text:
        if d.textlength(cur + ch, font=fnt) > MAXW and cur:
            out.append(cur)
            cur = ch
            if len(out) == lines:
                return [text]
        else:
            cur += ch
    out.append(cur)
    return out


y = 300
ks = shrink(KICKER, 38, floor=24)
d.text((52, y), KICKER, font=f(ks), fill=(233, 210, 220))
y += ks + 28

# 見出しは 2 行そろえたいので、長いほうに合わせて同じサイズにする
ts = min(shrink(T1, 96), shrink(T2, 96))
for line in (T1, T2):
    d.text((PAD_L, y), line, font=f(ts), fill=(255, 255, 255))
    y += ts + 24

y += 12
d.rectangle([52, y, 402, y + 11], fill=(233, 30, 99))
y += 40

ss = shrink(SUB, 35, floor=24)
sub_lines = wrap(SUB, ss)
if len(sub_lines) > 1:                      # 折り返すなら少し小さくして詰める
    ss = max(24, ss - 2)
    sub_lines = wrap(SUB, ss)
for line in sub_lines:
    d.text((52, y), line, font=f(ss), fill=(226, 226, 232))
    y += ss + 10

d.text((52, H - 58), CREDIT, font=f(24), fill=(150, 150, 160))

# 発信元のハンドル（他の記事の表紙と同じ位置・同じ体裁）
# **札を出しているときは、右下の札と重なる。** その場合は札の帯の右端に寄せる。
hb = f(26); ht = "@heng_ji31590"
hx = W - 40 - d.textlength(ht, font=hb)
if len(LABELS) >= 6 and LABELS[5]:
    d.text((hx, H - LABEL_BH + 12), ht, font=hb, fill=(255, 224, 230))
else:
    d.text((hx, H - 62), ht, font=hb, fill=(255, 224, 230))

canvas.save(OUT, quality=90, optimize=True)
print(OUT, canvas.size)
