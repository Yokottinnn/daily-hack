#!/usr/bin/env python3
"""アプリのアイコン＋スクショを並べた横長ショーケース画像を生成。
公式App Store画像を素材に、記事本文に貼るリアリティ要素を作る。"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "public/images/ana-pocket-vs-jal-wellness-2026")
SRC = os.path.join(DIR, "src")
FONT_B = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

def rounded(img, rad):
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0,0,img.size[0],img.size[1]], rad, fill=255)
    out = img.convert("RGBA"); out.putalpha(m); return out

def showcase(prefix, name, tag, accent, bg, out_name):
    W, H = 1200, 660
    canvas = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(canvas)
    # ヘッダー: アイコン + 名前 + タグ
    icon = Image.open(os.path.join(SRC, f"{prefix}-icon.png")).convert("RGBA")
    icon.thumbnail((104,104), Image.LANCZOS)
    icon_r = rounded(icon, 22)
    canvas.paste(icon_r, (44, 40), icon_r)
    d.text((170, 50), name, font=ImageFont.truetype(FONT_B, 46), fill=(30,30,40))
    # タグチップ
    tw = d.textlength(tag, font=ImageFont.truetype(FONT, 26))
    d.rounded_rectangle([172, 108, 172+tw+36, 108+44], 22, fill=accent)
    d.text((172+18, 108+22), tag, font=ImageFont.truetype(FONT, 26), fill=(255,255,255), anchor="lm")
    # 右上 出典
    d.text((W-44, 58), "出典: App Store", font=ImageFont.truetype(FONT_L, 22), fill=(150,150,160), anchor="rm")
    # スクショ3枚を横並び
    ss = [Image.open(os.path.join(SRC, f"{prefix}-ss{i}.png")).convert("RGB") for i in range(3)]
    sh = 420
    scaled = []
    for im in ss:
        w = int(im.width * sh / im.height)
        scaled.append(im.resize((w, sh), Image.LANCZOS))
    gap = 36
    total = sum(s.width for s in scaled) + gap*(len(scaled)-1)
    x = (W - total)//2
    y = 190
    for s in scaled:
        # 影
        sh_img = Image.new("RGBA",(W,H),(0,0,0,0))
        ImageDraw.Draw(sh_img).rounded_rectangle([x+5,y+8,x+s.width+5,y+sh+8], 22, fill=(40,40,60,80))
        canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), sh_img.filter(ImageFilter.GaussianBlur(10))).convert("RGB"),(0,0))
        sr = rounded(s, 22)
        canvas.paste(sr, (x, y), sr)
        d.rounded_rectangle([x,y,x+s.width,y+sh], 22, outline=accent, width=3)
        x += s.width + gap
    out = os.path.join(DIR, out_name)
    canvas.save(out, quality=90)
    print("saved", out, canvas.size)

showcase("ana", "ANA Pocket", "移動距離型・移動でマイル", (30,110,200), (240,247,253), "ana-showcase.jpg")
showcase("jal", "JAL Wellness & Travel", "歩数チャレンジ型・歩いてマイル", (210,35,45), (253,242,243), "jal-showcase.jpg")
