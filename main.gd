extends Node2D

const FishingChallengeScript = preload("res://fishing_challenge.gd")
const MusicDirectorScript = preload("res://audio/music_director.gd")

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
var shells := 12
var bait_index := 0
var rod_index := 0
const BAITS: Array[Dictionary] = [
 {"name":"Worm","cost":0,"rarity_bonus":0.0,"tension_bonus":0.0},
 {"name":"Glowbait","cost":2,"rarity_bonus":0.14,"tension_bonus":0.06},
 {"name":"Moonseed","cost":4,"rarity_bonus":0.28,"tension_bonus":0.12}
]
const RODS: Array[Dictionary] = [
 {"name":"Reed Rod","tension_mult":1.0,"escape_mult":1.0},
 {"name":"Fiberglass Rod","tension_mult":0.82,"escape_mult":0.90},
 {"name":"Stormglass Rod","tension_mult":0.68,"escape_mult":0.82}
]
var day := 1
var time_of_day := 0.35
# Fishing conditions are part of the saved tide state.  The clock is a
# normalized day (0.0 = midnight, 0.5 = midday), while weather and season are
# plain strings so the forecast is readable in saves and easy to probe.
var weather := "clear"
var season := "spring"
const DAY_LENGTH_SECONDS := 180.0
const WEATHER_NAMES := ["clear", "overcast", "rain", "storm"]
const SEASON_NAMES := ["spring", "summer", "autumn", "winter"]
const WEATHER_CYCLE := ["clear", "clear", "overcast", "rain", "clear", "storm", "overcast"]
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
var face := 0
var walk_time := 0.0
var walking := false
var elapsed := 0.0
var cast_timer := 0.0
var catches: Dictionary = {}
# Catch depth lives alongside the compact species -> count ledger.  The first
# record is intentionally immutable so a repeat catch cannot erase the moment
# a species was discovered.  `catch_latest` powers the current reveal while
# `catch_metadata`/`first_capture_metadata` are the durable first-capture API.
var catch_metadata: Dictionary = {}
var first_capture_metadata: Dictionary = {}
var catch_latest: Dictionary = {}
var best_records: Dictionary = {}
var last_catch_metadata: Dictionary = {}
var last_catch_size_cm := 0.0
var last_catch_weight_kg := 0.0
var last_catch_variant := "Standard"
var last_catch_mystery := false
var last_rescue_used := false
# Expanded coastal field guide: five original entries plus eighteen approved species.
const FISH_SPECIES: Array[Dictionary] = [
 {"name":"Silver sprat","rarity":"COMMON","maps":["town","beach"]}, {"name":"Sand goby","rarity":"COMMON","maps":["town","beach"]}, {"name":"Moonfin trout","rarity":"RARE","maps":["beach","rocky"]}, {"name":"Old boot","rarity":"COMMON","maps":["town"]}, {"name":"Rainbow Kingfish","rarity":"LEGENDARY","maps":["rocky"]},
 {"name":"Amber anchovy","rarity":"COMMON","maps":["beach"]}, {"name":"Dune flounder","rarity":"COMMON","maps":["beach"]}, {"name":"Tidepool blenny","rarity":"UNCOMMON","maps":["beach"]}, {"name":"Glass shrimp","rarity":"UNCOMMON","maps":["beach","rocky"]}, {"name":"Copper mackerel","rarity":"RARE","maps":["beach"]},
 {"name":"Saltwater eel","rarity":"UNCOMMON","maps":["town","rocky"]}, {"name":"Lantern squid","rarity":"RARE","maps":["rocky"]}, {"name":"Blackglass bass","rarity":"RARE","maps":["rocky"]}, {"name":"Storm sardine","rarity":"UNCOMMON","maps":["rocky"]}, {"name":"Gullfin","rarity":"COMMON","maps":["town","rocky"]},
 {"name":"Lighthouse ray","rarity":"EPIC","maps":["rocky"]}, {"name":"Tidemark carp","rarity":"UNCOMMON","maps":["town"]}, {"name":"Sea lavender perch","rarity":"RARE","maps":["beach","rocky"]}, {"name":"Pearl puffer","rarity":"EPIC","maps":["beach","rocky"]}, {"name":"Night sailfish","rarity":"EPIC","maps":["rocky"]},
 {"name":"Crown snapper","rarity":"EPIC","maps":["town","rocky"]}, {"name":"Singing herring","rarity":"RARE","maps":["town","beach"]}, {"name":"Aurora koi","rarity":"LEGENDARY","maps":["hidden"]}
]
var rumor_found := false
var hidden_spot_unlocked := false
var hidden_spot_collected := false
var promotion_t := 0.0
var promotion_stage := 0
var promotion_reversal := false
var promotion_false_cue := false
var promotion_false_cue_revealed := false
var promotion_reversal_armed := false
var promotion_cue_rank := 0
var cast_candidate: Dictionary = {}
var cast_good_candidate: Dictionary = {}
var promotion_target_rarity := "COMMON"
var promotion_result_label := ""
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
const FEVER_THRESHOLD := 3
const FEVER_DURATION := 30.0
const FEVER_RARITY_BONUS := 0.5
const PROMOTION_FALSE_CUE_CHANCE := 0.18
const PROMOTION_FALSE_RAINBOW_CHANCE := 0.02
const PROMOTION_FALSE_PURPLE_CHANCE := 0.06
const PROMOTION_REVERSAL_CHANCE := 0.24
## Soft pity is a transparent rescue hook for an unlucky run.  A miss or a
## low-grade (GOOD) catch advances the meter, but the player still has to land
## the next battle normally.  Once armed, the hook only changes the species
## floor to RARE; it never auto-wins a cast or bypasses map/grade rules.
const PITY_THRESHOLD := 3
var pity_meter := 0
var rescue_ready := false
var low_grade_streak := 0
var rescue_selection_used := false
var fever_active := false
var fever_t := 0.0
var fever_flash_t := 0.0
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
var reveal_shortened := false
var fishing_challenge: RefCounted
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

# ---- Tide forecast -------------------------------------------------------
# The same deterministic rules drive the species pool, the ledger, and smoke
# probes. A new day gets a repeatable forecast; no wall-clock randomness can
# change which fish are legal for a cast.
func _season_for_day(day_number: int) -> String:
	var safe_day := maxi(1, day_number)
	return SEASON_NAMES[((safe_day - 1) / 7) % SEASON_NAMES.size()]

func _weather_for_day(day_number: int) -> String:
	var safe_day := maxi(1, day_number)
	return WEATHER_CYCLE[(safe_day - 1) % WEATHER_CYCLE.size()]

func _normalize_weather(value: String) -> String:
	var candidate := value.to_lower().strip_edges()
	return candidate if WEATHER_NAMES.has(candidate) else "clear"

func _normalize_season(value: String) -> String:
	var candidate := value.to_lower().strip_edges()
	return candidate if SEASON_NAMES.has(candidate) else "spring"

func set_weather(value: String) -> void:
	weather = _normalize_weather(value)

func set_season(value: String) -> void:
	season = _normalize_season(value)

func _time_period(value: float = -1.0) -> String:
	var clock := time_of_day if value < 0.0 else value
	clock = fmod(clock, 1.0)
	if clock < 0.0: clock += 1.0
	if clock < 0.20 or clock >= 0.85: return "night"
	if clock < 0.35: return "dawn"
	if clock < 0.70: return "day"
	return "dusk"

func time_period() -> String:
	return _time_period()

func clock_text() -> String:
	var minutes := int(round(time_of_day * 24.0 * 60.0)) % (24 * 60)
	return "%02d:%02d" % [minutes / 60, minutes % 60]

func environment_label() -> String:
	return "%s  /  %s  /  %s" % [season.to_upper(), _time_period().to_upper(), weather.to_upper()]

func _advance_world_clock(delta: float) -> void:
	if delta <= 0.0: return
	var previous_day := day
	time_of_day += delta / DAY_LENGTH_SECONDS
	while time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
	if day != previous_day:
		season = _season_for_day(day)
		weather = _weather_for_day(day)

func _fish_entry(species: String) -> Dictionary:
	for fish in FISH_SPECIES:
		if str(fish.get("name", "")) == species: return fish
	return {}

func _fish_conditions(species: String) -> Dictionary:
	# Unlisted species retain their old map-only availability. The named
	# schedules add readable ecological variety without breaking old saves.
	var all_times := ["night", "dawn", "day", "dusk"]
	var all_weather := ["clear", "overcast", "rain", "storm"]
	var all_seasons := ["spring", "summer", "autumn", "winter"]
	match species:
		"Silver sprat": return {"times":["dawn", "day", "dusk"], "weather":["clear", "overcast", "rain"], "seasons":["spring", "summer", "autumn"]}
		"Sand goby": return {"times":all_times, "weather":all_weather, "seasons":all_seasons}
		"Moonfin trout": return {"times":["dusk", "night"], "weather":["clear", "rain"], "seasons":["autumn", "winter"]}
		"Old boot": return {"times":["day", "dusk"], "weather":["clear", "overcast"], "seasons":all_seasons}
		"Amber anchovy": return {"times":["dawn", "day", "dusk"], "weather":["clear", "overcast"], "seasons":["spring", "summer"]}
		"Dune flounder": return {"times":["dawn", "day"], "weather":["clear", "overcast", "rain"], "seasons":["spring", "summer", "autumn"]}
		"Tidepool blenny": return {"times":["dawn", "day", "dusk"], "weather":["clear", "overcast", "rain"], "seasons":["spring", "summer"]}
		"Copper mackerel": return {"times":["day", "dusk"], "weather":["clear", "overcast", "rain"], "seasons":["summer", "autumn"]}
		# Saltwater eel remains the town's broad fallback; the newer Storm sardine
		# carries the weather-specific eel-like niche.
		"Saltwater eel": return {"times":all_times, "weather":all_weather, "seasons":all_seasons}
		"Lantern squid": return {"times":["night"], "weather":["clear", "rain"], "seasons":["summer", "autumn", "winter"]}
		"Storm sardine": return {"times":["dusk", "night"], "weather":["rain", "storm"], "seasons":["summer", "autumn"]}
		"Lighthouse ray": return {"times":["dawn", "day"], "weather":["clear", "overcast"], "seasons":["summer", "autumn"]}
		"Tidemark carp": return {"times":["dawn", "day"], "weather":["clear", "overcast", "rain"], "seasons":["spring", "summer"]}
		"Sea lavender perch": return {"times":["dusk", "night"], "weather":["clear", "rain"], "seasons":["autumn", "winter"]}
		"Pearl puffer": return {"times":["day", "dusk"], "weather":["overcast", "rain"], "seasons":["summer", "autumn"]}
		"Night sailfish": return {"times":["night"], "weather":["clear", "storm"], "seasons":["autumn", "winter"]}
		"Crown snapper": return {"times":all_times, "weather":all_weather, "seasons":all_seasons}
		# Singing herring keeps a broad town fallback so old map-only rescue and
		# fever rolls always retain a rare option in daylight.
		"Singing herring": return {"times":all_times, "weather":all_weather, "seasons":all_seasons}
		# Aurora koi is the grotto's explicit discovery reward; the hidden spot
		# gates it, while tide conditions should not make the one-off reward vanish.
		"Aurora koi": return {"times":all_times, "weather":all_weather, "seasons":all_seasons}
		_: return {"times":all_times, "weather":all_weather, "seasons":all_seasons}

func fish_available(species: String, map_name: String = "", at_time: float = -1.0, weather_name: String = "", season_name: String = "") -> bool:
	var fish := _fish_entry(species)
	if fish.is_empty(): return false
	var map := current_map if map_name.is_empty() else map_name
	var map_ok: bool = fish.maps.has(map)
	if fish.maps.has("hidden") and map == "rocky": map_ok = _at_hidden_fishing_spot()
	if not map_ok: return false
	var conditions := _fish_conditions(species)
	var forecast_weather := weather if weather_name.is_empty() else _normalize_weather(weather_name)
	var forecast_season := season if season_name.is_empty() else _normalize_season(season_name)
	return conditions.times.has(_time_period(at_time)) and conditions.weather.has(forecast_weather) and conditions.seasons.has(forecast_season)

func available_fish(map_name: String = "", at_time: float = -1.0, weather_name: String = "", season_name: String = "") -> Array:
	var available: Array = []
	for fish in FISH_SPECIES:
		var species := str(fish.get("name", ""))
		if fish_available(species, map_name, at_time, weather_name, season_name): available.append(species)
	return available

func fish_availability(map_name: String = "", at_time: float = -1.0, weather_name: String = "", season_name: String = "") -> Array:
	return available_fish(map_name, at_time, weather_name, season_name)

func _available_fish(map_name: String = "", at_time: float = -1.0, weather_name: String = "", season_name: String = "") -> Array:
	return available_fish(map_name, at_time, weather_name, season_name)

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
	landmarks.append({"kind":"rumor_sign","pos":Vector2(468,381),"label":"Weathered notice"})
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
		{"kind":"lighthouse","pos":Vector2(704,154),"label":"Farwatch Lighthouse"},
		{"kind":"hidden_pool","pos":Vector2(690,520),"label":"Moonlit Grotto"}
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
	_advance_world_clock(delta)
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
	_update_rumor_gate()
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	walking = dir.length() > 0 and not notebook_open and fishing_state == FishingState.IDLE
	if walking:
		_move_player(dir,delta)
		walk_time += delta
		if absf(dir.x) > absf(dir.y): face = 2 if dir.x < 0 else 3
		else: face = 1 if dir.y < 0 else 0
		_check_map_exit()
	if not notebook_open:
		if Input.is_action_just_pressed("bait_next"): cycle_bait()
		if Input.is_action_just_pressed("rod_next"): cycle_rod()
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
		"rocky":
			var spots: Array[Dictionary] = [{"pos":Vector2(170,590),"label":"Blackglass Pool"},{"pos":Vector2(520,578),"label":"Gull's Pool"}]
			if hidden_spot_unlocked: spots.append({"pos":Vector2(690,520),"label":"Moonlit Grotto"})
			return spots
		_: return []

func _update_rumor_gate() -> void:
	if not rumor_found and current_map == "town" and player.distance_to(Vector2(468,381)) < 34.0:
		rumor_found = true
		toast = "The weathered notice whispers of a moonlit grotto"; toast_t = 3.0
	if rumor_found and not hidden_spot_unlocked and fish_count >= 3:
		hidden_spot_unlocked = true
		toast = "A hidden fishing spot is now marked on the rocky shore"; toast_t = 3.0
	if hidden_spot_unlocked and current_map == "rocky" and player.distance_to(Vector2(690,520)) < 28.0:
		hidden_spot_collected = true

func _at_hidden_fishing_spot() -> bool:
	# Aurora koi is tied to the grotto pool itself.  Visiting the grotto unlocks
	# the pool for the run, but standing at another rocky shoreline must not
	# silently include hidden fish in its species roll.
	return current_map == "rocky" and hidden_spot_unlocked and hidden_spot_collected and player.distance_to(Vector2(690,520)) <= 24.0

func _species_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for fish in FISH_SPECIES:
		var species := str(fish.get("name", ""))
		if fish_available(species): pool.append(fish)
	return pool

func _pick_species(grade: String, apply_rescue := false, exclude_legendary := false) -> Dictionary:
	if apply_rescue: rescue_selection_used = false
	var pool := _species_pool()
	if pool.is_empty(): return FISH_SPECIES[0]
	var eligible: Array[Dictionary] = []
	for fish in pool:
		if exclude_legendary and str(fish.get("rarity", "COMMON")) == "LEGENDARY": continue
		if grade == "PERFECT" or fish.rarity in ["COMMON","UNCOMMON","RARE"]: eligible.append(fish)
	if eligible.is_empty(): eligible = pool
	var bonus := float(BAITS[bait_index].rarity_bonus) + (FEVER_RARITY_BONUS if fever_active else 0.0)
	var total := 0.0
	var weights: Array[float] = []
	for fish in eligible:
		var weight := 100.0
		var rarity := str(fish.rarity)
		match rarity:
			"UNCOMMON": weight = 40.0
			"RARE": weight = 12.0
			"EPIC": weight = 3.0
			"LEGENDARY": weight = 0.5
		# Bait and FEVER are intentionally rarity-sensitive.  Common fish keep
		# their baseline weight, while the bonus increasingly favours a real
		# upgrade instead of inflating every rarity by the same amount.
		weight *= 1.0 + bonus * _rarity_bonus_scale(rarity)
		weights.append(weight); total += weight
	var roll := rng.randf() * total
	for i in range(eligible.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return _apply_rescue_floor(eligible[i], eligible, grade) if apply_rescue else eligible[i]
	var fallback: Dictionary = eligible[eligible.size() - 1]
	return _apply_rescue_floor(fallback, eligible, grade) if apply_rescue else fallback

func _rarity_rank(rarity: String) -> int:
	match rarity:
		"LEGENDARY": return 4
		"EPIC": return 3
		"RARE": return 2
		"UNCOMMON": return 1
		_: return 0

func _rarity_bonus_scale(rarity: String) -> float:
	match rarity:
		"UNCOMMON": return 0.35
		"RARE": return 0.85
		"EPIC": return 1.25
		"LEGENDARY": return 1.45
		_: return 0.0

func _legendary_chance_for_cast() -> float:
	# The upcoming bite is eligible for a legendary only on Rocky Shore after
	# the third chain catch.  FEVER and Moonseed each add a small, bounded nudge;
	# together they cap the chance at 5% rather than making a legendary routine.
	if current_map != "rocky" or combo + 1 < FEVER_THRESHOLD: return 0.0
	var chance := 0.01
	if fever_active: chance += 0.02
	if bait_index == 2: chance += 0.02
	return minf(chance, 0.05)

func _pick_cast_candidate(apply_rescue := false) -> Dictionary:
	# Keep the explicit legendary roll as the only way a cast can become
	# legendary; the ordinary perfect-pool pick excludes legendary entries so its
	# small base weight cannot bypass the five-percent cap.
	var candidate := _pick_species("PERFECT", apply_rescue, true)
	var chance := _legendary_chance_for_cast()
	if chance > 0.0 and rng.randf() < chance:
		var legendary_pool: Array[Dictionary] = []
		for fish in _species_pool():
			if str(fish.get("rarity", "COMMON")) == "LEGENDARY": legendary_pool.append(fish)
		if not legendary_pool.is_empty():
			# Preserve the existing grotto reward split: Aurora koi is a 35%
			# hidden-spot reward, while Rainbow Kingfish remains the usual result.
			if _at_hidden_fishing_spot() and rng.randf() < 0.35:
				for fish in legendary_pool:
					if str(fish.get("name", "")) == "Aurora koi":
						candidate = fish
						return candidate
			for fish in legendary_pool:
				if str(fish.get("name", "")) == "Rainbow Kingfish":
					candidate = fish
					return candidate
			candidate = legendary_pool[0]
	return candidate

func _pick_good_substitute(candidate: Dictionary) -> Dictionary:
	if _rarity_rank(str(candidate.get("rarity", "COMMON"))) <= _rarity_rank("RARE"):
		return {}
	var rare_pool: Array[Dictionary] = []
	for fish in _species_pool():
		if str(fish.get("rarity", "COMMON")) == "RARE": rare_pool.append(fish)
	if rare_pool.is_empty(): return {}
	# The substitute is selected at cast time, so GOOD cannot introduce a
	# second result-time species roll. Draw from the whole map-legal pool so
	# downgrades do not funnel every catch into one species.
	return rare_pool[rng.randi_range(0, rare_pool.size() - 1)].duplicate(true)

func _candidate_for_grade(candidate: Dictionary, grade: String) -> Dictionary:
	var resolved := candidate.duplicate(true)
	# The cast roll is intentionally a PERFECT-pool candidate.  A GOOD timing
	# result downgrades an EPIC/LEGENDARY candidate to the deterministic RARE
	# substitute selected at cast time, so a Legendary species never enters the
	# ledger from a low-grade battle.
	if grade == "GOOD" and _rarity_rank(str(resolved.get("rarity", "COMMON"))) > _rarity_rank("RARE"):
		var original_rarity := str(resolved.get("rarity", "COMMON"))
		var original_species := str(resolved.get("name", "Unknown catch"))
		var substitute := cast_good_candidate.duplicate(true)
		if substitute.is_empty(): substitute = _pick_good_substitute(resolved)
		if not substitute.is_empty():
			substitute["original_rarity"] = original_rarity
			substitute["downgraded_from_species"] = original_species
			resolved = substitute
	return resolved

func _promotion_max_stage(rarity: String) -> int:
	var rank := _rarity_rank(rarity)
	if rank <= 1: return 1 # COMMON / UNCOMMON: gold at most
	if rank == 2: return 2 # RARE: purple at most
	return 3 # EPIC / LEGENDARY: rainbow

func _visible_promotion_stage() -> int:
	var stage := promotion_stage
	if promotion_reversal: stage = maxi(0, stage - 1)
	return stage

func _apply_rescue_floor(candidate: Dictionary, eligible: Array[Dictionary], _grade: String) -> Dictionary:
	# The rescue hook is intentionally conservative: it selects from the same
	# map/grade-eligible pool and only raises the rarity floor to RARE.  The
	# timing battle has already been completed before this is called.
	if not rescue_ready or _rarity_rank(str(candidate.get("rarity", "COMMON"))) >= _rarity_rank("RARE"):
		return candidate
	var rare_pool: Array[Dictionary] = []
	for fish in eligible:
		if _rarity_rank(str(fish.get("rarity", "COMMON"))) >= _rarity_rank("RARE"):
			rare_pool.append(fish)
	if rare_pool.is_empty():
		return candidate
	rescue_selection_used = true
	return rare_pool[rng.randi_range(0, rare_pool.size() - 1)]

func _reset_pity() -> void:
	pity_meter = 0
	low_grade_streak = 0
	rescue_ready = false

func _advance_pity(outcome: String) -> void:
	# Keep this meter monotonic while a run is unlucky so its HUD signal is easy
	# to trust.  A successful RARE/PERFECT catch calls _reset_pity instead.
	pity_meter = mini(PITY_THRESHOLD, pity_meter + 1)
	if outcome == "GOOD": low_grade_streak += 1
	if pity_meter >= PITY_THRESHOLD:
		rescue_ready = true

func pity_status() -> Dictionary:
	return {"meter": pity_meter, "threshold": PITY_THRESHOLD, "ready": rescue_ready, "low_grade_streak": low_grade_streak}

func _pity_label() -> String:
	if rescue_ready:
		return "RESCUE READY"
	return "RESCUE %d/%d" % [pity_meter, PITY_THRESHOLD]

# Keep the variation ranges deliberately broad but believable.  They are
# derived from rarity rather than adding 23 hand-maintained fields to the
# species cards, so old saves and future species remain compatible.
func _fish_size_range(rarity: String) -> Vector2:
	match rarity:
		"UNCOMMON": return Vector2(24.0, 54.0)
		"RARE": return Vector2(36.0, 76.0)
		"EPIC": return Vector2(52.0, 104.0)
		"LEGENDARY": return Vector2(88.0, 168.0)
		_: return Vector2(14.0, 38.0)

func _fish_weight_range(rarity: String) -> Vector2:
	match rarity:
		"UNCOMMON": return Vector2(0.35, 1.65)
		"RARE": return Vector2(0.80, 3.80)
		"EPIC": return Vector2(2.20, 8.80)
		"LEGENDARY": return Vector2(7.50, 24.0)
		_: return Vector2(0.08, 0.72)

func _nearest_fishing_spot_label() -> String:
	var nearest := "Open water"
	var distance := INF
	for spot in _fishing_spots():
		var d := player.distance_to(spot.pos)
		if d < distance:
			distance = d
			nearest = str(spot.label)
	return nearest

func _roll_catch_variant(rarity: String, grade: String) -> Dictionary:
	# Variants are light-touch markers, not a second rarity system.  A perfect
	# pull gives a small shimmer chance and the rarer cards can very occasionally
	# receive the gilded marker.  The mystery flag is retained for the ledger so
	# callers can render an unknown marker without exposing hidden species data.
	var variant := "Standard"
	var variant_marker := ""
	var roll := rng.randf()
	if roll < (0.035 if rarity in ["EPIC", "LEGENDARY"] else 0.018):
		variant = "Gilded"
		variant_marker = "!"
	elif roll < (0.16 if grade == "PERFECT" else 0.09):
		variant = "Shimmer"
		variant_marker = "~"
	return {"variant":variant,"variant_marker":variant_marker,"mystery":false,"mystery_marker":""}

func _capture_metadata(fish: Dictionary, grade: String) -> Dictionary:
	var rarity := str(fish.get("rarity", "COMMON"))
	var size_range := _fish_size_range(rarity)
	var weight_range := _fish_weight_range(rarity)
	var variant_data := _roll_catch_variant(rarity, grade)
	var size_cm := snappedf(rng.randf_range(size_range.x, size_range.y), 0.1)
	var weight_kg := snappedf(rng.randf_range(weight_range.x, weight_range.y), 0.01)
	var fish_name := str(fish.get("name", "Unknown catch"))
	return {
		"species": fish_name,
		"rarity": rarity,
		"original_rarity": str(fish.get("original_rarity", rarity)),
		"downgraded_from_species": str(fish.get("downgraded_from_species", "")),
		"size_cm": size_cm,
		"weight_kg": weight_kg,
		"variant": str(variant_data.variant),
		"variant_marker": str(variant_data.variant_marker),
		"mystery": bool(variant_data.mystery),
		"mystery_marker": str(variant_data.mystery_marker),
		"map": current_map,
		"location": current_map,
		"spot": _nearest_fishing_spot_label(),
		"day": day,
		"time": time_of_day,
		"grade": grade,
		"first_capture": true
	}

func _record_catch_metadata(fish: Dictionary, grade: String) -> Dictionary:
	var fish_name := str(fish.get("name", "Unknown catch"))
	var metadata := _capture_metadata(fish, grade)
	var is_first_capture := not catch_metadata.has(fish_name)
	# First-capture metadata is immutable.  The latest record still changes on
	# every catch, allowing each reveal to show its own size and variant.
	if is_first_capture:
		reveal_shortened = false
	else:
		metadata["first_capture"] = false
		reveal_shortened = true
	catch_latest[fish_name] = metadata.duplicate(true)
	var record: Dictionary = best_records.get(fish_name, {})
	var is_crown := float(metadata.get("size_cm", 0.0)) > float(record.get("size_cm", 0.0))
	if is_crown:
		record = {"size_cm":float(metadata.get("size_cm", 0.0)),"weight_kg":float(metadata.get("weight_kg", 0.0)),"day":day}
		best_records[fish_name] = record.duplicate(true)
	metadata["crown"] = is_crown
	metadata["record_size_cm"] = float(record.get("size_cm", metadata.get("size_cm", 0.0)))
	metadata["record_weight_kg"] = float(record.get("weight_kg", metadata.get("weight_kg", 0.0)))
	if is_first_capture:
		catch_metadata[fish_name] = metadata.duplicate(true)
		first_capture_metadata[fish_name] = metadata.duplicate(true)
	catch_latest[fish_name] = metadata.duplicate(true)
	last_catch_metadata = metadata.duplicate(true)
	last_catch_size_cm = float(metadata.get("size_cm", 0.0))
	last_catch_weight_kg = float(metadata.get("weight_kg", 0.0))
	last_catch_variant = str(metadata.get("variant", "Standard"))
	last_catch_mystery = bool(metadata.get("mystery", false))
	return metadata

func get_first_capture_metadata(species: String) -> Dictionary:
	return (first_capture_metadata.get(species, {}) as Dictionary).duplicate(true)

func get_catch_metadata(species: String) -> Dictionary:
	return (catch_metadata.get(species, {}) as Dictionary).duplicate(true)

func _ledger_marker(species: String, owned: int) -> String:
	if owned <= 0: return "?"
	var metadata := get_first_capture_metadata(species)
	return _metadata_marker(metadata)

func _metadata_marker(metadata: Dictionary) -> String:
	# Mystery takes precedence over cosmetic variants.  Keep the fallback marker
	# explicit so old/hand-authored saves still render an unknown catch clearly.
	if bool(metadata.get("mystery", false)):
		var mystery_marker := str(metadata.get("mystery_marker", "?"))
		return mystery_marker if mystery_marker != "" else "?"
	var variant_marker := str(metadata.get("variant_marker", ""))
	return variant_marker

func bait_name() -> String: return str(BAITS[bait_index].name)
func rod_name() -> String: return str(RODS[rod_index].name)
func cycle_bait(step: int = 1) -> void:
	if fishing_state != FishingState.IDLE: return
	bait_index = posmod(bait_index + step, BAITS.size())
	toast = "%s selected (%d shells, rarity +%d%%)" % [bait_name(), int(BAITS[bait_index].cost), int(BAITS[bait_index].rarity_bonus * 100.0)]
	toast_t = 2.0
func cycle_rod(step: int = 1) -> void:
	if fishing_state != FishingState.IDLE: return
	rod_index = posmod(rod_index + step, RODS.size())
	toast = "%s selected (line strain x%.2f)" % [rod_name(), float(RODS[rod_index].tension_mult)]
	toast_t = 2.0

func _try_fish():
	if notebook_open: return
	if fishing_state == FishingState.RESULT:
		_reset_fishing()
		return
	if fishing_state != FishingState.IDLE: return
	if _can_fish():
		var bait_cost := int(BAITS[bait_index].cost)
		if shells < bait_cost:
			toast = "Need %d shells for %s (you have %d)" % [bait_cost, bait_name(), shells]; toast_t = 2.5
			return
		shells -= bait_cost
		fishing_state = FishingState.ANTICIPATING
		promotion_t = 0.0
		promotion_stage = 0
		promotion_reversal = false
		promotion_false_cue = false
		promotion_false_cue_revealed = false
		promotion_reversal_armed = false
		promotion_result_label = ""
		cast_candidate = _pick_cast_candidate(true)
		cast_good_candidate = _pick_good_substitute(cast_candidate)
		promotion_target_rarity = str(cast_candidate.get("rarity", "COMMON"))
		promotion_cue_rank = _rarity_rank(promotion_target_rarity)
		# The cue is decided once, at cast time.  A high-rarity candidate can
		# occasionally look ordinary, and a common/uncommon candidate can flash a
		# misleading high promotion.  No new random roll occurs while the float is
		# moving, so the same cast always tells the same visual story.
		var cue_roll := rng.randf()
		if cue_roll < PROMOTION_FALSE_CUE_CHANCE and promotion_cue_rank >= 2:
			promotion_false_cue = true
			promotion_cue_rank = maxi(0, promotion_cue_rank - 2)
		elif cue_roll < PROMOTION_FALSE_RAINBOW_CHANCE and promotion_cue_rank <= 1:
			promotion_false_cue = true
			promotion_cue_rank = 3
		elif cue_roll < PROMOTION_FALSE_RAINBOW_CHANCE + PROMOTION_FALSE_PURPLE_CHANCE and promotion_cue_rank <= 1:
			promotion_false_cue = true
			promotion_cue_rank = 2
		promotion_reversal_armed = rng.randf() < PROMOTION_REVERSAL_CHANCE
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
	# Notebook and map transitions pause fishing; the same pause applies here.
	# Thirty seconds leaves room for the reveal and another full tug-of-war.
	fever_flash_t = maxf(0.0, fever_flash_t - delta)
	if fever_active:
		fever_t = maxf(0.0, fever_t - delta)
		if fever_t <= 0.0:
			_break_chain()
			toast = "FEVER ended / Build another three-catch chain"
			toast_t = 2.0
	if fishing_state == FishingState.ANTICIPATING:
		bite_timer += delta
		promotion_t = bite_timer
		var promotion_progress := clampf(bite_timer / maxf(0.01, bite_delay), 0.0, 1.0)
		var stage_bias := 0.12 * float(promotion_cue_rank)
		var cue_progress := clampf(promotion_progress + stage_bias, 0.0, 1.0)
		var raw_stage := 3 if cue_progress >= 0.86 else (2 if cue_progress >= 0.62 else (1 if cue_progress >= 0.34 else 0))
		var stage_limit := _promotion_max_stage(promotion_target_rarity)
		if promotion_false_cue: stage_limit = _promotion_max_stage(str(["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"][promotion_cue_rank]))
		promotion_stage = mini(raw_stage, stage_limit)
		if promotion_reversal_armed and promotion_progress > 0.62 and promotion_progress < 0.76: promotion_reversal = true
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
			battle_tension = clampf(0.22 + float(BAITS[bait_index].tension_bonus), 0.0, 0.9)
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
		battle_escape = clampf(battle_escape + delta * (-0.035 if countering else (0.095 if straining else 0.055)) * float(RODS[rod_index].escape_mult), 0.0, 1.0)
		battle_tension = clampf(battle_tension + delta * (-0.045 if countering else (0.07 if straining else -0.014)) * float(RODS[rod_index].tension_mult), 0.0, 1.0)
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
			legendary_t = minf(legendary_t + delta, 6.0)
			# Keep the generic reveal state in sync for deterministic probes and
			# future result skins; legendary keeps its established six-second arc.
			reveal_t = legendary_t
			reveal_stage = _reveal_stage_at(reveal_t, last_rarity)
			# The catch is deliberately paced: a small omen, rising energy, a
			# full-screen climax, then a long rainbow afterglow.
			if previous_legendary_t < 0.82 and legendary_t >= 0.82:
				legendary_stage = maxi(legendary_stage, 1)
				_play_se("rise")
				flash_t = maxf(flash_t, 0.42)
				shake_t = maxf(shake_t, 0.65)
			if previous_legendary_t < 2.05 and legendary_t >= 2.05:
				legendary_stage = maxi(legendary_stage, 2)
				_play_se("peak")
				flash_t = maxf(flash_t, 1.35)
				shake_t = maxf(shake_t, 1.8)
			if previous_legendary_t < 3.75 and legendary_t >= 3.75:
				legendary_stage = maxi(legendary_stage, 3)
				_play_se("after")
		elif last_grade != "MISS":
			var previous_reveal_t := reveal_t
			var reveal_duration := 1.24 if reveal_shortened else 2.0
			reveal_t = minf(reveal_t + delta, reveal_duration)
			reveal_stage = _reveal_stage_at(reveal_t, last_rarity)
			# A single gentle chime marks the flip; no rapid white flashes.
			var flip_time := 0.92 if reveal_shortened else 1.48
			if previous_reveal_t < flip_time and reveal_t >= flip_time:
				_play_se("rise")
	flash_t = maxf(0.0, flash_t-delta)
	shake_t = maxf(0.0, shake_t-delta)
	fish_particle_t += delta

# Stage boundaries are fixed so a seed, frame rate, or renderer cannot change
# the order of the reveal.  Legendary reuses its existing six-second timing;
# standard catches fit the same two-second result window they had before.
func _reveal_stage_at(time: float, rarity: String) -> int:
	if rarity == "LEGENDARY":
		if time < 0.82: return 0 # unknown omen
		if time < 2.05: return 1 # rarity and energy rising
		if time < 3.75: return 2 # full-screen reveal
		return 3 # afterglow
	var scale := 0.62 if reveal_shortened else 1.0
	if time < 0.42 * scale: return 0 # card back and ???
	if time < 0.82 * scale: return 1 # rarity seal
	if time < 1.42 * scale: return 2 # growing silhouette/light
	if time < 1.78 * scale: return 3 # card flip
	return 4 # fish name revealed

func reveal_stage_name() -> String:
	if last_rarity == "LEGENDARY":
		match reveal_stage:
			0: return "UNKNOWN"
			1: return "RISING"
			2: return "CLIMAX"
			3: return "AFTERGLOW"
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
		"EPIC": return Color("#d19cff")
		"LEGENDARY": return Color("#f6c76b")
		_: return Color("#b7c3d7")

func _start_fever() -> void:
	fever_active = true
	fever_t = FEVER_DURATION
	fever_flash_t = 1.0
	_music_call("set_fever", [true])
	_play_se("fever")

func _break_chain() -> void:
	combo = 0
	fever_active = false
	fever_t = 0.0
	fever_flash_t = 0.0
	_music_call("set_fever", [false])
	_music_call("set_combo", [0])

func _resolve_fishing_timing(position: float):
	var grade := "MISS"
	if position >= 0.42 and position <= 0.62: grade = "PERFECT"
	elif position >= 0.26 and position <= 0.80: grade = "GOOD"
	if grade == "MISS":
		promotion_false_cue_revealed = promotion_false_cue
		promotion_result_label = ""
		_break_chain()
		_advance_pity("MISS")
		last_catch = "The fish got away"
		last_rarity = ""
		last_grade = grade
		last_catch_metadata = {}
		last_catch_size_cm = 0.0
		last_catch_weight_kg = 0.0
		last_catch_variant = "Standard"
		last_catch_mystery = true
		last_rescue_used = false
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
	var fever_started := combo >= FEVER_THRESHOLD and not fever_active
	if fever_started: _start_fever()
	last_grade = grade
	var rescue_was_ready := rescue_ready
	# The species roll belongs to the cast, not to the final timing frame.  This
	# keeps the promotion cue, the revealed fish, and the ledger in lockstep.
	# Timing still has explicit effects: PERFECT keeps the clean grade/pity reset
	# and allows the bounded legendary reveal, while GOOD records a lower-quality
	# catch and advances the rescue meter when appropriate.
	promotion_false_cue_revealed = promotion_false_cue
	var picked: Dictionary = cast_candidate.duplicate(true)
	if picked.is_empty():
		# Compatibility callers such as _finish_cast may resolve without opening a
		# visible anticipation state first.  Establish the candidate once, then use
		# that same dictionary for the result.
		picked = _pick_cast_candidate(rescue_was_ready)
		cast_candidate = picked.duplicate(true)
	var candidate_rarity := str(picked.get("rarity", "COMMON"))
	picked = _candidate_for_grade(picked, grade)
	var legendary := grade == "PERFECT" and str(picked.get("rarity", "COMMON")) == "LEGENDARY"
	var result_rank := _rarity_rank(str(picked.get("rarity", "COMMON")))
	var candidate_rank := _rarity_rank(candidate_rarity)
	var effective_cue_rank := maxi(0, promotion_cue_rank - (1 if promotion_reversal else 0))
	if result_rank > effective_cue_rank and result_rank >= _rarity_rank("RARE"):
		promotion_result_label = "逆転!"
	elif result_rank < effective_cue_rank:
		promotion_result_label = "惜しい!  PERFECTなら " + candidate_rarity if candidate_rank > result_rank and not promotion_false_cue else "ガセ…"
	else:
		promotion_result_label = ""
	last_catch = str(picked.name)
	last_rarity = str(picked.rarity)
	last_rescue_used = rescue_was_ready and rescue_selection_used and _rarity_rank(last_rarity) >= _rarity_rank("RARE")
	# A clean or genuinely rare catch closes the unlucky streak.  GOOD/common
	# outcomes remain visible on the meter, allowing the one-shot rescue hook to
	# arm without silently granting a win.
	if _rarity_rank(last_rarity) >= _rarity_rank("RARE") or grade == "PERFECT":
		_reset_pity()
	else:
		_advance_pity("GOOD")
	_music_call("set_combo", [combo])
	_music_call("play_fanfare", [legendary])
	fish_count += 1
	shells += 1
	catches[last_catch] = int(catches.get(last_catch,0))+1
	_record_catch_metadata(picked, grade)
	fishing_state = FishingState.RESULT
	cast_timer = 0.0
	legendary_t = 0.0
	legendary_stage = 0
	reveal_t = 0.0
	reveal_stage = 0
	result_t = 6.2 if last_rarity == "LEGENDARY" else 2.0
	flash_t = 0.90 if last_rarity == "LEGENDARY" else (0.32 if last_rarity == "RARE" else 0.18)
	shake_t = 1.10 if last_rarity == "LEGENDARY" else (0.22 if last_rarity == "RARE" else 0.10)
	_play_se("catch" if last_rarity != "LEGENDARY" else "legendary")
	toast = ("BIG CATCH!!  " if legendary else grade + "!  ") + last_catch + "  /  SPACE to cast again"
	if rescue_was_ready and last_rescue_used:
		toast = "RESCUE! RARE floor / " + last_catch
	if fever_started: toast = "FEVER! Rarity boosted for 30s / " + last_catch
	toast_t = result_t

func _handle_fishing_strike(position: float, counter_axis: float = 0.0):
	if pull_cooldown > 0.0: return
	pull_cooldown = 1.8

	# Challenge beats are deliberately forgiving and resolve before the normal
	# gauge grade.  A missed beat strains the same authoritative line model as a
	# missed gold-zone pull; it never bypasses the existing escape/tension rules.
	if fishing_challenge != null and not fishing_challenge.done:
		var challenge_result: Dictionary = fishing_challenge.accept(position, counter_axis)
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
		battle_tension = clampf(battle_tension + 0.33 * float(RODS[rod_index].tension_mult), 0.0, 1.0)
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
		"fever":
			base = 392.0; duration = 0.55; volume = 0.28; sweep = 392.0; tones = [523.2, 659.2]
		"legendary":
			base = 330.0; duration = 0.52; volume = 0.36; sweep = 260.0; tones = [495.0, 660.0, 990.0]
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
	if fishing_state == FishingState.IDLE: _break_chain()
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
	last_catch_metadata = {}
	last_catch_size_cm = 0.0
	last_catch_weight_kg = 0.0
	last_catch_variant = "Standard"
	last_catch_mystery = false
	last_rescue_used = false
	rescue_selection_used = false
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
	cast_candidate = {}
	cast_good_candidate = {}
	promotion_target_rarity = "COMMON"
	promotion_cue_rank = 0
	promotion_false_cue = false
	promotion_false_cue_revealed = false
	promotion_reversal_armed = false
	promotion_reversal = false
	promotion_result_label = ""
	toast = "Ready to cast"
	toast_t = 1.2

func _save_game(path: String = SAVE_PATH):
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		toast = "Could not save. Please check available storage."; toast_t = 4; return
	f.store_string(JSON.stringify({"version":10,"combo":combo,"fever_t":fever_t,"pity_meter":pity_meter,"rescue_meter":pity_meter,"rescue_ready":rescue_ready,"low_grade_streak":low_grade_streak,"map":current_map,"day":day,"time":time_of_day,"weather":weather,"season":season,"fish":fish_count,"shells":shells,"bait":bait_index,"rod":rod_index,"x":player.x,"y":player.y,"catches":catches,"catch_metadata":catch_metadata,"first_capture_metadata":first_capture_metadata,"catch_latest":catch_latest,"best_records":best_records,"rumor_found":rumor_found,"hidden_spot_unlocked":hidden_spot_unlocked,"hidden_spot_collected":hidden_spot_collected}))
	toast = "Saved to the tide ledger"; toast_t = 2.4

func _normalize_catch_metadata(raw: Dictionary, species: String, first_capture := true) -> Dictionary:
	var metadata := raw.duplicate(true)
	metadata["species"] = str(metadata.get("species", species))
	metadata["rarity"] = str(metadata.get("rarity", "COMMON"))
	metadata["original_rarity"] = str(metadata.get("original_rarity", metadata["rarity"]))
	metadata["downgraded_from_species"] = str(metadata.get("downgraded_from_species", ""))
	metadata["size_cm"] = maxf(0.0, float(metadata.get("size_cm", 0.0)))
	metadata["weight_kg"] = maxf(0.0, float(metadata.get("weight_kg", 0.0)))
	metadata["variant"] = str(metadata.get("variant", "Standard"))
	metadata["variant_marker"] = str(metadata.get("variant_marker", ""))
	metadata["mystery"] = bool(metadata.get("mystery", false))
	metadata["mystery_marker"] = str(metadata.get("mystery_marker", ""))
	metadata["map"] = str(metadata.get("map", metadata.get("location", "town")))
	metadata["location"] = str(metadata.get("location", metadata["map"]))
	metadata["spot"] = str(metadata.get("spot", "Open water"))
	metadata["day"] = maxi(1, int(metadata.get("day", 1)))
	metadata["time"] = clampf(float(metadata.get("time", 0.35)), 0.0, 1.0)
	metadata["grade"] = str(metadata.get("grade", "GOOD"))
	metadata["first_capture"] = first_capture
	return metadata

func _load_game(path: String = SAVE_PATH):
	if not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	var loaded_map := str(data.get("map","town"))
	if loaded_map in ["town","beach","rocky"] and loaded_map != current_map:
		current_map = loaded_map; _build_map(current_map)
	day = maxi(1,int(data.get("day",1))); fish_count = maxi(0,int(data.get("fish",0)))
	shells = maxi(0, int(data.get("shells", 12)))
	bait_index = clampi(int(data.get("bait", 0)), 0, BAITS.size()-1)
	rod_index = clampi(int(data.get("rod", 0)), 0, RODS.size()-1)
	time_of_day = clampf(float(data.get("time",0.35)),0.0,1.0)
	weather = _normalize_weather(str(data.get("weather", _weather_for_day(day))))
	season = _normalize_season(str(data.get("season", _season_for_day(day))))
	var saved_pos := Vector2(float(data.get("x",368)),float(data.get("y",372)))
	if _walkable(saved_pos): player = saved_pos
	if data.get("catches",{}) is Dictionary: catches = data.get("catches",{})
	catch_metadata.clear()
	first_capture_metadata.clear()
	catch_latest.clear()
	best_records.clear()
	var saved_metadata = data.get("catch_metadata", data.get("first_capture_metadata", {}))
	if saved_metadata is Dictionary:
		for species in saved_metadata:
			if saved_metadata[species] is Dictionary:
				var metadata := _normalize_catch_metadata(saved_metadata[species], str(species), true)
				catch_metadata[str(species)] = metadata
				first_capture_metadata[str(species)] = metadata.duplicate(true)
	var saved_first = data.get("first_capture_metadata", {})
	if saved_first is Dictionary:
		for species in saved_first:
			if saved_first[species] is Dictionary:
				var first := _normalize_catch_metadata(saved_first[species], str(species), true)
				first_capture_metadata[str(species)] = first
				if not catch_metadata.has(str(species)): catch_metadata[str(species)] = first.duplicate(true)
	var saved_latest = data.get("catch_latest", {})
	if saved_latest is Dictionary:
		for species in saved_latest:
			if saved_latest[species] is Dictionary:
				catch_latest[str(species)] = _normalize_catch_metadata(saved_latest[species], str(species), false)
	for species in catch_metadata:
		if not catch_latest.has(species): catch_latest[species] = catch_metadata[species].duplicate(true)
	var saved_records = data.get("best_records", {})
	var legacy_metadata := int(data.get("version", 0)) < 9
	if saved_records is Dictionary:
		for species in saved_records:
			if saved_records[species] is Dictionary:
				best_records[str(species)] = saved_records[species].duplicate(true)
	# Version 8 saves did not have best_records. Reconstruct them from every
	# durable measurement we do have so the first post-migration repeat cannot
	# become a false crown just because the new ledger field is absent.
	for species in catch_metadata:
		var key := str(species)
		var known: Dictionary = best_records.get(key, {})
		for source in [catch_metadata.get(key, {}), first_capture_metadata.get(key, {}), catch_latest.get(key, {})]:
			if source is Dictionary and float(source.get("size_cm", 0.0)) > float(known.get("size_cm", 0.0)):
				known = {"size_cm":float(source.get("size_cm", 0.0)),"weight_kg":float(source.get("weight_kg", 0.0)),"day":int(source.get("day", day))}
		if not known.is_empty(): best_records[key] = known
	# Backfill the derived fields that were absent from pre-v9 metadata so all
	# callers see the same crown/record contract after migration.
	for species in first_capture_metadata:
		var key := str(species)
		var record: Dictionary = best_records.get(key, {})
		if record.is_empty(): continue
		var first: Dictionary = first_capture_metadata[key]
		if legacy_metadata or not first.has("crown"):
			# A legacy first capture is the immutable discovery record. Preserve its
			# historical crown even when a later specimen is larger.
			first["crown"] = true
		if legacy_metadata or not first.has("record_size_cm"):
			first["record_size_cm"] = float(record.get("size_cm", first.get("size_cm", 0.0)))
		if legacy_metadata or not first.has("record_weight_kg"):
			first["record_weight_kg"] = float(record.get("weight_kg", first.get("weight_kg", 0.0)))
		catch_metadata[key] = first.duplicate(true)
		first_capture_metadata[key] = first
		if catch_latest.has(key):
			var latest: Dictionary = catch_latest[key]
			if legacy_metadata or not latest.has("record_size_cm"): latest["record_size_cm"] = float(record.get("size_cm", latest.get("size_cm", 0.0)))
			if legacy_metadata or not latest.has("record_weight_kg"): latest["record_weight_kg"] = float(record.get("weight_kg", latest.get("weight_kg", 0.0)))
			if legacy_metadata or not latest.has("crown"): latest["crown"] = is_equal_approx(float(latest.get("size_cm", 0.0)), float(record.get("size_cm", 0.0)))
			catch_latest[key] = latest
	rumor_found = bool(data.get("rumor_found", false))
	hidden_spot_unlocked = bool(data.get("hidden_spot_unlocked", rumor_found and fish_count >= 3))
	hidden_spot_collected = bool(data.get("hidden_spot_collected", false))
	combo = clampi(int(data.get("combo", 0)), 0, 999)
	pity_meter = clampi(int(data.get("pity_meter", data.get("rescue_meter", 0))), 0, PITY_THRESHOLD)
	low_grade_streak = clampi(int(data.get("low_grade_streak", 0)), 0, PITY_THRESHOLD)
	rescue_ready = bool(data.get("rescue_ready", pity_meter >= PITY_THRESHOLD))
	if pity_meter < PITY_THRESHOLD: rescue_ready = false
	fever_t = clampf(float(data.get("fever_t", 0.0)), 0.0, FEVER_DURATION)
	fever_active = fever_t > 0.0 and combo >= FEVER_THRESHOLD
	if not fever_active: fever_t = 0.0
	fever_flash_t = 0.0
	_music_call("set_fever", [fever_active])
	_music_call("set_combo", [combo])
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
		var float_color := Color("#6db7ff")
		var visible_stage := _visible_promotion_stage()
		if visible_stage == 1: float_color = Color("#f0c65a")
		elif visible_stage == 2: float_color = Color("#b383ff")
		elif visible_stage >= 3: float_color = Color.from_hsv(fmod(elapsed*0.22,1.0),0.72,1.0)
		draw_circle(float_pos+Vector2(1,1),3.0+sin(elapsed*10)*1.2,float_color)

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
		elif kind == "hidden_pool":
			draw_circle(p,19.0,Color("#2d426c")); draw_circle(p-Vector2(3,3),13.0,Color("#8065b4"))
			draw_arc(p,19.0,0,TAU,20,Color("#e1c6ff"),2.0)
			if hidden_spot_unlocked: draw_string(ThemeDB.fallback_font,p+Vector2(-45,29),str(landmark.label),HORIZONTAL_ALIGNMENT_CENTER,90,8,Color("#c6b4df"))
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
	_text(Vector2(16,35),"Day %02d    Fish %02d  Shells %02d" % [day,fish_count,shells],10)
	_panel(Rect2(8,40,174,18))
	_text(Vector2(15,53),environment_label() + "  " + clock_text(),8)
	_panel(Rect2(294,8,178,22))
	_text(Vector2(302,23),"[N] Ledger   [B] Bait: %s   [R] Rod: %s" % [bait_name(), rod_name()],10)
	_panel(Rect2(8,244,464,19))
	_text(Vector2(15,257),toast if toast_t>0 else _map_hint(),10)
	var nearby_exit := _exit_hint()
	if nearby_exit != "" and not notebook_open and not transition_active:
		_panel(Rect2(286,218,184,20))
		_text(Vector2(294,232),nearby_exit,10)
	if _can_fish() and not notebook_open and fishing_state == FishingState.IDLE:
		_panel(Rect2(172,218,138,20)); _text(Vector2(182,232),"SPACE Cast  /  B bait  /  R rod",10)
	if fishing_state == FishingState.ANTICIPATING or fishing_state == FishingState.TIMING:
		_draw_fishing_hud()
	elif fishing_state == FishingState.RESULT:
		_draw_fishing_result()
	if not notebook_open:
		# Draw after the result card so the timer cannot be hidden by its reveal.
		_panel(Rect2(188,8,100,30))
		_text(Vector2(195,21),("FEVER %.0fs" % ceilf(fever_t)) if fever_active else ("CHAIN %d/%d" % [combo, FEVER_THRESHOLD]),10)
		hud_bar(Vector2(195,27),Vector2(85,4),fever_t / FEVER_DURATION if fever_active else float(combo) / FEVER_THRESHOLD,Color("#efbf69"))
		_panel(Rect2(188,40,100,18))
		_text(Vector2(195,53),_pity_label(),8)
		if fever_flash_t > 0.0:
			hud.draw_rect(Rect2(0,0,480,270),Color(1.0,0.62,0.18,fever_flash_t*0.10))
	if notebook_open:
		_panel(Rect2(66,51,348,194),true)
		_text(Vector2(85,75),"THE TIDE LEDGER",17,true)
		_text(Vector2(85,94),"Saltmere / " + current_map.capitalize() + "  " + _time_period().to_upper(),10,true)
		_text(Vector2(85,104),"Rescue: " + ("READY / next catch RARE+" if rescue_ready else "%d/%d unlucky pulls" % [pity_meter, PITY_THRESHOLD]),9,true)
		# Three-column field guide: every species has a card fallback portrait.
		var rows := 8
		for i in range(FISH_SPECIES.size()):
			var fish: Dictionary = FISH_SPECIES[i]
			var col := i / rows
			var row := i % rows
			var x := 82.0 + col * 112.0
			var y := 114.0 + row * 14.0
			var owned := int(catches.get(str(fish.name),0))
			var icon := Color("#b6c7d9") if owned == 0 else _rarity_color(str(fish.rarity))
			hud.draw_rect(Rect2(x,y-9,8,8),icon)
			var marker := _ledger_marker(str(fish.name), owned)
			var display_name := str(fish.name) if owned > 0 else "????????"
			if marker != "": display_name += " " + marker
			if best_records.has(str(fish.name)): display_name += " ^"
			_text(Vector2(x+11,y),display_name,8,true)
			_text(Vector2(x+85,y),str(owned),8,true)
		_text(Vector2(85,232),"Rumor: " + ("heard" if rumor_found else "find the weathered notice"),9,true)
		_text(Vector2(85,241),"? mystery  ~ shimmer  ! gilded  ^ crown  /  N close",8,true)
		_text(Vector2(85,223),"N to close  /  Movement pauses while reading",10,true)

func _draw_fishing_hud():
	if fishing_state == FishingState.TIMING:
		var power := 1.0 - float(fish_hp) / maxf(1.0,fish_hp_max)
		for i in range(14):
			var a := float(i) * TAU / 14.0 + elapsed * 0.16
			var start := Vector2(240,126) + Vector2(cos(a),sin(a))* (140.0 + power * 55.0)
			var end := Vector2(240,126) + Vector2(cos(a),sin(a))* 350.0
			hud.draw_line(start,end,Color.from_hsv(float(i)/14.0,0.55,1.0,0.10+power*0.46),2.0+power*3.0)
	var challenge_live: bool = fishing_challenge != null and not fishing_challenge.done
	var challenge_offset := 30 if challenge_live else 0
	var panel := Rect2(96,48,288,160 + challenge_offset)
	_panel(panel)
	_text(Vector2(114,70), "FISHING  /  " + ("WAIT FOR THE BITE" if fishing_state == FishingState.ANTICIPATING else "TUG-OF-WAR"), 12)
	if fishing_state == FishingState.ANTICIPATING:
		var p := clampf(bite_timer / maxf(0.01,bite_delay), 0.0, 1.0)
		hud_bar(Vector2(114,98),Vector2(252,8),p,Color("#6c9b91"))
		var cue: String = ["FLOAT BLUE  /  quiet water", "FLOAT GOLD  /  promotion cue", "FLOAT PURPLE  /  hold your breath", "RAINBOW PROMOTION  /  BITE!"][_visible_promotion_stage()]
		_text(Vector2(114,123), cue, 10)
		_text(Vector2(114,137), "Read the float, then trust your timing", 8)
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
			var lane: float = fishing_challenge.safe_lane()
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
	if promotion_result_label != "" or promotion_false_cue_revealed:
		_text(Vector2(116,147),promotion_result_label if promotion_result_label != "" else "FALSE CUE REVEALED",9)
		_text(Vector2(116,160),"SPACE  cast again",10)
	else:
		_text(Vector2(116,155),"SPACE  cast again",11)
	if flash_t > 0.0:
		hud.draw_rect(Rect2(0,0,480,270),Color(1.0,0.9,0.55,flash_t*0.28))
	if last_grade != "MISS":
		var sparkle_color := Color("#ffffff") if last_rarity == "LEGENDARY" else (Color("#f8dc75") if last_rarity == "RARE" else Color("#c6e6b7"))
		var sparkle_count := 28 if last_rarity == "LEGENDARY" else (20 if last_rarity == "EPIC" else (14 if last_rarity == "RARE" else 7))
		for i in range(sparkle_count):
			var a := fish_particle_t*2.0 + float(i)*TAU/float(sparkle_count)
			var q := Vector2(240,108) + Vector2(cos(a),sin(a))* (42.0 + sin(fish_particle_t*5.0+i)*5.0)
			hud.draw_circle(q,3.0 if last_rarity == "LEGENDARY" else 2.0,Color.from_hsv(fmod(float(i)/float(sparkle_count)+fish_particle_t*0.1,1.0),0.72,1.0) if last_rarity == "LEGENDARY" else sparkle_color)

func _draw_standard_reveal_result():
	var t := reveal_t
	var timing_scale := 0.62 if reveal_shortened else 1.0
	var center := Vector2(240,137)
	var rarity_col := _rarity_color(last_rarity)
	var rise := clampf((t - 0.82 * timing_scale) / (0.60 * timing_scale), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	var flip_start := 1.42 * timing_scale
	var flip_end := 1.78 * timing_scale
	var flip_p := clampf((t - flip_start) / (0.36 * timing_scale), 0.0, 1.0)
	var face_visible := t >= flip_end
	# The card stays on screen for the whole reveal. A wide back, a narrow
	# turning edge, and a wide face read as one smooth flip rather than a cut.
	var card_half_width := 136.0
	if t >= flip_start and t < flip_end:
		card_half_width = maxf(7.0, 136.0 * absf(cos(flip_p * PI)))
	var card_rect := Rect2(center.x - card_half_width, 35, card_half_width * 2.0, 194)
	_panel(card_rect)
	hud.draw_rect(card_rect.grow(-5), Color(0.06, 0.10, 0.18, 0.72))
	# Soft rings and rays make the silhouette grow without using strobing.
	if t >= 0.42 * timing_scale:
		for ring in range(3):
			var radius := 28.0 + rise * (18.0 + ring * 15.0)
			hud.draw_arc(center, radius, 0, TAU, 64, Color(rarity_col, 0.16 + pulse * 0.08), 1.5)
	if t >= 0.82 * timing_scale:
		for i in range(12):
			var a := float(i) * TAU / 12.0 + t * 0.10
			var inner := 40.0 + rise * 18.0
			var outer := inner + 13.0 + rise * 28.0
			hud.draw_line(center + Vector2(cos(a), sin(a)) * inner, center + Vector2(cos(a), sin(a)) * outer, Color(rarity_col, 0.22 + rise * 0.28), 1.0)
	var fish_scale := 0.28
	if t >= 0.42 * timing_scale:
		fish_scale = 0.36 + rise * 0.64
	var fish_col := Color("#111a2b") if not face_visible else rarity_col.lightened(0.12)
	var fish_width_scale := 1.0
	if t >= flip_start and t < flip_end:
		fish_width_scale = absf(cos(flip_p * PI))
	_draw_reveal_fish(center, fish_scale, fish_col, face_visible, fish_width_scale)
	if face_visible:
		# Coloured bands remain subtle so the card and name carry the reveal.
		for k in range(5):
			var band_x := -38.0 + float(k) * 18.0
			hud.draw_line(center + Vector2(band_x, -13) * fish_scale, center + Vector2(band_x + 5, 16) * fish_scale, Color(1.0, 0.92, 0.70, 0.42), 2.0)
	if t < 0.42 * timing_scale:
		_center_text(68, "???", 28, Color("#e7edf7"))
		_center_text(207, "A hidden tide catch", 10, Color("#b4c5db"))
	elif t < 0.82 * timing_scale:
		_center_text(66, "RARITY...", 18, rarity_col.lightened(0.22))
		_center_text(207, "The water holds its breath", 10, Color("#c4d1e2"))
	elif t < flip_start:
		_center_text(64, last_rarity, 22, rarity_col.lightened(0.22))
		_center_text(207, "Something is surfacing", 10, Color("#d5e2ef"))
	elif not face_visible:
		_center_text(64, last_rarity, 18, rarity_col.lightened(0.16))
		_center_text(207, "TURNING THE CARD...", 10, Color("#e3e7ee"))
	else:
		_center_text(62, last_rarity, 16, rarity_col.lightened(0.18))
		# Repeats can roll a different cosmetic variant; reveal the current catch
		# marker while the ledger keeps its immutable first-capture marker.
		var reveal_marker := _metadata_marker(last_catch_metadata)
		if reveal_marker == "": reveal_marker = _ledger_marker(last_catch, 1)
		var reveal_name := last_catch + (" " + reveal_marker if reveal_marker != "" else "") + ("  CROWN" if bool(last_catch_metadata.get("crown", false)) else "")
		_center_text(207, reveal_name, 19, Color("#fff0c6"))
		_center_text(225, "%s  /  COMBO x%d" % [last_rarity, combo], 10, Color("#d3deec"))
		_center_text(239, "%.1f cm  /  %.2f kg  /  %s%s" % [last_catch_size_cm, last_catch_weight_kg, last_catch_variant, "  NEW" if bool(last_catch_metadata.get("first_capture", false)) else ""], 9, Color("#c8d8e8"))
		if promotion_result_label != "" or promotion_false_cue_revealed:
			_center_text(250, promotion_result_label if promotion_result_label != "" else "FALSE CUE REVEALED", 9, Color("#f7f0cb"))
			_center_text(260, "SPACE  continue", 9, Color("#fff0d8"))
		else:
			_center_text(250, "SPACE  continue", 10, Color("#fff0d8"))
	# A single low-alpha wash at the flip keeps the card readable and avoids
	# the rapid flashing that makes ordinary catches tiring to watch.
	if t >= flip_start and t < flip_end:
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
		# A wide ribbon and a large trophy silhouette dominate the final frame.
		hud.draw_colored_polygon(PackedVector2Array([Vector2(14,19),Vector2(466,19),Vector2(455,63),Vector2(24,63)]),Color(0.12,0.05,0.2,0.88))
		hud.draw_line(Vector2(16,19),Vector2(464,19),Color("#ffe39a"),3)
		hud.draw_line(Vector2(24,63),Vector2(456,63),Color("#ffe39a"),3)
		_center_text(53,"LEGENDARY!!",35,Color("#fff4bd"))
		var legendary_marker := _metadata_marker(last_catch_metadata)
		var legendary_name := str(last_catch).to_upper() + (" " + legendary_marker if legendary_marker != "" else "") + ("  CROWN" if bool(last_catch_metadata.get("crown", false)) else "")
		_center_text(211,legendary_name,24,Color("#fff3c9"))
		_center_text(231,"BIG CATCH!   COMBO x%d" % combo,15,Color("#e4d2ff"))
		_center_text(245,"%.1f cm  /  %.2f kg  /  %s" % [last_catch_size_cm, last_catch_weight_kg, last_catch_variant],9,Color("#d8d0ff"))
		if promotion_result_label != "" or promotion_false_cue_revealed:
			_center_text(258,(promotion_result_label if promotion_result_label != "" else "FALSE CUE REVEALED") + "  /  SPACE",9,Color("#f7f0cb"))
		else:
			_center_text(258,"SPACE  continue",10,Color("#fff0d8"))
	# The fish grows from a dark silhouette to a full-width rainbow trophy.
	var scale := 0.22 + rise * 0.55 + peak * 0.28
	var body := PackedVector2Array([Vector2(-84,0),Vector2(-55,-25),Vector2(29,-30),Vector2(65,-13),Vector2(87,0),Vector2(65,18),Vector2(30,30),Vector2(-51,25)])
	var transformed := PackedVector2Array()
	for p in body: transformed.append(center + p * scale)
	hud.draw_colored_polygon(transformed,Color("#130f32") if t < 2.05 else Color("#fff1c2"))
	hud.draw_colored_polygon(PackedVector2Array([center+Vector2(-67,0)*scale,center+Vector2(-112,-36)*scale,center+Vector2(-108,35)*scale]),Color("#9184ff") if t >= 2.05 else Color("#130f32"))
	if t >= 2.05:
		for k in range(8):
			var x := -50.0 + k * 14.0
			var col := Color.from_hsv(fmod(float(k)/8.0+t*0.025,1.0),0.62,1.0)
			hud.draw_rect(Rect2(center+Vector2(x,-18)*scale,Vector2(13,36)*scale),col)
		hud.draw_colored_polygon(PackedVector2Array([center+Vector2(-25,-26)*scale,center+Vector2(5,-53)*scale,center+Vector2(31,-26)*scale]),Color("#d0acff"))
		hud.draw_circle(center+Vector2(57,-8)*scale,5*scale,Color("#162539"))
		hud.draw_circle(center+Vector2(58,-10)*scale,1.5*scale,Color.WHITE)
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
