#!/usr/bin/env python3
"""松屋60周年4大コード決済キャンペーン記事の eyecatch を生成。
4つの公式キャンペーン画像を2x2グリッドに配置 + 上下に帯。"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMGDIR = os.path.join(ROOT, "public/images/matsuya-60th-cashless-2026-jun")
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

W, H = 1600, 900
BAR_TOP, BAR_BOT = 90, 100
GRID_H = H - BAR_TOP - BAR_BOT

def main():
    img = Image.new("RGB", (W, H), (255, 100, 60))  # 松屋オレンジ
    d = ImageDraw.Draw(img)

    # 2x2 grid of campaign images
    src = ["campaign-paypay.jpg", "campaign-rakutenpay.jpg", "campaign-aupay.jpg", "campaign-dpay.jpg"]
    cell_w = (W - 60) // 2; cell_h = (GRID_H - 40) // 2
    margin_l, margin_t, gap = 20, BAR_TOP + 10, 20
    for i, fn in enumerate(src):
        r, c = divmod(i, 2)
        x0 = margin_l + c * (cell_w + gap)
        y0 = margin_t + r * (cell_h + gap)
        im = Image.open(os.path.join(IMGDIR, fn)).convert("RGB")
        im.thumbnail((cell_w, cell_h), Image.LANCZOS)
        # center within cell
        cx0 = x0 + (cell_w - im.width) // 2
        cy0 = y0 + (cell_h - im.height) // 2
        # white frame
        d.rectangle([x0, y0, x0 + cell_w, y0 + cell_h], fill=(255, 245, 235), outline=(220, 60, 30), width=4)
        img.paste(im, (cx0, cy0))

    # top title bar
    d.rectangle([0, 0, W, BAR_TOP], fill=(220, 30, 30))
    ft = ImageFont.truetype(FONT, 50)
    d.text((W / 2, BAR_TOP / 2), "松屋60周年 4大コード決済キャンペーン徹底比較", font=ft, fill=(255, 255, 255), anchor="mm")
    # bottom bar
    d.rectangle([0, H - BAR_BOT, W, H], fill=(255, 245, 235))
    fs = ImageFont.truetype(FONT, 38)
    d.text((W / 2, H - BAR_BOT + 30), "PayPay  ×  楽天ペイ  ×  au PAY  ×  d払い", font=fs, fill=(220, 30, 30), anchor="mm")
    fb = ImageFont.truetype(FONT_L, 26)
    d.text((W / 2, H - BAR_BOT + 72), "2026年6月1日スタート — どれが最お得か全比較", font=fb, fill=(80, 50, 30), anchor="mm")

    out = os.path.join(IMGDIR, "matsuya60-collage.jpg")
    img.save(out, quality=90)
    print("saved", out, img.size)

if __name__ == "__main__":
    main()
