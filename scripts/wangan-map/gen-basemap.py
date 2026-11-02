#!/usr/bin/env python3
"""湾岸イベントマップの土台（陸の輪郭）を作る（2026-11-02）。

国土地理院の淡色地図タイル（z15）を並べ、海の色の画素を除いて陸の輪郭を取り、
簡略化した SVG の path にする。区（中央区・江東区・港区など）は国土地理院の逆ジオコーダで
各島の中心から引く。**一度作れば足りる（海岸線は変わらない）**。出力は src/data/wangan-basemap.json。

出典: 国土地理院（地理院タイル・淡色地図）。マップの隅に出典を出す。
使い方: python3 scripts/wangan-map/gen-basemap.py   （要: Pillow, numpy, scipy, scikit-image）
"""
import json, math, os, urllib.request, urllib.parse
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure
from skimage.segmentation import expand_labels

# 2026-11-03 利用者「新橋・銀座エリアも表示して／逆に巽エリアとかいらない」→ 西へ広げ、東は辰巳の手前で切る
Z, X0, Y0, NX, NY = 15, 29104, 12903, 6, 8
CROP = (100, 160, 1385, 1940)     # 並べた画像のうち使う範囲（px）。北西＝新橋・銀座、南東＝青海・有明
VB = 1000                          # viewBox の横幅（縦は範囲の比で決まる）
CACHE = '/tmp/wangan-tiles'
OUT = os.path.join(os.path.dirname(__file__), '../../src/data/wangan-basemap.json')

def get(url, path):
    if not os.path.exists(path):
        urllib.request.urlretrieve(url, path)
    return path

def px_to_lonlat(px, py):
    n = 2 ** Z
    x = X0 + px / 256; y = Y0 + py / 256
    lon = x / n * 360 - 180
    lat = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))
    return lon, lat

def main():
    os.makedirs(CACHE, exist_ok=True)
    im = Image.new('RGB', (NX * 256, NY * 256))
    for i in range(NX):
        for j in range(NY):
            p = get(f'https://cyberjapandata.gsi.go.jp/xyz/pale/{Z}/{X0+i}/{Y0+j}.png', f'{CACHE}/{X0+i}_{Y0+j}.png')
            im.paste(Image.open(p).convert('RGB'), (i * 256, j * 256))
    a = np.array(im).astype(int)
    water = (abs(a[..., 0] - 190) < 14) & (abs(a[..., 1] - 210) < 14) & (a[..., 2] > 240)
    water = ndi.binary_opening(ndi.binary_closing(water, iterations=3), iterations=4)
    land = ndi.binary_opening(~water, iterations=3)
    x0, y0, x1, y1 = CROP
    land = land[y0:y1, x0:x1]
    # 橋でつながった島を分ける: 強く削って島ごとに番号を振り、元の陸の中だけで広げ直す
    core = ndi.binary_erosion(land, iterations=9)
    seeds, _ = ndi.label(core)
    lab = expand_labels(seeds, distance=14) * land
    n = int(lab.max())
    s = VB / (x1 - x0)
    vbh = round((y1 - y0) * s)
    shapes = []
    for k in range(1, n + 1):
        m = lab == k
        if m.sum() < 1500:
            continue
        m = np.pad(m, 1)
        for c in measure.find_contours(m.astype(float), 0.5):
            c = measure.approximate_polygon(c, tolerance=2.2)
            if len(c) < 4:
                continue
            pts = [((cx - 1) * s, (cy - 1) * s) for cy, cx in c]
            area = 0.5 * sum(pts[i][0] * pts[i - 1][1] - pts[i - 1][0] * pts[i][1] for i in range(len(pts)))
            if abs(area) < 60:
                continue
            d = 'M' + 'L'.join(f'{px:.1f},{py:.1f}' for px, py in pts) + 'Z'
            cy, cx = ndi.center_of_mass(lab == k)
            if not (lab[int(cy), int(cx)] == k):   # 形がくびれて中心が外に出たら、島の中の 1 点を使う
                ys, xs = np.nonzero(lab == k); cy, cx = ys[len(ys) // 2], xs[len(xs) // 2]
            lon, lat = px_to_lonlat(cx + x0, cy + y0)
            shapes.append({'d': d, 'lon': round(lon, 5), 'lat': round(lat, 5), 'area': abs(area)})
    # 区を引く（島ごとに 1 回）
    seen = {}
    for sh in shapes:
        key = (sh['lon'], sh['lat'])
        if key not in seen:
            q = urllib.parse.urlencode({'lat': sh['lat'], 'lon': sh['lon']})
            try:
                with urllib.request.urlopen(f'https://mreversegeocoder.gsi.go.jp/reverse-geocoder/LonLatToAddress?{q}', timeout=20) as r:
                    seen[key] = json.load(r).get('results', {}).get('muniCd', '')
            except Exception:
                seen[key] = ''
        sh['muni'] = seen[key]
    w_lon, n_lat = px_to_lonlat(x0, y0)
    e_lon, s_lat = px_to_lonlat(x1, y1)
    out = {
        '_note': '湾岸イベントマップの陸の輪郭。scripts/wangan-map/gen-basemap.py が国土地理院の淡色地図タイル（z15）から作った。muni は市区町村コード（13102 中央区・13108 江東区・13103 港区・13109 品川区）',
        'source': '国土地理院（地理院タイル・淡色地図）',
        'viewBox': VB,
        'viewBoxH': vbh,
        'tile': {'z': Z, 'x0': X0 + x0 / 256, 'y0': Y0 + y0 / 256, 'scale': s},
        'bounds': {'west': w_lon, 'east': e_lon, 'north': n_lat, 'south': s_lat},
        'land': [{'d': sh['d'], 'muni': sh['muni']} for sh in sorted(shapes, key=lambda x: -x['area'])],
    }
    json.dump(out, open(OUT, 'w'), ensure_ascii=False)
    print(len(shapes), 'shapes', OUT, os.path.getsize(OUT), 'bytes')

if __name__ == '__main__':
    main()
