"""Import the approved 4x4 anime turnaround as a pixel-native 96x128 prototype.

The generated turnaround is a visual master, never copied into runtime. Each source
cell is independently thresholded, palette-quantized, and nearest-neighbour reduced
onto the 96x128 game grid. The output is deliberately local-only while the team
reviews style fidelity.
"""
from pathlib import Path
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artifacts"
ART.mkdir(exist_ok=True)
MASTER = Path(os.environ.get("STYLE_MASTER_PATH", "/workspace/scratch/292fc4632731/generated_images/exec-d986deb9-6cdc-4dc3-ad12-14ccc0c989bd.png"))
ATLAS = ART / "hero-fisherman-96x128-style-master-atlas.png"
PREVIEW = ART / "hero-fisherman-96x128-style-master-preview.png"
COMPARISON = ART / "hero-style-master-96x128-comparison.png"
CHECKS = ART / "hero-style-master-96x128-checks.txt"
NOTES = ART / "hero-style-master-96x128-notes.md"

# Keep the palette compact enough to read as deliberate pixel clusters, while
# retaining the navy/teal/cream/ochre/red-orange cues from the visual master.
PALETTE_SIZE = 56
ALPHA_CUTOFF = 96
CELL_W, CELL_H = 96, 128
ROWS = COLS = 4

def font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def clean_master(im):
    """Binary alpha + median-cut palette removes soft generation fringe."""
    im = im.convert("RGBA")
    px = []
    for r, g, b, a in im.getdata():
        if a < ALPHA_CUTOFF:
            px.append((0, 0, 0, 0))
        else:
            px.append((r, g, b, 255))
    out = Image.new("RGBA", im.size)
    out.putdata(px)
    # Quantize RGB only where alpha is opaque, preserving transparent pixels.
    rgb = Image.new("RGB", im.size, (0, 0, 0))
    rgb.paste(out.convert("RGB"), mask=out.getchannel("A"))
    q = rgb.quantize(colors=PALETTE_SIZE, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out_rgb = Image.new("RGBA", im.size)
    out_rgb.putdata([(r, g, b, a) for (r, g, b), (_, _, _, a) in zip(q.getdata(), out.getdata())])
    return out_rgb

def tile_source(clean, row, col):
    w, h = clean.size
    box = (round(col * w / COLS), round(row * h / ROWS), round((col + 1) * w / COLS), round((row + 1) * h / ROWS))
    return clean.crop(box)

def native_tile(clean, row, col):
    """Reduce a source cell to native pixels and align feet at y=126."""
    src = tile_source(clean, row, col)
    tile = src.resize((CELL_W, CELL_H), Image.Resampling.NEAREST)
    # Source rows have slightly different vertical gutters. Re-anchor the visible
    # foot/shoe cluster so every facing lands on local y=126 for the runtime.
    alpha = tile.getchannel("A")
    bbox = alpha.getbbox()
    if bbox:
        desired_bottom = 126
        shift = desired_bottom - (bbox[3] - 1)
        # Never clip the cap; if a source cell needs more room, keep its top row.
        shift = max(shift, -bbox[1])
        if shift:
            moved = Image.new("RGBA", tile.size, (0, 0, 0, 0))
            moved.alpha_composite(tile, (0, shift))
            tile = moved
    return tile

def build_atlas():
    if not MASTER.exists():
        raise FileNotFoundError(f"style master missing: {MASTER}")
    clean = clean_master(Image.open(MASTER))
    atlas = Image.new("RGBA", (COLS * CELL_W, ROWS * CELL_H), (0, 0, 0, 0))
    for row in range(ROWS):
        for col in range(COLS):
            atlas.alpha_composite(native_tile(clean, row, col), (col * CELL_W, row * CELL_H))
    return atlas, clean

def save_preview(atlas):
    PREVIEW.parent.mkdir(exist_ok=True)
    preview = atlas.resize((atlas.width * 4, atlas.height * 4), Image.Resampling.NEAREST)
    preview.save(PREVIEW)

def comparison(atlas):
    # Full turnaround source plus old 96x128 native trace and this style import.
    master = Image.open(MASTER).convert("RGBA")
    old = Image.open(ART / "hero-fisherman-96x128-master-trace-atlas.png").convert("RGBA")
    cards = [("New 4x4 style master · visual guide", master), ("Existing 96×128 trace", old), ("Style-cleaned native 96×128", atlas)]
    board = Image.new("RGBA", (1840, 900), (11, 23, 32, 255))
    d = ImageDraw.Draw(board)
    d.text((26, 20), "96×128 style-master prototype · deterministic palette + hard alpha", font=font(28), fill=(248, 229, 176, 255))
    d.text((26, 58), "Generated turnaround is guide only; each cell is thresholded, quantized and nearest-reduced.", font=font(16), fill=(173, 197, 194, 255))
    x = 24
    for title, im in cards:
        card_w, card_h = 570, 760
        d.rounded_rectangle((x, 98, x + card_w, 858), radius=12, fill=(20, 36, 44, 255), outline=(75, 105, 110, 255), width=2)
        d.text((x + 14, 112), title, font=font(19), fill=(240, 220, 165, 255))
        max_w, max_h = card_w - 28, 680
        fit = min(max_w / im.width, max_h / im.height)
        scaled = im.resize((max(1, int(im.width * fit)), max(1, int(im.height * fit))), Image.Resampling.NEAREST)
        board.alpha_composite(scaled, (x + (card_w - scaled.width) // 2, 154 + (max_h - scaled.height) // 2))
        x += card_w + 22
    board.save(COMPARISON)

def checks(atlas):
    lines = [f"atlas_size={atlas.size}", f"mode={atlas.mode}", f"cell_size={CELL_W}x{CELL_H}", f"cells={ROWS*COLS}", f"alpha_cutoff={ALPHA_CUTOFF}", f"palette_target={PALETTE_SIZE}"]
    if atlas.size != (384, 512): lines.append("ERROR atlas must be 384x512")
    bad = []
    anchors = []
    for row in range(ROWS):
        for col in range(COLS):
            tile = atlas.crop((col * CELL_W, row * CELL_H, (col + 1) * CELL_W, (row + 1) * CELL_H))
            a = tile.getchannel("A")
            bbox = a.getbbox()
            if not bbox: bad.append(f"empty:{row},{col}")
            anchors.append((row, col, bbox[3] - 1 if bbox else -1))
    lines.append("feet_bottoms=" + ",".join(f"{r}:{c}={b}" for r, c, b in anchors))
    if bad: lines.append("ERROR " + ",".join(bad))
    else: lines.append("PASS every cell non-empty")
    if all(b == 126 for _, _, b in anchors): lines.append("PASS feet anchor y=126 across all cells")
    else: lines.append("ERROR foot anchor mismatch")
    # Hard-alpha check catches residual translucent fringe.
    weak = sum(0 < a < 255 for a in atlas.getchannel("A").getdata())
    lines.append(f"weak_alpha_pixels={weak}")
    lines.append("PASS hard alpha" if weak == 0 else "ERROR translucent pixels remain")
    CHECKS.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return lines

def main():
    atlas, _ = build_atlas()
    atlas.save(ATLAS)
    save_preview(atlas)
    comparison(atlas)
    lines = checks(atlas)
    NOTES.write_text("""# 96×128 style-master prototype

The approved 4×4 anime/chibi fisherman turnaround is a visual master only. This
local prototype converts each of the 16 source cells to a deterministic 96×128
native tile using a binary alpha cutoff, a compact median-cut palette, nearest
neighbour reduction and a shared local foot anchor at y=126. Soft generated
colour bleed is intentionally removed; no runtime texture or draw code changed.

Rows retain front, back, right-profile and left-profile facings. Columns retain
walk-frame timing/gear consistency from the source sheet. The hand-painted cues
are navy cap/hair, warm cream brim and scarf, teal jacket, orange trousers,
chunky brown boots, olive shoulder pack and a dark fishing rod/reel.

Runtime impact if adopted: atlas is 384×512 RGBA (768 KiB uncompressed), still
16 cells and 96×128 source regions. Existing 2× destination draw/collider and
feet anchor remain compatible. This branch/artifact is intentionally local-only
for visual review; PR20 remains untouched.
""", encoding="utf-8")
    print(f"wrote {ATLAS}")
    print(f"wrote {PREVIEW}")
    print(f"wrote {COMPARISON}")
    print(f"wrote {CHECKS}")
    print("\n".join(lines))

if __name__ == "__main__":
    main()
