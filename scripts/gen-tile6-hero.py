# -*- coding: utf-8 -*-
"""6 枚のタイルを全部見せる表紙をつくる。

左に見出し帯（不透明）、右に 2 列 × 3 行のタイル。
gen-mosaic-hero.py は 3×2 の上に見出しを重ねるため左 2 枚が潰れる。
**6 枚とも見せたいときはこちらを使う。**

    python3 scripts/gen-tile6-hero.py OUT.jpg KICKER T1 T2 SUB CREDIT img1 … img6
"""
import sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
KICKER, T1, T2, SUB, CREDIT = sys.argv[2:7]
IMGS = sys.argv[7:13]

W, H = 1600, 900
PANEL = 596        # 左の見出し帯
GAP = 8
GX = PANEL + GAP   # タイル領域の左端
TW = (W - GX - GAP) // 2
TH = (H - GAP * 2) // 3

# Linux（クラウドセッション）は IPA ゴシック、macOS はヒラギノ
CAND = ["/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
        "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"]
import os
F = next((c for c in CAND if os.path.exists(c)), None)
if F is None:
    raise SystemExit("日本語フォントが見つからない: " + " / ".join(CAND))
def f(sz): return ImageFont.truetype(F, sz)

canvas = Image.new("RGB", (W, H), (14, 14, 18))

def fit(path, w, h):
    im = Image.open(path).convert("RGB")
    r = max(w / im.width, h / im.height)
    im = im.resize((max(w, int(im.width * r)), max(h, int(im.height * r))), Image.LANCZOS)
    l = (im.width - w) // 2
    t = int((im.height - h) * 0.42)
    return im.crop((l, t, l + w, t + h))

for i, p in enumerate(IMGS[:6]):
    col, row = i % 2, i // 2
    x = GX + col * (TW + GAP)
    y = row * (TH + GAP)
    canvas.paste(fit(p, TW, TH), (x, y))

# 左帯（不透明）
d = ImageDraw.Draw(canvas)
d.rectangle([0, 0, PANEL - 1, H], fill=(17, 17, 22))
# 帯からタイルへのなじみ
grad = Image.new("L", (1, 1))
for i in range(56):
    a = int(255 * (1 - i / 56))
    d.line([(PANEL + i, 0), (PANEL + i, H)], fill=(17, 17, 22))
    if a < 255:
        break

# ロゴ
d.rounded_rectangle([48, 44, 306, 106], radius=31, fill=(255, 255, 255))
d.ellipse([70, 63, 96, 89], fill=(233, 30, 99))
d.text((108, 60), "Daily Hack", font=f(30), fill=(24, 24, 28))

y = 300
d.text((52, y), KICKER, font=f(38), fill=(233, 210, 220))
y += 66
d.text((48, y), T1, font=f(96), fill=(255, 255, 255))
y += 120
d.text((48, y), T2, font=f(96), fill=(255, 255, 255))
y += 132
d.rectangle([52, y, 402, y + 11], fill=(233, 30, 99))
y += 40
d.text((52, y), SUB, font=f(35), fill=(226, 226, 232))

d.text((52, H - 58), CREDIT, font=f(24), fill=(150, 150, 160))

# 発信元のハンドル（他の記事の表紙と同じ位置・同じ体裁）
hb = f(26); ht = "@heng_ji31590"
d.text((W - 40 - d.textlength(ht, font=hb), H - 62), ht, font=hb, fill=(255, 224, 230))

canvas.save(OUT, quality=90, optimize=True)
print(OUT, canvas.size)
