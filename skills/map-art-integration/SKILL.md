---
name: map-art-integration
description: Add or replace map art in shiokaze-note, aligning reference images and static backgrounds with world coordinates, collision, landmarks, exits, saves, and dynamic labels. Use for playable map additions or map-art integration, not isolated concept art.
---

# Map art integration

Inspect the active checkout before changing a map; runtime copies and worktrees
may differ. Extend existing helpers rather than building a parallel map system.
Preserve authorized gameplay scope when the request is visual-only.

## Runtime anchors

Verified in this checkout’s `main.gd`: `TILE := 16`, `WORLD_W := 64`,
`WORLD_H := 40`, `WORLD_SIZE := Vector2(WORLD_W*TILE, WORLD_H*TILE)`.
The world is **1024 x 640 pixels**; `project.godot` uses a **480 x 270** viewport
with integer scaling and nearest filtering. Re-read these constants before a
future integration rather than assuming the dimensions remain unchanged.

- `_build_map()` clears `props`, `solids`, and `landmarks`, then dispatches to a
  builder. Map ids currently are `town`, `beach`, `rocky`, and `grotto`.
- `_ready()` loads `assets/maps/saltmere_town.png`, `amber_beach.png`,
  `rocky_shore.png`, and `moonlit_grotto.png` into `map_art`.
  `_draw_map_background()` draws them across `WORLD_SIZE`.
- Town is authored against its backdrop: `TOWN_WALK` lists the rectangles the
  hero may stand in and `TOWN_SOLIDS` the obstacles inside them
  (`_town_walkable()`), instead of the shoreline rule the other maps use.
- `_draw_map_landmarks()` routes static-map labels to `_draw_static_map_labels()`;
  `_map_art_point()` scales label anchors from authored 1024 x 640 coordinates.
  `_using_static_map_art()` suppresses duplicate props/landmark primitives while
  keeping their solids active. `_draw()` depth-sorts props and the player by
  their feet, then draws exit markers and transient effects.
- `_walkable()` checks a feet rectangle against `solids`, world bounds, and
  `_shore(x)`. `_fishing_spots()` and `_can_fish()` define castable locations.
- The `MAP_EXITS` table defines map connections (trigger zone, destination
  spawn, signpost); `_check_map_exit()`, `_entry_spawn()`, and
  `_exit_markers()` only read it, and `_transition_to()` performs the travel.
- `_save_game()` / `_load_game()` persist map and player position plus shared
  progress. `_map_display_name()`, `_map_hint()`, `_exit_hint()`, and
  `_draw_hud()` own dynamic presentation.

Read `README.md`, `MAP_DESIGN.md`, `MAP_ART_WORKFLOW.md`, `tests/smoke.gd`, and
the above helpers. Determine whether the active checkout uses procedural backgrounds or
`map_art` textures before choosing the integration point.

## 1. Inspect and prepare the reference

- View the supplied image. Record its dimensions, crop, playable land/water,
  entry/exit edges, fishing locations, and major landmarks. Existing references
  in `reference_maps/` and `refs/` are 1448 x 1086 RGB, not runtime-size assets.
- Retain the original outside runtime assets. Record which image/version was
  approved and the crop/scale used. Separate map scenery from frame, text,
  legend, and screenshot UI.
- Preserve the approved composition and visual treatment. For image-model edits,
  supply the approved image as reference and explicitly preserve geography;
  request scenery only, with no characters, labels, HUD, arrows, or watermark.
- Export final backgrounds under `assets/maps/<descriptive_stem>.png`. Prefer
  exact world dimensions and an opaque RGB or RGBA PNG. Use RGBA for intentional
  overlay transparency. Preserve aspect ratio by an explicit crop/pad decision;
  avoid silently stretching a 4:3 source into the 8:5 world.
- Use nearest-neighbour resampling for established pixel art, inspect at native
  viewport scale, and retain a deterministic preparation command when resizing
  or cropping. Keep experiments outside runtime asset folders.

Done when the full-world image has the approved composition, known transform,
correct dimensions, and no baked dynamic elements.

## 2. Establish one coordinate transform

For a cropped reference mapped to the entire world:

```text
world_x = (reference_x - crop_left) * WORLD_SIZE.x / crop_width
world_y = (reference_y - crop_top)  * WORLD_SIZE.y / crop_height
```

If padding is used, include its offset in the transform. Use the same transform
for image anchors, collision, fishing spots, labels, exits, and spawns. Extend
`_map_art_point()` or equivalent shared helpers rather than adding another
independent label transform. Round
final authored anchors to pixels; tile-snap only where it improves routes.
Define whether each anchor is a sprite's feet, a water edge, or a label center.
Keep camera zoom/presentation scaling separate from world coordinates.

Done when entrance, shoreline, and at least two distant landmark anchors agree
between the image and a debug/capture overlay. A changed world scale requires
reviewing camera limits, movement speed, feet size, fish reach, effect offsets,
all map coordinates, and saved-position migration together.

## 3. Integrate art and geometry

Load the final texture once (follow existing `map_art` loading if present),
select it in `_draw_map_background()`, and draw it over
`Rect2(Vector2.ZERO, WORLD_SIZE)`. Retain a procedural/plain fallback for missing
art. Keep the existing player, fishing effects, and HUD dynamic.

For scenery already baked into the image, suppress its duplicate drawing while
retaining or replacing its collision explicitly. Removing `_add_prop()` also
removes the solid it creates; never use that as a visual-only fix. Static
foreground objects cannot depth-sort around the hero: split an occluding canopy
or roof into a separate layer when the route passes behind it.

Implement a map builder and update the dispatch. Align `solids` and `_shore()`
with the visible land. The current `_shore(x)` model only describes a lower
coastline; caves, holes, internal pools, and disconnected land require additional
collision regions rather than an inaccurate shore approximation. Limit special
pier/bridge walkability overrides to their intended map.

Add landmarks (`kind`, `pos`, `label`) and castable `_fishing_spots()` as needed.
Validate fishing from walkable positions beside the actual water, and reject
inland casting. Update fish catalog/conditions only when the requested map
addition includes availability changes. Leave 2-3 tile clear routes between
major colliders and room for casting at each fishing bank.

**Known integration risk:** the existing static beach/rocky art inherited older
collider positions. Their presence and passing smoke tests do not establish
background/collision alignment. Compare each drawn bank/building to its runtime
solid in rendered GUI views before treating those maps as verified.

Done when every visible route, obstacle, and fishing area behaves as drawn.

## 4. Connect maps and preserve saves

For each connection, add one `MAP_EXITS` entry per travel direction (trigger
`zone`, destination `spawn`, `marker`, `label`, `dir`); the smoke suite checks
every entry for a reachable trigger, a safe spawn, and a return exit. A spawn must be walkable in the destination and outside its
return trigger, so travel does not bounce immediately back. Verify triggers by
walking to them; directly calling `_transition_to()` alone misses blocked exits.

Extend the load-time map whitelist and map dispatch together. Build the loaded
map before validating its saved position; use a map-specific safe spawn when a
position is invalid. Preserve saves missing newer fields. If map coordinates or
ids change, document the migration and advance the save version when needed.
Keep progress (catch ledger, conditions, unlocks, etc.) intact across travel.

Done when round-trip travel and save/reload restore each map safely, including
an old save, an unknown map id, and a saved position now inside an obstacle.

## 5. Keep labels and HUD dynamic

World names/signs belong in `_draw_static_map_labels()`,
`_draw_map_landmarks()`, or `_draw_exit_markers()`;
map title, clock/weather, toast, nearby exit hint, and fishing controls belong
in `_draw_hud()` on its CanvasLayer. Update display-name and hint matches for
new ids. Use the same destination spelling on its sign and HUD.

Measure long labels with the actual font, fit or wrap them, and test contrast
against the art. Check notebook, fishing result, and transition states for
clipping or overlapping prompts. Retain localized text as data, not pixels.

## 6. Verify and review

Run import and smoke checks with isolated test data (do not overwrite real saves):

```sh
TEST_ROOT=$(mktemp -d /tmp/shiokaze-map-test.XXXXXX)
export XDG_DATA_HOME="$TEST_ROOT/data" XDG_CACHE_HOME="$TEST_ROOT/cache"
export XDG_CONFIG_HOME="$TEST_ROOT/config"
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/smoke.gd -- --fresh
```

Extend smoke coverage for each map: texture dimensions/loading, safe spawns,
solid/water rejection, reachable fishing spots, real exit triggers, reverse
travel, fade completion, and current/legacy save restoration. Assert fallback
behavior if optional art is missing.

Use `capture_maps.gd` if present, extending its map list and explicit valid
camera/spawn positions. Captures need a rendering-capable GUI/display; headless
smoke alone does not prove appearance. Inspect full-map and player-level views
at native and integer scale. In the GUI, traverse every connection, open `N`,
cast with `Space`, and save/reload with `F6`. Verify camera edges, feet alignment,
occlusion, readable labels, and transition completion.

Before delivery:

- [ ] Final asset matches approved geography; no baked HUD/text or duplicate props.
- [ ] One documented transform aligns visuals, collision, fishing, exits, and labels.
- [ ] Every entrance has a safe spawn; routes and fishing banks are reachable.
- [ ] Both directions of every connection pass real movement and transition tests.
- [ ] Old/current saves load safely and retain shared progress.
- [ ] Dynamic HUD remains readable in exploration, notebook, fishing, and fades.
- [ ] Import/smoke checks pass and rendered/GUI evidence was actually inspected.
- [ ] Diff contains only intended assets/code/docs/tests; excludes `.godot/` cache.

Report changed paths, test results, reviewed screenshots, and any unverified
behavior. Describe remaining visual or collision limitations explicitly.
