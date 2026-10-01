extends Node2D

const FishingChallengeScript = preload("res://fishing_challenge.gd")
const MusicDirectorScript = preload("res://audio/music_director.gd")
const LegendaryRevealTiming = preload("res://legendary_reveal_timing.gd")

# The tide ledger treats every species as a small collectable card.  The
# portraits are intentionally compact, palette-limited PNGs so they stay crisp
# at the 480x270 viewport and still read on the paper ledger.
const FISH_SPECIES := [
	{"name":"Sand goby", "rarity":"COMMON", "art":"sand_goby", "description":"A shy bottom-dweller that loves warm sand."},
	{"name":"Silver sprat", "rarity":"UNCOMMON", "art":"silver_sprat", "description":"A bright schooling fish that flashes at the surface."},
	{"name":"Coral bream", "rarity":"UNCOMMON", "art":"coral_bream", "description":"A reef wanderer with sunset stripes."},
	{"name":"Moonfin trout", "rarity":"RARE", "art":"moonfin_trout", "description":"Its crescent fin glows under a clear night tide."},
	{"name":"Rainbow Kingfish", "rarity":"LEGENDARY", "art":"rainbow_kingfish", "description":"A once-in-a-season trophy from the deep."}
]

# Original v2 world dimensions retained; viewport now shows a walkable slice.
const TILE := 16
const WORLD_W := 64
const WORLD_H := 40
const WORLD_SIZE := Vector2(WORLD_W*TILE, WORLD_H*TILE)
const SAVE_PATH := "user://saltmere_save.json"
var player := Vector2(368, 372)
var current_map := "town"
var transition_active := false
var transition_t := 0.0
var transition_target := ""
var transition_spawn := Vector2.ZERO
var transition_fade := 0.0
var speed := 78.0
var fish_count := 0
var day := 1
var time_of_day := 0.35
var notebook_open := false
var toast := "Follow the path east, then south to the pier"
var toast_t := 5.0
var rng := RandomNumberGenerator.new()
var cam := Camera2D.new()
var terrain: Texture2D
var hero: Texture2D
var props: Array[Dictionary] = []
var solids: Array[Rect2] = []
var landmarks: Array[Dictionary] = []
var textures: Dictionary = {}
var fish_portraits: Dictionary = {}
var fish_cards: Dictionary = {}
var face := 0
var walk_time := 0.0
var walking := false
var elapsed := 0.0
var cast_timer := 0.0
var catches: Dictionary = {}
# Fishing is a short, deterministic-feeling arcade loop: cast, wait for a bite,
# then tap SPACE while the moving gauge crosses the sweet spot.
enum FishingState { IDLE, ANTICIPATING, TIMING, RESULT }
var fishing_state: FishingState = FishingState.IDLE
var bite_timer := 0.0
var bite_delay := 1.1
var timing_timer := 0.0
var timing_window := 0.72
var gauge := 0.0
var gauge_direction := 1.0
var fish_hp := 0
var fish_hp_max := 0
var battle_hits := 0
var battle_required := 4
var battle_elapsed := 0.0
var pull_cooldown := 0.0
var perfect_pulls := 0
var direction_timer := 0.0
var battle_tension := 0.0
var battle_escape := 0.0
var battle_direction := 1.0
var combo := 0
var last_grade := ""
var last_catch := ""
var last_rarity := ""
var result_t := 0.0
var flash_t := 0.0
var shake_t := 0.0
var fish_particle_t := 0.0
var legendary_t := 0.0
var legendary_stage := 0
# Every successful, non-legendary catch now gets a short, readable reveal:
# card back -> rarity -> growing silhouette -> flip.  The timer is separate
# from result_t so the existing result/input pacing stays intact.
var reveal_t := 0.0
var reveal_stage := 0
var fishing_challenge: FishingChallenge
var challenge_strength := 1
var challenge_round_event := ""
var challenge_hint_t := 0.0
var music: Node
var se_player := AudioStreamPlayer.new()
const SE_RATE := 22050.0
var hud := Node2D.new()

func _music_call(method: String, args: Array = []) -> void:
	# Music is an optional child so older exported checkouts can still boot. Keep
	# gameplay independent from the director while routing all state changes
	# through one guarded call site.
	if music == null or not is_instance_valid(music) or not music.has_method(method):
		return
	music.callv(method, args)

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain = load("res://assets/terrain.png")
	hero = load("res://assets/hero.png")
	for asset in ["cottage", "inn", "shop", "tree0", "tree1", "tree2", "barrel", "sign", "rock", "well", "reeds"]:
		textures[asset] = load("res://assets/" + asset + ".png")
	for species in FISH_SPECIES:
		var art_name := str(species.get("art", ""))
		var portrait := load("res://assets/fish/" + art_name + ".png")
		if portrait != null:
			fish_portraits[str(species.name)] = portrait
		var card := load("res://assets/fish_cards/" + art_name + ".png")
		if card != null:
			fish_cards[str(species.name)] = card
	_build_world()
	cam.position = player.round()
	cam.position_smoothing_enabled = false
	cam.limit_left = 0; cam.limit_top = 0
	cam.limit_right = int(WORLD_SIZE.x); cam.limit_bottom = int(WORLD_SIZE.y)
	add_child(cam)
	var layer := CanvasLayer.new()
	add_child(layer); layer.add_child(hud); hud.draw.connect(_draw_hud)
	# Keep the arcade feedback self-contained: the short SE are synthesized in
	# memory, so the game has no external audio-file dependency.
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SE_RATE
	generator.buffer_length = 0.8
	se_player.stream = generator
	se_player.volume_db = -8.0
	add_child(se_player)
	se_player.play()
	# The field loop is layered at runtime. MusicDirector is optional while the
	# prototype is being opened from an older checkout, so keep gameplay usable
	# if that script has not been imported yet.
	if ResourceLoader.exists("res://audio/music_director.gd"):
		music = MusicDirectorScript.new()
		add_child(music)
		_music_call("start_field")
	rng.randomize()
	if not OS.get_cmdline_user_args().has("--fresh"):
		_load_game()
	queue_redraw()

func _build_world():
	_build_map(current_map)

func _build_map(map_name: String):
	props.clear(); solids.clear(); landmarks.clear()
	if map_name == "beach":
		_build_beach()
	elif map_name == "rocky":
		_build_rocky()
	else:
		_build_town()

func _build_town():
	landmarks = [{"kind":"pier","pos":Vector2(502,500),"label":"Old Salt Pier"}]
	_add_prop("inn", Vector2(240,322), Rect2(-32,-40,64,37))
	_add_prop("cottage", Vector2(424,320), Rect2(-25,-29,50,25))
	_add_prop("shop", Vector2(550,335), Rect2(-25,-29,50,25))
	_add_prop("cottage", Vector2(254,228), Rect2(-25,-29,50,25))
	_add_prop("well", Vector2(366,401), Rect2(-10,-16,20,14))
	_add_prop("sign", Vector2(468,381), Rect2(-6,-9,12,9))
	for pos in [Vector2(296,323),Vector2(306,337),Vector2(582,337),Vector2(475,452)]:
		_add_prop("barrel",pos,Rect2(-7,-17,14,16))
	var tree_positions: Array[Vector2] = [Vector2(183,298),Vector2(194,232),Vector2(313,228),Vector2(316,280),Vector2(463,260),Vector2(498,278),Vector2(593,292),Vector2(172,378),Vector2(206,400),Vector2(286,410),Vector2(608,387),Vector2(663,359)]
	for x in range(45,803,35):
		tree_positions.append(Vector2(x,76 + (x%3)*11))
		tree_positions.append(Vector2(x+12,126 + (x%5)*6))
	for y in range(165,409,35):
		tree_positions.append(Vector2(56 + y%19,y))
		tree_positions.append(Vector2(772 + y%25,y))
	for i in range(tree_positions.size()):
		_add_prop("tree%d" % (i%3),tree_positions[i],Rect2(-6,-12,12,12))
	for pos in [Vector2(110,446),Vector2(130,439),Vector2(661,461),Vector2(737,446),Vector2(711,420)]:
		_add_prop("rock",pos,Rect2(-10,-13,20,12))
	for i in range(13):
		_add_prop("reeds",Vector2(791+(i%3)*11,287+i*10),Rect2())
	props.sort_custom(func(a,b): return a.pos.y < b.pos.y)

func _build_beach():
	# Amber beach: dunes, driftwood and a broad north entrance from town.
	landmarks = [
		{"kind":"driftwood","pos":Vector2(146,430),"label":"Driftwood Cove"},
		{"kind":"pool","pos":Vector2(300,480),"label":"North Tide Pool"},
		{"kind":"pool","pos":Vector2(620,480),"label":"South Tide Pool"}
	]
	_add_prop("cottage", Vector2(260,190), Rect2(-25,-29,50,25))
	_add_prop("barrel", Vector2(322,232), Rect2(-7,-17,14,16))
	_add_prop("sign", Vector2(392,92), Rect2(-6,-9,12,9))
	for x in range(70,790,42):
		_add_prop("rock", Vector2(x,270+(x%5)*21), Rect2(-10,-13,20,12))
	for x in range(90,760,58):
		_add_prop("tree%d" % (int(x/58)%3), Vector2(x,90+(x%4)*25), Rect2(-6,-12,12,12))
	for i in range(14):
		_add_prop("reeds", Vector2(760+(i%3)*11,260+i*10), Rect2())
	props.sort_custom(func(a,b): return a.pos.y < b.pos.y)

func _build_rocky():
	# Rocky shore: sparse windblown trees and stone shelves.
	landmarks = [
		{"kind":"breakwater","pos":Vector2(310,420),"label":"Stone Breakwater"},
		{"kind":"pool","pos":Vector2(170,585),"label":"Blackglass Pool"},
		{"kind":"pool","pos":Vector2(520,573),"label":"Gull's Pool"},
		{"kind":"lighthouse","pos":Vector2(704,154),"label":"Farwatch Lighthouse"}
	]
	_add_prop("inn", Vector2(585,170), Rect2(-32,-40,64,37))
	_add_prop("sign", Vector2(120,102), Rect2(-6,-9,12,9))
	# A future-route sign keeps the lighthouse legible before that region is playable.
	_add_prop("sign", Vector2(632,232), Rect2())
	for x in range(70,760,52):
		_add_prop("rock", Vector2(x,250+(x%6)*25), Rect2(-10,-13,20,12))
	for x in range(130,760,95):
		_add_prop("tree%d" % (int(x/95)%3), Vector2(x,90+(x%3)*28), Rect2(-6,-12,12,12))
	for i in range(12):
		_add_prop("barrel", Vector2(340+(i%4)*18,420+i*9), Rect2(-7,-17,14,16))
	props.sort_custom(func(a,b): return a.pos.y < b.pos.y)

func _add_prop(kind: String, pos: Vector2, body: Rect2):
	props.append({"kind":kind,"pos":pos})
	if body.size != Vector2.ZERO: solids.append(Rect2(pos+body.position,body.size))

func _shore(x: float) -> float:
	if current_map == "beach": return 500.0
	if current_map == "rocky": return 620.0 - (int(x/96.0)%3)*12
	if x < 240: return 464
	if x < 416: return 480
	if x < 608: return 464
	if x < 752: return 448
	return 432

func _walkable(pos: Vector2) -> bool:
	# Feet collision: canopy overlap is intentional for top-down depth.
	var feet := Rect2(pos-Vector2(4,3),Vector2(8,5))
	for c in [feet.position,feet.position+Vector2(8,0),feet.end,feet.position+Vector2(0,5)]:
		var on_pier: bool = c.x >= 486 and c.x <= 518 and c.y >= 440 and c.y <= 545
		if not on_pier and (c.x < 28 or c.x >= 828 or c.y < 28 or c.y >= _shore(c.x)-4): return false
	for body in solids:
		if body.intersects(feet): return false
	return true

func _move_player(dir: Vector2, delta: float):
	# Substeps prevent tunnelling at low frame rates.
	var motion := dir.limit_length() * speed * minf(delta,0.1)
	var steps := maxi(1,ceili(motion.length()/3.0))
	for i in range(steps):
		var step := motion/steps
		if _walkable(player+Vector2(step.x,0)): player.x += step.x
		if _walkable(player+Vector2(0,step.y)): player.y += step.y

func _process(delta):
	elapsed += delta
	if transition_active:
		transition_t += delta
		transition_fade = minf(1.0, transition_t / 0.22)
		if transition_t >= 0.44:
			current_map = transition_target
			_build_map(current_map)
			player = transition_spawn
			transition_active = false
			transition_fade = 0.0
			toast = "Arrived at " + current_map.capitalize()
			toast_t = 2.0
		queue_redraw(); hud.queue_redraw()
		return
	if Input.is_action_just_pressed("notebook"):
		notebook_open = not notebook_open
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	walking = dir.length() > 0 and not notebook_open and fishing_state == FishingState.IDLE
	if walking:
		_move_player(dir,delta)
		walk_time += delta
		if absf(dir.x) > absf(dir.y): face = 2 if dir.x < 0 else 3
		else: face = 1 if dir.y < 0 else 0
		_check_map_exit()
	if not notebook_open:
		if Input.is_action_just_pressed("fish") and fishing_state == FishingState.IDLE:
			_try_fish()
		_process_fishing(delta)
	if Input.is_action_just_pressed("save_game"): _save_game()
	toast_t = maxf(0.0, toast_t-delta)
	cam.position = player.round()
	if shake_t > 0.0:
		var shake_power := 8.0 if last_rarity == "LEGENDARY" else (4.0 if last_rarity == "RARE" else 2.0)
		cam.offset = Vector2(sin(elapsed*80.0), cos(elapsed*71.0)) * shake_power * minf(1.0, shake_t*8.0)
	else:
		cam.offset = Vector2.ZERO
	queue_redraw(); hud.queue_redraw()

func _check_map_exit():
	if transition_active: return
	var exit := ""
	if current_map == "town":
		# The south road meets the shoreline around y=440; keep the exit on walkable land.
		if player.y > 438 and player.x > 450 and player.x < 550: exit = "beach"
		elif player.x > 798 and player.y > 250 and player.y < 430: exit = "rocky"
	elif current_map == "beach":
		if player.y < 34 and player.x > 280 and player.x < 560: exit = "town"
		elif player.x > 798 and player.y > 280 and player.y < 560: exit = "rocky"
	elif current_map == "rocky":
		if player.x < 34 and player.y > 250 and player.y < 430: exit = "town"
		elif player.y > 420 and player.x > 280 and player.x < 560: exit = "beach"
	if exit != "":
		var spawn := _entry_spawn(exit)
		_transition_to(exit, spawn)

func _entry_spawn(map_name: String) -> Vector2:
	if current_map == "town" and map_name == "beach": return Vector2(400,80)
	if current_map == "town" and map_name == "rocky": return Vector2(90,340)
	if current_map == "beach" and map_name == "town": return Vector2(500,520)
	if current_map == "beach" and map_name == "rocky": return Vector2(90,340)
	if current_map == "rocky" and map_name == "town": return Vector2(760,340)
	return Vector2(400,80)

func transition_to_map(map_name: String, spawn: Vector2):
	_transition_to(map_name, spawn)

func _transition_to(map_name: String, spawn: Vector2):
	if map_name == current_map: return
	transition_target = map_name; transition_spawn = spawn; transition_t = 0.0
	transition_fade = 0.0; transition_active = true
	toast = "Travelling to " + map_name.capitalize() + "..."; toast_t = 1.0

func _can_fish() -> bool:
	for spot in _fishing_spots():
		if player.distance_to(spot.pos) <= 24.0: return true
	return (player.y >= _shore(player.x)-21 and player.x>70 and player.x<810)

func _fishing_spots() -> Array[Dictionary]:
	match current_map:
		"town": return [{"pos":Vector2(502,530),"label":"Old Salt Pier"}]
		"beach": return [
			{"pos":Vector2(300,487),"label":"North Tide Pool"},
			{"pos":Vector2(620,487),"label":"South Tide Pool"}
		]
		"rocky": return [
			{"pos":Vector2(170,590),"label":"Blackglass Pool"},
			{"pos":Vector2(520,578),"label":"Gull's Pool"}
		]
		_: return []

func _try_fish():
	if notebook_open: return
	if fishing_state == FishingState.RESULT:
		_reset_fishing()
		return
	if fishing_state != FishingState.IDLE: return
	if _can_fish():
		fishing_state = FishingState.ANTICIPATING
		cast_timer = 1.8
		bite_delay = rng.randf_range(0.72, 1.42)
		bite_timer = 0.0
		face = 0
		toast = "Line out... wait for a bite!"
		toast_t = 2.0
		_music_call("start_fishing", [combo])
		_play_se("cast")
	else:
		toast = "Cast from the water's edge or the end of the pier"; toast_t = 3.0

func _process_fishing(delta: float):
	if fishing_state == FishingState.ANTICIPATING:
		bite_timer += delta
		cast_timer = maxf(0.0, cast_timer-delta)
		if bite_timer >= bite_delay:
			fishing_state = FishingState.TIMING
			# A bite opens a short tug-of-war instead of a one-frame skill check.
			# The fish must be controlled through several good inputs.
			fish_hp_max = 10 + mini(combo, 4)
			fish_hp = fish_hp_max
			battle_hits = 0
			battle_required = fish_hp_max
			battle_elapsed = 0.0
			pull_cooldown = 1.0
			perfect_pulls = 0
			direction_timer = 2.0
			battle_tension = 0.22
			battle_escape = 0.0
			battle_direction = -1.0 if rng.randf() < 0.5 else 1.0
			timing_timer = 20.0
			gauge = 0.0
			gauge_direction = 1.0
			# The challenge chain sits on top of the existing tug-of-war.  A
			# growing combo asks for more varied beats, while the line tension and
			# stamina model below remain authoritative for the actual catch.
			challenge_strength = clampi(combo + 1, 1, 3)
			fishing_challenge = FishingChallengeScript.new()
			fishing_challenge.configure(challenge_strength, combo, rng.randi())
			challenge_round_event = fishing_challenge.round_label()
			challenge_hint_t = 2.4
			toast = "BITE!  Keep the line in the gold zone!"
			toast_t = 2.0
			flash_t = 0.12
			_play_se("bite")
			_play_se("battle_start")
		elif Input.is_action_just_pressed("fish"):
			# Early taps are ignored so anticipation remains readable.
			toast = "Not yet... watch the float"
			toast_t = 0.6
	elif fishing_state == FishingState.TIMING:
		timing_timer -= delta
		# The fish surges against the line. The moving target gets more urgent
		# as tension rises, giving each pull a readable battle rhythm.
		battle_elapsed += delta
		pull_cooldown = maxf(0.0, pull_cooldown - delta)
		direction_timer -= delta
		if direction_timer <= 0.0:
			battle_direction = -battle_direction
			direction_timer = rng.randf_range(2.0, 3.3)
		var counter := Input.get_axis("move_left", "move_right")
		var countering := counter * battle_direction < -0.25
		var straining := counter * battle_direction > 0.25
		if fishing_challenge != null and not fishing_challenge.done:
			fishing_challenge.tick(delta, counter)
			challenge_hint_t = maxf(0.0, challenge_hint_t-delta)
		battle_escape = clampf(battle_escape + delta * (-0.035 if countering else (0.095 if straining else 0.055)), 0.0, 1.0)
		battle_tension = clampf(battle_tension + delta * (-0.045 if countering else (0.07 if straining else -0.014)), 0.0, 1.0)
		gauge += delta * (1.25 + battle_tension * 0.75) * gauge_direction
		if gauge >= 1.0: gauge = 1.0; gauge_direction = -1.0
		if gauge <= 0.0: gauge = 0.0; gauge_direction = 1.0
		if timing_timer <= 0.0 or battle_tension >= 1.0 or battle_escape >= 1.0:
			# Running out of line is a miss even if the fish was nearly tired.
			_resolve_fishing_timing(-1.0)
		elif Input.is_action_just_pressed("fish"):
			_handle_fishing_strike(gauge, counter)
	elif fishing_state == FishingState.RESULT:
		result_t -= delta
		if Input.is_action_just_pressed("fish"):
			_reset_fishing()
		if last_rarity == "LEGENDARY":
			var previous_legendary_t := legendary_t
			legendary_t = minf(legendary_t + delta, LegendaryRevealTiming.DURATION)
			reveal_t = legendary_t
			reveal_stage = _reveal_stage_at(reveal_t, last_rarity)
			legendary_stage = reveal_stage
			if previous_legendary_t < LegendaryRevealTiming.RARITY_AT and legendary_t >= LegendaryRevealTiming.RARITY_AT:
				_play_se("seal")
			if previous_legendary_t < LegendaryRevealTiming.RISE_AT and legendary_t >= LegendaryRevealTiming.RISE_AT:
				_play_se("rise")
			if previous_legendary_t < LegendaryRevealTiming.HOLD_AT and legendary_t >= LegendaryRevealTiming.HOLD_AT:
				_play_se("suspense")
			if previous_legendary_t < LegendaryRevealTiming.FLIP_AT and legendary_t >= LegendaryRevealTiming.FLIP_AT:
				_play_se("flip")
			if previous_legendary_t < LegendaryRevealTiming.REVEAL_AT and legendary_t >= LegendaryRevealTiming.REVEAL_AT:
				_play_se("peak")
				shake_t = maxf(shake_t, 0.7)
				toast = "BIG CATCH!!  " + last_catch + "  /  SPACE to continue"
			if previous_legendary_t < LegendaryRevealTiming.AFTERGLOW_AT and legendary_t >= LegendaryRevealTiming.AFTERGLOW_AT:
				_play_se("after")
		elif last_grade != "MISS":
			var previous_reveal_t := reveal_t
			reveal_t = minf(reveal_t + delta, 2.0)
			reveal_stage = _reveal_stage_at(reveal_t, last_rarity)
			# A single gentle chime marks the flip; no rapid white flashes.
			if previous_reveal_t < 1.48 and reveal_t >= 1.48:
				_play_se("rise")
	flash_t = maxf(0.0, flash_t-delta)
	shake_t = maxf(0.0, shake_t-delta)
	fish_particle_t += delta

# Stage boundaries are fixed so a seed, frame rate, or renderer cannot change
# the order of the reveal.  Legendary reuses its existing six-second timing;
# standard catches fit the same two-second result window they had before.
func _reveal_stage_at(time: float, rarity: String) -> int:
	if rarity == "LEGENDARY":
		return LegendaryRevealTiming.stage_at(time)
	if time < 0.42: return 0 # card back and ???
	if time < 0.82: return 1 # rarity seal
	if time < 1.42: return 2 # growing silhouette/light
	if time < 1.78: return 3 # card flip
	return 4 # fish name revealed

func reveal_stage_name() -> String:
	if last_rarity == "LEGENDARY":
		match reveal_stage:
			0: return "UNKNOWN"
			1: return "RARITY"
			2: return "RISING"
			3: return "HOLD"
			4: return "FLIPPING"
			5: return "CLIMAX"
			6: return "AFTERGLOW"
			_: return "UNKNOWN"
	match reveal_stage:
		0: return "UNKNOWN"
		1: return "RARITY"
		2: return "RISING"
		3: return "FLIPPING"
		4: return "REVEALED"
		_: return "UNKNOWN"

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"RARE": return Color("#72c7e8")
		"UNCOMMON": return Color("#8bd59c")
		"LEGENDARY": return Color("#f6c76b")
		_: return Color("#b7c3d7")

func _fish_info(species_name: String) -> Dictionary:
	for species in FISH_SPECIES:
		if str(species.get("name", "")) == species_name:
			return species
	return {"name": species_name, "rarity": "COMMON", "art": "", "description": "A fish from the Saltmere tide."}

func _fish_rarity(species_name: String) -> String:
	return str(_fish_info(species_name).get("rarity", "COMMON"))

func _fish_description(species_name: String) -> String:
	return str(_fish_info(species_name).get("description", ""))

func _roll_fish_species(grade: String, roll: float) -> String:
	# Perfect pulls can surface the rarer cards more often, while every normal
	# cast still has a clear path to the new Coral bream card.
	if grade == "PERFECT":
		if roll > 0.74: return "Moonfin trout"
		if roll > 0.50: return "Coral bream"
		if roll > 0.25: return "Silver sprat"
		return "Sand goby"
	if roll > 0.86: return "Silver sprat"
	if roll > 0.61: return "Coral bream"
	return "Sand goby"

func _draw_fish_portrait(center: Vector2, species_name: String, scale: float = 1.0, modulate := Color.WHITE):
	var portrait: Texture2D = fish_portraits.get(species_name)
	if portrait == null:
		_draw_reveal_fish(center, scale, _rarity_color(_fish_rarity(species_name)), true)
		return
	var size := Vector2(portrait.get_width(), portrait.get_height()) * scale
	hud.draw_texture_rect(portrait, Rect2(center - size * 0.5, size), false, modulate)

func _draw_fish_card(center: Vector2, species_name: String, card_size: Vector2, modulate := Color.WHITE):
	# The concept-sheet illustration is deliberately kept separate from the
	# tiny pixel portrait used by the ledger. Fit the larger card art without
	# stretching its hand-pixeled proportions, so fins stay crisp on the reveal.
	var card: Texture2D = fish_cards.get(species_name)
	if card == null:
		_draw_fish_portrait(center, species_name, minf(card_size.x / 96.0, card_size.y / 64.0), modulate)
		return
	var source_size := Vector2(card.get_width(), card.get_height())
	var fit := minf(card_size.x / source_size.x, card_size.y / source_size.y)
	var draw_size := source_size * fit
	hud.draw_texture_rect(card, Rect2(center - draw_size * 0.5, draw_size), false, modulate)

func _resolve_fishing_timing(position: float):
	var grade := "MISS"
	if position >= 0.42 and position <= 0.62: grade = "PERFECT"
	elif position >= 0.26 and position <= 0.80: grade = "GOOD"
	if grade == "MISS":
		combo = 0
		last_catch = "The fish got away"
		last_rarity = ""
		last_grade = grade
		fishing_state = FishingState.RESULT
		cast_timer = 0.0
		result_t = 1.3
		shake_t = 0.12
		_music_call("set_combo", [0])
		_music_call("start_field")
		_play_se("miss")
		toast = "MISS!  Tap SPACE to cast again"
		toast_t = result_t
		return
	combo += 1
	last_grade = grade
	var roll := rng.randf()
	var legendary := grade == "PERFECT" and combo >= 3
	var result := "Rainbow Kingfish" if legendary else _roll_fish_species(grade, roll)
	last_catch = result
	last_rarity = _fish_rarity(result)
	_music_call("set_combo", [combo])
	_music_call("play_fanfare", [legendary])
	fish_count += 1
	catches[result] = int(catches.get(result,0))+1
	fishing_state = FishingState.RESULT
	cast_timer = 0.0
	legendary_t = 0.0
	legendary_stage = 0
	reveal_t = 0.0
	reveal_stage = 0
	result_t = LegendaryRevealTiming.DURATION if legendary else 2.0
	flash_t = 0.90 if last_rarity == "LEGENDARY" else (0.32 if last_rarity == "RARE" else 0.18)
	shake_t = 1.10 if last_rarity == "LEGENDARY" else (0.22 if last_rarity == "RARE" else 0.10)
	_play_se("omen" if legendary else "catch")
	toast = "A sealed catch... something waits inside" if legendary else grade + "!  " + last_catch + "  /  SPACE to cast again"
	toast_t = result_t

func _handle_fishing_strike(position: float, counter_axis: float = 0.0):
	if pull_cooldown > 0.0: return
	pull_cooldown = 1.8

	# Challenge beats are deliberately forgiving and resolve before the normal
	# gauge grade.  A missed beat strains the same authoritative line model as a
	# missed gold-zone pull; it never bypasses the existing escape/tension rules.
	if fishing_challenge != null and not fishing_challenge.done:
		var challenge_result := fishing_challenge.accept(position, counter_axis)
		challenge_round_event = str(challenge_result.get("event", ""))
		challenge_hint_t = 1.1
		if not bool(challenge_result.get("success", false)):
			battle_tension = clampf(battle_tension + 0.25, 0.0, 1.0)
			battle_escape = clampf(battle_escape + 0.12, 0.0, 1.0)
			shake_t = 0.24
			_play_se("danger")
			toast = "CHALLENGE MISSED!  " + challenge_round_event
			toast_t = 1.2
			if battle_tension >= 1.0 or battle_escape >= 1.0:
				_resolve_fishing_timing(-1.0)
			return
		if bool(challenge_result.get("round_complete", false)):
			_play_se("perfect_tug")

	# A pull outside the teal band strains the line. Inside it, each successful
	# input wears down the fish and raises the spectacle toward the final catch.
	var grade := "MISS"
	if position >= 0.42 and position <= 0.62: grade = "PERFECT"
	elif position >= 0.26 and position <= 0.80: grade = "GOOD"
	if grade == "MISS":
		battle_tension = clampf(battle_tension + 0.33, 0.0, 1.0)
		battle_escape = clampf(battle_escape + 0.16, 0.0, 1.0)
		shake_t = 0.28
		_play_se("danger")
		toast = "LINE STRAIN! Counter the fish, then try again"
		toast_t = 1.2
		if battle_tension >= 1.0 or battle_escape >= 1.0:
			_resolve_fishing_timing(-1.0)
		return
	battle_hits += 1
	# Let each clean pull add a layer during the same encounter; the retained
	# catch combo remains the starting energy for the next cast.
	_music_call("set_combo", [mini(4, combo + battle_hits)])
	if grade == "PERFECT": perfect_pulls += 1
	fish_hp = maxi(0, fish_hp - (2 if grade == "PERFECT" else 1))
	battle_tension = clampf(battle_tension + (0.08 if grade == "PERFECT" else 0.14), 0.0, 1.0)
	battle_escape = maxf(0.0, battle_escape - (0.24 if grade == "PERFECT" else 0.11))
	gauge_direction = -gauge_direction
	shake_t = maxf(shake_t, 0.14 + battle_hits * 0.06)
	flash_t = maxf(flash_t, 0.10 + battle_hits * 0.025)
	_play_se("perfect_tug" if grade == "PERFECT" else "tug")
	if fish_hp <= 0:
		# Preserve the strongest grade across the battle for rarity/combos.
		_resolve_fishing_timing(0.5 if perfect_pulls * 2 >= battle_hits else 0.34)
		return
	toast = ("PERFECT PULL!  " if grade == "PERFECT" else "GOOD PULL!  ") + "Fish stamina %d/%d" % [fish_hp, fish_hp_max]
	toast_t = 0.9

func _play_se(kind: String):
	# Tiny procedural chimes keep the feedback punchy while avoiding bundled
	# copyrighted assets. In headless tests the audio server may be absent, so
	# every step is guarded and simply becomes a no-op there.
	if se_player == null or se_player.stream == null: return
	var playback := se_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null: return
	var duration := 0.18
	var base := 280.0
	var volume := 0.22
	var sweep := 0.0
	var tones: Array = []
	match kind:
		"cast":
			base = 220.0; duration = 0.16; volume = 0.16
		"bite":
			base = 540.0; duration = 0.22; volume = 0.24; tones = [810.0]
		"battle_start":
			base = 420.0; duration = 0.30; volume = 0.25; sweep = 260.0; tones = [630.0]
		"tug":
			base = 300.0 + battle_hits * 55.0; duration = 0.17; volume = 0.25; tones = [base * 1.5]
		"perfect_tug":
			base = 500.0 + battle_hits * 70.0; duration = 0.24; volume = 0.34; sweep = 180.0; tones = [base * 1.5, base * 2.0]
		"danger":
			base = 120.0; duration = 0.28; volume = 0.28; sweep = -70.0
		"miss":
			base = 150.0; duration = 0.28; volume = 0.22; sweep = -55.0
		"catch":
			base = 520.0; duration = 0.34; volume = 0.26; sweep = 180.0; tones = [780.0]
		"legendary":
			base = 330.0; duration = 0.52; volume = 0.36; sweep = 260.0; tones = [495.0, 660.0, 990.0]
		"omen":
			base = 146.8; duration = 0.56; volume = 0.24; sweep = 18.0; tones = [220.0]
		"seal":
			base = 440.0; duration = 0.42; volume = 0.26; tones = [660.0, 880.0]
		"suspense":
			base = 110.0; duration = 0.28; volume = 0.12; sweep = -22.0
		"flip":
			base = 350.0; duration = 0.32; volume = 0.27; sweep = 880.0
		"rise":
			base = 620.0; duration = 0.44; volume = 0.38; sweep = 480.0; tones = [930.0, 1240.0]
		"peak":
			base = 261.6; duration = 0.72; volume = 0.44; sweep = 80.0; tones = [329.6, 392.0, 523.2, 659.2]
		"after":
			base = 783.9; duration = 0.64; volume = 0.28; sweep = -260.0; tones = [523.2, 392.0]
		_: return
	var frames := int(duration * SE_RATE)
	for i in range(frames):
		if not playback.can_push_buffer(1): break
		var t := float(i) / SE_RATE
		var progress := clampf(t / duration, 0.0, 1.0)
		var freq := maxf(45.0, base + sweep * progress)
		var sample := sin(TAU * freq * t) * 0.72
		for tone in tones:
			sample += sin(TAU * float(tone) * t) * 0.24
		# Quick attack and musical tail; no click at the boundaries.
		var envelope := minf(1.0, t / 0.018) * minf(1.0, (duration - t) / 0.06)
		playback.push_frame(Vector2.ONE * sample * volume * envelope)

func _finish_cast():
	# Compatibility helper for old saves/tests: resolve a generous GOOD hit.
	if fishing_state == FishingState.IDLE: combo = 0
	_resolve_fishing_timing(0.5)

func _reset_fishing():
	fishing_state = FishingState.IDLE
	_music_call("start_field")
	cast_timer = 0.0
	bite_timer = 0.0
	timing_timer = 0.0
	last_grade = ""
	last_catch = ""
	last_rarity = ""
	legendary_t = 0.0
	legendary_stage = 0
	reveal_t = 0.0
	reveal_stage = 0
	fish_hp = 0
	fish_hp_max = 0
	battle_hits = 0
	battle_required = 4
	battle_elapsed = 0.0
	pull_cooldown = 0.0
	perfect_pulls = 0
	direction_timer = 0.0
	battle_tension = 0.0
	battle_escape = 0.0
	fishing_challenge = null
	challenge_strength = 1
	challenge_round_event = ""
	challenge_hint_t = 0.0
	toast = "Ready to cast"
	toast_t = 1.2

func _save_game(path: String = SAVE_PATH):
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		toast = "Could not save. Please check available storage."; toast_t = 4; return
	f.store_string(JSON.stringify({"version":4,"map":current_map,"day":day,"time":time_of_day,"fish":fish_count,"x":player.x,"y":player.y,"catches":catches}))
	toast = "Saved to the tide ledger"; toast_t = 2.4

func _load_game(path: String = SAVE_PATH):
	if not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	var loaded_map := str(data.get("map","town"))
	if loaded_map in ["town","beach","rocky"] and loaded_map != current_map:
		current_map = loaded_map; _build_map(current_map)
	day = maxi(1,int(data.get("day",1))); fish_count = maxi(0,int(data.get("fish",0)))
	time_of_day = clampf(float(data.get("time",0.35)),0.0,1.0)
	var saved_pos := Vector2(float(data.get("x",368)),float(data.get("y",372)))
	if _walkable(saved_pos): player = saved_pos
	if data.get("catches",{}) is Dictionary: catches = data.get("catches",{})
	toast = "Welcome back to Saltmere"; toast_t = 3

func _draw():
	if terrain == null: return
	draw_texture(terrain,Vector2.ZERO)
	_draw_map_landmarks()
	# Fine animated foam and water highlights, snapped to integer pixels.
	for x in range(32,819,24):
		var y := _shore(x) + 3 + int(sin(elapsed*1.5+x)*2)
		draw_line(Vector2(x,y),Vector2(x+12,y),Color("#c4dbc1"))
	for i in range(28):
		var x := 50+i*33
		var y := 558+(i%4)*18
		var drift := int(sin(elapsed+i)*3)
		draw_line(Vector2(x+drift,y),Vector2(x+drift+6,y),Color("#64a2a5"))
	var drawn := false
	for prop in props:
		if not drawn and prop.pos.y > player.y:
			_draw_player(); drawn = true
		var tex: Texture2D = textures[prop.kind]
		draw_texture(tex,prop.pos-Vector2(tex.get_width()/2.0,tex.get_height()))
	if not drawn: _draw_player()
	_draw_exit_markers()
	if transition_active:
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.04,0.08,0.10, transition_fade))
	if transition_active:
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.04,0.08,0.10, transition_fade))
	if fishing_state == FishingState.ANTICIPATING or fishing_state == FishingState.TIMING:
		var float_pos := player.round()+Vector2(15,32+int(sin(elapsed*6)))
		draw_line(player.round()+Vector2(7,-9),player.round()+Vector2(12,-23),Color("#80674a"))
		draw_line(player.round()+Vector2(12,-23),float_pos,Color("#d1d6b2"))
		draw_circle(float_pos+Vector2(1,1),3.0+sin(elapsed*10)*1.2,Color("#edb17b"))

func _exit_markers() -> Array[Dictionary]:
	# Exit markers are deliberately kept in world space so they remain visible as
	# the camera follows the player. Their locations mirror _check_map_exit().
	match current_map:
		"town":
			return [
				{"pos":Vector2(500,441),"label":"BEACH","dir":Vector2(0,1)},
				{"pos":Vector2(800,338),"label":"ROCKY SHORE","dir":Vector2(1,0)}
			]
		"beach":
			return [
				{"pos":Vector2(420,40),"label":"TOWN","dir":Vector2(0,-1)},
				{"pos":Vector2(800,390),"label":"ROCKY SHORE","dir":Vector2(1,0)}
			]
		"rocky":
			return [
				{"pos":Vector2(40,340),"label":"TOWN","dir":Vector2(-1,0)},
				{"pos":Vector2(420,430),"label":"BEACH","dir":Vector2(0,1)}
			]
		_:
			return []

func _draw_exit_markers():
	for marker in _exit_markers():
		var p: Vector2 = marker.pos
		var d: Vector2 = marker.dir
		# A small pixel signpost with a directional chevron. It uses the same
		# muted wood/ink palette as the existing sign prop.
		draw_line(p + Vector2(0,10), p + Vector2(0,-7), Color("#604c3d"), 2.0)
		var board := Rect2(p + Vector2(-27,-19), Vector2(54,12))
		draw_rect(board, Color("#c59b65"))
		draw_rect(board.grow(-1), Color("#6d5544"), false, 1.0)
		var tip := p + d * 9.0
		var left := tip - d * 5.0 + Vector2(-d.y,d.x) * 4.0
		var right := tip - d * 5.0 - Vector2(-d.y,d.x) * 4.0
		draw_line(tip,left,Color("#f0dcaa"),2.0)
		draw_line(tip,right,Color("#f0dcaa"),2.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(-24,-10), str(marker.label), HORIZONTAL_ALIGNMENT_CENTER, 48, 8, Color("#3f4038"))

func _draw_map_landmarks():
	# Small, readable primitives make each shoreline recognizable without new art.
	if current_map == "rocky":
		# Wind-cut shelves and cairns point toward the future lighthouse route.
		for i in range(6):
			var shelf := Vector2(560 + i*34, 278 + (i%2)*8)
			draw_line(shelf, shelf + Vector2(23, -5), Color("#6f8580"), 2.0)
		for i in range(5):
			var cairn := Vector2(385 + i*57, 348 - i*37)
			draw_circle(cairn, 5.0, Color("#526b69"))
			draw_circle(cairn - Vector2(1,2), 2.5, Color("#91a39a"))
	for landmark in landmarks:
		var p: Vector2 = landmark.pos
		var kind := str(landmark.kind)
		if kind == "pier":
			draw_rect(Rect2(p-Vector2(18,7),Vector2(36,20)),Color("#8f6e4e"))
			for x in range(-14,19,8): draw_line(p+Vector2(x,-6),p+Vector2(x,12),Color("#d2a36b"),2.0)
			draw_line(p+Vector2(-20,14),p+Vector2(20,14),Color("#513f37"),2.0)
		elif kind == "driftwood":
			draw_line(p+Vector2(-25,5),p+Vector2(23,-8),Color("#765744"),5.0)
			draw_line(p+Vector2(-16,1),p+Vector2(-23,-8),Color("#a27b54"),2.0)
		elif kind == "breakwater":
			for i in range(7):
				var q := p+Vector2(i*18-54, sin(i*1.7)*4)
				draw_circle(q,9.0,Color("#526b69")); draw_circle(q-Vector2(2,2),5.0,Color("#718785"))
		elif kind == "pool":
			draw_circle(p,16.0,Color("#4f9291")); draw_circle(p-Vector2(3,3),11.0,Color("#80b9a7"))
			draw_arc(p,16.0,0,TAU,16,Color("#d0d3a4"),2.0)
		elif kind == "lighthouse":
			# Farwatch is a distant silhouette for now; the west trail can become
			# an actual route when the offshore map is added.
			draw_circle(p+Vector2(0,10),24.0,Color("#334f52"))
			draw_colored_polygon(PackedVector2Array([
				p+Vector2(-11,10), p+Vector2(-7,-25), p+Vector2(7,-25), p+Vector2(11,10)
			]),Color("#d8c28d"))
			draw_rect(Rect2(p+Vector2(-10,-30),Vector2(20,7)),Color("#57484a"))
			draw_rect(Rect2(p+Vector2(-8,-38),Vector2(16,9)),Color("#bd7057"))
			draw_circle(p+Vector2(0,-34),4.0,Color("#f4d67e"))
			draw_line(p+Vector2(0,-34),p+Vector2(-39,-47),Color(1.0,0.92,0.63,0.18),3.0)
			draw_line(p+Vector2(0,-34),p+Vector2(39,-47),Color(1.0,0.92,0.63,0.18),3.0)
		# Landmark names are intentionally small, like hand-painted map notes.
		draw_string(ThemeDB.fallback_font, p + Vector2(-34,27), str(landmark.label), HORIZONTAL_ALIGNMENT_CENTER, 68, 8, Color("#3f514d"))
	# Fishing markers sit just inland of each water feature and pulse gently.
	for spot in _fishing_spots():
		var p: Vector2 = spot.pos
		var pulse := 1.0 + sin(elapsed*3.0 + p.x)*0.15
		draw_circle(p,5.0*pulse,Color(0.91,0.81,0.47,0.85))
		draw_arc(p,9.0*pulse,0,TAU,12,Color("#f3e2a2"),1.0)

func _exit_hint() -> String:
	var best := ""
	var best_distance := 120.0
	for marker in _exit_markers():
		var distance := player.distance_to(marker.pos)
		if distance < best_distance:
			best_distance = distance
			best = "Exit to " + str(marker.label).capitalize() + "  " + _exit_arrow(marker.dir)
	return best

func _exit_arrow(direction: Vector2) -> String:
	if direction.x > 0: return ">"
	if direction.x < 0: return "<"
	if direction.y > 0: return "v"
	return "^"

func _draw_player():
	var frame := int(walk_time*9)%4 if walking else 0
	draw_texture_rect_region(hero,Rect2(player.round()-Vector2(8,22),Vector2(16,24)),Rect2(frame*16,face*24,16,24))

func _panel(rect: Rect2, paper := false):
	hud.draw_rect(rect,Color("#e5d5ab") if paper else Color("#263e43"))
	hud.draw_rect(rect.grow(-2),Color("#a38f64") if paper else Color("#8ba79b"),false,1)

func _text(pos: Vector2, value: String, size := 11, paper := false):
	hud.draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("#43534e") if paper else Color("#f1e3ba"))

func _draw_hud():
	_panel(Rect2(8,8,174,34))
	_text(Vector2(16,22),"SALTMERE  /  " + _map_display_name(),11)
	_text(Vector2(16,35),"Day %02d    Fish %02d" % [day,fish_count],10)
	_panel(Rect2(294,8,178,22))
	_text(Vector2(302,23),"[N] Ledger   [F6] Save",10)
	_panel(Rect2(8,244,464,19))
	_text(Vector2(15,257),toast if toast_t>0 else _map_hint(),10)
	var nearby_exit := _exit_hint()
	if nearby_exit != "" and not notebook_open and not transition_active:
		_panel(Rect2(286,218,184,20))
		_text(Vector2(294,232),nearby_exit,10)
	if _can_fish() and not notebook_open and fishing_state == FishingState.IDLE:
		_panel(Rect2(172,218,138,20)); _text(Vector2(182,232),"SPACE  Cast your line",11)
	if fishing_state == FishingState.ANTICIPATING or fishing_state == FishingState.TIMING:
		_draw_fishing_hud()
	elif fishing_state == FishingState.RESULT:
		_draw_fishing_result()
	if notebook_open:
		_panel(Rect2(48,43,384,190),true)
		_text(Vector2(85,75),"THE TIDE LEDGER",17,true)
		_text(Vector2(85,94),"Saltmere / " + current_map.capitalize(),11,true)
		var row := 116
		for species in FISH_SPECIES:
			var species_name := str(species.get("name", ""))
			var rarity := str(species.get("rarity", "COMMON"))
			var portrait: Texture2D = fish_portraits.get(species_name)
			# Five tiny portraits make the ledger feel like a collection page. The
			# paper strip remains readable even before a species has been caught.
			hud.draw_rect(Rect2(82,row-12,38,24),Color("#d4c397"))
			if portrait != null:
				hud.draw_texture_rect(portrait,Rect2(84,row-10,34,22),false)
			_text(Vector2(128,row-2),"%s  %s  x%d" % [species_name,rarity,int(catches.get(species_name,0))],9,true)
			row += 20
		_text(Vector2(85,218),"Shore or pier: SPACE to cast",9,true)
		_text(Vector2(85,229),"N to close  /  Movement pauses while reading",9,true)

func _draw_fishing_hud():
	if fishing_state == FishingState.TIMING:
		var power := 1.0 - float(fish_hp) / maxf(1.0,fish_hp_max)
		for i in range(14):
			var a := float(i) * TAU / 14.0 + elapsed * 0.16
			var start := Vector2(240,126) + Vector2(cos(a),sin(a))* (140.0 + power * 55.0)
			var end := Vector2(240,126) + Vector2(cos(a),sin(a))* 350.0
			hud.draw_line(start,end,Color.from_hsv(float(i)/14.0,0.55,1.0,0.10+power*0.46),2.0+power*3.0)
	var challenge_live := fishing_challenge != null and not fishing_challenge.done
	var challenge_offset := 30 if challenge_live else 0
	var panel := Rect2(96,48,288,160 + challenge_offset)
	_panel(panel)
	_text(Vector2(114,70), "FISHING  /  " + ("WAIT FOR THE BITE" if fishing_state == FishingState.ANTICIPATING else "TUG-OF-WAR"), 12)
	if fishing_state == FishingState.ANTICIPATING:
		var p := clampf(bite_timer / maxf(0.01,bite_delay), 0.0, 1.0)
		hud_bar(Vector2(114,98),Vector2(252,8),p,Color("#6c9b91"))
		_text(Vector2(114,123), "Listen for the splash...", 10)
	else:
		if challenge_live:
			_text(Vector2(114,86), fishing_challenge.round_label(), 9)
			_text(Vector2(114,99), _challenge_prompt(), 8)
			if challenge_hint_t > 0.0 and challenge_round_event != "":
				_text(Vector2(114,110), challenge_round_event, 8)
		var gauge_y := 98.0 + challenge_offset
		# Gold center zone is the PERFECT band; wider teal band is GOOD.
		_text(Vector2(114,87 + challenge_offset), "TIME %02ds   /   PULLS %d" % [ceili(maxf(0.0,timing_timer)),battle_hits], 9)
		hud_bar(Vector2(114,gauge_y),Vector2(252,12),1.0,Color("#355a5a"))
		hud_bar(Vector2(114+252*0.26,gauge_y),Vector2(252*0.54,12),1.0,Color("#7eb59d"))
		hud_bar(Vector2(114+252*0.42,gauge_y),Vector2(252*0.20,12),1.0,Color("#edc467"))
		if challenge_live:
			_draw_challenge_target(Vector2(114,gauge_y),Vector2(252,12))
		hud.draw_rect(Rect2(114+252*gauge-2,gauge_y-4,4,20),Color("#fff3c2"))
		_text(Vector2(114,128 + challenge_offset), ("SPACE  PULL NOW!" if pull_cooldown <= 0.0 else "Recover... wait for next pull"), 11)
		_text(Vector2(114,145 + challenge_offset), "FISH STAMINA  %d / %d" % [fish_hp,fish_hp_max], 9)
		hud_bar(Vector2(114,151 + challenge_offset),Vector2(252,6),float(fish_hp)/maxf(1.0,fish_hp_max),Color("#a45f69"))
		_text(Vector2(114,171 + challenge_offset), "LINE TENSION", 9)
		hud_bar(Vector2(194,166 + challenge_offset),Vector2(172,6),battle_tension,Color("#bd7b58"))
		_text(Vector2(114,186 + challenge_offset), "FISH " + ("<" if battle_direction < 0 else ">") + "  HOLD " + ("RIGHT" if battle_direction < 0 else "LEFT") + " TO COUNTER", 10)
		_text(Vector2(114,201 + challenge_offset), "ESCAPE", 8)
		hud_bar(Vector2(151,195 + challenge_offset),Vector2(215,4),battle_escape,Color("#c06363"))

func _challenge_prompt() -> String:
	if fishing_challenge == null: return ""
	match fishing_challenge.current_game_name():
		"SHRINKING RING": return "SPACE inside the shrinking ring"
		"MOVING SAFE ZONE": return "SPACE while the safe zone overlaps"
		"TIDE SLALOM":
			var lane := fishing_challenge.safe_lane()
			if lane < -0.5: return "HOLD LEFT, then SPACE"
			if lane > 0.5: return "HOLD RIGHT, then SPACE"
			return "CENTER, then SPACE"
		"FINISHING RHYTHM": return "Tap SPACE on every finishing beat"
		_: return fishing_challenge.instructions()

func _draw_challenge_target(pos: Vector2, size: Vector2):
	if fishing_challenge == null or fishing_challenge.done: return
	var center := clampf(fishing_challenge.target_center(), 0.0, 1.0)
	var width := clampf(fishing_challenge.target_width(), 0.04, 1.0)
	var left := pos.x + size.x * clampf(center - width * 0.5, 0.0, 1.0)
	var right := pos.x + size.x * clampf(center + width * 0.5, 0.0, 1.0)
	var color := Color("#eacb72")
	match fishing_challenge.current_game_name():
		"MOVING SAFE ZONE": color = Color("#9fd5ac")
		"TIDE SLALOM": color = Color("#b6b3ed")
		"FINISHING RHYTHM": color = Color("#f2a66f")
	# Keep the original gold/teal grade visible underneath. The outlined target
	# makes each challenge readable even for players who ignore the text prompt.
	hud.draw_rect(Rect2(left,pos.y-2,maxf(2.0,right-left),size.y+4),Color(color,0.38))
	hud.draw_line(Vector2(left,pos.y-4),Vector2(left,pos.y+size.y+4),color,1.0)
	hud.draw_line(Vector2(right,pos.y-4),Vector2(right,pos.y+size.y+4),color,1.0)

func _draw_fishing_result():
	if last_rarity == "LEGENDARY":
		_draw_legendary_result()
		return
	if last_grade != "MISS":
		_draw_standard_reveal_result()
		return
	var panel := Rect2(92,64,296,110)
	_panel(panel)
	_text(Vector2(116,88),"BIG CATCH!!" if last_rarity == "LEGENDARY" else last_grade,24 if last_rarity == "LEGENDARY" else 20)
	_text(Vector2(116,113),last_catch,20 if last_rarity == "LEGENDARY" else 16)
	if last_grade != "MISS":
		_text(Vector2(116,133),last_rarity + "  /  COMBO x" + str(combo),13 if last_rarity == "LEGENDARY" else 11)
	else:
		_text(Vector2(116,133),"Combo reset",11)
	_text(Vector2(116,155),"SPACE  cast again",11)
	if flash_t > 0.0:
		hud.draw_rect(Rect2(0,0,480,270),Color(1.0,0.9,0.55,flash_t*0.28))
	if last_grade != "MISS":
		var sparkle_color := Color("#ffffff") if last_rarity == "LEGENDARY" else (Color("#f8dc75") if last_rarity == "RARE" else Color("#c6e6b7"))
		var sparkle_count := 28 if last_rarity == "LEGENDARY" else (14 if last_rarity == "RARE" else 7)
		for i in range(sparkle_count):
			var a := fish_particle_t*2.0 + float(i)*TAU/float(sparkle_count)
			var q := Vector2(240,108) + Vector2(cos(a),sin(a))* (42.0 + sin(fish_particle_t*5.0+i)*5.0)
			hud.draw_circle(q,3.0 if last_rarity == "LEGENDARY" else 2.0,Color.from_hsv(fmod(float(i)/float(sparkle_count)+fish_particle_t*0.1,1.0),0.72,1.0) if last_rarity == "LEGENDARY" else sparkle_color)

func _draw_standard_reveal_result():
	var t := reveal_t
	var center := Vector2(240,137)
	var rarity_col := _rarity_color(last_rarity)
	var rise := clampf((t - 0.82) / 0.60, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	var flip_p := clampf((t - 1.42) / 0.36, 0.0, 1.0)
	var face_visible := t >= 1.60
	# The card stays on screen for the whole reveal. A wide back, a narrow
	# turning edge, and a wide face read as one smooth flip rather than a cut.
	var card_half_width := 136.0
	if t >= 1.42 and t < 1.78:
		card_half_width = maxf(7.0, 136.0 * absf(cos(flip_p * PI)))
	var card_rect := Rect2(center.x - card_half_width, 35, card_half_width * 2.0, 194)
	_panel(card_rect)
	hud.draw_rect(card_rect.grow(-5), Color(0.06, 0.10, 0.18, 0.72))
	# Soft rings and rays make the silhouette grow without using strobing.
	if t >= 0.42:
		for ring in range(3):
			var radius := 28.0 + rise * (18.0 + ring * 15.0)
			hud.draw_arc(center, radius, 0, TAU, 64, Color(rarity_col, 0.16 + pulse * 0.08), 1.5)
	if t >= 0.82:
		for i in range(12):
			var a := float(i) * TAU / 12.0 + t * 0.10
			var inner := 40.0 + rise * 18.0
			var outer := inner + 13.0 + rise * 28.0
			hud.draw_line(center + Vector2(cos(a), sin(a)) * inner, center + Vector2(cos(a), sin(a)) * outer, Color(rarity_col, 0.22 + rise * 0.28), 1.0)
	var fish_scale := 0.28
	if t >= 0.42:
		fish_scale = 0.36 + rise * 0.64
	var fish_col := Color("#111a2b") if not face_visible else rarity_col.lightened(0.12)
	var fish_width_scale := 1.0
	if t >= 1.42 and t < 1.78:
		fish_width_scale = absf(cos(flip_p * PI))
	if face_visible:
		# Resolve into the large concept-sheet illustration. The compact pixel
		# portrait remains reserved for the ledger strip below.
		_draw_fish_card(center + Vector2(0, -2), last_catch, Vector2(238, 158))
	else:
		_draw_reveal_fish(center, fish_scale, fish_col, false, fish_width_scale)
	if t < 0.42:
		_center_text(68, "???", 28, Color("#e7edf7"))
		_center_text(207, "A hidden tide catch", 10, Color("#b4c5db"))
	elif t < 0.82:
		_center_text(66, "RARITY...", 18, rarity_col.lightened(0.22))
		_center_text(207, "The water holds its breath", 10, Color("#c4d1e2"))
	elif t < 1.42:
		_center_text(64, last_rarity, 22, rarity_col.lightened(0.22))
		_center_text(207, "Something is surfacing", 10, Color("#d5e2ef"))
	elif not face_visible:
		_center_text(64, last_rarity, 18, rarity_col.lightened(0.16))
		_center_text(207, "TURNING THE CARD...", 10, Color("#e3e7ee"))
	else:
		_center_text(62, last_rarity, 16, rarity_col.lightened(0.18))
		_center_text(207, last_catch, 19, Color("#fff0c6"))
		_center_text(225, "%s  /  COMBO x%d" % [last_rarity, combo], 10, Color("#d3deec"))
		_center_text(250, "SPACE  continue", 10, Color("#fff0d8"))
	# A single low-alpha wash at the flip keeps the card readable and avoids
	# the rapid flashing that makes ordinary catches tiring to watch.
	if t >= 1.42 and t < 1.78:
		var flip_glow := sin(flip_p * PI) * 0.10
		hud.draw_rect(Rect2(0, 0, 480, 270), Color(rarity_col, flip_glow))

func _draw_reveal_fish(center: Vector2, scale: float, color: Color, revealed: bool, width_scale: float = 1.0):
	var body := PackedVector2Array([Vector2(-84,0), Vector2(-55,-25), Vector2(29,-30), Vector2(65,-13), Vector2(87,0), Vector2(65,18), Vector2(30,30), Vector2(-51,25)])
	var transformed := PackedVector2Array()
	for point in body:
		transformed.append(center + Vector2(point.x * width_scale, point.y) * scale)
	hud.draw_colored_polygon(transformed, color)
	var tail := PackedVector2Array([center + Vector2(-67 * width_scale, 0) * scale, center + Vector2(-112 * width_scale, -36) * scale, center + Vector2(-108 * width_scale, 35) * scale])
	hud.draw_colored_polygon(tail, color.darkened(0.18))
	if revealed:
		hud.draw_circle(center + Vector2(57 * width_scale, -8) * scale, 5.0 * scale, Color("#18263d"))
		hud.draw_circle(center + Vector2(58 * width_scale, -10) * scale, 1.5 * scale, Color.WHITE)

func _draw_legendary_result():
	var t := legendary_t
	var center := Vector2(240,132)
	var rise := clampf((t - 0.65) / 1.4, 0.0, 1.0)
	var peak := clampf((t - 2.05) / 0.32, 0.0, 1.0)
	var after := clampf((t - 4.6) / 1.4, 0.0, 1.0)
	# Broad, smoothly moving colour fields provide scale without strobing.
	hud.draw_rect(Rect2(0,0,480,270),Color(0.025,0.03,0.12,0.5 + rise * 0.43 - after * 0.19))
	var strength := (0.10 + rise * 0.31) * (1.0 - after * 0.48)
	for i in range(32):
		var a := float(i) * TAU / 32.0 + t * 0.07
		var b := a + TAU / 45.0
		var col := Color.from_hsv(fmod(float(i)/32.0 + t * 0.028,1.0),0.75,1.0,strength)
		hud.draw_colored_polygon(PackedVector2Array([center, center + Vector2(cos(a),sin(a)) * 580.0, center + Vector2(cos(b),sin(b)) * 580.0]),col)
	# Concentric rings travel from a tiny omen all the way past the screen edges.
	for j in range(5):
		var radius := 15.0 + rise * (44.0 + j * 42.0) + peak * 60.0
		var col := Color.from_hsv(fmod(t * 0.08 + float(j)/5.0,1.0),0.65,1.0,0.6 - after * 0.34)
		hud.draw_arc(center,radius,0,TAU,96,col,2.0 + peak * 2.0)
	# Confetti fills the entire frame at the climax instead of orbiting a small
	# central panel. Motion is smooth; these are not alternating white flashes.
	var count := 18 + int(rise * 32.0) + int(peak * 86.0)
	for i in range(count):
		var angle := float(i) * 2.399963 + t * (0.05 if i % 2 == 0 else -0.035)
		var radius := 18.0 + fmod(float(i) * 41.0 + t * (15.0 + float(i % 7) * 8.0), 335.0) * (0.2 + rise * 0.8)
		var q := center + Vector2(cos(angle),sin(angle) * 0.7) * radius
		var col := Color.from_hsv(fmod(float(i) * 0.0618 + t * 0.032,1.0),0.65,1.0,0.95 - after * 0.45)
		var sz := 1.5 + peak * float(2 + i % 3)
		hud.draw_rect(Rect2(q-Vector2(sz,sz),Vector2(sz*2,sz*2)),col)
		if i % 4 == 0:
			hud.draw_line(q-Vector2(sz*2.5,0),q+Vector2(sz*2.5,0),Color(1,1,0.85,col.a),1)
			hud.draw_line(q-Vector2(0,sz*2.5),q+Vector2(0,sz*2.5),Color(1,1,0.85,col.a),1)
	if t < 0.82:
		_center_text(56,"SOMETHING ENORMOUS...",19,Color("#c8e8ff"))
		_center_text(219,"Feel the tide gathering",11,Color("#d4cefa"))
	elif t < 2.05:
		_center_text(49,"THE OCEAN AWAKENS",24,Color("#ffe0a4"))
		_center_text(229,"RAINBOW ENERGY RISING",14,Color("#fff5dc"))
	else:
		# A wide ribbon and the large concept-sheet trophy card dominate the final frame.
		hud.draw_colored_polygon(PackedVector2Array([Vector2(14,19),Vector2(466,19),Vector2(455,63),Vector2(24,63)]),Color(0.12,0.05,0.2,0.88))
		hud.draw_line(Vector2(16,19),Vector2(464,19),Color("#ffe39a"),3)
		hud.draw_line(Vector2(24,63),Vector2(456,63),Color("#ffe39a"),3)
		_center_text(53,"LEGENDARY!!",35,Color("#fff4bd"))
		_center_text(211,"RAINBOW KINGFISH",24,Color("#fff3c9"))
		_center_text(231,"BIG CATCH!   COMBO x%d" % combo,15,Color("#e4d2ff"))
		_center_text(258,"SPACE  continue",10,Color("#fff0d8"))
	# The fish grows from a dark silhouette into the original framed trophy
	# illustration. Keep the silhouette phase so the existing reveal timing and
	# suspense beats remain unchanged.
	var scale := 0.22 + rise * 0.55 + peak * 0.28
	if t < 2.05:
		var body := PackedVector2Array([Vector2(-84,0),Vector2(-55,-25),Vector2(29,-30),Vector2(65,-13),Vector2(87,0),Vector2(65,18),Vector2(30,30),Vector2(-51,25)])
		var transformed := PackedVector2Array()
		for p in body: transformed.append(center + p * scale)
		hud.draw_colored_polygon(transformed,Color("#130f32"))
		hud.draw_colored_polygon(PackedVector2Array([center+Vector2(-67,0)*scale,center+Vector2(-112,-36)*scale,center+Vector2(-108,35)*scale]),Color("#130f32"))
	else:
		# The card art is intentionally drawn after the background fields and
		# before the text ribbon so the framed illustration reads as a trophy.
		_draw_fish_card(center + Vector2(0, -8), "Rainbow Kingfish", Vector2(240, 136))
	# The initial reveal gets one soft glow, never repeated high-frequency flash.
	if t >= 2.05 and t < 2.55:
		var glow := sin((t-2.05)/0.5*PI)*0.20
		hud.draw_rect(Rect2(0,0,480,270),Color(1,0.90,0.67,glow))

func _center_text(y: float, value: String, size: int, color: Color):
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	hud.draw_string(font,Vector2((480-width)/2+1,y+2),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0.04,0.025,0.09,0.95))
	hud.draw_string(font,Vector2((480-width)/2,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func hud_bar(pos: Vector2, size: Vector2, amount: float, color: Color):
	hud.draw_rect(Rect2(pos,size), color.darkened(0.65))
	if amount > 0.0:
		hud.draw_rect(Rect2(pos, Vector2(size.x * clampf(amount,0.0,1.0), size.y)), color.lightened(0.16))

func _map_display_name() -> String:
	match current_map:
		"town": return "TOWN HARBOR"
		"beach": return "AMBER BEACH"
		"rocky": return "ROCKY SHORE"
		_: return current_map.to_upper()

func _map_hint() -> String:
	match current_map:
		"town": return "WASD / arrows: walk     SPACE: cast at Old Salt Pier"
		"beach": return "WASD / arrows: walk     SPACE: cast in the tide pools"
		"rocky": return "WASD / arrows: walk     SPACE: cast at the stone pools"
		_: return "WASD / arrows: walk     SPACE: cast"
