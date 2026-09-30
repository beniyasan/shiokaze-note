extends Node2D

# Original v2 world dimensions retained; viewport now shows a walkable slice.
const TILE := 16
const WORLD_W := 64
const WORLD_H := 40
const WORLD_SIZE := Vector2(WORLD_W*TILE, WORLD_H*TILE)
const SAVE_PATH := "user://saltmere_save.json"
var player := Vector2(368, 372)
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
var textures: Dictionary = {}
var face := 0
var walk_time := 0.0
var walking := false
var elapsed := 0.0
var cast_timer := 0.0
var catches: Dictionary = {}
var hud := Node2D.new()

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
	rng.randomize()
	if not OS.get_cmdline_user_args().has("--fresh"):
		_load_game()
	queue_redraw()

func _build_world():
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

func _add_prop(kind: String, pos: Vector2, body: Rect2):
	props.append({"kind":kind,"pos":pos})
	if body.size != Vector2.ZERO: solids.append(Rect2(pos+body.position,body.size))

func _shore(x: float) -> float:
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
	if Input.is_action_just_pressed("notebook"):
		notebook_open = not notebook_open
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	walking = dir.length() > 0 and not notebook_open and cast_timer <= 0
	if walking:
		_move_player(dir,delta)
		walk_time += delta
		if absf(dir.x) > absf(dir.y): face = 2 if dir.x < 0 else 3
		else: face = 1 if dir.y < 0 else 0
	if not notebook_open:
		if cast_timer > 0:
			cast_timer -= delta
			if cast_timer <= 0: _finish_cast()
		elif Input.is_action_just_pressed("fish"): _try_fish()
	if Input.is_action_just_pressed("save_game"): _save_game()
	toast_t = maxf(0.0, toast_t-delta)
	cam.position = player.round()
	queue_redraw(); hud.queue_redraw()

func _can_fish() -> bool:
	return (player.x >= 490 and player.x <= 514 and player.y >= 506) or (player.y >= _shore(player.x)-21 and player.x>70 and player.x<810)

func _try_fish():
	if notebook_open or cast_timer > 0: return
	if _can_fish():
		cast_timer = 1.6; face = 0
		toast = "Casting... watch the float"; toast_t = 2.0
	else:
		toast = "Cast from the water's edge or the end of the pier"; toast_t = 3.0

func _finish_cast():
	var result: String = ["Silver sprat", "Sand goby", "Moonfin trout", "Old boot"][rng.randi_range(0,3)]
	if result != "Old boot": fish_count += 1
	catches[result] = int(catches.get(result,0))+1
	toast = "Caught: " + result + "!  [N] View ledger"; toast_t = 3.5

func _save_game(path: String = SAVE_PATH):
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		toast = "Could not save. Please check available storage."; toast_t = 4; return
	f.store_string(JSON.stringify({"version":3,"day":day,"time":time_of_day,"fish":fish_count,"x":player.x,"y":player.y,"catches":catches}))
	toast = "Saved to the tide ledger"; toast_t = 2.4

func _load_game(path: String = SAVE_PATH):
	if not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	day = maxi(1,int(data.get("day",1))); fish_count = maxi(0,int(data.get("fish",0)))
	time_of_day = clampf(float(data.get("time",0.35)),0.0,1.0)
	var saved_pos := Vector2(float(data.get("x",368)),float(data.get("y",372)))
	if _walkable(saved_pos): player = saved_pos
	if data.get("catches",{}) is Dictionary: catches = data.get("catches",{})
	toast = "Welcome back to Saltmere"; toast_t = 3

func _draw():
	if terrain == null: return
	draw_texture(terrain,Vector2.ZERO)
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
	if cast_timer > 0:
		var float_pos := player.round()+Vector2(15,32+int(sin(elapsed*6)))
		draw_line(player.round()+Vector2(7,-9),player.round()+Vector2(12,-23),Color("#80674a"))
		draw_line(player.round()+Vector2(12,-23),float_pos,Color("#d1d6b2"))
		draw_rect(Rect2(float_pos,Vector2(2,3)),Color("#edb17b"))

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
	_text(Vector2(16,22),"SALTMERE  /  AMBER COAST",11)
	_text(Vector2(16,35),"Day %02d    Fish %02d" % [day,fish_count],10)
	_panel(Rect2(294,8,178,22))
	_text(Vector2(302,23),"[N] Ledger   [F6] Save",10)
	_panel(Rect2(8,244,464,19))
	_text(Vector2(15,257),toast if toast_t>0 else "WASD / arrows: walk     SPACE: cast     Follow the path to the pier",10)
	if _can_fish() and not notebook_open and cast_timer<=0:
		_panel(Rect2(172,218,138,20)); _text(Vector2(182,232),"SPACE  Cast your line",11)
	if notebook_open:
		_panel(Rect2(66,51,348,181),true)
		_text(Vector2(85,75),"THE TIDE LEDGER",17,true)
		_text(Vector2(85,94),"Saltmere town & Amber beach",11,true)
		var row := 116
		for species in ["Silver sprat","Sand goby","Moonfin trout","Old boot"]:
			_text(Vector2(85,row),"%s  ................  %d" % [species,int(catches.get(species,0))],11,true)
			row += 18
		_text(Vector2(85,201),"Shore or pier: SPACE to cast",10,true)
		_text(Vector2(85,218),"N to close  /  Movement pauses while reading",10,true)
