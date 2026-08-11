#!/usr/bin/env python3
"""全国アウトレット徹底比較 2026 のアイキャッチ（表紙）。
ららぽーと完全ガイドと同型: 3x2 の実写コラージュ + 左→右の暗グラデ +
Daily Hack バッジ + 大タイトル + マゼンタ下線 + サブ + クレジット + @handle。
出力: public/images/outlet-mall-guide-2026/eyecatch.jpg (1600x900)
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PH = os.path.join(ROOT, "public/images/outlet-mall-guide-2026/photos")
OUT = os.path.join(ROOT, "public/images/outlet-mall-guide-2026/eyecatch.jpg")
FB = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FL = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
MAG = (214, 62, 118)
W, H = 1600, 900

# 3x2 グリッド（左上は暗部に入るので賑やかすぎない gotemba を置く）
GRID = [
    ["gotemba.jpg", "rinku.jpg", "karuizawa.jpg"],
    ["the-outlets.jpg", "kisarazu.jpg", "okazaki.jpg"],
]
COLS, ROWS = 3, 2
GAP = 4  # セル間の白い細線


def cover(im, w, h):
    sw, sh = im.size
    s = max(w / sw, h / sh)
    im = im.resize((int(sw * s + 0.5), int(sh * s + 0.5)), Image.LANCZOS)
    x = (im.width - w) // 2
    y = (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def main():
    canvas = Image.new("RGB", (W, H), (255, 255, 255))
    cw = (W - GAP * (COLS - 1)) // COLS
    ch = (H - GAP * (ROWS - 1)) // ROWS
    for r in range(ROWS):
        for c in range(COLS):
            src = Image.open(os.path.join(PH, GRID[r][c])).convert("RGB")
            cell = cover(src, cw, ch)
            canvas.paste(cell, (c * (cw + GAP), r * (ch + GAP)))

    # 左→右の暗グラデ（テキスト可読性）
    grad = Image.new("L", (W, 1))
    for i in range(W):
        a = max(0, int(225 * (1 - i / (W * 0.66))))
        grad.putpixel((i, 0), a)
    grad = grad.resize((W, H))
    shade = Image.new("RGB", (W, H), (16, 10, 18))
    img = Image.composite(shade, canvas, grad)
    img = ImageEnhance.Contrast(img).enhance(1.02)

    d = ImageDraw.Draw(img, "RGBA")

    # Daily Hack バッジ
    pill_x, pill_y, pill_h = 48, 40, 62
    tf = ImageFont.truetype(FB, 34)
    label = "Daily Hack"
    tw = d.textlength(label, font=tf)
    pill_w = int(tw + 108)
    d.rounded_rectangle([pill_x, pill_y, pill_x + pill_w, pill_y + pill_h], pill_h // 2,
                        fill=(255, 255, 255))
    dot_r = 13
    d.ellipse([pill_x + 30 - dot_r, pill_y + pill_h // 2 - dot_r,
               pill_x + 30 + dot_r, pill_y + pill_h // 2 + dot_r], fill=MAG)
    d.text((pill_x + 58, pill_y + pill_h // 2), label, font=tf, fill=(20, 22, 30), anchor="lm")

    LX = 60
    # kicker
    fk = ImageFont.truetype(FL, 38)
    d.text((LX, 330), "全国32施設を運営会社で横断", font=fk, fill=(255, 255, 255), anchor="lm")
    # title 2 lines
    ft = ImageFont.truetype(FB, 104)
    d.text((LX, 430), "全国アウトレット", font=ft, fill=(255, 255, 255), anchor="lm")
    d.text((LX, 552), "徹底比較 2026", font=ft, fill=(255, 255, 255), anchor="lm")
    # magenta underline
    d.rectangle([LX, 636, LX + 360, 646], fill=MAG)
    # subtitle
    fs = ImageFont.truetype(FL, 40)
    d.text((LX, 712), "売上日本一は御殿場、店舗数日本一は木更津", font=fs,
           fill=(238, 238, 240), anchor="lm")

    # credit (bottom-left) / handle (bottom-right)
    fc = ImageFont.truetype(FL, 24)
    d.text((LX, H - 34),
           "画像: 各運営会社の公式サイトより（御殿場／りんくう／軽井沢／ジ・アウトレット／木更津）",
           font=fc, fill=(225, 225, 228), anchor="lm")
    fh = ImageFont.truetype(FB, 34)
    d.text((W - 40, H - 40), "@heng_ji31590", font=fh, fill=(255, 255, 255), anchor="rm")

    img.save(OUT, quality=90)
    print("saved", OUT, img.size)


if __name__ == "__main__":
    main()
