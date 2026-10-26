# exe とウィンドウのアイコンを作る（カードの裏面の中央の紋章 = 輪と爪を丸く切り抜く）。
# 使い方: python -I tools/app_icon.py  → icon.png（256 四方。project.godot の config/icon）と icon.ico（16〜256。windows_native_icon）。要 Pillow。
# 紋章の位置は card_back.png（512x720）の px で測った値。裏面を差し替えたら CENTER / RADIUS を測り直す。
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CARD_BACK = os.path.join(ROOT, "assets", "textures", "card_frames", "card_back.png")
CENTER = (256, 357)
RADIUS = 140  # 銅の輪の外側より少し大きく
SIZE = 256
SS = 4  # 丸の縁を滑らかにするため 4 倍で描いて縮める
OUTLINE = (24, 18, 22, 255)
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def main():
    back = Image.open(CARD_BACK).convert("RGBA")
    cx, cy = CENTER
    crop = back.crop((cx - RADIUS, cy - RADIUS, cx + RADIUS, cy + RADIUS))
    big = SIZE * SS
    crop = crop.resize((big, big), Image.LANCZOS)

    border = 6 * SS  # 濃い縁取りの太さ（256 px で 6 px）
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse((border, border, big - border - 1, big - border - 1), fill=255)
    outer = Image.new("L", (big, big), 0)
    ImageDraw.Draw(outer).ellipse((0, 0, big - 1, big - 1), fill=255)

    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (big, big), OUTLINE), (0, 0), outer)
    out.paste(crop, (0, 0), mask)
    out = out.resize((SIZE, SIZE), Image.LANCZOS)

    out.save(os.path.join(ROOT, "icon.png"))
    out.save(os.path.join(ROOT, "icon.ico"), sizes=ICO_SIZES)
    print("wrote icon.png / icon.ico")


if __name__ == "__main__":
    main()
