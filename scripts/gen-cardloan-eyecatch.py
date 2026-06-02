#!/usr/bin/env python3
"""カードローン即日融資 7社比較 2026 の eyecatch (1600x900 JPEG) を生成。
背景: 紺〜深い青グラデ。
メイン: 「カードローン即日融資 7社徹底比較 2026」
サブ: 「金利2.5%-18.0%／在籍確認ナシ／最短即日／全社網羅」
右下に「2026」アクセント。
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "public/images/cardloan-comparison-2026")
FONT_B = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_M = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

W, H = 1600, 900


def grad(w, h, top, bot):
    img = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return img


def main():
    # 紺(top) -> 深い青(bottom)
    img = grad(W, H, (28, 48, 110), (10, 18, 52))
    d = ImageDraw.Draw(img)

    # 装飾: 右上に淡い円
    d.ellipse([W - 260, -120, W + 80, 220], fill=(70, 110, 200), outline=None)
    d.ellipse([W - 200, -90, W + 30, 160], fill=(95, 140, 230))

    # 左上アクセント細線
    d.rectangle([60, 80, 240, 92], fill=(255, 200, 60))
    fa = ImageFont.truetype(FONT_M, 28)
    d.text((60, 110), "DAILY HACK / COMPARISONS", font=fa, fill=(255, 220, 120))

    # メインタイトル（2行）
    ft1 = ImageFont.truetype(FONT_B, 88)
    d.text((60, 200), "カードローン即日融資", font=ft1, fill=(255, 255, 255))
    ft2 = ImageFont.truetype(FONT_B, 96)
    # 強調: "7社徹底比較" を黄色
    line2_a = "7社徹底比較 "
    line2_b = "2026"
    bbox_a = d.textbbox((0, 0), line2_a, font=ft2)
    d.text((60, 310), line2_a, font=ft2, fill=(255, 215, 70))
    d.text((60 + (bbox_a[2] - bbox_a[0]), 310), line2_b, font=ft2, fill=(255, 255, 255))

    # 区切り線
    d.rectangle([60, 460, 980, 466], fill=(255, 255, 255))

    # サブ
    fs = ImageFont.truetype(FONT_M, 44)
    d.text((60, 500), "金利2.5%-18.0%／在籍確認ナシ／最短即日／全社網羅", font=fs, fill=(220, 235, 255))

    # 7社ロゴ風チップ
    chips = ["プロミス", "アコム", "SMBCモビット", "レイク", "アイフル", "三井住友カード", "オリックス"]
    fc = ImageFont.truetype(FONT_M, 26)
    x = 60
    y = 600
    for c in chips:
        tw = d.textbbox((0, 0), c, font=fc)
        w_ = (tw[2] - tw[0]) + 36
        h_ = 56
        if x + w_ > W - 60:
            x = 60
            y += 72
        d.rounded_rectangle([x, y, x + w_, y + h_], 14, fill=(255, 255, 255), outline=(180, 200, 240), width=2)
        d.text((x + w_ / 2, y + h_ / 2), c, font=fc, fill=(20, 35, 90), anchor="mm")
        x += w_ + 14

    # 右下に大きな "2026" アクセント
    fy = ImageFont.truetype(FONT_B, 200)
    txt = "2026"
    tb = d.textbbox((0, 0), txt, font=fy)
    tw = tb[2] - tb[0]
    th = tb[3] - tb[1]
    # 半透明グロー風: 影
    d.text((W - tw - 60 + 6, H - th - 80 + 6), txt, font=fy, fill=(0, 0, 0))
    d.text((W - tw - 60, H - th - 80), txt, font=fy, fill=(255, 215, 70))

    # 下部ノート
    fn = ImageFont.truetype(FONT_L, 22)
    d.text((60, H - 50), "※金利・条件は記事執筆時点（2026年5月）。利用前に各社公式で最新条件をご確認ください。",
           font=fn, fill=(200, 215, 240))

    out = os.path.join(OUT_DIR, "eyecatch.jpg")
    img.convert("RGB").save(out, quality=88)
    print("saved", out, img.size)


if __name__ == "__main__":
    main()
