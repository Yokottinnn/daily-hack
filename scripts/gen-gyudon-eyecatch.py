#!/usr/bin/env python3
"""牛丼チェーン4社決済キャンペーン記事 eyecatch (16:9)。"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMGDIR = os.path.join(ROOT, "public/images/gyudon-chains-cashless-2026-jun")
os.makedirs(IMGDIR, exist_ok=True)
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"

W, H = 1600, 900

def grad(w, h, top, bot):
    img = Image.new("RGB", (w, h), top); d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h-1)
        c = tuple(int(top[i] + (bot[i]-top[i])*t) for i in range(3))
        d.line([(0,y),(w,y)], fill=c)
    return img

def main():
    img = grad(W, H, (60, 30, 20), (120, 70, 30))
    d = ImageDraw.Draw(img)

    BAR_TOP = 110
    BAR_BOT = 115
    # top title bar
    d.rectangle([0, 0, W, BAR_TOP], fill=(180, 30, 30))
    ft = ImageFont.truetype(FONT, 52)
    d.text((W/2, BAR_TOP/2), "牛丼チェーン4社 決済キャンペーン徹底比較 2026年6月", font=ft, fill=(255,255,240), anchor="mm")

    # 4 cards: 松屋 / 吉野家 / すき家 / なか卯 with brand color + key value
    chains = [
        ("松屋", (255, 80, 0), "PayPay 40%\nd払い 20%\n（60周年）"),
        ("吉野家", (200, 25, 25), "d払い 20%\n（テイクアウト\n〜6/6）"),
        ("すき家", (245, 130, 0), "三井住友NL 7%\n＋ポイント\n15倍"),
        ("なか卯", (200, 30, 60), "三井住友NL 7%\n＋ポイント\n15倍"),
    ]
    cw = (W - 100) // 4
    gap = 20
    cy0 = BAR_TOP + 30
    ch = H - BAR_TOP - BAR_BOT - 50
    fchain = ImageFont.truetype(FONT, 60)
    fkv = ImageFont.truetype(FONT, 32)
    for i, (name, color, kv) in enumerate(chains):
        x0 = 30 + i * (cw + gap)
        # card
        d.rounded_rectangle([x0, cy0, x0+cw, cy0+ch], 20, fill=(255, 245, 230), outline=color, width=5)
        # color top band with chain name
        d.rounded_rectangle([x0, cy0, x0+cw, cy0+115], 20, fill=color)
        d.rectangle([x0, cy0+85, x0+cw, cy0+115], fill=color)
        d.text((x0 + cw/2, cy0 + 60), name, font=fchain, fill=(255,255,255), anchor="mm")
        # kv text (3 lines)
        d.multiline_text((x0 + cw/2, cy0 + 220), kv, font=fkv, fill=(60,30,15), anchor="mm", align="center", spacing=12)

    # bottom subtitle bar
    d.rectangle([0, H - BAR_BOT, W, H], fill=(40, 20, 10))
    fs = ImageFont.truetype(FONT, 32)
    d.text((W/2, H - BAR_BOT + 32), "🥇 松屋60周年・🥈 ゼンショー(すき家/なか卯)・🥉 吉野家テイクアウト", font=fs, fill=(255, 220, 100), anchor="mm")
    fb = ImageFont.truetype(FONT_L, 22)
    d.text((W/2, H - BAR_BOT + 78), "経済圏別の最適ルートで月数千円浮く", font=fb, fill=(220, 200, 170), anchor="mm")

    out = os.path.join(IMGDIR, "eyecatch.jpg")
    img.save(out, quality=90)
    print("saved", out, img.size)

if __name__ == "__main__":
    main()
