# エフェクト用のトゥーン調テクスチャ（白 + アルファ）を作る。色はパーティクルの color_ramp（頂点カラー）で付ける。
# 使い方: python -I tools/fx_textures.py  → assets/textures/fx/*.png を上書きする（要 Pillow）。
# 形を変えたいときはここを直して作り直す（エディタで開いたまま上書きしても Godot が再インポートする）。
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures", "fx")
SS = 4  # 縁を滑らかにするため 4 倍で描いて縮小する


def canvas(w, h):
    return Image.new("L", (w * SS, h * SS), 0)


def save(name, alpha, value=None):
    w, h = alpha.size[0] // SS, alpha.size[1] // SS
    a = alpha.resize((w, h), Image.LANCZOS)
    v = value.resize((w, h), Image.LANCZOS) if value is not None else Image.new("L", (w, h), 255)
    Image.merge("RGBA", (v, v, v, a)).save(os.path.join(OUT, name))
    print(name, w, h)


def star(cx, cy, radii, n, rot=0.0):
    pts = []
    for i in range(n * 2):
        ang = rot + math.pi * i / n
        r = radii[i % len(radii)]
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    return pts


def burst():
    # 衝撃の「バシッ」：トゲの長さが不ぞろいな 8 本の星。
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    c = s / 2
    outer = [1.0, 0.78, 0.95, 0.7, 1.0, 0.82, 0.9, 0.74]
    pts = []
    for i in range(16):
        ang = -math.pi / 2 + math.pi * i / 8
        r = (outer[i // 2] if i % 2 == 0 else 0.42) * c * 0.96
        pts.append((c + r * math.cos(ang), c + r * math.sin(ang)))
    d.polygon(pts, fill=255)
    save("fx_burst.png", img)


def shard():
    # 飛び散る破片：進行方向（テクスチャの上 = +Y）が太く、後ろへ細く伸びる菱形。
    w, h = 64 * SS, 256 * SS
    img = canvas(64, 256)
    ImageDraw.Draw(img).polygon([(w / 2, 0), (w * 0.95, h * 0.22), (w / 2, h), (w * 0.05, h * 0.22)], fill=255)
    save("fx_shard.png", img)


def ring():
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    m = s * 0.03
    d.ellipse([m, m, s - m, s - m], fill=255)
    m2 = s * 0.1
    d.ellipse([m2, m2, s - m2, s - m2], fill=0)
    save("fx_ring.png", img)


def puff():
    # トゥーンの煙：丸 + 右下に三日月形の影（2 段の陰影。色は乗算で付く）。
    s = 256 * SS
    a = canvas(256, 256)
    v = Image.new("L", (s, s), 165)
    m = s * 0.04
    ImageDraw.Draw(a).ellipse([m, m, s - m, s - m], fill=255)
    ImageDraw.Draw(v).ellipse([s * -0.02, s * -0.04, s * 0.86, s * 0.84], fill=255)
    save("fx_puff.png", a, v)


def sparkle():
    # キラッ：アステロイドを細くした形（x = cos^5, y = sin^5）。内側へ反った辺と尖った 4 本の先。
    s = 256 * SS
    img = canvas(256, 256)
    c = s / 2
    pts = []
    for i in range(720):
        t = 2 * math.pi * i / 720
        pts.append((c + c * 0.97 * math.copysign(abs(math.cos(t)) ** 5, math.cos(t)), c + c * 0.97 * math.copysign(abs(math.sin(t)) ** 5, math.sin(t))))
    ImageDraw.Draw(img).polygon(pts, fill=255)
    save("fx_sparkle.png", img)


def shield():
    # 盾の六角形：太い枠 + 薄い面。
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    c = s / 2
    hexagon = lambda r: [(c + r * math.cos(math.pi / 6 + math.pi * i / 3), c + r * math.sin(math.pi / 6 + math.pi * i / 3)) for i in range(6)]
    d.polygon(hexagon(c * 0.97), fill=255)
    d.polygon(hexagon(c * 0.8), fill=70)
    save("fx_shield.png", img)


def soft():
    # 柔らかい丸（光の下地。トゥーンの形の後ろに薄く敷く）。
    s = 256
    img = Image.new("L", (s, s), 0)
    px = img.load()
    for y in range(s):
        for x in range(s):
            r = math.hypot(x - s / 2 + 0.5, y - s / 2 + 0.5) / (s / 2)
            px[x, y] = int(255 * max(0.0, 1.0 - r) ** 2)
    img = img.resize((s * SS, s * SS))
    save("fx_soft.png", img)


def cross():
    # 回復の十字：角の丸い太い「＋」。
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    w, r = s * 0.17, s * 0.06
    d.rounded_rectangle([s / 2 - w, s * 0.06, s / 2 + w, s * 0.94], radius=r, fill=255)
    d.rounded_rectangle([s * 0.06, s / 2 - w, s * 0.94, s / 2 + w], radius=r, fill=255)
    save("fx_cross.png", img)


def bubble():
    # 泡：薄い面 + 枠 + 左上の小さなハイライト。
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    m = s * 0.04
    d.ellipse([m, m, s - m, s - m], fill=255)
    m2 = s * 0.14
    d.ellipse([m2, m2, s - m2, s - m2], fill=90)
    d.ellipse([s * 0.24, s * 0.22, s * 0.42, s * 0.4], fill=255)
    save("fx_bubble.png", img)


def drop():
    # しずく：上が尖り、下が丸い（テクスチャの上 = +Y。落ちる向きに合わせるなら下向きの速度で反転する）。
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    r = s * 0.3
    cx, cy = s / 2, s * 0.64
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    d.polygon([(cx, s * 0.04), (cx + r * 0.94, cy - r * 0.34), (cx - r * 0.94, cy - r * 0.34)], fill=255)
    save("fx_drop.png", img)


def teardrop(d, cx, cy, r, tx, ty):
    # (cx, cy) 半径 r の丸から (tx, ty) へ尖る形。
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    ang = math.atan2(ty - cy, tx - cx)
    side = ang + math.pi / 2
    p1 = (cx + r * math.cos(side), cy + r * math.sin(side))
    p2 = (cx - r * math.cos(side), cy - r * math.sin(side))
    d.polygon([p1, (tx, ty), p2], fill=255)


def flame():
    # トゥーンの炎：丸い根元から 3 本の舌（中央が一番高い）。
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    teardrop(d, s * 0.33, s * 0.68, s * 0.17, s * 0.12, s * 0.3)
    teardrop(d, s * 0.67, s * 0.68, s * 0.17, s * 0.88, s * 0.34)
    teardrop(d, s * 0.5, s * 0.66, s * 0.27, s * 0.52, s * 0.03)
    save("fx_flame.png", img)


def swirl():
    # 渦：中心から外へ広がる太い渦巻きの線。
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    c = s / 2
    for i in range(400):
        t = i / 400
        ang = t * math.pi * 3.2
        r = c * (0.12 + 0.8 * t)
        w = s * (0.025 + 0.05 * t)
        x, y = c + r * math.cos(ang), c + r * math.sin(ang)
        d.ellipse([x - w, y - w, x + w, y + w], fill=255)
    save("fx_swirl.png", img)


def arrow():
    # 下向きの矢印（弱体）。
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    d.rectangle([s * 0.36, s * 0.04, s * 0.64, s * 0.55], fill=255)
    d.polygon([(s * 0.08, s * 0.5), (s * 0.92, s * 0.5), (s * 0.5, s * 0.96)], fill=255)
    save("fx_arrow.png", img)


def crack():
    # ひび（脆弱）：中心から折れ線が 5 本。
    s = 256 * SS
    img = canvas(256, 256)
    d = ImageDraw.Draw(img)
    c = s / 2
    w = int(s * 0.075)
    for k, (a0, bend) in enumerate([(-90, 25), (-20, -30), (40, 20), (130, -25), (200, 30)]):
        p = (c, c)
        ang = math.radians(a0)
        for seg in range(3):
            ln = s * (0.17 - 0.03 * seg)
            ang += math.radians(bend if seg % 2 == 0 else -bend)
            q = (p[0] + ln * math.cos(ang), p[1] + ln * math.sin(ang))
            d.line([p, q], fill=255, width=max(2, w - seg * w // 4))
            p = q
    save("fx_crack.png", img)


def glass():
    # 割れた盾の破片：細長い三角形。
    s = 256 * SS
    img = canvas(256, 256)
    ImageDraw.Draw(img).polygon([(s * 0.5, s * 0.03), (s * 0.85, s * 0.9), (s * 0.18, s * 0.72)], fill=255)
    save("fx_glass.png", img)


def rock():
    # 土の塊：角ばった不規則な多角形 + 右下の影（色は乗算で付く）。
    s = 256 * SS
    a = canvas(256, 256)
    pts = [(0.5, 0.06), (0.86, 0.22), (0.95, 0.6), (0.7, 0.93), (0.28, 0.9), (0.06, 0.58), (0.18, 0.2)]
    ImageDraw.Draw(a).polygon([(x * s, y * s) for x, y in pts], fill=255)
    v = Image.new("L", (s, s), 150)
    ImageDraw.Draw(v).polygon([(x * s, y * s) for x, y in [(0.5, 0.06), (0.86, 0.22), (0.75, 0.55), (0.4, 0.66), (0.06, 0.58), (0.18, 0.2)]], fill=255)
    save("fx_rock.png", a, v)


def confetti():
    # 紙吹雪：横長の四角（回転と色は粒ごと）。
    s = 128 * SS
    img = canvas(128, 128)
    ImageDraw.Draw(img).rectangle([s * 0.08, s * 0.3, s * 0.92, s * 0.7], fill=255)
    save("fx_confetti.png", img)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in (burst, shard, ring, puff, sparkle, shield, soft, cross, bubble, drop, flame, swirl, arrow, crack, glass, rock, confetti):
        f()
    sys.exit(0)
