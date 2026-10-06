extends Node2D
## Draws the FX director's state in screen space (480x270).
##
## Two instances are used: a "back" canvas between the world and the HUD
## (darkening, letterbox, speed lines, danger edge) and a "front" canvas above
## the HUD (cut-ins, particles, text pops, cracks, flash, FEVER frame).

const FxDirector = preload("res://fx/fx_director.gd")

var director: FxDirector
var layer_kind := "front"

const W := 480.0
const H := 270.0

# The angler's five faces, in order of excitement.  A face that fails to load
# simply is not drawn, so missing art never stops a battle.
var portraits: Array[Texture2D] = []

func _ready() -> void:
	# Painted portraits are scaled down a lot; smooth filtering keeps them from
	# shimmering.  Everything else this canvas draws is lines and polygons.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portraits.clear()
	for n in range(1, FxDirector.PORTRAIT_FACES + 1):
		var path := "res://assets/portraits/angler_%d.png" % n
		portraits.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)

func _draw() -> void:
	if director == null: return
	if layer_kind == "back": _draw_back()
	else: _draw_front()

func heat_color(heat: int, phase: float = 0.0) -> Color:
	if heat == 3: return Color.from_hsv(fmod(director.time * 0.35 + phase, 1.0), 0.65, 1.0)
	return director.HEAT_COLORS[clampi(heat, 0, director.HEAT_COLORS.size() - 1)]

# ---- back ------------------------------------------------------------------

func _draw_back() -> void:
	var d: FxDirector = director
	# The gacha backdrop is on this layer on purpose: the result card and every
	# HUD panel are drawn above it, so it can fill the screen and still never
	# cover anything the player reads.
	if not d.gacha.is_empty(): _draw_gacha_back()
	if d.dim > 0.01:
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.06, d.dim))
	if d.vignette > 0.01:
		# Stepped bands read as deliberate pixel art and stay cheap.
		for i in range(8):
			var inset := float(i) * 9.0
			var a := d.vignette * 0.11 * (1.0 - float(i) / 8.0)
			_frame(Rect2(inset, inset * 0.6, W - inset * 2.0, H - inset * 1.2), 9.0, Color(d.vignette_color, a))
	if d.speed > 0.02:
		var n := 40
		for i in range(n):
			var a := float(i) * TAU / float(n) + d.time * 0.25 + sin(float(i) * 12.9) * 0.06
			var inner := 120.0 - d.speed * 40.0 + fmod(d.time * 260.0 + float(i) * 37.0, 60.0)
			var start: Vector2 = d.CENTER + Vector2(cos(a), sin(a)) * inner
			var end: Vector2 = d.CENTER + Vector2(cos(a), sin(a)) * 360.0
			var col := heat_color(d.speed_heat, float(i) / float(n))
			if d.speed_heat < 3: col = col.lerp(Color.WHITE, 0.35)
			draw_line(start, end, Color(col, 0.16 + d.speed * 0.34), 1.0 + d.speed * 2.0)
	if d.danger > 0.01:
		var pulse := 1.0 if d.reduced else 0.6 + 0.4 * sin(d.time * TAU * 1.3)
		var a := d.danger * 0.32 * pulse
		for i in range(4):
			_frame(Rect2(float(i) * 6.0, float(i) * 6.0, W - float(i) * 12.0, H - float(i) * 12.0), 6.0, Color(0.85, 0.08, 0.1, a * (1.0 - float(i) / 4.0)))
	if d.letterbox > 0.01:
		var bar := 24.0 * _ease_out(d.letterbox)
		draw_rect(Rect2(0, 0, W, bar), Color(0, 0, 0, 0.92))
		draw_rect(Rect2(0, H - bar, W, bar), Color(0, 0, 0, 0.92))
		var edge := heat_color(d.speed_heat)
		draw_line(Vector2(0, bar), Vector2(W, bar), Color(edge, 0.8), 1.0)
		draw_line(Vector2(0, H - bar), Vector2(W, H - bar), Color(edge, 0.8), 1.0)

# ---- front -----------------------------------------------------------------

func _draw_front() -> void:
	var d: FxDirector = director
	if not d.school.is_empty(): _draw_school(d.school)
	if not d.golden.is_empty(): _draw_golden(d.golden)
	if d.crack_t >= 0.0: _draw_cracks()
	for s in d.shards: _draw_shard(s)
	if d.card_active or not d.card_break.is_empty(): _draw_streak_card()
	if d.portrait_visible(): _draw_portrait()
	if not d.gacha.is_empty() and float(d.gacha.flip_t) < 0.2: _draw_gacha_style()
	if not d.gacha.is_empty() and float(d.gacha.flip_t) >= 0.0: _draw_gacha_stars()
	for p in d.particles: _draw_particle(p)
	for i in d.impacts: _draw_impact(i)
	for c in d.cutins: _draw_cutin(c)
	for p in d.pops: _draw_pop(p)
	if d.fever_border > 0.01: _draw_fever_border(d.fever_border)
	var fa: float = d.current_flash_alpha()
	if fa > 0.005:
		draw_rect(Rect2(0, 0, W, H), Color(d.flash_color, fa))

func _draw_particle(p: Dictionary) -> void:
	var life: float = clampf(float(p.life) / maxf(0.01, float(p.max)), 0.0, 1.0)
	var col: Color = p.color
	var pos: Vector2 = p.pos
	var sz: float = float(p.size)
	match str(p.kind):
		"coin":
			var w := absf(cos(float(p.rot))) * sz + 0.6
			draw_rect(Rect2(pos - Vector2(w, sz), Vector2(w * 2.0, sz * 2.0)), Color(col, minf(1.0, life * 2.0)))
			draw_rect(Rect2(pos - Vector2(w * 0.4, sz * 0.6), Vector2(w * 0.8, sz * 0.5)), Color(1, 1, 0.85, life))
		"confetti":
			var w2 := absf(cos(float(p.rot))) * sz
			draw_rect(Rect2(pos - Vector2(w2, sz * 0.5), Vector2(maxf(0.8, w2 * 2.0), sz)), Color(col, minf(1.0, life * 1.6)))
		"drop":
			draw_rect(Rect2(pos - Vector2(sz * 0.5, sz), Vector2(sz, sz * 2.0)), Color(col, life))
		"ash":
			draw_rect(Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(col, life * 0.8))
		"star":
			var a_star := minf(1.0, life * 2.2)
			draw_colored_polygon(_star(pos, sz + 1.2, (sz + 1.2) * 0.45, 5, float(p.rot)), Color(0.05, 0.04, 0.1, a_star * 0.7))
			draw_colored_polygon(_star(pos, sz, sz * 0.42, 5, float(p.rot)), Color(col, a_star))
		"gem":
			var a_gem := minf(1.0, life * 2.2)
			var gem := PackedVector2Array([pos + Vector2(0, -sz), pos + Vector2(sz * 0.75, -sz * 0.15), pos + Vector2(0, sz), pos + Vector2(-sz * 0.75, -sz * 0.15)])
			draw_colored_polygon(gem, Color(col, a_gem))
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -sz), pos + Vector2(sz * 0.75, -sz * 0.15), pos + Vector2(0, -sz * 0.05)]), Color(1, 1, 1, a_gem * 0.75))
		"note":
			var a_note := minf(1.0, life * 2.2)
			draw_line(pos + Vector2(sz * 0.45, 0), pos + Vector2(sz * 0.45, -sz * 2.0), Color(col, a_note), 1.0)
			draw_line(pos + Vector2(sz * 0.45, -sz * 2.0), pos + Vector2(sz * 1.3, -sz * 1.5), Color(col, a_note), 2.0)
			draw_circle(pos, sz * 0.55, Color(col, a_note))
		_:
			draw_rect(Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(col, life))
			if sz > 1.8 and life > 0.5:
				draw_line(pos - Vector2(sz * 1.8, 0), pos + Vector2(sz * 1.8, 0), Color(1, 1, 0.9, life * 0.7), 1.0)
				draw_line(pos - Vector2(0, sz * 1.8), pos + Vector2(0, sz * 1.8), Color(1, 1, 0.9, life * 0.7), 1.0)

# ---- pull impacts ----------------------------------------------------------

func _impact_color(tier: int, phase: float = 0.0) -> Color:
	match tier:
		0: return Color("#ff5a4a")
		1: return Color("#8fe6d2")
		2: return Color("#ffd44a")
		3: return Color("#fff0a8")
		_: return Color.from_hsv(fmod(director.time * 0.9 + phase, 1.0), 0.6, 1.0)

func _impact_label(i: Dictionary) -> String:
	match int(i.tier):
		0: return "STRAIN!"
		1: return "GOOD!"
		2: return "PERFECT!!"
		# The look stops climbing at the top tier, but the count keeps going: a
		# fourth and fifth PERFECT in a row read x4 and x5.
		_: return "PERFECT x%d!!" % int(i.streak)

func _draw_impact(i: Dictionary) -> void:
	var d: FxDirector = director
	var tier := int(i.tier)
	var t := float(i.t)
	var p := clampf(t / float(i.dur), 0.0, 1.0)
	var fade := 1.0 - p
	var pos: Vector2 = i.pos
	# Reduced flashing keeps every shape but dims it; the full-screen wash below
	# goes through soft_overlay() and disappears entirely.
	var k := 0.45 if d.reduced else 1.0
	var col := _impact_color(tier)
	var r := RandomNumberGenerator.new()
	r.seed = int(i.seed)
	# Screen-edge frame: thick on the hit, gone by the end.
	var frame_w := float([12, 6, 12, 16, 20][tier]) * fade + 1.0
	var frame_a := float([0.6, 0.4, 0.65, 0.75, 0.85][tier]) * fade * k
	for band in range(3):
		var inset := float(band) * frame_w * 0.5
		var band_w := frame_w * 0.5
		var band_a := frame_a * (1.0 - float(band) / 3.0)
		var r_band := Rect2(inset, inset, W - inset * 2.0, H - inset * 2.0)
		if tier >= 4:
			# The top tier wraps the screen in four hues at once, so it reads as
			# a rainbow on any single frame rather than one colour at a time.
			draw_rect(Rect2(r_band.position, Vector2(r_band.size.x, band_w)), Color(_impact_color(tier, 0.0), band_a))
			draw_rect(Rect2(r_band.position + Vector2(r_band.size.x - band_w, band_w), Vector2(band_w, r_band.size.y - band_w * 2.0)), Color(_impact_color(tier, 0.25), band_a))
			draw_rect(Rect2(r_band.position + Vector2(0, r_band.size.y - band_w), Vector2(r_band.size.x, band_w)), Color(_impact_color(tier, 0.5), band_a))
			draw_rect(Rect2(r_band.position + Vector2(0, band_w), Vector2(band_w, r_band.size.y - band_w * 2.0)), Color(_impact_color(tier, 0.75), band_a))
		else:
			_frame(r_band, band_w, Color(col, band_a))
	if tier == 0:
		# A strained line tears across the screen instead of bursting outward.
		for j in range(6):
			var y := r.randf_range(20.0, H - 20.0)
			var tear := r.randf_range(-10.0, 10.0)
			var x0 := r.randf_range(0.0, W * 0.4) * p
			draw_line(Vector2(x0, y), Vector2(W - r.randf_range(0.0, W * 0.3) * p, y + tear), Color(col, 0.7 * fade * k), 1.0 + r.randf() * 1.5)
	else:
		# Shock rings from the float. A GOOD ring stays local; a PERFECT ring
		# crosses the whole screen, and a streak adds more of them.
		var reach := float([0, 170, 560, 560, 560][tier])
		for ring in range(maxi(1, tier - 1)):
			var rp := clampf((t - float(ring) * 0.07) / float(i.dur), 0.0, 1.0)
			if rp <= 0.0: continue
			draw_arc(pos, _ease_out(rp) * reach, 0, TAU, 56, Color(_impact_color(tier, float(ring) * 0.33), 0.7 * (1.0 - rp) * k), float([0, 2, 3, 3, 4][tier]))
		# Rays fly out past the ring toward the screen edges.
		var rays := int([0, 14, 22, 30, 38][tier])
		for j in range(rays):
			var a := float(j) * TAU / float(rays) + r.randf_range(-0.08, 0.08)
			var dir := Vector2(cos(a), sin(a))
			var length := (40.0 + r.randf() * 140.0) * (0.4 if tier == 1 else 0.6 + float(tier) * 0.2)
			var r0 := 14.0 + _ease_out(p) * (60.0 + r.randf() * (60.0 if tier == 1 else 220.0) + float(tier) * 40.0)
			# Neighbouring rays take scattered hues: the float is often near a
			# screen edge, where only a narrow fan of rays is in view.
			var ray_col := _impact_color(tier, fmod(float(j) * 0.37, 1.0))
			draw_line(pos + dir * r0, pos + dir * (r0 + length * (1.0 - p * 0.5)), Color(ray_col, 0.55 * fade * k), 1.0 + (1.0 if tier >= 3 else 0.0) + r.randf())
		if tier >= 2:
			# The wash is a light, near-white lift even on the rainbow tier: a
			# strong or hue-cycling tint over the teal HUD reads as a green cast.
			draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.98, 0.9, d.soft_overlay(0.04 * float(tier - 1) * fade * fade)))
	# The grade slams into the bottom lane (see IMPACT_LANE_TOP). The slam is a
	# purely sideways stretch and the word is level, so its height never changes
	# and it is inside the lane on every frame, including the first.
	var size := _impact_text_size(tier)
	var slam := 1.0 + float(IMPACT_SLAM[tier]) * (1.0 - _ease_out(clampf(t / 0.12, 0.0, 1.0)))
	var alpha := 1.0 - clampf((t - float(i.dur) * 0.7) / (float(i.dur) * 0.3), 0.0, 1.0)
	var rot := float(IMPACT_TEXT_ROT[tier])
	var text_pos: Vector2 = d.IMPACT_TEXT_POS
	if tier == 0: text_pos += Vector2(sin(d.time * 90.0), cos(d.time * 77.0)) * 2.0 * fade
	# A slanted band behind the word, like a cut-in that lasts one beat. Every
	# grade gets one: the lane lies over the toast bar, whose text would
	# otherwise show through the letters.
	var rows := _impact_band(tier)
	var top := rows.position.y
	var bottom := rows.end.y
	var skew := 14.0
	var band_poly := PackedVector2Array([Vector2(-20 + skew, top), Vector2(W + 20 + skew, top), Vector2(W + 20 - skew, bottom), Vector2(-20 - skew, bottom)])
	draw_colored_polygon(band_poly, Color(0.04, 0.03, 0.09, (0.82 if tier >= 2 else 0.9) * alpha))
	draw_line(band_poly[0], band_poly[1], Color(col, (0.9 if tier >= 2 else 0.5) * alpha), 2.0 if tier >= 2 else 1.0)
	draw_line(band_poly[3], band_poly[2], Color(col, (0.9 if tier >= 2 else 0.5) * alpha), 2.0 if tier >= 2 else 1.0)
	if tier >= 2:
		for j in range(8):
			var sx := fmod(float(j) * 71.0 + t * 1100.0, W + 100.0) - 50.0
			var sy := top + 4.0 + fmod(float(j) * 11.0, rows.size.y - 8.0)
			draw_line(Vector2(sx, sy), Vector2(sx + 30.0, sy), Color(1, 1, 1, 0.3 * alpha), 1.0)
	_text_center(_impact_label(i), text_pos, size, Color(col, alpha), slam, rot, tier >= 4, IMPACT_SLAM_TALL)
	_draw_emblem(i)
	if bool(i.clean):
		# Beside the grade, at the right end of the lane. It waits for the slam
		# to settle, because the stretched word reaches this far at first.
		var clean_alpha := alpha * clampf((t - 0.09) / 0.06, 0.0, 1.0)
		_text_center("CLEAN BEAT", Vector2(W - 64.0, text_pos.y - 4.0), 8, Color(0.82, 0.8, 1.0, clean_alpha), 1.0, 0.0, false)

# How the grade arrives: extra horizontal scale at the first frame per tier, how
# much of that scale also applies vertically, and the word's tilt. Height and
# tilt are both zero so the lane holds; _impact_text_top() is what tests check.
const IMPACT_SLAM := [0.5, 0.35, 1.0, 1.3, 1.6]
const IMPACT_SLAM_TALL := 0.0
const IMPACT_TEXT_ROT := [0.0, 0.0, 0.0, 0.0, 0.0]
# Capital letters reach about this share of the font size above the baseline.
const IMPACT_CAP_HEIGHT := 0.74
# _text_center() outlines glyphs 5px wide, so 2.5px beyond the ink.
const IMPACT_OUTLINE := 2.5

# The highest point the grade text can reach at any moment of its slam: the
# stretched, tilted word's upper corner plus its outline.
func _impact_text_top(tier: int, label: String) -> float:
	var size := _impact_text_size(tier)
	var peak := 1.0 + float(IMPACT_SLAM[tier])
	var height := float(size) * IMPACT_CAP_HEIGHT * (1.0 + (peak - 1.0) * IMPACT_SLAM_TALL)
	var half_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5 * peak
	var lift := absf(sin(float(IMPACT_TEXT_ROT[tier]))) * half_width
	return float(director.IMPACT_TEXT_POS.y) - height - lift - IMPACT_OUTLINE

# ---- the gacha reveal --------------------------------------------------------

func _gacha_color(heat: int, phase: float = 0.0) -> Color:
	if heat >= 3: return Color.from_hsv(fmod(director.time * 0.3 + phase, 1.0), 0.6, 1.0)
	return director.HEAT_COLORS[clampi(heat, 0, 2)]

func _draw_gacha_back() -> void:
	var d: FxDirector = director
	var g: Dictionary = d.gacha
	var t := float(g.t)
	var heat := int(g.heat)
	var flip_t := float(g.flip_t)
	var flipped := flip_t >= 0.0
	var charge := 0.0
	if float(g.charge_t) >= 0.0: charge = clampf(float(g.charge_t) / float(g.charge_dur), 0.0, 1.0)
	var k := 0.5 if d.reduced else 1.0
	var c: Vector2 = d.CARD_CENTER
	# Summon rays turn behind the card, brightening through the charge.  After
	# the turn they flare, then settle: a rare catch keeps a slow halo while the
	# card waits, a common one lets it go.
	var ray_a := 0.14 + 0.26 * charge
	if flipped:
		var settle := float([0.0, 0.05, 0.14, 0.2][clampi(heat, 0, 3)])
		ray_a = lerpf(0.5 + 0.06 * float(heat), settle, clampf(flip_t / 1.4, 0.0, 1.0))
	ray_a *= clampf(t / 0.2, 0.0, 1.0) * k
	if ray_a > 0.004:
		var rays := 16
		var spin := d.time * (0.25 + 0.5 * charge)
		for i in range(rays):
			var a0 := spin + float(i) * TAU / float(rays)
			var a1 := a0 + TAU / float(rays) * 0.45
			draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 520.0, c + Vector2(cos(a1), sin(a1)) * 520.0]), Color(_gacha_color(heat, float(i) / float(rays)), ray_a))
	# Fireworks after the turn, across the whole screen.
	if flipped:
		for show in g.fireworks:
			var age := flip_t - float(show.at)
			if age <= 0.0 or age >= d.GACHA_FIREWORK_LIFE: continue
			var fp := age / d.GACHA_FIREWORK_LIFE
			var centre: Vector2 = show.pos
			var radius := float(show.size) * _ease_out(fp * 1.5)
			var fade := (1.0 - fp) * k
			var fr := RandomNumberGenerator.new()
			fr.seed = int(show.seed)
			var petals := 18
			for i in range(petals):
				var a2 := float(i) * TAU / float(petals) + fr.randf() * 0.2
				var reach := radius * (0.8 + fr.randf() * 0.35)
				var tip := centre + Vector2(cos(a2), sin(a2)) * reach + Vector2(0, 16.0 * fp * fp)
				var hue := fmod(float(show.hue) + (float(i) / float(petals) if heat >= 3 or bool(g.festival) else fr.randf() * 0.08), 1.0)
				var col2 := Color.from_hsv(hue, 0.55, 1.0) if heat >= 3 or bool(g.festival) else _gacha_color(heat).lerp(Color.from_hsv(hue, 0.4, 1.0), 0.35)
				draw_line(centre.lerp(tip, 0.45), tip, Color(col2, 0.85 * fade), 2.5)
				draw_rect(Rect2(tip - Vector2(2, 2), Vector2(4, 4)), Color(col2.lightened(0.45), fade))
				# A shorter inner ring fills the flower in.
				draw_rect(Rect2(centre.lerp(tip, 0.5) - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.8 * fade))
			if fp < 0.3: draw_circle(centre, 9.0 * (1.0 - fp / 0.3), Color(1, 1, 1, 0.95 * k))


# The summon style and the charging orbs play over the whole screen, card
# included, while the card is still face-down and has nothing to read.  They
# are gone within a fifth of a second of the turn.
func _draw_gacha_style() -> void:
	var d: FxDirector = director
	var g: Dictionary = d.gacha
	var t := float(g.t)
	var heat := int(g.heat)
	var flip_t := float(g.flip_t)
	var flipped := flip_t >= 0.0
	var charge := 0.0
	if float(g.charge_t) >= 0.0: charge = clampf(float(g.charge_t) / float(g.charge_dur), 0.0, 1.0)
	var k := 0.5 if d.reduced else 1.0
	var c: Vector2 = d.CARD_CENTER
	var r := RandomNumberGenerator.new()
	r.seed = int(g.seed)
	var style_a := clampf(t / 0.15, 0.0, 1.0) * (1.0 - clampf(flip_t / 0.18, 0.0, 1.0) if flipped else 1.0) * k
	if style_a > 0.01:
		match str(g.style):
			"meteor":
				for i in range(16):
					var period := 0.5 + r.randf() * 0.35
					var p := fmod(t + r.randf() * period, period) / period
					var from := Vector2(r.randf_range(120.0, 620.0), -30.0)
					var head := from + Vector2(-230.0, 300.0) * p
					var tail := head - Vector2(-230.0, 300.0).normalized() * (26.0 + 20.0 * r.randf())
					var streak := _gacha_color(heat, r.randf())
					draw_line(tail, head, Color(streak, 0.4 * style_a), 5.0)
					draw_line(tail, head, Color(streak.lightened(0.5), 0.9 * style_a * (1.0 - p * 0.4)), 2.0)
					draw_circle(head, 3.0, Color(1, 1, 1, style_a))
			"bubble":
				for i in range(34):
					var period2 := 1.1 + r.randf() * 0.9
					var p2 := fmod(t + r.randf() * period2, period2) / period2
					var x := r.randf_range(8.0, W - 8.0) + sin(t * 3.0 + float(i)) * 6.0
					var y := H + 10.0 - p2 * (H + 30.0)
					var rad := 4.0 + r.randf() * 9.0
					draw_arc(Vector2(x, y), rad, 0, TAU, 14, Color(_gacha_color(heat, r.randf()).lightened(0.35), 0.9 * style_a), 2.0)
					draw_circle(Vector2(x - rad * 0.3, y - rad * 0.3), rad * 0.22, Color(1, 1, 1, 0.8 * style_a))
			"thunder":
				# Bolts strike toward the card and fade smoothly: no strobing.
				for i in range(4):
					var period3 := 0.62
					var p3 := fmod(t + float(i) * 0.17, period3) / period3
					var bolt_a := (1.0 - p3) * (1.0 - p3) * style_a
					var strike := int((t + float(i) * 0.17) / period3)
					var br := RandomNumberGenerator.new()
					br.seed = int(g.seed) + i * 131 + strike * 977
					var x0 := br.randf_range(30.0, W - 30.0)
					var pts := PackedVector2Array([Vector2(x0, 0.0)])
					var target := Vector2(c.x + br.randf_range(-150.0, 150.0), c.y + br.randf_range(-30.0, 60.0))
					for seg in range(1, 7):
						var q := Vector2(x0, 0.0).lerp(target, float(seg) / 6.0)
						if seg < 6: q.x += br.randf_range(-16.0, 16.0)
						pts.append(q)
					draw_polyline(pts, Color(_gacha_color(heat, float(i) * 0.2), 0.5 * bolt_a), 7.0)
					draw_polyline(pts, Color(1, 1, 1, 0.95 * bolt_a), 2.0)
			"wave":
				for band in range(5):
					var pts2 := PackedVector2Array()
					var base_y := H - 22.0 - float(band) * 34.0 - 30.0 * charge
					for step in range(25):
						var x2 := float(step) / 24.0 * W
						pts2.append(Vector2(x2, base_y + sin(x2 * 0.035 + t * (3.0 + float(band)) + float(band)) * (7.0 + 3.0 * float(band))))
					draw_polyline(pts2, Color(_gacha_color(heat, float(band) * 0.15).lightened(0.2), (0.7 - float(band) * 0.1) * style_a), 3.0 - float(band) * 0.4)
	# Orbs spiral in to the card through the charge.
	if charge > 0.0 and not flipped:
		var orbs := 10 + heat * 5
		for i in range(orbs):
			var a := float(i) * TAU / float(orbs) + charge * 5.0 + r.randf() * 0.4
			var dist := lerpf(300.0, 14.0, charge * charge) * (0.85 + r.randf() * 0.3)
			var pos := c + Vector2(cos(a), sin(a) * 0.62) * dist
			var col := _gacha_color(heat, float(i) / float(orbs))
			draw_circle(pos, 7.0, Color(col, 0.35 * k))
			draw_circle(pos, 3.2, Color(col.lightened(0.5), 0.95 * k))
			draw_line(pos, pos - Vector2(-sin(a), cos(a) * 0.62) * 16.0, Color(col, 0.6 * k), 2.0)

# The star rating counts up after the card turns: one star per rarity step,
# each slamming into its slot, with a ring off the last one.
func _draw_gacha_stars() -> void:
	var d: FxDirector = director
	var g: Dictionary = d.gacha
	var flip_t := float(g.flip_t)
	var total := int(g.stars)
	var shown: int = d.gacha_stars_shown()
	var r: Rect2 = d.GACHA_STARS_RECT
	var appear := clampf(flip_t / 0.12, 0.0, 1.0)
	draw_rect(r.grow(3.0), Color(0.05, 0.07, 0.13, 0.78 * appear))
	draw_rect(r.grow(2.0), Color(_gacha_color(int(g.rank)), 0.8 * appear), false, 1.0)
	for slot in range(d.GACHA_STAR_SLOTS):
		var c: Vector2 = d.gacha_star_pos(slot)
		if slot >= shown:
			draw_colored_polygon(_star(c, 8.0, 3.4, 5), Color(0.5, 0.56, 0.6, 0.32 * appear))
			continue
		var landed_at: float = d.GACHA_STAR_FIRST + float(slot) * d.GACHA_STAR_GAP
		var age := flip_t - landed_at
		var slam := 1.0 + 1.6 * (1.0 - _ease_out(clampf(age / 0.13, 0.0, 1.0)))
		var col := Color("#ffd23a") if total < 4 else Color.from_hsv(fmod(director.time * 0.5 + float(slot) * 0.16, 1.0), 0.5, 1.0)
		draw_colored_polygon(_star(c, 11.0 * slam, 4.7 * slam, 5), Color(0.05, 0.04, 0.1, 0.95))
		draw_colored_polygon(_star(c, 9.0 * slam, 3.8 * slam, 5), col)
		draw_colored_polygon(_star(c + Vector2(-1.2, -1.2), 3.4 * slam, 1.4 * slam, 5), Color(1, 1, 1, 0.6))
		if slot == total - 1 and age < 0.4:
			var ring := age / 0.4
			draw_arc(c, 9.0 + ring * 22.0, 0, TAU, 24, Color(col, (1.0 - ring) * 0.9), 2.0)

# ---- emblems and the streak card -------------------------------------------

func _star(center: Vector2, outer: float, inner: float, points: int, rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(points * 2):
		var a := rot - PI * 0.5 + float(k) * PI / float(points)
		out.append(center + Vector2(cos(a), sin(a)) * (outer if k % 2 == 0 else inner))
	return out

func _ease_out_back(x: float) -> float:
	var c := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * c * c * c + 1.70158 * c * c

# The word on an emblem's ribbon, by emblem level (see emblem_level()).
const EMBLEM_WORDS := ["OUCH", "OK!", "GREAT", "SUPER", "HYPER", "ULTRA", "KING!"]

func _emblem_word(level: int) -> String:
	return str(EMBLEM_WORDS[clampi(level, 0, EMBLEM_WORDS.size() - 1)])

func _emblem_color(level: int, phase: float = 0.0) -> Color:
	match level:
		0: return Color("#e0473c")
		1: return Color("#3fbfa8")
		2: return Color("#ffc93c")
		3: return Color("#ff9d2e")
		_: return Color.from_hsv(fmod(director.time * 0.8 + phase, 1.0), 0.62, 1.0)

# A badge for the pull, drawn in the margin right of the fishing panel.  It pops
# in with an overshoot, and each level adds a part: a check for GOOD; a star on
# a burst for PERFECT; then orbiting stars, a crown, wings, and for the fifth
# PERFECT in a row a fish leaping over the crown inside a rainbow halo.
func _draw_emblem(i: Dictionary) -> void:
	var d: FxDirector = director
	var level: int = d.emblem_level(int(i.tier), int(i.streak))
	var t := float(i.t)
	var alpha := (1.0 - clampf((t - float(i.dur) * 0.7) / (float(i.dur) * 0.3), 0.0, 1.0)) * (0.6 if d.reduced else 1.0)
	var pop_in := _ease_out_back(t / 0.16)
	# On its first frame the badge has almost no size, and its ribbon folds over
	# itself below about a tenth of full size; such a polygon cannot be drawn.
	if pop_in < 0.12: return
	var c: Vector2 = d.IMPACT_EMBLEM_POS
	var unit: float = d.IMPACT_EMBLEM_RADIUS / 44.0 * pop_in
	var ink := Color(0.05, 0.04, 0.1, alpha)
	var col := _emblem_color(level)
	var spin := d.time * 1.4
	if level >= 6:
		# Rainbow halo: long rays turning behind everything else.
		for k in range(16):
			var a := spin * 0.6 + float(k) * TAU / 16.0
			draw_line(c + Vector2(cos(a), sin(a)) * 18.0 * unit, c + Vector2(cos(a), sin(a)) * 43.0 * unit, Color(_emblem_color(level, float(k) / 16.0), 0.75 * alpha), 3.0)
	if level >= 5:
		# Wings: three feathers a side.
		for side in [-1.0, 1.0]:
			for f in range(3):
				var lift := -0.25 - float(f) * 0.42
				var tip := c + Vector2(side * cos(lift), sin(lift)) * (40.0 - float(f) * 3.0) * unit
				var root_a := c + Vector2(side * 14.0, 4.0 - float(f) * 6.0) * unit
				var root_b := c + Vector2(side * 14.0, -4.0 - float(f) * 6.0) * unit
				draw_colored_polygon(PackedVector2Array([root_a, tip, root_b]), Color(1.0, 0.98, 0.9, alpha))
				draw_polyline(PackedVector2Array([root_a, tip, root_b]), ink, 1.0)
	if level == 0:
		# A cracked red badge with a cross.
		draw_colored_polygon(_star(c, 26.0 * unit, 21.0 * unit, 9, 0.2), ink)
		draw_colored_polygon(_star(c, 23.0 * unit, 18.5 * unit, 9, 0.2), Color(col, alpha))
		for s in [-1.0, 1.0]:
			draw_line(c + Vector2(-10.0, -10.0 * s) * unit, c + Vector2(10.0, 10.0 * s) * unit, ink, 7.0 * unit)
			draw_line(c + Vector2(-10.0, -10.0 * s) * unit, c + Vector2(10.0, 10.0 * s) * unit, Color(1, 1, 1, alpha), 4.0 * unit)
	elif level == 1:
		# A round teal badge with a tick.
		draw_circle(c, 25.0 * unit, ink)
		draw_circle(c, 22.5 * unit, Color(col, alpha))
		draw_arc(c, 18.5 * unit, 0, TAU, 32, Color(1, 1, 1, 0.75 * alpha), 1.5)
		var tick := PackedVector2Array([c + Vector2(-10, 0) * unit, c + Vector2(-3, 8) * unit, c + Vector2(11, -8) * unit])
		draw_polyline(tick, ink, 7.0 * unit)
		draw_polyline(tick, Color(1, 1, 1, alpha), 4.0 * unit)
	else:
		# PERFECT: a spinning burst, a second one behind it from the second
		# pull on, and a white star (or the leaping fish) in the middle.
		if level >= 3:
			draw_colored_polygon(_star(c, 34.0 * unit, 24.0 * unit, 12, -spin * 0.7), Color(_emblem_color(level, 0.35), alpha))
		draw_colored_polygon(_star(c, 31.0 * unit, 22.0 * unit, 12, spin), ink)
		draw_colored_polygon(_star(c, 28.5 * unit, 20.5 * unit, 12, spin), Color(col, alpha))
		draw_circle(c, 17.0 * unit, Color(1.0, 0.97, 0.82, alpha))
		draw_arc(c, 17.0 * unit, 0, TAU, 32, ink, 1.5)
		if level >= 6:
			# The fish: body, tail and eye, tilted as if clearing the crown.
			var tilt := -0.35
			var body := PackedVector2Array()
			for q in [Vector2(-13, 0), Vector2(-5, -7), Vector2(7, -6), Vector2(14, 0), Vector2(7, 6), Vector2(-5, 7)]:
				body.append(c + Vector2(0, 1) * unit + q.rotated(tilt) * unit)
			var tail := PackedVector2Array()
			for q in [Vector2(-11, 0), Vector2(-19, -7), Vector2(-19, 7)]:
				tail.append(c + Vector2(0, 1) * unit + q.rotated(tilt) * unit)
			draw_colored_polygon(tail, Color("#2b7fd1", alpha))
			draw_colored_polygon(body, Color("#3fa0ee", alpha))
			var body_line := body.duplicate(); body_line.append(body[0])
			draw_polyline(body_line, ink, 1.5)
			draw_circle(c + Vector2(0, 1) * unit + Vector2(8, -2).rotated(tilt) * unit, 1.8 * unit, ink)
		else:
			draw_colored_polygon(_star(c, 14.5 * unit, 6.2 * unit, 5), ink)
			draw_colored_polygon(_star(c, 12.0 * unit, 5.0 * unit, 5), Color(col.lerp(Color("#ff7a00"), 0.25), alpha))
		if level >= 3:
			# Small stars in orbit: two, then one more per level.
			var orbit := level - 1
			for k in range(orbit):
				var a2 := -spin * 1.8 + float(k) * TAU / float(orbit)
				var sp := c + Vector2(cos(a2), sin(a2) * 0.8) * 37.0 * unit
				draw_colored_polygon(_star(sp, 5.5 * unit, 2.3 * unit, 5, a2), ink)
				draw_colored_polygon(_star(sp, 4.2 * unit, 1.8 * unit, 5, a2), Color(1.0, 0.95, 0.6, alpha))
		if level >= 4:
			# The crown sits on top of the badge.
			var base := c + Vector2(0, -24) * unit
			var crown := PackedVector2Array()
			for q in [Vector2(-13, 6), Vector2(-14, -6), Vector2(-7, 0), Vector2(0, -10), Vector2(7, 0), Vector2(14, -6), Vector2(13, 6)]:
				crown.append(base + q * unit)
			draw_colored_polygon(crown, Color("#ffd23a", alpha))
			var crown_line := crown.duplicate(); crown_line.append(crown[0])
			draw_polyline(crown_line, ink, 1.5)
			for q in [Vector2(-14, -6), Vector2(0, -10), Vector2(14, -6)]:
				draw_circle(base + q * unit, 2.2 * unit, Color("#ff5a8a", alpha))
	# A shine sweeps across the badge once as it lands.
	var sweep := clampf((t - 0.1) / 0.22, 0.0, 1.0)
	if sweep > 0.0 and sweep < 1.0 and level >= 1:
		var sx := c.x + (sweep * 2.0 - 1.0) * 26.0 * unit
		draw_line(Vector2(sx - 5.0, c.y + 20.0 * unit), Vector2(sx + 5.0, c.y - 20.0 * unit), Color(1, 1, 1, 0.55 * alpha), 3.0)
	# Ribbon with the rank word under the badge.
	var word := _emblem_word(level)
	var rib := c + Vector2(0, 34) * unit
	var half := 27.0 * unit
	var ribbon := PackedVector2Array([rib + Vector2(-half - 6, -7), rib + Vector2(half + 6, -7), rib + Vector2(half, 0), rib + Vector2(half + 6, 7), rib + Vector2(-half - 6, 7), rib + Vector2(-half, 0)])
	draw_colored_polygon(ribbon, ink)
	draw_colored_polygon(PackedVector2Array([rib + Vector2(-half - 3, -5), rib + Vector2(half + 3, -5), rib + Vector2(half - 2, 0), rib + Vector2(half + 3, 5), rib + Vector2(-half - 3, 5), rib + Vector2(-half + 2, 0)]), Color(col.darkened(0.25) if level < 4 else Color("#7a2fb8"), alpha))
	_text_center(word, rib + Vector2(0, 4), 10, Color(1, 1, 1, alpha), 1.0, 0.0, level >= 6)

# The angler's portrait, in the margin under the emblem.  It punches in whenever
# his face changes, gets a hotter frame as the streak grows, and shakes and
# dims for a moment when the streak breaks.
func _draw_portrait() -> void:
	var d: FxDirector = director
	var face: int = d.portrait_face()
	if face < 1 or face > portraits.size(): return
	var tex: Texture2D = portraits[face - 1]
	if tex == null: return
	var r: Rect2 = d.PORTRAIT_RECT
	var broke := not d.card_break.is_empty()
	var held := not d.portrait_hold.is_empty()
	var alpha := 1.0
	if held: alpha = 1.0 - clampf((float(d.portrait_hold.t) - d.PORTRAIT_HOLD * 0.75) / (d.PORTRAIT_HOLD * 0.25), 0.0, 1.0)
	var punch := 1.0 + (0.16 + 0.05 * float(face)) * (1.0 - _ease_out(clampf(d.portrait_change_t / 0.18, 0.0, 1.0)))
	if broke: punch = 1.0
	var centre := r.get_center()
	if broke:
		var jolt := 1.0 - float(d.card_break.t) / d.STREAK_CARD_BREAK_TIME
		centre.x += sin(d.time * 70.0) * 3.0 * jolt
	var size := r.size * punch
	var box := Rect2(centre - size * 0.5, size)
	var frame_col := Color("#8ba79b") if face <= 1 else _emblem_color(face, 0.2)
	if face >= 4 and not broke:
		# Excitement lines burst out from behind the frame.
		var rr := RandomNumberGenerator.new()
		rr.seed = face
		for k in range(14):
			var a := float(k) * TAU / 14.0 + sin(d.time * 6.0 + float(k)) * 0.05
			var inner := size.x * 0.62
			var outer := inner + 7.0 + rr.randf() * 9.0 + (4.0 if face >= 5 else 0.0)
			draw_line(centre + Vector2(cos(a), sin(a)) * inner, centre + Vector2(cos(a), sin(a)) * outer, Color(_emblem_color(face, float(k) / 14.0), 0.85 * alpha), 2.0)
	draw_rect(box.grow(3.0), Color(0.05, 0.04, 0.1, 0.9 * alpha))
	draw_texture_rect(tex, box, false, Color(1, 1, 1, alpha))
	if broke:
		var dim := 0.45 * (1.0 - float(d.card_break.t) / d.STREAK_CARD_BREAK_TIME)
		draw_rect(box, Color(0.1, 0.12, 0.25, dim))
	draw_rect(box.grow(1.5), Color(frame_col, alpha), false, 3.0 if face >= 3 else 2.0)
	if face >= 2 and d.portrait_change_t < 0.3 and not broke:
		# A ring off the frame on every step up.
		var ring := d.portrait_change_t / 0.3
		draw_rect(box.grow(2.0 + ring * 10.0), Color(frame_col, (1.0 - ring) * 0.8 * alpha), false, 2.0)

# The streak card in the left margin: five slots that fill from the bottom, one
# star per consecutive PERFECT.  The newest stamp slams in; a broken streak
# drops its stamps off the card.
func _draw_streak_card() -> void:
	var d: FxDirector = director
	var r: Rect2 = d.STREAK_CARD_RECT
	var k := 0.6 if d.reduced else 1.0
	var full := d.card_count >= d.STREAK_CARD_SLOTS
	draw_rect(r, Color(0.05, 0.07, 0.13, 0.72))
	var rim := _emblem_color(6) if full else Color("#8ba79b")
	draw_rect(r.grow(-1.0), Color(rim, 0.95 if full else 0.7), false, 2.0 if full else 1.0)
	_text_center("FULL!" if full else "STREAK", Vector2(r.get_center().x, r.position.y + 12.0), 8, Color("#fff0c6") if not full else _emblem_color(6, 0.3), 1.0, 0.0, false)
	for slot in range(d.STREAK_CARD_SLOTS):
		var c: Vector2 = d.streak_slot_pos(slot)
		draw_circle(c, 12.0, Color(0.02, 0.03, 0.07, 0.8))
		draw_arc(c, 12.0, 0, TAU, 24, Color(0.55, 0.65, 0.62, 0.55), 1.0)
		if slot >= d.card_count:
			_text_center(str(slot + 1), c + Vector2(0, 3), 8, Color(0.55, 0.65, 0.62, 0.6), 1.0, 0.0, false)
			continue
		var newest := slot == d.card_count - 1
		var slam := 1.0
		if newest: slam = 1.0 + 1.4 * (1.0 - _ease_out(clampf(d.card_stamp_t / 0.14, 0.0, 1.0)))
		var stamp_col := _emblem_color(slot + 2, float(slot) * 0.17)
		draw_colored_polygon(_star(c, 12.5 * slam, 5.4 * slam, 5), Color(0.05, 0.04, 0.1, 0.9))
		draw_colored_polygon(_star(c, 10.5 * slam, 4.4 * slam, 5), Color(stamp_col, k if not d.reduced else 0.85))
		draw_colored_polygon(_star(c + Vector2(-1.5, -1.5), 4.0 * slam, 1.7 * slam, 5), Color(1, 1, 1, 0.55))
		if newest and d.card_stamp_t < 0.3:
			# One ring off the fresh stamp.
			var ring := d.card_stamp_t / 0.3
			draw_arc(c, 10.0 + ring * 16.0, 0, TAU, 24, Color(stamp_col, (1.0 - ring) * 0.8 * k), 2.0)
	if not d.card_break.is_empty():
		# Knocked-off stamps tumble down and fade.
		var bt := float(d.card_break.t)
		var fade := 1.0 - bt / d.STREAK_CARD_BREAK_TIME
		for slot in range(int(d.card_break.count)):
			var from: Vector2 = d.streak_slot_pos(slot)
			var drift := Vector2((float(slot % 2) * 2.0 - 1.0) * 26.0 * bt, 150.0 * bt * bt - 20.0 * bt)
			draw_colored_polygon(_star(from + drift, 10.0, 4.2, 5, bt * 9.0 * (1.0 if slot % 2 == 0 else -1.0)), Color(0.6, 0.63, 0.7, fade * 0.9))

func _impact_text_size(tier: int) -> int:
	return int(director.IMPACT_TEXT_SIZES[clampi(tier, 0, director.IMPACT_TEXT_SIZES.size() - 1)])

# The rows the slanted band behind a grade occupies.
func _impact_band(tier: int) -> Rect2:
	var size := float(_impact_text_size(tier))
	var h := size + 4.0
	var cy: float = director.IMPACT_TEXT_POS.y - size * 0.36
	return Rect2(0, cy - h * 0.5, W, h)

func _cutin_colors(style: String) -> Array:
	match style:
		"hot": return [Color("#d6123b"), Color("#ffe066"), true]
		"premium": return [Color("#8a5a00"), Color("#fff2b0"), false]
		"reach_premium": return [Color("#7a5200"), Color("#ffe8a0"), false]
		"super": return [Color("#5a1a9a"), Color("#ffffff"), true]
		"reach": return [Color("#3b1f7a"), Color("#e7d6ff"), false]
		"fever": return [Color("#d0491a"), Color("#fff1c9"), true]
		"last": return [Color("#7a0f1c"), Color("#ffffff"), false]
		_: return [Color("#244a6a"), Color("#ffffff"), false]

func _draw_cutin(c: Dictionary) -> void:
	var t := float(c.t)
	var dur := float(c.dur)
	var style := str(c.style)
	var colors := _cutin_colors(style)
	var band: Color = colors[0]
	var ink: Color = colors[1]
	var rainbow: bool = colors[2]
	var slide_in := _ease_out(clampf(t / 0.16, 0.0, 1.0))
	var slide_out := clampf((t - (dur - 0.18)) / 0.18, 0.0, 1.0)
	var x := (1.0 - slide_in) * W - slide_out * slide_out * W
	var cy := float(c.get("y", 122.0))
	var h := float(c.get("h", 46.0))
	var skew := 26.0
	var poly := PackedVector2Array([Vector2(x - 40 + skew, cy - h * 0.5), Vector2(x + W + 40 + skew, cy - h * 0.5), Vector2(x + W + 40 - skew, cy + h * 0.5), Vector2(x - 40 - skew, cy + h * 0.5)])
	draw_colored_polygon(poly, Color(0, 0, 0, 0.55))
	var inner := PackedVector2Array([poly[0] + Vector2(0, 4), poly[1] + Vector2(0, 4), poly[2] - Vector2(0, 4), poly[3] - Vector2(0, 4)])
	draw_colored_polygon(inner, band)
	if rainbow:
		for i in range(7):
			var yy := cy - h * 0.5 + 4.0 + float(i) * ((h - 8.0) / 7.0)
			draw_line(Vector2(x - 60, yy), Vector2(x + W + 60, yy), Color.from_hsv(fmod(float(i) / 7.0 + director.time * 0.6, 1.0), 0.7, 1.0, 0.28), 2.0)
	# Streaks race across the band to sell the motion.
	for i in range(10):
		var sx := fmod(float(i) * 61.0 - t * 900.0, W + 120.0) + x - 60.0
		var sy := cy - h * 0.5 + 6.0 + fmod(float(i) * 13.0, h - 12.0)
		draw_line(Vector2(sx, sy), Vector2(sx + 34.0, sy), Color(1, 1, 1, 0.35), 1.0)
	draw_line(poly[0], poly[1], ink, 2.0)
	draw_line(poly[3], poly[2], ink, 2.0)
	var punch := 1.0 + 0.35 * (1.0 - clampf((t - 0.12) / 0.14, 0.0, 1.0))
	var text_x := x + W * 0.5
	var slim := h < 40.0
	var main_size := (20 if slim else 30) if str(c.text).length() <= 8 else (18 if slim else 24)
	_text_center(str(c.text), Vector2(text_x, cy + (5.0 if slim else 9.0)), main_size, ink, punch, -0.06, rainbow)
	if str(c.sub) != "" and not slim:
		_text_center(str(c.sub), Vector2(text_x, cy + 21.0), 8, Color(ink, 0.85), 1.0, 0.0, false)
	elif str(c.sub) != "":
		_text_center(str(c.sub), Vector2(text_x + 150.0, cy + 4.0), 8, Color(ink, 0.85), 1.0, 0.0, false)

func _draw_pop(p: Dictionary) -> void:
	var t := float(p.t)
	var dur := float(p.dur)
	var pos: Vector2 = p.pos
	var col: Color = p.color
	var alpha := 1.0 - clampf((t - dur * 0.65) / (dur * 0.35), 0.0, 1.0)
	var scale := 1.0
	var rot := 0.0
	match str(p.style):
		"slam":
			scale = 1.0 + 1.4 * (1.0 - _ease_out(clampf(t / 0.14, 0.0, 1.0)))
		"stamp":
			scale = 1.0 + 1.8 * (1.0 - _ease_out(clampf(t / 0.12, 0.0, 1.0)))
			rot = -0.14
			alpha = 1.0 - clampf((t - dur * 0.8) / (dur * 0.2), 0.0, 1.0)
		"drop":
			pos += Vector2(0, t * 18.0)
		_:
			var b := clampf(t / 0.3, 0.0, 1.0)
			pos += Vector2(0, -16.0 * b)
			scale = 1.0 + 0.45 * sin(clampf(t / 0.18, 0.0, 1.0) * PI)
	if str(p.style) == "stamp":
		var box := Rect2(-34, -16, 68, 22)
		draw_set_transform(pos, rot, Vector2(scale, scale))
		draw_rect(box, Color(0.05, 0.03, 0.1, 0.72 * alpha))
		draw_rect(box, Color(col, alpha), false, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text_center(str(p.text), pos, int(p.size), Color(col, alpha), scale, rot, false)

func _draw_school(s: Dictionary) -> void:
	var t := float(s.t) / float(s.dur)
	var count := 46
	var r := RandomNumberGenerator.new()
	r.seed = int(s.seed)
	for i in range(count):
		var lane := r.randf()
		var lag := r.randf() * 0.35
		var p := clampf((t - lag) / 0.65, 0.0, 1.0)
		if p <= 0.0 or p >= 1.0: continue
		var x := W + 30.0 - p * (W + 60.0)
		var y := 70.0 + lane * 150.0 + sin(p * TAU * 1.5 + lane * 9.0) * 10.0
		var col := Color.from_hsv(0.5 + lane * 0.12, 0.45, 1.0, 0.9)
		var sz := 1.0 + r.randf() * 0.9
		var body := PackedVector2Array([Vector2(x - 6 * sz, y), Vector2(x - 1 * sz, y - 3 * sz), Vector2(x + 5 * sz, y), Vector2(x - 1 * sz, y + 3 * sz)])
		draw_colored_polygon(body, col)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 4 * sz, y), Vector2(x + 9 * sz, y - 3 * sz), Vector2(x + 9 * sz, y + 3 * sz)]), col.darkened(0.2))
		draw_line(Vector2(x + 9 * sz, y), Vector2(x + 22 * sz, y), Color(col, 0.25), 1.0)

func _draw_golden(g: Dictionary) -> void:
	var t := float(g.t)
	var dur := float(g.dur)
	var p := clampf(t / dur, 0.0, 1.0)
	# A wide golden swell sweeps left to right, followed by a gull.
	var front := -80.0 + p * (W + 160.0)
	for i in range(6):
		var x0 := front - float(i) * 26.0
		var col := Color("#ffd44a").lerp(Color("#fff6cf"), float(i) / 6.0)
		col.a = 0.42 - float(i) * 0.06
		var pts := PackedVector2Array()
		for k in range(13):
			var yy := float(k) / 12.0 * H
			pts.append(Vector2(x0 + sin(yy * 0.05 + t * 6.0) * 10.0, yy))
		pts.append(Vector2(x0 - 30.0, H))
		pts.append(Vector2(x0 - 30.0, 0.0))
		draw_colored_polygon(pts, col)
	var gull := Vector2(-40.0 + p * (W + 80.0), 70.0 + sin(t * 3.0) * 8.0)
	var flap := sin(t * 14.0) * 7.0
	draw_line(gull, gull + Vector2(-14, -6 - flap), Color("#fff8dc"), 3.0)
	draw_line(gull, gull + Vector2(14, -6 - flap), Color("#fff8dc"), 3.0)
	for i in range(8):
		var sp := gull + Vector2(-float(i) * 9.0, sin(t * 9.0 + i) * 4.0)
		draw_rect(Rect2(sp, Vector2(2, 2)), Color("#ffe27a", 0.9 - float(i) * 0.1))

func _draw_cracks() -> void:
	var d: FxDirector = director
	for c in d.cracks:
		var reveal := clampf((d.crack_t - float(c.delay)) / 0.06, 0.0, 1.0)
		if reveal <= 0.0: continue
		var a: Vector2 = c.a
		var b: Vector2 = c.b
		var end := a.lerp(b, reveal)
		draw_line(a + Vector2(1, 1), end + Vector2(1, 1), Color(0, 0, 0, 0.6), 2.0)
		draw_line(a, end, Color(0.92, 0.97, 1.0, 0.95), 1.0)

func _draw_shard(s: Dictionary) -> void:
	var pts := PackedVector2Array()
	var rot := float(s.rot)
	var base: PackedVector2Array = s.pts
	for q in base:
		pts.append(Vector2(s.pos) + q.rotated(rot))
	var alpha := clampf(float(s.life) / 0.5, 0.0, 1.0)
	draw_colored_polygon(pts, Color(0.75, 0.85, 1.0, 0.35 * alpha))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(1, 1, 1, 0.9 * alpha), 1.0)

func _draw_fever_border(amount: float) -> void:
	var t: float = director.time
	var thickness := 4.0
	var segs := 24
	for i in range(segs):
		var hue := fmod(float(i) / float(segs) + t * 0.18, 1.0)
		var col := Color.from_hsv(hue, 0.7, 1.0, 0.75 * amount)
		var fx := float(i) / float(segs) * W
		var fw := W / float(segs) + 1.0
		draw_rect(Rect2(fx, 0, fw, thickness), col)
		draw_rect(Rect2(W - fx - fw, H - thickness, fw, thickness), col)
		var fy := float(i) / float(segs) * H
		var fh := H / float(segs) + 1.0
		draw_rect(Rect2(0, fy, thickness, fh), col)
		draw_rect(Rect2(W - thickness, H - fy - fh, thickness, fh), col)

# ---- helpers ---------------------------------------------------------------

func _frame(r: Rect2, w: float, col: Color) -> void:
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), col)
	draw_rect(Rect2(r.position + Vector2(0, w), Vector2(w, r.size.y - w * 2.0)), col)
	draw_rect(Rect2(r.position + Vector2(r.size.x - w, w), Vector2(w, r.size.y - w * 2.0)), col)

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

# tall is how much of `scale` also applies vertically: 1.0 scales evenly, lower
# values stretch the text sideways while keeping its height nearly unchanged.
func _text_center(text: String, pos: Vector2, size: int, col: Color, scale: float, rot: float, rainbow: bool, tall: float = 1.0) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_set_transform(pos, rot, Vector2(scale, 1.0 + (scale - 1.0) * tall))
	var origin := Vector2(-w * 0.5, 0)
	draw_string_outline(font, origin + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.03, 0.02, 0.08, col.a * 0.9))
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.03, 0.02, 0.08, col.a))
	if rainbow:
		# Per-glyph hue so the hottest banners shimmer without strobing.
		var x := 0.0
		for i in range(text.length()):
			var ch := text.substr(i, 1)
			var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var hue := fmod(float(i) * 0.11 + director.time * 0.5, 1.0)
			draw_string(font, origin + Vector2(x, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.from_hsv(hue, 0.35, 1.0, col.a))
			x += cw
	else:
		draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
