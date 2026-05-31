#!/usr/bin/env python3
"""自動車保険 一括見積もり 8社比較記事の eyecatch (16:9) を生成。
緑〜青グラデ背景（安心感）＋メインタイトル＋サブタイトル＋中央にハンドル絵文字。
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMGDIR = os.path.join(ROOT, "public/images/car-insurance-comparison-2026")
os.makedirs(IMGDIR, exist_ok=True)

FONT_B = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
# 絵文字フォント候補（macOS 標準）
EMOJI_FONT = "/System/Library/Fonts/Apple Color Emoji.ttc"

W, H = 1600, 900


def grad(w, h, top, bot):
    img = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return img


def text_with_shadow(d, xy, text, font, fill, shadow=(0, 0, 0, 150), offset=(3, 3), anchor="mm"):
    d.text((xy[0] + offset[0], xy[1] + offset[1]), text, font=font, fill=shadow[:3], anchor=anchor)
    d.text(xy, text, font=font, fill=fill, anchor=anchor)


def main():
    # 緑〜青の安心感グラデ（上:深緑、下:深青）
    img = grad(W, H, (28, 110, 90), (20, 60, 130))
    d = ImageDraw.Draw(img)

    # 上下に半透明オーバーレイ（タイトル可読性アップ）
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rectangle([0, 0, W, 200], fill=(0, 0, 0, 90))
    od.rectangle([0, H - 200, W, H], fill=(0, 0, 0, 110))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    d = ImageDraw.Draw(img)

    # 中央にハンドル風アイコン（円リング + 十字スポーク）
    cx, cy = W // 2, H // 2 + 10
    R = 165
    # 外周リング
    for w in range(28, 0, -2):
        col = (255, 220, 70) if w <= 8 else (240, 240, 250)
        d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=col, width=w)
        break  # 1回だけ
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(245, 245, 250), width=18)
    # 内側ハブ
    d.ellipse([cx - 38, cy - 38, cx + 38, cy + 38], fill=(245, 245, 250))
    # 3本スポーク（Mercedes風）
    import math
    for ang_deg in (90, 210, 330):
        ang = math.radians(ang_deg)
        x2 = cx + int(math.cos(ang) * (R - 14))
        y2 = cy + int(math.sin(ang) * (R - 14))
        d.line([(cx, cy), (x2, y2)], fill=(245, 245, 250), width=22)
    # ハイライト（黄色アクセント）
    d.ellipse([cx - R - 6, cy - R - 6, cx + R + 6, cy + R + 6], outline=(255, 220, 70), width=4)

    # メインタイトル（上部）
    ft = ImageFont.truetype(FONT_B, 78)
    text_with_shadow(d, (W // 2, 105), "自動車保険 一括見積もり", ft, (255, 255, 255))
    ft2 = ImageFont.truetype(FONT_B, 70)
    text_with_shadow(d, (W // 2, 195), "8社徹底比較 2026", ft2, (255, 230, 90))

    # サブタイトル（下部 3行）
    fs_big = ImageFont.truetype(FONT_B, 50)
    text_with_shadow(d, (W // 2, H - 145), "年間5万円差がつく選び方", fs_big, (255, 255, 255))
    fs_mid = ImageFont.truetype(FONT_L, 36)
    text_with_shadow(d, (W // 2, H - 80), "ダイレクト型 vs 代理店型 ／ オススメ8社まとめ", fs_mid, (230, 240, 255))

    # 角に「2026年最新」リボン風
    d.polygon([(0, 0), (220, 0), (180, 60), (0, 60)], fill=(220, 50, 50))
    fr = ImageFont.truetype(FONT_B, 28)
    d.text((90, 30), "2026年版", font=fr, fill=(255, 255, 255), anchor="mm")

    # 右上に「8社比較」バッジ
    d.ellipse([W - 200, 30, W - 30, 200], fill=(255, 220, 70))
    fb = ImageFont.truetype(FONT_B, 36)
    d.text((W - 115, 95), "8社", font=fb, fill=(20, 60, 130), anchor="mm")
    fb2 = ImageFont.truetype(FONT_B, 26)
    d.text((W - 115, 140), "徹底比較", font=fb2, fill=(20, 60, 130), anchor="mm")

    out = os.path.join(IMGDIR, "eyecatch.jpg")
    img.save(out, quality=90)
    print("saved", out, img.size)


if __name__ == "__main__":
    main()
