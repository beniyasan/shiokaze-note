extends RefCounted
# One timeline drives the reveal renderer, sound cues, music and smoke tests.
const RARITY_AT := 1.10
const RISE_AT := 1.90
const HOLD_AT := 3.20
const FLIP_AT := 3.65
const REVEAL_AT := 4.05
const FLIP_END := 4.45
const AFTERGLOW_AT := 6.20
const DURATION := 8.40

static func stage_at(time: float) -> int:
	if time < RARITY_AT: return 0 # unknown sealed card
	if time < RISE_AT: return 1 # legendary rarity seal
	if time < HOLD_AT: return 2 # growing silhouette and rainbow energy
	if time < FLIP_AT: return 3 # deliberate breath before the turn
	if time < REVEAL_AT: return 4 # card back turns to its edge
	if time < AFTERGLOW_AT: return 5 # face opens into the rainbow climax
	return 6 # sustained afterglow
