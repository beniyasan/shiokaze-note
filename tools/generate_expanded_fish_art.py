"""Generate the expanded Tidebound field-guide fish art.

The first six illustrated cards landed in PR #9.  This companion generator keeps
the 17 remaining fish entries in the same transparent, polygon-painted style:
each species gets a large ``*_v2.png`` card source plus a 96x64 portrait used by
the catch reveal.  It also refreshes two existing non-standard catalog entries
(the Old boot junk catch and Aurora koi's hidden legendary reward) so every
catalog row has art without counting either as one of the 17 fish.  All geometry
is local and deterministic, so rerunning the tool never changes a committed
asset or pulls in an external image dependency.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
import math

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CARD_DIR = ROOT / "assets" / "fish_cards"
PORTRAIT_DIR = ROOT / "assets" / "fish"
CARD_DIR.mkdir(parents=True, exist_ok=True)
PORTRAIT_DIR.mkdir(parents=True, exist_ok=True)

SCALE = 3
W, H = 768, 512
INK = (18, 31, 48, 255)
INK_SOFT = (31, 52, 68, 235)
FOAM = (235, 242, 224, 230)

@dataclass(frozen=True)
class FishStyle:
    base: tuple[int, int, int]
    light: tuple[int, int, int]
    dark: tuple[int, int, int]
    fin: tuple[int, int, int]
    accent: tuple[int, int, int]
    kind: str = "fish"
    pattern: str = "stripe"
    scale: float = 1.0

# Species intentionally use names from FISH_SPECIES.  Old boot is kept as a
# collectible card too: it is a playful non-fish catch and should not regress
# to the old blank square fallback.
STYLES: dict[str, FishStyle] = {
    "old_boot": FishStyle((112, 83, 61), (184, 141, 89), (62, 51, 45), (79, 67, 55), (207, 173, 107), "boot", "stitch"),
    "amber_anchovy": FishStyle((199, 139, 63), (239, 191, 91), (127, 75, 54), (64, 148, 142), (247, 214, 137), pattern="dots", scale=.85),
    "dune_flounder": FishStyle((176, 132, 92), (222, 184, 130), (104, 77, 68), (92, 139, 124), (227, 198, 134), pattern="spots", scale=1.08),
    "tidepool_blenny": FishStyle((70, 151, 133), (133, 202, 166), (34, 79, 88), (222, 159, 91), (244, 198, 106), pattern="bars", scale=.92),
    "glass_shrimp": FishStyle((156, 215, 198), (225, 248, 223), (59, 125, 137), (238, 151, 119), (250, 224, 160), kind="shrimp", pattern="segments", scale=.8),
    "copper_mackerel": FishStyle((113, 155, 173), (201, 218, 206), (35, 67, 86), (201, 112, 67), (227, 167, 82), pattern="bars", scale=1.03),
    "saltwater_eel": FishStyle((61, 130, 125), (132, 195, 161), (28, 59, 70), (205, 150, 80), (235, 196, 103), kind="eel", pattern="rings", scale=1.10),
    "lantern_squid": FishStyle((112, 99, 175), (191, 171, 224), (49, 45, 99), (239, 178, 93), (255, 222, 126), kind="squid", pattern="glow", scale=.90),
    "blackglass_bass": FishStyle((50, 78, 98), (111, 151, 163), (18, 29, 54), (100, 191, 180), (228, 191, 93), pattern="glass", scale=1.08),
    "storm_sardine": FishStyle((74, 115, 154), (163, 195, 212), (33, 52, 87), (107, 157, 212), (232, 218, 132), pattern="bolt", scale=.94),
    "gullfin": FishStyle((174, 194, 190), (239, 240, 217), (82, 102, 115), (174, 139, 203), (247, 206, 106), pattern="wing", scale=1.0),
    "lighthouse_ray": FishStyle((71, 111, 125), (155, 202, 190), (30, 57, 79), (231, 172, 94), (251, 220, 129), kind="ray", pattern="beam", scale=1.05),
    "tidemark_carp": FishStyle((163, 102, 73), (231, 167, 96), (81, 47, 56), (95, 158, 144), (251, 222, 135), pattern="scales", scale=1.05),
    "sea_lavender_perch": FishStyle((111, 89, 158), (192, 157, 201), (49, 43, 89), (80, 171, 163), (237, 186, 230), pattern="lavender", scale=1.0),
    "pearl_puffer": FishStyle((185, 153, 105), (245, 219, 158), (96, 70, 65), (87, 160, 151), (255, 239, 180), kind="puffer", pattern="pearl", scale=.88),
    "night_sailfish": FishStyle((36, 67, 112), (100, 153, 196), (18, 32, 69), (190, 111, 164), (232, 200, 106), kind="sailfish", pattern="sail", scale=1.04),
    "crown_snapper": FishStyle((189, 92, 74), (241, 153, 93), (81, 41, 58), (219, 191, 86), (255, 228, 132), pattern="crown", scale=1.08),
    "singing_herring": FishStyle((132, 177, 193), (232, 239, 218), (43, 72, 98), (135, 120, 194), (240, 210, 111), pattern="wave", scale=1.0),
    "aurora_koi": FishStyle((64, 123, 137), (217, 178, 107), (27, 46, 84), (119, 177, 220), (239, 127, 150), pattern="aurora", scale=1.1),
}

EXPANDED_FISH_STEMS = (
    "amber_anchovy", "dune_flounder", "tidepool_blenny", "glass_shrimp",
    "copper_mackerel", "saltwater_eel", "lantern_squid", "blackglass_bass",
    "storm_sardine", "gullfin", "lighthouse_ray", "tidemark_carp",
    "sea_lavender_perch", "pearl_puffer", "night_sailfish", "crown_snapper",
    "singing_herring",
)
SUPPORT_STEMS = ("old_boot", "aurora_koi")


def rgba(color, alpha=255):
    return (*color, alpha)


def pts(values: Iterable[tuple[float, float]]):
    return [(round(x * SCALE), round(y * SCALE)) for x, y in values]


def draw_poly(draw: ImageDraw.ImageDraw, values, fill, outline=INK, width=2):
    p = pts(values)
    draw.polygon(p, fill=rgba(fill) if len(fill) == 3 else fill)
    if outline:
        draw.line(p + [p[0]], fill=outline, width=width * SCALE, joint="curve")


def draw_line(draw, values, fill, width=2):
    draw.line(pts(values), fill=rgba(fill) if len(fill) == 3 else fill, width=width * SCALE, joint="curve")


def draw_fish(style: FishStyle) -> Image.Image:
    im = Image.new("RGBA", (W * SCALE, H * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = 384, 269
    s = style.scale * SCALE
    # ground shadow and two restrained water glints match the original cards
    d.ellipse((int((cx - 300 * s / SCALE) * SCALE), 397 * SCALE,
               int((cx + 300 * s / SCALE) * SCALE), 439 * SCALE), fill=(18, 42, 56, 70))
    draw_line(d, [(162, 434), (604, 434)], (70, 137, 145, 160), 2)
    draw_line(d, [(267, 449), (501, 449)], (126, 194, 171, 120), 1)
    if style.kind == "boot":
        draw_boot(d, style, s)
    elif style.kind == "shrimp":
        draw_shrimp(d, style, s)
    elif style.kind == "squid":
        draw_squid(d, style, s)
    elif style.kind == "ray":
        draw_ray(d, style, s)
    elif style.kind == "puffer":
        draw_puffer(d, style, s)
    elif style.kind == "sailfish":
        draw_sailfish(d, style, s)
    elif style.kind == "eel":
        draw_eel(d, style, s)
    else:
        draw_standard_fish(d, style, s)
    # High-resolution drawing gives the same softened polygon edges as the
    # source illustrations while retaining crisp internal linework.
    return im.resize((W, H), Image.Resampling.LANCZOS)


def fish_body(style, s):
    # body coordinates in source pixel units, then scaled by SCALE and species size
    return [((cx) * s / SCALE + 0) for cx in []]


def draw_standard_fish(d, style, s):
    # Broad, slightly asymmetrical body; head is at the right like the original
    # six cards. Tail and fins use three-point polygons so every silhouette is
    # recognisable at ledger scale.
    def q(x, y): return (384 + x * style.scale, 266 + y * style.scale)
    body = [q(-272, 12), q(-214, -77), q(-40, -98), q(138, -76), q(261, -20), q(286, 16), q(238, 58), q(70, 95), q(-135, 80), q(-246, 57)]
    body = [(x * SCALE, y * SCALE) for x, y in body]
    d.polygon(body, fill=rgba(style.base)); d.line(body + [body[0]], fill=INK, width=5 * SCALE, joint="curve")
    tail = [(384 + x * style.scale, 266 + y * style.scale) for x, y in [(-222, 12), (-345, -86), (-320, 19), (-348, 107)]]
    tail = [(x * SCALE, y * SCALE) for x, y in tail]
    d.polygon(tail, fill=rgba(style.dark)); d.line(tail + [tail[0]], fill=INK, width=5 * SCALE, joint="curve")
    # dorsal and belly fins
    draw_poly(d, [q(-70, -68), q(-28, -172), q(22, -80)], style.fin)
    draw_poly(d, [q(-28, 78), q(40, 176), q(90, 72)], style.dark)
    draw_poly(d, [q(106, -64), q(218, -153), q(208, -33)], style.light)
    draw_poly(d, [q(-8, 36), q(38, 142), q(104, 47)], style.light)
    # scale / stripe pattern, clipped approximately by staying inside body bounds
    for i in range(6):
        x = -168 + i * 53
        if style.pattern in ("stripe", "bars", "lavender", "glass", "wave"):
            draw_line(d, [q(x, -70), q(x + 25, 69)], style.accent, 8)
        elif style.pattern == "rings":
            d.ellipse((int((384 + (x - 7) * style.scale) * SCALE), int((266 - 12 * style.scale) * SCALE), int((384 + (x + 23) * style.scale) * SCALE), int((266 + 35 * style.scale) * SCALE)), outline=rgba(style.accent, 185), width=3 * SCALE)
        elif style.pattern == "dots":
            d.ellipse((int((384 + x * style.scale) * SCALE), int((266 - 20 * style.scale) * SCALE), int((384 + (x + 19) * style.scale) * SCALE), int((266 + 0 * style.scale) * SCALE)), fill=rgba(style.accent, 225))
        elif style.pattern == "spots":
            d.ellipse((int((384 + x * style.scale) * SCALE), int((266 - 8 * style.scale) * SCALE), int((384 + (x + 20) * style.scale) * SCALE), int((266 + 13 * style.scale) * SCALE)), fill=rgba(style.accent, 220))
        elif style.pattern == "scales":
            draw_line(d, [q(x, -40), q(x + 15, 5), q(x, 42)], style.accent, 4)
            draw_line(d, [q(x + 16, -38), q(x + 31, 7), q(x + 15, 42)], style.light, 3)
        elif style.pattern == "bolt":
            draw_poly(d, [q(x, -55), q(x + 17, -8), q(x + 1, -1), q(x + 24, 59)], style.accent, None, 0)
        elif style.pattern == "wing":
            draw_line(d, [q(x, -56), q(x + 45, 53)], style.accent, 5)
        elif style.pattern == "crown":
            draw_line(d, [q(x, -56), q(x + 20, 55)], style.accent, 7)
        elif style.pattern == "wave":
            draw_line(d, [q(x, -16), q(x + 28, -37), q(x + 52, -12), q(x + 78, -33)], style.accent, 4)
        elif style.pattern == "aurora":
            draw_line(d, [q(x, -67), q(x + 31, 52)], style.accent, 12)
    # lateral highlight and mouth / eye
    draw_line(d, [q(-193, 18), q(201, 12)], style.light, 8)
    draw_line(d, [q(215, 21), q(268, 9)], style.accent, 4)
    ex, ey = q(193, -31)
    d.ellipse((int((ex - 22) * SCALE), int((ey - 22) * SCALE), int((ex + 22) * SCALE), int((ey + 22) * SCALE)), fill=INK)
    d.ellipse((int((ex - 14) * SCALE), int((ey - 14) * SCALE), int((ex + 14) * SCALE), int((ey + 14) * SCALE)), fill=rgba(style.accent))
    d.ellipse((int((ex - 6) * SCALE), int((ey - 10) * SCALE), int((ex + 4) * SCALE), int((ey) * SCALE)), fill=FOAM)
    draw_line(d, [q(250, 20), q(281, 29), q(255, 40)], style.dark, 4)


def draw_boot(d, style, s):
    # A readable old boot keeps the playful junk-catch card from looking empty.
    p = [(262, 118), (398, 118), (423, 236), (536, 278), (596, 343), (577, 396), (292, 396), (251, 344), (272, 259)]
    d.polygon(pts(p), fill=rgba(style.base)); d.line(pts(p + [p[0]]), fill=INK, width=6 * SCALE, joint="curve")
    draw_poly(d, [(281, 123), (407, 123), (412, 248), (319, 245)], style.light)
    draw_poly(d, [(413, 245), (541, 282), (589, 340), (577, 393), (309, 390), (289, 345)], style.dark)
    draw_line(d, [(294, 178), (403, 178)], style.accent, 8)
    for y in (212, 246, 280): draw_line(d, [(301, y), (409, y)], style.accent, 4)
    draw_poly(d, [(481, 305), (547, 318), (570, 353), (495, 350)], style.light)
    d.ellipse((330 * SCALE, 423 * SCALE, 435 * SCALE, 442 * SCALE), fill=(18, 42, 56, 60))


def draw_shrimp(d, style, s):
    def q(x, y): return (384 + x * style.scale, 268 + y * style.scale)
    for i in range(5):
        x = -184 + i * 71
        d.ellipse((int((q(x, -50)[0]) * SCALE), int((q(x, -42)[1]) * SCALE), int((q(x + 106, 46)[0]) * SCALE), int((q(x + 106, 46)[1]) * SCALE)), fill=rgba(style.base), outline=INK, width=4 * SCALE)
    draw_poly(d, [q(-282, 6), q(-353, -72), q(-319, 13), q(-353, 87)], style.fin)
    draw_poly(d, [q(177, -42), q(241, -136), q(263, -36)], style.accent)
    draw_line(d, [q(210, -22), q(337, -96)], style.light, 3)
    draw_line(d, [q(210, -5), q(347, -27)], style.light, 3)
    ex, ey = q(236, -33); d.ellipse((int((ex - 17) * SCALE), int((ey - 17) * SCALE), int((ex + 17) * SCALE), int((ey + 17) * SCALE)), fill=INK); d.ellipse((int((ex - 5) * SCALE), int((ey - 10) * SCALE), int((ex + 5) * SCALE), int((ey) * SCALE)), fill=FOAM)
    for i in range(4): draw_line(d, [q(-150 + i * 75, 54), q(-172 + i * 75, 117)], style.fin, 4)


def draw_squid(d, style, s):
    def q(x, y): return (384 + x * style.scale, 242 + y * style.scale)
    draw_poly(d, [q(-192, 44), q(-171, -96), q(-61, -174), q(89, -153), q(197, -58), q(154, 65), q(-15, 98)], style.base)
    draw_poly(d, [q(-157, -80), q(-45, -189), q(58, -163), q(129, -93), q(-3, -114)], style.light)
    for i in range(6):
        x = -154 + i * 61
        draw_line(d, [q(x, 30), q(x - 22, 175 - i * 5), q(x + 17, 210 - i * 8)], style.fin if i % 2 else style.dark, 8)
    for x in (-70, 2, 74):
        ex, ey = q(x, -10); d.ellipse((int((ex - 18) * SCALE), int((ey - 18) * SCALE), int((ex + 18) * SCALE), int((ey + 18) * SCALE)), fill=rgba(style.accent)); d.ellipse((int((ex - 5) * SCALE), int((ey - 7) * SCALE), int((ex + 5) * SCALE), int((ey + 3) * SCALE)), fill=FOAM)


def draw_ray(d, style, s):
    def q(x, y): return (384 + x * style.scale, 289 + y * style.scale)
    draw_poly(d, [q(-352, 35), q(-190, -63), q(-56, -169), q(96, -140), q(248, -49), q(362, 18), q(248, 79), q(75, 103), q(-106, 95), q(-274, 69)], style.base)
    draw_poly(d, [q(-21, -139), q(11, -271), q(76, -145)], style.fin)
    draw_poly(d, [q(230, -47), q(347, -120), q(312, 10)], style.light)
    draw_line(d, [q(-238, 29), q(293, 27)], style.light, 8)
    ex, ey = q(224, -26); d.ellipse((int((ex - 20) * SCALE), int((ey - 20) * SCALE), int((ex + 20) * SCALE), int((ey + 20) * SCALE)), fill=INK); d.ellipse((int((ex - 5) * SCALE), int((ey - 8) * SCALE), int((ex + 5) * SCALE), int(ey * SCALE)), fill=FOAM)
    draw_poly(d, [q(-354, 35), q(-445, 13), q(-408, 68)], style.accent)


def draw_puffer(d, style, s):
    def q(x, y): return (384 + x * style.scale, 264 + y * style.scale)
    # radial spines behind a compact round body
    for i in range(16):
        a = math.tau * i / 16
        p1 = q(math.cos(a) * 130, math.sin(a) * 130)
        p2 = q(math.cos(a) * 205, math.sin(a) * 205)
        draw_line(d, [p1, p2], style.fin if i % 2 else style.accent, 5)
    d.ellipse((int((q(-150, -150)[0]) * SCALE), int((q(-150, -150)[1]) * SCALE), int((q(150, 150)[0]) * SCALE), int((q(150, 150)[1]) * SCALE)), fill=rgba(style.base), outline=INK, width=6 * SCALE)
    for x, y in [(-83,-57),(-22,-92),(43,-56),(87,-4),(47,54),(-32,76),(-92,40)]:
        ex, ey = q(x, y); d.ellipse((int((ex - 16) * SCALE), int((ey - 16) * SCALE), int((ex + 16) * SCALE), int((ey + 16) * SCALE)), fill=rgba(style.light), outline=INK, width=2 * SCALE)
    ex, ey = q(82,-32); d.ellipse((int((ex - 20) * SCALE), int((ey - 20) * SCALE), int((ex + 20) * SCALE), int((ey + 20) * SCALE)), fill=INK); d.ellipse((int((ex - 6) * SCALE), int((ey - 10) * SCALE), int((ex + 5) * SCALE), int((ey + 1) * SCALE)), fill=FOAM)
    draw_line(d, [q(103, 19), q(132, 28), q(104, 37)], style.dark, 5)


def draw_sailfish(d, style, s):
    def q(x, y): return (384 + x * style.scale, 260 + y * style.scale)
    draw_poly(d, [q(-280, 14), q(-176, -58), q(34, -76), q(224, -45), q(293, 8), q(232, 44), q(34, 68), q(-162, 57)], style.base)
    draw_poly(d, [q(-212, 15), q(-350, -65), q(-327, 12), q(-350, 91)], style.dark)
    draw_poly(d, [q(-56, -62), q(-40, -249), q(-2, -114), q(37, -263), q(52, -46), q(94, -229), q(108, -34)], style.fin)
    draw_poly(d, [q(220, -42), q(419, -17), q(230, 9)], style.light)
    draw_line(d, [q(-150, 5), q(248, 4)], style.accent, 5)
    ex, ey = q(232,-29); d.ellipse((int((ex - 18) * SCALE), int((ey - 18) * SCALE), int((ex + 18) * SCALE), int((ey + 18) * SCALE)), fill=INK); d.ellipse((int((ex - 5) * SCALE), int((ey - 8) * SCALE), int((ex + 5) * SCALE), int((ey + 2) * SCALE)), fill=FOAM)
    draw_poly(d, [q(240, -12), q(495, -31), q(246, 18)], style.accent)


def draw_eel(d, style, s):
    def q(x, y): return (384 + x * style.scale, 264 + y * style.scale)
    body = [q(-347, 20), q(-279, -44), q(-170, -65), q(-30, -45), q(120, -16), q(282, -35), q(353, 10), q(277, 58), q(111, 35), q(-35, 65), q(-190, 73), q(-310, 58)]
    draw_poly(d, body, style.base)
    draw_poly(d, [q(280,-31), q(424,-103), q(387,18), q(426,93), q(286,52)], style.fin)
    for x in range(-255, 260, 57): draw_line(d, [q(x, -45), q(x+10, 57)], style.accent, 7)
    ex, ey = q(339,-22); d.ellipse((int((ex - 19) * SCALE), int((ey - 19) * SCALE), int((ex + 19) * SCALE), int((ey + 19) * SCALE)), fill=INK); d.ellipse((int((ex - 5) * SCALE), int((ey - 8) * SCALE), int((ex + 5) * SCALE), int((ey + 2) * SCALE)), fill=FOAM)
    draw_line(d, [q(342, 13), q(378, 20), q(342, 31)], style.dark, 4)


def save_style(stem: str, style: FishStyle):
    card = draw_fish(style)
    card.save(CARD_DIR / f"{stem}_v2.png", optimize=True)
    portrait = card.resize((96, 64), Image.Resampling.LANCZOS)
    portrait.save(PORTRAIT_DIR / f"{stem}.png", optimize=True)


def main():
    expected = set(EXPANDED_FISH_STEMS) | set(SUPPORT_STEMS)
    if set(STYLES) != expected:
        raise SystemExit(f"style manifest drift: expected {len(expected)} stems, got {len(STYLES)}")
    for stem, style in STYLES.items():
        save_style(stem, style)
    print(f"generated {len(EXPANDED_FISH_STEMS)} expanded fish styles plus {len(SUPPORT_STEMS)} catalog support styles")

if __name__ == "__main__":
    main()
