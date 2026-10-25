#!/usr/bin/env python3
"""湾岸ニュースの表紙：主催者・公式の元の画像を、ブログの表紙の形（1600×900）に合わせる。

2026-10-25 利用者「表紙は記事のようにしないで、速報感や公式感が出るようにオリジナルの画像を使って欲しい」。文字は足さない。
2026-10-25 利用者「縦長の画像だろうとすべてブログにマッチするようにしてほしい。基本的には切り取った方がいい。
最悪は縦長に画像をはめるか」。→ **既定は切り取り**（16:9 で画面いっぱい）。どこを残すかは --y / --x で決める。
切り取ると要の部分（題名・日付）が入らないときだけ --fit（全体を収め、余白は同じ画像をぼかして埋める）。

Usage: gen-news-cover.py <元の画像> <出力 eyecatch.jpg> [--y 0.0〜1.0] [--x 0.0〜1.0] [--fit]
  --y  縦長の画像で、どの高さを残すか（0 = いちばん上、0.5 = 真ん中、1 = いちばん下）。既定 0.3
  --x  横長すぎる画像で、どの位置を残すか。既定 0.5
"""
import argparse
from PIL import Image, ImageFilter, ImageEnhance

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("out")
ap.add_argument("--y", type=float, default=0.3)
ap.add_argument("--x", type=float, default=0.5)
ap.add_argument("--fit", action="store_true")
a = ap.parse_args()
W, H = 1600, 900
src = Image.open(a.src).convert("RGB")

def cover(img, fx, fy):
    # 16:9 で画面いっぱいに切り取る
    sc = max(W / img.width, H / img.height)
    r = img.resize((round(img.width * sc), round(img.height * sc)), Image.LANCZOS)
    x0 = round((r.width - W) * fx); y0 = round((r.height - H) * fy)
    return r.crop((x0, y0, x0 + W, y0 + H))

if a.fit:
    bg = ImageEnhance.Brightness(cover(src, .5, .5).filter(ImageFilter.GaussianBlur(28))).enhance(0.55)
    pad = 24
    fs = min((W - 2 * pad) / src.width, (H - 2 * pad) / src.height)
    fg = src.resize((int(src.width * fs), int(src.height * fs)), Image.LANCZOS)
    bg.paste(fg, ((W - fg.width) // 2, (H - fg.height) // 2))
    out = bg
else:
    out = cover(src, a.x, a.y)
out.save(a.out, quality=90)
print("saved", a.out, "fit" if a.fit else f"crop x={a.x} y={a.y}", "元", src.size)
