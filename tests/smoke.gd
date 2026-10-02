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
	# Tide forecast gates species by map, time, weather, and season.
	check(game._time_period(0.50)=='day' and game._time_period(0.25)=='dawn' and game._time_period(0.95)=='night','clock resolves fishing periods')
	check(game.fish_available('Silver sprat','town',0.50,'clear','spring'),'daytime sprat are available in spring')
	check(not game.fish_available('Silver sprat','town',0.50,'clear','winter'),'sprat leave in winter')
	check(game.fish_available('Moonfin trout','beach',0.75,'clear','autumn'),'moonfin follows an autumn dusk tide')
	check(not game.fish_available('Moonfin trout','beach',0.50,'clear','autumn'),'moonfin leaves after dusk')
	check(game.fish_available('Storm sardine','rocky',0.95,'storm','summer'),'storm sardine follows a summer storm night')
	check(not game.fish_available('Storm sardine','rocky',0.50,'storm','summer'),'storm sardine avoids daylight')
	var forecast_before: Array = game.available_fish('rocky',0.95,'storm','summer')
	check(forecast_before == game.fish_availability('rocky',0.95,'storm','summer'),'forecast aliases stay deterministic')
	var old_day: int = game.day; var old_time: float = game.time_of_day; var old_weather: String = game.weather; var old_season: String = game.season
	game.day = 7; game.time_of_day = 0.99; game.weather = 'storm'; game.season = 'spring'; game._advance_world_clock(3.0)
	check(game.day==8 and game.season=='summer' and game.weather=='clear','clock rollover advances season and forecast')
	game.day = old_day; game.time_of_day = old_time; game.weather = old_weather; game.season = old_season
	# Route through town to the pier, using the same substep movement as runtime.
	for target in [Vector2(500,530)]:
		for i in range(1000):
			if game.player.distance_to(target)<2: break
			game._move_player((target-game.player).normalized(),0.016)
		check(game.player.distance_to(target)<2,'route waypoint '+str(target))
	check(game._can_fish(),'pier route ends at fishing spot')
	check(game.bait_name()=='Worm' and game.rod_name()=='Reed Rod','default tackle is available')
	game.cycle_bait(); check(game.bait_name()=='Glowbait' and game.BAITS[game.bait_index].rarity_bonus>0.0,'bait selection improves rarity odds')
	game.cycle_rod(); check(game.rod_name()=='Fiberglass Rod' and game.RODS[game.rod_index].tension_mult<1.0,'rod selection reduces line strain')
	game.cycle_bait(-1); game.cycle_rod(-1)
	game.fishing_state=game.FishingState.IDLE; game._try_fish()
	check(game.fishing_state==game.FishingState.ANTICIPATING,'fishing bite anticipation starts')
	var cast_species := str(game.cast_candidate.get('name',''))
	game._process_fishing(2.0)
	check(game.fishing_state==game.FishingState.TIMING,'bite opens timing window')
	game._resolve_fishing_timing(0.5)
	check(game.fishing_state==game.FishingState.RESULT and game.last_grade=='PERFECT','perfect timing resolves result')
	check(game.combo==1 and game.last_rarity!='','successful catch increments combo and rarity')
	check(game.last_catch==cast_species,'cast candidate is the authoritative resolved species')
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
	# The cast keeps a PERFECT-pool candidate, while the mini-game grade still
	# changes quality: GOOD downgrades a high-rarity candidate to RARE, whereas
	# PERFECT adopts the candidate unchanged.
	var high_candidate: Dictionary = game.FISH_SPECIES[15].duplicate(true)
	game._reset_fishing(); game.cast_candidate=high_candidate.duplicate(true); game._resolve_fishing_timing(0.34)
	check(game.last_catch!=str(high_candidate.name) and game.last_rarity=='RARE' and game.last_catch_metadata.get('original_rarity','')=='EPIC' and game.last_catch_metadata.get('downgraded_from_species','')==str(high_candidate.name) and game.result_t<=2.0,'GOOD timing swaps EPIC candidate for a map-legal RARE without legendary reveal')
	game._reset_fishing(); game.cast_candidate=high_candidate.duplicate(true); game._resolve_fishing_timing(0.5)
	check(game.last_catch==str(high_candidate.name) and game.last_rarity=='EPIC' and game.last_catch_metadata.get('original_rarity','')=='EPIC','PERFECT timing keeps the cast candidate rarity')
	check(game._promotion_max_stage('COMMON')==1 and game._promotion_max_stage('UNCOMMON')==1 and game._promotion_max_stage('RARE')==2 and game._promotion_max_stage('EPIC')==3 and game._promotion_max_stage('LEGENDARY')==3,'promotion stage cap follows candidate rank')
	game.promotion_stage=3; game.promotion_reversal=true
	check(game._visible_promotion_stage()==2,'reversal visibly steps the float back one stage')
	game._reset_fishing(); game.cast_candidate=high_candidate.duplicate(true); game.promotion_cue_rank=3; game._resolve_fishing_timing(0.34)
	check(game.promotion_result_label.begins_with('惜しい') and game.last_rarity=='RARE','honest high preview to GOOD low result is labelled near miss')
	game._reset_fishing(); game.cast_candidate=game.FISH_SPECIES[2].duplicate(true); game.promotion_cue_rank=0; game._resolve_fishing_timing(0.5)
	check(game.promotion_result_label=='逆転!' and game.last_rarity=='RARE','low preview to PERFECT high result is labelled reversal')
	# Promotion lies are configured once per cast, so a seeded cast reproduces
	# both its misleading cue and its reversal window exactly.
	game._reset_fishing(); game.current_map='town'; game._build_map('town'); game.player=Vector2(500,530); game.shells=100
	var false_cue_seed := -1
	for seed in range(1,512):
		game._reset_fishing(); game.shells=100; game.rng.seed=seed; game._try_fish()
		if game.promotion_false_cue and game.promotion_reversal_armed:
			false_cue_seed = seed; break
	check(false_cue_seed > 0,'seeded cast finds a false cue and reversal path')
	if false_cue_seed > 0:
		var first_cue_rank: int = game.promotion_cue_rank
		var first_target_rank: int = game._rarity_rank(game.promotion_target_rarity)
		var first_candidate := str(game.cast_candidate.get('name',''))
		game._reset_fishing(); game.shells=100; game.rng.seed=false_cue_seed; game._try_fish()
		check(game.promotion_false_cue and game.promotion_cue_rank==first_cue_rank and game.cast_candidate.get('name','')==first_candidate,'promotion cue is deterministic per cast seed')
		check(not game.promotion_false_cue_revealed,'false cue stays hidden during anticipation')
		var reversal_delta: float = game.bite_delay * 0.68
		game._process_fishing(reversal_delta)
		check(game.promotion_reversal and not game.promotion_false_cue_revealed and first_cue_rank != first_target_rank,'false cue enters its configured reversal window without revealing early')
		game._resolve_fishing_timing(0.5)
		check(game.promotion_false_cue_revealed,'false cue is disclosed only on the result reveal')
	game._reset_fishing()
	game._reset_fishing()
	game._resolve_fishing_timing(0.1)
	check(game.last_grade=='MISS' and game.combo==0,'miss resets combo')
	# Soft pity counts consecutive misses/low-grade outcomes and arms one
	# transparent rescue hook. The hook changes only the rarity floor; the
	# timing battle is still required for a real catch.
	game._reset_pity()
	for i in range(game.PITY_THRESHOLD):
		game._resolve_fishing_timing(-1.0)
		game._reset_fishing()
	check(game.pity_status().meter==game.PITY_THRESHOLD and game.pity_status().ready,'miss streak arms rescue hook')
	game.current_map='town'; game._build_map('town'); game.rng.seed=9182
	var rescued_pick: Dictionary = game._pick_species('GOOD', true)
	check(game._rarity_rank(str(rescued_pick.get('rarity','COMMON')))>=game._rarity_rank('RARE'),'armed rescue raises catch floor to rare')
	game.pity_meter=2; game.low_grade_streak=2; game.rescue_ready=false
	game._save_game('user://pity-test.json')
	game._reset_pity(); game._load_game('user://pity-test.json')
	check(game.pity_meter==2 and game.low_grade_streak==2 and not game.rescue_ready,'save restores pity meter without arming early')
	game.pity_meter=game.PITY_THRESHOLD; game.rescue_ready=true
	game._reset_fishing()
	game.rng.seed=2026
	game._finish_cast()
	check(game.catches.size()>=1,'catch recorded in ledger')
	check(game.pity_meter==0 and not game.rescue_ready,'successful rescue catch clears pity meter')
	var first_species: String = str(game.last_catch)
	var first_meta: Dictionary = game.get_first_capture_metadata(first_species)
	check(first_meta.has('day') and first_meta.has('map') and first_meta.has('spot'),'first capture stores where and when')
	check(float(first_meta.get('size_cm',0.0))>0.0 and float(first_meta.get('weight_kg',0.0))>0.0,'first capture stores size and weight variation')
	check(first_meta.has('variant') and first_meta.has('mystery_marker'),'first capture stores variant and mystery markers')
	check(bool(game.last_catch_metadata.get('crown', false)),'first capture is marked as crown')
	var first_size := float(first_meta.get('size_cm',0.0))
	check(bool(first_meta.get('crown', false)) and first_meta.has('record_size_cm'),'first capture persists crown metadata')
	check(game.best_records.has(first_species) and float(game.best_records[first_species].get('size_cm',0.0))>=first_size,'first capture creates a size record')
	check(game.best_records[first_species].has('map') and game.best_records[first_species].has('spot'),'crown record keeps its catch location')
	check(game._record_is_better({'size_cm':42.0,'weight_kg':2.0},{'size_cm':42.0,'weight_kg':1.9}),'heavier equal-size specimen can take the crown')
	check(not game._record_is_better({'size_cm':41.9,'weight_kg':9.0},{'size_cm':42.0,'weight_kg':1.0}),'smaller specimen cannot displace a size crown')
	# A catch remains on the result card until the player explicitly chooses a
	# disposition. Saving at that point must preserve the held fish and its
	# deterministic sale value.
	check(game.catch_choice_pending() and game.pending_catch_species()==first_species,'catch opens an explicit sell-or-register choice')
	var pending_shells: int = game.shells
	var pending_count := int(game.catches.get(first_species,0))
	var pending_value: int = game.pending_catch_sell_value()
	game._save_game('user://pending-catch.json')
	game._reset_fishing()
	game._load_game('user://pending-catch.json')
	check(game.catch_choice_pending() and game.pending_catch_sell_value()==pending_value,'save restores pending catch choice without rerolling value')
	check(bool(game.pending_catch.get('metadata',{}).get('first_capture',false)) and not game.reveal_shortened,'pending first-capture metadata survives save/load')
	check(game.shells==pending_shells and int(game.catches.get(first_species,0))==pending_count,'pending choice does not duplicate currency or inventory')
	check(game.register_pending_catch() and not game.catch_choice_pending() and game.shells==pending_shells+1,'register keeps fish and awards the established shell reward once')
	# A repeat updates the current reveal while leaving the discovery record intact.
	game._record_catch_metadata({'name':first_species,'rarity':str(first_meta.get('rarity','COMMON'))},'GOOD')
	check(is_equal_approx(float(game.get_first_capture_metadata(first_species).get('size_cm',0.0)),first_size) and game.catch_latest.has(first_species),'first capture metadata is immutable across repeats')
	check(game.reveal_shortened,'repeat catch uses shortened reveal')
	var repeat_size := float(game.last_catch_metadata.get('size_cm',0.0))
	var repeat_record_size := float(game.best_records[first_species].get('size_cm',0.0))
	check(bool(game.last_catch_metadata.get('crown', false)) == is_equal_approx(repeat_size,repeat_record_size),'repeat crown marker matches the generated record')
	# Selling removes only the held inventory copy.  Discovery metadata and the
	# species crown remain available, so a player cannot lose a record by taking
	# the shell payout.
	var first_rarity := str(first_meta.get('rarity','COMMON'))
	game._reset_fishing(); game.cast_candidate={'name':first_species,'rarity':first_rarity}; game._resolve_fishing_timing(0.5)
	var sell_shells: int = game.shells
	var sell_value: int = game.pending_catch_sell_value()
	var sell_count_before := int(game.catches.get(first_species,0))
	check(game.sell_pending_catch() and not game.catch_choice_pending(),'sell resolves the pending choice')
	check(game.shells==sell_shells+sell_value and int(game.catches.get(first_species,0))==sell_count_before-1,'selling pays shells and removes only one held fish')
	check(game.get_first_capture_metadata(first_species).has('size_cm') and game.best_records.has(first_species),'selling preserves discovery and crown records')
	check(first_rarity == 'LEGENDARY' or game._reveal_stage_at(1.12,first_rarity)==4,'shortened reveal reaches face before standard timing')
	game.weather='rain'; game.season='autumn'; game.time_of_day=0.74
	var saved_fish=game.fish_count
	game._save_game('user://smoke-test.json')
	game.player=Vector2(368,372); game.fish_count=999; game.catches={}; game.weather='clear'; game.season='spring'; game.time_of_day=0.35
	game.catch_metadata={}; game.first_capture_metadata={}; game.catch_latest={}
	game._load_game('user://smoke-test.json')
	check(game.fish_count==saved_fish and game.catches.size()>=1,'save restores ledger and count')
	check(game.weather=='rain' and game.season=='autumn' and is_equal_approx(game.time_of_day,0.74),'save restores tide forecast')
	game.weather='clear'; game.season='spring'; game.time_of_day=0.35
	check(game.get_first_capture_metadata(first_species).has('size_cm') and is_equal_approx(float(game.get_first_capture_metadata(first_species).get('size_cm',0.0)),first_size),'save restores first capture metadata')
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
	game._reset_fishing(); game._break_chain(); game.combo=2
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
	check(game.fishing_state==game.FishingState.RESULT and game.last_rarity != '', 'six perfect pulls resolve a catch without guaranteed legendary')
	check(game.battle_elapsed>=9.0 and game.fish_count==before_battle+1,'legendary battle lasts at least nine seconds and counts once')
	if game.last_rarity == 'LEGENDARY':
		check(game.legendary_t==0.0 and game.result_t>6.0,'legendary starts its six second staged celebration')
		game._process_fishing(1.0); check(game.legendary_stage==1,'legendary advances to rising energy')
		game._process_fishing(1.2); check(game.legendary_stage==2,'legendary advances to full screen climax')
		game._process_fishing(1.7); check(game.legendary_stage==3,'legendary advances to afterglow')
	else:
		check(game.last_rarity in ['COMMON','UNCOMMON','RARE','EPIC'],'bounded rarity result is valid')
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
	game._reset_fishing(); game._break_chain(); game.combo=2; game.player=Vector2(170,590)
	game._try_fish(); game._process_fishing(2.0)
	check(game.fishing_challenge != null and game.fishing_challenge.rounds.size()==4,'bite configures the four-round challenge chain')
	# Use the real moving gauge at 60fps, rather than injecting perfect positions.
	# This proves each rotated chain can be caught through the normal key path.
	for seed in range(4):
		game._reset_fishing(); game._break_chain(); game.combo=2
		game._try_fish(); game._process_fishing(2.0)
		game.fishing_challenge.configure(3,2,seed)
		for frame in range(1200):
			if game.fishing_state != game.FishingState.TIMING: break
			game._process_fishing(1.0/60.0)
			var target = game.fishing_challenge.target_center()
			var half_width = game.fishing_challenge.target_width()*0.5
			if game.pull_cooldown<=0.0 and game.gauge>=0.42 and game.gauge<=0.62 and absf(game.gauge-target)<=half_width:
				game._handle_fishing_strike(game.gauge)
		check(game.fishing_challenge.done and game.fishing_state==game.FishingState.RESULT,'moving gauge completes rotated chain %d within time limit' % seed)
	check(game.FISH_SPECIES.size()==23,'expanded field guide has 23 species')
	check(game.FISH_SPECIES.any(func(f): return f.rarity=='EPIC') and game.FISH_SPECIES.any(func(f): return f.rarity=='LEGENDARY'),'field guide includes epic and legendary')
	game.current_map='town'; game._build_map('town'); game.player=Vector2(468,381); game._update_rumor_gate()
	check(game.rumor_found,'weathered notice reveals hidden fishing rumor')
	game.fish_count=3; game._update_rumor_gate(); check(game.hidden_spot_unlocked,'collection gate unlocks hidden spot')
	game.current_map='rocky'; game._build_map('rocky'); check(game._fishing_spots().size()==3,'hidden grotto adds distinct pool')
	game.hidden_spot_collected=true; game.player=Vector2(170,590)
	var rocky_pool: Array = game._species_pool()
	check(not rocky_pool.any(func(f): return f.rarity=='LEGENDARY' and f.maps.has('hidden')),'hidden fish stay out of ordinary rocky pools')
	game.player=Vector2(690,520)
	check(game._species_pool().any(func(f): return f.rarity=='LEGENDARY' and f.maps.has('hidden')),'hidden fish require the actual grotto fishing spot')
	check(game._legendary_chance_for_cast()<=0.05,'rocky legendary chance is capped at five percent')
	game.combo=2; game.fever_active=false; game.bait_index=1
	var no_fever_legendary_chance: float = game._legendary_chance_for_cast()
	game.combo=3; game.fever_active=true; game.bait_index=1
	var fever_legendary_chance: float = game._legendary_chance_for_cast()
	game.bait_index=2
	var moonseed_legendary_chance: float = game._legendary_chance_for_cast()
	check(is_equal_approx(no_fever_legendary_chance,0.01) and is_equal_approx(fever_legendary_chance,0.03) and is_equal_approx(moonseed_legendary_chance,0.05) and is_equal_approx(moonseed_legendary_chance-fever_legendary_chance,0.02),'legendary chance uses actual FEVER and bounded Moonseed nudge')
	check(game._rarity_bonus_scale('COMMON')==0.0 and game._rarity_bonus_scale('RARE')>game._rarity_bonus_scale('UNCOMMON') and game._rarity_bonus_scale('EPIC')>game._rarity_bonus_scale('RARE'),'bait and FEVER scales favour higher rarities')
	# Force a legendary candidate to verify the reveal path without relying on a
	# statistical roll.  The result must still come from the cast candidate.
	game._reset_fishing(); game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(170,590); game.combo=2
	game.cast_candidate=game.FISH_SPECIES[4].duplicate(true)
	game._resolve_fishing_timing(0.5)
	check(game.last_rarity=='LEGENDARY' and game.last_catch==game.FISH_SPECIES[4].name and game.result_t>6.0,'forced legendary candidate opens the staged reveal')
	var rainbow_count_before: int = int(game.catches.get('Rainbow Kingfish',0))
	game._reset_fishing(); game.cast_candidate=game.FISH_SPECIES[4].duplicate(true); game._resolve_fishing_timing(0.34)
	check(game.last_rarity=='RARE' and game.last_catch!='Rainbow Kingfish' and int(game.catches.get('Rainbow Kingfish',0))==rainbow_count_before,'GOOD legendary candidate becomes a RARE catch without ledgering Legendary species')
	# Fever is earned through three catches, survives result dismissal, and
	# expires independently of the fish's battle timer.
	game._reset_fishing(); game._break_chain()
	game.current_map='town'; game._build_map('town'); game.player=Vector2(500,530)
	game.bait_index=0
	for i in range(3):
		game._resolve_fishing_timing(0.34)
		check(game.combo==i+1 and game.fever_active==(i==2),'fever threshold catch %d' % (i+1))
		game._reset_fishing()
	check(game.fever_t==game.FEVER_DURATION,'result dismissal preserves fever window')
	check(game.music.get_snapshot().fever,'fever enables music cue')
	game.music._update_transport(1.0)
	check(game.music.get_snapshot().combo==4,'fever activates maximum music layer')
	var rare_normal=0
	var rare_fever=0
	game.fever_active=false; game.rng.seed=4401
	for i in range(2000):
		if game._pick_species('GOOD').rarity=='RARE': rare_normal+=1
	game.fever_active=true; game.rng.seed=4401
	for i in range(2000):
		var picked=game._pick_species('GOOD')
		if picked.rarity=='RARE': rare_fever+=1
		if not picked.maps.has('town') or picked.rarity in ['EPIC','LEGENDARY']: failures+=1
	check(rare_fever>rare_normal,'fever raises seeded rare catch frequency without bypassing pool/grade')
	var remaining=game.fever_t
	game._process_fishing(1.0)
	check(is_equal_approx(game.fever_t,remaining-1.0),'fever countdown advances while idle')
	game.bait_index=1; game.rod_index=2
	game._save_game('user://fever-test.json')
	var saved_fever=game.fever_t
	game._break_chain(); game.bait_index=0; game.rod_index=0
	game._load_game('user://fever-test.json')
	check(game.combo==3 and game.fever_active and is_equal_approx(game.fever_t,saved_fever),'save restores combo and remaining fever')
	check(game.bait_index==1 and game.rod_index==2 and game.catches.size()>0,'fever save preserves loadout and ledger')
	game._process_fishing(game.FEVER_DURATION+0.1)
	check(not game.fever_active and game.combo==0 and game.fever_t==0.0,'fever timeout resets chain')
	check(not game.music.get_snapshot().fever,'fever timeout clears music cue')
	game._reset_fishing(); game.combo=2; game._resolve_fishing_timing(0.34)
	game._reset_fishing(); game._resolve_fishing_timing(-1.0)
	check(not game.fever_active and game.combo==0 and game.fever_t==0.0,'miss ends fever and resets chain')
	game._load_game('user://legacy-test.json')
	check(not game.fever_active and game.combo==0,'legacy saves default to no fever')
	game.queue_free()
	await process_frame
	print('RESULT: %d failure(s)' % failures)
	quit(failures)
