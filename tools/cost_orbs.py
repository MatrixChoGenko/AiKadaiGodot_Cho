# カードのコストの丸（cardframe02 の energy_orb）を、フレームの金属の色（銅・銀・金）に合わせて作る。
# 使い方: python -I tools/cost_orbs.py <cardframe02 のフォルダ>  → assets/textures/card_frames/cost_orb_*.png（要 Pillow）。
# 先に tools/card_frames.py でフレームを作っておくこと（色はフレームから取る）。
# 加工：銅色の部分（輪・鋲の縁）だけを、フレームの左上のコインの輪の色に置き換える。明るさの順位を保ったまま
# フレームの輪の色の分布に合わせる（ヒストグラムの一致）ので、陰影はそのままで金属の色だけが変わる。青い中身は触らない。
# 銅（bronze）は元の画像のまま。
import colorsys
import math
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FRAMES = os.path.join(ROOT, "assets", "textures", "card_frames")
# フレーム（1024x1440）の左上のコインの輪：中心と、金属の帯の内側・外側の半径（px）。
RING_CENTER = (170, 190)
RING_R = (100, 112)


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def metal_weight(c):
    """銅らしさ 0〜1（赤 > 青で彩度がある所）。青い中身・黒い縁・灰色の鋲の芯は 0。"""
    r, g, b = (v / 255 for v in c[:3])
    _, s, v = colorsys.rgb_to_hsv(r, g, b)
    w = max(0.0, min(1.0, (r - b - 0.05) / 0.15)) * max(0.0, min(1.0, (s - 0.15) / 0.15))
    return w * max(0.0, min(1.0, (v - 0.12) / 0.1))


def ring_palette(frame_path):
    """フレームのコインの輪の色を明るさの順に並べたもの。"""
    im = Image.open(frame_path).convert("RGBA")
    cx, cy = RING_CENTER
    cols = []
    for y in range(cy - RING_R[1], cy + RING_R[1] + 1):
        for x in range(cx - RING_R[1], cx + RING_R[1] + 1):
            d = math.hypot(x - cx, y - cy)
            p = im.getpixel((x, y))
            if RING_R[0] <= d <= RING_R[1] and p[3] > 250 and lum(p) > 40:
                cols.append(p[:3])
    cols.sort(key=lum)
    return cols


def recolor(orb, palette):
    px = orb.load()
    w, h = orb.size
    metal = []
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] > 0 and metal_weight(p) > 0.0:
                metal.append((lum(p), x, y))
    metal.sort()
    n = len(metal)
    out = orb.copy()
    opx = out.load()
    for i, (_, x, y) in enumerate(metal):
        p = px[x, y]
        q = palette[min(len(palette) - 1, int(i / n * len(palette)))]
        k = metal_weight(p)
        opx[x, y] = tuple(round(p[j] * (1 - k) + q[j] * k) for j in range(3)) + (p[3],)
    return out


def main(src):
    orb = Image.open(os.path.join(src, "UI Elements", "256", "energy_orb.png")).convert("RGBA")
    orb.save(os.path.join(FRAMES, "cost_orb_bronze.png"))
    print("cost_orb_bronze.png")
    for name in ("silver", "gold"):
        palette = ring_palette(os.path.join(FRAMES, "frame_%s.png" % name))
        recolor(orb, palette).save(os.path.join(FRAMES, "cost_orb_%s.png" % name))
        print("cost_orb_%s.png (%d ring colors)" % (name, len(palette)))


if __name__ == "__main__":
    main(sys.argv[1])
