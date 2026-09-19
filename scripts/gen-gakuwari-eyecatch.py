#!/usr/bin/env python3
"""放送大学 学割の eyecatch（1600x900 JPEG）を生成。

**この記事の主役は数字。** 施設一覧ではないのでタイル合成は使わず、
損益分岐の額を表紙に置く（blog-article スキル「対象が複数の記事はタイル合成」は
一覧記事の規定であり、計算が主題の記事には当てはまらない）。

配色はこの記事の資料（アーティファクト）と揃える。
背景: 濃紺グラデ ／ アクセント: 琥珀
フォントは IPA ゴシック（クラウドセッションに入っている唯一の和文フォント）。
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "public/images/hoso-daigaku-gakuwari-2026/eyecatch.jpg")
FONT = "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"
FONT_B = "/usr/share/fonts/opentype/ipafont-gothic/ipagp.ttf"
W, H = 1600, 900
INK_TOP, INK_BOT = (17, 26, 51), (8, 12, 28)
AMBER = (227, 172, 87)
PAPER = (240, 243, 252)
MUTED = (150, 160, 190)


def grad(w, h, top, bot):
    img = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)],
               fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return img


def f(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT, size)


def main():
    img = grad(W, H, INK_TOP, INK_BOT)
    d = ImageDraw.Draw(img)

    # 左下に薄い同心円。放送＝電波の含意を、うるさくない強さで置く
    for r in range(260, 1100, 120):
        d.ellipse([-260 - r // 3, H - 120 - r, -260 + r, H - 120 + r],
                  outline=(28, 38, 70), width=2)

    x = 120
    d.text((x, 108), "放送大学 × 学割  2026年版", font=f(30, True), fill=AMBER)

    d.text((x, 176), "大人の学割は、", font=f(86, True), fill=PAPER)
    d.text((x, 286), "月1,750円で買える", font=f(86, True), fill=PAPER)

    # 損益分岐の額を図として置く
    box_y = 430
    d.rounded_rectangle([x, box_y, x + 700, box_y + 196], 14,
                        fill=(23, 32, 60), outline=(44, 56, 96), width=2)
    d.text((x + 34, box_y + 28), "選科履修生（1科目・1年）", font=f(26), fill=MUTED)
    d.text((x + 34, box_y + 68), "1,750", font=f(104, True), fill=AMBER)
    d.text((x + 330, box_y + 118), "円 / 月", font=f(34, True), fill=PAPER)
    d.text((x + 470, box_y + 74), "入学料 9,000", font=f(26), fill=MUTED)
    d.text((x + 470, box_y + 112), "＋授業料 12,000", font=f(26), fill=MUTED)

    d.line([(x, 682), (x + 150, 682)], fill=AMBER, width=5)
    d.text((x, 712), "Adobe を使うなら即 元が取れる。ただしJRの学割証は対象外",
           font=f(34, True), fill=PAPER)
    d.text((x, 768), "入学料・授業料・学生証の有効期限は放送大学 公式より",
           font=f(24), fill=MUTED)

    d.text((W - 300, H - 66), "Daily Hack", font=f(30, True), fill=MUTED)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, "JPEG", quality=90, optimize=True)
    print("saved", OUT)


if __name__ == "__main__":
    main()
