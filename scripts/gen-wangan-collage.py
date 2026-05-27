#!/usr/bin/env python3
"""
湾岸スーパー記事のアイキャッチ用ロゴコラージュ生成。
- 3x3 グリッドの白カードに各チェーンロゴを「上下左右とも中央」配置
- イオン東雲を記事から削除したため AEON は載せず、リンコスを含む実掲載 9 チェーンで構成
- 下部にタイトルバー
出力: public/images/wangan-supermarkets-2026/wangan-collage.jpg
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMGDIR = os.path.join(ROOT, "public/images/wangan-supermarkets-2026")
ICONS = os.path.join(IMGDIR, "icons")
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

W, H = 1600, 900
BAR_H = 150                       # bottom title bar height
GRID_H = H - BAR_H
COLS, ROWS = 3, 3
MARGIN_X, MARGIN_Y = 70, 55
GAP = 40

# (logo file or None, fallback text, text color)
CELLS = [
    ("logo-life.png", None, None),
    ("logo-maruetsu.png", None, None),
    ("logo-bunkado.png", None, None),
    ("logo-seijoishii.png", None, None),
    ("logo-summit.png", None, None),
    ("logo-daiei.png", None, None),
    ("logo-maibasuketto.png", None, None),
    ("logo-tobustore.jpg", None, None),
    (None, "Lincos", (200, 30, 60)),  # リンコス（ロゴはSVGのためテキスト表現）
]

def vgrad(w, h, top, bot):
    base = Image.new("RGB", (w, h), top)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        ImageDraw.Draw(base).line([(0, y), (w, y)], fill=c)
    return base

def main():
    img = vgrad(W, H, (252, 228, 214), (250, 214, 205))
    d = ImageDraw.Draw(img)

    cw = (W - MARGIN_X * 2 - GAP * (COLS - 1)) // COLS
    ch = (GRID_H - MARGIN_Y * 2 - GAP * (ROWS - 1)) // ROWS

    for i, (logo, txt, col) in enumerate(CELLS):
        r, c = divmod(i, COLS)
        x0 = MARGIN_X + c * (cw + GAP)
        y0 = MARGIN_Y + r * (ch + GAP)
        # card with soft shadow
        d.rounded_rectangle([x0 + 5, y0 + 7, x0 + cw + 5, y0 + ch + 7], 22, fill=(220, 180, 175))
        d.rounded_rectangle([x0, y0, x0 + cw, y0 + ch], 22, fill=(255, 252, 252), outline=(244, 200, 205), width=3)
        cx, cy = x0 + cw / 2, y0 + ch / 2  # card center
        if logo:
            lg = Image.open(os.path.join(ICONS, logo)).convert("RGBA")
            maxw, maxh = int(cw * 0.74), int(ch * 0.62)
            lg.thumbnail((maxw, maxh), Image.LANCZOS)
            # 上下左右とも中央
            img.paste(lg, (int(cx - lg.width / 2), int(cy - lg.height / 2)), lg)
        else:
            f = ImageFont.truetype(FONT, int(ch * 0.34))
            d.text((cx, cy), txt, font=f, fill=col, anchor="mm")

    # bottom title bar
    d.rectangle([0, GRID_H, W, H], fill=(255, 250, 250))
    d.line([(0, GRID_H), (W, GRID_H)], fill=(214, 32, 80), width=4)
    ft = ImageFont.truetype(FONT, 58)
    fs = ImageFont.truetype(FONT_L, 30)
    d.text((W / 2, GRID_H + 50), "湾岸エリア スーパー徹底比較", font=ft, fill=(40, 44, 60), anchor="mm")
    d.text((W / 2, GRID_H + 108), "晴海・勝どき・月島・豊洲 ／ 18店舗", font=fs, fill=(150, 90, 90), anchor="mm")

    out = os.path.join(IMGDIR, "wangan-collage.jpg")
    img.save(out, quality=90)
    print("saved", out, img.size)

if __name__ == "__main__":
    main()
