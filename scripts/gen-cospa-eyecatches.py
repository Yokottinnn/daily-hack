#!/usr/bin/env python3
"""C047-C051 独自指標コスパ記事の eyecatch (16:9)。
テーマ写真ポリシー準拠（キャラ画像は使わない）。
各記事の『独自指標の数式』を主役にしたクリーンなカード型デザイン。"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
FONT_B = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
W, H = 1600, 900

# slug, 背景上, 背景下, アクセント, アイコン絵文字, タイトル, 数式, サブ
SPECS = [
    ("video-subscription-cost-per-view-2026", (20,20,40),(70,30,90),(229,9,20),
     "🎬", "動画サブスク 実質1本単価", "月額 ÷ 観た本数 = 1本単価",
     "Netflix・U-NEXT・Prime・Disney+・Hulu・DAZN を本数で再評価"),
    ("cheap-sim-speed-cost-2026", (10,30,50),(20,70,110),(0,160,210),
     "📶", "格安SIM 1Mbpsあたり月額", "月額 ÷ 昼の実効速度 = 速度単価",
     "“最安”が実は割高？ 昼12時の速度で再ランキング"),
    ("budget-gym-cost-per-visit-2026", (15,40,30),(20,90,70),(0,180,120),
     "🏋️", "格安ジム 幽霊会員の期待値", "月額 ÷ 来店回数 = 1回単価",
     "chocoZAP は本当に得か？ 来店回数で損益分岐を暴く"),
    ("money-hacks-hourly-wage-2026", (45,30,10),(110,75,15),(245,170,20),
     "⏱️", "お得施策の『本当の時給』", "得した額 ÷ 手間時間 = 時給",
     "ポイ活・ふるさと納税・クレカ…一番割がいいのは"),
    ("mobility-cost-per-km-2026", (35,20,45),(80,40,100),(170,90,220),
     "🛴", "移動の 1kmあたり総コスト", "(運賃＋待ち時間) ÷ 距離 = 1km単価",
     "LUUP・シェアサイクル・タクシー・電車を時間込みで"),
]

def grad(w, h, top, bot):
    img = Image.new("RGB", (w, h), top); d = ImageDraw.Draw(img)
    for y in range(h):
        t = y/max(1,h-1)
        d.line([(0,y),(w,y)], fill=tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)))
    return img

def emoji_font(size):
    try:
        return ImageFont.truetype("/System/Library/Fonts/Apple Color Emoji.ttc", 137)
    except Exception:
        return ImageFont.truetype(FONT_B, size)

def main():
    for slug, top, bot, accent, icon, title, formula, sub in SPECS:
        img = grad(W, H, top, bot)
        d = ImageDraw.Draw(img)
        # 左アクセントバー
        d.rectangle([0,0,18,H], fill=accent)
        # ラベル「2026年最新版 / コスパ徹底比較」
        d.rounded_rectangle([70, 70, 70+330, 70+54], 27, fill=accent)
        d.text((70+165, 70+27), "2026 コスパ徹底比較", font=ImageFont.truetype(FONT,26), fill=(255,255,255), anchor="mm")
        # 右上の装飾（半透明の同心円＋アクセントドット）
        ov = Image.new("RGBA", (W, H), (0,0,0,0)); od = ImageDraw.Draw(ov)
        od.ellipse([W-360, -120, W-40, 200], outline=(255,255,255,40), width=14)
        od.ellipse([W-300, -60, W-100, 140], outline=(255,255,255,28), width=10)
        od.ellipse([W-230, 20, W-150, 100], fill=(accent[0],accent[1],accent[2],230))
        img.paste(ov, (0,0), ov); d = ImageDraw.Draw(img)
        # タイトル（大）
        ft = ImageFont.truetype(FONT_B, 78)
        d.text((70, 210), title, font=ft, fill=(255,255,255))
        # 数式カード（主役）
        cy = 380
        d.rounded_rectangle([70, cy, W-70, cy+150], 24, fill=(255,255,255))
        d.rounded_rectangle([70, cy, 86, cy+150], 0, fill=accent)
        ff = ImageFont.truetype(FONT_B, 60)
        d.text(((W)/2+8, cy+75), formula, font=ff, fill=(30,30,40), anchor="mm")
        # 「独自指標」ピル
        d.rounded_rectangle([70, cy-44, 70+220, cy-2], 21, fill=accent)
        d.text((70+110, cy-23), "独自指標で再評価", font=ImageFont.truetype(FONT,24), fill=(255,255,255), anchor="mm")
        # サブテキスト
        fs = ImageFont.truetype(FONT_L, 34)
        d.text((70, 590), sub, font=fs, fill=(235,235,245))
        # 下部ブランド
        d.text((70, H-70), "Daily Hack ｜ daily-hack.fieldbeside.com", font=ImageFont.truetype(FONT,26), fill=(200,200,215))

        outdir = os.path.join(ROOT, "public/images", slug)
        os.makedirs(outdir, exist_ok=True)
        out = os.path.join(outdir, "eyecatch.jpg")
        img.save(out, quality=90)
        print("saved", out, img.size)

if __name__ == "__main__":
    main()
