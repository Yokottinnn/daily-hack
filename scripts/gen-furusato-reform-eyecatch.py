#!/usr/bin/env python3
"""ふるさと納税 2026年10月改正の表紙を、10月以降の内容に描き直す（2026-10-04）。

元の表紙は「駆け込みは9月末まで」「9/30 までに確保しないと消えるかも」で、締め切りを過ぎた。
上段の写真 3 枚（米・和牛・海鮮。出典は記事末の source-note）は元の表紙からそのまま使い、
下の文字帯だけを描き直す。元画像の写真素材はリポジトリに残っていなかったため。

    python3 scripts/gen-furusato-reform-eyecatch.py <元の表紙> <出力>
"""
import sys
from PIL import Image, ImageDraw, ImageFont

SRC, OUT = sys.argv[1], sys.argv[2]
B = "/usr/share/fonts/opentype/ipafont-gothic/ipagp.ttf"
PINK, INK, SUB = (214, 62, 118), (26, 22, 26), (70, 62, 68)

im = Image.open(SRC).convert("RGB")
W, H = im.size
d = ImageDraw.Draw(im)
d.rectangle([0, 575, W, H], fill=(255, 255, 255))   # 下の文字帯（ピンクの線より下）を消す


def fit(text, size, maxw):
    while size > 20:
        f = ImageFont.truetype(B, size)
        if d.textlength(text, font=f) <= maxw:
            return f
        size -= 2
    return ImageFont.truetype(B, size)


X, MAXW = 56, W - 112
k = "2026年10月 改正 ─ 地場産品の基準が厳しくなった"
t = "ふるさと納税、10月から何が変わった？"
s = "控除の仕組みはそのまま。今年分は12月31日までの寄付が対象"
d.text((X, 600), k, font=fit(k, 38, MAXW), fill=PINK, stroke_width=1, stroke_fill=PINK)
d.text((X, 652), t, font=fit(t, 88, MAXW - 8), fill=INK, stroke_width=3, stroke_fill=INK)  # IPA に太字が無いので縁で太らせる
d.text((X, 780), s, font=fit(s, 40, MAXW), fill=SUB)
h = "@heng_ji31590"
fh = ImageFont.truetype(B, 32)
d.text((W - 56 - d.textlength(h, font=fh), 848), h, font=fh, fill=PINK, stroke_width=1, stroke_fill=PINK)
im.save(OUT, quality=90)
print(OUT, im.size)
