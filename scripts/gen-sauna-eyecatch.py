#!/usr/bin/env python3
"""湾岸サウナ記事の eyecatch（写真ヒーロー型）。他記事と構図を変える狙い。
背景=実在の露天風呂写真(CC) + 左から暗→透のグラデ + タイトル/ブランド/ハンドル。
出力: public/images/wangan-sauna-2026/eyecatch.jpg (1600x900)
"""
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "public/images/wangan-sauna-2026")
BG = os.path.join(D, "photos/hero-onsen.jpg")
FB = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FL = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
def f(sz, light=False): return ImageFont.truetype(FL if light else FB, sz)
MAG = (214, 62, 118)

W, H = 1600, 900
# cover crop
src = Image.open(BG).convert("RGB")
sw, sh = src.size
scale = max(W/sw, H/sh)
src = src.resize((int(sw*scale), int(sh*scale)), Image.LANCZOS)
x = (src.width - W)//2; y = (src.height - H)//2
img = src.crop((x, y, x+W, y+H))
img = ImageEnhance.Brightness(img).enhance(0.92)

# 左→右に暗くするグラデ（テキスト可読性）
grad = Image.new("L", (W, 1))
for i in range(W):
    a = max(0, int(205 * (1 - i/(W*0.62))))  # 左濃い→右で透明
    grad.putpixel((i, 0), a)
grad = grad.resize((W, H))
shade = Image.new("RGB", (W, H), (20, 8, 14))
img = Image.composite(shade, img, grad)
# 下部にも軽い暗がり
bg2 = Image.new("L",(1,H))
for j in range(H):
    bg2.putpixel((0,j), max(0,int(150*(j-H*0.62)/(H*0.38))) if j> H*0.62 else 0)
img = Image.composite(Image.new("RGB",(W,H),(20,8,14)), img, bg2.resize((W,H)))

d = ImageDraw.Draw(img, "RGBA")
def rrect(xy, r, fill):
    d.rounded_rectangle(xy, radius=r, fill=fill)
def text_sh(pos, s, font, fill=(255,255,255), sh=(0,0,0,150), off=2):
    d.text((pos[0]+off,pos[1]+off), s, font=font, fill=sh)
    d.text(pos, s, font=font, fill=fill)

# brand pill 左上
bp = f(30)
bw = d.textlength("Daily Hack", font=bp)
rrect((50,46,50+bw+78,46+56), 28, (255,255,255,235))
d.ellipse((68,64,90,86), fill=MAG)
d.text((100,57), "Daily Hack", font=bp, fill=(42,25,35))
# badge 右上
bd = f(26)
bt = "2026年版"; btw = d.textlength(bt, font=bd)
rrect((W-50-btw-46, 50, W-50, 50+50), 14, MAG+(255,))
d.text((W-50-btw-23, 58), bt, font=bd, fill=(255,255,255))

# kicker
text_sh((58, 300), "豊洲・有明・月島・芝浦", f(34, light=False), fill=(255,210,225))
# title 2行
text_sh((54, 348), "湾岸エリア", f(104))
text_sh((54, 470), "サウナ徹底比較 2026", f(82))
# magenta accent bar
rrect((58, 600, 58+340, 600+12), 6, MAG+(255,))
# subtitle
text_sh((58, 632), "コスパ＆“ととのい”で選ぶ保存版", f(36, light=True), fill=(245,245,245))

# 出典 + handle 下部
sm = f(20, light=True)
text_sh((58, H-52), "写真: 露天風呂（Wikimedia Commons, CC BY-SA 4.0）", sm, fill=(220,220,220), off=1)
hb = f(26)
ht = "@heng_ji31590"; htw = d.textlength(ht, font=hb)
text_sh((W-50-htw, H-58), ht, hb, fill=(255,224,230))

out = os.path.join(D, "eyecatch.jpg")
img.convert("RGB").save(out, quality=90)
print("saved", out, img.size)
