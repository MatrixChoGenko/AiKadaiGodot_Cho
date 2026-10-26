# カードのイラスト（AI で作った正方形の絵）を取り込む。
# 使い方: python -I tools/card_art.py [元の絵のフォルダ]（既定 assets/AiGenerateCardArt）→ assets/textures/card_art/<id>.png（要 Pillow）。
# その後 Godot で tools/card_art.gd を実行して、カードの .tres に絵と見せる位置（art_focus）を入れる。
# ファイル名の英小文字の部分（例「ストライク strike .jpg」の strike）をカードの id とする。英字の無い名前は NAMES で引く。
# 絵は切らずに SIZE 四方へ縮小するだけ。窓に見せる範囲はゲーム側（CardView.art_region と CardData.art_focus）で決める。
import glob
import os
import re
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "assets", "AiGenerateCardArt")
OUT = os.path.join(ROOT, "assets", "textures", "card_art")
SIZE = 512  # 手札で窓は 140px 前後、拡大表示でも 300px 未満
NAMES = {"防御": "defend"}
# ミップマップあり（縮小表示のちらつき防止）＋ VRAM 圧縮（全カードの絵が常に読み込まれるため）。残りは Godot が埋める。
IMPORT = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=2\nmipmaps/generate=true\n'


def card_id(path):
    stem = os.path.splitext(os.path.basename(path))[0]
    words = re.findall(r"[a-z][a-z_]*", stem)
    if words:
        return words[0]
    return NAMES.get(stem.strip())


def card_exists(cid):
    return bool(glob.glob(os.path.join(ROOT, "content", "cards", "*", cid + ".tres")))


def main(src):
    os.makedirs(OUT, exist_ok=True)
    ok = True
    for path in sorted(glob.glob(os.path.join(src, "*"))):
        if os.path.splitext(path)[1].lower() not in (".jpg", ".jpeg", ".png", ".webp"):
            continue
        cid = card_id(path)
        if cid is None or not card_exists(cid):
            print("SKIP %s: no card id %r" % (os.path.basename(path), cid))
            ok = False
            continue
        im = Image.open(path).convert("RGB")
        if im.width != im.height:
            print("WARN %s: not square %s (the window shows the full width)" % (cid, im.size))
        im.resize((SIZE, round(SIZE * im.height / im.width)), Image.LANCZOS).save(os.path.join(OUT, cid + ".png"), optimize=True)
        imp = os.path.join(OUT, cid + ".png.import")
        if not os.path.exists(imp):
            with open(imp, "w", encoding="utf-8", newline="\n") as f:
                f.write(IMPORT)
        print("%s.png" % cid)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else SRC))
