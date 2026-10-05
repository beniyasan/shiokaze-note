# Adding a static map

The map renderer now accepts an authored pixel-art background while gameplay
still uses explicit map rules. Treat the texture and those rules as one change.

## Asset preparation

1. Start with a clean background: no HUD, hero, UI text, or baked-in fishing markers.
2. Save a PNG under `assets/maps/`. Current backgrounds use 1024×640 world pixels.
3. Keep important landmarks legible at the 480×270 viewport and current camera zoom.
4. Import with Godot before testing (`godot --headless --editor --path . --quit-after 100`).

## Wire the map

- Add the background to `map_art` in `_ready()` and route it in `_draw_map_background()`.
- Add `_build_<map>()`, then add the map key in `_build_map()`.
- Specify walkable banks/solids, fishing spots, both directions of each transition,
  entry spawns, and exit marker positions. Never add an exit without a valid return spawn.
- Add the map to save/load's accepted map list and give it a display name/hint.
- Keep labels as overlays. `_map_art_point()` maps authored coordinates to world size.
- `_using_static_map_art()` suppresses the old prop/landmark drawings so textures
  do not get duplicate buildings or rocks. Gameplay solids remain independent.

## Grotto example

`grotto` is reached through the unlocked Rocky Shore gate around `(690,520)` and
returns through the west edge. It has its own background, central-lake solid,
moonlit fishing point at `(512,520)`, and save key. The original Rocky Shore hidden
spot remains compatible with old saves and the existing collection/rumor gate.

## Verification

Run `tests/smoke.gd` with writable XDG directories. Cover the gate, entry/return,
fishing point, and save/load. Then inspect a real rendered frame at each spawn and
at the fishing edge: headless dummy rendering cannot prove visual alignment. In
particular, compare drawn banks and solid boundaries and keep the live hero off
water/cliffs. Test the camera framing after every texture/layout change.
