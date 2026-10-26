# 休憩所（RestScreen）の選択肢のタイルを作る（StS2 の「Rest」「Smith」のタイルに寄せた仮の素材。あとで画像を差し替えてよい）。
# 使い方: python -I tools/rest_ui.py  → assets/textures/ui/rest/*.png（要 Pillow）。
# tile_rest = 緑の地にベッドと「Zzz」、tile_smith = 赤い光の筋の地に金床と槌と火花、tile_frame = ホバーで重ねる金の縁。
# どれも 4 倍で描いて縮める（hud_icons.py / reward_ui.py と同じ作り）。
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "textures", "ui", "rest")
FONT = os.path.join(ROOT, "assets", "fonts", "banner_mincho.ttf")
SS = 4
W, H = 300, 200
OUTLINE = (24, 18, 16, 255)


def radial(size, inner, outer, center=(0.5, 0.5)):
    w, h = size
    im = Image.new("RGBA", size)
    px = im.load()
    cx, cy = w * center[0], h * center[1]
    rmax = math.hypot(max(cx, w - cx), max(cy, h - cy))
    for y in range(0, h):
        for x in range(0, w):
            t = min(1.0, math.hypot(x - cx, y - cy) / rmax)
            px[x, y] = tuple(round(inner[i] + (outer[i] - inner[i]) * t) for i in range(3)) + (255,)
    return im


def tile_mask(S):
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).rounded_rectangle((3 * S, 3 * S, W * S - 3 * S, H * S - 3 * S), radius=14 * S, fill=255)
    return m


def outlined_shape(canvas, mask, fill, width=3):
    grown = mask.filter(ImageFilter.MaxFilter(width * SS * 2 + 1))
    canvas.paste(Image.new("RGBA", canvas.size, OUTLINE), (0, 0), grown)
    canvas.paste(fill, (0, 0), mask)


def finish(im, mask):
    """角丸で切り抜き、濃い縁を付けて縮める。"""
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", im.size, OUTLINE), (0, 0), mask)
    inner = mask.filter(ImageFilter.MinFilter(4 * SS * 2 + 1))
    out.paste(im, (0, 0), inner)
    return out.resize((W, H), Image.LANCZOS)


def tile_rest():
    S = SS
    size = (W * S, H * S)
    im = radial(size, (150, 220, 140), (40, 120, 72), (0.5, 0.45))
    d = ImageDraw.Draw(im)
    # Zzz（左上から右上へ大きくなる）
    font_path = FONT if os.path.exists(FONT) else None
    for i, (x, y, fs) in enumerate([(30, 18, 54), (92, 8, 66), (166, 0, 80)]):
        f = ImageFont.truetype(font_path, fs * S) if font_path else ImageFont.load_default()
        layer = Image.new("L", size, 0)
        ImageDraw.Draw(layer).text((x * S, y * S), "Z", font=f, fill=255)
        outlined_shape(im, layer, Image.new("RGBA", size, (226, 250, 196, 255)), 3)
    # ベッド：頭板・敷き布団・枕・脚
    shapes = []
    head = Image.new("L", size, 0)
    ImageDraw.Draw(head).rounded_rectangle((196 * S, 88 * S, 226 * S, 170 * S), radius=8 * S, fill=255)
    shapes.append((head, (150, 96, 60)))
    frame = Image.new("L", size, 0)
    ImageDraw.Draw(frame).rectangle((58 * S, 136 * S, 222 * S, 156 * S), fill=255)
    ImageDraw.Draw(frame).rectangle((62 * S, 150 * S, 74 * S, 176 * S), fill=255)
    shapes.append((frame, (128, 80, 50)))
    mattress = Image.new("L", size, 0)
    ImageDraw.Draw(mattress).rounded_rectangle((62 * S, 114 * S, 200 * S, 142 * S), radius=8 * S, fill=255)
    shapes.append((mattress, (246, 242, 228)))
    blanket = Image.new("L", size, 0)
    ImageDraw.Draw(blanket).rounded_rectangle((62 * S, 112 * S, 150 * S, 144 * S), radius=8 * S, fill=255)
    shapes.append((blanket, (226, 214, 184)))
    pillow = Image.new("L", size, 0)
    ImageDraw.Draw(pillow).rounded_rectangle((156 * S, 100 * S, 194 * S, 120 * S), radius=8 * S, fill=255)
    shapes.append((pillow, (255, 255, 248)))
    for m, col in shapes:
        outlined_shape(im, m, Image.new("RGBA", size, col + (255,)), 3)
    return finish(im, tile_mask(S))


def tile_smith():
    S = SS
    size = (W * S, H * S)
    im = radial(size, (255, 190, 120), (170, 40, 52), (0.55, 0.42))
    # 中心から外への光の筋
    rays = Image.new("L", size, 0)
    d = ImageDraw.Draw(rays)
    cx, cy = W * S * 0.55, H * S * 0.42
    rnd = random.Random(5)
    for i in range(18):
        a = i / 18 * math.tau + rnd.uniform(-0.1, 0.1)
        w = rnd.uniform(0.05, 0.11)
        r = W * S
        d.polygon([(cx, cy), (cx + math.cos(a - w) * r, cy + math.sin(a - w) * r), (cx + math.cos(a + w) * r, cy + math.sin(a + w) * r)],
                  fill=rnd.randint(50, 110))
    im.paste(Image.new("RGBA", size, (255, 236, 180, 255)), (0, 0), rays.filter(ImageFilter.GaussianBlur(2 * S)))
    # 金床
    anvil = Image.new("L", size, 0)
    d = ImageDraw.Draw(anvil)
    d.polygon([(70 * S, 112 * S), (220 * S, 112 * S), (238 * S, 100 * S), (232 * S, 126 * S), (200 * S, 132 * S), (186 * S, 150 * S),
               (204 * S, 176 * S), (96 * S, 176 * S), (114 * S, 150 * S), (100 * S, 132 * S), (78 * S, 128 * S)], fill=255)
    outlined_shape(im, anvil, Image.new("RGBA", size, (70, 66, 74, 255)), 3)
    top = Image.new("L", size, 0)
    ImageDraw.Draw(top).polygon([(74 * S, 113 * S), (222 * S, 113 * S), (232 * S, 106 * S), (226 * S, 118 * S), (78 * S, 120 * S)], fill=255)
    im.paste(Image.new("RGBA", size, (150, 146, 156, 255)), (0, 0), top)
    # 槌（柄と頭を傾けて）
    hammer = Image.new("L", size, 0)
    hd = ImageDraw.Draw(hammer)
    hd.rectangle((146 * S, 30 * S, 156 * S, 104 * S), fill=255)
    handle = hammer.rotate(-35, center=(151 * S, 100 * S), resample=Image.BICUBIC)
    outlined_shape(im, handle, Image.new("RGBA", size, (150, 98, 56, 255)), 3)
    head = Image.new("L", size, 0)
    ImageDraw.Draw(head).rounded_rectangle((126 * S, 22 * S, 178 * S, 46 * S), radius=4 * S, fill=255)
    head = head.rotate(-35, center=(151 * S, 100 * S), resample=Image.BICUBIC)
    outlined_shape(im, head, Image.new("RGBA", size, (96, 92, 104, 255)), 3)
    # 火花
    sp = Image.new("L", size, 0)
    sd = ImageDraw.Draw(sp)
    rnd = random.Random(9)
    for i in range(16):
        a = rnd.uniform(math.pi * 1.05, math.pi * 1.95)
        r0, r1 = rnd.uniform(10, 20) * S, rnd.uniform(34, 70) * S
        x0, y0 = 150 * S, 108 * S
        sd.line([(x0 + math.cos(a) * r0, y0 + math.sin(a) * r0), (x0 + math.cos(a) * r1, y0 + math.sin(a) * r1)],
                fill=255, width=3 * S)
    im.paste(Image.new("RGBA", size, (255, 246, 170, 255)), (0, 0), sp)
    return finish(im, tile_mask(S))


def tile_frame():
    """ホバーで重ねる金の縁（中は透明）。"""
    S = SS
    size = (W * S, H * S)
    outer = tile_mask(S)
    inner = outer.filter(ImageFilter.MinFilter(9 * S * 2 + 1))
    ring = ImageChops.subtract(outer, inner)
    grad = Image.new("RGBA", size)
    gd = ImageDraw.Draw(grad)
    for y in range(size[1]):
        t = y / size[1]
        gd.line([(0, y), (size[0], y)], fill=(round(255 - 40 * t), round(222 - 70 * t), round(120 - 70 * t), 255))
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", size, (60, 36, 10, 255)), (0, 0), ImageChops.subtract(ring, ring.filter(ImageFilter.MinFilter(3 * S * 2 + 1))))
    out.paste(grad, (0, 0), ring.filter(ImageFilter.MinFilter(2 * S * 2 + 1)))
    return out.resize((W, H), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, im in (("tile_rest.png", tile_rest()), ("tile_smith.png", tile_smith()), ("tile_frame.png", tile_frame())):
        path = os.path.join(OUT, name)
        im.save(path)
        print("wrote", path, im.size)


if __name__ == "__main__":
    main()
