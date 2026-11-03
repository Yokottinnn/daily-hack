#!/usr/bin/env python3
"""湾岸イベントマップの「外側」の陸（2026-11-03）。

利用者「－を押した時はもっと広範囲の地図を表示して／左右の部分がすぐに消えてしまってデザイン上かなりひどい」。
本体の地図（gen-basemap.py・z15）の外側を、国土地理院の淡色地図タイル（z14）から取り、
**本体と同じ座標（viewBox の単位）**の SVG path にする。座標は負や 1000 超えになる（地図の外側だから）。
縮小したときに、本体の周りに陸が続いて見えるようにするためのもので、ピン・地区名は置かない。

出力: src/data/wangan-basemap-wide.json
使い方: python3 scripts/wangan-map/gen-basemap-wide.py   （要: Pillow, numpy, scipy, scikit-image）
"""
import json, os, urllib.request
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage import measure

HERE = os.path.dirname(__file__)
BASE = json.load(open(os.path.join(HERE, '../../src/data/wangan-basemap.json')))
T = BASE['tile']                      # 本体の原点（z15 のタイル座標）と倍率
Z = 14
# z14 のタイル範囲（本体のおよそ 3 倍の幅・2.6 倍の高さ）。北は日本橋・築地の北、南は品川・東京港、東は辰巳・新木場の手前
X14 = range(14550, 14559)
Y14 = range(6449, 6459)
CACHE = '/tmp/wangan-tiles-z14'
OUT = os.path.join(HERE, '../../src/data/wangan-basemap-wide.json')

def get(url, path):
    if not os.path.exists(path):
        urllib.request.urlretrieve(url, path)
    return path

def main():
    os.makedirs(CACHE, exist_ok=True)
    nx, ny = len(X14), len(Y14)
    im = Image.new('RGB', (nx * 256, ny * 256))
    for i, x in enumerate(X14):
        for j, y in enumerate(Y14):
            p = get(f'https://cyberjapandata.gsi.go.jp/xyz/pale/{Z}/{x}/{y}.png', f'{CACHE}/{x}_{y}.png')
            im.paste(Image.open(p).convert('RGB'), (i * 256, j * 256))
    a = np.array(im).astype(int)
    water = (abs(a[..., 0] - 190) < 14) & (abs(a[..., 1] - 210) < 14) & (a[..., 2] > 240)
    water = ndi.binary_opening(ndi.binary_closing(water, iterations=2), iterations=2)
    land = ndi.binary_opening(~water, iterations=2)
    lab, n = ndi.label(land)
    # z14 の画素 → z15 の画素 → 本体の viewBox の単位
    ox = (X14[0] * 256) * 2 - T['x0'] * 256
    oy = (Y14[0] * 256) * 2 - T['y0'] * 256
    s = T['scale']
    shapes = []
    for k in range(1, n + 1):
        m = lab == k
        if m.sum() < 300:
            continue
        m = np.pad(m, 1)
        for c in measure.find_contours(m.astype(float), 0.5):
            c = measure.approximate_polygon(c, tolerance=1.4)
            if len(c) < 4:
                continue
            pts = [(((cx - 1) * 2 + ox) * s, ((cy - 1) * 2 + oy) * s) for cy, cx in c]
            area = 0.5 * sum(pts[i][0] * pts[i - 1][1] - pts[i - 1][0] * pts[i][1] for i in range(len(pts)))
            if abs(area) < 200:
                continue
            shapes.append({'d': 'M' + 'L'.join(f'{px:.0f},{py:.0f}' for px, py in pts) + 'Z', 'area': abs(area)})
    ext = {'x': round(ox * s), 'y': round(oy * s), 'w': round(nx * 256 * 2 * s), 'h': round(ny * 256 * 2 * s)}
    out = {
        '_note': '湾岸イベントマップの外側の陸（縮小したときに見える）。scripts/wangan-map/gen-basemap-wide.py が国土地理院の淡色地図タイル（z14）から作った。座標は本体（wangan-basemap.json）と同じ viewBox の単位',
        'source': '国土地理院（地理院タイル・淡色地図）',
        'extent': ext,
        # 川・運河・入り江は陸の輪郭の「穴」として出てくる。全部を 1 本の path にまとめ、evenodd で塗る（穴を海に残す）
        'land': [' '.join(sh['d'] for sh in shapes)],
        'fillRule': 'evenodd',
    }
    json.dump(out, open(OUT, 'w'), ensure_ascii=False)
    print(len(shapes), 'shapes', ext, OUT, os.path.getsize(OUT), 'bytes')

if __name__ == '__main__':
    main()
