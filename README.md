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

LEGENDARY follows a paced reveal: omen, rising energy, full-screen rainbow light/rays/particles, then a long afterglow. All SE are synthesized with Godot's AudioStreamGenerator and have no external audio-file dependency. The ledger records each catch, and save/load stores versioned position and catch data while rejecting unsafe legacy positions.

Run headless smoke checks with:

```sh
XDG_DATA_HOME=/tmp/godot-data XDG_CACHE_HOME=/tmp/godot-cache XDG_CONFIG_HOME=/tmp/godot-config godot --headless --path . --script tests/smoke.gd -- --fresh
```

## Three-map slice

The first connected region has three focused maps: Saltmere town, Amber beach, and Rocky shore. Exits connect town south to beach north, town east to rocky west, and beach east to rocky shore (with matching return entrances). A short pixel fade runs during each transition. The active map is written into the save file alongside day, time, fish count, catch ledger, and player position; older saves default to town.

NPC schedules, quests, and the wider offshore/lighthouse progression remain future work.

## Expanded field guide and hidden tide loop

The rebuilt slice includes 23 fish cards across Saltmere town, Amber Beach, and Rocky Shore, with COMMON, UNCOMMON, RARE, EPIC, and LEGENDARY rarity. The ledger opens as a three-column field guide with fallback card portraits for undiscovered species. Casting rolls one PERFECT-pool candidate up front. PERFECT timing keeps that candidate; GOOD timing swaps an EPIC/LEGENDARY candidate for a RARE drawn from the map's RARE pool at cast time, so low-grade results never register a Legendary species. Staged promotion cues are capped by the cue's rank (gold for COMMON/UNCOMMON, purple for RARE, rainbow for EPIC/LEGENDARY). Lies are calibrated per stage so a higher float stays more trustworthy: a RARE+ fish can look one or two stages lower (18%), while a COMMON/UNCOMMON fish shows purple 6% of the time and rainbow only 2%. A reversal (24% of casts) steps the float back one stage mid-wait. The result card names what happened: “逆転!” when a RARE+ catch beat the float, “ガセ…” when the float promised more than the catch, and “惜しい! PERFECTなら …” when an honest cue was cut down by a GOOD pull.

A weathered notice beside the Saltmere sign starts Issue #1's rumor loop. After the rumor is heard and three catches are collected, Moonlit Grotto appears as a distinct rocky-shore fishing pool; visiting it completes discovery and can surface Aurora koi.

## Chain FEVER

Three consecutive catches activate a 30-second FEVER window. The HUD shows chain
progress and remaining time; a warm flash, original chime, and full music layers
announce activation. FEVER and bait use rarity-sensitive weights: common fish
retain their baseline, while higher rarities receive progressively stronger
boosts. On Rocky Shore, a cast after two chain catches rolls for a legendary
candidate: 1% base, +2% during FEVER, +2% with Moonseed (5% cap). The roll
happens at cast time; PERFECT timing keeps the legendary, while GOOD timing
swaps it for a RARE catch and keeps its lower-quality metadata and
rescue-meter effect. Catches do not refresh the timer. A lost fish or elapsed
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
