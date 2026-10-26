# カード面のフレーム（cardframe02 の creature_card_*）を TryCard 用に加工して取り込む。
# 使い方: python -I tools/card_frames.py <cardframe02 のフォルダ>  → assets/textures/card_frames/*.png を上書きする（要 Pillow）。
# 加工：内側の列（絵の窓・名前の札・羊皮紙）だけを上へずらし、絵の窓を CUT 行縮める。名前の札は太くし、
# 羊皮紙は縦に伸ばす。外側の柱・下の丸・底の飾りは元のまま（側面の飾りを歪ませないため）。
# 加工後の各欄の位置は CardView の LAYOUT（この画像の 1024x1440 上の座標）と一致させる。
import os
import shutil
import sys

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures", "card_frames")
FRAMES = {"bronze": "creature_card_bronze", "silver": "creature_card_silver", "gold": "creature_card_gold"}

W, H = 1024, 1440
CUT_AT, CUT = 470, 90             # 絵の窓の中で行を抜く位置と量（窓 612x495 = 比 1.24。カードの絵は正方形なので抜きすぎない）
PLATE_BANDS = [(858, 870), (896, 908)]  # 名前の札の、鋲を避けた 2 つの帯（それぞれ 2 倍にする）
PARCH_TOP, PARCH_END = 985, 1150  # 羊皮紙の上の縁の下 〜 下の丸の上（ここから下は触らない）
X0, X1 = 116, 908                 # 内側の列（札の端 125 / 899 と、側面の飾りの内側 108 / 914 の間）
FEATHER = 3                       # 列の境目のぼかし幅


def rows(im, y0, y1, height=None):
    part = im.crop((0, y0, W, y1))
    return part if height is None or height == y1 - y0 else part.resize((W, height), Image.BICUBIC)


def modify(im):
    """内側の列を組み直した画像を作り、外側の列と合成する。"""
    plate_grow = sum(b - a for a, b in PLATE_BANDS)
    parts = [rows(im, 0, CUT_AT)]
    y = CUT_AT + CUT
    for a, b in PLATE_BANDS:
        parts += [rows(im, y, a), rows(im, a, b, (b - a) * 2)]
        y = b
    parts.append(rows(im, y, PARCH_TOP))
    top = PARCH_TOP - CUT + plate_grow
    parts.append(rows(im, PARCH_TOP, PARCH_END, PARCH_END - top))
    inner = Image.new("RGBA", (W, H))
    y = 0
    for p in parts:
        inner.paste(p, (0, y))
        y += p.size[1]
    assert y == PARCH_END, y
    inner.paste(rows(im, PARCH_END, H), (0, PARCH_END))
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    for i in range(FEATHER + 1):
        md.rectangle((X0 + i, 0, X1 - i, PARCH_END - 1), fill=round(255 * (i + 1) / (FEATHER + 1)))
    return Image.composite(inner, im, mask)


def main(src):
    os.makedirs(OUT, exist_ok=True)
    for name, file in FRAMES.items():
        im = Image.open(os.path.join(src, "Frames", "1024x1440", file + ".png")).convert("RGBA")
        assert im.size == (W, H), im.size
        modify(im).save(os.path.join(OUT, "frame_%s.png" % name))
        print("frame_%s.png" % name)
    shutil.copyfile(os.path.join(src, "Frames", "512x720", "card_back_player.png"), os.path.join(OUT, "card_back.png"))
    print("card_back.png")


if __name__ == "__main__":
    main(sys.argv[1])
