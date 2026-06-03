#!/usr/bin/env python3
"""移動ポイ活アプリ比較記事 eyecatch (16:9)。
ハッカー子キャラ + 各サービスのアイコンタイルをキャッチーに配置。"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "public/images/move-to-earn-poikatsu-apps-2026")
os.makedirs(OUT, exist_ok=True)
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_B = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
W, H = 1600, 900

# サービスアイコンタイル: 表示名, 略称, 背景色
APPS = [
    ("トリマ", "歩・移動", (45, 175, 95)),
    ("ANA Pocket", "マイル", (30, 110, 200)),
    ("JAL Wellness", "マイル", (210, 35, 45)),
    ("dヘルスケア", "dポイント", (230, 90, 30)),
    ("楽天ヘルスケア", "楽天P", (190, 30, 45)),
]

def grad(w, h, top, bot):
    img = Image.new("RGB", (w, h), top); d = ImageDraw.Draw(img)
    for y in range(h):
        t = y/max(1,h-1)
        d.line([(0,y),(w,y)], fill=tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)))
    return img

def main():
    img = grad(W, H, (15, 130, 95), (10, 80, 130))
    d = ImageDraw.Draw(img)

    # 上部タイトルバー
    d.rectangle([0, 0, W, 130], fill=(20, 40, 55))
    d.text((50, 34), "移動ポイ活アプリ徹底比較", font=ImageFont.truetype(FONT_B, 60), fill=(255,255,255))
    # 2026最新版バッジ
    d.rounded_rectangle([W-360, 38, W-50, 96], 29, fill=(255, 200, 30))
    d.text((W-205, 67), "2026年最新版", font=ImageFont.truetype(FONT_B, 36), fill=(30,30,40), anchor="mm")

    # キャラ（左）cheer ポーズ — 角丸フレームで囲んで意図的なポートレートに
    ch = Image.open(os.path.join(ROOT, "public/images/expr-04-cheer.png")).convert("RGBA")
    CHAR = 540
    ch.thumbnail((CHAR, CHAR), Image.LANCZOS)
    cw, chh = ch.size
    cx, cy = 70, 270
    rad = 40
    # アクセント枠（黄色）→白縁→キャラ
    d.rounded_rectangle([cx-14, cy-14, cx+cw+14, cy+chh+14], rad+12, fill=(255, 200, 30))
    # 角丸マスクでキャラの白背景の四角さを消す
    mask = Image.new("L", (cw, chh), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, cw, chh], rad, fill=255)
    img.paste(ch, (cx, cy), mask)

    # 吹き出し（キャラの上）
    bx, by = 70, 165
    d.rounded_rectangle([bx, by, bx+470, by+74], 20, fill=(255,255,255))
    d.polygon([(bx+70, by+74),(bx+110, by+74),(bx+75, by+110)], fill=(255,255,255))
    d.text((bx+235, by+37), "歩く・移動するだけで稼げる！", font=ImageFont.truetype(FONT_B, 30), fill=(20, 110, 80), anchor="mm")

    # サービスアイコンタイル（右側に縦並び）
    tile_w, tile_h = 620, 116
    tx = W - tile_w - 60
    ty0 = 175
    gap = 22
    fname = ImageFont.truetype(FONT_B, 40)
    ftag = ImageFont.truetype(FONT, 26)
    for i, (name, tag, color) in enumerate(APPS):
        ty = ty0 + i*(tile_h+gap)
        # タイル本体（白）
        d.rounded_rectangle([tx, ty, tx+tile_w, ty+tile_h], 22, fill=(255,255,255))
        # 左のアイコン正方形（ブランドカラー）
        ic = tile_h - 24
        d.rounded_rectangle([tx+12, ty+12, tx+12+ic, ty+12+ic], 18, fill=color)
        d.text((tx+12+ic/2, ty+12+ic/2), name[0], font=ImageFont.truetype(FONT_B, 56), fill=(255,255,255), anchor="mm")
        # アプリ名
        d.text((tx+12+ic+24, ty+30), name, font=fname, fill=(30,30,40))
        # タグ（貯まるもの）
        d.rounded_rectangle([tx+12+ic+24, ty+74, tx+12+ic+24+150, ty+74+30], 15, fill=color)
        d.text((tx+12+ic+24+75, ty+74+15), tag, font=ftag, fill=(255,255,255), anchor="mm")

    # 下部キャッチ
    d.rectangle([0, H-66, W, H], fill=(20, 40, 55))
    d.text((W/2, H-33), "実際いくら稼げる？ 月収実績で「一番お得」を検証", font=ImageFont.truetype(FONT, 32), fill=(255, 220, 120), anchor="mm")

    out = os.path.join(OUT, "eyecatch.jpg")
    img.save(out, quality=90)
    print("saved", out, img.size)

if __name__ == "__main__":
    main()
