# Tidebound Notebook v2

A compact Godot 4 coastal fishing RPG prototype with an intentionally small SFC-era hero on a broad 64×40 tile overworld (16 px tile basis). Explore separate Saltmere town, amber beach, and rocky shore maps connected by short fade transitions at marked exits. Walk with WASD/arrow keys, cast with Space near water, open the tide ledger with N, save with F6, and press F to toggle reduced flashing.

All visuals are original primitive pixel-style shapes; no Dragon Quest, Final Fantasy, or other protected character/asset content is used.

## Saltmere town slice (v3 local refinement)

The playable slice uses a 480×270 integer-scaled viewport over the same broad 64×40 world. Original generated pixel art (`assets/`) adds a hand-authored-feeling terrain texture, three building variants, trees, rocks, reeds, well, barrels, and a 16×24 hero sprite sheet with four facing directions and four walking frames. The town route runs from the plaza down a cobbled path to the pier; shallow water and building footprints have collision, while the pier remains a valid fishing route.

## Fishing battle

Space starts a cast at the shore or pier. After the bite, the fish battle is a short tug-of-war rather than a single instant check:

- Follow the moving gauge and press Space in the teal/gold zone for repeated pulls
- Hold the opposite WASD/arrow direction shown on screen to counter the fish's escape direction
- Fish stamina, line tension, escape pressure, pull cooldown and the battle timer are all visible
- The teal/gold gauge alone decides a pull. The outlined challenge zone is a bonus: a pull inside it also eases the line, and a GOOD pull outside it still counts
- A pull is ready again after about one second; fish stamina is the same at every chain length, and a longer chain only adds bonus rounds
- The slalom round asks for the same direction as the counter prompt
- Clean pulls ramp the procedural SE and screen effects; failed pulls strain the line and can snap it
- A three-catch perfect combo can surface Storm tuna (LEGENDARY)

LEGENDARY follows a paced reveal: omen, rising energy, full-screen rainbow light/rays/particles, then a long afterglow. All SE are synthesized with Godot's AudioStreamGenerator and have no external audio-file dependency. After the reveal, the catch stays safely on the result card until the player chooses C to register/keep it or X to sell it for shells; Space never dismisses an undecided catch. A pending choice is saved and restored, so closing the game cannot discard a fish. Selling removes only the held inventory copy while preserving its discovery (see Sell or register for how crowns work). First captures remain immutable discovery records; repeat catches use a shortened reveal, and a larger registered specimen updates a species crown record shown with a CROWN marker. Size breaks ties by weight, and crown records retain map, spot, day, variant, and grade. Crown data, pending choices, heard rumors, and the tide forecast are saved in the version 13 ledger format.

## Tide forecast and fish availability

The tide ledger carries a deterministic clock, weather forecast, and four-season cycle. A full in-game day lasts three real minutes; every seventh in-game day advances the season, and each new day receives a repeatable clear/overcast/rain/storm forecast. Fish pools respond to all three conditions: Moonfish prefer autumn/winter dusk and night tides, Storm tuna favor rain or storms after dusk, and Sunrise bream, Sand flatfish and Pearl seabass bite in daylight all year. The field guide's other species follow similarly readable seasonal windows. No map is empty for a whole season, but a restrictive tide (the town pier at night, any storm in town) can still leave a pool with nothing biting; the cast is then refused without charging tackle.

The HUD shows the current season, time period, weather, and clock. Forecast state is saved with the tide ledger; older saves fall back to the day-based forecast.

Run headless smoke checks with:

```sh
XDG_DATA_HOME=/tmp/godot-data XDG_CACHE_HOME=/tmp/godot-cache XDG_CONFIG_HOME=/tmp/godot-config godot --headless --path . --script tests/smoke.gd -- --fresh
```

## Three-map slice

The first connected region has three focused maps: Saltmere town, Amber beach, and Rocky shore. Exits connect town south to beach north, town east to rocky west, and beach east to rocky shore (with matching return entrances). A short pixel fade runs during each transition. The active map is written into the save file alongside day, time, fish count, catch ledger, and player position; older saves default to town.

NPC schedules, quests, and the wider offshore/lighthouse progression remain future work.

## Expanded field guide and hidden tide loop

For contributors adding a species or regenerating its artwork, see the
[fish art generation skill](skills/fish-art-generation/SKILL.md). It documents
the compact polygon portrait and transparent encyclopedia-card contracts,
rarity treatment, loader fallbacks, and validation commands.

The rebuilt slice now uses the attached approved 25-fish set as its complete active roster across Saltmere town, Amber Beach, Rocky Shore, and Moonlit Grotto. `fish_name_mapping.json` is the authoritative ID and asset-path manifest: only Amber anchovy, Aurora koi, and Tidepool blenny retain matching original IDs; the other 22 entries receive their own game references. Each entry has a matching transparent encyclopedia illustration in `assets/fish_cards/*_v2.png` (768×512 RGBA) and compact portrait in `assets/fish/` (96×64 RGBA); the card is reused for the species-specific catch reveal after the generic silhouette flips, with the portrait as a compatibility fallback. The old prototype roster and its fish files were removed rather than guessed onto the approved names. The ledger opens as a three-column field guide and keeps undiscovered Legendary identities masked. Casting rolls one PERFECT-pool candidate up front. PERFECT timing keeps that candidate; GOOD timing deterministically swaps an EPIC/LEGENDARY candidate for a map-legal RARE catch unless the golden-tide premium cue has locked that EPIC/LEGENDARY result. Staged promotion cues are capped by candidate rank (gold for COMMON/UNCOMMON, purple for RARE, rainbow for EPIC/LEGENDARY) but can occasionally mislead or reverse. A false rainbow or purple float is sized against the chance of a genuine one in the current tide pool, so a rainbow float stays honest roughly three times in four whichever pool is active. The result card discloses the mismatch as “逆転!” or “ガセ…”, and nothing about the catch (toast, SELL/REGISTER prices, name) is shown until the card has flipped.

The materialized bundle also includes unchanged map, hero, and world-prop references; those files remain outside the fish replacement and are byte-identical to the approved archive's unchanged entries.

### Rumors, hints and the grotto gate

Stand beside Fisher Mera or the weathered notice in the Saltmere plaza (a bobbing
`!` marks an unheard rumor) and press SPACE to hear the next rumor. Each source
knows five: the grotto rumor plus four species hints. A species hint is generated
from the same condition table that decides the species pool (for example
`Moonfish: dusk or night / clear or rain / autumn or winter`), so it can never
disagree with the water. Heard rumors are listed in the tide ledger (N, then A/D to
page), a rumor names an otherwise `????????` card, and the ledger draws a green dot
beside every discovered or rumored species that is biting on the current map,
time, weather and season.

Moonlit Grotto appears as a distinct rocky-shore pool once the grotto rumor has been
heard **and** the field guide is 25% discovered (7 of 25 species); the ledger shows
the guide percentage. Visiting it completes discovery and can surface Aurora koi.
Undiscovered legendary field-guide cards stay `???` with a generic icon; after the
first catch, their name, icon, and durable discovery remain visible even if the last
inventory copy is sold.

## Sell or register

Every landed fish waits for a choice once its card has flipped: `X` sells it, `C`
registers it. The prompt shows both prices, e.g. `X SELL +8   C REGISTER +5  NEW  CROWN`.

- Selling pays by rarity, size and variant. The species stays discovered and the
  first-capture record is kept, but a specimen that would have been a new crown is
  not recorded as one.
- Registering pays 1 shell, plus a rarity-scaled bonus for a first capture and +2
  for a new size crown, and is the only way a crown is written to the ledger (`^`).
  Duplicates are therefore worth selling; trophies are a real decision.

## Tide ledger quick reference

`N` opens the ledger. `A`/`D` page through heard rumors. `? mystery`, `~ shimmer`,
`! gilded` and `^ crown` mark specimens; a green dot means that species is biting now.

## Cue show: heat ladder and reduced flashing

The whole cast is staged as one escalating show, defined in
[EFFECTS_DESIGN.md](EFFECTS_DESIGN.md) and driven by `fx/fx_director.gd`:

- **Heat ladder.** Float, cut-ins, speed lines and the reveal's summon light all use
  one colour ladder: blue → gold → purple → rainbow, plus a premium gold. Gold is a
  quiet glint (it appears on most casts); purple dims the world, hushes the music and
  starts a heartbeat; rainbow fires a `激アツ!!` cut-in, speed lines and a brief
  chromatic pulse. Hotter cues hold the bite back longer (up to +1.7 s).
- **Extra cues.** A glowing fish school sometimes crosses the screen (often, but not
  always, RARE or better). The golden tide (`黄金の潮`) only ever appears for an
  EPIC-or-better candidate, and a golden-tide cast never fakes out (no downward false
  cue, no mid-wait reversal). These rolls use the FX director's own RNG, so they never
  change which fish bites.
- **Reach.** Purple-or-hotter bites enter a letterboxed REACH / SUPER REACH. Each pull
  has a short hit-stop, splash and callout; banners use a slim top strip so the timing
  gauge is never covered.
- **Reveal.** The card glows in the promised heat, then promotes one step at a time
  to the real result (`UP!`) or quietly fizzles. The flip bursts in proportion to
  rarity, followed by `NEW!` / `CROWN!` stamps. LEGENDARY cracks the screen, then
  shatters it. FEVER is announced once the catch is sold or registered: the banner,
  flash, chime, music change and rainbow frame all start together then.
- **Safety.** Full-screen flashes are limited to three per second with a brightness
  cap. F toggles reduced flashing (smaller flashes, gentler shake/zoom, no chromatic
  aberration, no soft full-screen tints, a steady danger edge); the setting is saved.

## Chain FEVER

Three consecutive catches activate a 30-second FEVER window. The HUD shows chain
progress and remaining time; a warm flash, original chime, and full music layers
announce activation once the catch that earned it is sold or registered. FEVER and bait use rarity-sensitive weights: common fish
retain their baseline, while higher rarities receive progressively stronger boosts.

The Rocky Shore legendary roll happens once, at cast time, when the upcoming catch
would be the third in the chain or later; timing does not create a second roll. It starts at
3%, FEVER adds 3% and Moonseed 2%, and it is capped at 8%. A legendary only ever
comes from this roll: a pool that holds nothing but a legendary refuses the cast. PERFECT keeps the
rolled candidate, while GOOD downgrades an EPIC/LEGENDARY candidate to a map-legal
RARE catch (keeping its lower-quality metadata and rescue-meter effect), except on
a golden-tide cast whose premium cue guarantees the EPIC/LEGENDARY result. Catches do
not refresh the timer. A lost fish or an elapsed FEVER window resets the chain, and
a miss that breaks a chain says how close it was (`惜しい!  one more catch for
FEVER`). Reading the ledger and map transitions pause the timer with the fishing
loop, and the timer holds while the catch that earned FEVER is still waiting for
SELL/REGISTER: the 30 seconds start when the FEVER banner appears. Version 6+
saves retain the combo and remaining FEVER time, and a save made while that catch is
still held keeps the pending banner (and the held clock) with it; older saves start
with no chain.

## Fair rescue (soft pity)

Unlucky runs are visible rather than hidden. Misses and low-grade catches advance
a three-step Rescue meter shown in the HUD and tide ledger. When it fills, the
next successfully landed battle gets a one-shot RARE-or-better species floor
from the current map and grade-eligible pool; the timing battle still has to be
won, so rescue never auto-catches a fish. A RARE/EPIC/LEGENDARY or PERFECT catch
resets the meter, and save files (version 8) retain its progress for a later
session. Older saves start with an empty meter.

On a fresh clone, import assets before running smoke checks:
```sh
XDG_DATA_HOME=/tmp/godot-data XDG_CACHE_HOME=/tmp/godot-cache XDG_CONFIG_HOME=/tmp/godot-config godot --headless --editor --path . --import --quit
```

## Tackle economy and fair rescue forecast

Bait is consumed on every cast and rods charge a small maintenance fee on the
same cast. Worms and the Reed Rod are free, reliable fallbacks. Glowbait and
Moonseed cost 2 and 4 shells and increase rarity odds, but make an uncountered
fish surge harder. Fiberglass costs 2 shells and reduces line strain while
slowing the bite; Stormglass costs 4 shells and suppresses escape while making
the line twitchier. These are different risk/reward choices rather than a free
upgrade ladder. The HUD and bait/rod selection toasts show the exact
shells-per-cast cost and trade-off.

Misses and GOOD catches advance a visible three-step RESCUE meter. The first
two misses each add a deterministic +6% PURPLE+ cue forecast (with a stronger
weight lift for EPIC/LEGENDARY species), so purple-or-higher cues become more
likely without resolving the timing battle. The HUD discloses this as
`PURPLE+ cue`; the third miss arms a one-shot, map-legal RARE-or-better floor,
then the meter resets. The rescue floor keeps the normal rarity weights inside
that eligible pool rather than selecting each RARE-or-better species uniformly.
Tackle selection and rescue progress are saved in the
version 13 ledger; older saves keep their selected indices and start with the
new derived forecast bonus.
