#!/usr/bin/env python3
"""
湾岸スーパー エリア別イラスト風マップ生成。
- CartoDB Voyager @2x retina タイルを Web Mercator 正確投影でステッチ（高解像度）
- 軽いイラスト風スタイライズ（彩度UP + 軽ポスタライズ）
- 店舗マーカー = チェーンロゴチップ、駅/ランドマークは別スタイル
- ラベル衝突回避 + リーダー線（矢印）で被りを解消

Usage: python3 scripts/gen-wangan-maps.py
出力: public/images/wangan-supermarkets-2026/wangan-map-<area>.png
"""
import math, json, io, time, urllib.request, os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMGDIR = os.path.join(ROOT, "public/images/wangan-supermarkets-2026")
ICONS = os.path.join(IMGDIR, "icons")
STORES = json.load(open(os.path.join(ROOT, "tmp/wangan-stores.json")))["stores"]

FONT = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"
FONT_L = "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc"
def font(sz, light=False): return ImageFont.truetype(FONT_L if light else FONT, sz)

Z = 16
TILE = 512          # @2x tile pixel size
LOGICAL = 256       # logical tile size
SCALE = TILE // LOGICAL

def logo_for(name):
    table = [("ライフ","logo-life.png"),("マルエツ","logo-maruetsu.png"),
             ("文化堂","logo-bunkado.png"),("成城石井","logo-seijoishii.png"),
             ("東武","logo-tobustore.jpg"),("サミット","logo-summit.png"),
             ("ダイエー","logo-daiei.png"),("まいばす","logo-maibasuketto.png"),
             ("SANWA","logo-sanwa.jpg"),("リンコス",None)]
    for key, f in table:
        if key in name:
            return f
    return None

# 駅・ランドマーク
STATIONS = {
    "勝どき駅": (35.6589, 139.7773),
    "月島駅":  (35.6654, 139.7840),
    "豊洲駅":  (35.6542, 139.7963),
}
LANDMARKS = {
    "晴海トリトンスクエア": (35.65556, 139.78183),
    "HARUMI FLAG":        (35.6515, 139.7745),
    "リバーシティ21":      (35.6690, 139.7850),
    "もんじゃストリート":    (35.6643, 139.7836),
    "ららぽーと豊洲":       (35.65581, 139.79489),
}
AREA_CONF = {
    "晴海":  {"stations": ["勝どき駅"], "landmarks": ["晴海トリトンスクエア", "HARUMI FLAG"]},
    "勝どき": {"stations": ["勝どき駅"], "landmarks": []},
    "月島":  {"stations": ["月島駅"],   "landmarks": ["リバーシティ21", "もんじゃストリート"]},
    "豊洲":  {"stations": ["豊洲駅"],   "landmarks": ["ららぽーと豊洲"]},
}

def g_px(lat, lon, z=Z):
    n = 2 ** z
    x = (lon + 180.0) / 360.0 * n * LOGICAL
    lr = math.radians(lat)
    y = (1 - math.log(math.tan(lr) + 1 / math.cos(lr)) / math.pi) / 2 * n * LOGICAL
    return x, y  # logical px

def fetch_tile(z, xt, yt, sub="abcd"):
    s = sub[(xt + yt) % len(sub)]
    url = f"https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{xt}/{yt}@2x.png"
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "daily-hack-blog/1.0"})
            return Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=25).read())).convert("RGB")
        except Exception as e:
            time.sleep(1.0 + attempt)
    raise RuntimeError(f"tile fail {url}")

def build_basemap(points, margin=215):
    gx = [g_px(la, lo)[0] for la, lo in points]
    gy = [g_px(la, lo)[1] for la, lo in points]
    minx, maxx, miny, maxy = min(gx), max(gx), min(gy), max(gy)
    # logical bbox + margin (margin given in @2x px -> /SCALE logical)
    mlog = margin / SCALE
    minx -= mlog; maxx += mlog; miny -= mlog; maxy += mlog
    tx0, tx1 = int(minx // LOGICAL), int(maxx // LOGICAL)
    ty0, ty1 = int(miny // LOGICAL), int(maxy // LOGICAL)
    canvas = Image.new("RGB", ((tx1 - tx0 + 1) * TILE, (ty1 - ty0 + 1) * TILE), "#eef3f7")
    for xt in range(tx0, tx1 + 1):
        for yt in range(ty0, ty1 + 1):
            canvas.paste(fetch_tile(Z, xt, yt), ((xt - tx0) * TILE, (yt - ty0) * TILE))
    # crop region in @2x px
    cx0 = int((minx - tx0 * LOGICAL) * SCALE)
    cy0 = int((miny - ty0 * LOGICAL) * SCALE)
    cx1 = int((maxx - tx0 * LOGICAL) * SCALE)
    cy1 = int((maxy - ty0 * LOGICAL) * SCALE)
    crop = canvas.crop((cx0, cy0, cx1, cy1))
    # origin (global logical px) of crop top-left
    origin = (minx, miny)
    return crop, origin

def to_canvas(lat, lon, origin):
    gx, gy = g_px(lat, lon)
    return (gx - origin[0]) * SCALE, (gy - origin[1]) * SCALE

def stylize(img):
    img = ImageEnhance.Color(img).enhance(1.32)
    img = ImageEnhance.Contrast(img).enhance(1.06)
    img = ImageEnhance.Brightness(img).enhance(1.02)
    img = ImageOps.posterize(img, 6)  # 軽いフラット化でイラスト風
    # soft paper overlay
    return img

# ---- label collision avoidance ----
def rects_overlap(a, b, pad=4):
    return not (a[2] + pad < b[0] or b[2] + pad < a[0] or a[3] + pad < b[1] or b[3] + pad < a[1])

def decluster(centers, mind):
    """重なり合うマーカー中心を、元の位置を保ちつつ最小距離 mind まで押し広げる（力学的）。"""
    pts = [list(c) for c in centers]
    for _ in range(80):
        moved = False
        for i in range(len(pts)):
            for j in range(i + 1, len(pts)):
                dx = pts[j][0] - pts[i][0]; dy = pts[j][1] - pts[i][1]
                d = math.hypot(dx, dy)
                if d < mind:
                    if d < 0.01:  # 完全一致（同一施設の1F/2F等）は決定的な方向へ
                        dx, dy, d = math.cos(i * 2.4), math.sin(i * 2.4), 1.0
                    push = (mind - d) / 2 + 0.6
                    ux, uy = dx / d, dy / d
                    pts[i][0] -= ux * push; pts[i][1] -= uy * push
                    pts[j][0] += ux * push; pts[j][1] += uy * push
                    moved = True
        if not moved:
            break
    return [tuple(p) for p in pts]

def place_label(anchor, w, h, placed, bounds, prefer=None):
    """マーカーの最寄りの空きスロットを放射状に探索（リーダー線を最短に＝施設の近くに置く）。"""
    ax, ay = anchor
    for radius in range(int(CHIP / 2) + 8, 480, 11):
        for ang in range(-90, 270, 16):  # 上方向を最初に試す
            rad = math.radians(ang)
            cxp = ax + math.cos(rad) * radius
            cyp = ay + math.sin(rad) * radius
            x0 = cxp - w / 2; y0 = cyp - h / 2
            x0 = max(6, min(x0, bounds[0] - w - 6))
            y0 = max(6, min(y0, bounds[1] - h - 6))
            r = (x0, y0, x0 + w, y0 + h)
            if not any(rects_overlap(r, p) for p in placed):
                return r
    x0 = max(6, min(ax + 18, bounds[0] - w - 6))
    y0 = max(6, min(ay - h / 2, bounds[1] - h - 6))
    return (x0, y0, x0 + w, y0 + h)

def draw_leader(draw, marker, rect):
    mx, my = marker
    # nearest point on rect
    nx = max(rect[0], min(mx, rect[2])); ny = max(rect[1], min(my, rect[3]))
    if abs(nx - mx) < 6 and abs(ny - my) < 6:
        return
    draw.line([(mx, my), (nx, ny)], fill=(60, 70, 90), width=3)
    draw.ellipse([nx - 4, ny - 4, nx + 4, ny + 4], fill=(60, 70, 90))

CHIP = 52  # logo chip size

def paste_logo_chip(base, cx, cy, logo_file, ring, initial=""):
    chip = Image.new("RGBA", (CHIP, CHIP), (0, 0, 0, 0))
    d = ImageDraw.Draw(chip)
    loaded = False
    if logo_file:
        try:
            lg = Image.open(os.path.join(ICONS, logo_file)).convert("RGBA")
            d.ellipse([0, 0, CHIP - 1, CHIP - 1], fill=(255, 255, 255, 255), outline=ring, width=4)
            pad = 11
            box = CHIP - pad * 2
            lg.thumbnail((box, box), Image.LANCZOS)
            chip.alpha_composite(lg, (pad + (box - lg.width) // 2, pad + (box - lg.height) // 2))
            loaded = True
        except Exception:
            loaded = False
    if not loaded:
        # ロゴ無し: ブランド色の塗りつぶし円 + 白の頭文字
        d.ellipse([0, 0, CHIP - 1, CHIP - 1], fill=ring, outline=(255, 255, 255, 255), width=4)
        if initial:
            d.text((CHIP / 2, CHIP / 2), initial, font=font(26), fill=(255, 255, 255, 255), anchor="mm")
    base.alpha_composite(chip, (int(cx - CHIP / 2), int(cy - CHIP / 2)))

BRAND_RING = {
    "ライフ": (0, 119, 73), "マルエツ": (227, 0, 79), "文化堂": (0, 90, 168),
    "成城石井": (124, 92, 56), "東武": (0, 70, 150), "サミット": (0, 150, 70),
    "ダイエー": (240, 90, 0), "まいばす": (240, 90, 0), "リンコス": (200, 30, 60),
    "SANWA": (227, 30, 40),
}
def ring_for(name):
    for k, v in BRAND_RING.items():
        if k in name:
            return v
    return (60, 70, 90)

def short_name(name):
    return (name.replace("ストア", "").replace("店", "")
            .replace("ららテラスHARUMI FLAG", "HARUMI FLAG")
            .replace("ららぽーと豊洲", "ららぽーと")
            .replace(" リバーシティ", "リバーシティ"))

def render_area(area):
    conf = AREA_CONF[area]
    stores = [s for s in STORES if s["area"] == area]
    pts = [(s["lat"], s["lng"]) for s in stores]
    pts += [STATIONS[n] for n in conf["stations"]]
    pts += [LANDMARKS[n] for n in conf["landmarks"]]
    base_rgb, origin = build_basemap(pts)
    base_rgb = stylize(base_rgb)
    W, H = base_rgb.size
    base = base_rgb.convert("RGBA")
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    bounds = (W, H)
    placed = []
    fL = font(27); fLs = font(22, light=True); fSt = font(25)

    # 同一/近接施設で重なるロゴチップを分離（位置は施設の近くを維持）
    store_centers = decluster([to_canvas(s["lat"], s["lng"], origin) for s in stores], CHIP + 8)

    # タイトルバッジ領域を予約（左上にラベルが潜り込まない）
    placed.append((6, 6, 6 + len(f"{area}エリア スーパーマップ") * 34 + 50, 76))
    # マーカー/ロゴチップの占有領域を先に予約 → ラベルが図形に被らない
    for (mx, my) in store_centers:
        placed.append((mx - CHIP / 2 - 2, my - CHIP / 2 - 2, mx + CHIP / 2 + 2, my + CHIP / 2 + 2))
    for nm in conf["stations"]:
        mx, my = to_canvas(*STATIONS[nm], origin)
        placed.append((mx - 16, my - 16, mx + 16, my + 16))
    for nm in conf["landmarks"]:
        mx, my = to_canvas(*LANDMARKS[nm], origin)
        placed.append((mx - 10, my - 10, mx + 10, my + 10))

    # 1) landmarks first (pale pill, low priority -> drawn under markers)
    for nm in conf["landmarks"]:
        cx, cy = to_canvas(*LANDMARKS[nm], origin)
        d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(150, 120, 200, 230), outline=(255, 255, 255, 255), width=3)
        tb = d.textbbox((0, 0), nm, font=fLs); tw, th = tb[2] - tb[0], tb[3] - tb[1]
        r = place_label((cx, cy), tw + 20, th + 14, placed, bounds, prefer=[(-tw - 24, -th - 22)])
        d.rounded_rectangle(r, 9, fill=(245, 240, 255, 235), outline=(150, 120, 200, 255), width=2)
        draw_leader(d, (cx, cy), r)
        d.text((r[0] + 10, r[1] + 6), nm, font=fLs, fill=(90, 60, 150, 255))
        placed.append(r)

    # 2) stations
    for nm in conf["stations"]:
        cx, cy = to_canvas(*STATIONS[nm], origin)
        d.rounded_rectangle([cx - 13, cy - 13, cx + 13, cy + 13], 5, fill=(31, 111, 235, 255), outline=(255, 255, 255, 255), width=3)
        d.text((cx, cy), "🚆", font=fSt, anchor="mm")
        label = nm
        tb = d.textbbox((0, 0), label, font=fSt); tw, th = tb[2] - tb[0], tb[3] - tb[1]
        r = place_label((cx, cy), tw + 20, th + 14, placed, bounds, prefer=[(16, -th - 22)])
        d.rounded_rectangle(r, 9, fill=(31, 111, 235, 255), outline=(255, 255, 255, 255), width=2)
        draw_leader(d, (cx, cy), r)
        d.text((r[0] + 10, r[1] + 6), label, font=fSt, fill=(255, 255, 255, 255))
        placed.append(r)

    # 3) store markers (logo chips) + labels
    chip_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for s, (cx, cy) in zip(stores, store_centers):
        nm = short_name(s["name"])
        ring = ring_for(s["name"])
        tb = d.textbbox((0, 0), nm, font=fL); tw, th = tb[2] - tb[0], tb[3] - tb[1]
        r = place_label((cx, cy), tw + 22, th + 16, placed, bounds)
        d.rounded_rectangle(r, 11, fill=(255, 255, 255, 245), outline=ring + (255,), width=3)
        draw_leader(d, (cx, cy), r)
        d.text((r[0] + 11, r[1] + 7), nm, font=fL, fill=(35, 40, 55, 255))
        placed.append(r)
        paste_logo_chip(chip_layer, cx, cy, logo_for(s["name"]), ring + (255,), initial=nm[0])

    out = Image.alpha_composite(base, overlay)
    out = Image.alpha_composite(out, chip_layer)
    # title badge
    dd = ImageDraw.Draw(out)
    ft = font(34)
    title = f"{area}エリア スーパーマップ"
    tb = dd.textbbox((0, 0), title, font=ft)
    dd.rounded_rectangle([18, 18, 18 + (tb[2] - tb[0]) + 36, 18 + (tb[3] - tb[1]) + 28], 14,
                         fill=(255, 255, 255, 235), outline=(0, 150, 136, 255), width=3)
    dd.text((36, 30), title, font=ft, fill=(0, 110, 100, 255))
    out = out.convert("RGB")
    path = os.path.join(IMGDIR, f"wangan-map-{area}.png")
    out.save(path, quality=92)
    print(f"saved {path}  {out.size}  stores={len(stores)}")

if __name__ == "__main__":
    for a in ["晴海", "勝どき", "月島", "豊洲"]:
        render_area(a)
