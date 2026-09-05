#!/usr/bin/env python3
"""
gen-mosaic-hero.py — 複数イベントの画像をタイル合成した eyecatch を作る。

まとめ記事（イベント一覧・比較記事など）で「1枚の写真では中身が伝わらない」
場合に使う。3x2 のタイルに各イベントのビジュアルを敷き、暗幕を重ねてタイトルを載せる。

**これがこのブログの表紙の標準形**（利用者指示 2026-09-05）。タイルは画面全体を
埋め、その上に透過の暗幕とロゴ・タイトルを重ねる。左に帯を作って分ける
`gen-tile6-hero.py` の形式ではなく、**原則こちらを使う。**

**左上と左下のタイルには「静かな写真」を置く。** そこは暗幕が濃く、文字が乗る。
賑やかな写真を置くと文字も写真も両方死ぬ。

Usage:
  python3.11 scripts/gen-mosaic-hero.py OUT.jpg KICKER TITLE1 TITLE2 SUB CREDIT img1 img2 ...

例:
  python3.11 scripts/gen-mosaic-hero.py out.jpg "豊洲・有明" "湾岸の8月イベント" \
      "今からでも間に合う" "無料・激安だけを厳選" "画像: 各イベント公式サイト" a.jpg b.jpg ...
"""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter

out, kicker, t1, t2, sub, credit = sys.argv[1:7]
imgs = sys.argv[7:]
if not imgs:
    print("画像を1枚以上指定すること", file=sys.stderr)
    sys.exit(1)

# macOS はヒラギノ、Linux（クラウドセッション）は IPA ゴシックを使う。
# **どちらでも同じコマンドで生成できるようにする**（2026-08-28 に代替を追加）。
import os as _os
_CAND_B = ["/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
           "/usr/share/fonts/opentype/ipafont-gothic/ipagp.ttf",
           "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"]
_CAND_L = ["/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
           "/usr/share/fonts/opentype/ipafont-gothic/ipagp.ttf",
           "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"]
FB = next((c for c in _CAND_B if _os.path.exists(c)), None)
FL = next((c for c in _CAND_L if _os.path.exists(c)), None)
if FB is None or FL is None:
    raise SystemExit("日本語フォントが見つからない: " + " / ".join(_CAND_B))
f = lambda sz, light=False: ImageFont.truetype(FL if light else FB, sz)
MAG = (214, 62, 118)
W, H = 1600, 900
COLS, ROWS = 3, 2

# --- タイル合成 ---
base = Image.new("RGB", (W, H), (18, 7, 13))
tw, th = W // COLS, H // ROWS
for i in range(COLS * ROWS):
    src_path = imgs[i % len(imgs)]
    im = Image.open(src_path).convert("RGB")
    sw, sh = im.size
    sc = max(tw / sw, th / sh)
    im = im.resize((int(sw * sc) + 1, int(sh * sc) + 1), Image.LANCZOS)
    x = (im.width - tw) // 2
    y = (im.height - th) // 2
    tile = im.crop((x, y, x + tw, y + th))
    base.paste(tile, ((i % COLS) * tw, (i // COLS) * th))

# タイルの境目をうっすら見せて「複数イベントの集合」だと分かるようにする
d0 = ImageDraw.Draw(base)
for c in range(1, COLS):
    d0.line([(c * tw, 0), (c * tw, H)], fill=(255, 255, 255), width=3)
for r in range(1, ROWS):
    d0.line([(0, r * th), (W, r * th)], fill=(255, 255, 255), width=3)

# --- 文字の可読性を確保する暗幕 ---
base = ImageEnhance.Brightness(base).enhance(0.82)
# 左から右へ濃度が下がるグラデーション（左にテキストを置くため）
grad = Image.new("L", (W, 1))
for i in range(W):
    grad.putpixel((i, 0), max(0, int(225 * (1 - i / (W * 0.72)))))
img = Image.composite(Image.new("RGB", (W, H), (18, 7, 13)), base, grad.resize((W, H)))
# 全面にも薄く敷いて、明るいタイルでも文字が負けないようにする
veil = Image.new("RGB", (W, H), (18, 7, 13))
img = Image.blend(img, veil, 0.18)

d = ImageDraw.Draw(img, "RGBA")
def rr(xy, r, fill): d.rounded_rectangle(xy, radius=r, fill=fill)
def ts(p, s, fnt, fill=(255, 255, 255), off=2):
    d.text((p[0] + off, p[1] + off), s, font=fnt, fill=(0, 0, 0, 170))
    d.text(p, s, font=fnt, fill=fill)

bp = f(30)
bw = d.textlength("Daily Hack", font=bp)
rr((50, 46, 50 + bw + 78, 102), 28, (255, 255, 255, 235))
d.ellipse((68, 64, 90, 86), fill=MAG)
d.text((100, 57), "Daily Hack", font=bp, fill=(42, 25, 35))

# **文字は暗幕が濃い左側に収める。** グラデーションは W*0.72 で薄くなるので、
# そこを越えると明るいタイルの上に白文字が乗って読めなくなる（2026-09-05）。
TEXT_W = int(W * 0.60) - 58


def shrink(text, start, floor=24):
    """左の帯に収まる最大の文字サイズを返す。**はみ出させない。**"""
    size = start
    while size > floor and d.textlength(text, font=f(size)) > TEXT_W:
        size -= 2
    return size


ks = shrink(kicker, 34, floor=22)
ts((58, 296), kicker, f(ks), fill=(255, 210, 225))
y = 296 + ks + 14
# 見出し 2 行は長いほうに合わせてサイズをそろえる
ts_size = min(shrink(t1, 104), shrink(t2, 104))
ts((54, y), t1, f(ts_size))
y += ts_size + 18
ts((54, y), t2, f(ts_size))
y += ts_size + 34
rr((58, y, 398, y + 12), 6, MAG + (255,))
y += 32
ss = shrink(sub, 36, floor=24)
ts((58, y), sub, f(ss, light=True), fill=(245, 245, 245))
ts((58, H - 50), credit, f(19, light=True), fill=(225, 225, 225), off=1)

hb = f(26); ht = "@heng_ji31590"
htw = d.textlength(ht, font=hb)
ts((W - 50 - htw, H - 58), ht, hb, fill=(255, 224, 230))

img.convert("RGB").save(out, quality=90)
print("saved", out)
