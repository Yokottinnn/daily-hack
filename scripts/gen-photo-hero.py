#!/usr/bin/env python3
"""写真ヒーロー型 eyecatch 汎用生成（情景記事用・構図を他と差別化）。
Usage: gen-photo-hero.py <bg.jpg> <out.jpg> <kicker> <title1> <title2> <subtitle> <credit>
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
bg_p, out, kicker, t1, t2, sub, credit = sys.argv[1:8]
FB="/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"; FL="/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
def f(sz,light=False): return ImageFont.truetype(FL if light else FB, sz)
MAG=(214,62,118); W,H=1600,900
src=Image.open(bg_p).convert("RGB"); sw,sh=src.size; sc=max(W/sw,H/sh)
src=src.resize((int(sw*sc),int(sh*sc)),Image.LANCZOS)
x=(src.width-W)//2; y=(src.height-H)//2; img=src.crop((x,y,x+W,y+H))
img=ImageEnhance.Brightness(img).enhance(0.9)
grad=Image.new("L",(W,1))
for i in range(W): grad.putpixel((i,0),max(0,int(210*(1-i/(W*0.6)))))
img=Image.composite(Image.new("RGB",(W,H),(18,7,13)),img,grad.resize((W,H)))
d=ImageDraw.Draw(img,"RGBA")
def rr(xy,r,fill): d.rounded_rectangle(xy,radius=r,fill=fill)
def ts(p,s,fnt,fill=(255,255,255),off=2): d.text((p[0]+off,p[1]+off),s,font=fnt,fill=(0,0,0,150)); d.text(p,s,font=fnt,fill=fill)
bp=f(30); bw=d.textlength("Daily Hack",font=bp); rr((50,46,50+bw+78,102),28,(255,255,255,235)); d.ellipse((68,64,90,86),fill=MAG); d.text((100,57),"Daily Hack",font=bp,fill=(42,25,35))
ts((58,296),kicker,f(34),fill=(255,210,225))
ts((54,344),t1,f(104)); ts((54,466),t2,f(78))
rr((58,596,398,608),6,MAG+(255,)); ts((58,628),sub,f(36,light=True),fill=(245,245,245))
ts((58,H-50),credit,f(19,light=True),fill=(220,220,220),off=1)
hb=f(26); ht="@heng_ji31590"; htw=d.textlength(ht,font=hb); ts((W-50-htw,H-58),ht,hb,fill=(255,224,230))
img.convert("RGB").save(out,quality=90); print("saved",out)
