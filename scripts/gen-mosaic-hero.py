#!/usr/bin/env python3
"""
gen-mosaic-hero.py — 複数イベントの画像をタイル合成した eyecatch を作る。

まとめ記事（イベント一覧・比較記事など）で「1枚の写真では中身が伝わらない」
場合に使う。3x2 のタイルに各イベントのビジュアルを敷き、暗幕を重ねてタイトルを載せる。

Usage:
  python3.11 scripts/gen-mosaic-hero.py OUT.jpg KICKER TITLE1 TITLE2 SUB CREDIT img1 img2 ...

例:
  python3.11 scripts/gen-mosaic-hero.py out.jpg "豊洲・有明" "湾岸の8月イベント" \
      "今からでも間に合う" "無料・激安だけを厳選" "画像: 各イベント公式サイト" a.jpg b.jpg ...
"""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter

out, kicker, t1, t2, sub, credit = sys.argv[1:7]
imgs = sys.argv[7:]
if not imgs:
    print("画像を1枚以上指定すること", file=sys.stderr)
    sys.exit(1)

FB = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FL = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
f = lambda sz, light=False: ImageFont.truetype(FL if light else FB, sz)
MAG = (214, 62, 118)
W, H = 1600, 900
COLS, ROWS = 3, 2

# --- タイル合成 ---
base = Image.new("RGB", (W, H), (18, 7, 13))
tw, th = W // COLS, H // ROWS
for i in range(COLS * ROWS):
    src_path = imgs[i % len(imgs)]
    im = Image.open(src_path).convert("RGB")
    sw, sh = im.size
    sc = max(tw / sw, th / sh)
    im = im.resize((int(sw * sc) + 1, int(sh * sc) + 1), Image.LANCZOS)
    x = (im.width - tw) // 2
    y = (im.height - th) // 2
    tile = im.crop((x, y, x + tw, y + th))
    base.paste(tile, ((i % COLS) * tw, (i // COLS) * th))

# タイルの境目をうっすら見せて「複数イベントの集合」だと分かるようにする
d0 = ImageDraw.Draw(base)
for c in range(1, COLS):
    d0.line([(c * tw, 0), (c * tw, H)], fill=(255, 255, 255), width=3)
for r in range(1, ROWS):
    d0.line([(0, r * th), (W, r * th)], fill=(255, 255, 255), width=3)

# --- 文字の可読性を確保する暗幕 ---
base = ImageEnhance.Brightness(base).enhance(0.82)
# 左から右へ濃度が下がるグラデーション（左にテキストを置くため）
grad = Image.new("L", (W, 1))
for i in range(W):
    grad.putpixel((i, 0), max(0, int(225 * (1 - i / (W * 0.72)))))
img = Image.composite(Image.new("RGB", (W, H), (18, 7, 13)), base, grad.resize((W, H)))
# 全面にも薄く敷いて、明るいタイルでも文字が負けないようにする
veil = Image.new("RGB", (W, H), (18, 7, 13))
img = Image.blend(img, veil, 0.18)

d = ImageDraw.Draw(img, "RGBA")
def rr(xy, r, fill): d.rounded_rectangle(xy, radius=r, fill=fill)
def ts(p, s, fnt, fill=(255, 255, 255), off=2):
    d.text((p[0] + off, p[1] + off), s, font=fnt, fill=(0, 0, 0, 170))
    d.text(p, s, font=fnt, fill=fill)

bp = f(30)
bw = d.textlength("Daily Hack", font=bp)
rr((50, 46, 50 + bw + 78, 102), 28, (255, 255, 255, 235))
d.ellipse((68, 64, 90, 86), fill=MAG)
d.text((100, 57), "Daily Hack", font=bp, fill=(42, 25, 35))

ts((58, 296), kicker, f(34), fill=(255, 210, 225))
ts((54, 344), t1, f(104))
ts((54, 466), t2, f(78))
rr((58, 596, 398, 608), 6, MAG + (255,))
ts((58, 628), sub, f(36, light=True), fill=(245, 245, 245))
ts((58, H - 50), credit, f(19, light=True), fill=(225, 225, 225), off=1)

hb = f(26); ht = "@heng_ji31590"
htw = d.textlength(ht, font=hb)
ts((W - 50 - htw, H - 58), ht, hb, fill=(255, 224, 230))

img.convert("RGB").save(out, quality=90)
print("saved", out)
