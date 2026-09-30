# Tidebound Notebook v2

A compact Godot 4 coastal fishing RPG prototype with an intentionally small SFC-era hero on a broad 64×40 tile overworld (16 px tile basis). Explore separate Saltmere town, amber beach, and rocky shore maps connected by short fade transitions at marked exits. Walk with WASD/arrow keys, cast with Space near water, open the tide ledger with N, and save with F6.

All visuals are original primitive pixel-style shapes; no Dragon Quest, Final Fantasy, or other protected character/asset content is used.

## Saltmere town slice (v3 local refinement)

The playable slice uses a 480×270 integer-scaled viewport over the same broad 64×40 world. Original generated pixel art (`assets/`) adds a hand-authored-feeling terrain texture, three building variants, trees, rocks, reeds, well, barrels, and a 16×24 hero sprite sheet with four facing directions and four walking frames. The town route runs from the plaza down a cobbled path to the pier; shallow water and building footprints have collision, while the pier remains a valid fishing route.

Space now starts a short cast sequence at the shore/pier and resolves into a catch, with the ledger showing species counts. Save/load stores versioned position and catch data, rejects unsafe legacy positions, and F6 remains the save key. This is still a bounded first slice: there are no NPC schedules, dialogue, quests, or audio yet, and the large overworld beyond the slice remains a visual backdrop.

Run headless smoke checks with:

```sh
XDG_DATA_HOME=/tmp/godot-data XDG_CACHE_HOME=/tmp/godot-cache XDG_CONFIG_HOME=/tmp/godot-config godot --headless --path . --script tests/smoke.gd -- --fresh
```


## Three-map slice

The first connected region has three focused maps: Saltmere town, Amber beach, and Rocky shore. Exits connect town south to beach north, town east to rocky west, and beach east to rocky shore (with matching return entrances). A short pixel fade runs during each transition. The active map is written into the save file alongside day, time, fish count, catch ledger, and player position; older saves default to town.

## Three-map transition slice

The current map state is split into town, beach and rocky shore. Walking to a marked edge exit fades to the next map and spawns at its matching entrance. Day, time, fish count, catch ledger and save data carry across maps. Save data is versioned and legacy unsafe positions are rejected.

This first transition slice covers town↔beach, town↔rocky shore and beach↔rocky shore. NPC schedules, quests, audio and the wider offshore/lighthouse progression remain future work.
