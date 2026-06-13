#!/usr/bin/env python3
"""
湾岸エリア 2026 花火・祭り 全体イラスト風マップ生成。
- CartoDB Voyager @2x retina タイルを Web Mercator 正確投影でステッチ
- 軽いイラスト風スタイライズ
- イベント = 種別カラーの番号ピン（花火=赤 / 祭り=橙 / 盆踊り=緑 / 番外=青）
- ラベル衝突回避 + リーダー線
- 右下に凡例（種別カラー）

Usage: python3 scripts/gen-wangan-festivals-map.py
出力: public/images/wangan-festivals-2026/wangan-festivals-map.png
"""
import math, io, time, urllib.request, os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMGDIR = os.path.join(ROOT, "public/images/wangan-festivals-2026")
os.makedirs(IMGDIR, exist_ok=True)

FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
def font(sz, light=False): return ImageFont.truetype(FONT_L if light else FONT, sz)

Z = 14
TILE = 512
LOGICAL = 256
SCALE = TILE // LOGICAL

# 種別カラー
COL = {
    "花火": (220, 38, 38),
    "祭り": (234, 109, 23),
    "盆踊り": (22, 150, 90),
    "番外": (37, 99, 235),
}

# イベント（番号順）: (番号, 名称, 種別, lat, lon, 日付ラベル)
EVENTS = [
    (1, "東京湾大華火祭",   "花火",  35.6435, 139.7860, "10/24 晴海沖"),
    (2, "江東花火大会",     "花火",  35.6745, 139.8360, "8/11 荒川"),
    (3, "佃 住吉神社例祭",  "祭り",  35.6703, 139.7856, "8/6-10 本祭り"),
    (4, "深川八幡祭り",     "祭り",  35.6718, 139.7986, "8/12-16 本祭り"),
    (5, "キラナ大夏祭り",   "盆踊り", 35.6566, 139.7918, "7/4-5 豊洲"),
    (6, "月島・勝どき盆踊り", "盆踊り", 35.6622, 139.7818, "夏(例年)"),
    (7, "お台場レインボー花火", "番外", 35.6300, 139.7742, "冬・番外"),
]

def g_px(lat, lon, z=Z):
    n = 2 ** z
    x = (lon + 180.0) / 360.0 * n * LOGICAL
    lr = math.radians(lat)
    y = (1 - math.log(math.tan(lr) + 1 / math.cos(lr)) / math.pi) / 2 * n * LOGICAL
    return x, y

def fetch_tile(z, xt, yt, sub="abcd"):
    s = sub[(xt + yt) % len(sub)]
    url = f"https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{xt}/{yt}@2x.png"
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "daily-hack-blog/1.0"})
            return Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=25).read())).convert("RGB")
        except Exception:
            time.sleep(1.0 + attempt)
    raise RuntimeError(f"tile fail {url}")

def build_basemap(points, margin=230):
    gx = [g_px(la, lo)[0] for la, lo in points]
    gy = [g_px(la, lo)[1] for la, lo in points]
    minx, maxx, miny, maxy = min(gx), max(gx), min(gy), max(gy)
    mlog = margin / SCALE
    minx -= mlog; maxx += mlog; miny -= mlog; maxy += mlog
    tx0, tx1 = int(minx // LOGICAL), int(maxx // LOGICAL)
    ty0, ty1 = int(miny // LOGICAL), int(maxy // LOGICAL)
    canvas = Image.new("RGB", ((tx1 - tx0 + 1) * TILE, (ty1 - ty0 + 1) * TILE), "#eef3f7")
    for xt in range(tx0, tx1 + 1):
        for yt in range(ty0, ty1 + 1):
            canvas.paste(fetch_tile(Z, xt, yt), ((xt - tx0) * TILE, (yt - ty0) * TILE))
    cx0 = int((minx - tx0 * LOGICAL) * SCALE)
    cy0 = int((miny - ty0 * LOGICAL) * SCALE)
    cx1 = int((maxx - tx0 * LOGICAL) * SCALE)
    cy1 = int((maxy - ty0 * LOGICAL) * SCALE)
    return canvas.crop((cx0, cy0, cx1, cy1)), (minx, miny)

def to_canvas(lat, lon, origin):
    gx, gy = g_px(lat, lon)
    return (gx - origin[0]) * SCALE, (gy - origin[1]) * SCALE

def stylize(img):
    img = ImageEnhance.Color(img).enhance(1.30)
    img = ImageEnhance.Contrast(img).enhance(1.06)
    img = ImageEnhance.Brightness(img).enhance(1.02)
    return ImageOps.posterize(img, 6)

def rects_overlap(a, b, pad=4):
    return not (a[2] + pad < b[0] or b[2] + pad < a[0] or a[3] + pad < b[1] or b[3] + pad < a[1])

def place_label(anchor, w, h, placed, bounds):
    ax, ay = anchor
    for radius in range(40, 620, 13):
        for ang in range(-90, 270, 14):
            rad = math.radians(ang)
            cxp = ax + math.cos(rad) * radius
            cyp = ay + math.sin(rad) * radius
            x0 = cxp - w / 2; y0 = cyp - h / 2
            x0 = max(8, min(x0, bounds[0] - w - 8))
            y0 = max(8, min(y0, bounds[1] - h - 8))
            r = (x0, y0, x0 + w, y0 + h)
            if not any(rects_overlap(r, p) for p in placed):
                return r
    x0 = max(8, min(ax + 20, bounds[0] - w - 8))
    y0 = max(8, min(ay - h / 2, bounds[1] - h - 8))
    return (x0, y0, x0 + w, y0 + h)

def draw_leader(draw, marker, rect):
    mx, my = marker
    nx = max(rect[0], min(mx, rect[2])); ny = max(rect[1], min(my, rect[3]))
    if abs(nx - mx) < 6 and abs(ny - my) < 6:
        return
    draw.line([(mx, my), (nx, ny)], fill=(50, 60, 80), width=3)
    draw.ellipse([nx - 4, ny - 4, nx + 4, ny + 4], fill=(50, 60, 80))

PIN_R = 27

def render():
    pts = [(e[3], e[4]) for e in EVENTS]
    base_rgb, origin = build_basemap(pts)
    base_rgb = stylize(base_rgb)
    W, H = base_rgb.size
    base = base_rgb.convert("RGBA")
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    bounds = (W, H)
    placed = []
    fL = font(28); fD = font(22, light=True)

    # タイトルバッジ領域 & 凡例領域を予約
    placed.append((14, 14, 14 + 30 * 16, 96))             # title (top-left)
    placed.append((W - 250, H - 200, W - 14, H - 14))      # legend (bottom-right)

    centers = [to_canvas(la, lo, origin) for (la, lo) in pts]
    for (mx, my) in centers:
        placed.append((mx - PIN_R - 2, my - PIN_R - 2, mx + PIN_R + 2, my + PIN_R + 2))

    # ラベル（名称 + 日付）
    for e, (cx, cy) in zip(EVENTS, centers):
        num, name, kind, *_ , date = e
        line1, line2 = name, date
        tb1 = d.textbbox((0, 0), line1, font=fL); tb2 = d.textbbox((0, 0), line2, font=fD)
        tw = max(tb1[2] - tb1[0], tb2[2] - tb2[0]); th = (tb1[3] - tb1[1]) + (tb2[3] - tb2[1]) + 8
        r = place_label((cx, cy), tw + 24, th + 18, placed, bounds)
        col = COL[kind]
        d.rounded_rectangle(r, 12, fill=(255, 255, 255, 247), outline=col + (255,), width=3)
        draw_leader(d, (cx, cy), r)
        d.text((r[0] + 12, r[1] + 8), line1, font=fL, fill=(30, 35, 50, 255))
        d.text((r[0] + 12, r[1] + 8 + (tb1[3] - tb1[1]) + 8), line2, font=fD, fill=col + (255,))
        placed.append(r)

    out = Image.alpha_composite(base, overlay)
    dd = ImageDraw.Draw(out)

    # ピン（番号付き）
    for e, (cx, cy) in zip(EVENTS, centers):
        num, name, kind = e[0], e[1], e[2]
        col = COL[kind]
        dd.ellipse([cx - PIN_R, cy - PIN_R, cx + PIN_R, cy + PIN_R], fill=col + (255,), outline=(255, 255, 255, 255), width=4)
        dd.text((cx, cy - 1), str(num), font=font(30), fill=(255, 255, 255, 255), anchor="mm")

    # タイトルバッジ
    ft = font(36)
    title = "湾岸エリア 花火・祭りマップ 2026"
    tb = dd.textbbox((0, 0), title, font=ft)
    dd.rounded_rectangle([18, 18, 18 + (tb[2] - tb[0]) + 40, 18 + (tb[3] - tb[1]) + 30], 14,
                         fill=(255, 255, 255, 240), outline=(214, 62, 118, 255), width=3)
    dd.text((38, 30), title, font=ft, fill=(168, 41, 89, 255))

    # 凡例（右下）
    lx, ly = W - 244, H - 196
    dd.rounded_rectangle([lx, ly, W - 18, H - 18], 14, fill=(255, 255, 255, 242), outline=(120, 130, 150, 255), width=2)
    dd.text((lx + 16, ly + 12), "凡例", font=font(24), fill=(40, 45, 60, 255))
    yy = ly + 50
    for kind, col in COL.items():
        dd.ellipse([lx + 18, yy, lx + 42, yy + 24], fill=col + (255,), outline=(255, 255, 255, 255), width=2)
        dd.text((lx + 54, yy - 1), kind, font=font(22, light=True), fill=(40, 45, 60, 255))
        yy += 36

    out = out.convert("RGB")
    path = os.path.join(IMGDIR, "wangan-festivals-map.png")
    out.save(path, quality=92)
    print(f"saved {path}  {out.size}  events={len(EVENTS)}")

if __name__ == "__main__":
    render()
