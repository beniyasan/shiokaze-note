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
	# The grade slams in below the gauge rows, so the timing bar stays clear.
	var size := int([20, 20, 30, 33, 36][tier])
	var slam := 1.0 + float([0.5, 0.35, 1.2, 1.5, 1.8][tier]) * (1.0 - _ease_out(clampf(t / 0.12, 0.0, 1.0)))
	var alpha := 1.0 - clampf((t - float(i.dur) * 0.7) / (float(i.dur) * 0.3), 0.0, 1.0)
	var rot := float([0.0, 0.0, -0.04, -0.06, -0.08][tier])
	var text_pos: Vector2 = d.IMPACT_TEXT_POS
	if tier == 0: text_pos += Vector2(sin(d.time * 90.0), cos(d.time * 77.0)) * 2.0 * fade
	if tier >= 2:
		# A slanted band behind the word, like a cut-in that lasts one beat.
		var h := float(size) + 12.0
		var cy := text_pos.y - float(size) * 0.36
		var skew := 18.0
		var band_poly := PackedVector2Array([Vector2(-20 + skew, cy - h * 0.5), Vector2(W + 20 + skew, cy - h * 0.5), Vector2(W + 20 - skew, cy + h * 0.5), Vector2(-20 - skew, cy + h * 0.5)])
		draw_colored_polygon(band_poly, Color(0.04, 0.03, 0.09, 0.55 * alpha))
		draw_line(band_poly[0], band_poly[1], Color(col, 0.9 * alpha), 2.0)
		draw_line(band_poly[3], band_poly[2], Color(col, 0.9 * alpha), 2.0)
		for j in range(8):
			var sx := fmod(float(j) * 71.0 + t * 1100.0, W + 100.0) - 50.0
			var sy := cy - h * 0.5 + 4.0 + fmod(float(j) * 11.0, h - 8.0)
			draw_line(Vector2(sx, sy), Vector2(sx + 30.0, sy), Color(1, 1, 1, 0.3 * alpha), 1.0)
	_text_center(_impact_label(i), text_pos, size, Color(col, alpha), slam, rot, tier >= 4)
	if bool(i.clean):
		_text_center("CLEAN BEAT", text_pos + Vector2(0, 14), 9, Color(0.82, 0.8, 1.0, alpha), 1.0, 0.0, false)

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

func _text_center(text: String, pos: Vector2, size: int, col: Color, scale: float, rot: float, rainbow: bool) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_set_transform(pos, rot, Vector2(scale, scale))
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
