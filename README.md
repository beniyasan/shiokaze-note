# Tidebound Notebook v2

A compact Godot 4 coastal fishing RPG prototype with an intentionally small SFC-era hero on a broad 64×40 tile overworld (16 px tile basis). Explore separate Saltmere town, amber beach, and rocky shore maps connected by short fade transitions at marked exits. Walk with WASD/arrow keys, cast with Space near water, open the tide ledger with N, and save with F6.

All visuals are original primitive pixel-style shapes; no Dragon Quest, Final Fantasy, or other protected character/asset content is used.

## Saltmere town slice (v3 local refinement)

The playable slice uses a 480×270 integer-scaled viewport over the same broad 64×40 world. Original generated pixel art (`assets/`) adds a hand-authored-feeling terrain texture, three building variants, trees, rocks, reeds, well, barrels, and a 16×24 hero sprite sheet with four facing directions and four walking frames. The town route runs from the plaza down a cobbled path to the pier; shallow water and building footprints have collision, while the pier remains a valid fishing route.

## Fishing battle

Space starts a cast at the shore or pier. After the bite, the fish battle is a short tug-of-war rather than a single instant check:

- Follow the moving gauge and press Space in the teal/gold zone for repeated pulls
- Hold the opposite WASD/arrow direction shown on screen to counter the fish's escape direction
- Fish stamina, line tension, escape pressure, pull cooldown and the battle timer are all visible
- Clean pulls ramp the procedural SE and screen effects; failed pulls strain the line and can snap it
- A three-catch perfect combo unlocks Rainbow Kingfish (LEGENDARY)

LEGENDARY follows a paced reveal: omen, rising energy, full-screen rainbow light/rays/particles, then a long afterglow. All SE are synthesized with Godot's AudioStreamGenerator and have no external audio-file dependency. After the reveal, the catch stays safely on the result card until the player chooses C to register/keep it or X to sell it for shells; Space never dismisses an undecided catch. A pending choice is saved and restored, so closing the game cannot discard a fish. Selling removes only the held inventory copy while preserving its discovery and size record. First captures remain immutable discovery records; repeat catches use a shortened reveal, and a larger specimen updates a species crown record shown with a CROWN marker. Size breaks ties by weight, and crown records retain map, spot, day, variant, and grade. Crown data, pending choices, and the tide forecast are saved in the version 12 ledger format.

## Tide forecast and fish availability

The tide ledger carries a deterministic clock, weather forecast, and four-season cycle. A full in-game day lasts three real minutes; every seventh in-game day advances the season, and each new day receives a repeatable clear/overcast/rain/storm forecast. Fish pools respond to all three conditions: moonfin trout prefer autumn/winter dusk and night tides, storm sardines and saltwater eels favor rain or storms after dusk, and familiar sprat and gobies remain available in calmer daylight waters. The field guide's other species follow similarly readable seasonal windows.

The HUD shows the current season, time period, weather, and clock. Forecast state is saved with the tide ledger; older saves fall back to the day-based forecast.

Run headless smoke checks with:

```sh
XDG_DATA_HOME=/tmp/godot-data XDG_CACHE_HOME=/tmp/godot-cache XDG_CONFIG_HOME=/tmp/godot-config godot --headless --path . --script tests/smoke.gd -- --fresh
```

## Three-map slice

The first connected region has three focused maps: Saltmere town, Amber beach, and Rocky shore. Exits connect town south to beach north, town east to rocky west, and beach east to rocky shore (with matching return entrances). A short pixel fade runs during each transition. The active map is written into the save file alongside day, time, fish count, catch ledger, and player position; older saves default to town.

NPC schedules, quests, and the wider offshore/lighthouse progression remain future work.

## Expanded field guide and hidden tide loop

The rebuilt slice includes 23 fish cards across Saltmere town, Amber Beach, and Rocky Shore, with COMMON, UNCOMMON, RARE, EPIC, and LEGENDARY rarity. The ledger opens as a three-column field guide with fallback card portraits for undiscovered species. Casting rolls one PERFECT-pool candidate up front. PERFECT timing keeps that candidate; GOOD timing deterministically swaps an EPIC/LEGENDARY candidate for a map-legal RARE catch, so low-grade results never register a Legendary species. Staged promotion cues are capped by candidate rank (gold for COMMON/UNCOMMON, purple for RARE, rainbow for EPIC/LEGENDARY) but can occasionally mislead or reverse. The result card discloses the mismatch as “逆転!” or “ガセ…”.

Fisher Mera in the Saltmere plaza or the weathered notice beside the sign starts Issue #1's rumor loop. After the rumor is heard and three catches are collected, Moonlit Grotto appears as a distinct rocky-shore fishing pool; visiting it completes discovery and can surface Aurora koi. Legendary field-guide cards remain `???` with a generic icon even after collection, keeping the highest-rarity mystery intact.

## Chain FEVER

Three consecutive catches activate a 30-second FEVER window. The HUD shows chain
progress and remaining time; a warm flash, original chime, and full music layers
announce activation. FEVER and bait use rarity-sensitive weights: common fish
retain their baseline, while higher rarities receive progressively stronger
boosts. The Rocky Shore legendary roll happens at cast time after two chain
catches; timing does not create a second roll. PERFECT keeps the rolled
candidate, while GOOD downgrades it to a map-legal RARE catch,
capped at 5% even with Moonseed; GOOD timing keeps its lower-quality metadata,
RARE substitution, and rescue-meter effect. Catches do not refresh the timer. A lost fish or elapsed
FEVER window resets the chain. Reading
the ledger and map transitions pause the timer with the fishing loop. Version 6
saves retain the combo and remaining FEVER time; older saves start with no chain.

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

Misses and GOOD catches advance a visible three-step RESCUE meter. Each step
adds a small, deterministic rarity nudge to the tide forecast and moves the
promotion float forward, disclosed as `RESCUE TIDE`; it never resolves the
timing battle. At RESCUE READY, the next landed battle gets a one-shot
map-legal RARE-or-better floor, then the meter resets. Tackle selection and
rescue progress are saved in the version 12 ledger; older saves keep their
selected indices and start with the new derived forecast bonus.
