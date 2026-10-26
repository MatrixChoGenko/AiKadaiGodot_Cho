# 戦闘画面の山（山札・捨て札・廃棄）と上部バーのアイコン・背景を作る（StS2 の HUD に寄せた仮の素材。あとで画像を差し替えてよい）。
# 使い方: python -I tools/hud_icons.py  → assets/textures/ui/hud/*.png（要 Pillow）。
# 山のアイコンはカードの裏面（card_frames/card_back.png）を傾けて 3 枚重ねる。捨て札は青、廃棄は紫がかった灰色に色を変える。
# ほかの図形は 4 倍の大きさで描いて縮める（縁を滑らかにする）。どれも濃い縁取り＋上からの明るさの勾配＋白いハイライト。
import colorsys
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "textures", "ui", "hud")
CARD_BACK = os.path.join(ROOT, "assets", "textures", "card_frames", "card_back.png")
SS = 4  # 描くときの倍率
OUTLINE = (24, 18, 22, 255)


# —— 共通 ——

def finish(im, size):
    return im.resize((size, size), Image.LANCZOS)


def outlined(mask, fill, width):
    """mask（L）の形を fill（RGBA 画像）で塗り、外側に width px の濃い縁を付ける。"""
    grown = mask.filter(ImageFilter.MaxFilter(width * 2 + 1))
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", mask.size, OUTLINE), (0, 0), grown)
    out.paste(fill, (0, 0), mask)
    return out


def gradient(size, top, bottom):
    """上から下への色の勾配（RGBA）。"""
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return im


def highlight(im, mask, box, alpha=110):
    """mask の内側の box（楕円）に白いハイライトを重ねる。"""
    hl = Image.new("L", mask.size, 0)
    ImageDraw.Draw(hl).ellipse(box, fill=alpha)
    hl = ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(mask.size[0] // 40)), mask)
    white = Image.new("RGBA", mask.size, (255, 255, 255, 255))
    im.paste(white, (0, 0), hl)
    return im


def recolor(im, hue, sat_scale, val_scale):
    """色相を hue（0〜1）にそろえ、彩度と明るさを掛ける（アルファは保つ）。"""
    px = im.load()
    out = Image.new("RGBA", im.size)
    po = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                po[x, y] = (0, 0, 0, 0)
                continue
            _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            r2, g2, b2 = colorsys.hsv_to_rgb(hue, min(1.0, s * sat_scale), min(1.0, v * val_scale))
            po[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return out


# —— 山（カードの束）——

def card_stack(card, size, angles, offsets, card_h):
    """card を傾けて重ねた束。angles / offsets は奥から手前の順（度・中心からの px）。"""
    big = size * SS
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ch = card_h * SS
    cw = round(ch * card.size[0] / card.size[1])
    c = card.resize((cw, ch), Image.LANCZOS)
    for ang, (ox, oy) in zip(angles, offsets):
        r = c.rotate(ang, resample=Image.BICUBIC, expand=True)
        # 下に落ちる影
        shadow = Image.new("RGBA", r.size, (0, 0, 0, 0))
        shadow.paste(Image.new("RGBA", r.size, (0, 0, 0, 150)), (0, 0), r.split()[3])
        shadow = shadow.filter(ImageFilter.GaussianBlur(3 * SS))
        x = big // 2 + ox * SS - r.size[0] // 2
        y = big // 2 + oy * SS - r.size[1] // 2
        canvas.alpha_composite(shadow, (x + 2 * SS, y + 4 * SS))
        canvas.alpha_composite(r, (x, y))
    return finish(canvas, size)


def piles():
    back = Image.open(CARD_BACK).convert("RGBA")
    small = back.resize((back.size[0] // 2, back.size[1] // 2), Image.LANCZOS)
    angles = [-20, -9, 4]
    offsets = [(-14, 4), (-4, 0), (8, -2)]
    variants = {
        "pile_draw": small,
        "pile_discard": recolor(small, 0.57, 1.25, 1.1),
        "pile_exhaust": recolor(small, 0.78, 0.45, 0.85),
    }
    for name, card in variants.items():
        card_stack(card, 192, angles, offsets, 128).save(os.path.join(OUT, name + ".png"))
    # 上部バーのデッキ：2 枚の扇。
    card_stack(small, 128, [-14, 8], [(-10, 4), (10, 0)], 108).save(os.path.join(OUT, "deck.png"))


# —— 上部バーの図形 ——

def heart():
    n = 96 * SS
    mask = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(mask)
    pts = []
    for i in range(360):
        t = math.radians(i)
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((n / 2 + x * n / 40, n * 0.47 - y * n / 40))
    d.polygon(pts, fill=255)
    im = outlined(mask, gradient((n, n), (240, 70, 70), (150, 20, 35)), 4 * SS)
    highlight(im, mask, (n * 0.22, n * 0.2, n * 0.45, n * 0.42), 150)
    finish(im, 96).save(os.path.join(OUT, "heart.png"))


def coin():
    n = 96 * SS
    m = n * 0.1
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).ellipse((m, m, n - m, n - m), fill=255)
    im = outlined(mask, gradient((n, n), (255, 220, 110), (200, 130, 30)), 4 * SS)
    d = ImageDraw.Draw(im)
    r = n * 0.24
    d.ellipse((n / 2 - r, n / 2 - r, n / 2 + r, n / 2 + r), outline=(150, 90, 20, 255), width=3 * SS)
    d.ellipse((n / 2 - r * 0.45, n / 2 - r * 0.45, n / 2 + r * 0.45, n / 2 + r * 0.45), fill=(170, 105, 25, 255))
    highlight(im, mask, (n * 0.22, n * 0.16, n * 0.55, n * 0.42), 140)
    finish(im, 96).save(os.path.join(OUT, "coin.png"))


def stairs():
    n = 96 * SS
    mask = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(mask)
    steps = 4
    x0, x1, y1 = n * 0.12, n * 0.88, n * 0.86
    h = (y1 - n * 0.14) / steps
    w = (x1 - x0) / steps
    for i in range(steps):
        d.rectangle((x0 + w * i, y1 - h * (i + 1), x1, y1), fill=255)
    im = outlined(mask, gradient((n, n), (235, 238, 240), (150, 160, 170)), 4 * SS)
    finish(im, 96).save(os.path.join(OUT, "floor.png"))


def gear():
    n = 96 * SS
    c = n / 2
    teeth = 8
    mask = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(mask)
    pts = []
    for i in range(teeth * 4):
        a = math.tau * i / (teeth * 4)
        r = n * (0.42 if (i % 4) in (1, 2) else 0.32)
        pts.append((c + r * math.cos(a), c + r * math.sin(a)))
    d.polygon(pts, fill=255)
    hole = n * 0.13
    d.ellipse((c - hole, c - hole, c + hole, c + hole), fill=0)
    im = outlined(mask, gradient((n, n), (230, 232, 235), (140, 148, 158)), 4 * SS)
    finish(im, 96).save(os.path.join(OUT, "gear.png"))


def hero():
    """騎士の兜（プレイヤーのキャラ。3D の騎士に合わせた）。"""
    n = 128 * SS
    c = n / 2
    mask = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(mask)
    # 丸い頭頂 + 下へ伸びる面当て
    d.ellipse((c - n * 0.3, n * 0.18, c + n * 0.3, n * 0.78), fill=255)
    d.rectangle((c - n * 0.3, n * 0.48, c + n * 0.3, n * 0.86), fill=255)
    steel = gradient((n, n), (225, 230, 238), (110, 118, 132))
    im = outlined(mask, steel, 4 * SS)
    d2 = ImageDraw.Draw(im)
    # のぞき穴と、縦の補強
    d2.rounded_rectangle((c - n * 0.24, n * 0.47, c + n * 0.24, n * 0.54), radius=n * 0.03, fill=OUTLINE)
    d2.rectangle((c - n * 0.025, n * 0.24, c + n * 0.025, n * 0.47), fill=(150, 158, 172, 255))
    for i in range(3):
        y = n * (0.62 + 0.07 * i)
        d2.rectangle((c - n * 0.16, y, c + n * 0.16, y + n * 0.025), fill=(60, 62, 72, 255))
    # 赤い羽根飾り
    plume = Image.new("L", (n, n), 0)
    ImageDraw.Draw(plume).pieslice((c - n * 0.06, n * 0.02, c + n * 0.42, n * 0.5), 180, 280, fill=255)
    plume_im = outlined(plume, gradient((n, n), (235, 70, 60), (140, 20, 25)), 3 * SS)
    im = Image.alpha_composite(plume_im, im)
    highlight(im, mask, (c - n * 0.22, n * 0.22, c - n * 0.02, n * 0.42), 120)
    finish(im, 128).save(os.path.join(OUT, "hero.png"))


def flask():
    """空のポーション枠（灰色の瓶の影）。"""
    n = 96 * SS
    c = n / 2
    mask = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((c - n * 0.3, n * 0.32, c + n * 0.3, n * 0.92), fill=255)
    d.rectangle((c - n * 0.1, n * 0.12, c + n * 0.1, n * 0.42), fill=255)
    d.rounded_rectangle((c - n * 0.15, n * 0.06, c + n * 0.15, n * 0.16), radius=n * 0.03, fill=255)
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    im.paste(Image.new("RGBA", (n, n), (120, 130, 140, 255)), (0, 0), mask)
    finish(im, 96).save(os.path.join(OUT, "potion_empty.png"))


def bar():
    """上部バーの石の帯（横に繰り返せる 512x80）。下の縁を暗く、上の縁を少し明るく。"""
    w, h = 512, 80
    rnd = random.Random(7)
    base = (40, 56, 66)
    # 横に巡回する値ノイズ（2 オクターブ）
    def layer(cells_x, cells_y, amp):
        grid = [[rnd.random() for _ in range(cells_x)] for _ in range(cells_y + 1)]
        img = Image.new("L", (w, h))
        px = img.load()
        for y in range(h):
            fy = y / h * cells_y
            iy = int(fy)
            ty = fy - iy
            ty = ty * ty * (3 - 2 * ty)
            for x in range(w):
                fx = x / w * cells_x
                ix = int(fx)
                tx = fx - ix
                tx = tx * tx * (3 - 2 * tx)
                a = grid[iy][ix % cells_x] * (1 - tx) + grid[iy][(ix + 1) % cells_x] * tx
                b = grid[min(iy + 1, cells_y)][ix % cells_x] * (1 - tx) + grid[min(iy + 1, cells_y)][(ix + 1) % cells_x] * tx
                px[x, y] = round(128 + (a * (1 - ty) + b * ty - 0.5) * 255 * amp)
        return img

    noise = ImageChops.add(layer(16, 3, 0.35), layer(64, 10, 0.25), scale=1.0, offset=-128)
    im = Image.new("RGBA", (w, h))
    px = im.load()
    npx = noise.load()
    for y in range(h):
        edge = 1.0
        if y < 3:
            edge = 1.25
        elif y >= h - 6:
            edge = 0.45
        for x in range(w):
            k = (npx[x, y] - 128) / 255 * 0.5 + 1.0
            px[x, y] = tuple(max(0, min(255, round(v * k * edge))) for v in base) + (255,)
    # ひび（暗い細線。左右の端はまたがない）
    d = ImageDraw.Draw(im)
    for _ in range(6):
        x = rnd.uniform(30, w - 60)
        y = rnd.uniform(8, h - 16)
        pts = [(x, y)]
        for _ in range(rnd.randint(3, 6)):
            x += rnd.uniform(6, 18)
            y += rnd.uniform(-6, 6)
            pts.append((min(x, w - 20), max(4, min(h - 10, y))))
        d.line(pts, fill=(22, 30, 36, 200), width=1)
    im.save(os.path.join(OUT, "bar.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    piles()
    heart()
    coin()
    stairs()
    gear()
    hero()
    flask()
    bar()
    print("written:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
