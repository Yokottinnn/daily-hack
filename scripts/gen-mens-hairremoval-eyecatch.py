#!/usr/bin/env python3
"""メンズ脱毛 おすすめ5社比較 2026 の eyecatch (1600x900 JPEG) を生成。
背景: 紺〜深い青〜紫グラデ（クリニカル感）。
メイン: 「メンズ脱毛 おすすめ5社比較 2026」
サブ: 「医療 vs サロン／ヒゲ脱毛から全身まで／5社徹底検証」
中央に「💎」アクセント（フォールバックは菱形）。
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "public/images/mens-hairremoval-comparison-2026")
FONT_B = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
FONT_M = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
FONT_EMOJI = "/System/Library/Fonts/Apple Color Emoji.ttc"

W, H = 1600, 900


def grad3(w, h, top, mid, bot):
    """3-stop vertical gradient (top -> mid -> bot)."""
    img = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(img)
    half = h // 2
    for y in range(h):
        if y < half:
            t = y / max(1, half - 1)
            c = tuple(int(top[i] + (mid[i] - top[i]) * t) for i in range(3))
        else:
            t = (y - half) / max(1, h - half - 1)
            c = tuple(int(mid[i] + (bot[i] - mid[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    # 紺(top) -> 深い青(mid) -> 紫(bot) のクリニカル系グラデ
    img = grad3(W, H, (22, 38, 96), (18, 26, 80), (58, 30, 110))
    d = ImageDraw.Draw(img)

    # 装飾円
    d.ellipse([W - 300, -140, W + 100, 240], fill=(80, 130, 220))
    d.ellipse([W - 230, -100, W + 40, 180], fill=(120, 170, 245))
    d.ellipse([-120, H - 240, 240, H + 100], fill=(90, 50, 160))

    # 左上アクセント細線 + キャプション
    d.rectangle([60, 80, 240, 92], fill=(255, 200, 80))
    fa = ImageFont.truetype(FONT_M, 28)
    d.text((60, 110), "DAILY HACK / COMPARISONS", font=fa, fill=(255, 220, 130))

    # メインタイトル
    ft1 = ImageFont.truetype(FONT_B, 92)
    d.text((60, 200), "メンズ脱毛 おすすめ", font=ft1, fill=(255, 255, 255))
    ft2 = ImageFont.truetype(FONT_B, 104)
    line2_a = "5社比較 "
    line2_b = "2026"
    bbox_a = d.textbbox((0, 0), line2_a, font=ft2)
    d.text((60, 318), line2_a, font=ft2, fill=(255, 220, 80))
    d.text((60 + (bbox_a[2] - bbox_a[0]), 318), line2_b, font=ft2, fill=(255, 255, 255))

    # 区切り線
    d.rectangle([60, 470, 980, 476], fill=(255, 255, 255))

    # サブ
    fs = ImageFont.truetype(FONT_M, 42)
    d.text((60, 510), "医療 vs サロン  ／  ヒゲから全身まで  ／  5社徹底検証", font=fs, fill=(225, 230, 255))

    # 5社ロゴ風チップ
    chips = ["メンズリゼ", "湘南美容", "ゴリラクリニック", "RINX", "メンズTBC"]
    fc = ImageFont.truetype(FONT_M, 28)
    x = 60
    y = 610
    for c in chips:
        tw = d.textbbox((0, 0), c, font=fc)
        w_ = (tw[2] - tw[0]) + 40
        h_ = 60
        if x + w_ > W - 60:
            x = 60
            y += 76
        d.rounded_rectangle([x, y, x + w_, y + h_], 14, fill=(255, 255, 255), outline=(180, 200, 245), width=2)
        d.text((x + w_ / 2, y + h_ / 2), c, font=fc, fill=(20, 30, 90), anchor="mm")
        x += w_ + 16

    # 右下に大きな "2026"
    fy = ImageFont.truetype(FONT_B, 200)
    txt = "2026"
    tb = d.textbbox((0, 0), txt, font=fy)
    tw = tb[2] - tb[0]
    th = tb[3] - tb[1]
    d.text((W - tw - 60 + 6, H - th - 80 + 6), txt, font=fy, fill=(0, 0, 0))
    d.text((W - tw - 60, H - th - 80), txt, font=fy, fill=(255, 220, 80))

    # 右上に「💎」絵文字 (Apple Color Emoji 固定サイズ 137 が必要)
    try:
        fe = ImageFont.truetype(FONT_EMOJI, 137)
        d.text((W - 540, 180), "💎", font=fe, embedded_color=True)
    except Exception as e:
        # フォールバック: 白い菱形
        print("emoji skipped, using fallback diamond:", e)
        cx, cy, sz = W - 460, 270, 100
        d.polygon([(cx, cy - sz), (cx + sz, cy), (cx, cy + sz), (cx - sz, cy)],
                  fill=(255, 255, 255), outline=(255, 220, 80))
        d.polygon([(cx, cy - sz + 18), (cx + sz - 18, cy), (cx, cy + sz - 18), (cx - sz + 18, cy)],
                  outline=(255, 220, 80), width=3)

    # 下部ノート
    fn = ImageFont.truetype(FONT_L, 22)
    d.text((60, H - 50), "※料金・コース内容は記事執筆時点（2026年5月）。最新条件は各社公式サイトでご確認ください。",
           font=fn, fill=(205, 215, 245))

    out = os.path.join(OUT_DIR, "eyecatch.jpg")
    img.convert("RGB").save(out, quality=88)
    print("saved", out, img.size)


if __name__ == "__main__":
    main()
