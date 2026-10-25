#!/usr/bin/env python3
"""湾岸ニュースの表紙：主催者・公式の元の画像を、そのまま 1600×900 に収める。

2026-10-25 利用者「表紙は記事のようにしないで、速報感や公式感が出るようにオリジナルの画像を使って欲しい。
ほかの湾岸ニュース記事でも同じような構成にして」。文字は足さない。画像は切らずに全体を見せ、
余白は同じ画像をぼかして暗くしたもので埋める（縦長のチラシでも横長のキービジュアルでも同じ形になる）。

Usage: gen-news-cover.py <元の画像> <出力 eyecatch.jpg>
"""
import sys
from PIL import Image, ImageFilter, ImageEnhance

src_p, out = sys.argv[1:3]
W, H = 1600, 900
src = Image.open(src_p).convert("RGB")

# 背景：同じ画像を全面に敷いて、ぼかして暗くする
sc = max(W / src.width, H / src.height)
bg = src.resize((int(src.width * sc) + 1, int(src.height * sc) + 1), Image.LANCZOS)
bg = bg.crop(((bg.width - W) // 2, (bg.height - H) // 2, (bg.width - W) // 2 + W, (bg.height - H) // 2 + H))
bg = ImageEnhance.Brightness(bg.filter(ImageFilter.GaussianBlur(28))).enhance(0.55)

# 前景：元の画像を切らずに収める（上下左右 24px の余白）
pad = 24
fs = min((W - 2 * pad) / src.width, (H - 2 * pad) / src.height)
fg = src.resize((int(src.width * fs), int(src.height * fs)), Image.LANCZOS)
bg.paste(fg, ((W - fg.width) // 2, (H - fg.height) // 2))
bg.save(out, quality=90)
print("saved", out, fg.size)
