extends RefCounted
## Dopamine FX director.
##
## One place turns game events ("the float went purple", "PERFECT pull", "the
## card flipped to EPIC") into screen effects, following the heat ladder in
## EFFECTS_DESIGN.md. It only holds state and timing so it can be driven and
## inspected headless; fx_canvas.gd draws it and main.gd plays its sounds.

const SCREEN := Vector2(480, 270)
const CENTER := Vector2(240, 126)
const CARD_CENTER := Vector2(240, 137)

# Heat ladder: blue -> gold -> purple -> rainbow, plus the premium gold that
# never lies. Index 3 is drawn as a cycling rainbow by the canvas.
const HEAT_PREMIUM := 4
const HEAT_COLORS := [Color("#7fc4ff"), Color("#f4c94f"), Color("#b77dff"), Color("#ff6fae"), Color("#ffd44a")]
# A longer breath before the bite is itself a cue (see the design table).
const WAIT_EXTENSION := [0.0, 0.25, 0.8, 1.4, 1.7]
const REACH_TITLES := ["", "", "REACH!", "SUPER REACH!!", "PREMIUM REACH"]

# Photosensitivity guard: never more than three full-screen flashes in any
# rolling second, with a hard brightness cap that reduced mode lowers further.
const FLASH_WINDOW := 1.0
const FLASH_MAX_PER_WINDOW := 3
const FLASH_ALPHA_CAP := 0.55
const FLASH_ALPHA_CAP_REDUCED := 0.16
const MAX_PARTICLES := 420

# Optional cue rolls. They use this director's own RNG so adding or tuning an
# effect can never shift the gameplay RNG (species, bite timing, cue lies).
const SCHOOL_CHANCE_EPIC := 0.55
const SCHOOL_CHANCE_RARE := 0.30
const SCHOOL_CHANCE_LOW := 0.01
const PREMIUM_CHANCE := 0.20

var reduced := false
var time := 0.0
var rng := RandomNumberGenerator.new()

var hitstop_t := 0.0
var slowmo_t := 0.0
var slowmo_scale := 1.0
var shake_t := 0.0
var shake_dur := 0.0
var shake_power := 0.0
var zoom_t := 0.0
var zoom_dur := 0.0
var zoom_amount := 0.0
var chroma_t := 0.0
var chroma_dur := 0.0
var chroma_amount := 0.0

var flash_color := Color.WHITE
var flash_alpha := 0.0
var flash_t := 0.0
var flash_dur := 0.0
var flash_log: Array[float] = []

var letterbox := 0.0
var letterbox_target := 0.0
var dim := 0.0
var dim_target := 0.0
var vignette := 0.0
var vignette_target := 0.0
var vignette_color := Color(0.0, 0.0, 0.0)
var speed := 0.0
var speed_target := 0.0
var speed_heat := 0
var danger := 0.0
var fever_border := 0.0
var fever_target := 0.0
var music_duck := 1.0

# Pull impacts: one short, screen-wide burst per pull whose size is the grade
# (see pull()). Each is over within IMPACT_MAX_DUR, well inside the pull
# cooldown, so it never sits on the gauge when the next pull can be timed.
const IMPACT_MAX_DUR := 0.6
const IMPACT_DURS := [0.32, 0.34, 0.46, 0.52, IMPACT_MAX_DUR]
# The grade is written in a lane along the bottom of the screen, over the toast
# bar (which says the same thing in words) and below every row of the fishing
# panel, so stamina, tension, the counter prompt and the escape meter stay
# readable through a pull.
const IMPACT_LANE_TOP := 234.0
const IMPACT_TEXT_POS := Vector2(240, 264)
const IMPACT_TEXT_SIZES := [20, 20, 24, 26, 28]
var impacts: Array[Dictionary] = []
# Each impact also throws up an emblem: a designed badge for the grade that
# grows through the streak (see fx_canvas._draw_emblem).  It lives in the free
# margin to the right of the fishing panel, so it can be big without covering
# anything the player reads.
const IMPACT_EMBLEM_POS := Vector2(432, 100)
const IMPACT_EMBLEM_RADIUS := 44.0
# The streak card: five slots in the left margin, stamped one per consecutive
# PERFECT pull.  Five PERFECT pulls land a fish, so a full card is a perfect
# catch; a GOOD or strained pull knocks the stamps off.
const STREAK_CARD_SLOTS := 5
const STREAK_CARD_RECT := Rect2(14, 64, 68, 174)
const STREAK_CARD_BREAK_TIME := 0.5
# The old angler watching from the margin below the emblem.  His face follows
# the streak: calm before the first PERFECT, then one step more excited for each
# one in a row (assets/portraits/angler_1..5.png).  A broken streak drops him
# back to calm.  PORTRAIT_HOLD keeps him on screen through the landing.
const PORTRAIT_RECT := Rect2(398, 158, 68, 68)
const PORTRAIT_FACES := 5
const PORTRAIT_HOLD := 1.2
var portrait_change_t := 99.0
var portrait_hold: Dictionary = {}
var card_active := false
var card_count := 0
var card_stamp_t := 99.0
var card_break: Dictionary = {}
var cutins: Array[Dictionary] = []
var pops: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var school: Dictionary = {}
var golden: Dictionary = {}
var cracks: Array[Dictionary] = []
var crack_t := -1.0
var shards: Array[Dictionary] = []
var scheduled: Array[Dictionary] = []
var sounds: Array[String] = []
var counters: Dictionary = {}
var heartbeat_on := false
# Once the golden tide has shown, later steps stay on the gold ladder so the
# show never contradicts the one cue that cannot lie.
var premium_active := false
var heartbeat_t := 0.0

func _init() -> void:
	rng.randomize()

# ---- Cast-time rolls ------------------------------------------------------

func roll_school(actual_rank: int) -> bool:
	var chance := SCHOOL_CHANCE_LOW
	if actual_rank >= 3: chance = SCHOOL_CHANCE_EPIC
	elif actual_rank == 2: chance = SCHOOL_CHANCE_RARE
	return rng.randf() < chance

func roll_premium(actual_rank: int) -> bool:
	# The premium cue is the one effect that never lies: it is only rolled for
	# an EPIC-or-better candidate, and nothing else can trigger it.
	if actual_rank < 3: return false
	return rng.randf() < PREMIUM_CHANCE

func wait_extension(heat: int) -> float:
	return float(WAIT_EXTENSION[clampi(heat, 0, WAIT_EXTENSION.size() - 1)])

# ---- Frame update -----------------------------------------------------------

func update(delta: float) -> void:
	time += delta
	hitstop_t = maxf(0.0, hitstop_t - delta)
	slowmo_t = maxf(0.0, slowmo_t - delta)
	shake_t = maxf(0.0, shake_t - delta)
	zoom_t = maxf(0.0, zoom_t - delta)
	chroma_t = maxf(0.0, chroma_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	var k := clampf(delta * 5.0, 0.0, 1.0)
	letterbox = move_toward(letterbox, letterbox_target, delta * 3.2)
	dim = lerpf(dim, dim_target, k)
	vignette = lerpf(vignette, vignette_target, k)
	speed = lerpf(speed, speed_target, k)
	fever_border = move_toward(fever_border, fever_target, delta * 1.6)
	for i in impacts: i.t = float(i.t) + delta
	impacts = impacts.filter(func(i): return float(i.t) < float(i.dur))
	card_stamp_t += delta
	portrait_change_t += delta
	if not portrait_hold.is_empty():
		portrait_hold.t = float(portrait_hold.t) + delta
		if float(portrait_hold.t) >= PORTRAIT_HOLD: portrait_hold = {}
	if not card_break.is_empty():
		card_break.t = float(card_break.t) + delta
		if float(card_break.t) >= STREAK_CARD_BREAK_TIME: card_break = {}
	for c in cutins: c.t = float(c.t) + delta
	cutins = cutins.filter(func(c): return float(c.t) < float(c.dur))
	for p in pops: p.t = float(p.t) + delta
	pops = pops.filter(func(p): return float(p.t) < float(p.dur))
	for p in particles:
		var vel: Vector2 = p.vel
		vel += Vector2(0.0, float(p.gravity)) * delta
		vel *= pow(float(p.drag), delta)
		p.vel = vel
		p.pos = Vector2(p.pos) + vel * delta
		p.life = float(p.life) - delta
		p.rot = float(p.rot) + float(p.spin) * delta
	particles = particles.filter(func(p): return float(p.life) > 0.0)
	if not school.is_empty():
		school.t = float(school.t) + delta
		if float(school.t) >= float(school.dur): school = {}
	if not golden.is_empty():
		golden.t = float(golden.t) + delta
		if float(golden.t) >= float(golden.dur): golden = {}
	if crack_t >= 0.0: crack_t += delta
	for s in shards:
		s.pos = Vector2(s.pos) + Vector2(s.vel) * delta
		s.vel = Vector2(s.vel) + Vector2(0.0, 260.0) * delta
		s.rot = float(s.rot) + float(s.spin) * delta
		s.life = float(s.life) - delta
	shards = shards.filter(func(s): return float(s.life) > 0.0)
	if heartbeat_on:
		heartbeat_t -= delta
		if heartbeat_t <= 0.0:
			heartbeat_t = 0.62
			_sound("heartbeat")
	var due: Array[Dictionary] = []
	for e in scheduled:
		if float(e.at) <= time: due.append(e)
	if not due.is_empty():
		scheduled = scheduled.filter(func(e): return float(e.at) > time)
		for e in due: callv(str(e.fn), e.args)

func time_scale() -> float:
	if hitstop_t > 0.0: return 0.0
	if slowmo_t > 0.0: return slowmo_scale
	return 1.0

func shake_offset() -> Vector2:
	if shake_t <= 0.0 or shake_dur <= 0.0: return Vector2.ZERO
	var fade := shake_t / shake_dur
	var power := shake_power * fade * (0.4 if reduced else 1.0)
	return Vector2(sin(time * 83.0), cos(time * 67.0)) * power

func zoom_factor() -> float:
	if zoom_t <= 0.0 or zoom_dur <= 0.0: return 1.0
	var p := 1.0 - zoom_t / zoom_dur
	# Snap in fast, ease back out.
	var curve := minf(1.0, p / 0.15) * (1.0 - smoothstep(0.15, 1.0, p))
	return 1.0 + zoom_amount * curve * (0.5 if reduced else 1.0)

func chroma() -> float:
	if reduced or chroma_t <= 0.0 or chroma_dur <= 0.0: return 0.0
	return chroma_amount * (chroma_t / chroma_dur)

func current_flash_alpha() -> float:
	if flash_t <= 0.0 or flash_dur <= 0.0: return 0.0
	# The cap is applied again here, not only when the flash was requested, so
	# pressing F mid-flash dims a flash that is already on screen instead of
	# letting it finish at the old, brighter level.
	var cap := FLASH_ALPHA_CAP_REDUCED if reduced else FLASH_ALPHA_CAP
	return minf(flash_alpha, cap) * (flash_t / flash_dur)

# Smooth full-screen tints drawn by the HUD (reveal wash, LEGENDARY glow, FEVER
# wash) are single low-alpha bumps rather than director flashes, so they skip
# the flash budget. Reduced mode drops them entirely: the capped, budgeted
# request_flash() is then the only full-screen brightness change.
func soft_overlay(alpha: float) -> float:
	return 0.0 if reduced else alpha

func pop_sounds() -> Array[String]:
	var out := sounds.duplicate()
	sounds.clear()
	return out

# ---- Primitives -------------------------------------------------------------

func request_flash(color: Color, alpha: float, dur: float = 0.22) -> bool:
	var keep: Array[float] = []
	for at in flash_log:
		if time - at < FLASH_WINDOW: keep.append(at)
	flash_log = keep
	if flash_log.size() >= FLASH_MAX_PER_WINDOW:
		_count("flash_suppressed")
		return false
	flash_log.append(time)
	flash_color = color
	flash_alpha = minf(alpha, FLASH_ALPHA_CAP_REDUCED if reduced else FLASH_ALPHA_CAP)
	flash_t = dur
	flash_dur = dur
	_count("flash")
	return true

func shake(power: float, dur: float) -> void:
	if shake_t > 0.0 and shake_power * (shake_t / maxf(0.001, shake_dur)) > power: return
	shake_power = power
	shake_t = dur
	shake_dur = dur

func hitstop(dur: float) -> void:
	hitstop_t = maxf(hitstop_t, dur)
	_count("hitstop")

func slowmo(scale: float, dur: float) -> void:
	slowmo_scale = scale
	slowmo_t = maxf(slowmo_t, dur)

func zoom_punch(amount: float, dur: float = 0.35) -> void:
	zoom_amount = amount
	zoom_t = dur
	zoom_dur = dur

func chroma_pulse(amount: float, dur: float = 0.45) -> void:
	chroma_amount = amount
	chroma_t = dur
	chroma_dur = dur

func cutin(text: String, sub: String, style: String, dur: float = 1.15, lane: String = "center") -> void:
	# A newer banner replaces an older one; stacking banners reads as noise.
	# The "top" lane is a slimmer strip used during the tug-of-war so a banner
	# never covers the timing gauge the player is reading.
	cutins = [{"text": text, "sub": sub, "style": style, "t": 0.0, "dur": dur, "y": 34.0 if lane == "top" else 122.0, "h": 32.0 if lane == "top" else 46.0}]
	_count("cutin_" + style)
	_sound("cutin")

func pop(text: String, pos: Vector2, color: Color, size: int = 14, dur: float = 0.75, style: String = "bounce") -> void:
	pops.append({"text": text, "pos": pos, "color": color, "size": size, "t": 0.0, "dur": dur, "style": style})
	if pops.size() > 10: pops.pop_front()

# max_life caps how long each particle lives (0 = the kind's own lifetime), for
# effects that promise to be off screen by a deadline.
func burst(pos: Vector2, color: Color, count: int, spd: float, kind: String = "spark", rainbow: bool = false, max_life: float = 0.0) -> void:
	for i in range(count):
		if particles.size() >= MAX_PARTICLES: particles.pop_front()
		var a := rng.randf() * TAU
		var v := Vector2(cos(a), sin(a)) * spd * rng.randf_range(0.35, 1.0)
		var col := color
		if rainbow: col = Color.from_hsv(rng.randf(), 0.7, 1.0)
		var life := rng.randf_range(0.45, 0.95)
		var gravity := 0.0
		var drag := 0.08
		var size := rng.randf_range(1.0, 2.4)
		match kind:
			"drop":
				v.y -= spd * 0.6; gravity = 360.0; drag = 0.5; life = rng.randf_range(0.4, 0.8)
			"coin":
				v = Vector2(rng.randf_range(-1.0, 1.0) * spd * 0.7, -rng.randf_range(0.6, 1.1) * spd * 1.3)
				gravity = 420.0; drag = 0.6; life = rng.randf_range(0.9, 1.5); size = 3.0
			"confetti":
				v = Vector2(rng.randf_range(-1.0, 1.0) * spd, -rng.randf_range(0.3, 1.0) * spd)
				gravity = 120.0; drag = 0.25; life = rng.randf_range(1.2, 2.2); size = rng.randf_range(2.0, 3.4)
			"ash":
				gravity = 60.0; drag = 0.3; life = rng.randf_range(0.5, 0.9)
			"star", "gem":
				# Icons thrown up and out in a fan, tumbling as they fall.
				v = Vector2(rng.randf_range(-1.0, 1.0) * spd, -rng.randf_range(0.35, 1.0) * spd)
				gravity = 300.0; drag = 0.45; life = rng.randf_range(0.6, 1.0); size = rng.randf_range(3.2, 5.6)
			"note":
				# Music notes drift up instead of falling.
				v = Vector2(rng.randf_range(-0.7, 0.7) * spd, -rng.randf_range(0.5, 1.0) * spd)
				gravity = -50.0; drag = 0.55; life = rng.randf_range(0.6, 1.0); size = rng.randf_range(3.6, 4.8)
		if max_life > 0.0 and life > max_life:
			# Keep the spread of lifetimes, squeezed under the cap, so capped
			# particles still fade out raggedly instead of vanishing together.
			life = max_life * rng.randf_range(0.6, 1.0)
		particles.append({"pos": pos, "vel": v, "color": col, "size": size, "life": life, "max": life, "gravity": gravity, "drag": drag, "kind": kind, "rot": rng.randf() * TAU, "spin": rng.randf_range(-9.0, 9.0)})

func schedule(delay: float, fn: String, args: Array = []) -> void:
	scheduled.append({"at": time + delay, "fn": fn, "args": args})

func clear_show() -> void:
	# A cast reset is a hard boundary between shows.  Targets alone are not
	# enough here: drawables and delayed callbacks can outlive the result card
	# and then appear over the next cast (especially after a Legendary shatter).
	# Keep the rolling flash log intact so resetting cannot bypass the
	# photosensitivity budget, but drop every active/transient show primitive.
	letterbox_target = 0.0
	dim_target = 0.0
	vignette_target = 0.0
	speed_target = 0.0
	letterbox = 0.0
	dim = 0.0
	vignette = 0.0
	speed = 0.0
	danger = 0.0
	heartbeat_on = false
	heartbeat_t = 0.0
	music_duck = 1.0
	hitstop_t = 0.0
	slowmo_t = 0.0
	slowmo_scale = 1.0
	shake_t = 0.0
	shake_dur = 0.0
	shake_power = 0.0
	zoom_t = 0.0
	zoom_dur = 0.0
	zoom_amount = 0.0
	chroma_t = 0.0
	chroma_dur = 0.0
	chroma_amount = 0.0
	flash_alpha = 0.0
	flash_t = 0.0
	flash_dur = 0.0
	impacts.clear()
	card_active = false
	card_count = 0
	card_stamp_t = 99.0
	card_break = {}
	portrait_change_t = 99.0
	portrait_hold = {}
	cutins.clear()
	pops.clear()
	particles.clear()
	school = {}
	golden = {}
	cracks.clear()
	crack_t = -1.0
	shards.clear()
	scheduled.clear()
	sounds.clear()
	premium_active = false

func _sound(kind: String) -> void:
	sounds.append(kind)

func _count(key: String) -> void:
	counters[key] = int(counters.get(key, 0)) + 1

# ---- Show events: A. anticipation -----------------------------------------

func cast(heat: int) -> void:
	clear_show()
	speed_heat = heat

# ---- the wait ---------------------------------------------------------------

func cast_splash(pos: Vector2) -> void:
	burst(pos, Color("#d8f1ff"), 8, 70.0, "drop", false, 0.5)
	_sound("plop")
	_count("cast_splash")

# The float twitches before the bite.  Hotter cues twitch harder.
func nibble(pos: Vector2, strength: float) -> void:
	burst(pos, Color("#d8f1ff"), int(2.0 + strength * 2.0), 36.0 + strength * 10.0, "drop", false, 0.4)
	if strength >= 2.0: shake(0.5 * strength, 0.12)
	_sound("nibble")
	_count("nibble")

# A quiet cast that draws no bite: the fish simply leaves.
func no_bite(pos: Vector2) -> void:
	burst(pos, Color("#8f9aa8"), 6, 40.0, "ash", false, 0.5)
	pop("逃げられた…", pos + Vector2(0, -28), Color("#b6c0cc"), 11, 0.9, "drop")
	_sound("fizzle")
	_count("no_bite")

func cue_step(stage: int, float_pos: Vector2) -> void:
	_count("cue_step_%d" % stage)
	match stage:
		1:
			# Gold is reachable on almost every cast, so it stays a small
			# glint and chime. Loud effects are reserved for purple and up.
			burst(float_pos, HEAT_COLORS[1], 8, 50.0)
			_sound("step1")
		2:
			burst(float_pos, HEAT_COLORS[2], 18, 90.0)
			pop("!!", float_pos + Vector2(0, -22), HEAT_COLORS[2], 16, 0.8)
			dim_target = 0.32
			vignette_target = 0.75
			vignette_color = Color(0.20, 0.05, 0.32)
			shake(2.0, 0.25)
			zoom_punch(0.045, 0.4)
			music_duck = 0.12
			heartbeat_on = true
			heartbeat_t = 0.25
			_sound("step2")
		3:
			if premium_active: cutin("確定!!", "GOLDEN TIDE", "premium", 1.25)
			else: cutin("激アツ!!", "RAINBOW TIDE", "hot", 1.25)
			burst(float_pos, Color.WHITE, 34, 140.0, "spark", true)
			speed_target = 0.85
			speed_heat = HEAT_PREMIUM if premium_active else 3
			dim_target = 0.4
			vignette_target = 0.9
			vignette_color = Color(0.25, 0.02, 0.18)
			request_flash(Color(1, 1, 1), 0.4, 0.25)
			chroma_pulse(0.9, 0.5)
			zoom_punch(0.08, 0.5)
			shake(3.0, 0.4)
			music_duck = 0.08
			heartbeat_on = true
			_sound("step3")

func cue_reversal(float_pos: Vector2) -> void:
	burst(float_pos, Color("#8a93a6"), 8, 40.0, "ash")
	_sound("fizzle")
	_count("cue_reversal")

func school_pass() -> void:
	school = {"t": 0.0, "dur": 1.7, "seed": rng.randi()}
	_sound("school")
	_count("school")

func premium_omen() -> void:
	golden = {"t": 0.0, "dur": 2.2}
	premium_active = true
	dim_target = 0.62
	vignette_target = 0.6
	vignette_color = Color(0.25, 0.17, 0.0)
	music_duck = 0.0
	heartbeat_on = false
	speed_heat = HEAT_PREMIUM
	schedule(0.35, "_premium_hit")
	_count("premium")

func _premium_hit() -> void:
	cutin("黄金の潮", "GOLDEN TIDE", "premium", 1.5)
	request_flash(Color("#ffe59a"), 0.45, 0.35)
	burst(CENTER, HEAT_COLORS[4], 50, 170.0, "spark")
	zoom_punch(0.07, 0.6)
	_sound("premium")

func bite(heat: int, float_pos: Vector2) -> void:
	music_duck = 1.0
	heartbeat_on = false
	hitstop(0.06 + 0.02 * heat)
	shake(2.0 + float(heat), 0.3)
	zoom_punch(0.04 + 0.015 * heat, 0.35)
	burst(float_pos, Color("#d8f1ff"), 16 + heat * 6, 110.0, "drop")
	if heat >= 2: request_flash(Color(1, 1, 1), 0.22 + 0.06 * heat, 0.18)
	pop("HIT!", float_pos + Vector2(0, -24), Color.WHITE, 16, 0.6, "slam")
	# The battle has begun: lay out an empty streak card.
	card_active = true
	card_count = 0
	card_stamp_t = 99.0
	card_break = {}
	if heat >= 2: reach_start(heat)

# ---- B. reach ---------------------------------------------------------------

func reach_start(heat: int) -> void:
	letterbox_target = 1.0
	dim_target = 0.22
	speed_target = 0.45 if heat == 2 else 0.7
	speed_heat = heat
	vignette_target = 0.45
	schedule(0.12, "cutin", [REACH_TITLES[clampi(heat, 0, 4)], "Keep the line in the gold zone", "reach_premium" if heat >= HEAT_PREMIUM else ("super" if heat >= 3 else "reach"), 1.1, "top"])
	_count("reach_%d" % heat)

# The size of a pull's celebration. 0 is a strained (missed) pull, 1 a GOOD
# pull, 2 a PERFECT pull, and a run of consecutive PERFECT pulls climbs to 3
# and 4. Everything about the impact scales from this one number.
func impact_tier(grade: String, streak: int = 0) -> int:
	if grade == "PERFECT": return clampi(1 + maxi(1, streak), 2, 4)
	return 1 if grade == "GOOD" else 0

# Which emblem an impact shows: 0 strained, 1 GOOD, then 2-6 for a PERFECT
# streak of one to five.  Unlike the tier it keeps climbing to the fifth pull.
func emblem_level(tier: int, streak: int) -> int:
	if tier <= 1: return tier
	return 1 + clampi(streak, 1, STREAK_CARD_SLOTS)

# Centre of a streak-card slot; slot 0 is the bottom one.
func streak_slot_pos(slot: int) -> Vector2:
	var slot_h := (STREAK_CARD_RECT.size.y - 20.0) / float(STREAK_CARD_SLOTS)
	return Vector2(STREAK_CARD_RECT.get_center().x, STREAK_CARD_RECT.end.y - 6.0 - slot_h * (float(slot) + 0.5))

# Which of the angler's faces is showing, 1 (calm) to PORTRAIT_FACES (awed).
func portrait_face() -> int:
	if not portrait_hold.is_empty(): return int(portrait_hold.face)
	return clampi(card_count + 1, 1, PORTRAIT_FACES)

func portrait_visible() -> bool:
	return card_active or not portrait_hold.is_empty()

func _break_card() -> void:
	if card_count <= 0: return
	portrait_change_t = 0.0
	card_break = {"count": card_count, "t": 0.0}
	card_count = 0
	_count("card_break")

func _add_impact(grade: String, tier: int, pos: Vector2, streak: int, clean: bool) -> void:
	impacts.append({"grade": grade, "tier": tier, "pos": pos, "t": 0.0, "dur": float(IMPACT_DURS[tier]), "streak": streak, "clean": clean, "seed": rng.randi()})
	if impacts.size() > 4: impacts.pop_front()
	_count("impact_tier%d" % tier)

func pull(grade: String, pos: Vector2, hits: int, power: float, streak: int = 0, clean: bool = false) -> void:
	var tier := impact_tier(grade, streak)
	var perfect := tier >= 2
	var step := tier - 1
	hitstop([0.05, 0.09, 0.11, 0.13][step])
	shake(1.5 + [0.6, 2.0, 2.8, 3.6][step] + power * 2.0, 0.22 + 0.04 * float(step))
	zoom_punch(0.03 + [0.0, 0.025, 0.04, 0.055][step] + power * 0.02, 0.28)
	# Everything a pull throws is capped to the impact's lifetime, so nothing
	# from this pull is still in the air when the next one can be timed.
	burst(pos, Color("#d8f1ff"), 10 + hits * 2, 100.0, "drop", false, IMPACT_MAX_DUR)
	_add_impact(grade, tier, pos, streak, clean)
	if perfect:
		card_count = clampi(streak, 1, STREAK_CARD_SLOTS)
		card_stamp_t = 0.0
		portrait_change_t = 0.0
		_count("card_stamp")
	else:
		_break_card()
		burst(IMPACT_EMBLEM_POS, Color("#8fe6d2"), 3, 80.0, "star", false, IMPACT_MAX_DUR)
	if perfect:
		var rainbow := tier >= 4
		# Icons fly out of the emblem as it lands: stars and music notes, and
		# gems once the streak is running.  They start in the margins (the
		# emblem and the fresh stamp), not at the float, which is often behind
		# the fishing panel: icons are opaque and must not cross the gauge.
		burst(IMPACT_EMBLEM_POS, HEAT_COLORS[1], 4 + tier * 2, 110.0, "star", rainbow, IMPACT_MAX_DUR)
		burst(IMPACT_EMBLEM_POS + Vector2(0, -10), Color("#bfe9ff"), 2 + tier, 90.0, "note", rainbow, IMPACT_MAX_DUR)
		if tier >= 3: burst(IMPACT_EMBLEM_POS, Color("#ff9ad5"), tier * 2, 120.0, "gem", true, IMPACT_MAX_DUR)
		burst(IMPACT_EMBLEM_POS, HEAT_COLORS[1], 6 + tier * 3, 95.0, "spark", rainbow, IMPACT_MAX_DUR)
		burst(streak_slot_pos(card_count - 1), HEAT_COLORS[1], 5 + tier, 60.0, "star", rainbow, IMPACT_MAX_DUR)
		burst(pos, HEAT_COLORS[1], 12 + tier * 4, 120.0 + float(tier) * 20.0, "spark", rainbow, IMPACT_MAX_DUR)
		request_flash(Color("#fff3c2") if tier == 2 else Color("#fffdf0"), [0.0, 0.22, 0.30, 0.38][step], 0.14)
		# Party poppers from both bottom corners carry the hit across the screen.
		var popper := [0, 8, 14, 20][step] as int
		burst(Vector2(36, 252), HEAT_COLORS[1], popper, 300.0, "confetti", tier >= 3, IMPACT_MAX_DUR)
		burst(Vector2(SCREEN.x - 36, 252), HEAT_COLORS[1], popper, 300.0, "confetti", tier >= 3, IMPACT_MAX_DUR)
		for k in range((tier - 2) * 4):
			burst(Vector2(rng.randf_range(30.0, SCREEN.x - 30.0), rng.randf_range(24.0, SCREEN.y - 40.0)), Color("#fff6cf"), 4, 50.0, "spark", rainbow, IMPACT_MAX_DUR)
		if tier >= 3: chroma_pulse(0.35 + 0.15 * float(tier - 3), 0.3)
	# The pull's sound is main.gd's (_play_pull_se): it is one designed sound per
	# grade and streak, not a stack of effect cues.
	speed_target = clampf(speed_target + 0.05, 0.0, 1.0) if letterbox_target > 0.0 else maxf(speed_target, power * 0.35)

func last_pull(heat: int, pos: Vector2) -> void:
	heartbeat_on = true
	heartbeat_t = 0.1
	if heat >= 2:
		cutin("LAST PULL!", "あと一引き", "last", 0.95, "top")
		vignette_target = maxf(vignette_target, 0.6)
	else:
		pop("LAST!", pos + Vector2(0, -40), Color("#ffb3a8"), 12, 0.8)
	_count("last_pull")

func strain(pos: Vector2) -> void:
	shake(3.0, 0.3)
	burst(pos, Color("#ff7b6b"), 8, 70.0, "ash", false, IMPACT_MAX_DUR)
	# A missed pull gets the same screen-wide treatment in red, so the three
	# outcomes of a pull read as one family: red, teal, gold.
	_add_impact("MISS", 0, pos, 0, false)
	_break_card()

func set_danger(tension: float) -> void:
	danger = clampf((tension - 0.7) / 0.3, 0.0, 1.0)

func landed(rank: int, legendary: bool, pos: Vector2) -> void:
	# The pull that lands the fish fires its impact in this same frame. Carry
	# that one burst across the reset so the finishing blow is actually seen; it
	# is over within IMPACT_MAX_DUR, before the card shows anything to read.
	var finishing: Array[Dictionary] = []
	if not impacts.is_empty():
		var newest: Dictionary = impacts[impacts.size() - 1]
		if float(newest.t) <= 0.0 and int(newest.tier) > 0: finishing.append(newest)
	var last_face := portrait_face()
	var watching := card_active
	clear_show()
	impacts = finishing
	# The angler stays for a beat with the face the last pull earned.
	if watching: portrait_hold = {"face": last_face, "t": 0.0}
	# Battle callouts must not linger over the face-down card.
	pops.clear()
	cutins.clear()
	hitstop(0.2 if legendary else 0.1 + 0.02 * rank)
	slowmo(0.35, 0.25 if rank >= 2 else 0.0)
	request_flash(Color(1, 1, 1), 0.3 + 0.06 * rank, 0.25)
	zoom_punch(0.06 + 0.015 * rank, 0.45)
	shake(3.0 + float(rank), 0.35)
	burst(pos, Color("#d8f1ff"), 24 + rank * 8, 150.0, "drop")
	_sound("landed")

func miss(pos: Vector2, near_fever: bool) -> void:
	clear_show()
	shake(3.5, 0.3)
	burst(pos, Color("#7f8899"), 16, 80.0, "ash")
	# Below the MISS panel (y 64-174) so the callouts never cover its text.
	pop("LINE SNAPPED", Vector2(240, 196), Color("#c6ccd8"), 13, 0.9, "drop")
	if near_fever: schedule(0.3, "pop", ["惜しい!", Vector2(240, 226), Color("#ffb37a"), 18, 1.0, "slam"])
	dim = 0.35
	_sound("snap")

# ---- C. reveal --------------------------------------------------------------

func reveal_promote(rank: int) -> void:
	var col: Color = HEAT_COLORS[clampi(rank, 0, 3)]
	burst(CARD_CENTER, col, 18 + rank * 6, 130.0, "spark", rank >= 3)
	pop("UP!", CARD_CENTER + Vector2(rng.randf_range(-30, 30), -46), col.lightened(0.25), 16, 0.6, "slam")
	request_flash(col.lightened(0.4), 0.18 + 0.04 * rank, 0.16)
	zoom_punch(0.03 + 0.01 * rank, 0.3)
	shake(2.0 + float(rank), 0.22)
	if rank >= 3: chroma_pulse(0.6, 0.35)
	_sound("promote")
	_count("promote")

func reveal_fizzle() -> void:
	burst(CARD_CENTER, Color("#8a93a6"), 10, 50.0, "ash")
	_sound("fizzle")
	_count("fizzle")

func reveal_flip(rank: int, is_new: bool, is_crown: bool) -> void:
	hitstop(0.05 + 0.02 * rank)
	request_flash(Color(1, 1, 1), 0.12 + 0.1 * rank, 0.22)
	shake(1.0 + rank * 1.2, 0.3)
	zoom_punch(0.02 + 0.02 * rank, 0.4)
	var col: Color = HEAT_COLORS[clampi(rank, 0, 3)]
	burst(CARD_CENTER, col, [8, 14, 26, 44][clampi(rank, 0, 3)], 110.0 + rank * 30.0, "spark", rank >= 3)
	if rank >= 2: burst(CARD_CENTER + Vector2(0, 20), Color("#ffd75e"), 10 + rank * 6, 130.0, "coin")
	if rank >= 3:
		burst(CARD_CENTER, Color.WHITE, 60, 210.0, "confetti", true)
		chroma_pulse(0.8, 0.5)
		speed_target = 0.6
		speed_heat = 3
		schedule(1.0, "_ease_speed")
	_sound("flip%d" % clampi(rank, 0, 3))
	var delay := 0.24
	if is_new:
		schedule(delay, "stamp", ["NEW!", Color("#7ff0b2"), CARD_CENTER + Vector2(-92, -62)])
		delay += 0.22
	if is_crown:
		schedule(delay, "stamp", ["CROWN!", Color("#ffd75e"), CARD_CENTER + Vector2(92, -62)])
	_count("flip_%d" % rank)

func _ease_speed() -> void:
	speed_target = 0.0

func stamp(text: String, color: Color, pos: Vector2) -> void:
	pop(text, pos, color, 16, 1.6, "stamp")
	shake(2.0, 0.16)
	burst(pos, color, 10, 80.0)
	_sound("stamp")
	_count("stamp")

func legendary_crack() -> void:
	crack_t = 0.0
	cracks.clear()
	var origin := CENTER + Vector2(rng.randf_range(-20, 20), rng.randf_range(-10, 10))
	for i in range(9):
		var a := float(i) * TAU / 9.0 + rng.randf_range(-0.2, 0.2)
		var p := origin
		var length := rng.randf_range(140.0, 300.0)
		var segs := 6
		for s in range(segs):
			var q := p + Vector2(cos(a), sin(a)) * (length / segs) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
			cracks.append({"a": p, "b": q, "delay": float(s) * 0.035 + float(i) * 0.01})
			p = q
	request_flash(Color(0.85, 0.9, 1.0), 0.3, 0.2)
	shake(6.0, 0.6)
	chroma_pulse(0.5, 0.4)
	hitstop(0.1)
	_sound("crack")
	_count("legendary_crack")

func legendary_shatter() -> void:
	crack_t = -1.0
	cracks.clear()
	shards.clear()
	for i in range(28):
		var c := Vector2(rng.randf_range(0, SCREEN.x), rng.randf_range(0, SCREEN.y))
		var r := rng.randf_range(14.0, 34.0)
		var pts := PackedVector2Array()
		for j in range(3):
			var a := rng.randf() * TAU
			pts.append(Vector2(cos(a), sin(a)) * r)
		var dir := (c - CENTER).normalized()
		shards.append({"pos": c, "pts": pts, "vel": dir * rng.randf_range(220.0, 420.0), "rot": 0.0, "spin": rng.randf_range(-6.0, 6.0), "life": rng.randf_range(0.7, 1.1)})
	request_flash(Color("#fff6d8"), 0.55, 0.4)
	chroma_pulse(1.0, 0.7)
	zoom_punch(0.1, 0.7)
	hitstop(0.2)
	shake(7.0, 0.9)
	burst(CENTER, Color.WHITE, 140, 260.0, "confetti", true)
	burst(CENTER, Color("#ffd75e"), 30, 180.0, "coin")
	_sound("shatter")
	_count("legendary_shatter")

func legendary_afterglow() -> void:
	for i in range(4):
		schedule(float(i) * 0.25, "burst", [Vector2(rng.randf_range(60, 420), -6), Color.WHITE, 22, 60.0, "confetti", true])

# ---- D. FEVER ---------------------------------------------------------------

func fever_start() -> void:
	cutin("FEVER!!", "RARITY UP  30s", "fever", 1.3)
	request_flash(Color("#ffa040"), 0.35, 0.3)
	burst(CENTER, Color("#ffb347"), 40, 200.0, "confetti", true)
	fever_target = 1.0
	_count("fever")

func set_fever(active: bool) -> void:
	fever_target = 1.0 if active else 0.0
