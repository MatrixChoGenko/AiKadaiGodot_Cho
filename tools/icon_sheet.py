# AI で作ったアイコンのシート（純マゼンタ #FF00FF の背景に格子状に並べたもの）を 1 個ずつの透明 PNG に切り出す。
# 使い方: python -I tools/icon_sheet.py <シート名> [画像]
#   シート名 = intents / status / potions / relics1 / relics2（並び順は SHEETS。ItemList.md のプロンプトの順）。
#   画像を渡すと assets/textures/icons/_source/<シート名>.jpg に写してから切り出す（次からは画像なしで作り直せる）。
#   出力 = assets/textures/icons/<種類>/<id>.png（要 Pillow。numpy は使わない）。
# 背景の抜き方:
#   マゼンタらしさ d = min(R, B) - G。外周から d が LO を超える画素をたどった範囲（= 背景とそれに混ざった光のにじみ）と、
#   その外にある「純マゼンタを含む穴」（念珠の輪の内側など）を背景とみなし、そこだけ alpha = 1 - (d の LO〜HI の割合)。
#   黒い縁取りの内側は d が高くても（紫の球など）たどり着かないので消えない。
#   半透明の画素はマゼンタを混ぜ戻した色から取り除く（にじみがピンクに残らない）。
#   FILL_HOLES の id は穴を抜かずにマゼンタを指定の色へ置き換える（提灯のガラス越しの背景 → 灯りの色）。
import os
import shutil
import sys

from PIL import Image, ImageChops, ImageFilter, ImageMath

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ICONS = os.path.join(ROOT, "assets", "textures", "icons")
SOURCE = os.path.join(ICONS, "_source")

# シート名: (列, 行, id の並び, 出力フォルダ, 出力の大きさ, 余白の割合)
SHEETS = {
    "intents": (4, 2, ["attack", "defend", "attack_debuff", "buff", "debuff", "special", "sleep", "unknown"],
                "intent", 128, 0.03),
    "status": (5, 2, ["poison", "vulnerable", "weak", "strength", "artifact",
                      "barricade", "demon_form", "regenerate", "revive", "thorns"], "status", 96, 0.03),
    "potions": (5, 2, ["block", "cleanse", "draw", "energy", "fire",
                       "fracture", "healing", "poison", "strength", "weak"], "potion", 128, 0.05),
    "relics1": (4, 2, ["anchor", "artifact_totem", "bag_of_preparation", "black_star",
                       "blood_vial", "bronze_scales", "burning_blood", "echo_charm"], "relic", 128, 0.05),
    "relics2": (4, 2, ["lantern", "lizard_tail", "meditation_beads", "pen_nib",
                       "philosophers_stone", "recycler", "toolbox", "vajra"], "relic", 128, 0.05),
}

# 穴を抜かずに塗る id → (色, 穴の種を探す範囲 = セルの中の割合 (x0, y0, x1, y1))。
FILL_HOLES = {
    "lantern": ((255, 196, 92), (0.3, 0.35, 0.7, 0.8)),
}

WORK_SCALE = 0.5  # 2752 px のシートを半分にしてから処理する（出力は 128 px なので十分）
LO = 30  # d がこれ以下 = 不透明
STRONG = 200  # 穴とみなす純マゼンタの d


def _ramp(img, lo, hi):
    return img.point(lambda v: 0 if v <= lo else 255 if v >= hi else int((v - lo) * 255 / (hi - lo)))


def _threshold(img, t):
    return img.point(lambda v: 255 if v > t else 0)


def _reconstruct(seed, mask):
    """seed から mask の中だけを広げた範囲（形態学的再構成）。どちらも 0/255 の L 画像。"""
    cur = ImageChops.darker(seed, mask)
    while True:
        nxt = cur
        for _ in range(16):
            nxt = ImageChops.darker(nxt.filter(ImageFilter.MaxFilter(3)), mask)
        if nxt.tobytes() == cur.tobytes():
            return cur
        cur = nxt


def _border(size):
    seed = Image.new("L", size, 0)
    w, h = size
    seed.paste(255, (0, 0, w, 1))
    seed.paste(255, (0, h - 1, w, h))
    seed.paste(255, (0, 0, 1, h))
    seed.paste(255, (w - 1, 0, w, h))
    return seed


def key_cell(cell, key, fill=None):
    """セル（RGB）→ 背景を抜いた RGBA。"""
    r, g, b = cell.split()
    d = ImageChops.subtract(ImageChops.darker(r, b), g)
    key_d = min(key[0], key[2]) - key[1]
    hi = max(LO + 20, key_d - 12)
    m = _threshold(d, LO)
    outside = _reconstruct(_border(cell.size), m)
    rest = ImageChops.subtract(m, outside)
    strong = ImageChops.darker(_threshold(d, STRONG), rest)
    holes = Image.new("L", cell.size, 0)
    fill_region = Image.new("L", cell.size, 0)
    if strong.getbbox():
        found = _reconstruct(strong, rest)
        if fill is None:
            holes = found
        else:
            w, h = cell.size
            fx0, fy0, fx1, fy1 = fill[1]
            area = Image.new("L", cell.size, 0)
            area.paste(255, (int(w * fx0), int(h * fy0), int(w * fx1), int(h * fy1)))
            fill_region = _reconstruct(ImageChops.darker(strong, area), rest)
            holes = ImageChops.subtract(found, fill_region)
    region = ImageChops.lighter(outside, holes)
    amount = _ramp(d, LO, hi)
    alpha = ImageChops.invert(ImageChops.multiply(amount, region))
    # マゼンタを取り除く：F = (P - (1 - a) K) / a
    chans = []
    for c, k in zip((r, g, b), key):
        f = ImageMath.lambda_eval(
            lambda a: a["max"](a["min"]((a["p"] * 255.0 - (255.0 - a["al"]) * k) / a["max"](a["al"], 1.0), 255.0), 0.0),
            p=c.convert("F"), al=alpha.convert("F"))
        chans.append(f.convert("L"))
    if fill is not None and fill_region.getbbox():
        # 穴の中はマゼンタの分を灯りの色に置き換える：P' = P + t (W - K)
        t = ImageChops.multiply(amount, fill_region)
        for i, (c, k, wv) in enumerate(zip((r, g, b), key, fill[0])):
            f = ImageMath.lambda_eval(
                lambda a: a["max"](a["min"](a["p"] + a["t"] / 255.0 * (wv - k), 255.0), 0.0), p=c.convert("F"), t=t.convert("F"))
            chans[i] = Image.composite(f.convert("L"), chans[i], fill_region)
    return Image.merge("RGBA", (*chans, alpha))


def fit_square(rgba, margin):
    """不透明な部分（alpha > 128）を中心に、余白付きの正方形へ切り出す（光のにじみは余白に入る分だけ残る）。"""
    core = _threshold(rgba.getchannel("A"), 128).getbbox()
    if core is None:
        raise ValueError("empty cell")
    x0, y0, x1, y1 = core
    side = max(x1 - x0, y1 - y0) / (1.0 - 2.0 * margin)
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    box = (int(round(cx - side / 2)), int(round(cy - side / 2)))
    n = int(round(side))
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(rgba, (-box[0], -box[1]))
    return out


def shrink(rgba, size):
    return rgba.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")


def compose_attack_defend(attack, defend):
    """攻撃 ＋ 防御：短剣の右下に盾を小さく重ねる（StS の攻撃＋ブロックの意図と同じ考え方）。"""
    n = attack.size[0]
    out = attack.copy()
    s = int(n * 0.52)
    shield = defend.resize((s, s), Image.LANCZOS)
    out.alpha_composite(shield, (n - s, n - s))
    return out


def run(name, src):
    cols, rows, ids, folder, size, margin = SHEETS[name]
    os.makedirs(SOURCE, exist_ok=True)
    keep = os.path.join(SOURCE, name + ".jpg")
    if src is not None and os.path.abspath(src) != os.path.abspath(keep):
        shutil.copyfile(src, keep)
    sheet = Image.open(keep).convert("RGB")
    sheet = sheet.resize((int(sheet.width * WORK_SCALE), int(sheet.height * WORK_SCALE)), Image.LANCZOS)
    # 背景の色 = 四隅の平均
    corners = [sheet.getpixel(p) for p in ((2, 2), (sheet.width - 3, 2), (2, sheet.height - 3), (sheet.width - 3, sheet.height - 3))]
    key = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    out_dir = os.path.join(ICONS, folder)
    os.makedirs(out_dir, exist_ok=True)
    cw, ch = sheet.width / cols, sheet.height / rows
    squares = {}
    for i, icon_id in enumerate(ids):
        cx, cy = i % cols, i // cols
        cell = sheet.crop((int(cx * cw), int(cy * ch), int((cx + 1) * cw), int((cy + 1) * ch)))
        rgba = key_cell(cell, key, FILL_HOLES.get(icon_id))
        squares[icon_id] = fit_square(rgba, margin)
    if name == "intents":
        squares["attack_defend"] = compose_attack_defend(squares["attack"], squares["defend"])
    for icon_id, sq in squares.items():
        shrink(sq, size).save(os.path.join(out_dir, icon_id + ".png"))
    print("%s: key=%s -> %d icons in %s" % (name, key, len(squares), os.path.relpath(out_dir, ROOT)))


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in SHEETS:
        print("usage: python -I tools/icon_sheet.py <%s> [image]" % "|".join(SHEETS))
        sys.exit(1)
    run(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)


if __name__ == "__main__":
    main()
