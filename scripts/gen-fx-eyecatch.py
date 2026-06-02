#!/usr/bin/env python3
"""FX口座おすすめ8社比較 2026 記事の eyecatch を生成 (1600x900 JPEG)。
背景は黒→ダークグリーンのグラデ、チャート風グリッド、ローソク足モチーフ、
上昇/下降矢印を配置。タイトル白抜き＋サブテキスト。"""
import os
import random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMGDIR = os.path.join(ROOT, "public/images/fx-account-comparison-2026")
os.makedirs(IMGDIR, exist_ok=True)

FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
FONT_EN = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

W, H = 1600, 900


def grad(w, h, top, bot):
    """vertical gradient."""
    img = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return img


def draw_grid(d, w, h, color=(40, 70, 55), step_x=80, step_y=70):
    for x in range(0, w, step_x):
        d.line([(x, 0), (x, h)], fill=color, width=1)
    for y in range(0, h, step_y):
        d.line([(0, y), (w, y)], fill=color, width=1)


def draw_candles(d, area, n=42):
    """draw stylized candlestick chart inside area=(x0,y0,x1,y1).
    Trend slightly upward overall."""
    x0, y0, x1, y1 = area
    aw = x1 - x0
    ah = y1 - y0
    cw = aw / n
    body_w = max(4, cw * 0.55)
    rng = random.Random(20260531)
    price = (y0 + y1) / 2
    mid_band = ah * 0.32
    drift = -ah * 0.005  # tiny upward drift (lower y = higher price)
    for i in range(n):
        cx = x0 + cw * (i + 0.5)
        # open price = previous close
        open_p = price
        # walk
        delta = rng.uniform(-mid_band * 0.12, mid_band * 0.12) + drift
        close_p = open_p + delta
        # clamp
        close_p = max(y0 + 30, min(y1 - 30, close_p))
        high_p = min(open_p, close_p) - rng.uniform(4, 22)
        low_p = max(open_p, close_p) + rng.uniform(4, 22)
        bull = close_p < open_p  # since y smaller = higher price, bull means close above open
        color = (60, 220, 130) if bull else (235, 90, 90)
        # wick
        d.line([(cx, high_p), (cx, low_p)], fill=color, width=2)
        # body
        top_b = min(open_p, close_p)
        bot_b = max(open_p, close_p)
        if bot_b - top_b < 3:
            bot_b = top_b + 3
        d.rectangle([cx - body_w / 2, top_b, cx + body_w / 2, bot_b], fill=color, outline=color)
        price = close_p


def draw_up_arrow(d, cx, cy, size=120, color=(80, 240, 140)):
    s = size
    poly = [
        (cx, cy - s * 0.55),
        (cx + s * 0.5, cy - s * 0.05),
        (cx + s * 0.22, cy - s * 0.05),
        (cx + s * 0.22, cy + s * 0.55),
        (cx - s * 0.22, cy + s * 0.55),
        (cx - s * 0.22, cy - s * 0.05),
        (cx - s * 0.5, cy - s * 0.05),
    ]
    d.polygon(poly, fill=color, outline=(255, 255, 255))


def draw_down_arrow(d, cx, cy, size=90, color=(230, 100, 100)):
    s = size
    poly = [
        (cx, cy + s * 0.55),
        (cx + s * 0.5, cy + s * 0.05),
        (cx + s * 0.22, cy + s * 0.05),
        (cx + s * 0.22, cy - s * 0.55),
        (cx - s * 0.22, cy - s * 0.55),
        (cx - s * 0.22, cy + s * 0.05),
        (cx - s * 0.5, cy + s * 0.05),
    ]
    d.polygon(poly, fill=color, outline=(255, 255, 255))


def main():
    # background: black → dark green
    img = grad(W, H, (8, 14, 18), (10, 60, 38))
    d = ImageDraw.Draw(img)

    # subtle chart grid
    draw_grid(d, W, H, color=(28, 60, 48), step_x=80, step_y=70)

    # candlestick chart band across the middle
    chart_area = (60, 230, W - 60, H - 200)
    draw_candles(d, chart_area, n=48)

    # diagonal "trend" line (rising)
    d.line([(80, H - 250), (W - 200, 280)], fill=(120, 240, 170), width=4)

    # corner accents: up arrow top-right, down arrow bottom-left
    draw_up_arrow(d, W - 150, 130, size=130, color=(70, 230, 140))
    draw_down_arrow(d, 140, H - 160, size=90, color=(230, 110, 110))

    # title overlay panel (semi-transparent)
    panel = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(panel)
    # main title backdrop
    pd.rectangle([0, 60, W, 280], fill=(0, 0, 0, 120))
    # bottom subtitle backdrop
    pd.rectangle([0, H - 170, W, H - 40], fill=(0, 40, 25, 165))
    img = Image.alpha_composite(img.convert("RGBA"), panel).convert("RGB")
    d = ImageDraw.Draw(img)

    # main title
    ft_main = ImageFont.truetype(FONT, 96)
    d.text((W / 2, 130), "FX口座 おすすめ8社比較 2026", font=ft_main, fill=(255, 255, 255), anchor="mm")

    # sub-title under title
    ft_sub = ImageFont.truetype(FONT_L, 38)
    d.text(
        (W / 2, 220),
        "初心者向け／スプレッド・キャッシュバック・取引ツール完全攻略",
        font=ft_sub,
        fill=(180, 235, 200),
        anchor="mm",
    )

    # bottom highlights
    ft_b = ImageFont.truetype(FONT, 44)
    d.text(
        (W / 2, H - 125),
        "スプレッド 0.2 銭〜 ／ 最大 100 万円キャッシュバック",
        font=ft_b,
        fill=(255, 235, 130),
        anchor="mm",
    )
    ft_bs = ImageFont.truetype(FONT_L, 30)
    d.text(
        (W / 2, H - 75),
        "DMM FX・外為どっとコム・GMOクリック・みんなのFX・楽天・松井・SBI・マネックス",
        font=ft_bs,
        fill=(220, 235, 220),
        anchor="mm",
    )

    # corner brand mark
    ft_brand = ImageFont.truetype(FONT_EN, 28)
    d.text((40, 40), "Daily Hack", font=ft_brand, fill=(120, 220, 160), anchor="lt")

    out = os.path.join(IMGDIR, "eyecatch.jpg")
    img.save(out, quality=90, optimize=True)
    print("saved", out, img.size)


if __name__ == "__main__":
    main()
