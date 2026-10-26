# タイトル画面のロゴを作る（StS2 のロゴに寄せた仮の素材。あとで画像を差し替えてよい）。
# 使い方: python -I tools/title_logo.py  → assets/textures/ui/title/logo.png（要 Pillow）。
# 2 段組み：1 段目「Sxxx ◆ the」、2 段目「SXXX」を大きく右へずらす。字は assets/fonts/banner_mincho.ttf。
# 金の縦グラデーション ＋ 上半分の照り ＋ 濃い茶の太い縁取り ＋ 下への落ち影。間の ◆ は青白い 4 本の光（StS2 の青い炎の代わり。しずく形は水滴に見えた）。
# 文言を変えるときは LINES を直す（漢字を使うなら tools/banner_font.py の KANJI にも足してフォントを作り直す）。
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "textures", "ui", "title")
FONT = os.path.join(ROOT, "assets", "fonts", "banner_mincho.ttf")
SS = 2  # 描くときの倍率
W, H = 1100, 520

# (文字, 字の大きさ, 左上の位置) は出力の px。
LINES = [
    ("Sxxx", 190, (40, 20)),
    ("the", 120, (560, 88)),
    ("SXXX", 230, (250, 215)),
]
FLAME_AT = (508, 138)  # 青白い光の中心

GOLD_TOP = (255, 236, 140)
GOLD_BOTTOM = (222, 138, 34)
OUTLINE = (52, 26, 10)


def gradient(size, top, bottom, y0, y1):
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = min(1.0, max(0.0, (y - y0) / max(1, y1 - y0)))
        d.line([(0, y), (w, y)], fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return im


def text_mask(size):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    for text, fs, (x, y) in LINES:
        d.text((x * SS, y * SS), text, font=ImageFont.truetype(FONT, fs * SS), fill=255)
    return mask


def flame(size):
    """青白い 4 本の光（縦が長い十字の星）。"""
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    cx, cy = FLAME_AT[0] * SS, FLAME_AT[1] * SS
    long_r, short_r, waist = 34 * SS, 22 * SS, 6 * SS
    d.polygon([(cx, cy - long_r), (cx + waist, cy - waist), (cx + short_r, cy), (cx + waist, cy + waist),
               (cx, cy + long_r), (cx - waist, cy + waist), (cx - short_r, cy), (cx - waist, cy - waist)], fill=255)
    return mask


def main():
    S = (W * SS, H * SS)
    letters = text_mask(S)
    fl = flame(S)
    out = Image.new("RGBA", S, (0, 0, 0, 0))
    # 落ち影（縁取りの形を下へずらしてぼかす）
    outline_mask = letters.filter(ImageFilter.MaxFilter(9 * SS + 1))
    shadow = outline_mask.filter(ImageFilter.GaussianBlur(8 * SS)).point(lambda v: int(v * 0.75))
    out.paste(Image.new("RGBA", S, (0, 0, 0, 255)), (0, 10 * SS), shadow)
    # 縁取り
    out.paste(Image.new("RGBA", S, OUTLINE + (255,)), (0, 0), outline_mask)
    # 金の字：各段ごとに上から下へのグラデーション
    gold = Image.new("RGBA", S, (0, 0, 0, 0))
    for text, fs, (x, y) in LINES:
        top, bottom = (y + fs * 0.15) * SS, (y + fs * 1.05) * SS
        g = gradient(S, GOLD_TOP, GOLD_BOTTOM, top, bottom)
        band = Image.new("L", S, 0)
        ImageDraw.Draw(band).rectangle((0, y * SS, S[0], (y + fs * 1.3) * SS), fill=255)
        gold.paste(g, (0, 0), ImageChops.multiply(band, letters))
    out.alpha_composite(gold)
    # 上半分の照り（字の内側だけ、上辺から少し下まで白っぽく）
    inner = letters.filter(ImageFilter.MinFilter(3 * SS + 1))
    shine = ImageChops.subtract(inner, inner.transform(S, Image.AFFINE, (1, 0, 0, 0, 1, -6 * SS)))
    out.paste(Image.new("RGBA", S, (255, 250, 220, 255)), (0, 0), shine.filter(ImageFilter.GaussianBlur(1.5 * SS)).point(lambda v: int(v * 0.8)))
    # 青白い炎（外側に柔らかい光）
    glow = fl.filter(ImageFilter.MaxFilter(6 * SS + 1)).filter(ImageFilter.GaussianBlur(10 * SS))
    out.paste(Image.new("RGBA", S, (90, 200, 255, 255)), (0, 0), glow.point(lambda v: int(v * 0.8)))
    out.paste(Image.new("RGBA", S, (20, 40, 70, 255)), (0, 0), fl.filter(ImageFilter.MaxFilter(3 * SS + 1)))
    out.paste(gradient(S, (230, 250, 255), (80, 190, 250), (FLAME_AT[1] - 34) * SS, (FLAME_AT[1] + 34) * SS), (0, 0), fl)
    os.makedirs(OUT, exist_ok=True)
    out = out.convert("RGBa").resize((W, H), Image.LANCZOS).convert("RGBA")
    out = out.crop(out.getbbox())
    out.save(os.path.join(OUT, "logo.png"))
    print("logo: %dx%d" % out.size)


if __name__ == "__main__":
    main()
