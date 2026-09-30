# 潮風ノート MAP DESIGN v1

## World scale
- 64x40 overworld target
- 16px tile basis
- Broad walkable lanes and small SFC-era JRPG character/object proportions
- Camera shows a local slice of the larger world and scrolls through routes

## Zones
- Port town: square, bait/tackle shop, market, inn/save, boatwright, piers
- Sandy beach: tutorial fishing, tide pools, driftwood
- Estuary and marsh: winding river, bridges, reeds, freshwater/brackish fishing
- Rocky coast: ledges, coves, breakwater, lighthouse stair
- Offshore: boat-only deep-water spots and moving fish schools
- Lighthouse and boss cove: late-game storm/night fishing area

## Route and progression
Town -> beach is the early tutorial route.
Town -> east pier -> rocky coast is the equipment route.
Town north gate -> marsh -> estuary is the exploration route.
Boatwright deliveries unlock offshore water.
Lighthouse key plus night rain unlocks the boss cove.

## Readability rules
- Town roads are 2 tiles wide
- Keep 2-3 tile clear lanes between major colliders
- Buildings use 2-3 tile footprints where possible
- Fishing banks leave room for the player and casting animation
- Use ground color, lanterns, foam, bridges and signposts as navigation landmarks

## Progression flags
rocky_access
boat_unlocked
sluice_open
lighthouse_key
storm_tide
boss_cove_open

The current prototype is intentionally procedural and uses original pixel-style primitives.
