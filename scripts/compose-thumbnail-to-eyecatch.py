#!/usr/bin/env python3
"""SNSテンプレ(1080角)のサムネを 16:9 ブログeyecatchに合成する。
X投稿サムネのフォーマットをブログのトップ画像にそのまま活用するため、
角版ポスターを同系ピンク背景の 1600x900 に置き、下部バーを全幅に延長して
1枚のポスターに見えるよう仕上げる。

Usage: compose-thumbnail-to-eyecatch.py <square_png> <out_jpg>
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

W, H = 1600, 900

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def main():
    src_path, out_path = sys.argv[1], sys.argv[2]
    sq = Image.open(src_path).convert("RGB")

    # --- 背景: 縦グラデ(淡ピンク→白→淡ピンク) でポスターbgに馴染ませる ---
    PINK_TOP = (253, 228, 238)
    WHITE = (255, 252, 253)
    canvas = Image.new("RGB", (W, H), WHITE)
    d = ImageDraw.Draw(canvas)
    for y in range(H):
        t = y / (H - 1)
        # 0→0.5 で pink→white, 0.5→1 で white→pink
        c = lerp(PINK_TOP, WHITE, t * 2) if t < 0.5 else lerp(WHITE, PINK_TOP, (t - 0.5) * 2)
        d.line([(0, y), (W, y)], fill=c)

    # --- ピンクのドットテクスチャ(テンプレと同じ雰囲気) ---
    dot = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dot)
    step = 30
    for yy in range(0, H, step):
        for xx in range(0, W, step):
            dd.ellipse([xx, yy, xx + 3, yy + 3], fill=(214, 62, 118, 16))
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), dot).convert("RGB"), (0, 0))
    d = ImageDraw.Draw(canvas)

    # --- 角版ポスターを高さフィット(900)にして中央配置 ---
    scale = H / sq.height
    nw = int(sq.width * scale)
    sq_r = sq.resize((nw, H), Image.LANCZOS)
    px = (W - nw) // 2

    # ポスター下部の結論バー色をサンプルして全幅バーを先に描く（シームレス化）
    spx = sq_r.load()
    bar_col_l = spx[6, H - 30]
    bar_col_r = spx[nw - 6, H - 30]
    # 結論バーの上端を検出（左端列でピンクが濃くなる y）
    bar_top = H - 70
    for y in range(H - 1, H - 140, -1):
        r, g, b = spx[6, y]
        if not (r > 190 and b > 110 and g < 130):  # ピンクバーでなくなったら
            bar_top = y + 1
            break
    # 全幅バー
    for y in range(bar_top, H):
        t = (y - bar_top) / max(1, (H - bar_top))
        c = lerp((208, 59, 114), (168, 41, 89), t)
        d.line([(0, y), (W, y)], fill=c)

    # 側面に大きな淡い ¥ 装飾（テンプレ準拠）
    try:
        from PIL import ImageFont
        yf = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc", 150)
        for (yx, yy) in [(px // 2 - 60, 120), (W - px // 2 - 40, 320), (px // 2 - 70, 470)]:
            d.text((yx, yy), "¥", font=yf, fill=(214, 62, 118), anchor="mm")
    except Exception:
        pass

    # ポスター本体に軽い影をつけて前面に
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rectangle([px + 6, 6, px + nw + 6, H], fill=(120, 30, 60, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB"), (0, 0))

    # ポスター貼り付け
    canvas.paste(sq_r, (px, 0))

    canvas.save(out_path, quality=92)
    print("saved", out_path, canvas.size)

if __name__ == "__main__":
    main()
