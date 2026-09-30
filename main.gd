extends Node2D

const TILE := 16
const WORLD_W := 64
const WORLD_H := 40
const WORLD_SIZE := Vector2(WORLD_W*TILE, WORLD_H*TILE)
var player := Vector2(28*TILE, 23*TILE)
var speed := 115.0
var fish_count := 0
var day := 1
var time_of_day := 0.25
var notebook_open := false
var toast := "Welcome to Saltmere"
var toast_t := 4.0
var rng := RandomNumberGenerator.new()
var cam := Camera2D.new()

func _ready():
	cam.position = player
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = 0; cam.limit_top = 0; cam.limit_right = int(WORLD_SIZE.x); cam.limit_bottom = int(WORLD_SIZE.y)
	add_child(cam)
	rng.seed = 90210
	queue_redraw()

func _process(delta):
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0:
		player += dir.normalized() * speed * delta
		player.x = clamp(player.x, 2*TILE, WORLD_SIZE.x-2*TILE)
		player.y = clamp(player.y, 2*TILE, WORLD_SIZE.y-2*TILE)
		time_of_day = fmod(time_of_day + delta*0.008, 1.0)
	if Input.is_action_just_pressed("fish"):
		_try_fish()
	if Input.is_action_just_pressed("notebook"):
		notebook_open = not notebook_open
		toast = "Notebook opened" if notebook_open else "Notebook closed"; toast_t = 2.0
	if Input.is_action_just_pressed("save_game"):
		_save_game()
	toast_t = maxf(0.0, toast_t-delta)
	cam.position = player
	queue_redraw()

func _try_fish():
	# water zones: beach south, estuary east, offshore north
	var tx := int(player.x/TILE); var ty := int(player.y/TILE)
	if (ty >= 29 and tx >= 8 and tx <= 55) or (tx >= 48 and ty >= 10 and ty <= 29) or (ty <= 9 and tx >= 20 and tx <= 57):
		fish_count += 1
		toast = ["A silver sprat!", "Old boot...", "Moonfin trout!", "The line hums with a boss hook..."][rng.randi_range(0,3)]
	else:
		toast = "Find water to cast your line"
	toast_t = 2.8

func _save_game():
	var f := FileAccess.open("user://saltmere_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"day":day,"time":time_of_day,"fish":fish_count,"x":player.x,"y":player.y}))
	toast = "Game saved to the tide ledger"; toast_t = 2.4

func _draw():
	# base sea and tile-grid world
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#193d59"))
	for y in range(WORLD_H):
		for x in range(WORLD_W):
			var p := Vector2(x*TILE, y*TILE)
			var c := Color("#1b4762")
			# mainland wedge / zones
			if y >= 10 and x <= 49: c = Color("#6b8f58")
			if y >= 18 and x <= 38: c = Color("#7c9a5a")
			if y >= 29 and x <= 56: c = Color("#c5a36a")
			if x >= 48 and y >= 10 and y <= 28: c = Color("#2c6074")
			if y <= 9 and x >= 20: c = Color("#24506a")
			if (x in [4,5,6] and y in [12,13,14,15]) or (x in [9,10] and y in [20,21]): c = Color("#6b6f73")
			draw_rect(Rect2(p, Vector2(TILE-1,TILE-1)), c)
	# town plaza and buildings
	draw_rect(Rect2(7*TILE, 18*TILE, 17*TILE, 10*TILE), Color("#8aa36b"))
	draw_rect(Rect2(10*TILE, 19*TILE, 7*TILE, 5*TILE), Color("#ae6e53"))
	draw_rect(Rect2(19*TILE, 20*TILE, 4*TILE, 4*TILE), Color("#bd8456"))
	draw_string(ThemeDB.fallback_font, Vector2(11*TILE,18*TILE-3), "SALTMERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#f7e7b2"))
	# lighthouse on rocky point
	draw_rect(Rect2(56*TILE, 8*TILE, 2*TILE, 8*TILE), Color("#e4d4b4"))
	draw_rect(Rect2(55*TILE, 8*TILE, 4*TILE, TILE), Color("#d65a4a"))
	draw_circle(Vector2(57*TILE,8*TILE), 22.0, Color(1,0.95,0.65,0.10))
	# piers and reed clusters
	for i in range(8):
		var px := (25+i)*TILE; draw_rect(Rect2(px,28*TILE, TILE, 5*TILE), Color("#79583f"))
	for i in range(12):
		var rx := (40+i%6)*TILE; var ry := (26+i/6)*TILE
		draw_line(Vector2(rx,ry+12), Vector2(rx+4,ry), Color("#b0b96b"), 2.0)
	# day/night tint
	var night := clampf(absf(time_of_day-0.5)*2.0,0.0,1.0)
	draw_rect(Rect2(Vector2.ZERO,WORLD_SIZE), Color(0.05,0.08,0.18,night*0.46))
	# player, intentionally tiny relative to world
	var pp := player
	draw_rect(Rect2(pp+Vector2(-5,-8),Vector2(10,12)), Color("#e8b36a"))
	draw_rect(Rect2(pp+Vector2(-5,-8),Vector2(10,4)), Color("#3f6ea0"))
	draw_rect(Rect2(pp+Vector2(-4,4),Vector2(3,5)), Color("#263650")); draw_rect(Rect2(pp+Vector2(1,4),Vector2(3,5)), Color("#263650"))
	# HUD anchored to camera screen
	var hud := cam.get_screen_center_position() - Vector2(460,250)
	draw_rect(Rect2(hud+Vector2(14,14),Vector2(330,52)), Color("#152334"))
	draw_string(ThemeDB.fallback_font,hud+Vector2(26,35),"TIDEBound  •  DAY %02d  •  %s" % [day, _time_label()],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#f4dba1"))
	draw_string(ThemeDB.fallback_font,hud+Vector2(26,55),"Fish %02d   [N] notebook   [F6] save   [SPACE] cast" % fish_count,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#b9d6d0"))
	if toast_t > 0: draw_string(ThemeDB.fallback_font,hud+Vector2(26,90),toast,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#ffe8a3"))
	if notebook_open:
		draw_rect(Rect2(hud+Vector2(110,110),Vector2(740,360)),Color("#ead9ac"))
		draw_rect(Rect2(hud+Vector2(125,125),Vector2(710,330)),Color("#d6bf8e"),false,3)
		draw_string(ThemeDB.fallback_font,hud+Vector2(150,165),"THE TIDE LEDGER",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("#293b4b"))
		draw_string(ThemeDB.fallback_font,hud+Vector2(150,205),"Saltmere coast chart",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#3c4e59"))
		draw_string(ThemeDB.fallback_font,hud+Vector2(150,240),"• Town plaza — trade, rumors, warm lanterns",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#3c4e59"))
		draw_string(ThemeDB.fallback_font,hud+Vector2(150,268),"• Amber beach — cast where waves comb the sand",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#3c4e59"))
		draw_string(ThemeDB.fallback_font,hud+Vector2(150,296),"• Reed estuary — quiet water, strange tracks",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#3c4e59"))
		draw_string(ThemeDB.fallback_font,hud+Vector2(150,324),"• Rocky coast — climb toward the lighthouse",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#3c4e59"))
		draw_string(ThemeDB.fallback_font,hud+Vector2(150,352),"• Offshore — the boss hook waits beyond dusk",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#3c4e59"))
		draw_string(ThemeDB.fallback_font,hud+Vector2(150,410),"Press N to close",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#694d3b"))

func _time_label() -> String:
	if time_of_day < 0.25: return "DAWN"
	if time_of_day < 0.55: return "DAY"
	if time_of_day < 0.8: return "DUSK"
	return "NIGHT"
