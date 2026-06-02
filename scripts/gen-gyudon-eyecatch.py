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

    # 4 cards: 松屋 / 吉野家 / すき家 / なか卯 with brand color + KV + character + logo
    # 各社の「気分」に合わせて表情選定:
    #   松屋(60周年・40%還元) → gasp(驚き)
    #   吉野家(d払い20% 6/6まで) → pout(急ぎ)
    #   すき家(毎月15倍 定番) → smug(ドヤ顔)
    #   なか卯(3段重ね最強) → cheer(やったね)
    LOGOS = os.path.join(IMGDIR, "logos")
    CHARS = os.path.join(ROOT, "public/images")
    chains = [
        ("松屋", (255, 80, 0), "PayPay 40%\nd払い 20%\n（60周年）", "matsuya.png", "expr-07-gasp.png"),
        ("吉野家", (200, 25, 25), "d払い 20%\n（テイクアウト\n〜6/6）", "yoshinoya.png", "expr-02-pout.png"),
        ("すき家", (245, 130, 0), "三井住友NL 7%\n＋ポイント\n15倍", "sukiya.png", "expr-05-smug.png"),
        ("なか卯", (200, 30, 60), "三井住友NL 7%\n＋ポイント\n15倍", "nakau.png", "expr-04-cheer.png"),
    ]
    cw = (W - 100) // 4
    gap = 20
    cy0 = BAR_TOP + 30
    ch = H - BAR_TOP - BAR_BOT - 50
    fchain = ImageFont.truetype(FONT, 60)
    fkv = ImageFont.truetype(FONT, 30)

    # ロゴを共通サイズ 240x100 の white box に fit させて調和
    LOGO_BOX_W, LOGO_BOX_H = 240, 100
    CHAR_SIZE = 160  # キャラ画像の最大辺
    for i, (name, color, kv, logo_file, char_file) in enumerate(chains):
        x0 = 30 + i * (cw + gap)
        # card
        d.rounded_rectangle([x0, cy0, x0+cw, cy0+ch], 20, fill=(255, 245, 230), outline=color, width=5)
        # color top band with chain name
        d.rounded_rectangle([x0, cy0, x0+cw, cy0+115], 20, fill=color)
        d.rectangle([x0, cy0+85, x0+cw, cy0+115], fill=color)
        d.text((x0 + cw/2, cy0 + 60), name, font=fchain, fill=(255,255,255), anchor="mm")
        # KV text (3 lines)
        d.multiline_text((x0 + cw/2, cy0 + 195), kv, font=fkv, fill=(60,30,15), anchor="mm", align="center", spacing=10)
        # ロゴカード（共通サイズで調和）
        logo_x = x0 + (cw - LOGO_BOX_W) // 2
        logo_y = cy0 + ch - LOGO_BOX_H - 30
        d.rounded_rectangle([logo_x, logo_y, logo_x+LOGO_BOX_W, logo_y+LOGO_BOX_H], 14, fill=(255,255,255), outline=color, width=2)
        lg_path = os.path.join(LOGOS, logo_file)
        if os.path.exists(lg_path):
            lg = Image.open(lg_path).convert("RGBA")
            pad = 12
            maxw, maxh = LOGO_BOX_W - pad*2, LOGO_BOX_H - pad*2
            lg.thumbnail((maxw, maxh), Image.LANCZOS)
            paste_x = logo_x + (LOGO_BOX_W - lg.width) // 2
            paste_y = logo_y + (LOGO_BOX_H - lg.height) // 2
            if lg.mode == "RGBA":
                img.paste(lg, (paste_x, paste_y), lg)
            else:
                img.paste(lg, (paste_x, paste_y))
        # キャラ画像（ロゴカードの上の空きスペースに配置）
        char_path = os.path.join(CHARS, char_file)
        if os.path.exists(char_path):
            ch_img = Image.open(char_path).convert("RGBA")
            ch_img.thumbnail((CHAR_SIZE, CHAR_SIZE), Image.LANCZOS)
            char_x = x0 + (cw - ch_img.width) // 2
            char_y = logo_y - ch_img.height - 6  # ロゴカード上に少し被るくらい
            img.paste(ch_img, (char_x, char_y), ch_img)

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
