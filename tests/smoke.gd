extends SceneTree
var failures := 0
func check(ok: bool, label: String):
	print(('PASS ' if ok else 'FAIL ') + label)
	if not ok: failures += 1
func _initialize():
	call_deferred('run')
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game); game.set_process(false)
	check(game._walkable(game.player),'spawn is walkable')
	check(not game._walkable(Vector2(240,300)),'inn blocks movement')
	check(not game._walkable(Vector2(400,530)),'sea blocks movement')
	check(game._walkable(Vector2(502,530)),'pier is walkable')
	# Route through town to the pier, using the same substep movement as runtime.
	for target in [Vector2(500,530)]:
		for i in range(1000):
			if game.player.distance_to(target)<2: break
			game._move_player((target-game.player).normalized(),0.016)
		check(game.player.distance_to(target)<2,'route waypoint '+str(target))
	check(game._can_fish(),'pier route ends at fishing spot')
	game.notebook_open=true; game._try_fish()
	check(game.cast_timer==0,'notebook prevents casting')
	game.notebook_open=false; game._try_fish()
	check(game.cast_timer>0,'valid cast starts timed sequence')
	game.rng.seed=2026
	game._finish_cast()
	check(game.catches.size()==1,'catch recorded in ledger')
	var saved_fish=game.fish_count
	game._save_game('user://smoke-test.json')
	game.player=Vector2(368,372); game.fish_count=999; game.catches={}
	game._load_game('user://smoke-test.json')
	check(game.fish_count==saved_fish and game.catches.size()==1,'save restores ledger and count')
	check(game.player.distance_to(Vector2(500,530))<2,'save restores valid position')
	game.player=Vector2(368,372); game.cast_timer=0; game._try_fish()
	check(game.cast_timer==0,'inland cast rejected')
	# Old v2 saves may place the hero in the sea: keep a safe spawn.
	var f=FileAccess.open('user://legacy-test.json',FileAccess.WRITE)
	f.store_string('{"fish":5,"x":950,"y":600}'); f.close()
	game._load_game('user://legacy-test.json')
	check(game._walkable(game.player) and game.fish_count==5,'legacy unsafe position handled')
	# Map transitions fade, rebuild props, and preserve shared progress.
	game.current_map='town'; game._build_map('town'); game._transition_to('beach',Vector2(400,80)); game._process(0.5)
	check(game.current_map=='beach' and game.player==Vector2(400,80),'town to beach transition')
	game._transition_to('rocky',Vector2(90,340)); game._process(0.5)
	check(game.current_map=='rocky' and game.fish_count==5,'beach to rocky preserves ledger')
	game._save_game('user://map-test.json'); game.current_map='town'; game._build_map('town'); game._load_game('user://map-test.json')
	check(game.current_map=='rocky','save restores active map')
	game.current_map='town'; game._build_map('town'); game.player=Vector2(500,440); game._check_map_exit()
	check(game._walkable(Vector2(500,440)) and game.transition_target=='beach','town beach exit is reachable')
	print('RESULT: %d failure(s)' % failures)
	quit(failures)
