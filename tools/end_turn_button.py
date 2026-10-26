# 戦闘のターン終了ボタンの素材を作る（StS2 の「End Turn」に寄せた仮の素材。あとで画像を差し替えてよい）。
# 使い方: python -I tools/end_turn_button.py  → assets/textures/ui/hud/end_turn_{normal,hover,pressed,disabled}.png（要 Pillow）。
# 両端のとがった横長の六角の札：濃い紺の地に、黒い外枠 → 金の縁 → 細い暗い線。hover は地を明るくして内側に光。
# 9 分割（左右のとがった部分は伸ばさない）で使う。余白は main_theme.tres の StyleBoxTexture_end_turn_* と合わせる。
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "textures", "ui", "hud")
SS = 4  # 描くときの倍率
W, H = 280, 84

STATES = {
    # 地の上, 地の下, 縁, 内側の光（無し = None）
    "normal": ((48, 72, 108), (24, 38, 64), (214, 188, 132), None),
    "hover": ((70, 104, 148), (36, 58, 94), (240, 216, 160), (150, 200, 255)),
    "pressed": ((26, 40, 64), (18, 28, 46), (190, 164, 112), None),
    "disabled": ((54, 58, 66), (36, 39, 45), (128, 122, 108), None),
}


def gradient(size, top, bottom):
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return im


def hexagon(w, h, inset):
    k = h * 0.42
    return [(inset, h / 2), (inset + k, inset), (w - inset - k, inset), (w - inset, h / 2),
            (w - inset - k, h - inset), (inset + k, h - inset)]


def solid(size, color):
    return Image.new("RGBA", size, color + (255,))


def button(state):
    top, bot, rim, glow = STATES[state]
    S = (W * SS, H * SS)
    m = 3 * SS
    shape = Image.new("L", S, 0)
    ImageDraw.Draw(shape).polygon(hexagon(S[0], S[1], m), fill=255)
    out = Image.new("RGBA", S, (0, 0, 0, 0))
    # 黒い外枠（形を広げて塗る）
    out.paste(solid(S, (10, 14, 22)), (0, 0), shape.filter(ImageFilter.MaxFilter(2 * SS + 1)))
    # 金の縁（形そのもの）→ 細い暗い線 → 紺の地（内側へ順に縮める）
    out.paste(gradient(S, tuple(min(255, c + 24) for c in rim), tuple(int(c * 0.78) for c in rim)), (0, 0), shape)
    line = shape.filter(ImageFilter.MinFilter(4 * SS + 1))
    out.paste(solid(S, (14, 20, 32)), (0, 0), line)
    inner = line.filter(ImageFilter.MinFilter(2 * SS + 1))
    fill = gradient(S, top, bot)
    if glow is not None:
        ring = ImageChops.subtract(inner, inner.filter(ImageFilter.MinFilter(16 * SS + 1))).filter(ImageFilter.GaussianBlur(6 * SS))
        fill.paste(solid(S, glow), (0, 0), ImageChops.multiply(ring, inner).point(lambda v: int(v * 0.55)))
    # 上半分の弱い照り
    hl = Image.new("L", S, 0)
    ImageDraw.Draw(hl).rectangle((0, 0, S[0], S[1] * 0.45), fill=30 if state != "disabled" else 14)
    fill.paste(solid(S, (255, 255, 255)), (0, 0), ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(5 * SS)), inner))
    out.paste(fill, (0, 0), inner)
    return out.convert("RGBa").resize((W, H), Image.LANCZOS).convert("RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    for state in STATES:
        button(state).save(os.path.join(OUT, "end_turn_%s.png" % state))
    print("end_turn: %d images in %s" % (len(STATES), os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()
