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
	game.fishing_state=game.FishingState.IDLE; game._try_fish()
	check(game.fishing_state==game.FishingState.ANTICIPATING,'fishing bite anticipation starts')
	game._process_fishing(2.0)
	check(game.fishing_state==game.FishingState.TIMING,'bite opens timing window')
	game._resolve_fishing_timing(0.5)
	check(game.fishing_state==game.FishingState.RESULT and game.last_grade=='PERFECT','perfect timing resolves result')
	check(game.combo==1 and game.last_rarity!='','successful catch increments combo and rarity')
	# Standard catches use a deterministic gacha-style reveal instead of
	# showing the species immediately: unknown -> rarity -> rising -> flip.
	check(game.reveal_stage==0 and game.reveal_stage_name()=='UNKNOWN','reveal starts as unknown silhouette')
	game._process_fishing(0.45)
	check(game.reveal_stage==1 and game.reveal_stage_name()=='RARITY','reveal shows rarity seal')
	game._process_fishing(0.40)
	check(game.reveal_stage==2 and game.reveal_stage_name()=='RISING','reveal grows silhouette and light')
	game._process_fishing(0.60)
	check(game.reveal_stage==3 and game.reveal_stage_name()=='FLIPPING','reveal starts card flip')
	game._process_fishing(0.40)
	check(game.reveal_stage==4 and game.reveal_stage_name()=='REVEALED','reveal resolves fish name')
	game._reset_fishing()
	game.notebook_open=true; game._try_fish()
	check(game.cast_timer==0,'notebook prevents casting')
	game.notebook_open=false; game._try_fish()
	check(game.cast_timer>0,'valid cast starts timed sequence')
	check(game.fishing_state == game.FishingState.ANTICIPATING,'cast enters bite anticipation')
	game._process_fishing(2.0)
	game._resolve_fishing_timing(0.5)
	check(game.last_grade=='PERFECT' and game.combo>=1,'perfect timing awards grade and combo')
	game._reset_fishing()
	game._resolve_fishing_timing(0.1)
	check(game.last_grade=='MISS' and game.combo==0,'miss resets combo')
	game._reset_fishing()
	game.rng.seed=2026
	game._finish_cast()
	check(game.catches.size()>=1,'catch recorded in ledger')
	var saved_fish=game.fish_count
	game._save_game('user://smoke-test.json')
	game.player=Vector2(368,372); game.fish_count=999; game.catches={}
	game._load_game('user://smoke-test.json')
	check(game.fish_count==saved_fish and game.catches.size()>=1,'save restores ledger and count')
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
	# Each map exposes named, local fishing landmarks as well as its shoreline.
	game.current_map='beach'; game._build_map('beach'); game.player=Vector2(300,487)
	check(game._can_fish() and game._fishing_spots().size()==2,'beach tide pools are fishable')
	game.player=Vector2(300,300)
	check(not game._can_fish(),'beach inland cast rejected')
	game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(170,590)
	check(game._can_fish() and game._fishing_spots().size()==2,'rocky tide pools are fishable')
	# Battle lasts through multiple spaced inputs; a single tap is not a catch.
	game.transition_active=false
	game.notebook_open=false
	game._reset_fishing(); game.combo=2
	game.player=Vector2(170,590)
	game._try_fish(); game._process_fishing(2.0)
	check(game.fish_hp_max==12 and game.timing_timer==20.0,'battle starts with stamina and a 20 second limit')
	var before_battle=game.fish_count
	game._handle_fishing_strike(0.5)
	check(game.fish_count==before_battle and game.battle_hits==0,'initial tug cooldown rejects instant catch')
	game._process_fishing(1.1)
	game._handle_fishing_strike(0.5)
	check(game.fishing_state==game.FishingState.TIMING and game.fish_hp==10,'first perfect pull wears fish down but does not finish')
	game._handle_fishing_strike(0.5)
	check(game.battle_hits==1,'rapid repeated inputs cannot skip battle')
	for i in range(5):
		game._process_fishing(1.85)
		game._handle_fishing_strike(0.5)
	check(game.last_rarity=='LEGENDARY' and game.fishing_state==game.FishingState.RESULT,'six perfect pulls land the combo legendary')
	check(game.battle_elapsed>=9.0 and game.fish_count==before_battle+1,'legendary battle lasts at least nine seconds and counts once')
	check(game.legendary_t==0.0 and game.result_t==8.4,'legendary starts its delayed 8.4 second card reveal')
	check(game.reveal_stage_name()=='UNKNOWN' and not game.toast.contains('Rainbow Kingfish'),'legendary starts sealed with no species spoiler')
	var reveal_points := [1.11,1.91,3.21,3.66,4.04,4.06,6.21,8.4]
	var reveal_names := ['RARITY','RISING','HOLD','FLIPPING','FLIPPING','CLIMAX','AFTERGLOW','AFTERGLOW']
	var reveal_clock := 0.0
	for index in range(reveal_points.size()):
		game._process_fishing(reveal_points[index]-reveal_clock)
		reveal_clock = reveal_points[index]
		check(game.reveal_stage_name()==reveal_names[index],'legendary stage at %.2fs is %s' % [reveal_clock,reveal_names[index]])
		if reveal_clock < game.LegendaryRevealTiming.REVEAL_AT:
			check(not game.toast.contains('Rainbow Kingfish'),'legendary toast stays hidden at %.2fs' % reveal_clock)
		else:
			check(game.toast.contains('Rainbow Kingfish'),'legendary species appears after the card edge at %.2fs' % reveal_clock)
	check(game.music._fanfare_length==game.LegendaryRevealTiming.DURATION,'legendary music shares the entire visual timeline')
	# The pause is musically quiet and the fanfare cannot wrap back to its omen.
	game.music._fanfare_start_sample=0.0
	check(absf(game.music._fanfare_voice(3.4))<0.03,'legendary music leaves a breath before the flip')
	check(game.music._fanfare_voice(8.5)==0.0,'legendary music does not wrap after its ending')
	# Early repeated Space presses cannot erase the mystery, but continue works
	# once the face has finished opening. A second catch restarts every stage.
	game._reset_fishing(); game.combo=2; game._resolve_fishing_timing(0.5)
	Input.action_press('fish'); game._process_fishing(0.1)
	check(game.fishing_state==game.FishingState.RESULT and game.reveal_stage_name()=='UNKNOWN','early Space cannot skip the legendary reveal')
	Input.action_release('fish')
	game._process_fishing(4.5)
	check(game.legendary_t >= game.LegendaryRevealTiming.FLIP_END,'legendary card is open before continue')
	game._reset_fishing()
	check(game.fishing_state==game.FishingState.IDLE,'continue resets after the legendary card opens')
	game._resolve_fishing_timing(0.5)
	check(game.legendary_t==0.0 and game.reveal_stage_name()=='UNKNOWN','repeated legendary restarts as a sealed catch')
	game._reset_fishing(); game._try_fish(); game._process_fishing(2.0)
	game._process_fishing(1.1)
	game._handle_fishing_strike(0.0)
	check(game.fishing_state==game.FishingState.TIMING and game.battle_tension>0.4,'bad pull strains the line without instant failure')
	game.battle_tension=0.9; game.pull_cooldown=0.0; game._handle_fishing_strike(0.0)
	check(game.last_grade=='MISS' and game.combo==0,'repeated bad pulls can snap the line and reset combo')
	game._reset_fishing()
	check(game.fish_hp==0 and game.battle_hits==0 and game.legendary_t==0.0,'reset clears battle and celebration state')
	game._try_fish(); game._process_fishing(2.0); game._process_fishing(21.0)
	check(game.last_grade=='MISS','battle timeout loses the fish')
	# The standalone chain exposes all four deterministic mini-game styles.
	var ChallengeScript = preload('res://fishing_challenge.gd')
	for seed in range(4):
		var challenge = ChallengeScript.new()
		challenge.configure(3,2,seed)
		check(challenge.current_game()==seed,'challenge seed %d opens %s' % [seed,challenge.current_game_name()])
		var starting_name = challenge.current_game_name()
		var beat = challenge.accept(0.5,0.0)
		check(beat.success,'challenge %s accepts a centred keyboard beat' % starting_name)
		challenge.configure(3,2,seed)
		challenge.tick(1.2)
		var missed = challenge.accept(0.0,0.0)
		check(not missed.success and challenge.round_index==0,'challenge %s rejects an outside beat after grace' % starting_name)
		var recovered = challenge.accept(challenge.target_center(),challenge.safe_lane())
		check(recovered.success,'challenge %s can recover at its visible target' % starting_name)
	# A combo-two battle wires the chain into the live timing state.
	game._reset_fishing(); game.combo=2; game.player=Vector2(170,590)
	game._try_fish(); game._process_fishing(2.0)
	check(game.fishing_challenge != null and game.fishing_challenge.rounds.size()==4,'bite configures the four-round challenge chain')
	# Use the real moving gauge at 60fps, rather than injecting perfect positions.
	# This proves each rotated chain can be caught through the normal key path.
	for seed in range(4):
		game._reset_fishing(); game.combo=2
		game._try_fish(); game._process_fishing(2.0)
		game.fishing_challenge.configure(3,2,seed)
		for frame in range(1200):
			if game.fishing_state != game.FishingState.TIMING: break
			game._process_fishing(1.0/60.0)
			var target = game.fishing_challenge.target_center()
			var half_width = game.fishing_challenge.target_width()*0.5
			if game.pull_cooldown<=0.0 and game.gauge>=0.42 and game.gauge<=0.62 and absf(game.gauge-target)<=half_width:
				game._handle_fishing_strike(game.gauge)
		check(game.last_rarity=='LEGENDARY' and game.fishing_challenge.done,'moving gauge completes rotated chain %d within time limit' % seed)
	game.queue_free()
	await process_frame
	print('RESULT: %d failure(s)' % failures)
	quit(failures)
