# Fish art generation skill

Use this guide when adding a fish to Tidebound Notebook. A fish has two optional
visual assets: a compact polygon portrait used by the ledger and reveal helpers,
and a larger illustrated card used by the encyclopedia and result card. The game
is deliberately playable without either asset, so art can land independently of
gameplay work.

## Asset contract

The approved roster is authoritative in `fish_name_mapping.json`. Each
`FISH_SPECIES` entry carries the exact `id` from that file, and the loader uses
the mapping's `pixel_portrait` and `encyclopedia` paths. Similar-looking
species must never be assigned to an old ID; only the three entries marked
`matching_original_id` in the mapping retain their original IDs. The small
`_fish_art_stem()` helper remains available for isolated naming tests, but it
is not a migration mechanism for the active roster.

| Use | Path | Target | Required treatment |
| --- | --- | --- | --- |
| Compact portrait / polygon catch art | `assets/fish/<stem>.png` | 96×64 px | RGBA PNG, transparent background, side profile, flat pixel-friendly shapes |
| Encyclopedia illustration | `assets/fish_cards/<stem>_v2.png` | 768×512 px for the approved bundle | RGBA PNG, transparent outside the illustration, no baked-in text or UI |

Godot preserves card aspect ratio while fitting it into the ledger, so do not
stretch a card to fill a fixed rectangle. Keep the `fish_id` and both mapping
paths synchronized when replacing an approved asset.

## Visual language

### Compact polygon portrait and catch reveal

The compact asset should read at 1× and remain recognizable at the tiny ledger
size. Draw a left-facing or right-facing side profile with one clear head, body,
tail, dorsal fin, and ventral fin. Use a dark blue ink outline (`#13253a` or a
nearby tone), a small flat palette, and one or two high-contrast eye/glint
pixels. Leave transparent breathing room around the silhouette; a soft water
shadow is fine, but do not add a solid rectangle, frame, label, or drop-shadow
background.

The staged catch reveal draws a generic procedural polygon silhouette before
the card flips, so the species stays hidden while rarity and timing cues play.
After the flip it prefers the matching transparent `_v2` encyclopedia card
art, then falls back to the compact portrait for partial/legacy bundles. Keep
the asset's proportions compatible with that silhouette: a broad body, a
distinct tail on one side, and fins that do not depend on fine antialiasing.
Do not use text baked into the portrait. The reveal supplies the fish name,
rarity, size, weight, variant, and crown marker after the flip.

The approved bundle is a materialized input, not a generated replacement for
the source sheet. If a future approved sheet changes, update
`fish_name_mapping.json`, copy only the listed fish assets, and preserve the
map, hero, and prop files that are marked unchanged in the bundle manifest.

If using an image model instead of Pillow, generate the compact and card art as
two views of the same side-profile reference. A useful compact prompt shape is:
`original SFC-era pixel-art <species>, side profile, dark navy one-pixel outline,
flat sea/sand palette, distinct tail and fins, one eye glint, transparent
background, no words, no frame, no watermark`. Request a larger working image
only to avoid jagged model output, then downsample to 96×64 with nearest-neighbor
resampling and clean the background to alpha. Treat the prompt as a starting
point; preserve the project's silhouette and palette rather than copying a
model's incidental style.

### Illustrated encyclopedia card

The card is a larger, more expressive side-profile illustration. It may have
textured brushwork, scales, glow, or a richer background *inside the fish*, but
the pixels outside the illustration must stay transparent so the ledger panel
can provide its own background. Compose the fish centrally with 5–8% clear
margin on every edge, keep the head and eye readable when reduced to roughly
16×10 px, and avoid tiny details that collapse into noise.

When deriving a card from a concept sheet, crop one fish at a time, remove the
paper/background with a connected flood-fill or mask, trim stray border noise,
and export a straight-alpha RGBA PNG. Keep any one-off crop/mask script outside the runtime asset directories and
record the source sheet and crop coordinates with the materialized bundle rather
than hand-cropping a screenshot without provenance. The older 480×320 framed cards
are compatibility fallbacks only.

For a new illustration, a matching prompt shape is: `original illustrated
coastal field-guide card of <species>, same side profile and markings as the
compact reference, expressive scales and fins, restrained <rarity> accent,
centered with clear margins, transparent background, no text, no border, no
watermark`. Supply the compact portrait as a visual reference when the tool
supports it, or keep the species' eye, tail direction, and dominant colors in
the prompt. Export at 768 px wide, preserve the aspect ratio, and remove any
generated paper, frame, lettering, or checkerboard before saving the PNG.

## Rarity-specific treatment

Rarity is gameplay data and should remain legible in the art without making
common fish look unfinished:

- `COMMON`: restrained sand/sea colors; use the neutral ledger accent `#b7c3d7`.
- `UNCOMMON`: one fresh mint or teal accent; ledger accent `#8bd59c`.
- `RARE`: a cool luminous fin, stripe, or eye glint; ledger accent `#72c7e8`.
- `EPIC`: a stronger silhouette or unusual fin/marking with a purple accent;
  ledger accent `#d19cff`.
- `LEGENDARY`: a clearly special motif (radiance, iridescence, crown-like fin,
  or other story cue) with warm gold `#f6c76b` and optional rainbow accents.
  Keep the species visually distinctive after discovery, but do not leak its
  name or identity through UI text before the first durable discovery.

These colors match `_rarity_color()` in `main.gd`; use them as accents rather
than filling every pixel. Do not encode map, weather, season, or catch-grade
rules in the image. Those rules belong in `_fish_conditions()` and the species
dictionary.

## Add a species and wire its art

1. Add the approved `fish_id`, display name, rarity, legal maps, and (when
   needed) conditions to `fish_name_mapping.json` and `FISH_SPECIES` together.
   Keep the ID order and count aligned; do not alias a new display name to a
   removed species.
2. Use the mapping's exact asset paths:

   ```gdscript
   {"id":"kelp_runner", "name":"Kelp Runner", "rarity":"UNCOMMON", "maps":["beach"]}
   ```

   The mapping controls both `assets/fish/` and `assets/fish_cards/` lookup. Do
   not add a second ad-hoc loader.
3. Add `assets/fish/<stem>.png` and `assets/fish_cards/<stem>_v2.png` using the
   exact paths recorded in the mapping.
4. Check that the new ID and name are unique, the rarity is one of `COMMON`, `UNCOMMON`,
   `RARE`, `EPIC`, or `LEGENDARY`, and every map is one of the maps built by the
   game. Confirm the conditions in `_fish_conditions()` describe the intended
   tide pool and do not make the species unreachable.
5. Add a focused smoke assertion when the species has special art or
   availability behavior. Prefer looking up the dictionary by name over a raw
   index; this keeps tests stable as the guide grows.

## Fallback behavior (do not remove)

`_load_fish_art()` resolves each path from `fish_name_mapping.json`. Missing or
unreadable files are ignored. Callers then fall through as follows:

1. Encyclopedia card: transparent card illustration (also preferred for the
   revealed catch face).
2. Catch reveal fallback: compact portrait fitted without stretching.
3. Final fallback: the existing procedural icon/silhouette, so the ledger and
   fishing loop still work.

Undiscovered legendary entries intentionally mask their identity (`???`) and
use a generic icon until a durable first capture. Do not “fix” that by making a
legendary card visible before discovery. Selling the last inventory copy does
not erase discovery; art should continue to render after that state transition.

## Validation checklist

Run these checks from the repository root before committing:

```sh
# Inspect dimensions, mode, and alpha bounds for the new files
python - <<'PY'
from pathlib import Path
from PIL import Image

stem = "kelp_runner"  # change this for the species under review
for path in (Path("assets/fish") / f"{stem}.png",
             Path("assets/fish_cards") / f"{stem}_v2.png"):
    if not path.exists():
        print(f"optional/missing: {path}")
        continue
    im = Image.open(path)
    assert im.format == "PNG" and im.mode == "RGBA", (path, im.format, im.mode)
    assert im.getbbox() is not None, f"empty image: {path}"
    alpha = im.getchannel("A")
    assert alpha.getbbox() is not None, f"no visible alpha: {path}"
    print(path, im.size, im.mode, "alpha bbox", alpha.getbbox())
PY

# Re-import textures, then run the order-independent game smoke suite
XDG_DATA_HOME=/tmp/godot-data XDG_CACHE_HOME=/tmp/godot-cache \
XDG_CONFIG_HOME=/tmp/godot-config godot --headless --editor --path . --import --quit
XDG_DATA_HOME=/tmp/godot-data XDG_CACHE_HOME=/tmp/godot-cache \
XDG_CONFIG_HOME=/tmp/godot-config godot --headless --path . \
  --script tests/smoke.gd -- --fresh
```

Before opening a PR, also verify visually that:

- the portrait has no opaque corners or accidental text;
- the card's transparent margins survive export and its eye/body read at
  ledger scale;
- the filename exactly matches the resolved stem and case;
- a missing one of the two assets still shows the intended fallback;
- a legendary card remains masked before discovery and visible after capture;
- the new species appears in the expected map/time/weather/season pool; and
- the diff does not include generated `.godot/imported` output or unrelated
  art rewrites.

Keep source sheets and one-off generation experiments outside the runtime asset
directories (or document the reproducible command in the PR). Commit the final
PNG and any small deterministic generator change, not a huge temporary source
image.
