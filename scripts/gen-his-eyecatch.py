#!/usr/bin/env python3
"""HIS在庫処分セール記事の eyecatch (16:9) を生成。
2つのツイート画像（海外/国内）を横並び＋上下にタイトル/サブを乗せる。"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMGDIR = os.path.join(ROOT, "public/images/his-clearance-sale-2026-jun")
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

W, H = 1600, 900
BAR_TOP = 110
BAR_BOT = 110
GRID_H = H - BAR_TOP - BAR_BOT

def grad(w, h, top, bot):
    img = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h-1)
        c = tuple(int(top[i] + (bot[i]-top[i])*t) for i in range(3))
        d.line([(0,y),(w,y)], fill=c)
    return img

def main():
    # HIS ブランド系オレンジ→赤ベース
    img = grad(W, H, (255, 130, 60), (220, 50, 30))
    d = ImageDraw.Draw(img)

    # 2画像横並び（海外左、国内右）
    cell_w = (W - 60) // 2  # 30+30 margins, 0 gap inside cells
    cell_h = GRID_H - 30
    margin_x = 20; gap = 20
    for i, fn in enumerate(["his-sale-overseas.png", "his-sale-domestic.png"]):
        x0 = margin_x + i * (cell_w + gap)
        y0 = BAR_TOP + 15
        im = Image.open(os.path.join(IMGDIR, fn)).convert("RGB")
        im.thumbnail((cell_w - 16, cell_h - 16), Image.LANCZOS)
        cx = x0 + (cell_w - im.width)//2
        cy = y0 + (cell_h - im.height)//2
        # white card
        d.rounded_rectangle([x0, y0, x0+cell_w, y0+cell_h], 18, fill=(255, 248, 240), outline=(255,255,255), width=3)
        img.paste(im, (cx, cy))

    # top title bar
    d.rectangle([0, 0, W, BAR_TOP], fill=(180, 25, 15))
    ft = ImageFont.truetype(FONT, 54)
    d.text((W/2, BAR_TOP/2), "HIS 在庫処分セール 2026年6月", font=ft, fill=(255, 255, 240), anchor="mm")

    # bottom subtitle bar
    d.rectangle([0, H - BAR_BOT, W, H], fill=(40, 25, 20))
    fs = ImageFont.truetype(FONT, 38)
    d.text((W/2, H - BAR_BOT + 30), "沖縄25,800円  ／  バンコク44,800円  ／  ソウル22,800円〜", font=fs, fill=(255, 220, 100), anchor="mm")
    fb = ImageFont.truetype(FONT_L, 26)
    d.text((W/2, H - BAR_BOT + 75), "全プラン 往復航空券＋ホテル込み・燃油サーチャージなし／6月出発限定", font=fb, fill=(245, 230, 200), anchor="mm")

    out = os.path.join(IMGDIR, "his-eyecatch-16x9.jpg")
    img.save(out, quality=90)
    print("saved", out, img.size)

if __name__ == "__main__":
    main()
