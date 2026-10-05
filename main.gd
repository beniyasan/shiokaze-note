extends Node2D

const FishingChallengeScript = preload("res://fishing_challenge.gd")
const MusicDirectorScript = preload("res://audio/music_director.gd")
const FxDirectorScript = preload("res://fx/fx_director.gd")
const FxCanvasScript = preload("res://fx/fx_canvas.gd")
const PostFxShader = preload("res://fx/post_fx.gdshader")

# Original v2 world dimensions retained; viewport now shows a walkable slice.
const TILE := 16
const WORLD_W := 64
const WORLD_H := 40
const WORLD_SIZE := Vector2(WORLD_W*TILE, WORLD_H*TILE)
const SAVE_PATH := "user://saltmere_save.json"
# Keep the legendary choice controls clear of the 270px viewport edge. These
# are shared by both the promotion-label and no-label variants so a long-lived
# result cannot move the actionable prompt back to the clipped baseline.
const LEGENDARY_RESULT_PROMOTION_Y := 242.0
const LEGENDARY_RESULT_CHOICE_Y := 252.0
const LEGENDARY_RESULT_NAME_Y := 203.0
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
 # Bait is a per-cast consumable.  The brighter baits improve rarity odds,
 # but their scent also makes a hooked fish surge harder.  Worm is a safe,
 # free fallback rather than a strictly-worse tutorial item.
 {"name":"Worm","cost":0,"rarity_bonus":0.0,"tension_bonus":0.0,"escape_mult":1.0,"risk":"steady"},
 {"name":"Glowbait","cost":2,"rarity_bonus":0.14,"tension_bonus":0.06,"escape_mult":1.06,"risk":"warm line"},
 {"name":"Moonseed","cost":4,"rarity_bonus":0.28,"tension_bonus":0.12,"escape_mult":1.14,"risk":"hot line"}
]
const RODS: Array[Dictionary] = [
 # Rods are also maintenance costs paid when a cast starts.  Each model has a
 # different trade-off: Fiberglass forgives strain but gives the fish a little
 # more escape time, while Stormglass controls escape at the cost of a twitchy
 # line.  There is no free, strictly dominant upgrade.
 {"name":"Reed Rod","cost":0,"tension_mult":1.0,"escape_mult":1.0,"bite_mult":1.0,"risk":"steady"},
 {"name":"Fiberglass Rod","cost":2,"tension_mult":0.82,"escape_mult":1.08,"bite_mult":1.16,"risk":"slow bite"},
 {"name":"Stormglass Rod","cost":4,"tension_mult":1.08,"escape_mult":0.78,"bite_mult":0.88,"risk":"hot line"}
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
const MAP_PRESENTATION_ZOOM := 0.55
var terrain: Texture2D
var map_art: Dictionary = {}
var hero: Texture2D
var props: Array[Dictionary] = []
var solids: Array[Rect2] = []
var landmarks: Array[Dictionary] = []
var textures: Dictionary = {}
# Small portraits and larger card illustrations are used by the encyclopedia.
# Missing art keeps the existing polygon/icon fallback so adding a new species
# never blocks play.
var fish_portraits: Dictionary = {}
var fish_cards: Dictionary = {}
var face := 0
var walk_time := 0.0
var walking := false
var elapsed := 0.0
var cast_timer := 0.0
var catches: Dictionary = {}
# A successful catch is held in a small, explicit decision queue.  The species
# count is incremented when the catch lands (so existing ledgers and saves keep
# their meaning), then selling removes that one held fish.  Registering simply
# confirms the count.  Keeping the queue separate from the durable metadata
# means selling can never erase a discovery or a crown record.
var pending_catch: Dictionary = {}
var pending_catch_state := "" # "pending", "registered", or "sold"
var last_catch_decision := ""
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
 {"name":"Crown snapper","rarity":"EPIC","maps":["town","rocky"]}, {"name":"Singing herring","rarity":"RARE","maps":["town","beach"]}, {"name":"Aurora koi","rarity":"LEGENDARY","maps":["hidden","grotto"]}
]
var rumor_found := false
# Rumor ids heard from Fisher Mera / the notice: "grotto" or a species name.
var heard_rumors: Array = []
var rumor_page := 0
# Result toasts name the catch, so they wait until the card has flipped.
var result_toast_pending := ""
var chain_break_text := ""
var hidden_spot_unlocked := false
var hidden_spot_collected := false
var promotion_t := 0.0
var promotion_stage := 0
var promotion_reversal := false
var promotion_false_cue := false
var promotion_false_cue_revealed := false
var promotion_reversal_armed := false
var promotion_cue_rank := 0
var promotion_rescue_bonus := 0.0
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
# A false rainbow/purple float is capped both by these absolute chances and by a
# ratio of the honest one, so lies stay a minority of each cue.
const PROMOTION_FALSE_RAINBOW_CHANCE := 0.02
const PROMOTION_FALSE_PURPLE_CHANCE := 0.06
const PROMOTION_REVERSAL_CHANCE := 0.24
const PROMOTION_RAINBOW_LIE_RATIO := 0.35  # false rainbow floats per honest one (cap)
const PROMOTION_PURPLE_LIE_RATIO := 0.60   # purple may mislead a little more often
## Soft pity is a transparent rescue hook for an unlucky run.  A miss or a
## low-grade (GOOD) catch advances the meter, but the player still has to land
## the next battle normally.  Once armed, the hook only changes the species
## floor to RARE; it never auto-wins a cast or bypasses map/grade rules.
const PITY_THRESHOLD := 3
# The first two misses should make the next cue feel warmer without replacing
# the timing game.  The third miss still arms the separate RARE-or-better floor.
# These forecast lifts are deliberately modest and rarity-sensitive: purple
# (RARE) and rainbow (EPIC/LEGENDARY) weights rise faster than common fish.
const PITY_FORECAST_BONUS_STEP := 0.06
const PITY_LOW_GRADE_BONUS_STEP := 0.02
const RESCUE_RARE_WEIGHT_SCALE := 1.8
const RESCUE_EPIC_WEIGHT_SCALE := 2.6
const RESCUE_LEGENDARY_WEIGHT_SCALE := 2.9
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
# Dopamine FX (see EFFECTS_DESIGN.md). The director owns the heat ladder and
# timing; main only reports events. It exists before _ready so direct calls
# from tests and old saves can never hit a null effect target.
var fx: RefCounted = FxDirectorScript.new()
var fx_back = FxCanvasScript.new()
var fx_front = FxCanvasScript.new()
var post_fx := ColorRect.new()
var se_players: Array[AudioStreamPlayer] = []
var fx_heat := 0
var fx_bite_heat := 0
var fx_school := false
var fx_premium := false
var fx_school_done := false
var fx_premium_done := false
var fx_last_stage := 0
var fx_last_pull_shown := false
# Reveal "summon light": the card glow starts at the heat the player was shown
# and climbs (or fizzles) to the real result. -1 means no cue was seen (old
# saves, direct calls), so the glow simply starts at the result.
var reveal_glow_start := -1
var fever_announce_pending := false

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
	map_art["beach"] = load("res://assets/maps/amber_beach.png")
	map_art["rocky"] = load("res://assets/maps/rocky_shore.png")
	map_art["grotto"] = load("res://assets/maps/moonlit_grotto.png")
	hero = load("res://assets/hero.png")
	for asset in ["cottage", "inn", "shop", "tree0", "tree1", "tree2", "barrel", "sign", "rock", "well", "reeds"]:
		textures[asset] = load("res://assets/" + asset + ".png")
	_load_fish_art()
	_build_world()
	cam.position = player.round() + _map_camera_bias()
	cam.position_smoothing_enabled = false
	cam.limit_left = 0; cam.limit_top = 0
	cam.limit_right = int(WORLD_SIZE.x); cam.limit_bottom = int(WORLD_SIZE.y)
	add_child(cam)
	# Screen-space layers: FX back (darkening, letterbox, speed lines) sits
	# between the world and the HUD; FX front (cut-ins, particles, flash) and the
	# post-process pass sit above it.
	var back_layer := CanvasLayer.new(); back_layer.layer = 1
	add_child(back_layer); back_layer.add_child(fx_back)
	fx_back.director = fx; fx_back.layer_kind = "back"
	var layer := CanvasLayer.new(); layer.layer = 2
	add_child(layer); layer.add_child(hud); hud.draw.connect(_draw_hud)
	var front_layer := CanvasLayer.new(); front_layer.layer = 3
	add_child(front_layer); front_layer.add_child(fx_front)
	fx_front.director = fx; fx_front.layer_kind = "front"
	var post_layer := CanvasLayer.new(); post_layer.layer = 4
	add_child(post_layer)
	var post_material := ShaderMaterial.new()
	post_material.shader = PostFxShader
	post_fx.material = post_material
	post_fx.size = Vector2(480, 270)
	post_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_fx.visible = false
	post_layer.add_child(post_fx)
	# Keep the arcade feedback self-contained: the short SE are synthesized in
	# memory, so the game has no external audio-file dependency.
	# A small pool lets an impact, a cut-in whoosh and a heartbeat overlap
	# instead of queueing one after another on a single generator.
	for i in range(4):
		var player_node := se_player if i == 0 else AudioStreamPlayer.new()
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = SE_RATE
		generator.buffer_length = 1.0
		player_node.stream = generator
		player_node.volume_db = -8.0
		add_child(player_node)
		player_node.play()
		se_players.append(player_node)
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

func _fish_art_stem(species_name: String) -> String:
	# Keep the asset contract independent from the display name's spaces and
	# punctuation. Existing files use lowercase snake_case stems.
	return species_name.to_lower().strip_edges().replace(" ", "_")

func _load_fish_art() -> void:
	fish_portraits.clear()
	fish_cards.clear()
	for fish in FISH_SPECIES:
		var species_name := str(fish.get("name", ""))
		if species_name.is_empty(): continue
		var stem := str(fish.get("art", _fish_art_stem(species_name)))
		var portrait_path := "res://assets/fish/" + stem + ".png"
		if ResourceLoader.exists(portrait_path):
			var portrait := load(portrait_path) as Texture2D
			if portrait != null: fish_portraits[species_name] = portrait
		# The transparent v2 illustrations are the encyclopedia art. Keep the
		# older framed card as a compatibility fallback for species without a v2
		# asset, so a partial art bundle never removes a ledger entry.
		var card_paths := [
			"res://assets/fish_cards/" + stem + "_v2.png",
			"res://assets/fish_cards/" + stem + ".png"
		]
		for card_path in card_paths:
			if not ResourceLoader.exists(card_path): continue
			var card := load(card_path) as Texture2D
			if card != null:
				fish_cards[species_name] = card
				break

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
	# The grotto shares Rocky Shore's ordinary fish and rarity balance. Its
	# hidden pool adds Aurora koi rather than replacing the entire catch table.
	if map == "grotto" and fish.maps.has("rocky"): map_ok = true
	if fish.maps.has("hidden"):
		# Forecasts for an explicit grotto map should use that map's rules even
		# while the player is elsewhere; Rocky still requires its legacy pool.
		if map == "grotto": map_ok = true
		elif map == "rocky": map_ok = _at_hidden_fishing_spot()
		else: map_ok = false
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
	elif map_name == "grotto":
		_build_grotto()
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
	# The notice is not the only way to discover the grotto.  Fisher Mera hangs
	# around the plaza and shares the same rumor, so exploration and NPC talk
	# both feed the Issue #1 hidden-tide loop.
	landmarks.append({"kind":"rumor_npc","pos":RUMOR_SOURCES.mera.pos,"label":RUMOR_SOURCES.mera.label})
	landmarks.append({"kind":"rumor_sign","pos":RUMOR_SOURCES.notice.pos,"label":"Notice"})
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
		{"kind":"pool","pos":Vector2(205,157),"label":"North Tide Pool"},
		{"kind":"pool","pos":Vector2(725,370),"label":"South Tide Pool"}
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
		{"kind":"pool","pos":Vector2(497,151),"label":"Blackglass Pool"},
		{"kind":"pool","pos":Vector2(614,375),"label":"Gull's Pool"},
		{"kind":"lighthouse","pos":Vector2(704,154),"label":"Farwatch Lighthouse"},
		{"kind":"hidden_pool","pos":Vector2(690,480),"label":"Moonlit Grotto"}
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

func _build_grotto():
	# Moonlit Grotto is a hidden cove reached from Rocky Shore after the guide
	# gate. Its static art supplies the cliffs and waterfalls; this landmark keeps
	# the gameplay fishing spot explicit for saves and the tide ledger.
	landmarks = [{"kind":"grotto_pool","pos":Vector2(512,520),"label":"Moonlit Grotto"}]
	# Keep the cavern's central lake out of the walkable path while leaving a
	# generous ring around it for exploration and the lower fishing edge. Two
	# stepped rectangles follow the broad lagoon without introducing a new
	# collision shape dependency.
	solids.append(Rect2(280,230,460,165))
	solids.append(Rect2(345,395,330,88))

func _add_prop(kind: String, pos: Vector2, body: Rect2):
	props.append({"kind":kind,"pos":pos})
	# Static authored map art already contains visible landmarks; legacy prop
	# colliders would otherwise become invisible walls at old coordinates.
	if body.size != Vector2.ZERO and not _using_static_map_art():
		solids.append(Rect2(pos+body.position,body.size))

func _shore(x: float) -> float:
	if current_map == "beach": return 500.0
	# Rocky Shore artwork places the authored lower bank around y=500. Keep
	# movement and casts on that bank instead of allowing the hero into the
	# visibly deep water below it.
	if current_map == "rocky": return 500.0
	if current_map == "grotto": return 620.0
	if x < 240: return 464
	if x < 416: return 480
	if x < 608: return 464
	if x < 752: return 448
	return 432

func _walkable(pos: Vector2) -> bool:
	# Feet collision: canopy overlap is intentional for top-down depth.
	var feet := Rect2(pos-Vector2(4,3),Vector2(8,5))
	for c in [feet.position,feet.position+Vector2(8,0),feet.end,feet.position+Vector2(0,5)]:
		# The pier only exists in town; other maps end at their shoreline.
		var on_pier: bool = current_map == "town" and c.x >= 486 and c.x <= 518 and c.y >= 440 and c.y <= 545
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
	# Hit-stop and slow motion scale only the fishing simulation; the clock,
	# particles and camera keep real time so a freeze frame still feels alive.
	# The tide ledger pauses the whole cue show together with the fishing
	# simulation (see _sync_fx_outputs), so a banner, heartbeat or burst cannot
	# play out behind it and the cue is still there when the ledger closes.
	if not notebook_open: fx.update(delta)
	var game_delta: float = delta * float(fx.time_scale())
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
	if notebook_open:
		if Input.is_action_just_pressed("move_right"): page_rumor(1)
		elif Input.is_action_just_pressed("move_left"): page_rumor(-1)
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
			if rumor_source_near() != "": talk_to_rumor_source()
			else: _try_fish()
		_process_fishing(game_delta)
	if Input.is_action_just_pressed("save_game"): _save_game()
	if InputMap.has_action("fx_toggle") and Input.is_action_just_pressed("fx_toggle"): toggle_reduced_flash()
	toast_t = maxf(0.0, toast_t-delta)
	cam.position = player.round() + _map_camera_bias()
	var base_offset := Vector2.ZERO
	if shake_t > 0.0:
		var shake_power := 8.0 if last_rarity == "LEGENDARY" else (4.0 if last_rarity == "RARE" else 2.0)
		if fx.reduced: shake_power *= 0.4
		base_offset = Vector2(sin(elapsed*80.0), cos(elapsed*71.0)) * shake_power * minf(1.0, shake_t*8.0)
	if notebook_open:
		# The paused show must not leave the world shaking or zoomed.
		cam.offset = Vector2.ZERO
		cam.zoom = Vector2.ONE
	else:
		cam.offset = base_offset + fx.shake_offset()
		cam.zoom = Vector2.ONE * MAP_PRESENTATION_ZOOM * float(fx.zoom_factor())
	_sync_fx_outputs()
	queue_redraw(); hud.queue_redraw()

func _sync_fx_outputs() -> void:
	# While the tide ledger is open the show is paused: its layers are hidden so
	# a frozen cut-in, letterbox or chromatic pass never sits over the ledger,
	# and the music returns to normal until the cue resumes on close.
	var show_visible := not notebook_open
	fx_back.visible = show_visible
	fx_front.visible = show_visible
	if not show_visible:
		post_fx.visible = false
		_music_call("set_duck", [1.0])
		return
	# Sounds, music ducking, the FEVER frame and the post pass all read from
	# the director once per frame, so effect code never touches audio nodes.
	fx.set_fever(fever_active and not _fever_waiting())
	for kind in fx.pop_sounds(): _play_se(kind)
	_music_call("set_duck", [fx.music_duck])
	var amount: float = fx.chroma()
	post_fx.visible = amount > 0.001
	if post_fx.visible and post_fx.material is ShaderMaterial:
		(post_fx.material as ShaderMaterial).set_shader_parameter("amount", amount)
	fx_back.queue_redraw(); fx_front.queue_redraw()

func toggle_reduced_flash() -> void:
	fx.reduced = not fx.reduced
	toast = "FLASH  REDUCED  (F to restore)" if fx.reduced else "FLASH  NORMAL  (F to reduce)"
	toast_t = 2.0

# Screen position (480x270 HUD space) of the float, for splashes and pops.
func _float_screen_pos() -> Vector2:
	var world := player.round() + Vector2(15, 32)
	if not is_inside_tree(): return Vector2(240, 160)
	return get_viewport().get_canvas_transform() * world

# Every map connection lives in this one table: the trigger zone the hero walks
# into, the spawn in the destination map, and the signpost drawn for it. A zone
# must stay clear of fishing spots and of the spawns that arrive on its map, so
# travel never swallows a fishing bank or bounces straight back (see the exit
# checks in tests/smoke.gd).
const MAP_EXITS := {
	"town": [
		# The south road runs straight onto Old Salt Pier, so the beach gate sits
		# on the sand just east of it rather than across the road.
		{"to":"beach","zone":Rect2(528,448,56,32),"spawn":Vector2(400,80),"marker":Vector2(556,440),"label":"BEACH","dir":Vector2(0,1)},
		{"to":"rocky","zone":Rect2(798,250,62,180),"spawn":Vector2(90,340),"marker":Vector2(800,338),"label":"ROCKY SHORE","dir":Vector2(1,0)}
	],
	"beach": [
		{"to":"town","zone":Rect2(280,0,280,34),"spawn":Vector2(556,430),"marker":Vector2(420,40),"label":"TOWN","dir":Vector2(0,-1)},
		{"to":"rocky","zone":Rect2(798,280,62,280),"spawn":Vector2(420,440),"marker":Vector2(800,390),"label":"ROCKY SHORE","dir":Vector2(1,0)}
	],
	"rocky": [
		# Keep the legacy pool at (690,480) fishable; the grotto gate is farther
		# east on the same bank so merely approaching the pool cannot transition.
		{"to":"grotto","zone":Rect2(760,450,100,50),"spawn":Vector2(510,150),"marker":Vector2(780,460),"label":"MOONLIT GROTTO","dir":Vector2(1,0),"needs_grotto":true},
		{"to":"town","zone":Rect2(0,250,34,180),"spawn":Vector2(760,340),"marker":Vector2(40,340),"label":"TOWN","dir":Vector2(-1,0)},
		# A narrow gate at the water's edge: the rest of the lower bank stays
		# walkable and fishable.
		{"to":"beach","zone":Rect2(390,470,60,40),"spawn":Vector2(770,390),"marker":Vector2(420,458),"label":"BEACH","dir":Vector2(0,1)}
	],
	"grotto": [
		# The grotto's return route is the west edge, matching the authored map
		# workflow and keeping the cave entry above the lagoon as a one-way route.
		{"to":"rocky","zone":Rect2(0,250,34,180),"spawn":Vector2(90,340),"marker":Vector2(40,340),"label":"ROCKY SHORE","dir":Vector2(-1,0)}
	]
}

func _map_exits(map_name: String = "") -> Array[Dictionary]:
	var exits: Array[Dictionary] = []
	for entry in MAP_EXITS.get(current_map if map_name.is_empty() else map_name, []):
		if bool(entry.get("needs_grotto", false)) and not hidden_spot_unlocked: continue
		exits.append(entry)
	return exits

func _check_map_exit():
	if transition_active: return
	for entry in _map_exits():
		if (entry.zone as Rect2).has_point(player):
			_transition_to(str(entry.to), entry.spawn)
			return

func _entry_spawn(map_name: String) -> Vector2:
	for entry in _map_exits():
		if str(entry.to) == map_name: return entry.spawn
	return Vector2(400,80)

func _map_camera_bias() -> Vector2:
	# Shoreline entrances are intentionally at the north/west edge so route
	# transitions remain readable. Bias the camera a little into each map so the
	# first frame includes its signature pool/breakwater instead of an empty
	# approach strip, while the player stays comfortably on-screen.
	match current_map:
		"beach": return Vector2(0,110)
		"rocky": return Vector2(200,70)
		"grotto": return Vector2.ZERO
		_ : return Vector2.ZERO

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
	if current_map == "grotto": return false
	return (player.y >= _shore(player.x)-21 and player.x>70 and player.x<810)

func _fishing_spots() -> Array[Dictionary]:
	match current_map:
		"town": return [{"pos":Vector2(502,530),"label":"Old Salt Pier"}]
		"beach": return [
			{"pos":Vector2(205,157),"label":"North Tide Pool"},
			{"pos":Vector2(725,370),"label":"South Tide Pool"}
		]
		"rocky":
			var spots: Array[Dictionary] = [{"pos":Vector2(497,151),"label":"Blackglass Pool"},{"pos":Vector2(614,375),"label":"Gull's Pool"}]
			if hidden_spot_unlocked: spots.append({"pos":Vector2(690,480),"label":"Moonlit Grotto"})
			return spots
		"grotto": return [{"pos":Vector2(512,520),"label":"Moonlit Grotto"}]
		_: return []

# --- Rumors and the collection gate -------------------------------------------
# Fisher Mera and the weathered notice each know a few tide rumors.  Talking to
# one (SPACE nearby) reveals the next rumor it has not told you yet.  A species
# rumor is generated from the same condition table that drives the species pool,
# so it can never disagree with what the water actually does.
const HIDDEN_SPOT_COLLECTION_PERCENT := 25
const RUMOR_TALK_RADIUS := 34.0
const TIME_NAMES := ["dawn", "day", "dusk", "night"]
const RUMOR_SOURCES := {
	"mera": {"label":"Fisher Mera", "pos":Vector2(424,381), "rumors":["grotto", "Moonfin trout", "Lantern squid", "Night sailfish", "Storm sardine"]},
	"notice": {"label":"Weathered notice", "pos":Vector2(468,381), "rumors":["grotto", "Lighthouse ray", "Pearl puffer", "Sea lavender perch", "Copper mackerel"]}
}

func collection_discovered_count() -> int:
	var found := 0
	for fish in FISH_SPECIES:
		if species_discovered(str(fish.get("name", ""))): found += 1
	return found

func collection_percent() -> float:
	return 100.0 * float(collection_discovered_count()) / float(maxi(1, FISH_SPECIES.size()))

func _condition_phrase(values: Array, all_values: Array) -> String:
	if values.size() >= all_values.size(): return "any"
	if values.size() == all_values.size() - 1:
		for value in all_values:
			if not values.has(value): return "not " + str(value)
	var ordered: Array = []
	for value in all_values:
		if values.has(value): ordered.append(str(value))
	return " or ".join(ordered)

func fish_condition_hint(species: String) -> String:
	var conditions := _fish_conditions(species)
	return "%s: %s / %s / %s" % [species, _condition_phrase(conditions.times, TIME_NAMES), _condition_phrase(conditions.weather, WEATHER_NAMES), _condition_phrase(conditions.seasons, SEASON_NAMES)]

func rumor_text(rumor_id: String) -> String:
	if rumor_id == "grotto":
		return "A moonlit grotto opens on the rocky shore once the guide is %d%% full." % HIDDEN_SPOT_COLLECTION_PERCENT
	return fish_condition_hint(rumor_id)

func rumor_heard(rumor_id: String) -> bool:
	return heard_rumors.has(rumor_id)

func _all_rumor_ids() -> Array:
	var ids: Array = []
	for key in RUMOR_SOURCES:
		for id in RUMOR_SOURCES[key].rumors:
			if not ids.has(id): ids.append(id)
	return ids

func rumor_source_near() -> String:
	if current_map != "town": return ""
	var best := ""
	var best_distance := RUMOR_TALK_RADIUS
	for key in RUMOR_SOURCES:
		var distance := player.distance_to(RUMOR_SOURCES[key].pos)
		if distance < best_distance:
			best = str(key); best_distance = distance
	return best

func _next_unheard_rumor(source: String) -> String:
	if not RUMOR_SOURCES.has(source): return ""
	for id in RUMOR_SOURCES[source].rumors:
		if not heard_rumors.has(id): return str(id)
	return ""

func talk_to_rumor_source(source: String = "") -> bool:
	var key := source if source != "" else rumor_source_near()
	if key == "" or not RUMOR_SOURCES.has(key): return false
	var label := str(RUMOR_SOURCES[key].label)
	var id := _next_unheard_rumor(key)
	if id == "":
		toast = "%s has nothing new  /  N reviews the rumors you have heard" % label
		toast_t = 2.8
		return true
	_hear_rumor(id)
	toast = "%s: %s" % [label, rumor_text(id)]
	toast_t = 4.5
	return true

func _hear_rumor(rumor_id: String) -> void:
	if not heard_rumors.has(rumor_id): heard_rumors.append(rumor_id)
	if rumor_id == "grotto": rumor_found = true
	rumor_page = heard_rumors.size() - 1

func page_rumor(step: int) -> void:
	if heard_rumors.is_empty(): return
	rumor_page = posmod(rumor_page + step, heard_rumors.size())

# A species is "known" once it is in the ledger or a rumor has described it.
# Only known species get the "biting now" dot, so rumors are what turn the tide
# forecast into something readable.
func species_known(species: String) -> bool:
	return species_discovered(species) or heard_rumors.has(species)

func species_biting_now(species: String) -> bool:
	return species_known(species) and fish_available(species)

func _update_rumor_gate() -> void:
	if rumor_found and not hidden_spot_unlocked and collection_percent() >= float(HIDDEN_SPOT_COLLECTION_PERCENT):
		hidden_spot_unlocked = true
		toast = "The guide is %d%% full: a hidden grotto is marked on the rocky shore" % HIDDEN_SPOT_COLLECTION_PERCENT; toast_t = 3.5
	if hidden_spot_unlocked and current_map == "rocky" and player.distance_to(Vector2(690,480)) < 28.0:
		hidden_spot_collected = true
	if current_map == "grotto" and hidden_spot_unlocked:
		hidden_spot_collected = true

func _at_hidden_fishing_spot() -> bool:
	# Aurora koi is tied to the grotto pool itself.  Visiting the grotto unlocks
	# the pool for the run, but standing at another rocky shoreline must not
	# silently include hidden fish in its species roll.
	if not hidden_spot_unlocked or not hidden_spot_collected: return false
	if current_map == "grotto": return player.distance_to(Vector2(512,520)) <= 28.0
	return current_map == "rocky" and player.distance_to(Vector2(690,480)) <= 24.0

func _species_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for fish in FISH_SPECIES:
		var species := str(fish.get("name", ""))
		if fish_available(species): pool.append(fish)
	return pool

func _weighted_species_pick(pool: Array[Dictionary], bonus: float = -1.0) -> Dictionary:
	# Keep species selection rarity-weighted in every path, including the
	# one-shot rescue floor. A uniform rare_pool roll would make each rare and
	# epic species equally likely and quietly flatten the rarity curve.
	if pool.is_empty(): return {}
	var effective_bonus := _rarity_bonus_total() if bonus < 0.0 else bonus
	var total := 0.0
	var weights: Array[float] = []
	for fish in pool:
		var weight := _species_weight(str(fish.get("rarity", "COMMON")), effective_bonus)
		weights.append(weight)
		total += weight
	if total <= 0.0: return pool[0]
	var roll := rng.randf() * total
	for i in range(pool.size()):
		roll -= weights[i]
		if roll <= 0.0: return pool[i]
	return pool[pool.size() - 1]

func _pick_species(grade: String, apply_rescue := false, exclude_legendary := false) -> Dictionary:
	if apply_rescue: rescue_selection_used = false
	var pool := _species_pool()
	if pool.is_empty(): return FISH_SPECIES[0]
	var eligible: Array[Dictionary] = []
	for fish in pool:
		if exclude_legendary and str(fish.get("rarity", "COMMON")) == "LEGENDARY": continue
		if grade == "PERFECT" or fish.rarity in ["COMMON","UNCOMMON","RARE"]: eligible.append(fish)
	if eligible.is_empty(): eligible = pool
	# Rescue is intentionally a soft odds nudge before the one-shot RARE floor.
	# It makes an unlucky forecast feel warmer without handing out a catch or
	# changing the map/time/weather legality of the pool.
	var bonus := _rarity_bonus_total()
	var picked := _weighted_species_pick(eligible, bonus)
	if not picked.is_empty():
		return _apply_rescue_floor(picked, eligible, grade) if apply_rescue else picked
	var fallback: Dictionary = eligible[eligible.size() - 1]
	return _apply_rescue_floor(fallback, eligible, grade) if apply_rescue else fallback

func _rarity_bonus_total() -> float:
	return float(BAITS[bait_index].rarity_bonus) + (FEVER_RARITY_BONUS if fever_active else 0.0) + rescue_forecast_bonus()

func _species_weight(rarity: String, bonus: float) -> float:
	var weight := 100.0
	match rarity:
		"UNCOMMON": weight = 40.0
		"RARE": weight = 12.0
		"EPIC": weight = 3.0
		"LEGENDARY": weight = 0.5
	# Bait, FEVER, and the early rescue forecast are intentionally
	# rarity-sensitive. Common fish keep their baseline weight, while the
	# bonus increasingly favours a real upgrade instead of inflating every
	# rarity by the same amount. The rescue-specific scales make one or two
	# misses visible in the forecast without making high rarity dominant.
	var rescue_scale := 0.0
	match rarity:
		"RARE": rescue_scale = RESCUE_RARE_WEIGHT_SCALE
		"EPIC": rescue_scale = RESCUE_EPIC_WEIGHT_SCALE
		"LEGENDARY": rescue_scale = RESCUE_LEGENDARY_WEIGHT_SCALE
	var rescue_bonus := rescue_forecast_bonus()
	var tackle_bonus := maxf(0.0, bonus - rescue_bonus)
	return weight * (1.0 + tackle_bonus * _rarity_bonus_scale(rarity) + rescue_bonus * (_rarity_bonus_scale(rarity) + rescue_scale))

# Probability that the next cast's candidate has at least this rarity rank, from
# the same weights _pick_species uses plus the explicit legendary roll.  The
# promotion cue uses it to size its lies: the pool now changes with the tide, so
# a fixed lie rate would swamp a rainbow float in a pool with one EPIC species.
func _candidate_share_at_least(min_rank: int) -> float:
	var pool := _species_pool()
	var eligible: Array[Dictionary] = []
	var has_legendary := false
	for fish in pool:
		if str(fish.get("rarity", "COMMON")) == "LEGENDARY": has_legendary = true
		else: eligible.append(fish)
	if eligible.is_empty(): eligible = pool
	var bonus := _rarity_bonus_total()
	var total := 0.0
	var matched := 0.0
	for fish in eligible:
		var weight := _species_weight(str(fish.get("rarity", "COMMON")), bonus)
		total += weight
		if _rarity_rank(str(fish.get("rarity", "COMMON"))) >= min_rank: matched += weight
	var share := matched / total if total > 0.0 else 0.0
	if has_legendary and min_rank <= _rarity_rank("LEGENDARY"):
		var legendary_chance := _legendary_chance_for_cast()
		share = share * (1.0 - legendary_chance) + legendary_chance
	return share

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
	if current_map not in ["rocky", "grotto"] or combo + 1 < FEVER_THRESHOLD: return 0.0
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

func _candidate_for_grade(candidate: Dictionary, grade: String, premium_locked := false) -> Dictionary:
	var resolved := candidate.duplicate(true)
	# The cast roll is intentionally a PERFECT-pool candidate.  A GOOD timing
	# result downgrades an EPIC/LEGENDARY candidate to the deterministic RARE
	# substitute selected at cast time, so a Legendary species never enters the
	# ledger from a low-grade battle. The premium golden-tide cue is an explicit
	# exception: it promises an EPIC-or-better result, so GOOD timing cannot
	# contradict that promise.
	if grade == "GOOD" and not premium_locked and _rarity_rank(str(resolved.get("rarity", "COMMON"))) > _rarity_rank("RARE"):
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
	# The floor changes the minimum rarity only; within that floor preserve the
	# same weighted species curve as a natural roll.
	return _weighted_species_pick(rare_pool)

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
	return {"meter": pity_meter, "threshold": PITY_THRESHOLD, "ready": rescue_ready, "low_grade_streak": low_grade_streak, "forecast_bonus": rescue_forecast_bonus()}

func rescue_forecast_bonus() -> float:
	"""Return the visible rarity-odds nudge earned by misses/low-grade catches.

	This is deliberately separate from the RARE rescue floor.  A player gets a
	small, deterministic forecast improvement after the first unlucky outcome,
	then a larger promotion cue as the meter fills, while the timing battle is
	still required for every catch.
	"""
	return clampf(float(pity_meter) * PITY_FORECAST_BONUS_STEP + float(low_grade_streak) * PITY_LOW_GRADE_BONUS_STEP, 0.0, 0.18)

func rescue_forecast_label() -> String:
	var percent := int(round(rescue_forecast_bonus() * 100.0))
	if rescue_ready:
		return "RESCUE READY  /  RARE floor  /  PURPLE+ cue +%d%%" % percent
	if percent > 0:
		return "RESCUE %d/%d  /  PURPLE+ cue +%d%%" % [pity_meter, PITY_THRESHOLD, percent]
	return "RESCUE 0/%d" % PITY_THRESHOLD

func _pity_label() -> String:
	var percent := int(round(rescue_forecast_bonus() * 100.0))
	if rescue_ready: return "READY  PURPLE+%d%%" % percent
	if percent > 0: return "RESCUE %d/%d  PURPLE+%d%%" % [pity_meter, PITY_THRESHOLD, percent]
	return "RESCUE 0/%d" % PITY_THRESHOLD

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

func _record_is_better(metadata: Dictionary, record: Dictionary) -> bool:
	var specimen_size := float(metadata.get("size_cm", 0.0))
	var specimen_weight := float(metadata.get("weight_kg", 0.0))
	var record_size := float(record.get("size_cm", 0.0))
	var record_weight := float(record.get("weight_kg", 0.0))
	return specimen_size > record_size + 0.0001 or (is_equal_approx(specimen_size, record_size) and specimen_weight > record_weight + 0.0001)

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
	# Size is the primary king-of-species measure.  Weight breaks a rounded
	# size tie, so a heavier specimen can still take the crown without allowing
	# a smaller fish to replace a larger one.
	var specimen_size := float(metadata.get("size_cm", 0.0))
	var specimen_weight := float(metadata.get("weight_kg", 0.0))
	var is_crown := _record_is_better(metadata, record)
	if is_crown:
		# A crown candidate.  The ledger record itself is written only when the
		# player registers the specimen (_commit_crown_record), so selling the
		# biggest fish gives up the crown.
		record = {"species":fish_name,"size_cm":specimen_size,"weight_kg":specimen_weight,"day":day,"map":current_map,"spot":str(metadata.get("spot", "Open water")),"variant":str(metadata.get("variant", "Standard")),"grade":grade}
	metadata["crown"] = is_crown
	metadata["record_size_cm"] = float(record.get("size_cm", metadata.get("size_cm", 0.0)))
	metadata["record_weight_kg"] = float(record.get("weight_kg", metadata.get("weight_kg", 0.0)))
	metadata["record_day"] = int(record.get("day", day))
	metadata["record_map"] = str(record.get("map", current_map))
	metadata["record_spot"] = str(record.get("spot", metadata.get("spot", "Open water")))
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

const SELL_VALUES := {"COMMON":2, "UNCOMMON":3, "RARE":5, "EPIC":8, "LEGENDARY":14}
# Selling always keeps the species discovered, but only a REGISTERED specimen is
# written into the ledger as the crown.  Registering also pays a base reward plus
# a bonus for a first capture and for a new crown, so keeping the trophy competes
# with cashing it out instead of being a strictly worse +1 shell.
const REGISTER_BASE_REWARD := 1
const REGISTER_FIRST_BONUS := {"COMMON":2, "UNCOMMON":4, "RARE":6, "EPIC":8, "LEGENDARY":10}
const REGISTER_CROWN_BONUS := 2

func catch_choice_pending() -> bool:
	return pending_catch_state == "pending" and not pending_catch.is_empty()

# The reveal card, the toast bar and the SELL/REGISTER prompt all carry
# rarity-correlated information (names, values).  They wait for the flip.
func catch_reveal_complete() -> bool:
	if fishing_state != FishingState.RESULT or last_grade == "MISS" or last_rarity == "": return true
	if last_rarity == "LEGENDARY": return legendary_t >= 2.05
	return reveal_stage >= 4

func _flush_result_toast() -> void:
	if result_toast_pending == "": return
	# A decision may be made from a saved/revealed result before the next draw
	# tick. Do not resurrect a stale reveal toast after that fish is already SOLD
	# or REGISTERED; the decision handler owns the visible confirmation.
	if not catch_choice_pending():
		result_toast_pending = ""
		return
	if fishing_state != FishingState.RESULT or not catch_reveal_complete(): return
	toast = result_toast_pending
	toast_t = 4.0
	result_toast_pending = ""

func pending_catch_species() -> String:
	return str(pending_catch.get("species", last_catch)) if catch_choice_pending() else ""

func pending_catch_sell_value() -> int:
	if not catch_choice_pending(): return 0
	var stored := int(pending_catch.get("sell_value", 0))
	if stored > 0: return stored
	return _catch_sell_value(pending_catch.get("metadata", {}) as Dictionary)

func pending_catch_register_value() -> int:
	if not catch_choice_pending(): return 0
	return _register_value(pending_catch.get("metadata", {}) as Dictionary)

func _register_value(metadata: Dictionary) -> int:
	var value := REGISTER_BASE_REWARD
	if bool(metadata.get("first_capture", false)):
		value += int(REGISTER_FIRST_BONUS.get(str(metadata.get("rarity", "COMMON")), REGISTER_FIRST_BONUS["COMMON"]))
	if bool(metadata.get("crown", false)): value += REGISTER_CROWN_BONUS
	return value

func _catch_sell_value(metadata: Dictionary) -> int:
	var rarity := str(metadata.get("rarity", "COMMON"))
	var value := int(SELL_VALUES.get(rarity, SELL_VALUES["COMMON"]))
	# A larger catch is worth a modest premium, while cosmetic variants stay
	# cosmetic.  This is deterministic for a saved specimen and cannot be rerolled.
	value += clampi(int(floor(float(metadata.get("size_cm", 0.0)) / 40.0)), 0, 4)
	if str(metadata.get("variant", "Standard")) == "Gilded": value += 1
	return maxi(1, value)

func _open_catch_choice(metadata: Dictionary) -> void:
	pending_catch = {
		"species":last_catch,
		"metadata":metadata.duplicate(true),
		"sell_value":_catch_sell_value(metadata),
		"ledger_counted":true,
		"decision":"pending"
	}
	pending_catch_state = "pending"
	last_catch_decision = ""

# Writes the specimen into best_records.  Called only when the player registers
# it, so selling a record fish gives up the crown.
func _commit_crown_record(species: String, metadata: Dictionary) -> bool:
	if not bool(metadata.get("crown", false)): return false
	var record: Dictionary = best_records.get(species, {})
	if not _record_is_better(metadata, record): return false
	best_records[species] = {"species":species,"size_cm":float(metadata.get("size_cm", 0.0)),"weight_kg":float(metadata.get("weight_kg", 0.0)),"day":int(metadata.get("day", day)),"map":str(metadata.get("map", current_map)),"spot":str(metadata.get("spot", "Open water")),"variant":str(metadata.get("variant", "Standard")),"grade":str(metadata.get("grade", "GOOD"))}
	return true

# FEVER is presented as one moment: the banner, flash, chime, music change and
# rainbow frame all start when the catch that earned it is settled, and its
# clock starts then too. While the choice is open, FEVER is "waiting".
func _fever_waiting() -> bool:
	return fever_announce_pending and catch_choice_pending()

func _announce_fever_if_pending() -> void:
	if fever_announce_pending and fever_active:
		fever_announce_pending = false
		fx.fever_start()
		fever_flash_t = 1.0
		_music_call("set_fever", [true])
		_play_se("fever")
	fever_announce_pending = false

func register_pending_catch() -> bool:
	if not catch_choice_pending(): return false
	_announce_fever_if_pending()
	var species := pending_catch_species()
	var metadata := pending_catch.get("metadata", {}) as Dictionary
	# The reward is granted only when the player explicitly registers/keeps the
	# fish, so a pending result cannot be duplicated by repeated SPACE presses or
	# by saving mid-choice.
	var reward := _register_value(metadata)
	var new_crown := _commit_crown_record(species, metadata)
	result_toast_pending = ""
	shells += reward
	pending_catch["decision"] = "registered"
	pending_catch["register_value"] = reward
	pending_catch_state = "registered"
	last_catch_decision = "registered"
	toast = "REGISTERED  %s / +%d shells%s" % [species, reward, "  /  CROWN recorded" if new_crown else ""]
	toast_t = 2.4
	return true

func sell_pending_catch() -> bool:
	if not catch_choice_pending(): return false
	_announce_fever_if_pending()
	var species := pending_catch_species()
	var held := int(catches.get(species, 0))
	# The catch was counted at landing.  Never decrement another specimen if a
	# hand-edited or partially migrated save has no matching inventory entry.
	if held > 0:
		held -= 1
		if held == 0: catches.erase(species)
		else: catches[species] = held
	var value := pending_catch_sell_value()
	var gave_up_crown := bool((pending_catch.get("metadata", {}) as Dictionary).get("crown", false))
	result_toast_pending = ""
	shells += value
	pending_catch["decision"] = "sold"
	pending_catch["sell_value"] = value
	pending_catch_state = "sold"
	last_catch_decision = "sold"
	toast = "SOLD  %s / +%d shells  (discovery kept%s)" % [species, value, ", crown not recorded" if gave_up_crown else ""]
	toast_t = 2.4
	return true

func _catch_choice_prompt() -> String:
	if catch_choice_pending():
		var metadata := pending_catch.get("metadata", {}) as Dictionary
		var tag := ""
		if bool(metadata.get("first_capture", false)): tag += "  NEW"
		if bool(metadata.get("crown", false)): tag += "  CROWN"
		return "X SELL +%d   C REGISTER +%d%s" % [pending_catch_sell_value(), pending_catch_register_value(), tag]
	if last_catch_decision == "sold": return "SOLD  /  discovery kept   SPACE continue"
	if last_catch_decision == "registered": return "REGISTERED / KEPT   SPACE continue"
	return "SPACE  continue"

func species_discovered(species: String, owned: int = -1) -> bool:
	# Inventory is transient: selling the last copy must not erase the durable
	# field-guide discovery stored in catch metadata or the latest record.
	var count := int(catches.get(species, 0)) if owned < 0 else owned
	return count > 0 or catch_metadata.has(species) or first_capture_metadata.has(species) or catch_latest.has(species)

func _fish_art_visible(species: String, owned: int = -1) -> bool:
	# Legendary identity stays masked until the first durable discovery. Other
	# species can show their illustration even while their name remains hidden.
	var fish := _fish_entry(species)
	return not fish.is_empty() and (str(fish.get("rarity", "COMMON")) != "LEGENDARY" or species_discovered(species, owned))

func ledger_display_name(species: String, owned: int = -1) -> String:
	# Keep the highest-rarity cards mysterious until the first durable discovery.
	# Once caught, the name and records stay visible even if the final inventory
	# copy is sold, matching the rest of the field guide's collection UX.
	var fish := _fish_entry(species)
	var discovered := species_discovered(species, owned)
	if str(fish.get("rarity", "COMMON")) == "LEGENDARY" and not discovered: return "???"
	var display_name := species if discovered or heard_rumors.has(species) else "????????"
	var marker := _ledger_marker(species, owned)
	if marker != "": display_name += " " + marker
	return display_name

func _ledger_marker(species: String, owned: int) -> String:
	if not species_discovered(species, owned): return "?"
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
func bait_cost() -> int: return int(BAITS[bait_index].get("cost", 0))
func rod_cost() -> int: return int(RODS[rod_index].get("cost", 0))
func tackle_cost() -> int: return bait_cost() + rod_cost()
func can_afford_tackle() -> bool: return shells >= tackle_cost()
func tackle_summary() -> String:
	return "%s %d + %s %d = %d shells/cast" % [bait_name(), bait_cost(), rod_name(), rod_cost(), tackle_cost()]
func cycle_bait(step: int = 1) -> void:
	if fishing_state != FishingState.IDLE: return
	bait_index = posmod(bait_index + step, BAITS.size())
	toast = "%s selected (%d shells/cast, rarity +%d%%, %s)" % [bait_name(), bait_cost(), int(BAITS[bait_index].rarity_bonus * 100.0), str(BAITS[bait_index].get("risk", "steady"))]
	toast_t = 2.0
func cycle_rod(step: int = 1) -> void:
	if fishing_state != FishingState.IDLE: return
	rod_index = posmod(rod_index + step, RODS.size())
	toast = "%s selected (%d shells/cast, strain x%.2f, escape x%.2f, %s)" % [rod_name(), rod_cost(), float(RODS[rod_index].tension_mult), float(RODS[rod_index].escape_mult), str(RODS[rod_index].get("risk", "steady"))]
	toast_t = 2.0

func _try_fish():
	if notebook_open: return
	if fishing_state == FishingState.RESULT:
		_reset_fishing()
		return
	if fishing_state != FishingState.IDLE: return
	if _can_fish():
		var cast_cost := tackle_cost()
		if shells < cast_cost:
			toast = "Need %d shells for %s (you have %d)" % [cast_cost, tackle_summary(), shells]; toast_t = 2.5
			return
		shells -= cast_cost
		fishing_state = FishingState.ANTICIPATING
		promotion_t = 0.0
		promotion_stage = 0
		promotion_reversal = false
		promotion_false_cue = false
		promotion_false_cue_revealed = false
		promotion_reversal_armed = false
		promotion_result_label = ""
		promotion_rescue_bonus = rescue_forecast_bonus()
		cast_candidate = _pick_cast_candidate(true)
		cast_good_candidate = _pick_good_substitute(cast_candidate)
		promotion_target_rarity = str(cast_candidate.get("rarity", "COMMON"))
		promotion_cue_rank = _rarity_rank(promotion_target_rarity)
		# The cue is decided once, at cast time.  A high-rarity candidate can
		# occasionally look ordinary, and a common/uncommon candidate can flash a
		# misleading high promotion.  No new random roll occurs while the float is
		# moving, so the same cast always tells the same visual story.
		var cue_roll := rng.randf()
		var rainbow_share := _candidate_share_at_least(3)
		var purple_share := maxf(0.0, _candidate_share_at_least(2) - rainbow_share)
		var false_rainbow_chance := minf(PROMOTION_FALSE_RAINBOW_CHANCE, rainbow_share * PROMOTION_RAINBOW_LIE_RATIO)
		var false_purple_chance := minf(PROMOTION_FALSE_PURPLE_CHANCE, purple_share * PROMOTION_PURPLE_LIE_RATIO)
		if cue_roll < PROMOTION_FALSE_CUE_CHANCE and promotion_cue_rank >= 2:
			promotion_false_cue = true
			promotion_cue_rank = maxi(0, promotion_cue_rank - 2)
		elif cue_roll < false_rainbow_chance and promotion_cue_rank <= 1:
			promotion_false_cue = true
			promotion_cue_rank = 3
		elif cue_roll < false_rainbow_chance + false_purple_chance and promotion_cue_rank <= 1:
			promotion_false_cue = true
			promotion_cue_rank = 2
		promotion_reversal_armed = rng.randf() < PROMOTION_REVERSAL_CHANCE
		cast_timer = 1.8
		bite_delay = rng.randf_range(0.72, 1.42) * float(RODS[rod_index].get("bite_mult", 1.0))
		_plan_cast_fx()
		bite_timer = 0.0
		face = 0
		toast = "Line out... %s" % tackle_summary()
		toast_t = 2.0
		_music_call("start_fishing", [combo])
		_play_se("cast")
	else:
		toast = "Cast from the water's edge or the end of the pier"; toast_t = 3.0

func _promotion_stage_limit() -> int:
	if promotion_false_cue:
		return _promotion_max_stage(str(["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"][clampi(promotion_cue_rank, 0, 4)]))
	return _promotion_max_stage(promotion_target_rarity)

func _rarity_heat(rarity: String) -> int:
	# Results sit on the same blue/gold/purple/rainbow ladder as the float.
	return mini(3, _rarity_rank(rarity))

func _plan_cast_fx() -> void:
	# Optional cues are rolled on the FX director's own RNG, never the gameplay
	# RNG, so tuning a cut-in cannot change which fish bites or when.
	var actual_rank := _rarity_rank(promotion_target_rarity)
	fx_premium = fx.roll_premium(actual_rank)
	fx_school = fx.roll_school(actual_rank)
	if fx_premium:
		# The premium cue never lies, so it also removes every fake-out: the
		# downward false cue and the mid-wait reversal (a visible step back).
		# Both were rolled before this call, so clearing them leaves the
		# gameplay RNG stream untouched.
		promotion_false_cue = false
		promotion_reversal_armed = false
		promotion_cue_rank = actual_rank
	fx_heat = fx.HEAT_PREMIUM if fx_premium else _promotion_stage_limit()
	bite_delay += float(fx.wait_extension(fx_heat))
	fx_bite_heat = 0
	fx_school_done = false
	fx_premium_done = false
	fx_last_stage = 0
	fx_last_pull_shown = false
	reveal_glow_start = -1
	fx.cast(fx_heat)

func _update_cue_fx(promotion_progress: float) -> void:
	var float_pos := _float_screen_pos()
	if fx_premium and not fx_premium_done and promotion_progress >= 0.12:
		fx_premium_done = true
		fx.premium_omen()
	if fx_school and not fx_school_done and promotion_progress >= 0.38:
		fx_school_done = true
		fx.school_pass()
	var visible_stage := _visible_promotion_stage()
	if visible_stage > fx_last_stage:
		fx.cue_step(visible_stage, float_pos)
	elif visible_stage < fx_last_stage:
		fx.cue_reversal(float_pos)
	fx_last_stage = visible_stage

func _process_fishing(delta: float):
	# Notebook and map transitions pause fishing; the same pause applies here.
	var choice_changed := false
	# Thirty seconds leaves room for the reveal and another full tug-of-war.
	fever_flash_t = maxf(0.0, fever_flash_t - delta)
	# FEVER's clock starts when it is announced, i.e. when the catch that earned
	# it is settled. While that choice is still open the clock holds, so a result
	# left on screen cannot burn FEVER down (and lose its banner) unseen.
	if fever_active and not _fever_waiting():
		fever_t = maxf(0.0, fever_t - delta)
		if fever_t <= 0.0:
			_break_chain()
			toast = "FEVER ended / Build another three-catch chain"
			toast_t = 2.0
	if fishing_state == FishingState.ANTICIPATING:
		bite_timer += delta
		promotion_t = bite_timer
		var promotion_progress := clampf(bite_timer / maxf(0.01, bite_delay), 0.0, 1.0)
		# The rescue tide is a visible promotion assist, not an auto-catch. It
		# brings the float forward a little after repeated misses/GOOD catches,
		# while the player still has to win the timing battle below.
		var stage_bias := 0.12 * float(promotion_cue_rank) + promotion_rescue_bonus * 0.60
		var cue_progress := clampf(promotion_progress + stage_bias, 0.0, 1.0)
		var raw_stage := 3 if cue_progress >= 0.86 else (2 if cue_progress >= 0.62 else (1 if cue_progress >= 0.34 else 0))
		promotion_stage = mini(raw_stage, _promotion_stage_limit())
		if promotion_reversal_armed and promotion_progress > 0.62 and promotion_progress < 0.76: promotion_reversal = true
		_update_cue_fx(promotion_progress)
		cast_timer = maxf(0.0, cast_timer-delta)
		if bite_timer >= bite_delay:
			fishing_state = FishingState.TIMING
			# The heat the player actually saw decides the reach and where the
			# reveal's summon light starts.
			fx_bite_heat = fx.HEAT_PREMIUM if fx_premium else _visible_promotion_stage()
			# Only purple-or-hotter cues are a promise the reveal can break with
			# a fizzle; a gold float is too common to deflate every catch.
			reveal_glow_start = mini(3, fx_bite_heat) if fx_bite_heat >= 2 else mini(fx_bite_heat, _rarity_heat(promotion_target_rarity))
			fx.bite(fx_bite_heat, _float_screen_pos())
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
		var escape_rate := float(RODS[rod_index].escape_mult) * float(BAITS[bait_index].get("escape_mult", 1.0))
		# Bait risk applies to uncountered surges only. A deliberate counter
		# remains a reliable recovery action regardless of the lure selected.
		var escape_change := -0.035 * float(RODS[rod_index].escape_mult) if countering else (0.095 if straining else 0.055) * escape_rate
		battle_escape = clampf(battle_escape + delta * escape_change, 0.0, 1.0)
		battle_tension = clampf(battle_tension + delta * (-0.045 if countering else (0.07 if straining else -0.014)) * float(RODS[rod_index].tension_mult), 0.0, 1.0)
		gauge += delta * (1.25 + battle_tension * 0.75) * gauge_direction
		if gauge >= 1.0: gauge = 1.0; gauge_direction = -1.0
		if gauge <= 0.0: gauge = 0.0; gauge_direction = 1.0
		fx.set_danger(battle_tension)
		if timing_timer <= 0.0 or battle_tension >= 1.0 or battle_escape >= 1.0:
			# Running out of line is a miss even if the fish was nearly tired.
			_resolve_fishing_timing(-1.0)
		elif Input.is_action_just_pressed("fish"):
			_handle_fishing_strike(gauge, counter)
	elif fishing_state == FishingState.RESULT:
		result_t -= delta
		# Flush a queued reveal toast before reading disposition input. If
		# SELL/REGISTER is pressed on this same frame, its confirmation replaces
		# the reveal toast and the final guard below cannot overwrite it.
		_flush_result_toast()
		if catch_choice_pending():
			# The prompt is hidden until the card flips, so ignore blind presses.
			if not catch_reveal_complete():
				pass
			elif Input.is_action_just_pressed("sell_catch"):
				choice_changed = sell_pending_catch()
			elif Input.is_action_just_pressed("register_catch"):
				choice_changed = register_pending_catch()
			elif Input.is_action_just_pressed("fish"):
				# Space never silently chooses a disposition.  Keep the result on
				# screen until the player explicitly sells or registers it.
				result_toast_pending = ""
				toast = "Choose SELL or REGISTER / the catch is safely held"
				toast_t = 1.8
				choice_changed = true
		elif Input.is_action_just_pressed("fish"):
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
				shake_t = maxf(shake_t, 0.65)
				fx.legendary_crack()
			if previous_legendary_t < 2.05 and legendary_t >= 2.05:
				legendary_stage = maxi(legendary_stage, 2)
				_play_se("peak")
				shake_t = maxf(shake_t, 1.8)
				fx.legendary_shatter()
			if previous_legendary_t < 3.75 and legendary_t >= 3.75:
				legendary_stage = maxi(legendary_stage, 3)
				_play_se("after")
				fx.legendary_afterglow()
		elif last_grade != "MISS":
			var previous_reveal_t := reveal_t
			var reveal_duration := 1.24 if reveal_shortened else 2.0
			reveal_t = minf(reveal_t + delta, reveal_duration)
			reveal_stage = _reveal_stage_at(reveal_t, last_rarity)
			# A single gentle chime marks the turn; the FX director adds the
			# summon-light promotions and one rarity-scaled burst on the face.
			var flip_time := 0.92 if reveal_shortened else 1.48
			if previous_reveal_t < flip_time and reveal_t >= flip_time:
				_play_se("rise")
			for step in _reveal_glow_plan():
				if previous_reveal_t < float(step.t) and reveal_t >= float(step.t):
					if str(step.kind) == "promote": fx.reveal_promote(int(step.rank))
					else: fx.reveal_fizzle()
			var face_time := _reveal_face_time()
			if previous_reveal_t < face_time and reveal_t >= face_time:
				fx.reveal_flip(_rarity_heat(last_rarity), bool(last_catch_metadata.get("first_capture", false)), bool(last_catch_metadata.get("crown", false)))
	if not choice_changed:
		_flush_result_toast()
	shake_t = maxf(0.0, shake_t-delta)
	fish_particle_t += delta

func _reveal_face_time() -> float:
	return 1.78 * (0.62 if reveal_shortened else 1.0)

# The summon light's steps on the reveal clock: each step up is a "promotion"
# (gacha-style 昇格); a cue that promised more than the catch fizzles down once.
func _reveal_glow_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if last_rarity == "" or last_rarity == "LEGENDARY": return plan
	var result := _rarity_heat(last_rarity)
	var start := result if reveal_glow_start < 0 else reveal_glow_start
	var scale := 0.62 if reveal_shortened else 1.0
	if start < result:
		for k in range(1, result - start + 1):
			plan.append({"t": (0.86 + float(k - 1) * 0.18) * scale, "rank": start + k, "kind": "promote"})
	elif start > result:
		plan.append({"t": 0.86 * scale, "rank": result, "kind": "fizzle"})
	return plan

func _reveal_glow_rank_at(time: float) -> int:
	var rank := _rarity_heat(last_rarity) if reveal_glow_start < 0 else reveal_glow_start
	for step in _reveal_glow_plan():
		if time >= float(step.t): rank = int(step.rank)
	return rank

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
	# State only. The catch that earned FEVER is still being revealed, so its
	# presentation is deferred to _announce_fever_if_pending (see _fever_waiting).
	fever_active = true
	fever_t = FEVER_DURATION

# Shown when a miss ends a chain, so a near-FEVER loss reads as a near miss.
func _chain_break_note(lost_combo: int, lost_fever: bool) -> String:
	if lost_fever: return "FEVER lost at CHAIN %d" % lost_combo
	var remaining := FEVER_THRESHOLD - lost_combo
	if lost_combo <= 0 or remaining <= 0: return ""
	if remaining == 1: return "惜しい!  one more catch for FEVER"
	return "CHAIN %d lost  /  %d more for FEVER" % [lost_combo, remaining]

func _break_chain() -> void:
	combo = 0
	fever_active = false
	fever_t = 0.0
	fever_flash_t = 0.0
	fever_announce_pending = false
	_music_call("set_fever", [false])
	_music_call("set_combo", [0])

func _resolve_fishing_timing(position: float):
	var grade := "MISS"
	if position >= 0.42 and position <= 0.62: grade = "PERFECT"
	elif position >= 0.26 and position <= 0.80: grade = "GOOD"
	if grade == "MISS":
		promotion_false_cue_revealed = promotion_false_cue
		promotion_result_label = ""
		chain_break_text = _chain_break_note(combo, fever_active)
		fx.miss(_float_screen_pos(), chain_break_text.begins_with("惜しい"))
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
		toast = "MISS!  " + (chain_break_text + "  /  " if chain_break_text != "" else "") + "SPACE to cast again"
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
	# Golden tide is a cast-time guarantee. Keep its EPIC/LEGENDARY candidate
	# intact through a GOOD timing result instead of downgrading it to RARE.
	var premium_locked := fx_premium and _rarity_rank(candidate_rarity) >= _rarity_rank("EPIC")
	picked = _candidate_for_grade(picked, grade, premium_locked)
	var legendary := str(picked.get("rarity", "COMMON")) == "LEGENDARY"
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
	fx.landed(_rarity_heat(last_rarity), last_rarity == "LEGENDARY", _float_screen_pos())
	if fever_started:
		# Announce FEVER when the player settles this catch, so the banner
		# never covers the reveal that earned it and leads into the next cast.
		fever_announce_pending = true
	fish_count += 1
	catches[last_catch] = int(catches.get(last_catch,0))+1
	var resolved_metadata := _record_catch_metadata(picked, grade)
	_open_catch_choice(resolved_metadata)
	fishing_state = FishingState.RESULT
	cast_timer = 0.0
	legendary_t = 0.0
	legendary_stage = 0
	reveal_t = 0.0
	reveal_stage = 0
	result_t = 6.2 if last_rarity == "LEGENDARY" else 2.0
	shake_t = 1.10 if last_rarity == "LEGENDARY" else (0.22 if last_rarity == "RARE" else 0.10)
	_play_se("catch" if last_rarity != "LEGENDARY" else "legendary")
	var catch_toast := ("BIG CATCH!!  " if legendary else grade + "!  ") + last_catch
	if rescue_was_ready and last_rescue_used:
		catch_toast = "RESCUE! RARE floor / " + last_catch
	if fever_started: catch_toast = "FEVER! Rarity boosted for 30s / " + last_catch
	# Every variant names the fish (or its rarity), so none may appear while the
	# card is still face-down; _flush_result_toast shows it after the flip.
	result_toast_pending = catch_toast
	toast = ""
	toast_t = 0.0

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
			fx.strain(_float_screen_pos())
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
		fx.strain(_float_screen_pos())
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
	_play_se("perfect_tug" if grade == "PERFECT" else "tug")
	fx.pull(grade, _float_screen_pos(), battle_hits, 1.0 - float(fish_hp) / maxf(1.0, float(fish_hp_max)))
	if fish_hp > 0 and fish_hp <= 2 and not fx_last_pull_shown:
		fx_last_pull_shown = true
		fx.last_pull(fx_bite_heat, _float_screen_pos())
	if fish_hp <= 0:
		# Preserve the strongest grade across the battle for rarity/combos.
		_resolve_fishing_timing(0.5 if perfect_pulls * 2 >= battle_hits else 0.34)
		return
	toast = ("PERFECT PULL!  " if grade == "PERFECT" else "GOOD PULL!  ") + "Fish stamina %d/%d" % [fish_hp, fish_hp_max]
	toast_t = 0.9

func _se_playback() -> AudioStreamGeneratorPlayback:
	# Pick the pool voice with the most free buffer so overlapping cues mix.
	var best: AudioStreamGeneratorPlayback = null
	var best_free := -1
	var pool: Array = se_players if not se_players.is_empty() else [se_player]
	for node in pool:
		if node == null or node.stream == null or not node.playing: continue
		var playback := node.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback == null: continue
		var free := playback.get_frames_available()
		if free > best_free:
			best_free = free
			best = playback
	return best

func _play_se(kind: String):
	# Tiny procedural chimes keep the feedback punchy while avoiding bundled
	# copyrighted assets. In headless tests the audio server may be absent, so
	# every step is guarded and simply becomes a no-op there.
	var playback := _se_playback()
	if playback == null: return
	var duration := 0.18
	var base := 280.0
	var volume := 0.22
	var sweep := 0.0
	var noise := 0.0
	var decay := 0.06
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
		# ---- dopamine FX cues (EFFECTS_DESIGN.md) ----
		"step1":
			base = 660.0; duration = 0.2; volume = 0.24; sweep = 330.0; tones = [990.0]
		"step2":
			base = 311.1; duration = 0.42; volume = 0.3; sweep = -30.0; tones = [370.0, 466.2]; decay = 0.2
		"step3":
			base = 523.2; duration = 0.55; volume = 0.34; sweep = 520.0; tones = [784.0, 1046.5]; noise = 0.12
		"heartbeat":
			base = 58.0; duration = 0.34; volume = 0.6; sweep = -12.0
		"cutin":
			base = 240.0; duration = 0.34; volume = 0.3; sweep = 900.0; noise = 0.5; tones = [523.2, 659.2]
		"fizzle":
			base = 330.0; duration = 0.26; volume = 0.16; sweep = -220.0
		"school":
			base = 880.0; duration = 0.5; volume = 0.2; sweep = 440.0; tones = [1318.5]; noise = 0.06
		"premium":
			base = 1046.5; duration = 0.95; volume = 0.3; tones = [1568.0, 2093.0, 2637.0]; decay = 0.8
		"impact":
			base = 110.0; duration = 0.13; volume = 0.42; sweep = -60.0; noise = 0.35
		"landed":
			base = 196.0; duration = 0.38; volume = 0.36; sweep = 200.0; tones = [392.0, 587.3]; noise = 0.2
		"snap":
			base = 900.0; duration = 0.22; volume = 0.26; sweep = -760.0; noise = 0.6
		"promote":
			base = 700.0 + 0.0; duration = 0.24; volume = 0.32; sweep = 520.0; tones = [1050.0, 1400.0]
		"flip0":
			base = 523.2; duration = 0.2; volume = 0.2; tones = [659.2]
		"flip1":
			base = 523.2; duration = 0.26; volume = 0.24; tones = [659.2, 784.0]
		"flip2":
			base = 587.3; duration = 0.36; volume = 0.3; sweep = 120.0; tones = [740.0, 880.0, 1174.7]; noise = 0.08
		"flip3":
			base = 523.2; duration = 0.6; volume = 0.36; sweep = 260.0; tones = [659.2, 784.0, 1046.5, 1318.5]; noise = 0.12; decay = 0.3
		"stamp":
			base = 150.0; duration = 0.12; volume = 0.42; sweep = -40.0; noise = 0.4
		"crack":
			base = 1600.0; duration = 0.28; volume = 0.3; sweep = -1100.0; noise = 0.8
		"shatter":
			base = 620.0; duration = 0.7; volume = 0.38; sweep = -380.0; noise = 0.6; tones = [523.2, 659.2, 784.0]; decay = 0.4
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
		if noise > 0.0:
			# Hash noise keeps whooshes and cracks deterministic and cheap.
			var n := absf(fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0))
			sample = lerpf(sample, n * 2.0 - 1.0, noise)
		# Quick attack and musical tail; no click at the boundaries.
		var envelope := minf(1.0, t / 0.018) * minf(1.0, (duration - t) / decay)
		if kind == "heartbeat":
			# Two low thumps: lub-dub.
			envelope = exp(-t / 0.035) + (exp(-(t - 0.16) / 0.04) * 0.8 if t >= 0.16 else 0.0)
		playback.push_frame(Vector2.ONE * sample * volume * clampf(envelope, 0.0, 1.0))

func _finish_cast():
	# Compatibility helper for old saves/tests: resolve a generous GOOD hit.
	if fishing_state == FishingState.IDLE: _break_chain()
	_resolve_fishing_timing(0.5)

func _reset_fishing():
	# Internal callers from older saves/tests may dismiss a result directly. A
	# direct reset safely registers the held fish rather than dropping it; the
	# runtime SPACE path above still requires an explicit player choice.
	if catch_choice_pending(): register_pending_catch()
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
	pending_catch = {}
	pending_catch_state = ""
	last_catch_decision = ""
	result_toast_pending = ""
	chain_break_text = ""
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
	promotion_rescue_bonus = 0.0
	fx.clear_show()
	fx_premium = false
	fx_school = false
	fx_last_stage = 0
	reveal_glow_start = -1
	toast = "Ready to cast"
	toast_t = 1.2

func _save_game(path: String = SAVE_PATH):
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		toast = "Could not save. Please check available storage."; toast_t = 4; return
	f.store_string(JSON.stringify({"version":13,"combo":combo,"fever_t":fever_t,"pity_meter":pity_meter,"rescue_meter":pity_meter,"rescue_ready":rescue_ready,"low_grade_streak":low_grade_streak,"map":current_map,"day":day,"time":time_of_day,"weather":weather,"season":season,"fish":fish_count,"shells":shells,"bait":bait_index,"rod":rod_index,"x":player.x,"y":player.y,"catches":catches,"catch_metadata":catch_metadata,"first_capture_metadata":first_capture_metadata,"catch_latest":catch_latest,"best_records":best_records,"rumor_found":rumor_found,"heard_rumors":heard_rumors,"hidden_spot_unlocked":hidden_spot_unlocked,"hidden_spot_collected":hidden_spot_collected,"pending_catch":pending_catch,"pending_catch_state":pending_catch_state,"last_catch_decision":last_catch_decision,"reveal_t":reveal_t,"reveal_stage":reveal_stage,"reveal_shortened":reveal_shortened,"legendary_t":legendary_t,"legendary_stage":legendary_stage,"fx_reduced":fx.reduced,"fever_announce_pending":fever_announce_pending and fever_active and catch_choice_pending()}))
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
	fx.reduced = bool(data.get("fx_reduced", false))
	if loaded_map in ["town","beach","rocky","grotto"] and loaded_map != current_map:
		current_map = loaded_map; _build_map(current_map)
	day = maxi(1,int(data.get("day",1))); fish_count = maxi(0,int(data.get("fish",0)))
	shells = maxi(0, int(data.get("shells", 12)))
	bait_index = clampi(int(data.get("bait", 0)), 0, BAITS.size()-1)
	rod_index = clampi(int(data.get("rod", 0)), 0, RODS.size()-1)
	time_of_day = clampf(float(data.get("time",0.35)),0.0,1.0)
	weather = _normalize_weather(str(data.get("weather", _weather_for_day(day))))
	season = _normalize_season(str(data.get("season", _season_for_day(day))))
	var saved_pos := Vector2(float(data.get("x",368)),float(data.get("y",372)))
	if _walkable(saved_pos):
		player = saved_pos
	else:
		# A migrated or malformed save must never leave the hero at the previous
		# map's position (or inside a lagoon/solid). Use the map's known entry
		# point, then fall back to the town start if a future map changes shape.
		var safe_spawn := Vector2(510,150) if current_map == "grotto" else Vector2(400,80)
		if _walkable(safe_spawn): player = safe_spawn
	if data.get("catches",{}) is Dictionary: catches = data.get("catches",{})
	catch_metadata.clear()
	first_capture_metadata.clear()
	catch_latest.clear()
	best_records.clear()
	pending_catch = {}
	pending_catch_state = ""
	last_catch_decision = ""
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
	# Newer saves keep best_records as the registered-crown ledger (a sold
	# specimen is deliberately absent), so rebuilding it from catch_latest would
	# resurrect crowns the player sold.
	for species in catch_metadata:
		if data.has("best_records"): break
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
	# A v11/v12 save may have been written while the result card was awaiting the
	# player's disposition. Restore that card instead of silently discarding the
	# held fish. Older saves have no pending fields and remain idle as before.
	var saved_pending = data.get("pending_catch", {})
	var saved_pending_state := str(data.get("pending_catch_state", ""))
	if saved_pending is Dictionary and saved_pending_state == "pending" and not saved_pending.is_empty():
		var pending_copy: Dictionary = saved_pending.duplicate(true)
		var pending_species := str(pending_copy.get("species", ""))
		var pending_meta_raw = pending_copy.get("metadata", {})
		if pending_species != "" and pending_meta_raw is Dictionary:
			pending_copy["species"] = pending_species
			var pending_first_capture := bool(pending_meta_raw.get("first_capture", false))
			pending_copy["metadata"] = _normalize_catch_metadata(pending_meta_raw, pending_species, pending_first_capture)
			pending_copy["sell_value"] = maxi(1, int(pending_copy.get("sell_value", _catch_sell_value(pending_copy["metadata"]))))
			pending_copy["ledger_counted"] = bool(pending_copy.get("ledger_counted", true))
			pending_copy["decision"] = "pending"
			pending_catch = pending_copy
			pending_catch_state = "pending"
			last_catch_decision = ""
			last_catch = pending_species
			last_catch_metadata = pending_copy["metadata"].duplicate(true)
			last_rarity = str(last_catch_metadata.get("rarity", "COMMON"))
			last_grade = str(last_catch_metadata.get("grade", "GOOD"))
			last_catch_size_cm = float(last_catch_metadata.get("size_cm", 0.0))
			last_catch_weight_kg = float(last_catch_metadata.get("weight_kg", 0.0))
			last_catch_variant = str(last_catch_metadata.get("variant", "Standard"))
			last_catch_mystery = bool(last_catch_metadata.get("mystery", false))
			fishing_state = FishingState.RESULT
			reveal_shortened = bool(data.get("reveal_shortened", not bool(last_catch_metadata.get("first_capture", false))))
			reveal_stage = clampi(int(data.get("reveal_stage", 4)), 0, 4)
			reveal_t = maxf(0.0, float(data.get("reveal_t", 2.0 if not reveal_shortened else 1.24)))
			legendary_t = clampf(float(data.get("legendary_t", 6.0 if last_rarity == "LEGENDARY" else 0.0)), 0.0, 6.0)
			legendary_stage = clampi(int(data.get("legendary_stage", 3 if last_rarity == "LEGENDARY" and legendary_t >= 3.75 else 0)), 0, 3)
			result_t = 999.0
			toast = "Catch restored / choose REGISTER or SELL"
			toast_t = 4.0
	rumor_found = bool(data.get("rumor_found", false))
	heard_rumors = []
	var known_rumors := _all_rumor_ids()
	var saved_rumors = data.get("heard_rumors", [])
	if saved_rumors is Array:
		for id in saved_rumors:
			if known_rumors.has(str(id)) and not heard_rumors.has(str(id)): heard_rumors.append(str(id))
	# Saves from before the rumor list only knew the single grotto rumor.
	if rumor_found and not heard_rumors.has("grotto"): heard_rumors.append("grotto")
	rumor_page = maxi(0, heard_rumors.size() - 1)
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
	# A banner request belongs to the held catch that earned FEVER. It comes back
	# from the save only together with that catch and the running FEVER; it is
	# never inherited from this session's memory (a stale one would hold the
	# restored clock), and older saves without the key simply have none.
	fever_announce_pending = bool(data.get("fever_announce_pending", false)) and fever_active and catch_choice_pending()
	_music_call("set_fever", [fever_active and not fever_announce_pending])
	_music_call("set_combo", [combo])
	toast = "Welcome back to Saltmere"; toast_t = 3

func _draw():
	if terrain == null: return
	# Town keeps its authored terrain sheet; shoreline maps get their own layered
	# pixel backdrops so each transition has a distinct silhouette. These layers
	# are visual-only: movement and fishing still use _shore() and solids below.
	_draw_map_background()
	_draw_map_landmarks()
	var drawn := false
	for prop in props:
		if not drawn and prop.pos.y > player.y:
			_draw_player(); drawn = true
		var tex: Texture2D = textures[prop.kind]
		if not _using_static_map_art():
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
		if fx_premium and fx_premium_done: float_color = Color("#ffd44a").lerp(Color.WHITE, 0.3 + 0.3 * sin(elapsed * 8.0))
		# Rings spread from the float; hotter cues ring faster and wider.
		if visible_stage >= 1 or (fx_premium and fx_premium_done):
			var rings := 2 + visible_stage
			for r in range(rings):
				var phase := fmod(elapsed * (0.8 + visible_stage * 0.35) + float(r) / float(rings), 1.0)
				draw_arc(float_pos + Vector2(1, 2), 4.0 + phase * (8.0 + visible_stage * 6.0), 0, TAU, 20, Color(float_color, (1.0 - phase) * 0.7), 1.0)
		if visible_stage >= 2:
			draw_circle(float_pos+Vector2(1,1), 7.0 + sin(elapsed*12.0) * 1.5, Color(float_color, 0.22))
		draw_circle(float_pos+Vector2(1,1),3.0+sin(elapsed*10)*1.2,float_color)

func _draw_map_background() -> void:
	match current_map:
		"beach":
			var beach_art: Texture2D = map_art.get("beach")
			if beach_art != null:
				draw_texture_rect(beach_art,Rect2(Vector2.ZERO,WORLD_SIZE),false)
			else:
				_draw_beach_background()
		"rocky":
			var rocky_art: Texture2D = map_art.get("rocky")
			if rocky_art != null:
				draw_texture_rect(rocky_art,Rect2(Vector2.ZERO,WORLD_SIZE),false)
			else:
				_draw_rocky_background()
		"grotto":
			var grotto_art: Texture2D = map_art.get("grotto")
			if grotto_art != null:
				draw_texture_rect(grotto_art,Rect2(Vector2.ZERO,WORLD_SIZE),false)
			else:
				_draw_rocky_background()
		_:
			draw_texture(terrain,Vector2.ZERO)
			# Town's hand-authored sheet already contains the shoreline, but a few
			# restrained highlights keep it alive beside the newer map backdrops.
			for x in range(32,819,24):
				var y := _shore(x) + 3 + int(sin(elapsed*1.5+x)*2)
				draw_line(Vector2(x,y),Vector2(x+12,y),Color("#c4dbc1"))
			for i in range(28):
				var x := 50+i*33
				var y := 558+(i%4)*18
				var drift := int(sin(elapsed+i)*3)
				draw_line(Vector2(x+drift,y),Vector2(x+drift+6,y),Color("#64a2a5"))

func _using_static_map_art() -> bool:
	return map_art.get(current_map) is Texture2D

func _draw_wave_field(color: Color, spacing: int = 30, length: int = 10) -> void:
	# Short, integer-snapped wavelets make the ocean feel hand-pixeled without
	# allocating a texture for each map. The phase is deterministic per row so
	# screenshots remain stable while the tide still has a little motion.
	for y in range(18,640,spacing):
		for x in range(18 + (y % 5) * 17,1020,54):
			var drift := int(sin(elapsed*1.2 + float(x + y) * 0.04) * 2.0)
			draw_line(Vector2(x+drift,y),Vector2(x+drift+length,y),color,1.0)

func _draw_beach_background() -> void:
	# Amber Beach is a broad sandy shelf, with a grassy terrace at the north
	# entrance and a readable shallow-water band along the fishing edge.
	draw_rect(Rect2(Vector2.ZERO,WORLD_SIZE),Color("#147f9f"))
	_draw_wave_field(Color("#3ca7b5"),28,9)
	_draw_wave_field(Color(0.38,0.78,0.80,0.46),57,6)
	var island := PackedVector2Array([
		Vector2(26,26),Vector2(828,26),Vector2(828,104),Vector2(780,104),
		Vector2(780,206),Vector2(828,206),Vector2(828,342),Vector2(780,342),
		Vector2(780,470),Vector2(826,470),Vector2(826,500),Vector2(26,500)
	])
	draw_colored_polygon(island,Color("#75a94d"))
	# Sandy apron. The slightly darker lip is the cliff edge between the two
	# materials, echoing the stepped coastlines in the reference maps.
	draw_rect(Rect2(26,218,802,282),Color("#e7c57e"))
	draw_rect(Rect2(26,214,802,7),Color("#aa764e"))
	draw_line(Vector2(26,221),Vector2(828,221),Color("#f1d18a"),2.0)
	# A shallow band gives every beach fishing spot a clear water boundary.
	draw_rect(Rect2(26,500,802,18),Color("#53b4bb"))
	draw_rect(Rect2(26,518,802,20),Color("#2b9eaf"))
	for x in range(34,820,22):
		var drift := int(sin(elapsed*1.5 + x) * 2.0)
		draw_line(Vector2(x+drift,501),Vector2(x+drift+11,501),Color("#e7f2ce"),2.0)
		draw_line(Vector2(x+6+drift,514),Vector2(x+14+drift,514),Color("#9ce0d0"),1.0)
	# A short dune/cliff face gives the north terrace a readable stepped edge
	# instead of a single flat color break.
	draw_rect(Rect2(26,221,802,12),Color("#98684c"))
	for x in range(34,820,18):
		draw_line(Vector2(x,223),Vector2(x+4,231),Color("#be8758"),2.0)
	# Dune pixels, beach grass and scattered shells add texture at the scale of
	# the existing props while keeping the path and collision fully unchanged.
	for i in range(34):
		var x := 42 + ((i * 83) % 840)
		var y := 238 + ((i * 47) % 240)
		var tuft := Color("#a1b34f") if i % 2 == 0 else Color("#c7ca68")
		draw_line(Vector2(x,y+7),Vector2(x-3,y-3),tuft,2.0)
		draw_line(Vector2(x+2,y+7),Vector2(x+5,y-5),tuft,2.0)
		if i % 5 == 0: draw_circle(Vector2(x+7,y-3),2.0,Color("#f4e2a2"))
	for i in range(13):
		var rock_pos := Vector2(48 + ((i * 137) % 820), 285 + ((i * 59) % 188))
		draw_circle(rock_pos,4.0 + float(i%3),Color("#667d7e"))
		draw_circle(rock_pos-Vector2(1,1),2.0,Color("#9ba39a"))
	# Keep the two tide pools readable in the first camera slice as well as at
	# their gameplay spots lower on the beach. These are decorative previews;
	# fishing legality still comes from _fishing_spots().
	_draw_tide_pool(Vector2(220,252),24.0,Color("#63b7c0"),Color("#e7f2ce"))
	_draw_tide_pool(Vector2(620,390),24.0,Color("#63b7c0"),Color("#e7f2ce"))
	# A broad driftwood log makes the cove identity legible before the player
	# reaches the lower landmark label.
	_draw_driftwood(Vector2(708,290))

func _draw_rocky_background() -> void:
	# Rocky Shore trades the warm beach palette for cool cliffs and shelves. The
	# lower edge follows _shore(x), so visual water and walking/fishing rules stay
	# in lockstep even where the coast steps up and down.
	draw_rect(Rect2(Vector2.ZERO,WORLD_SIZE),Color("#126f96"))
	_draw_wave_field(Color("#2b9db6"),25,8)
	_draw_wave_field(Color(0.46,0.78,0.80,0.42),52,6)
	var plateau := PackedVector2Array([
		Vector2(28,28),Vector2(828,28),Vector2(828,105),Vector2(780,105),
		Vector2(780,212),Vector2(828,212),Vector2(828,350),Vector2(790,350),
		Vector2(790,420),Vector2(812,420),Vector2(812,594),Vector2(28,594)
	])
	draw_colored_polygon(plateau,Color("#4f7c57"))
	# Extend the visual shelf to the exact stepped shoreline used by collision
	# and fishing. This closes the former 2–26px blue seam before the foam.
	for x in range(28,828,8):
		var coast_y := _shore(float(x))
		if coast_y > 594.0:
			draw_rect(Rect2(x,594,8,coast_y - 594.0),Color("#4f7c57"))
	# Slate shelves beneath the grass. Drawing stepped strips rather than one
	# flat border gives the map its cliff-like silhouette at small viewport scale.
	for y in [212,260,318,382,446,510,570]:
		var shelf_width: int = 760 - (y % 3) * 18
		draw_rect(Rect2(28,y,shelf_width,12),Color("#394f5d"))
		draw_rect(Rect2(28,y+12,shelf_width,16),Color("#344553"))
		draw_line(Vector2(30,y),Vector2(778 - (y % 3) * 18,y),Color("#7e8e8b"),2.0)
		for x in range(42,28+shelf_width,24):
			draw_line(Vector2(x,y+14),Vector2(x-2,y+26),Color("#536675"),2.0)
	_draw_breakwater(Vector2(500,360))
	for i in range(28):
		var x := 44 + ((i * 97) % 730)
		var y := 84 + ((i * 53) % 485)
		var size := 4.0 + float(i % 4) * 2.0
		var rock := Color("#526472") if i % 2 == 0 else Color("#445563")
		draw_colored_polygon(PackedVector2Array([
			Vector2(x-size,y+size),Vector2(x-2,y-size),Vector2(x+size,y-size*0.6),
			Vector2(x+size*1.2,y+size),Vector2(x,y+size*1.35)
		]),rock)
		draw_line(Vector2(x-2,y-size+1),Vector2(x+size-1,y-size*0.2),Color("#87918d"),1.0)
	# Cool grass tufts break up shelves and make paths readable behind props.
	for i in range(22):
		var x := 42 + ((i * 113) % 740)
		var y := 72 + ((i * 71) % 480)
		draw_line(Vector2(x,y+7),Vector2(x-3,y-4),Color("#8ead64"),2.0)
		draw_line(Vector2(x+2,y+7),Vector2(x+6,y-2),Color("#a5bd71"),2.0)
	# Variable coast foam tracks the collision shoreline for a satisfying edge.
	for x in range(32,819,20):
		var y := _shore(x) + int(sin(elapsed*1.4 + x) * 2.0)
		draw_line(Vector2(x,y),Vector2(x+9,y),Color("#d4f3dc"),2.0)
		if x % 40 == 0: draw_line(Vector2(x+4,y+5),Vector2(x+11,y+5),Color("#74d2d4"),1.0)
	# A few offshore stacks sell the rocky map even when the camera is centered on
	# the playable shelf. They are visual-only and intentionally outside solids.
	for i in range(9):
		var p := Vector2(820 + (i%3)*52, 118 + (i/3)*120)
		draw_circle(p,9.0 + float(i%3)*2.0,Color("#3d5262"))
		draw_circle(p-Vector2(2,3),4.0,Color("#778786"))
		draw_arc(p,11.0,0,TAU,12,Color("#a9e3dc"),2.0)

func _draw_tide_pool(center: Vector2, radius: float, water: Color, foam: Color) -> void:
	# Pools are intentionally larger than the collision marker: at the 0.67 map
	# presentation zoom a 16px circle became easy to miss, while this still leaves
	# the existing fishing spot and walkable bank untouched.
	draw_circle(center + Vector2(2,3), radius + 5.0, Color("#7e6a59"))
	draw_circle(center, radius, water)
	draw_circle(center - Vector2(4,4), radius * 0.72, water.lightened(0.16))
	draw_arc(center, radius + 2.0, 0, TAU, 24, foam, 2.0)
	for i in range(5):
		var q := center + Vector2(-radius * 0.55 + i * radius * 0.25, sin(float(i) * 2.1) * radius * 0.34)
		draw_line(q, q + Vector2(0, -7 - (i % 2) * 3), Color("#2c8c82"), 2.0)
		draw_circle(q + Vector2(-2,-8), 2.0, Color("#74c49d"))
	for i in range(4):
		var stone := center + Vector2(-radius * 0.8 + i * radius * 0.5, radius * 0.55 + sin(float(i)) * 2.0)
		draw_circle(stone, 3.0 + float(i % 2), Color("#5e7177"))
		draw_circle(stone - Vector2(1,1), 1.5, Color("#9ca49a"))

func _draw_driftwood(center: Vector2) -> void:
	# Thick, knotted driftwood keeps the beach landmark legible at camera zoom.
	draw_line(center + Vector2(-39,11), center + Vector2(41,-11), Color("#6d5140"), 10.0)
	draw_line(center + Vector2(-37,8), center + Vector2(39,-14), Color("#a8784e"), 6.0)
	draw_circle(center + Vector2(-39,11), 5.0, Color("#533f37"))
	draw_circle(center + Vector2(41,-11), 4.0, Color("#c39360"))
	draw_line(center + Vector2(-12,4), center + Vector2(-25,-12), Color("#986d49"), 4.0)
	draw_line(center + Vector2(10,-2), center + Vector2(23,-18), Color("#986d49"), 3.0)

func _draw_breakwater(center: Vector2) -> void:
	# A broad stone finger reads as a breakwater even in the camera's local slice.
	for i in range(9):
		var q := center + Vector2(i * 21 - 84, sin(float(i) * 1.7) * 5.0)
		draw_circle(q + Vector2(1,3), 13.0, Color("#304955"))
		draw_circle(q, 11.0, Color("#526b76"))
		draw_circle(q - Vector2(3,3), 5.0, Color("#80918c"))
		draw_arc(q, 14.0, 0, TAU, 12, Color("#b7e8dc"), 2.0)

func _exit_markers() -> Array[Dictionary]:
	# Exit markers are deliberately kept in world space so they remain visible as
	# the camera follows the player. Their locations come from MAP_EXITS.
	var markers: Array[Dictionary] = []
	for entry in _map_exits():
		markers.append({"pos":entry.marker,"label":entry.label,"dir":entry.dir})
	return markers

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
	if _using_static_map_art():
		_draw_static_map_labels()
		if current_map == "rocky" and hidden_spot_unlocked:
			# Moonlit Grotto is a gameplay unlock layered onto the Rocky Shore art.
			_draw_tide_pool(Vector2(690,480),24.0,Color("#4d5fa0"),Color("#d9d2ff"))
			draw_string(ThemeDB.fallback_font,Vector2(638,563),"Moonlit Grotto",HORIZONTAL_ALIGNMENT_CENTER,104,10,Color("#e4dcff"))
		_draw_fishing_markers()
		return
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
		elif kind == "rumor_npc":
			# A tiny plaza fisherman gives the rumor loop a readable NPC source
			# without adding a new sprite dependency.
			draw_circle(p + Vector2(0,-12), 7.0, Color("#d6b27a"))
			draw_rect(Rect2(p + Vector2(-8,-5), Vector2(16,17)), Color("#557f82"))
			draw_line(p + Vector2(-6,12), p + Vector2(-10,21), Color("#3d4d51"), 3.0)
			draw_line(p + Vector2(6,12), p + Vector2(10,21), Color("#3d4d51"), 3.0)
			draw_line(p + Vector2(7,-2), p + Vector2(16,-14), Color("#8f6e4e"), 2.0)
		var rumor_key := "mera" if kind == "rumor_npc" else ("notice" if kind == "rumor_sign" else "")
		if rumor_key != "" and _next_unheard_rumor(rumor_key) != "":
			# A bobbing "!" says there is a new rumor to hear.
			draw_string(ThemeDB.fallback_font, p + Vector2(-4,-22 + sin(elapsed * 3.0) * 1.5), "!", HORIZONTAL_ALIGNMENT_CENTER, 8, 13, Color("#ffe08a"))
		if current_map == "town":
			# Keep town's existing handwritten labels and rumor/NPC presentation.
			draw_string(ThemeDB.fallback_font, p + Vector2(-34,27), str(landmark.label), HORIZONTAL_ALIGNMENT_CENTER, 68, 8, Color("#3f514d"))
		else:
			# Shoreline landmarks use little wooden field signs, echoing the reference
			# maps while remaining a purely decorative draw pass. Lighthouse labels
			# sit below the tower so the sign never masks its beacon silhouette.
			var label := str(landmark.label)
			var sign_width := maxf(52.0, float(label.length() * 5 + 14))
			var sign_y := p.y + 30.0 if kind == "lighthouse" else (p.y - 40.0 if p.y > 120.0 else p.y + 24.0)
			var sign_rect := Rect2(Vector2(p.x - sign_width * 0.5, sign_y),Vector2(sign_width,18))
			draw_line(Vector2(p.x - sign_width * 0.25, sign_y + 18),Vector2(p.x - sign_width * 0.25, sign_y + 25),Color("#654839"),2.0)
			draw_line(Vector2(p.x + sign_width * 0.25, sign_y + 18),Vector2(p.x + sign_width * 0.25, sign_y + 25),Color("#654839"),2.0)
			draw_rect(sign_rect,Color("#c58a52"))
			draw_rect(sign_rect.grow(-2),Color("#7a543e"),false,1.0)
			draw_string(ThemeDB.fallback_font, Vector2(sign_rect.position.x + 4, sign_rect.position.y + 12), label, HORIZONTAL_ALIGNMENT_CENTER, sign_width - 8, 8, Color("#2b3031"))
	# Fishing markers sit just inland of each water feature and pulse gently.
	for spot in _fishing_spots():
		var p: Vector2 = spot.pos
		var pulse := 1.0 + sin(elapsed*3.0 + p.x)*0.15
		draw_circle(p,5.0*pulse,Color(0.91,0.81,0.47,0.85))
		draw_arc(p,9.0*pulse,0,TAU,12,Color("#f3e2a2"),1.0)

func _draw_static_map_labels() -> void:
	# The generated background boards are intentionally blank so text stays
	# dynamic and localized. These coordinates match the 1024x640 map art.
	var labels: Array[Dictionary] = []
	if current_map == "beach":
		labels = [
			{"pos":Vector2(205,157),"text":"North Tide Pool"},
			{"pos":Vector2(873,285),"text":"Driftwood Cove"},
			{"pos":Vector2(725,370),"text":"South Tide Pool"}
		]
	elif current_map == "rocky":
		labels = [
			{"pos":Vector2(497,151),"text":"Blackglass Pool"},
			{"pos":Vector2(773,248),"text":"Stone Breakwater"},
			{"pos":Vector2(614,375),"text":"Gull's Pool"},
			{"pos":Vector2(953,112),"text":"Farwatch Lighthouse"}
		]
	else:
		labels = [{"pos":Vector2(292,176),"text":"Moonlit Grotto"}]
	for entry in labels:
		var p := _map_art_point(entry.pos)
		var text := str(entry.text)
		draw_string(ThemeDB.fallback_font,p,text,HORIZONTAL_ALIGNMENT_CENTER,100.0 * WORLD_SIZE.x / 1024.0,10,Color("#2b3031"))

func _map_art_point(point: Vector2) -> Vector2:
	# Generated maps are authored at 1024x640. Keep labels locked to the same
	# landmarks if a compact world width is used by an export or test harness.
	return Vector2(point.x * WORLD_SIZE.x / 1024.0, point.y * WORLD_SIZE.y / 640.0)

func _draw_fishing_markers() -> void:
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
	# Native 96×128 atlas rendered at 48×64 in world pixels. The presentation
	# camera zoom keeps the on-screen fisherman close to the reference-map scale
	# while retaining a crisp native atlas and the existing feet anchor.
	# Feet land at local y=126 → world player.y+1, matching the 8×5 collider.
	# The approved turnaround draws right profile on row 2 and left profile on row 3;
	# runtime face indices keep the historical left=2/right=3 convention.
	var atlas_face := 3 if face == 2 else 2 if face == 3 else face
	draw_texture_rect_region(hero,Rect2(player.round()-Vector2(24,62),Vector2(48,64)),Rect2(frame*96,atlas_face*128,96,128))

func _panel(rect: Rect2, paper := false):
	hud.draw_rect(rect,Color("#e5d5ab") if paper else Color("#263e43"))
	hud.draw_rect(rect.grow(-2),Color("#a38f64") if paper else Color("#8ba79b"),false,1)

func _text(pos: Vector2, value: String, size := 11, paper := false):
	hud.draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("#43534e") if paper else Color("#f1e3ba"))

func _result_reveal_hud_reserved() -> bool:
	# The result card owns the upper-center label rows. The persistent
	# chain/rescue status is redrawn in the left gutter while the result is on
	# screen, so this is a layout reservation rather than a visibility pause.
	return fishing_state == FishingState.RESULT and last_grade != "MISS" and last_rarity != ""

func _draw_result_status_hud():
	# Keep FEVER and rescue feedback visible while a held catch waits for an
	# explicit SELL/REGISTER choice. The 90px gutter is outside the standard
	# reveal card (x=104..376), so its rarity label and fish art stay untouched.
	_panel(Rect2(8,62,90,48))
	_text(Vector2(14,75),("FEVER %.0fs" % ceilf(fever_t)) if fever_active else ("CHAIN %d/%d" % [combo, FEVER_THRESHOLD]),8)
	hud_bar(Vector2(14,80),Vector2(76,4),fever_t / FEVER_DURATION if fever_active else float(combo) / FEVER_THRESHOLD,Color("#efbf69"))
	_text(Vector2(14,99),_pity_label(),7)
	if fever_flash_t > 0.0:
		hud.draw_rect(Rect2(0,0,480,270),Color(1.0,0.62,0.18,fx.soft_overlay(fever_flash_t*0.10)))

func _draw_hud():
	_panel(Rect2(8,8,174,34))
	_text(Vector2(16,22),"SALTMERE  /  " + _map_display_name(),11)
	_text(Vector2(16,35),"Day %02d    Fish %02d  Shells %02d" % [day,fish_count,shells],10)
	_panel(Rect2(8,40,174,18))
	_text(Vector2(15,53),environment_label() + "  " + clock_text(),8)
	_panel(Rect2(294,8,178,32))
	_text(Vector2(302,21),"[N] Ledger  B:%d  R:%d shells" % [bait_cost(), rod_cost()],9)
	_text(Vector2(302,34),bait_name() + " / " + rod_name(),8)
	_panel(Rect2(8,244,464,19))
	_text(Vector2(15,257),toast if toast_t>0 else _map_hint(),10)
	var nearby_exit := _exit_hint()
	if nearby_exit != "" and not notebook_open and not transition_active and fishing_state == FishingState.IDLE:
		_panel(Rect2(286,218,184,20))
		_text(Vector2(294,232),nearby_exit,10)
	if _can_fish() and not notebook_open and fishing_state == FishingState.IDLE:
		_panel(Rect2(172,218,138,20)); _text(Vector2(182,232),"SPACE Cast  /  B bait  /  R rod",10)
	elif rumor_source_near() != "" and not notebook_open and fishing_state == FishingState.IDLE:
		_panel(Rect2(172,218,84,20)); _text(Vector2(182,232),"SPACE  Talk",10)
	if fishing_state == FishingState.ANTICIPATING or fishing_state == FishingState.TIMING:
		_draw_fishing_hud()
	elif fishing_state == FishingState.RESULT:
		_draw_fishing_result()
	if not notebook_open:
		if _result_reveal_hud_reserved():
			_draw_result_status_hud()
		else:
			# Draw after the result card so the timer cannot be hidden by its reveal.
			# Standard reveals use the left gutter for status, keeping CHAIN/RESCUE
			# out of the card's upper-center rarity rows.
			_panel(Rect2(188,8,100,30))
			_text(Vector2(195,21),("FEVER %.0fs" % ceilf(fever_t)) if fever_active else ("CHAIN %d/%d" % [combo, FEVER_THRESHOLD]),10)
			hud_bar(Vector2(195,27),Vector2(85,4),fever_t / FEVER_DURATION if fever_active else float(combo) / FEVER_THRESHOLD,Color("#efbf69"))
			_panel(Rect2(188,40,100,18))
			# Seven points keeps "RESCUE 2/3  PURPLE+16%" inside the 100px panel.
			_text(Vector2(195,53),_pity_label(),7)
			if fever_flash_t > 0.0:
				hud.draw_rect(Rect2(0,0,480,270),Color(1.0,0.62,0.18,fx.soft_overlay(fever_flash_t*0.10)))
	if notebook_open:
		_panel(Rect2(66,51,348,194),true)
		_text(Vector2(85,75),"THE TIDE LEDGER",17,true)
		_text(Vector2(85,94),"Saltmere / " + current_map.capitalize() + "  " + _time_period().to_upper(),10,true)
		_text(Vector2(262,94),"Guide %d/%d  %d%%" % [collection_discovered_count(), FISH_SPECIES.size(), int(collection_percent())],9,true)
		_text(Vector2(85,104),rescue_forecast_label(),9,true)
		_text(Vector2(85,113),"Tackle  B:%s %d  /  R:%s %d  shells/cast" % [bait_name(), bait_cost(), rod_name(), rod_cost()],8,true)
		# Three-column field guide: every species has a card fallback portrait.
		var rows := 8
		for i in range(FISH_SPECIES.size()):
			var fish: Dictionary = FISH_SPECIES[i]
			var col := i / rows
			var row := i % rows
			var x := 82.0 + col * 112.0
			var y := 122.0 + row * 12.0
			var owned := int(catches.get(str(fish.name),0))
			var discovered := species_discovered(str(fish.name), owned)
			var icon := Color("#b6c7d9") if not discovered else _rarity_color(str(fish.rarity))
			# Show available illustration art in the field guide, but keep an
			# undiscovered legendary as a generic icon so its identity remains
			# masked until the first catch.
			var has_art := _fish_art_visible(str(fish.name), owned) and _draw_fish_card(Vector2(x+6,y-5), str(fish.name), Vector2(16,10))
			if not has_art: hud.draw_rect(Rect2(x,y-9,8,8),icon)
			if species_biting_now(str(fish.name)): hud.draw_circle(Vector2(x-3,y-5),2.0,Color("#4f9a6a"))
			var display_name := ledger_display_name(str(fish.name), owned)
			if best_records.has(str(fish.name)): display_name += " ^"
			_text(Vector2(x+17,y),display_name,8,true)
			_text(Vector2(x+85,y),str(owned),8,true)
		if heard_rumors.is_empty():
			_text(Vector2(85,230),"Rumors: press SPACE beside Fisher Mera or the notice",8,true)
		else:
			_text(Vector2(85,230),"[%d/%d] %s" % [rumor_page + 1, heard_rumors.size(), rumor_text(str(heard_rumors[clampi(rumor_page, 0, heard_rumors.size() - 1)]))],8,true)
		_text(Vector2(85,240),"? mystery ~ shimmer ! gilded ^ crown  green dot: biting now",8,true)
		_text(Vector2(85,220),"N close  /  A D read rumors" + ("  /  grotto opens at %d%%" % HIDDEN_SPOT_COLLECTION_PERCENT if rumor_found and not hidden_spot_unlocked else ""),8,true)

func _draw_fishing_hud():
	# Speed lines, letterbox and danger edges now live on the FX back layer.
	var challenge_live: bool = fishing_challenge != null and not fishing_challenge.done
	var challenge_offset := 30 if challenge_live else 0
	if fishing_state == FishingState.ANTICIPATING:
		# The wait is the stage for the cue show: keep the world and the float
		# visible and put the readout in a slim strip near the bottom.
		_panel(Rect2(96,180,288,36))
		var p := clampf(bite_timer / maxf(0.01,bite_delay), 0.0, 1.0)
		var stage := _visible_promotion_stage()
		var cue: String = ["FLOAT BLUE  /  quiet water", "FLOAT GOLD  /  chance", "FLOAT PURPLE  /  hold your breath", "RAINBOW  /  激アツ"][stage]
		if fx_premium and fx_premium_done: cue = "GOLDEN TIDE  /  確定"
		_text(Vector2(106,195), cue, 10)
		var bar_col: Color = Color("#ffd44a") if fx_premium and fx_premium_done else _heat_draw_color(stage, elapsed)
		if stage == 0 and not (fx_premium and fx_premium_done): bar_col = Color("#6c9b91")
		hud_bar(Vector2(106,202),Vector2(268,5),p,bar_col)
		if promotion_rescue_bonus > 0.0:
			_text(Vector2(106,213), "RESCUE TIDE  /  PURPLE+ cue +%d%%" % int(round(promotion_rescue_bonus * 100.0)), 7)
		return
	var panel := Rect2(96,48,288,160 + challenge_offset)
	_panel(panel)
	_text(Vector2(114,70), "FISHING  /  TUG-OF-WAR", 12)
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

func _draw_fish_portrait(center: Vector2, species_name: String, scale: float = 1.0, modulate := Color.WHITE) -> bool:
	var portrait: Texture2D = fish_portraits.get(species_name)
	if portrait == null: return false
	var size := Vector2(portrait.get_width(), portrait.get_height()) * scale
	hud.draw_texture_rect(portrait, Rect2(center - size * 0.5, size), false, modulate)
	return true

func _reveal_art_source(species_name: String) -> String:
	# Catch reveals should use the same illustrated species face as the field
	# guide. Keep the compact portrait as a compatibility fallback for old
	# saves or partial art bundles, but make the preferred source explicit so a
	# new species cannot silently drift to a different-looking reveal.
	if fish_cards.get(species_name) != null: return "card"
	if fish_portraits.get(species_name) != null: return "portrait"
	return "none"

func _draw_reveal_art(center: Vector2, species_name: String, target_size: Vector2, width_scale: float = 1.0, modulate := Color.WHITE) -> bool:
	var source: Texture2D = fish_cards.get(species_name)
	if source == null: source = fish_portraits.get(species_name)
	if source == null: return false
	# Cards have different aspect ratios (wide originals and the newer 3:2
	# illustrations), so fit before applying the horizontal flip squash. This
	# keeps the species art crisp and prevents tall fins from being clipped.
	var source_size := Vector2(source.get_width(), source.get_height())
	var fit := minf(target_size.x / source_size.x, target_size.y / source_size.y)
	var draw_size := source_size * fit
	draw_size.x *= clampf(width_scale, 0.0, 1.0)
	hud.draw_texture_rect(source, Rect2(center - draw_size * 0.5, draw_size), false, modulate)
	return true

func _draw_fish_card(center: Vector2, species_name: String, card_size: Vector2, modulate := Color.WHITE) -> bool:
	# Fit transparent card illustrations without stretching them. If a species
	# has no card, fall back to its compact portrait; callers can then keep the
	# existing procedural silhouette as the final fallback.
	var card: Texture2D = fish_cards.get(species_name)
	if card != null:
		var source_size := Vector2(card.get_width(), card.get_height())
		var fit := minf(card_size.x / source_size.x, card_size.y / source_size.y)
		var draw_size := source_size * fit
		hud.draw_texture_rect(card, Rect2(center - draw_size * 0.5, draw_size), false, modulate)
		return true
	var portrait_scale := minf(card_size.x / 96.0, card_size.y / 64.0)
	return _draw_fish_portrait(center, species_name, portrait_scale, modulate)

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
		_text(Vector2(116,133),chain_break_text if chain_break_text != "" else "Combo reset",11)
	if promotion_result_label != "" or promotion_false_cue_revealed:
		_text(Vector2(116,147),promotion_result_label if promotion_result_label != "" else "FALSE CUE REVEALED",9)
		_text(Vector2(116,160),"SPACE  cast again",10)
	else:
		_text(Vector2(116,155),"SPACE  cast again",11)
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
	var card_rect := Rect2(center.x - card_half_width, 35, card_half_width * 2.0, 211)
	# Summon light: the card glows in the heat the player was promised, then
	# steps up (or fizzles) to the real result before the flip.
	var glow_rank := _reveal_glow_rank_at(t)
	var glow_col := _heat_draw_color(glow_rank, t)
	var glow_amt := (0.55 + 0.3 * pulse) * (0.6 + 0.4 * float(glow_rank) / 3.0)
	for g in range(6):
		hud.draw_rect(card_rect.grow(3.0 + g * 5.0), Color(glow_col, glow_amt * (0.24 - g * 0.035)))
	_panel(card_rect)
	hud.draw_rect(card_rect.grow(-5), Color(0.06, 0.10, 0.18, 0.72))
	hud.draw_rect(card_rect.grow(-3), Color(glow_col, 0.55 + 0.35 * pulse), false, 2.0)
	# Soft rings and rays make the silhouette grow without using strobing.
	if t >= 0.42 * timing_scale:
		for ring in range(3):
			var radius := 28.0 + rise * (18.0 + ring * 15.0)
			hud.draw_arc(center, radius, 0, TAU, 64, Color(glow_col, 0.16 + pulse * 0.08 + float(glow_rank) * 0.05), 1.5 + float(glow_rank) * 0.5)
	if t >= 0.82 * timing_scale:
		var ray_count := 12 + glow_rank * 6
		for i in range(ray_count):
			var a := float(i) * TAU / float(ray_count) + t * (0.10 + float(glow_rank) * 0.12)
			var inner := 40.0 + rise * 18.0
			var outer := inner + 13.0 + rise * (28.0 + float(glow_rank) * 22.0)
			var ray_col := Color.from_hsv(fmod(float(i) / float(ray_count) + t * 0.3, 1.0), 0.6, 1.0) if glow_rank >= 3 else glow_col
			hud.draw_line(center + Vector2(cos(a), sin(a)) * inner, center + Vector2(cos(a), sin(a)) * outer, Color(ray_col, 0.22 + rise * 0.28), 1.0 + float(glow_rank) * 0.5)
	var fish_scale := 0.28
	if t >= 0.42 * timing_scale:
		fish_scale = 0.36 + rise * 0.64
	var fish_col := Color("#111a2b") if not face_visible else rarity_col.lightened(0.12)
	var fish_width_scale := 1.0
	if t >= flip_start and t < flip_end:
		fish_width_scale = absf(cos(flip_p * PI))
	var reveal_art := _draw_reveal_fish(center, fish_scale, fish_col, face_visible, fish_width_scale, last_catch)
	if face_visible and not reveal_art:
		# Coloured bands remain subtle so the card and name carry the reveal.
		for k in range(5):
			var band_x := -38.0 + float(k) * 18.0
			hud.draw_line(center + Vector2(band_x, -13) * fish_scale, center + Vector2(band_x + 5, 16) * fish_scale, Color(1.0, 0.92, 0.70, 0.42), 2.0)
	if t < 0.42 * timing_scale:
		_center_text(68, "???", 28, Color("#e7edf7"))
		_center_text(207, "A hidden tide catch", 10, Color("#b4c5db"))
	elif t < 0.82 * timing_scale:
		_center_text(66, "RARITY...", 18, glow_col.lightened(0.22))
		_center_text(207, "The water holds its breath", 10, Color("#c4d1e2"))
	elif t < flip_start:
		# While the light is still climbing, the seal names the current step so
		# each promotion reads as UNCOMMON -> RARE -> EPIC. A fizzle never shows
		# the higher, untrue rarity name.
		var seal := last_rarity
		var result_heat := _rarity_heat(last_rarity)
		if glow_rank < result_heat: seal = str(["COMMON", "UNCOMMON", "RARE", "EPIC"][glow_rank])
		_center_text(64, seal, 22, (glow_col if glow_rank < result_heat else rarity_col).lightened(0.22))
		var promoted := reveal_glow_start >= 0 and reveal_glow_start < result_heat
		_center_text(207, "PROMOTION!" if promoted and t >= 0.86 * timing_scale else "Something is surfacing", 10, Color("#fff0b0") if promoted else Color("#d5e2ef"))
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
		_center_text(199, reveal_name, 19, Color("#fff0c6"))
		# Every line sits inside the card: the HUD rows below it are not drawn over.
		_center_text(212, "%s  /  COMBO x%d  /  %.1f cm  %.2f kg  %s%s" % [last_rarity, combo, last_catch_size_cm, last_catch_weight_kg, last_catch_variant, "  NEW" if bool(last_catch_metadata.get("first_capture", false)) else ""], 8, Color("#d3deec"))
		if promotion_result_label != "" or promotion_false_cue_revealed:
			_center_text(224, promotion_result_label if promotion_result_label != "" else "FALSE CUE REVEALED", 8, Color("#f7f0cb"))
		_center_text(237, _catch_choice_prompt(), 9, Color("#fff0d8"))
	# A single low-alpha wash at the flip keeps the card readable and avoids
	# the rapid flashing that makes ordinary catches tiring to watch.
	if t >= flip_start and t < flip_end:
		var flip_glow := sin(flip_p * PI) * 0.10
		hud.draw_rect(Rect2(0, 0, 480, 270), Color(rarity_col, fx.soft_overlay(flip_glow)))

func _draw_reveal_fish(center: Vector2, scale: float, color: Color, revealed: bool, width_scale: float = 1.0, species_name: String = "") -> bool:
	# The face of an expanded catch uses the same transparent illustration as the
	# encyclopedia. Keeping a generic silhouette for the hidden stages preserves
	# the species spoiler, while the card makes the final flip match the guide
	# instead of every fish becoming one low-resolution generic portrait.
	if revealed and not species_name.is_empty():
		if _draw_reveal_art(center, species_name, Vector2(210, 140) * scale, width_scale): return true
	var body := PackedVector2Array([Vector2(-84,0), Vector2(-55,-25), Vector2(29,-30), Vector2(65,-13), Vector2(87,0), Vector2(65,18), Vector2(30,30), Vector2(-51,25)])
	var transformed := PackedVector2Array()
	for point in body:
		transformed.append(center + Vector2(point.x * width_scale, point.y) * scale)
	# A small dorsal/ventral pair and an ink outline give the fallback silhouette
	# the same deliberate polygon language as the generated field-guide art,
	# without encoding a species-specific shape before the card flips.
	var dorsal := PackedVector2Array([
		center + Vector2(-27 * width_scale, -23) * scale,
		center + Vector2(-2 * width_scale, -47) * scale,
		center + Vector2(18 * width_scale, -27) * scale
	])
	var ventral := PackedVector2Array([
		center + Vector2(-9 * width_scale, 23) * scale,
		center + Vector2(16 * width_scale, 46) * scale,
		center + Vector2(34 * width_scale, 22) * scale
	])
	hud.draw_colored_polygon(dorsal, color.darkened(0.10))
	hud.draw_colored_polygon(ventral, color.darkened(0.18))
	hud.draw_colored_polygon(transformed, color)
	var tail := PackedVector2Array([center + Vector2(-67 * width_scale, 0) * scale, center + Vector2(-112 * width_scale, -36) * scale, center + Vector2(-108 * width_scale, 35) * scale])
	hud.draw_colored_polygon(tail, color.darkened(0.18))
	var outline := transformed.duplicate()
	outline.append(transformed[0])
	hud.draw_polyline(outline, color.lightened(0.18), maxf(1.0, 1.5 * scale), true)
	hud.draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2], tail[0]]), color.lightened(0.08), maxf(1.0, 1.2 * scale), true)
	if revealed:
		hud.draw_circle(center + Vector2(57 * width_scale, -8) * scale, 5.0 * scale, Color("#18263d"))
		hud.draw_circle(center + Vector2(58 * width_scale, -10) * scale, 1.5 * scale, Color.WHITE)
	return false

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
	# Draw the fish before any result metadata. The card's transparent margins
	# still let the rainbow field show through, while the name, size, and choice
	# rows remain legible on top of even a tall legacy illustration.
	var scale := 0.22 + rise * 0.55 + peak * 0.28
	var legendary_art_revealed := false
	if t >= 2.05:
		var art_rect := _legendary_reveal_art_target_rect(0.72 + peak * 0.28)
		legendary_art_revealed = _draw_reveal_art(art_rect.get_center(), str(last_catch), art_rect.size, 1.0)
	if not legendary_art_revealed:
		# Old saves can still lack a card; reuse the improved generic silhouette
		# rather than reviving the old flat body/tail fallback. The rainbow
		# treatment below remains a legendary-only cue for that path.
		_draw_reveal_fish(center, scale, Color("#130f32") if t < 2.05 else Color("#fff1c2"), t >= 2.05)
		if t >= 2.05:
			for k in range(8):
				var x := -50.0 + k * 14.0
				var col := Color.from_hsv(fmod(float(k)/8.0+t*0.025,1.0),0.62,1.0)
				hud.draw_rect(Rect2(center+Vector2(x,-18)*scale,Vector2(13,36)*scale),col)
			hud.draw_colored_polygon(PackedVector2Array([center+Vector2(-25,-26)*scale,center+Vector2(5,-53)*scale,center+Vector2(31,-26)*scale]),Color("#d0acff"))
			hud.draw_circle(center+Vector2(57,-8)*scale,5*scale,Color("#162539"))
			hud.draw_circle(center+Vector2(58,-10)*scale,1.5*scale,Color.WHITE)
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
		_center_text(LEGENDARY_RESULT_NAME_Y,legendary_name,24,Color("#fff3c9"))
		_center_text(221,"BIG CATCH!   COMBO x%d" % combo,15,Color("#e4d2ff"))
		_center_text(234,"%.1f cm  /  %.2f kg  /  %s" % [last_catch_size_cm, last_catch_weight_kg, last_catch_variant],9,Color("#d8d0ff"))
		if promotion_result_label != "" or promotion_false_cue_revealed:
			_center_text(LEGENDARY_RESULT_PROMOTION_Y,(promotion_result_label if promotion_result_label != "" else "FALSE CUE REVEALED"),8,Color("#f7f0cb"))
		# One fixed prompt line, well inside the 270px viewport.
		_center_text(LEGENDARY_RESULT_CHOICE_Y,_catch_choice_prompt(),9,Color("#fff0d8"))
	# The initial reveal gets one soft glow, never repeated high-frequency flash.
	if t >= 2.05 and t < 2.55:
		var glow := sin((t-2.05)/0.5*PI)*0.20
		hud.draw_rect(Rect2(0,0,480,270),Color(1,0.90,0.67,fx.soft_overlay(glow)))

func _legendary_reveal_art_target_rect(growth: float = 1.0) -> Rect2:
	# Keep the maximum card box above the name and metadata rows. The artwork is
	# drawn before those rows too, so this is both a layout guard and a readable
	# composition if a future card has a denser alpha silhouette.
	var center := Vector2(240,132)
	var size := Vector2(206,138) * clampf(growth, 0.0, 1.0)
	return Rect2(center - size * 0.5, size)

func _heat_draw_color(heat: int, time: float = 0.0) -> Color:
	if heat >= 3: return Color.from_hsv(fmod(time * 0.35 + elapsed * 0.1, 1.0), 0.6, 1.0)
	return fx.HEAT_COLORS[clampi(heat, 0, 2)]

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
		"grotto": return "MOONLIT GROTTO"
		_: return current_map.to_upper()

func _map_hint() -> String:
	match current_map:
		"town": return "WASD / arrows: walk     SPACE: cast at Old Salt Pier"
		"beach": return "WASD / arrows: walk     SPACE: cast in the tide pools"
		"rocky": return "WASD / arrows: walk     SPACE: cast at the stone pools"
		"grotto": return "WASD / arrows: walk     SPACE: cast at the moonlit pool"
		_: return "WASD / arrows: walk     SPACE: cast"
