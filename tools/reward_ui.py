# 報酬画面（戦利品のパネル）とカードの 3 択（CardShowcase）の素材を作る（StS2 の見た目に寄せた仮の素材。あとで画像を差し替えてよい）。
# 使い方: python -I tools/reward_ui.py  → assets/textures/ui/reward/*.png（要 Pillow）。
# リボン = 羊皮紙の帯（両端は折り返した尾）、パネル = 青い石の枠、行 = 青い帯、角 = 金のカギ、矢印 = 赤い「進む」、
# 六角 = スキップ・目のボタン、光 = カードの足元の柔らかい光、イベントの選択肢 = 両端のとがった帯。
# どれも 4 倍で描いて縮める（hud_icons.py と同じ作り）。
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "textures", "ui", "reward")
SS = 4  # 描くときの倍率
OUTLINE = (22, 20, 26, 255)


# —— 共通 ——

def gradient(size, top, bottom):
    """上から下への色の勾配（RGBA）。"""
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return im


def outlined(mask, fill, width, color=OUTLINE):
    """mask（L）の形を fill で塗り、外側に width px の濃い縁を付ける。"""
    grown = mask.filter(ImageFilter.MaxFilter(width * 2 + 1))
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", mask.size, color), (0, 0), grown)
    out.paste(fill, (0, 0), mask)
    return out


def noise_tex(size, strength, seed, blur=1.5):
    """明るさのむら（-strength〜+strength の L 画像を 128 中心で）。"""
    rnd = random.Random(seed)
    w, h = size
    small = Image.new("L", (max(1, w // 8), max(1, h // 8)))
    small.putdata([128 + rnd.randint(-strength, strength) for _ in range(small.size[0] * small.size[1])])
    return small.resize(size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(blur * SS))


def shade(im, mask, noise):
    """noise（128 中心）で im の明るさを揺らす（mask の内側だけ）。"""
    dark = Image.new("RGBA", im.size, (0, 0, 0, 255))
    light = Image.new("RGBA", im.size, (255, 255, 255, 255))
    lo = ImageChops.multiply(noise.point(lambda v: max(0, 128 - v) * 2), mask)
    hi = ImageChops.multiply(noise.point(lambda v: max(0, v - 128) * 2), mask)
    im.paste(dark, (0, 0), lo)
    im.paste(light, (0, 0), hi)
    return im


def rough_polygon(points, jitter, seed, step):
    """多角形の辺を細かく割ってずらす（欠けた石・破れた紙の縁）。"""
    rnd = random.Random(seed)
    out = []
    for i in range(len(points)):
        x0, y0 = points[i]
        x1, y1 = points[(i + 1) % len(points)]
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
        for k in range(n):
            t = k / n
            out.append((x0 + (x1 - x0) * t + rnd.uniform(-jitter, jitter), y0 + (y1 - y0) * t + rnd.uniform(-jitter, jitter)))
    return out


def shrink(im, size):
    return im.resize(size, Image.LANCZOS)


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    im.save(path)
    print("wrote", path, im.size)


# —— リボン（見出し）——

def ribbon(w=900, h=190):
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # 尾（奥）：左右に折り返した短い帯。切れ込みは V 字。
    tail_col_top, tail_col_bot = (168, 132, 92), (122, 92, 62)
    for side in (-1, 1):
        cx = W / 2 + side * W * 0.40
        x_in, x_out = cx - side * W * 0.10, cx + side * W * 0.10
        top, bot = H * 0.30, H * 0.80
        pts = [(x_in, top), (x_out, top + H * 0.04), (x_out - side * W * 0.035, (top + bot) / 2 + H * 0.04), (x_out, bot + H * 0.04),
               (x_in, bot)]
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).polygon(rough_polygon(pts, 3 * SS, 7 + side, 10 * SS), fill=255)
        fill = shade(gradient((W, H), tail_col_top, tail_col_bot), mask, noise_tex((W, H), 26, 3 + side))
        im.alpha_composite(outlined(mask, fill, 3 * SS))
    # 帯（手前）：上下の辺が少し反った横長。
    mask = Image.new("L", (W, H), 0)
    pts = []
    x0, x1 = W * 0.13, W * 0.87
    n = 40
    for i in range(n + 1):
        t = i / n
        pts.append((x0 + (x1 - x0) * t, H * 0.14 + math.sin(t * math.pi) * -H * 0.03 + H * 0.03))
    for i in range(n + 1):
        t = 1 - i / n
        pts.append((x0 + (x1 - x0) * t, H * 0.70 + math.sin(t * math.pi) * -H * 0.03 + H * 0.03))
    ImageDraw.Draw(mask).polygon(rough_polygon(pts, 2.5 * SS, 11, 9 * SS), fill=255)
    fill = gradient((W, H), (232, 204, 158), (178, 140, 96))
    fill = shade(fill, mask, noise_tex((W, H), 30, 5))
    # 両端の折り目の影
    sh = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(sh)
    for xx in (x0, x1):
        d.rectangle((xx - W * 0.03, 0, xx + W * 0.03, H), fill=90)
    sh = ImageChops.multiply(sh.filter(ImageFilter.GaussianBlur(10 * SS)), mask)
    fill.paste(Image.new("RGBA", (W, H), (60, 36, 18, 255)), (0, 0), sh)
    # 上辺のハイライト・下辺の影
    hl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hl).rectangle((0, H * 0.17, W, H * 0.26), fill=70)
    fill.paste(Image.new("RGBA", (W, H), (255, 246, 220, 255)), (0, 0),
               ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(6 * SS)), mask))
    im.alpha_composite(outlined(mask, fill, 3 * SS))
    return shrink(im, (w, h))


# —— 戦利品のパネル（青い石の枠）——

def panel(w=560, h=640):
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    m = 6 * SS
    outer = rough_polygon([(m, m), (W - m, m), (W - m, H - m), (m, H - m)], 4 * SS, 21, 14 * SS)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(outer, fill=255)
    stone = gradient((W, H), (74, 104, 128), (48, 70, 92))
    stone = shade(stone, mask, noise_tex((W, H), 34, 9, 2.0))
    im.alpha_composite(outlined(mask, stone, 3 * SS))
    # 内側の暗い面（少しへこんだ影付き）
    b = 34 * SS
    inner = rough_polygon([(b, b), (W - b, b), (W - b, H - b), (b, H - b)], 2 * SS, 33, 16 * SS)
    imask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(imask).polygon(inner, fill=255)
    deep = gradient((W, H), (18, 30, 44), (26, 42, 58))
    edge = imask.filter(ImageFilter.MinFilter(9 * SS + 1)).filter(ImageFilter.GaussianBlur(9 * SS))
    rim = ImageChops.subtract(imask, edge)
    deep.paste(Image.new("RGBA", (W, H), (6, 10, 16, 255)), (0, 0), rim)
    im.alpha_composite(outlined(imask, deep, 3 * SS, (14, 20, 28, 255)))
    # 外枠の上辺のハイライト
    hl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hl).rectangle((0, m, W, m + 10 * SS), fill=60)
    im.paste(Image.new("RGBA", (W, H), (200, 228, 245, 255)), (0, 0),
             ImageChops.multiply(ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(4 * SS)), mask),
                                 ImageChops.invert(imask)))
    return shrink(im, (w, h))


# —— 報酬の行（青い帯）——

def row(w=440, h=84, hover=False):
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    m = 4 * SS
    pts = [(m, m + 3 * SS), (W - m, m), (W - m - 2 * SS, H - m - 6 * SS), (m + 2 * SS, H - m - 3 * SS)]
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(rough_polygon(pts, 1.2 * SS, 41, 12 * SS), fill=255)
    top, bot = ((92, 184, 214), (46, 122, 160)) if hover else ((70, 154, 190), (36, 100, 136))
    fill = shade(gradient((W, H), top, bot), mask, noise_tex((W, H), 14, 13))
    # 下の濃い帯（厚み）
    th = Image.new("L", (W, H), 0)
    ImageDraw.Draw(th).rectangle((0, H - m - 14 * SS, W, H), fill=255)
    fill.paste(Image.new("RGBA", (W, H), (28, 74, 104, 255)), (0, 0), ImageChops.multiply(th, mask))
    hl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hl).rectangle((0, m + 4 * SS, W, m + 9 * SS), fill=90 if hover else 60)
    fill.paste(Image.new("RGBA", (W, H), (230, 250, 255, 255)), (0, 0),
               ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(2 * SS)), mask))
    im.alpha_composite(outlined(mask, fill, 2 * SS))
    return shrink(im, (w, h))


def corner(size=34):
    """左上向きの金のカギ（ほかの 3 つは Godot で反転）。"""
    S = size * SS
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    t = 7 * SS
    d.polygon([(2 * SS, 2 * SS), (S - 2 * SS, 2 * SS), (S - 8 * SS, 2 * SS + t), (2 * SS + t, 2 * SS + t),
               (2 * SS + t, S - 8 * SS), (2 * SS, S - 2 * SS)], fill=255)
    fill = gradient((S, S), (255, 222, 120), (200, 140, 40))
    return shrink(outlined(mask, fill, 2 * SS, (60, 36, 10, 255)), (size, size))


# —— 進む（赤い矢印）——

def arrow(w=340, h=170):
    W, H = w * SS, h * SS
    pts = [(W * 0.03, H * 0.30), (W * 0.62, H * 0.24), (W * 0.60, H * 0.04), (W * 0.97, H * 0.52),
           (W * 0.62, H * 0.97), (W * 0.63, H * 0.76), (W * 0.06, H * 0.80), (W * 0.12, H * 0.55)]
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(rough_polygon(pts, 2 * SS, 51, 10 * SS), fill=255)
    fill = shade(gradient((W, H), (222, 92, 70), (150, 40, 34)), mask, noise_tex((W, H), 22, 17))
    hl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hl).polygon([(W * 0.06, H * 0.33), (W * 0.62, H * 0.28), (W * 0.62, H * 0.36), (W * 0.08, H * 0.40)], fill=80)
    fill.paste(Image.new("RGBA", (W, H), (255, 210, 190, 255)), (0, 0),
               ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(4 * SS)), mask))
    return shrink(outlined(mask, fill, 3 * SS), (w, h))


# —— 六角のボタン（スキップ・目）——

def hex_button(w, h, hover=False):
    W, H = w * SS, h * SS
    m = 4 * SS
    k = H * 0.42
    pts = [(m, H / 2), (m + k, m), (W - m - k, m), (W - m, H / 2), (W - m - k, H - m), (m + k, H - m)]
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    top, bot = ((110, 196, 220), (52, 128, 160)) if hover else ((80, 166, 196), (40, 104, 136))
    fill = gradient((W, H), top, bot)
    # 内側の細い明るい縁
    inner = mask.filter(ImageFilter.MinFilter(7 * SS + 1))
    rim = ImageChops.subtract(mask, inner)
    fill.paste(Image.new("RGBA", (W, H), (170, 230, 245, 255)), (0, 0), rim.point(lambda v: v * 0.6))
    hl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hl).rectangle((0, m, W, H * 0.42), fill=50)
    fill.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0),
               ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(4 * SS)), inner))
    return shrink(outlined(mask, fill, 3 * SS, (16, 34, 46, 255)), (w, h))


def eye_button(w=150, h=110, hover=False):
    base = hex_button(w, h, hover)
    S = SS
    W, H = w * S, h * S
    glyph = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(glyph)
    cx, cy, ew, eh = W / 2, H / 2, W * 0.26, H * 0.20
    d.ellipse((cx - ew, cy - eh, cx + ew, cy + eh), fill=255)
    inner = Image.new("L", (W, H), 0)
    ImageDraw.Draw(inner).ellipse((cx - ew + 7 * S, cy - eh + 6 * S, cx + ew - 7 * S, cy + eh - 6 * S), fill=255)
    glyph = ImageChops.subtract(glyph, inner)
    ImageDraw.Draw(glyph).ellipse((cx - eh * 0.62, cy - eh * 0.62, cx + eh * 0.62, cy + eh * 0.62), fill=255)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.paste(Image.new("RGBA", (W, H), (20, 44, 60, 255)), (0, 0), glyph)
    base.alpha_composite(shrink(layer, (w, h)))
    return base


# —— イベントの選択肢（両端のとがった帯。StS2 のイベント画面）——

def event_option(w=840, h=92, state="normal"):
    """暗い青緑の帯に青緑の縁。hover は縁を明るくして内側に光、disabled は灰色。9 分割で縦に伸ばして使う。"""
    W, H = w * SS, h * SS
    m = 6 * SS
    k = H * 0.36
    pts = [(m, H / 2), (m + k, m), (W - m - k, m), (W - m, H / 2), (W - m - k, H - m), (m + k, H - m)]
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    if state == "disabled":
        top, bot, rim_col = (44, 46, 50), (32, 34, 38), (88, 92, 98)
    elif state == "hover":
        top, bot, rim_col = (40, 78, 94), (26, 52, 66), (130, 230, 246)
    else:
        top, bot, rim_col = (32, 58, 70), (22, 40, 50), (70, 150, 172)
    fill = gradient((W, H), top, bot)
    rim_w = (5 if state == "hover" else 4) * SS
    inner = mask.filter(ImageFilter.MinFilter(rim_w * 2 + 1))
    rim = ImageChops.subtract(mask, inner)
    if state == "hover":
        glow = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(22 * SS + 1))).filter(ImageFilter.GaussianBlur(8 * SS))
        fill.paste(Image.new("RGBA", (W, H), rim_col + (255,)), (0, 0), ImageChops.multiply(glow, mask).point(lambda v: v * 0.45))
    fill.paste(Image.new("RGBA", (W, H), rim_col + (255,)), (0, 0), rim)
    hl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hl).rectangle((0, m, W, H * 0.4), fill=26)
    fill.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0),
               ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(4 * SS)), inner))
    return shrink(outlined(mask, fill, 2 * SS, (8, 14, 18, 255)), (w, h))


# —— カードの足元の光 ——

def halo(size=256):
    im = Image.new("L", (size, size), 0)
    ImageDraw.Draw(im).ellipse((size * 0.18, size * 0.18, size * 0.82, size * 0.82), fill=255)
    a = im.filter(ImageFilter.GaussianBlur(size * 0.12))
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(a)
    return out


# —— 行のアイコン ——

def icon_card(size=64):
    S = size * SS
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((S * 0.24, S * 0.12, S * 0.76, S * 0.88), radius=S * 0.06, fill=255)
    fill = gradient((S, S), (200, 206, 214), (120, 126, 138))
    inner = Image.new("L", (S, S), 0)
    ImageDraw.Draw(inner).rounded_rectangle((S * 0.32, S * 0.20, S * 0.68, S * 0.52), radius=S * 0.03, fill=255)
    fill.paste(Image.new("RGBA", (S, S), (70, 76, 90, 255)), (0, 0), inner)
    im = outlined(mask, fill, 3 * SS)
    return shrink(im.rotate(-10, resample=Image.BICUBIC), (size, size))


def icon_relic(size=64):
    S = size * SS
    mask = Image.new("L", (S, S), 0)
    pts = [(S * 0.5 + S * 0.36 * math.cos(math.pi / 2 + i * math.pi / 3), S * 0.5 + S * 0.36 * math.sin(math.pi / 2 + i * math.pi / 3))
           for i in range(6)]
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    fill = gradient((S, S), (255, 214, 120), (190, 120, 40))
    return shrink(outlined(mask, fill, 3 * SS), (size, size))


def icon_potion(size=64):
    S = size * SS
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((S * 0.2, S * 0.34, S * 0.8, S * 0.92), fill=255)
    d.rectangle((S * 0.40, S * 0.14, S * 0.60, S * 0.42), fill=255)
    fill = gradient((S, S), (240, 110, 110), (150, 30, 40))
    cork = Image.new("L", (S, S), 0)
    ImageDraw.Draw(cork).rectangle((S * 0.40, S * 0.10, S * 0.60, S * 0.20), fill=255)
    fill.paste(Image.new("RGBA", (S, S), (150, 110, 70, 255)), (0, 0), cork)
    return shrink(outlined(ImageChops.lighter(mask, cork), fill, 3 * SS), (size, size))


def main():
    save(ribbon(), "ribbon.png")
    save(panel(), "panel.png")
    save(row(), "row.png")
    save(row(hover=True), "row_hover.png")
    save(corner(), "corner.png")
    save(arrow(), "arrow.png")
    save(hex_button(300, 76), "hex.png")
    save(hex_button(300, 76, True), "hex_hover.png")
    save(eye_button(), "eye.png")
    save(eye_button(hover=True), "eye_hover.png")
    save(halo(), "halo.png")
    for state in ("normal", "hover", "disabled"):
        save(event_option(state=state), "event_option.png" if state == "normal" else "event_option_%s.png" % state)
    save(icon_card(), "icon_card.png")
    save(icon_relic(), "icon_relic.png")
    save(icon_potion(), "icon_potion.png")


if __name__ == "__main__":
    main()
