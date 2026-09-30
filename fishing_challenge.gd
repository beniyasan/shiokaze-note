# A deterministic, forgiving chain of short fishing mini-games.
# It owns the round rules; main.gd owns presentation, line tension, and audio.
class_name FishingChallenge
extends RefCounted

enum Game { SHRINKING_RING, MOVING_ZONE, SLALOM, FINISH }

var strength: int = 1
var combo: int = 0
var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var rounds: Array[Dictionary] = []
var round_index := 0
var action_progress := 0
var action_goal := 1
var phase_t := 0.0
var grace_t := 0.85
var done := false
var last_success := false
var last_event := ""

func configure(fish_strength: int, combo_count: int, seed: int = 1) -> void:
	strength = clampi(fish_strength, 1, 3)
	combo = maxi(combo_count, 0)
	seed_value = seed
	rng.seed = seed_value
	rounds.clear()
	# Light catches stay readable; a strong fish asks for all four styles.
	var round_count := 2 if strength == 1 else (3 if strength == 2 else 4)
	var order: Array[int] = [Game.SHRINKING_RING, Game.MOVING_ZONE, Game.SLALOM, Game.FINISH]
	# Rotate the opening style, while retaining all four styles for a large fish.
	var offset := int(abs(seed_value)) % order.size()
	for i in range(round_count):
		var game_type: int = order[(i + offset) % order.size()]
		var actions := 1
		if strength >= 2 and (game_type == Game.SLALOM or game_type == Game.FINISH): actions = 2
		# A combo-two catch deliberately takes six clean beats, preserving a
		# satisfying tug rhythm without making the first fish exhausting.
		if strength >= 3 and game_type == Game.FINISH: actions = 3
		rounds.append({"type": game_type, "actions": actions})
	# The normal combo-two battle has 1+2+1+2 = 6 accepted pulls.
	if strength == 3 and rounds.size() == 4:
		rounds[0].actions = 1
		rounds[1].actions = 2
		rounds[2].actions = 1
		rounds[3].actions = 2
	round_index = 0
	action_progress = 0
	done = rounds.is_empty()
	last_success = false
	last_event = ""
	phase_t = 0.0
	grace_t = 0.85
	_update_goal()

func total_actions() -> int:
	var total := 0
	for round_data in rounds: total += int(round_data.actions)
	return total

func current_game() -> int:
	if done or round_index >= rounds.size(): return Game.FINISH
	return int(rounds[round_index].type)

func current_game_name() -> String:
	match current_game():
		Game.SHRINKING_RING: return "SHRINKING RING"
		Game.MOVING_ZONE: return "MOVING SAFE ZONE"
		Game.SLALOM: return "TIDE SLALOM"
		Game.FINISH: return "FINISHING RHYTHM"
		_: return "FISHING"

func instructions() -> String:
	match current_game():
		Game.SHRINKING_RING: return "SPACE when the moving gauge is inside the shrinking ring"
		Game.MOVING_ZONE: return "SPACE while the gauge overlaps the moving safe zone"
		Game.SLALOM: return "Hold the shown arrow to steer around the tide buoys, then SPACE"
		Game.FINISH: return "Tap SPACE on each beat to finish the catch"
		_: return "Keep the line steady"

func round_label() -> String:
	if done: return "CHAIN CLEAR"
	return "ROUND %d/%d  ·  %s" % [round_index + 1, rounds.size(), current_game_name()]

func progress_text() -> String:
	return "%d/%d beats" % [action_progress, action_goal]

func target_center() -> float:
	# These values are intentionally forgiving for the first 0.85 seconds so a
	# player can read the instruction before the target starts moving in earnest.
	match current_game():
		Game.SHRINKING_RING: return 0.50
		Game.MOVING_ZONE: return 0.50 + sin(phase_t * 2.1) * 0.16
		Game.SLALOM: return 0.50 + sin(phase_t * 3.2) * 0.20
		Game.FINISH: return 0.50
		_: return 0.50

func target_width() -> float:
	match current_game():
		Game.SHRINKING_RING: return maxf(0.21, 0.43 - phase_t * 0.07)
		Game.MOVING_ZONE: return 0.38
		Game.SLALOM: return 0.34
		Game.FINISH: return 0.22
		_: return 0.40

func safe_lane() -> float:
	# Slalom's lane shifts left/right. Holding the opposite direction counters
	# the fish; a centred stick is always a valid beginner lane.
	var lane := 0.0
	if phase_t > 0.9: lane = -1.0 if int(phase_t * 1.9) % 2 == 0 else 1.0
	return lane

func tick(delta: float, counter_axis: float = 0.0) -> void:
	if done: return
	phase_t += maxf(0.0, delta)
	grace_t = maxf(0.0, grace_t - maxf(0.0, delta))
	# Countering the slalom direction gives a little breathing room. This is
	# feedback only; the line tension model in main.gd remains authoritative.
	if current_game() == Game.SLALOM and absf(counter_axis) > 0.25:
		phase_t = maxf(0.0, phase_t - delta * 0.24)

func accept(position: float, counter_axis: float = 0.0) -> Dictionary:
	if done: return {"success": false, "complete": true, "round_complete": false, "event": "chain already clear"}
	var p := clampf(position, 0.0, 1.0)
	var target := target_center()
	var half_width := target_width() * 0.5
	var valid := absf(p - target) <= half_width
	if current_game() == Game.SLALOM:
		# A centre-lane press is a safe fallback; a held counter steers toward
		# the lane. This prevents a single missed direction from killing a catch.
		var lane := safe_lane()
		var steered_lane := clampf(counter_axis, -1.0, 1.0)
		valid = valid and (absf(lane) < 0.5 or absf(steered_lane - lane) < 0.7 or absf(steered_lane) < 0.2)
	if grace_t > 0.0: valid = true
	last_success = valid
	if not valid:
		last_event = "The line jolts — recover and try the next beat"
		return {"success": false, "complete": false, "round_complete": false, "event": last_event}
	action_progress += 1
	last_event = "CLEAN %s  %s" % [current_game_name(), progress_text()]
	if action_progress >= action_goal:
		var completed_name := current_game_name()
		round_index += 1
		action_progress = 0
		if round_index >= rounds.size():
			done = true
			last_event = "CHAIN CLEAR  /  %s" % completed_name
			return {"success": true, "complete": true, "round_complete": true, "event": last_event}
		_update_goal()
		phase_t = 0.0
		grace_t = 0.85
		last_event = "ROUND CLEAR  /  %s" % completed_name
		return {"success": true, "complete": false, "round_complete": true, "event": last_event}
	return {"success": true, "complete": false, "round_complete": false, "event": last_event}

func _update_goal() -> void:
	if done or round_index >= rounds.size():
		action_goal = 0
	else:
		action_goal = int(rounds[round_index].actions)
