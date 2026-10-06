extends SceneTree
var failures := 0
func check(ok: bool, label: String):
	print(('PASS ' if ok else 'FAIL ') + label)
	if not ok: failures += 1
func _initialize():
	call_deferred('run')
# Walks like _process does: one movement step, then the map-exit check.
func walk_to(game, target: Vector2, frames: int = 900) -> bool:
	for i in range(frames):
		if game.player.distance_to(target) < 2.0: return true
		if game.transition_active: return game.player.distance_to(target) < 12.0
		game._move_player((target-game.player).normalized(),0.016)
		game._check_map_exit()
	return game.player.distance_to(target) < 2.0
func run():
	var game = load('res://main.tscn').instantiate()
	root.add_child(game); game.set_process(false)
	check(game._walkable(game.player),'spawn is walkable')
	check(not game._walkable(Vector2(240,300)) and not game._walkable(Vector2(478,150)) and not game._walkable(Vector2(800,260)),'cottage garden, inn and market block movement')
	check(not game._walkable(Vector2(505,280)) and game._walkable(Vector2(505,345)),'the fountain blocks movement but the plaza around it is open')
	check(not game._walkable(Vector2(300,420)) and not game._walkable(Vector2(700,440)),'the harbour wall drops into water on both sides of the pier')
	check(not game._walkable(Vector2(400,530)),'sea blocks movement')
	check(game._walkable(Vector2(502,530)),'pier is walkable')
	# Tide forecast gates species by map, time, weather, and season.
	check(game._time_period(0.50)=='day' and game._time_period(0.25)=='dawn' and game._time_period(0.95)=='night','clock resolves fishing periods')
	check(game.fish_available('Sunrise bream','town',0.50,'clear','spring'),'daytime bream are available in spring')
	check(game.fish_available('Sunrise bream','town',0.50,'clear','winter') and not game.fish_available('Sunrise bream','town',0.95,'clear','winter'),'bream stay through winter days but not nights')
	check(game.fish_available('Moonfish','beach',0.75,'clear','autumn'),'moonfish follows an autumn dusk tide')
	check(not game.fish_available('Moonfish','beach',0.50,'clear','autumn'),'moonfish leaves after dusk')
	check(game.fish_available('Storm tuna','rocky',0.95,'storm','summer'),'storm tuna follows a summer storm night')
	check(not game.fish_available('Storm tuna','rocky',0.50,'storm','summer'),'storm tuna avoids daylight')
	# A winter night can empty the condition-filtered town pool. Empty pools must
	# not synthesize a map-only species or let a cast register an illegal catch.
	var pre_empty_town_map: String = game.current_map
	var pre_empty_town_player: Vector2 = game.player
	var pre_empty_town_time: float = game.time_of_day
	var pre_empty_town_weather: String = game.weather
	var pre_empty_town_season: String = game.season
	var pre_empty_town_fish_count: int = game.fish_count
	var pre_empty_town_shells: int = game.shells
	game.current_map='town'; game._build_map('town'); game.time_of_day=0.95; game.weather='clear'; game.season='winter'
	check(game._species_pool().is_empty(),'town winter night can have an empty tide pool')
	var empty_town_pick: Dictionary = game._pick_species('PERFECT')
	check(empty_town_pick.is_empty(),'empty town pool does not synthesize an illegal species')
	game.player=Vector2(502,530); game.fishing_state=game.FishingState.IDLE
	game._try_fish()
	check(game.fishing_state==game.FishingState.IDLE and game.shells==pre_empty_town_shells and game.fish_count==pre_empty_town_fish_count,'empty town pool refuses the cast without charging or registering a catch')
	game.cast_candidate={}; game._finish_cast()
	check(game.fishing_state==game.FishingState.IDLE and game.fish_count==pre_empty_town_fish_count,'empty candidate compatibility path cancels without registering a catch')
	game.current_map=pre_empty_town_map; game._build_map(pre_empty_town_map); game.player=pre_empty_town_player
	game.time_of_day=pre_empty_town_time; game.weather=pre_empty_town_weather; game.season=pre_empty_town_season
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
	check(game.tackle_cost()==0 and game.can_afford_tackle(),'default tackle is free and affordable')
	game.cycle_bait(); check(game.bait_name()=='Glowbait' and game.bait_cost()==2 and game.BAITS[game.bait_index].rarity_bonus>0.0 and game.BAITS[game.bait_index].escape_mult>1.0,'glowbait costs shells and adds a surge risk')
	game.cycle_rod(); check(game.rod_name()=='Fiberglass Rod' and game.rod_cost()==2 and game.RODS[game.rod_index].tension_mult<1.0 and game.RODS[game.rod_index].escape_mult>1.0,'fiberglass trades lower strain for a slower riskier bite')
	game.cycle_rod(); check(game.rod_name()=='Stormglass Rod' and game.rod_cost()==4 and game.RODS[game.rod_index].tension_mult>game.RODS[1].tension_mult and game.RODS[game.rod_index].escape_mult<game.RODS[1].escape_mult,'stormglass trades higher strain for escape control')
	game.cycle_bait(-1); game.cycle_rod(-2)
	game.shells=3; game.bait_index=1; game.rod_index=0; game._try_fish()
	check(game.shells==1 and game.fishing_state==game.FishingState.ANTICIPATING,'cast charges the explicit bait cost')
	game._reset_fishing(); game.shells=100; game.bait_index=0; game.rod_index=0
	game.fishing_state=game.FishingState.IDLE; game._try_fish()
	# Hot cues deliberately hold the bite back (up to +1.7s, see
	# EFFECTS_DESIGN.md), so tests wait long enough for any cue to bite.
	check(game.fishing_state==game.FishingState.ANTICIPATING,'fishing bite anticipation starts')
	var cast_species := str(game.cast_candidate.get('name',''))
	game._process_fishing(4.0)
	check(game.fishing_state==game.FishingState.TIMING,'bite opens timing window')
	game._resolve_fishing_timing(0.5)
	check(game.fishing_state==game.FishingState.RESULT and game.last_grade=='PERFECT','perfect timing resolves result')
	check(game.combo==1 and game.last_rarity!='','successful catch increments combo and rarity')
	check(game.last_catch==cast_species,'cast candidate is the authoritative resolved species')
	# Standard catches use a deterministic gacha-style reveal instead of
	# showing the species immediately: unknown -> rarity -> rising -> flip.
	check(game.reveal_stage==0 and game.reveal_stage_name()=='UNKNOWN','reveal starts as unknown silhouette')
	# Nothing rarity-correlated may show while the card is face-down: not the
	# toast bar, not the SELL/REGISTER prompt (it carries the sale value).
	check(not game.catch_reveal_complete() and game.catch_choice_pending(),'sell/register prompt is held back while the card is face-down')
	check(game.toast=='' and game.toast_t==0.0 and game.result_toast_pending.contains(cast_species),'catch toast waits for the reveal instead of naming the fish')
	game._process_fishing(0.45)
	check(game.reveal_stage==1 and game.reveal_stage_name()=='RARITY','reveal shows rarity seal')
	game._process_fishing(0.40)
	check(game.reveal_stage==2 and game.reveal_stage_name()=='RISING','reveal grows silhouette and light')
	game._process_fishing(0.60)
	check(game.reveal_stage==3 and game.reveal_stage_name()=='FLIPPING','reveal starts card flip')
	game._process_fishing(0.40)
	check(game.reveal_stage==4 and game.reveal_stage_name()=='REVEALED','reveal resolves fish name')
	check(game.catch_reveal_complete() and game.toast.contains(cast_species) and game.result_toast_pending=='','toast and prompt appear once the card has flipped')
	# A choice made while a reveal toast is still queued must keep its own
	# confirmation: the queued toast is dropped, not flushed over it.
	game.result_toast_pending='stale reveal toast'
	game.sell_pending_catch(); game._process_fishing(0.0)
	check(game.toast.begins_with('SOLD') and game.result_toast_pending=='','selling is confirmed instead of being overwritten by the reveal toast')
	# A stale queue cannot resurrect after the decision, even if a later frame
	# runs the normal reveal-toast flush path.
	var sold_confirmation: String = game.toast
	game.result_toast_pending='stale reveal toast'; game._process_fishing(0.0)
	check(game.toast==sold_confirmation and game.result_toast_pending=='','stale reveal toast stays cleared after selling')
	game._reset_fishing(); game.cast_candidate={'name':'Sunrise bream','rarity':'COMMON'}; game._resolve_fishing_timing(0.5)
	game.reveal_stage=4; game.reveal_t=2.0; game.result_toast_pending='stale reveal toast'
	game.register_pending_catch(); game._process_fishing(0.0)
	check(game.toast.begins_with('REGISTERED') and game.result_toast_pending=='','registering is confirmed instead of being overwritten by the reveal toast')
	check(game.LEGENDARY_RESULT_PROMOTION_Y < game.LEGENDARY_RESULT_CHOICE_Y and game.LEGENDARY_RESULT_CHOICE_Y <= 260.0,'legendary promotion and choice lines stay inside the viewport')
	check(game._legendary_reveal_art_target_rect(1.0).end.y <= game.LEGENDARY_RESULT_NAME_Y,'legendary reveal art stays above the name metadata row')
	game._reset_fishing()
	game.notebook_open=true; game._try_fish()
	check(game.cast_timer==0,'notebook prevents casting')
	game.notebook_open=false; game._try_fish()
	check(game.cast_timer>0,'valid cast starts timed sequence')
	check(game.fishing_state == game.FishingState.ANTICIPATING,'cast enters bite anticipation')
	game._process_fishing(4.0)
	game._resolve_fishing_timing(0.5)
	check(game.last_grade=='PERFECT' and game.combo>=1,'perfect timing awards grade and combo')
	# The cast keeps a PERFECT-pool candidate, while the mini-game grade still
	# changes quality: ordinary GOOD downgrades a high-rarity candidate to RARE,
	# whereas PERFECT adopts the candidate unchanged.
	var high_candidate: Dictionary = game._fish_entry('Twilight salmon').duplicate(true)
	game._reset_fishing(); game.cast_candidate=high_candidate.duplicate(true); game._resolve_fishing_timing(0.34)
	check(game.last_catch!=str(high_candidate.name) and game.last_rarity=='RARE' and game.last_catch_metadata.get('original_rarity','')=='EPIC' and game.last_catch_metadata.get('downgraded_from_species','')==str(high_candidate.name) and game.result_t<=2.0,'GOOD timing swaps EPIC candidate for a map-legal RARE without legendary reveal')
	game._reset_fishing(); game.cast_candidate=high_candidate.duplicate(true); game._resolve_fishing_timing(0.5)
	check(game.last_catch==str(high_candidate.name) and game.last_rarity=='EPIC' and game.last_catch_metadata.get('original_rarity','')=='EPIC','PERFECT timing keeps the cast candidate rarity')
	# The premium golden-tide cue is a cast-time guarantee: GOOD timing must not
	# downgrade either premium rarity, including the full Legendary reveal path.
	game._reset_fishing(); game.cast_candidate=high_candidate.duplicate(true); game.fx_premium=true; game._resolve_fishing_timing(0.34)
	check(game.last_catch==str(high_candidate.name) and game.last_rarity=='EPIC' and game.last_catch_metadata.get('original_rarity','')=='EPIC' and game.last_catch_metadata.get('downgraded_from_species','')=='','premium EPIC keeps its rarity on GOOD timing')
	var premium_legendary: Dictionary = game._fish_entry('Storm tuna').duplicate(true)
	game._reset_fishing(); game.cast_candidate=premium_legendary.duplicate(true); game.fx_premium=true; game._resolve_fishing_timing(0.34)
	check(game.last_catch==str(premium_legendary.name) and game.last_rarity=='LEGENDARY' and game.result_t>6.0 and game.result_toast_pending.begins_with('BIG CATCH!!'),'premium LEGENDARY keeps its rarity and reveal on GOOD timing')
	check(game._promotion_max_stage('COMMON')==1 and game._promotion_max_stage('UNCOMMON')==1 and game._promotion_max_stage('RARE')==2 and game._promotion_max_stage('EPIC')==3 and game._promotion_max_stage('LEGENDARY')==3,'promotion stage cap follows candidate rank')
	game.promotion_stage=3; game.promotion_reversal=true
	check(game._visible_promotion_stage()==2,'reversal visibly steps the float back one stage')
	game._reset_fishing(); game.cast_candidate=high_candidate.duplicate(true); game.promotion_cue_rank=3; game._resolve_fishing_timing(0.34)
	check(game.promotion_result_label.begins_with('惜しい') and game.last_rarity=='RARE','honest high preview to GOOD low result is labelled near miss')
	game._reset_fishing(); game.cast_candidate=game._fish_entry('Moonfish').duplicate(true); game.promotion_cue_rank=0; game._resolve_fishing_timing(0.5)
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
	# Rarer fish are rare, so a flat lie rate would make rainbow mostly bait.
	# Over many seeded Rocky casts a rainbow float must be honest more often than not.
	var saved_combo: int = game.combo
	var saved_clock := [game.time_of_day, game.weather, game.season]
	game._reset_fishing(); game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(497,151)
	game.combo=0; game.fever_active=false; game.rng.seed=31337
	# The species pool follows the tide, so the lie rate must follow the pool:
	# check a pool with several EPIC species and the town's single-EPIC pool.
	var honesty_envs := [['rocky',Vector2(497,151),0.95,'clear','autumn'],['rocky',Vector2(497,151),0.95,'rain','summer'],['rocky',Vector2(497,151),0.95,'storm','winter']]
	for env in honesty_envs:
		game.current_map=str(env[0]); game._build_map(str(env[0])); game.player=env[1]
		game.time_of_day=float(env[2]); game.weather=str(env[3]); game.season=str(env[4])
		game.combo=0; game.fever_active=false; game.rng.seed=31337
		var rainbow_total := 0
		var rainbow_honest := 0
		var purple_total := 0
		var purple_honest := 0
		for i in range(4000):
			game._reset_fishing(); game.shells=100; game._try_fish()
			if game.promotion_cue_rank>=3:
				rainbow_total+=1
				if not game.promotion_false_cue: rainbow_honest+=1
			elif game.promotion_cue_rank==2:
				purple_total+=1
				if not game.promotion_false_cue: purple_honest+=1
		var rainbow_rate := float(rainbow_honest)/float(maxi(1,rainbow_total))
		var purple_rate := float(purple_honest)/float(maxi(1,purple_total))
		check(rainbow_total>20 and rainbow_rate>=0.6,'a rainbow cue is mostly honest on %s %s/%s (%d/%d)' % [str(env[0]),str(env[3]),str(env[4]),rainbow_honest,rainbow_total])
		check(purple_total>40 and purple_rate>=0.5,'a purple cue is honest more often than not on %s %s/%s (%d/%d)' % [str(env[0]),str(env[3]),str(env[4]),purple_honest,purple_total])
	game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(497,151)
	game.time_of_day=0.95; game.weather='clear'; game.season='autumn'
	check(game._candidate_share_at_least(0)>0.99 and game._candidate_share_at_least(3)<game._candidate_share_at_least(2),'candidate rank shares are a decreasing probability')
	# GOOD substitutes come from the whole RARE pool, not always its first species.
	var substitute_names := {}
	game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(497,151)
	game.time_of_day=0.95; game.weather='clear'; game.season='autumn'
	for seed_value in range(1,60):
		game.rng.seed=seed_value
		substitute_names[str(game._pick_good_substitute(game._fish_entry('Twilight salmon')).get('name',''))]=true
	check(substitute_names.size()>1,'GOOD substitutes vary across the RARE pool')
	game._reset_fishing(); game.combo=saved_combo
	game.time_of_day=float(saved_clock[0]); game.weather=str(saved_clock[1]); game.season=str(saved_clock[2])
	game.current_map='town'; game._build_map('town'); game.player=Vector2(500,530)
	game._reset_fishing()
	game._reset_fishing()
	game._resolve_fishing_timing(0.1)
	check(game.last_grade=='MISS' and game.combo==0,'miss resets combo')
	# A broken chain says how close FEVER was instead of silently resetting.
	game._reset_fishing(); game._break_chain(); game.combo=2; game._resolve_fishing_timing(-1.0)
	check(game.chain_break_text.begins_with('惜しい') and game.toast.contains('one more catch for FEVER'),'losing a two-catch chain reads as a near miss for FEVER')
	game._reset_fishing(); game._break_chain(); game.combo=1; game._resolve_fishing_timing(-1.0)
	check(game.chain_break_text.contains('2 more for FEVER'),'a one-catch chain reports how many more catches FEVER needed')
	game._reset_fishing(); game._break_chain(); game.combo=0; game._resolve_fishing_timing(-1.0)
	check(game.chain_break_text=='' and not game.toast.contains('FEVER'),'a miss without a chain stays quiet')
	game._reset_fishing(); game.combo=4; game.fever_active=true; game.fever_t=10.0; game._resolve_fishing_timing(-1.0)
	check(game.chain_break_text.contains('FEVER lost') and not game.fever_active,'a miss during FEVER reports the lost chain')
	game._reset_fishing(); check(game.chain_break_text=='','the chain-break note clears with the next cast')
	game._reset_fishing()
	# Soft pity counts consecutive misses/low-grade outcomes and arms one
	# transparent rescue hook. The hook changes only the rarity floor; the
	# timing battle is still required for a real catch.
	game._reset_pity()
	game._advance_pity("MISS")
	check(is_equal_approx(game.rescue_forecast_bonus(),0.06) and game.pity_status().forecast_bonus>0.0,'first miss adds a visible forecast bonus')
	game._advance_pity("GOOD")
	check(game.rescue_forecast_bonus()>0.04 and game.pity_status().low_grade_streak==1,'low-grade catch strengthens the rescue forecast')
	game.current_map='town'; game._build_map('town'); game.player=Vector2(500,530); game.shells=100; game.bait_index=0; game.rod_index=0
	game._try_fish()
	game._process_fishing(game.bite_delay * 0.30)
	check(game.promotion_rescue_bonus>0.0 and game.promotion_stage>=1,'rescue forecast is disclosed on the promotion float')
	game._reset_fishing()
	game._reset_pity()
	for i in range(game.PITY_THRESHOLD):
		game._resolve_fishing_timing(-1.0)
		game._reset_fishing()
	check(game.pity_status().meter==game.PITY_THRESHOLD and game.pity_status().ready,'miss streak arms rescue hook')
	game.current_map='town'; game._build_map('town'); game.rng.seed=9182
	var rescued_pick: Dictionary = game._pick_species('GOOD', true)
	check(game._rarity_rank(str(rescued_pick.get('rarity','COMMON')))>=game._rarity_rank('RARE'),'armed rescue raises catch floor to rare')
	game.rng.seed=9183
	var rescued_cast: Dictionary = game._pick_cast_candidate(true)
	check(game._rarity_rank(str(rescued_cast.get('rarity','COMMON')))>=game._rarity_rank('RARE'),'pity threshold guarantees the next landed cast is rare-or-better')
	# This block moves to the rocky shore at night; restore the town pier and
	# clock afterwards so later save/position checks do not depend on it.
	var pre_6b_state := [game.current_map, game.player, game.time_of_day, game.weather, game.season]
	# Option 6b: the first two misses make purple-or-higher cues visibly more
	# likely, while the third miss remains the explicit RARE floor. The shares
	# use the same deterministic rarity weights as the natural cast roll.
	game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(497,151)
	game.time_of_day=0.95; game.weather='rain'; game.season='summer'; game.combo=0; game.fever_active=false
	game._reset_pity(); var purple_share_0: float = game._candidate_share_at_least(2)
	game._advance_pity('MISS'); var purple_share_1: float = game._candidate_share_at_least(2)
	game._advance_pity('MISS'); var purple_share_2: float = game._candidate_share_at_least(2)
	check(purple_share_1>purple_share_0 and purple_share_2>purple_share_1,'one and two misses monotonically lift PURPLE+ cue share')
	check(game.rescue_forecast_label().contains('PURPLE+ cue'),'rescue HUD names the PURPLE+ cue uplift')
	var rescue_eligible: Array[Dictionary] = []
	for fish in game._species_pool():
		if str(fish.get('rarity','COMMON')) != 'LEGENDARY': rescue_eligible.append(fish)
	game.rescue_ready=false; game.rng.seed=77123
	var natural_common := 0
	var natural_rare := 0
	for i in range(6000):
		var natural_weighted: Dictionary = game._pick_species('PERFECT', false, true)
		if str(natural_weighted.get('rarity','COMMON')) == 'COMMON': natural_common += 1
		elif str(natural_weighted.get('rarity','COMMON')) == 'RARE': natural_rare += 1
	game.rescue_ready=true; game.rng.seed=77123
	var rescued_rare := 0
	var rescued_epic := 0
	for i in range(6000):
		var rescued_weighted: Dictionary = game._apply_rescue_floor({'name':'Sunrise bream','rarity':'COMMON'}, rescue_eligible, 'PERFECT')
		if str(rescued_weighted.get('rarity','COMMON')) == 'RARE': rescued_rare += 1
		elif str(rescued_weighted.get('rarity','COMMON')) == 'EPIC': rescued_epic += 1
	check(natural_common>0 and natural_rare>0 and rescued_rare>0 and rescued_epic>0 and rescued_rare>rescued_epic*3 and rescued_rare>natural_rare,'rescue raises the floor while preserving rarity weights (%d natural common, %d/%d rare)' % [natural_common,natural_rare,rescued_rare])
	check(game._rarity_rank(str(game._apply_rescue_floor({'name':'Sunrise bream','rarity':'COMMON'}, rescue_eligible, 'PERFECT').get('rarity','COMMON')))>=game._rarity_rank('RARE'),'weighted rescue never drops below RARE')
	game.fishing_state=game.FishingState.RESULT; game.last_grade='PERFECT'; game.last_rarity='RARE'
	check(game._result_reveal_hud_reserved(),'result reveal reserves rarity rows from CHAIN/RESCUE HUD')
	game.last_grade='MISS'; game.last_rarity=''
	check(not game._result_reveal_hud_reserved(),'miss result keeps ambient CHAIN/RESCUE HUD available')
	game._reset_fishing(); game._reset_pity()
	game.current_map=str(pre_6b_state[0]); game._build_map(game.current_map); game.player=pre_6b_state[1]
	game.time_of_day=float(pre_6b_state[2]); game.weather=str(pre_6b_state[3]); game.season=str(pre_6b_state[4])
	game._reset_pity()
	game.pity_meter=2; game.low_grade_streak=2; game.rescue_ready=false
	game._save_game('res://.smoke-pity-test.json')
	game._reset_pity(); game._load_game('res://.smoke-pity-test.json')
	check(game.pity_meter==2 and game.low_grade_streak==2 and not game.rescue_ready,'save restores pity meter without arming early')
	game.pity_meter=game.PITY_THRESHOLD; game.rescue_ready=true
	game._reset_fishing()
	# The first-capture checks below need a species that is genuinely new.  A
	# seeded roll would silently depend on every earlier cast and on the rarity
	# weights, so pin the cast to an undiscovered RARE/EPIC species instead.
	var first_pick: Dictionary = {}
	for fish in game.FISH_SPECIES:
		if str(fish.rarity) in ['RARE','EPIC'] and not game.species_discovered(str(fish.name)):
			first_pick = fish.duplicate(true); break
	check(not first_pick.is_empty(),'an undiscovered rare species remains for first-capture checks')
	game.rng.seed=2026
	game.cast_candidate=first_pick
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
	check(not game.best_records.has(first_species),'an unregistered first capture is only a crown candidate')
	check(game._record_is_better({'size_cm':42.0,'weight_kg':2.0},{'size_cm':42.0,'weight_kg':1.9}),'heavier equal-size specimen can take the crown')
	check(not game._record_is_better({'size_cm':41.9,'weight_kg':9.0},{'size_cm':42.0,'weight_kg':1.0}),'smaller specimen cannot displace a size crown')
	# A catch remains on the result card until the player explicitly chooses a
	# disposition. Saving at that point must preserve the held fish and its
	# deterministic sale value.
	check(game.catch_choice_pending() and game.pending_catch_species()==first_species,'catch opens an explicit sell-or-register choice')
	var pending_shells: int = game.shells
	var pending_count := int(game.catches.get(first_species,0))
	var pending_value: int = game.pending_catch_sell_value()
	var pending_register_value: int = game.pending_catch_register_value()
	var pending_rarity := str(first_meta.get('rarity','COMMON'))
	check(pending_register_value==game.REGISTER_BASE_REWARD+int(game.REGISTER_FIRST_BONUS[pending_rarity])+game.REGISTER_CROWN_BONUS,'registering a first-capture crown pays the base reward plus both bonuses')
	check(pending_register_value>1 and game._register_value({'rarity':'COMMON','first_capture':false,'crown':false})==game.REGISTER_BASE_REWARD,'a plain repeat registers for the base reward only')
	game._save_game('res://.smoke-pending-catch.json')
	game._reset_fishing()
	game._load_game('res://.smoke-pending-catch.json')
	check(game.catch_choice_pending() and game.pending_catch_sell_value()==pending_value,'save restores pending catch choice without rerolling value')
	check(bool(game.pending_catch.get('metadata',{}).get('first_capture',false)) and not game.reveal_shortened,'pending first-capture metadata survives save/load')
	check(game.shells==pending_shells and int(game.catches.get(first_species,0))==pending_count,'pending choice does not duplicate currency or inventory')
	check(game.register_pending_catch() and not game.catch_choice_pending() and game.shells==pending_shells+pending_register_value,'register keeps fish and pays its reward once')
	check(game.best_records.has(first_species) and float(game.best_records[first_species].get('size_cm',0.0))>=first_size-0.001,'registering a crown candidate writes the size record')
	check(game.best_records[first_species].has('map') and game.best_records[first_species].has('spot'),'crown record keeps its catch location')
	# A repeat updates the current reveal while leaving the discovery record intact.
	game._record_catch_metadata({'name':first_species,'rarity':str(first_meta.get('rarity','COMMON'))},'GOOD')
	check(is_equal_approx(float(game.get_first_capture_metadata(first_species).get('size_cm',0.0)),first_size) and game.catch_latest.has(first_species),'first capture metadata is immutable across repeats')
	check(game.reveal_shortened,'repeat catch uses shortened reveal')
	var repeat_size := float(game.last_catch_metadata.get('size_cm',0.0))
	var repeat_record_size := float(game.best_records[first_species].get('size_cm',0.0))
	check(bool(game.last_catch_metadata.get('crown', false)) == (repeat_size > repeat_record_size + 0.001),'repeat crown flag marks a candidate only when it beats the registered record')
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
	check(game.get_first_capture_metadata(first_species).has('size_cm') and game.best_records.has(first_species),'selling preserves discovery and the already-registered crown')
	# Selling a record-breaking specimen keeps the species discovered but does not
	# take the crown; registering the next record-breaker does.
	game.best_records[first_species]={'species':first_species,'size_cm':0.1,'weight_kg':0.01,'day':1,'map':'town','spot':'test'}
	game._reset_fishing(); game.cast_candidate={'name':first_species,'rarity':first_rarity}; game._resolve_fishing_timing(0.5)
	var sold_crown_candidate := bool(game.last_catch_metadata.get('crown', false))
	game.sell_pending_catch()
	check(sold_crown_candidate and is_equal_approx(float(game.best_records[first_species].get('size_cm',0.0)),0.1),'selling a record specimen does not take the crown')
	check(game.species_discovered(first_species),'selling a record specimen still keeps the species discovered')
	game._reset_fishing(); game.cast_candidate={'name':first_species,'rarity':first_rarity}; game._resolve_fishing_timing(0.5)
	var registered_size := float(game.last_catch_metadata.get('size_cm',0.0))
	var crown_register_value: int = game.pending_catch_register_value()
	check(bool(game.last_catch_metadata.get('crown', false)) and crown_register_value==game.REGISTER_BASE_REWARD+game.REGISTER_CROWN_BONUS,'a repeat crown candidate earns the crown bonus on register')
	game.register_pending_catch()
	check(is_equal_approx(float(game.best_records[first_species].get('size_cm',0.0)),registered_size),'registering a record specimen takes the crown')
	# A save written after a sold record must not resurrect it from catch_latest.
	game.best_records[first_species]={'species':first_species,'size_cm':0.1,'weight_kg':0.01,'day':1,'map':'town','spot':'test'}
	game._save_game('res://.smoke-sold-crown.json'); game._load_game('res://.smoke-sold-crown.json')
	check(is_equal_approx(float(game.best_records[first_species].get('size_cm',0.0)),0.1),'loading does not rebuild crowns from sold specimens')
	# Selling the final copy keeps the field-guide name visible because durable
	# discovery metadata is distinct from transient inventory ownership.
	game._reset_fishing(); game.catches.erase('Sunrise bream'); game.cast_candidate={'name':'Sunrise bream','rarity':'COMMON'}; game._resolve_fishing_timing(0.5)
	game.sell_pending_catch()
	check(int(game.catches.get('Sunrise bream',0))==0 and game.species_discovered('Sunrise bream') and game._ledger_marker('Sunrise bream',0)!='?','selling last copy keeps ledger discovery visible')
	# Whether the bream was a repeat depends on earlier casts, so use a species that
	# is certainly already in the ledger to check the shortened reveal.
	game._reset_fishing(); game.cast_candidate={'name':first_species,'rarity':first_rarity}; game._resolve_fishing_timing(0.5)
	check(game.reveal_shortened and (game.last_rarity == 'LEGENDARY' or game._reveal_stage_at(1.12,game.last_rarity)==4),'shortened reveal reaches face before standard timing')
	game.sell_pending_catch()
	game.weather='rain'; game.season='autumn'; game.time_of_day=0.74
	var saved_fish=game.fish_count
	game._save_game('res://.smoke-smoke-test.json')
	game.player=Vector2(368,372); game.fish_count=999; game.catches={}; game.weather='clear'; game.season='spring'; game.time_of_day=0.35
	game.catch_metadata={}; game.first_capture_metadata={}; game.catch_latest={}
	game._load_game('res://.smoke-smoke-test.json')
	check(game.fish_count==saved_fish and game.catches.size()>=1,'save restores ledger and count')
	check(game.weather=='rain' and game.season=='autumn' and is_equal_approx(game.time_of_day,0.74),'save restores tide forecast')
	game.weather='clear'; game.season='spring'; game.time_of_day=0.35
	check(game.get_first_capture_metadata(first_species).has('size_cm') and is_equal_approx(float(game.get_first_capture_metadata(first_species).get('size_cm',0.0)),first_size),'save restores first capture metadata')
	check(game.player.distance_to(Vector2(500,530))<2,'save restores valid position')
	game.player=Vector2(368,372); game.cast_timer=0; game._try_fish()
	check(game.cast_timer==0,'inland cast rejected')
	# Old v2 saves may place the hero in the sea: keep a safe spawn.
	var f=FileAccess.open('res://.smoke-legacy-test.json',FileAccess.WRITE)
	f.store_string('{"fish":5,"x":950,"y":600}'); f.close()
	game._load_game('res://.smoke-legacy-test.json')
	check(game._walkable(game.player) and game.fish_count==5,'legacy unsafe position handled')
	# Map transitions fade, rebuild props, and preserve shared progress.
	game.current_map='town'; game._build_map('town'); game._transition_to('beach',Vector2(400,80)); game._process(0.5)
	check(game.current_map=='beach' and game.player==Vector2(400,80),'town to beach transition')
	game._transition_to('rocky',Vector2(90,340)); game._process(0.5)
	check(game.current_map=='rocky' and game.fish_count==5,'beach to rocky preserves ledger')
	game._save_game('res://.smoke-map-test.json'); game.current_map='town'; game._build_map('town'); game._load_game('res://.smoke-map-test.json')
	check(game.current_map=='rocky','save restores active map')
	game.current_map='town'; game._build_map('town'); game.player=Vector2(992,520); game._check_map_exit()
	check(game._walkable(Vector2(992,520)) and game.transition_target=='beach' and game.transition_spawn==Vector2(400,80),'town beach exit is reachable')
	game.transition_active=false
	# Walk the real runtime path (move, then exit check): the south road must reach
	# the pier's fishing spot, and stepping off it must not leave town.
	game.player=Vector2(500,425)
	check(walk_to(game,Vector2(502,530)) and not game.transition_active and game._can_fish(),'walking the south road reaches the pier without leaving town')
	check(walk_to(game,Vector2(500,425)) and not game.transition_active,'walking back off the pier stays in town')
	# The quay leads east to the sand: off the east edge for the rocky shore,
	# down onto the east beach for Amber Beach. Neither gate is on the pier.
	check(walk_to(game,Vector2(500,392)) and walk_to(game,Vector2(986,392)) and not game.transition_active,'the quay runs from the pier to the east sand')
	check(not game._can_fish() and game._can_fish_at(Vector2(700,392)) and not game._can_fish_at(Vector2(560,300)),'town casts from the quay edge, not the plaza or the east sand')
	check(walk_to(game,Vector2(1012,380)) and game.transition_active and game.transition_target=='rocky','walking off the east edge leaves for the rocky shore')
	game.transition_active=false; game.player=Vector2(986,392)
	check(walk_to(game,Vector2(958,392)) and walk_to(game,Vector2(958,466)) and walk_to(game,Vector2(992,470)) and not game.transition_active,'the sand path leads down to the east beach')
	check(walk_to(game,Vector2(992,518)) and game.transition_active and game.transition_target=='beach','walking down the east beach leaves for Amber Beach')
	game.transition_active=false
	# Both rumor sources stand somewhere the hero can actually reach.
	for rumor_key in game.RUMOR_SOURCES:
		var rumor_reachable := false
		for dx in range(-24,25,8):
			for dy in range(-24,25,8):
				if Vector2(dx,dy).length()<game.RUMOR_TALK_RADIUS-4.0 and game._walkable(game.RUMOR_SOURCES[rumor_key].pos+Vector2(dx,dy)): rumor_reachable = true
		check(rumor_reachable,'%s can be walked up to' % game.RUMOR_SOURCES[rumor_key].label)
	# The pier is town geometry; the same rectangle is open water elsewhere.
	game.current_map='beach'; game._build_map('beach')
	check(not game._walkable(Vector2(502,530)),'beach has no phantom pier')
	game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(300,400)
	check(walk_to(game,Vector2(300,485)) and not game.transition_active and game._can_fish(),'rocky lower bank is walkable and fishable')
	game.player=Vector2(420,440)
	check(walk_to(game,Vector2(420,475)) and game.transition_target=='beach' and game.transition_spawn==Vector2(770,390),'rocky beach gate leads to the east side of the beach')
	game.transition_active=false
	# Every connection: the trigger can be stood in, and its spawn is walkable,
	# outside every trigger of the destination (no bounce) and has a way back.
	var unlocked_before: bool = game.hidden_spot_unlocked; game.hidden_spot_unlocked=true
	for map_name in game.MAP_EXITS:
		for entry in game.MAP_EXITS[map_name]:
			var route := '%s -> %s' % [map_name, entry.to]
			game.current_map=map_name; game._build_map(map_name)
			var standable := false
			for x in range(int(entry.zone.position.x), int(entry.zone.end.x), 4):
				for y in range(int(entry.zone.position.y), int(entry.zone.end.y), 4):
					if game._walkable(Vector2(x,y)): standable = true
			check(standable,'exit trigger is reachable: '+route)
			for spot in game._fishing_spots():
				check(not entry.zone.has_point(spot.pos),'exit trigger leaves %s fishable: %s' % [spot.label, route])
			game.current_map=str(entry.to); game._build_map(game.current_map)
			var clear: bool = game._walkable(entry.spawn)
			var way_back := str(entry.to) == 'grotto'
			for back in game.MAP_EXITS[entry.to]:
				if back.zone.has_point(entry.spawn): clear = false
				if str(back.to) == map_name: way_back = true
			check(clear,'spawn is walkable and outside every trigger: '+route)
			check(way_back,'destination has a return exit: '+route)
	# Every painted signboard carries its whole name, centred on the board.
	check(game._static_map_signs('town').is_empty() and game._static_map_signs('beach').size()==3 and game._static_map_signs('rocky').size()==4 and game._static_map_signs('grotto').size()==1,'each art map lists its signboards')
	for map_name in ['beach','rocky','grotto']:
		for sign_entry in game._static_map_signs(map_name):
			var sign_layout: Dictionary = game._static_sign_layout(sign_entry)
			if not sign_layout.on_board:
				check(sign_layout.pos.x>=0.0 and sign_layout.pos.x+sign_layout.width<=game.WORLD_SIZE.x,'%s caption stays inside the world' % sign_entry.text)
				continue
			var sign_board: Rect2 = sign_layout.board
			check(sign_layout.pos.x>=sign_board.position.x+game.STATIC_SIGN_MARGIN-0.5 and sign_layout.pos.x+sign_layout.width<=sign_board.end.x-game.STATIC_SIGN_MARGIN+0.5,'%s fits on its signboard' % sign_entry.text)
			check(absf(sign_layout.pos.x+sign_layout.width*0.5-sign_board.get_center().x)<=1.0 and sign_layout.pos==sign_layout.pos.round() and sign_layout.pos.y>sign_board.position.y and sign_layout.pos.y<sign_board.end.y,'%s is centred on its signboard' % sign_entry.text)
			check(sign_layout.size>=game.STATIC_SIGN_MIN_FONT_SIZE,'%s stays at a readable size' % sign_entry.text)
	# Every exit signpost fits its whole label and stays inside the world.
	for map_name in game.MAP_EXITS:
		game.current_map=map_name; game._build_map(map_name)
		for marker in game._exit_markers():
			var board: Rect2 = game._exit_sign_board(marker)
			var text_width: float = game._exit_sign_text_width(marker.label)
			check(text_width>0.0 and board.size.x>=text_width+game.EXIT_SIGN_PADDING*2.0-0.5,'%s sign in %s is wide enough for its label' % [marker.label, map_name])
			check(board.position.x>=0.0 and board.end.x<=game.WORLD_SIZE.x,'%s sign in %s stays inside the world' % [marker.label, map_name])
	game.hidden_spot_unlocked=unlocked_before
	# Each map exposes named, local fishing landmarks as well as its shoreline.
	game.current_map='beach'; game._build_map('beach'); game.player=Vector2(205,157)
	check(game._can_fish() and game._fishing_spots().size()==2,'beach tide pools are fishable')
	game.player=Vector2(300,300)
	check(not game._can_fish(),'beach inland cast rejected')
	game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(497,151)
	check(game._can_fish() and game._fishing_spots().size()==2,'rocky tide pools are fishable')
	# The unlocked cove is a real map transition, not only a hidden fishing spot
	# layered onto Rocky Shore. Its save/load state and local pool remain stable.
	game.hidden_spot_unlocked=true; game.hidden_spot_collected=true; game.transition_active=false
	game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(780,460); game._check_map_exit()
	check(game.transition_target=='grotto','rocky grotto exit is gated and reachable')
	game._transition_to('grotto',Vector2(510,150)); game._process(0.5)
	check(game.current_map=='grotto' and game.player==Vector2(510,150),'grotto transition rebuilds the map')
	check(game._walkable(Vector2(32,340)) and not game._walkable(Vector2(512,300)) and game._walkable(Vector2(512,520)),'grotto west route and lagoon collision')
	var grotto_exit: Dictionary = game._exit_markers()[0]
	check(grotto_exit.pos==Vector2(40,340) and grotto_exit.dir==Vector2(-1,0),'grotto uses a west-edge return marker')
	game.player=Vector2(512,520)
	check(game._can_fish() and game._fishing_spots().size()==1 and game._at_hidden_fishing_spot(),'grotto moonlit pool is fishable')
	game._save_game('res://.smoke-grotto-map-test.json'); game.current_map='town'; game._build_map('town'); game._load_game('res://.smoke-grotto-map-test.json')
	check(game.current_map=='grotto' and game._fishing_spots().size()==1,'save restores the grotto map')
	var malformed_grotto_save={"map":"grotto","x":512.0,"y":300.0}
	var malformed_file=FileAccess.open('res://.smoke-grotto-invalid-test.json',FileAccess.WRITE); malformed_file.store_string(JSON.stringify(malformed_grotto_save)); malformed_file.close()
	game.player=Vector2(700,700); game._load_game('res://.smoke-grotto-invalid-test.json')
	check(game.current_map=='grotto' and game.player==Vector2(510,150) and game._walkable(game.player),'invalid grotto save falls back to safe spawn')
	game.player=Vector2(32,340); game.transition_active=false; game._check_map_exit(); game._process(0.5)
	check(game.current_map=='rocky' and game.player==Vector2(90,340) and game._walkable(game.player),'grotto returns to rocky shore via west edge')
	# Battle lasts through multiple spaced inputs; a single tap is not a catch.
	game.transition_active=false
	game.notebook_open=false
	game._reset_fishing(); game._break_chain(); game.combo=2
	game.player=Vector2(497,151)
	# Use a legal rocky tide for the battle probes; empty pools now refuse casts.
	game.time_of_day=0.50; game.weather='clear'; game.season='summer'
	game._try_fish(); game._process_fishing(4.0)
	check(game.fish_hp_max==game.FISH_STAMINA and game.timing_timer==20.0,'battle starts with stamina and a 20 second limit')
	var chain_stamina: int = game.fish_hp_max
	game._reset_fishing(); game._break_chain(); game._try_fish(); game._process_fishing(4.0)
	check(game.fish_hp_max==chain_stamina,'a longer chain does not raise fish stamina')
	game._reset_fishing(); game._break_chain(); game.combo=2; game._try_fish(); game._process_fishing(4.0)
	var before_battle=game.fish_count
	game._handle_fishing_strike(0.5)
	check(game.fish_count==before_battle and game.battle_hits==0,'initial tug cooldown rejects instant catch')
	game._process_fishing(game.FIRST_PULL_DELAY+0.05)
	game._handle_fishing_strike(0.5)
	check(game.fishing_state==game.FishingState.TIMING and game.fish_hp==game.FISH_STAMINA-2,'first perfect pull wears fish down but does not finish')
	game._handle_fishing_strike(0.5)
	check(game.battle_hits==1,'rapid repeated inputs cannot skip battle')
	for i in range(4):
		game._process_fishing(game.PULL_COOLDOWN+0.05)
		game._handle_fishing_strike(0.5)
	check(game.fishing_state==game.FishingState.RESULT and game.last_rarity != '' and game.battle_hits==5, 'five perfect pulls resolve a catch without guaranteed legendary')
	check(game.battle_elapsed>=4.0 and game.battle_elapsed<8.0 and game.fish_count==before_battle+1,'battle takes several spaced pulls, not a long wait, and counts once')
	if game.last_rarity == 'LEGENDARY':
		check(game.legendary_t==0.0 and game.result_t>6.0,'legendary starts its six second staged celebration')
		game._process_fishing(1.0); check(game.legendary_stage==1,'legendary advances to rising energy')
		game._process_fishing(1.2); check(game.legendary_stage==2,'legendary advances to full screen climax')
		game._process_fishing(1.7); check(game.legendary_stage==3,'legendary advances to afterglow')
	else:
		check(game.last_rarity in ['COMMON','UNCOMMON','RARE','EPIC'],'bounded rarity result is valid')
	game._reset_fishing(); game._try_fish(); game._process_fishing(4.0)
	game._process_fishing(1.1)
	game._handle_fishing_strike(0.0)
	check(game.fishing_state==game.FishingState.TIMING and game.battle_tension>0.4,'bad pull strains the line without instant failure')
	# The gauge alone decides a pull; the challenge zone is only a bonus.
	for seed in range(4):
		game._reset_fishing(); game._break_chain(); game.combo=2; game._try_fish(); game._process_fishing(4.0)
		game.fishing_challenge.configure(3,2,seed)
		var style: String = game.fishing_challenge.current_game_name()
		while game.pull_cooldown>0.0: game._process_fishing(1.0/60.0)
		check(game.fishing_challenge.grace_t>0.8,'%s grace is still open when the first pull becomes available' % style)
		game.battle_direction=1.0; game.direction_timer=9.0
		for frame in range(120): game._process_fishing(1.0/60.0)
		check(game.fishing_challenge.grace_t==0.0,'%s grace runs out while a pull is available' % style)
		if style=='TIDE SLALOM':
			check(game.fishing_challenge.safe_lane()==-1.0 and game._challenge_prompt().contains('LEFT'),'slalom lane matches the HOLD LEFT counter prompt')
			game.battle_direction=-1.0; game._process_fishing(0.01)
			check(game.fishing_challenge.safe_lane()==1.0 and game._challenge_prompt().contains('RIGHT'),'slalom lane follows the fish when it turns')
		var tension_before: float = game.battle_tension; var escape_before: float = game.battle_escape
		game._handle_fishing_strike(0.79 if game.fishing_challenge.target_center()<0.53 else 0.27)
		check(game.battle_hits==1 and game.fish_hp==game.FISH_STAMINA-1 and game.fishing_challenge.round_index==0 and game.fishing_challenge.action_progress==0,'%s: a GOOD pull outside the bonus zone still counts' % style)
		check(is_equal_approx(game.battle_tension,tension_before+game.GOOD_PULL_TENSION) and game.battle_escape<=escape_before,'%s: a GOOD pull outside the bonus zone is not punished' % style)
		game.pull_cooldown=0.0; tension_before=game.battle_tension
		var beat_at: float = game.fishing_challenge.target_center()
		var beat_tension: float = game.PERFECT_PULL_TENSION if beat_at>=0.42 and beat_at<=0.62 else game.GOOD_PULL_TENSION
		game._handle_fishing_strike(beat_at,game.fishing_challenge.safe_lane())
		check(is_equal_approx(game.battle_tension,tension_before+beat_tension-game.CLEAN_BEAT_TENSION_RELIEF),'%s: a clean beat eases the line' % style)
		game.pull_cooldown=0.0; game.battle_tension=0.2
		var beats_before: int = game.fishing_challenge.action_progress; var round_before: int = game.fishing_challenge.round_index
		game._handle_fishing_strike(0.1,game.fishing_challenge.safe_lane())
		check(game.fishing_challenge.action_progress==beats_before and game.fishing_challenge.round_index==round_before and game.battle_tension>0.5,'%s: a pull off the gauge strains the line and earns no beat' % style)
	game.battle_tension=0.9; game.pull_cooldown=0.0; game._handle_fishing_strike(0.0)
	check(game.last_grade=='MISS' and game.combo==0,'repeated bad pulls can snap the line and reset combo')
	game._reset_fishing()
	check(game.fish_hp==0 and game.battle_hits==0 and game.legendary_t==0.0,'reset clears battle and celebration state')
	game._try_fish(); game._process_fishing(4.0); game._process_fishing(21.0)
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
	game._reset_fishing(); game._break_chain(); game.combo=2; game.player=Vector2(497,151)
	game._try_fish(); game._process_fishing(4.0)
	check(game.fishing_challenge != null and game.fishing_challenge.rounds.size()==4,'bite configures the four-round challenge chain')
	# Use the real moving gauge at 60fps, rather than injecting perfect positions.
	# This proves each rotated chain can be caught through the normal key path.
	for seed in range(4):
		game._reset_fishing(); game._break_chain(); game.combo=2
		game._try_fish(); game._process_fishing(4.0)
		game.fishing_challenge.configure(3,2,seed)
		for frame in range(1200):
			if game.fishing_state != game.FishingState.TIMING: break
			game._process_fishing(1.0/60.0)
			var target = game.fishing_challenge.target_center()
			var half_width = game.fishing_challenge.target_width()*0.5
			if game.pull_cooldown<=0.0 and game.gauge>=0.42 and game.gauge<=0.62 and absf(game.gauge-target)<=half_width:
				game._handle_fishing_strike(game.gauge)
		check(game.fishing_challenge.done and game.fishing_state==game.FishingState.RESULT,'moving gauge completes rotated chain %d within time limit' % seed)
	check(game.FISH_SPECIES.size()==25,'approved field guide has 25 species')
	check(game.fish_asset_manifest.get('approved_fish',[]).size()==25 and game.fish_asset_by_id.size()==25,'fish_name_mapping.json loads all approved species')
	var mapped_ids: Array[String] = []
	for field_fish in game.FISH_SPECIES: mapped_ids.append(str(field_fish.get('id','')))
	check(mapped_ids.size()==25 and not mapped_ids.has('') and game.fish_asset_by_id.keys().size()==mapped_ids.size(),'each active species has an explicit approved asset id')
	check(game.FISH_SPECIES.any(func(f): return f.rarity=='EPIC') and game.FISH_SPECIES.any(func(f): return f.rarity=='LEGENDARY'),'field guide includes epic and legendary')
	check(game.fish_cards.has('Amber anchovy') and game.fish_cards.has('Sunrise bream') and game.fish_cards.has('Moonfish') and game.fish_cards['Amber anchovy'].get_width()>500,'encyclopedia loads approved fish card art')
	check(game.fish_cards.has('Storm tuna') and game.fish_portraits.has('Storm tuna'),'legendary art assets are available for discovered entries')
	var missing_card_art: Array[String] = []
	var missing_portrait_art: Array[String] = []
	for field_fish in game.FISH_SPECIES:
		var field_name := str(field_fish.name)
		if not game.fish_cards.has(field_name): missing_card_art.append(field_name)
		if not game.fish_portraits.has(field_name): missing_portrait_art.append(field_name)
	check(missing_card_art.is_empty() and missing_portrait_art.is_empty(),'expanded field guide has card and reveal art for every species')
	var expanded_fish_names := ['Amber anchovy','Sunrise bream','Moonfish','Aurora koi','Coral grouper','Jellyfish fish','Tropical angelfish','Shadow flounder','Starry fish','Reef butterflyfish','Crystal fish','Sand flatfish','Night angler','Pearl seabass','Fire scorpionfish','Seahorse','Mint wrasse','Jellyfish butterflyfish','Storm tuna','Coral rabbitfish','Twilight salmon','Ghost fish','Harvest puffer','Lantern fish','Tidepool blenny']
	var missing_expanded_art: Array[String] = []
	for expanded_name in expanded_fish_names:
		if not game.fish_cards.has(expanded_name) or not game.fish_portraits.has(expanded_name): missing_expanded_art.append(expanded_name)
	check(expanded_fish_names.size()==25 and missing_expanded_art.is_empty(),'all approved fish have matching card and reveal art')
	check(game._reveal_art_source('Amber anchovy')=='card','catch reveal prefers the matching encyclopedia card art')
	check(game._draw_reveal_fish(Vector2(240,137),1.0,Color.WHITE,true,1.0,'Amber anchovy'),'catch reveal uses the matching species illustration')
	# Art stems intentionally preserve punctuation and repeated internal spaces;
	# this keeps the documented loader contract honest for future species names.
	check(game._fish_art_stem('  Kelp Runner  ')=='kelp_runner','art stem trims edges and replaces literal spaces')
	check(game._fish_art_stem("Angler-Fish")=='angler-fish','art stem preserves punctuation')
	check(game._fish_art_stem("Angler's  Fish")=="angler's__fish",'art stem preserves repeated spaces')
	var legendary_ledger_name := 'Storm tuna'
	game.catches.erase(legendary_ledger_name); game.catch_metadata.erase(legendary_ledger_name); game.first_capture_metadata.erase(legendary_ledger_name); game.catch_latest.erase(legendary_ledger_name)
	check(game.ledger_display_name(legendary_ledger_name,0)=='???','uncaught legendary encyclopedia card stays hidden as ???')
	check(not game._fish_art_visible(legendary_ledger_name,0),'uncaught legendary illustration stays masked')
	game.catches[legendary_ledger_name]=1
	check(game.ledger_display_name(legendary_ledger_name,1)==legendary_ledger_name,'caught legendary reveals its encyclopedia name')
	check(game._fish_art_visible(legendary_ledger_name,1),'caught legendary illustration becomes visible')
	game.catches.erase(legendary_ledger_name); game.catch_metadata[legendary_ledger_name]={"species":legendary_ledger_name,"rarity":"LEGENDARY"}
	check(game.ledger_display_name(legendary_ledger_name,0)==legendary_ledger_name and game.species_discovered(legendary_ledger_name,0),'selling the last legendary copy preserves its durable discovery')
	game.catch_metadata.erase(legendary_ledger_name)
	# Rumors: SPACE beside Fisher Mera or the notice tells the next unheard rumor.
	# The grotto opens when the guide is 25% full, not after a handful of fish.
	var rumor_clock := [game.time_of_day, game.weather, game.season]
	var kept_catches: Dictionary = game.catches.duplicate(true)
	var kept_catch_metadata: Dictionary = game.catch_metadata.duplicate(true)
	var kept_first_metadata: Dictionary = game.first_capture_metadata.duplicate(true)
	var kept_latest: Dictionary = game.catch_latest.duplicate(true)
	game.catches.clear(); game.catch_metadata.clear(); game.first_capture_metadata.clear(); game.catch_latest.clear()
	game.rumor_found=false; game.hidden_spot_unlocked=false; game.fish_count=0; game.heard_rumors=[]
	game.current_map='town'; game._build_map('town'); game.player=game.RUMOR_SOURCES.mera.pos
	check(game.rumor_source_near()=='mera','Fisher Mera can be talked to')
	check(game.talk_to_rumor_source() and game.rumor_found and game.heard_rumors==['grotto'],'fisher NPC tells the grotto rumor first')
	check(game.toast.contains('Fisher Mera') and game.toast.contains('grotto'),'a heard rumor is shown in the toast bar')
	check(game.talk_to_rumor_source() and game.heard_rumors.size()==2 and game.heard_rumors[1]=='Moonfish','Mera tells a different rumor each time she is asked')
	game.player=game.RUMOR_SOURCES.notice.pos
	check(game.rumor_source_near()=='notice','the weathered notice can be read')
	game.rumor_found=false; game.heard_rumors=[]
	check(game.talk_to_rumor_source() and game.rumor_found,'weathered notice reveals the grotto rumor')
	check(game.talk_to_rumor_source() and game.heard_rumors==['grotto','Fire scorpionfish'],'notice moves on to a species rumor')
	game.player=Vector2(300,250)
	check(game.rumor_source_near()=='' and not game.talk_to_rumor_source(),'no rumor is available away from the plaza')
	game.player=game.RUMOR_SOURCES.mera.pos
	for i in range(8): game.talk_to_rumor_source()
	var heard_after_all: int = game.heard_rumors.size()
	check(game.heard_rumors.has('Night angler') and game.talk_to_rumor_source() and game.heard_rumors.size()==heard_after_all and game.toast.contains('nothing new'),'an exhausted source says it has nothing new')
	# Rumors become a readable hint, and the ledger shows what is biting right now.
	check(game.fish_condition_hint('Moonfish')=='Moonfish: dusk or night / clear or rain / autumn or winter','species rumors are generated from the real condition table')
	check(game.fish_condition_hint('Night angler')=='Night angler: night / not overcast / not spring','a missing season reads as "not <season>"')
	# Field-guide reach: no map is dead for a whole season, the beach always has a
	# daytime bite, and every species has at least one tide it can be caught in.
	var guide_times := {'night':0.0,'dawn':0.25,'day':0.5,'dusk':0.75}
	var guide_legendary: Array = []
	for fish in game.FISH_SPECIES:
		if fish.rarity=='LEGENDARY': guide_legendary.append(fish.name)
	for guide_map in ['town','beach','rocky']:
		for guide_season in game.SEASON_NAMES:
			var alive := false
			for guide_weather in game.WEATHER_NAMES:
				for guide_time in guide_times:
					for species in game.available_fish(guide_map,guide_times[guide_time],guide_weather,guide_season):
						if not guide_legendary.has(species): alive = true
			check(alive,'%s has ordinary fish at some tide in %s' % [guide_map, guide_season])
	for guide_season in game.SEASON_NAMES:
		for guide_weather in game.WEATHER_NAMES:
			check(game.available_fish('beach',0.5,guide_weather,guide_season).size()>0,'beach has a daytime bite in %s %s' % [guide_season, guide_weather])
	for fish in game.FISH_SPECIES:
		var conditions: Dictionary = game._fish_conditions(fish.name)
		check(conditions.times.size()>0 and conditions.weather.size()>0 and conditions.seasons.size()>0,'%s has a reachable tide window' % fish.name)
	# A pool holding only a legendary must refuse the cast: the legendary comes
	# from the explicit roll, never from being the last fish left in the water.
	var koi_state := {'map':game.current_map,'player':game.player,'time':game.time_of_day,'weather':game.weather,'season':game.season,'unlocked':game.hidden_spot_unlocked,'collected':game.hidden_spot_collected,'combo':game.combo}
	game._reset_fishing(); game.hidden_spot_unlocked=true; game.hidden_spot_collected=true
	game.current_map='grotto'; game._build_map('grotto'); game.player=Vector2(512,520)
	game.time_of_day=0.5; game.weather='storm'; game.season='winter'; game.combo=5
	check(game._species_pool().size()==1 and game._species_pool()[0].name=='Aurora koi' and game._ordinary_pool().is_empty(),'a storm-bound grotto holds only Aurora koi')
	check(game._pick_species('PERFECT',false,true).is_empty(),'a legendary-only pool yields no ordinary candidate')
	# The roll is live here (chain of five, FEVER, Moonseed: 8% a cast), so 400
	# draws would surface a legendary if the empty candidate still reached it.
	var koi_bait: int = game.bait_index; var koi_fever: bool = game.fever_active
	game.fever_active=true; game.bait_index=2
	var koi_leaks := 0
	for i in range(400):
		if not game._pick_cast_candidate().is_empty(): koi_leaks += 1
	check(is_equal_approx(game._legendary_chance_for_cast(),game.LEGENDARY_CHANCE_CAP) and koi_leaks==0,'a legendary-only pool never enters the legendary roll')
	game.fever_active=koi_fever; game.bait_index=koi_bait
	var koi_shells: int = game.shells; var koi_fish: int = game.fish_count
	game._try_fish()
	check(game.fishing_state==game.FishingState.IDLE and game.fish_count==koi_fish and game.shells==koi_shells,'a legendary-only pool refuses the cast')
	# A caller that resolves a timing result directly must not reach the ledger
	# with the empty candidate either.
	var koi_combo: int = game.combo; var koi_catches: int = game.catches.size()
	game.cast_candidate={}; game._resolve_fishing_timing(0.5)
	check(game.fishing_state==game.FishingState.IDLE and game.fish_count==koi_fish and game.combo==koi_combo and game.catches.size()==koi_catches and not game.catch_choice_pending(),'resolving a cast in a legendary-only pool records no catch')
	game.current_map=koi_state.map; game._build_map(koi_state.map); game.player=koi_state.player; game.time_of_day=koi_state.time; game.weather=koi_state.weather; game.season=koi_state.season
	game.hidden_spot_unlocked=koi_state.unlocked; game.hidden_spot_collected=koi_state.collected; game.combo=koi_state.combo; game._reset_fishing()
	var worst_rumor_width := 0.0
	for rumor_id in game._all_rumor_ids():
		var width: float = ThemeDB.fallback_font.get_string_size('[9/9] '+game.rumor_text(str(rumor_id)),HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
		worst_rumor_width=maxf(worst_rumor_width,width)
	check(worst_rumor_width<=318.0,'every rumor fits the ledger line (%.0fpx)' % worst_rumor_width)
	game.heard_rumors=['grotto']; game.rumor_page=0
	game.page_rumor(1); check(game.rumor_page==0,'a single rumor does not page away')
	game.heard_rumors=['grotto','Moonfish','Lantern fish']; game.page_rumor(-1)
	check(game.rumor_page==2,'rumor paging wraps backwards')
	game.page_rumor(1); check(game.rumor_page==0,'rumor paging wraps forwards')
	game.heard_rumors=['grotto']; game.current_map='beach'; game.time_of_day=0.75; game.weather='clear'; game.season='autumn'
	check(not game.species_known('Moonfish') and not game.species_biting_now('Moonfish') and game.ledger_display_name('Moonfish',0).begins_with('????'),'an unheard, uncaught species stays unknown in the ledger')
	game.heard_rumors=['grotto','Moonfish']
	check(game.species_known('Moonfish') and game.species_biting_now('Moonfish') and game.ledger_display_name('Moonfish',0).begins_with('Moonfish'),'a rumor names the species and marks it as biting now')
	game.season='spring'
	check(game.species_known('Moonfish') and not game.species_biting_now('Moonfish'),'the biting-now dot follows the season')
	game._save_game('res://.smoke-rumor-test.json'); game.heard_rumors=[]; game.rumor_found=false; game._load_game('res://.smoke-rumor-test.json')
	check(game.heard_rumors==['grotto','Moonfish'],'heard rumors survive save and load')
	var legacy_rumor_file=FileAccess.open('res://.smoke-legacy-rumor.json',FileAccess.WRITE)
	legacy_rumor_file.store_string('{"version":12,"fish":5,"rumor_found":true,"x":368,"y":372}'); legacy_rumor_file.close()
	game._load_game('res://.smoke-legacy-rumor.json')
	check(game.rumor_found and game.heard_rumors==['grotto'],'a pre-rumor-list save keeps its grotto rumor')
	game.heard_rumors=[]; game.rumor_found=false; game.current_map='town'; game._build_map('town')
	game.catches.clear(); game.catch_metadata.clear(); game.first_capture_metadata.clear(); game.catch_latest.clear()
	game.rumor_found=true; game.hidden_spot_unlocked=false; game.fish_count=99
	for species in ['Sunrise bream','Amber anchovy','Coral rabbitfish','Seahorse','Harvest puffer','Tidepool blenny']: game.catch_metadata[species]={'species':species}
	game._update_rumor_gate()
	check(game.collection_discovered_count()==6 and game.collection_percent()<float(game.HIDDEN_SPOT_COLLECTION_PERCENT) and not game.hidden_spot_unlocked,'a few fish no longer open the grotto')
	game.catch_metadata['Mint wrasse']={'species':'Mint wrasse'}; game._update_rumor_gate()
	check(game.collection_percent()>=float(game.HIDDEN_SPOT_COLLECTION_PERCENT) and game.hidden_spot_unlocked,'collection gate unlocks hidden spot at a quarter of the guide')
	game.hidden_spot_unlocked=false; game.rumor_found=false; game._update_rumor_gate()
	check(not game.hidden_spot_unlocked,'the guide percentage alone does not open the grotto without the rumor')
	game.rumor_found=true; game.fish_count=0
	game.catches=kept_catches; game.catch_metadata=kept_catch_metadata; game.first_capture_metadata=kept_first_metadata; game.catch_latest=kept_latest
	game.time_of_day=float(rumor_clock[0]); game.weather=str(rumor_clock[1]); game.season=str(rumor_clock[2])
	game._update_rumor_gate(); game.hidden_spot_unlocked=true
	game.current_map='rocky'; game._build_map('rocky'); check(game._fishing_spots().size()==3,'hidden grotto adds distinct pool')
	game.hidden_spot_collected=true; game.player=Vector2(497,151)
	var rocky_pool: Array = game._species_pool()
	check(not rocky_pool.any(func(f): return f.rarity=='LEGENDARY' and f.maps.has('hidden')),'hidden fish stay out of ordinary rocky pools')
	game.player=Vector2(690,480)
	check(game._species_pool().any(func(f): return f.rarity=='LEGENDARY' and f.maps.has('hidden')),'hidden fish require the actual grotto fishing spot')
	# Pin the chain, FEVER and bait so the cap is actually exercised; the state
	# left by the earlier randomised casts would otherwise decide this check.
	game.combo=5; game.fever_active=true; game.bait_index=2
	check(is_equal_approx(game._legendary_chance_for_cast(),game.LEGENDARY_CHANCE_CAP) and game.LEGENDARY_BASE_CHANCE+game.LEGENDARY_FEVER_BONUS+game.LEGENDARY_MOONSEED_BONUS>=game.LEGENDARY_CHANCE_CAP,'rocky legendary chance is capped')
	game.combo=1
	check(game._legendary_chance_for_cast()==0.0,'no legendary roll before the third chain catch')
	game.combo=2; game.fever_active=false; game.bait_index=1
	var no_fever_legendary_chance: float = game._legendary_chance_for_cast()
	game.combo=3; game.fever_active=true; game.bait_index=1
	var fever_legendary_chance: float = game._legendary_chance_for_cast()
	game.bait_index=2
	var moonseed_legendary_chance: float = game._legendary_chance_for_cast()
	check(is_equal_approx(no_fever_legendary_chance,game.LEGENDARY_BASE_CHANCE) and is_equal_approx(fever_legendary_chance,game.LEGENDARY_BASE_CHANCE+game.LEGENDARY_FEVER_BONUS) and is_equal_approx(moonseed_legendary_chance,game.LEGENDARY_CHANCE_CAP) and is_equal_approx(moonseed_legendary_chance-fever_legendary_chance,game.LEGENDARY_MOONSEED_BONUS),'legendary chance uses actual FEVER and bounded Moonseed nudge')
	check(game._rarity_bonus_scale('COMMON')==0.0 and game._rarity_bonus_scale('RARE')>game._rarity_bonus_scale('UNCOMMON') and game._rarity_bonus_scale('EPIC')>game._rarity_bonus_scale('RARE'),'bait and FEVER scales favour higher rarities')
	# Force a legendary candidate to verify the reveal path without relying on a
	# statistical roll.  The result must still come from the cast candidate.
	game._reset_fishing(); game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(497,151); game.time_of_day=0.95; game.weather='rain'; game.season='summer'; game.combo=2
	game.cast_candidate=game._fish_entry('Storm tuna').duplicate(true)
	game._resolve_fishing_timing(0.5)
	check(game.last_rarity=='LEGENDARY' and game.last_catch==game._fish_entry('Storm tuna').name and game.result_t>6.0,'forced legendary candidate opens the staged reveal')
	check(not game.catch_reveal_complete() and game.toast=='' and game.result_toast_pending.contains('BIG CATCH'),'legendary omen does not announce the catch in the toast bar')
	game._process_fishing(2.1)
	check(game.catch_reveal_complete() and game.toast.contains('BIG CATCH'),'legendary toast and prompt wait for the name reveal')
	var storm_tuna_count_before: int = int(game.catches.get('Storm tuna',0))
	game._reset_fishing(); game.cast_candidate=game._fish_entry('Storm tuna').duplicate(true); game._resolve_fishing_timing(0.34)
	check(game.last_rarity=='RARE' and game.last_catch!='Storm tuna' and int(game.catches.get('Storm tuna',0))==storm_tuna_count_before,'GOOD legendary candidate becomes a RARE catch without ledgering Legendary species')
	# Fever is earned through three catches, survives result dismissal, and
	# expires independently of the fish's battle timer.
	game._reset_fishing(); game._break_chain()
	game.current_map='town'; game._build_map('town'); game.player=Vector2(500,530)
	game.time_of_day=0.5; game.weather='clear'; game.season='spring'
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
	game._save_game('res://.smoke-fever-test.json')
	var saved_fever=game.fever_t
	game._break_chain(); game.bait_index=0; game.rod_index=0
	game._load_game('res://.smoke-fever-test.json')
	check(game.combo==3 and game.fever_active and is_equal_approx(game.fever_t,saved_fever),'save restores combo and remaining fever')
	check(game.bait_index==1 and game.rod_index==2 and game.catches.size()>0,'fever save preserves loadout and ledger')
	game._process_fishing(game.FEVER_DURATION+0.1)
	check(not game.fever_active and game.combo==0 and game.fever_t==0.0,'fever timeout resets chain')
	check(not game.music.get_snapshot().fever,'fever timeout clears music cue')
	game._reset_fishing(); game.combo=2; game._resolve_fishing_timing(0.34)
	game._reset_fishing(); game._resolve_fishing_timing(-1.0)
	check(not game.fever_active and game.combo==0 and game.fever_t==0.0,'miss ends fever and resets chain')
	game._load_game('res://.smoke-legacy-test.json')
	check(not game.fever_active and game.combo==0,'legacy saves default to no fever')
	# ---- Dopamine FX (EFFECTS_DESIGN.md) ----------------------------------
	var fx = game.fx
	game._reset_fishing(); game._break_chain()
	game.current_map='rocky'; game._build_map('rocky'); game.player=Vector2(497,151)
	game.time_of_day=0.95; game.weather='clear'; game.season='autumn'
	# The premium "golden tide" is the one cue that never lies.
	var low_premium := 0
	for i in range(400):
		if fx.roll_premium(2) or fx.roll_premium(0): low_premium += 1
	check(low_premium==0,'premium cue is never rolled for a RARE-or-lower candidate')
	fx.rng.seed=4401
	var premium_casts := 0
	var premium_lies := 0
	for i in range(1500):
		game._reset_fishing(); game.shells=100; game.combo=0; game.fever_active=false
		game._try_fish()
		if game.fishing_state != game.FishingState.ANTICIPATING: continue
		if game.fx_premium:
			premium_casts += 1
			if game._rarity_rank(str(game.cast_candidate.get('rarity','COMMON'))) < 3 or game.promotion_false_cue: premium_lies += 1
	check(premium_casts>0 and premium_lies==0,'golden tide appears and always means EPIC or better (%d casts)' % premium_casts)
	# The golden tide also promises no fake-out: a reversal rolled for the
	# cast (a visible step back) is dropped together with any false cue.
	var tide_planned := 0
	var tide_dirty := 0
	for i in range(300):
		game.promotion_target_rarity='EPIC'; game.promotion_cue_rank=3
		game.promotion_false_cue=true; game.promotion_reversal_armed=true
		game._plan_cast_fx()
		if game.fx_premium:
			tide_planned += 1
			if game.promotion_false_cue or game.promotion_reversal_armed: tide_dirty += 1
	check(tide_planned>0 and tide_dirty==0,'planning a golden tide clears the false cue and the armed reversal (%d plans)' % tide_planned)
	# End to end: arm a reversal on an EPIC cast, plan it until the tide rolls,
	# then play the whole wait. (Premium is too rare in natural casts to rely on
	# the reversal roll landing on one, so the reversal is forced here.)
	game._reset_fishing(); game.shells=100; game.combo=0; game.fever_active=false
	game._try_fish()
	fx.rng.seed=4402
	var tide_rolled := false
	for i in range(200):
		game.promotion_target_rarity='EPIC'; game.promotion_cue_rank=3
		game.promotion_false_cue=false; game.promotion_reversal_armed=true; game.promotion_reversal=false
		game.bite_delay=1.0; game.bite_timer=0.0
		game._plan_cast_fx()
		if game.fx_premium:
			tide_rolled = true
			break
	fx.counters.clear()
	var tide_fakeouts := 0
	var tide_steps := 0
	while tide_rolled and game.fishing_state == game.FishingState.ANTICIPATING and tide_steps < 400:
		game._process_fishing(0.05); tide_steps += 1
		if game.promotion_reversal: tide_fakeouts += 1
	check(tide_rolled and tide_steps>10 and tide_fakeouts==0 and int(fx.counters.get('cue_reversal',0))==0,'a golden-tide wait never steps back, even when a reversal was rolled (%d steps)' % tide_steps)
	# FX rolls run on their own RNG, so the gameplay roll is unchanged.
	game._reset_fishing(); game.shells=100
	game.rng.seed=99001; fx.rng.seed=1
	game._try_fish()
	var cand_a := str(game.cast_candidate.get('name','')); var state_a: int = game.rng.state
	game._reset_fishing(); game.shells=100
	game.rng.seed=99001; fx.rng.seed=777
	game._try_fish()
	check(cand_a==str(game.cast_candidate.get('name','')) and state_a==game.rng.state,'FX rolls never shift the gameplay RNG')
	# Hotter cues hold the bite back longer.
	var ext: Array = fx.WAIT_EXTENSION
	var ladder_ok := true
	for i in range(1, ext.size()):
		if float(ext[i]) <= float(ext[i-1]): ladder_ok = false
	check(ladder_ok and fx.wait_extension(0)==0.0,'wait extension climbs with heat and is zero for a quiet float')
	var rod_mult := float(game.RODS[game.rod_index].get('bite_mult',1.0))
	var base_delay: float = game.bite_delay - fx.wait_extension(game.fx_heat)
	check(base_delay >= 0.72*rod_mult - 0.001 and base_delay <= 1.42*rod_mult + 0.001,'bite delay is the base roll plus the heat extension')
	# Documented contract: a natural cast never starts below H1 (gold is reachable
	# on every cast), so the blue H0 look only appears when a reversal steps the
	# float back, and every cast carries at least the gold wait extension.
	var min_cast_heat := 9
	game.rng.seed=2468
	for i in range(300):
		game._reset_fishing(); game.shells=100; game.combo=0; game.fever_active=false
		game._try_fish()
		if game.fishing_state == game.FishingState.ANTICIPATING: min_cast_heat = mini(min_cast_heat, game.fx_heat)
	check(min_cast_heat==1,'natural casts start at gold or hotter (min cast heat %d)' % min_cast_heat)
	# Photosensitivity guard.
	game._reset_fishing()
	fx.reduced=false; fx.flash_log.clear()
	var accepted := 0
	for i in range(10):
		if fx.request_flash(Color.WHITE, 1.0, 0.2): accepted += 1
	check(accepted==fx.FLASH_MAX_PER_WINDOW and fx.flash_alpha<=fx.FLASH_ALPHA_CAP,'at most three full-screen flashes per second, brightness capped')
	fx.update(1.05)
	check(fx.request_flash(Color.WHITE, 1.0, 0.2),'flash budget refills after a second')
	fx.reduced=true; fx.flash_log.clear(); fx.request_flash(Color.WHITE, 1.0, 0.2)
	check(fx.flash_alpha<=fx.FLASH_ALPHA_CAP_REDUCED and fx.chroma()==0.0,'reduced mode caps flashes and disables chromatic aberration')
	fx.chroma_pulse(1.0,0.5)
	check(fx.chroma()==0.0,'reduced mode ignores chroma pulses')
	game._save_game('res://.smoke-fx-test.json'); fx.reduced=false; game._load_game('res://.smoke-fx-test.json')
	check(fx.reduced,'reduced flash setting survives save/load')
	fx.reduced=false
	# HUD-drawn soft tints (reveal wash, LEGENDARY glow, FEVER wash) are not
	# director flashes, so reduced mode must drop them: the capped, budgeted
	# flash is then the only full-screen brightness change.
	check(is_equal_approx(fx.soft_overlay(0.2),0.2),'soft screen tints draw normally by default')
	fx.reduced=true
	check(fx.soft_overlay(0.2)==0.0 and fx.soft_overlay(0.1)==0.0,'reduced mode drops the HUD soft tints')
	fx.reduced=false
	# Pressing F while a flash is already on screen clamps that flash too.
	fx.reduced=false; fx.flash_log.clear(); fx.request_flash(Color.WHITE, 0.5, 0.4)
	var normal_flash: float = fx.current_flash_alpha()
	fx.reduced=true
	check(normal_flash>fx.FLASH_ALPHA_CAP_REDUCED and fx.current_flash_alpha()<=fx.FLASH_ALPHA_CAP_REDUCED+0.0001,'switching to reduced mode clamps a flash already on screen')
	fx.reduced=false; fx.update(1.0)
	# Source guard for the same promise: every light full-screen HUD rect goes
	# through soft_overlay (the dark LEGENDARY backdrop is not a light flash).
	var main_src: String = FileAccess.get_file_as_string('res://main.gd')
	var overlay_bypass := 0
	for src_line in main_src.split('\n'):
		var compact: String = src_line.replace(' ', '')
		if compact.contains('hud.draw_rect(Rect2(0,0,480,270)') and not compact.contains('soft_overlay') and not compact.contains('Color(0.025,0.03,0.12'):
			overlay_bypass += 1
	check(overlay_bypass==0,'no HUD full-screen light overlay bypasses the reduced-flash switch (%d found)' % overlay_bypass)
	# Hit-stop freezes the fishing clock only briefly.
	fx.hitstop(0.1)
	check(fx.time_scale()==0.0,'hit-stop freezes game time')
	fx.update(0.11)
	check(fx.time_scale()==1.0,'hit-stop releases after its duration')
	# Ladder: gold stays quiet, purple hushes the music, rainbow cuts in.
	fx.cast(1); fx.counters.clear(); fx.flash_log.clear()
	fx.cue_step(1, Vector2(240,160))
	check(not fx.counters.keys().any(func(k): return str(k).begins_with('cutin_')) and int(fx.counters.get('flash',0))==0 and fx.music_duck==1.0,'gold step is a quiet glint, not a cut-in')
	fx.cue_step(2, Vector2(240,160))
	check(fx.music_duck<0.2 and fx.heartbeat_on and fx.dim_target>0.0,'purple step hushes the music and starts the heartbeat')
	fx.cue_step(3, Vector2(240,160))
	check(int(fx.counters.get('cutin_hot',0))==1 and fx.speed_target>0.5,'rainbow step fires the hot cut-in and speed lines')
	fx.bite(3, Vector2(240,160))
	check(fx.music_duck==1.0 and fx.letterbox_target==1.0 and not fx.heartbeat_on,'a hot bite releases the hush and opens the reach letterbox')
	fx.cast(0); fx.bite(1, Vector2(240,160))
	check(fx.letterbox_target==0.0,'a gold bite does not enter reach')
	fx.cast(0); fx.premium_omen(); fx.update(0.4)
	check(int(fx.counters.get('cutin_premium',0))>=1,'golden tide lands its premium cut-in')
	fx.cue_step(3, Vector2(240,160))
	check(int(fx.counters.get('cutin_premium',0))>=2,'after the golden tide the rainbow step stays on the gold ladder')
	# Pull impacts: one screen-wide burst per pull, sized by the grade, and a run
	# of PERFECT pulls climbs two more steps.
	check(fx.impact_tier('MISS')==0 and fx.impact_tier('GOOD')==1 and fx.impact_tier('PERFECT',1)==2 and fx.impact_tier('PERFECT',2)==3 and fx.impact_tier('PERFECT',3)==4 and fx.impact_tier('PERFECT',9)==4,'pull impacts climb red, GOOD, PERFECT, then two streak steps')
	var impact_pos := Vector2(200,150)
	fx.clear_show(); fx.counters.clear(); fx.flash_log.clear()
	fx.pull('GOOD',impact_pos,1,0.2)
	var good_particles: int = fx.particles.size(); var good_shake: float = fx.shake_power; var good_stop: float = fx.hitstop_t
	check(fx.impacts.size()==1 and fx.impacts[0].tier==1 and int(fx.counters.get('flash',0))==0 and fx.chroma()==0.0,'a GOOD pull bursts without a full-screen flash')
	fx.clear_show(); fx.counters.clear(); fx.flash_log.clear()
	fx.pull('PERFECT',impact_pos,1,0.2,1)
	var perfect_particles: int = fx.particles.size(); var perfect_shake: float = fx.shake_power
	check(fx.impacts[0].tier==2 and int(fx.counters.get('flash',0))==1 and perfect_particles>good_particles and perfect_shake>good_shake and fx.hitstop_t>good_stop,'a PERFECT pull is visibly bigger than a GOOD one')
	fx.clear_show(); fx.counters.clear(); fx.flash_log.clear(); fx.sounds.clear()
	fx.pull('PERFECT',impact_pos,3,0.2,3,true)
	check(fx.impacts[0].tier==4 and fx.impacts[0].streak==3 and fx.impacts[0].clean and fx.particles.size()>perfect_particles and fx.shake_power>perfect_shake and fx.chroma()>0.0 and fx.sounds.has('streak'),'a PERFECT streak climbs to the top impact tier')
	check(game.fx_front._impact_label(fx.impacts[0])=='PERFECT x3!!' and game.fx_front._impact_label({'tier':1,'streak':0})=='GOOD!' and game.fx_front._impact_label({'tier':0,'streak':0})=='STRAIN!','each impact names its grade')
	check(fx.IMPACT_MAX_DUR<game.PULL_COOLDOWN and fx.IMPACT_DURS.max()<=fx.IMPACT_MAX_DUR,'every pull impact ends well inside the pull cooldown')
	# The top tier's look is capped but its count is not.
	check(fx.impact_tier('PERFECT',5)==4 and game.fx_front._impact_label({'tier':4,'streak':5})=='PERFECT x5!!','a long PERFECT streak keeps counting on the top tier')
	# The grade sits in a lane below every row of the fishing panel, even with
	# a challenge pushing the panel down, and inside the screen.
	var lowest_hud_row: float = game.FISHING_HUD_ESCAPE_Y + game.CHALLENGE_HUD_OFFSET
	check(fx.IMPACT_LANE_TOP>lowest_hud_row+2.0,'the impact lane starts below the escape meter')
	for impact_step in range(5):
		var impact_size: int = game.fx_front._impact_text_size(impact_step)
		var text_top: float = fx.IMPACT_TEXT_POS.y - ThemeDB.fallback_font.get_ascent(impact_size) * 0.8
		check(text_top>=fx.IMPACT_LANE_TOP and fx.IMPACT_TEXT_POS.y<=270.0,'tier %d grade text stays in the impact lane' % impact_step)
		var impact_band: Rect2 = game.fx_front._impact_band(impact_step)
		check(impact_band.position.y>=fx.IMPACT_LANE_TOP and impact_band.end.y<=270.0,'tier %d band stays in the impact lane' % impact_step)
	fx.update(fx.IMPACT_MAX_DUR+0.01)
	check(fx.impacts.is_empty(),'pull impacts clear themselves')
	fx.strain(impact_pos)
	check(fx.impacts.size()==1 and fx.impacts[0].tier==0,'a strained pull gets the red impact')
	# The photosensitivity budget still holds when PERFECT pulls arrive together.
	fx.clear_show(); fx.counters.clear(); fx.flash_log.clear()
	for i in range(6): fx.pull('PERFECT',impact_pos,i+1,0.5,i+1)
	check(int(fx.counters.get('flash',0))==fx.FLASH_MAX_PER_WINDOW and int(fx.counters.get('flash_suppressed',0))==3 and fx.impacts.size()<=4,'stacked PERFECT pulls stay inside the flash budget')
	fx.clear_show(); fx.flash_log.clear(); fx.reduced=true
	fx.pull('PERFECT',impact_pos,3,0.5,3)
	check(fx.current_flash_alpha()<=fx.FLASH_ALPHA_CAP_REDUCED and fx.chroma()==0.0 and fx.soft_overlay(0.2)==0.0,'reduced flashing dims the top-tier impact and drops its wash')
	fx.reduced=false; fx.clear_show(); fx.flash_log.clear()
	check(fx.impacts.is_empty(),'resetting the show clears pull impacts')
	# The live battle feeds the streak: PERFECT pulls build it, anything else ends it.
	game._reset_fishing(); game._break_chain(); game.current_map='town'; game._build_map('town'); game.player=Vector2(500,530)
	game.time_of_day=0.5; game.weather='clear'; game.season='spring'; game._try_fish(); game._process_fishing(4.0)
	game.pull_cooldown=0.0; game._handle_fishing_strike(0.5)
	game.pull_cooldown=0.0; game._handle_fishing_strike(0.5)
	check(game.perfect_streak==2 and fx.impacts[fx.impacts.size()-1].tier==3,'two PERFECT pulls in a row raise the impact tier')
	game.pull_cooldown=0.0; game._handle_fishing_strike(0.30)
	check(game.perfect_streak==0 and fx.impacts[fx.impacts.size()-1].tier==1,'a GOOD pull ends the PERFECT streak')
	game.pull_cooldown=0.0; game._handle_fishing_strike(0.5)
	game.pull_cooldown=0.0; game.battle_tension=0.0; game._handle_fishing_strike(0.05)
	check(game.perfect_streak==0 and fx.impacts[fx.impacts.size()-1].tier==0,'a strained pull ends the PERFECT streak')
	# Nothing a pull throws outlives the impact: the top tier's poppers and sparks
	# are all gone before the next pull can be timed.
	fx.clear_show(); fx.flash_log.clear()
	fx.pull('PERFECT',impact_pos,3,0.5,3,true)
	var longest_life := 0.0
	for particle in fx.particles: longest_life = maxf(longest_life, float(particle.life))
	check(fx.particles.size()>60 and longest_life<=fx.IMPACT_MAX_DUR,'every particle from a pull lives no longer than the impact')
	fx.strain(impact_pos); longest_life = 0.0
	for particle in fx.particles: longest_life = maxf(longest_life, float(particle.life))
	check(longest_life<=fx.IMPACT_MAX_DUR,'a strained pull is held to the same lifetime')
	fx.update(fx.IMPACT_MAX_DUR+0.01)
	check(fx.particles.is_empty() and fx.impacts.is_empty(),'a pull leaves nothing on screen once its impact is over')
	# The pull that lands the fish still shows its impact over the landing.
	game._reset_fishing(); game._break_chain(); game._try_fish(); game._process_fishing(4.0)
	for i in range(8):
		if game.fishing_state != game.FishingState.TIMING: break
		game.pull_cooldown=0.0; game._handle_fishing_strike(0.5)
	check(game.fishing_state==game.FishingState.RESULT and game.last_grade=='PERFECT' and fx.impacts.size()==1 and fx.impacts[0].tier==4 and fx.pops.is_empty() and fx.cutins.is_empty(),'the finishing pull keeps its impact through the landing')
	fx.update(fx.IMPACT_MAX_DUR+0.01)
	check(fx.impacts.is_empty(),'the finishing impact is gone before the card can be read')
	check(fx.IMPACT_MAX_DUR<game._reveal_face_time()*0.62,'the finishing impact ends before even a shortened reveal turns the card')
	# A line that snaps on a strained pull shows LINE SNAPPED, not STRAIN!.
	game._reset_fishing(); game._break_chain(); game._try_fish(); game._process_fishing(4.0)
	game.pull_cooldown=0.0; game.battle_tension=0.95; game._handle_fishing_strike(0.05)
	check(game.last_grade=='MISS' and fx.impacts.is_empty() and fx.pops.size()==1,'a snapped line replaces the strained impact with its own callout')
	game._reset_fishing(); fx.flash_log.clear()
	# Resetting a cast is a hard boundary: no reveal particles, banners, shards,
	# active flash or delayed callback may leak into the idle world/next cast.
	fx.cast(3)
	fx.flash_log.clear()
	fx.legendary_shatter(); fx.cutin('STALE', '', 'hot'); fx.pop('STALE', Vector2(240,160), Color.WHITE)
	fx.request_flash(Color.WHITE, 0.4, 0.4); fx.schedule(0.4, 'burst', [Vector2(240,160), Color.WHITE, 4, 20.0])
	game._reset_fishing()
	check(fx.cutins.is_empty() and fx.pops.is_empty() and fx.particles.is_empty() and fx.shards.is_empty() and fx.scheduled.is_empty() and fx.current_flash_alpha()==0.0 and fx.time_scale()==1.0,'cast reset clears all transient FX and delayed callbacks')
	# Summon light: promotions climb one step at a time; broken promises fizzle.
	game._reset_fishing()
	game.last_rarity='EPIC'; game.reveal_shortened=false; game.reveal_glow_start=1
	var plan: Array = game._reveal_glow_plan()
	check(plan.size()==2 and int(plan[0].rank)==2 and int(plan[1].rank)==3 and float(plan[1].t)<game._reveal_face_time(),'gold-to-EPIC reveal promotes twice before the card turns')
	check(game._reveal_glow_rank_at(0.5)==1 and game._reveal_glow_rank_at(game._reveal_face_time())==3,'summon light starts at the promised heat and ends at the result')
	game.last_rarity='RARE'; game.reveal_glow_start=3
	plan = game._reveal_glow_plan()
	check(plan.size()==1 and str(plan[0].kind)=='fizzle' and game._reveal_glow_rank_at(1.2)==2,'a rainbow promise that lands RARE fizzles once')
	game.last_rarity='COMMON'; game.reveal_glow_start=-1
	check(game._reveal_glow_plan().is_empty(),'a catch with no cue history reveals without promotions')
	# A gold float on a common fish must not fizzle every ordinary catch.
	game._reset_fishing(); game.current_map='town'; game._build_map('town'); game.player=Vector2(500,530)
	game.time_of_day=0.5; game.weather='clear'; game.season='spring'
	game.shells=100; game._try_fish()
	game.cast_candidate={'name':'Sunrise bream','rarity':'COMMON'}; game.promotion_target_rarity='COMMON'
	game.promotion_cue_rank=0; game.promotion_false_cue=false; game.fx_premium=false; game.promotion_reversal_armed=false
	game._process_fishing(game.bite_delay*0.5); game._process_fishing(game.bite_delay)
	check(game.fishing_state==game.FishingState.TIMING and game.reveal_glow_start==0,'gold float on a common catch starts the summon light at blue')
	# FEVER is announced when the catch is settled, not over the reveal.
	game._reset_fishing(); game._break_chain(); game.combo=2; fx.counters.clear()
	game.cast_candidate={'name':'Sunrise bream','rarity':'COMMON'}; game._resolve_fishing_timing(0.5)
	check(game.fever_active and int(fx.counters.get('fever',0))==0,'FEVER banner waits while the card is revealed')
	game.reveal_t=2.0; game.reveal_stage=4
	game.register_pending_catch()
	check(int(fx.counters.get('fever',0))==1 and fx.fever_target==1.0,'settling the catch announces FEVER and lights the frame')
	game._break_chain(); game._reset_fishing()
	# FEVER's clock starts when it is announced. A catch left unsettled must not
	# burn FEVER down (and lose its banner) before the player chooses.
	game.combo=2; fx.counters.clear()
	game.cast_candidate={'name':'Sunrise bream','rarity':'COMMON'}; game._resolve_fishing_timing(0.5)
	game.reveal_t=2.0; game.reveal_stage=4
	var held_fever_t: float = game.fever_t
	for i in range(40): game._process_fishing(1.0)
	check(game.fever_active and game.catch_choice_pending() and is_equal_approx(game.fever_t,held_fever_t),'FEVER waits while the catch that started it is unsettled')
	game.register_pending_catch()
	check(game.fever_active and int(fx.counters.get('fever',0))==1,'a catch held for a long time still announces FEVER')
	game._process_fishing(1.0)
	check(is_equal_approx(game.fever_t,held_fever_t-1.0),'FEVER counts down once the catch is settled')
	# The pending announcement belongs to this session's landing: a stale flag
	# must not freeze a loaded game's FEVER clock.
	game._reset_fishing(); game.fever_announce_pending=true
	game._load_game('res://.smoke-fever-test.json')
	check(not game.fever_announce_pending,'loading a save drops a stale FEVER announcement')
	game._break_chain(); game._reset_fishing()
	game.fever_announce_pending=true; game.combo=3; game.fever_active=true; game.fever_t=10.0
	game._break_chain()
	check(not game.fever_announce_pending,'ending FEVER drops its pending announcement')
	game._reset_fishing()
	# Saved while the FEVER-starting catch awaits its choice: the banner request
	# and the held clock come back together with the catch.
	game._break_chain(); game.combo=2; fx.counters.clear()
	game.cast_candidate={'name':'Sunrise bream','rarity':'COMMON'}; game._resolve_fishing_timing(0.5)
	game.reveal_t=2.0; game.reveal_stage=4
	game._save_game('res://.smoke-fever-pending-test.json')
	game._break_chain(); game._reset_fishing()
	game._load_game('res://.smoke-fever-pending-test.json')
	check(game.fever_active and game.catch_choice_pending() and game.fever_announce_pending,'save/load keeps the FEVER banner pending with its held catch')
	var loaded_fever_t: float = game.fever_t
	for i in range(40): game._process_fishing(1.0)
	check(game.fever_active and is_equal_approx(game.fever_t,loaded_fever_t),'a loaded FEVER clock still waits for the held catch')
	fx.counters.clear()
	game.register_pending_catch()
	check(int(fx.counters.get('fever',0))==1,'the restored banner plays once the held catch is settled')
	# A save made after settling carries no banner request.
	game._save_game('res://.smoke-fever-settled-test.json')
	game._break_chain(); game._reset_fishing()
	game._load_game('res://.smoke-fever-settled-test.json')
	check(not game.fever_announce_pending,'a settled FEVER is not announced again after loading')
	game._break_chain(); game._reset_fishing()
	# FEVER's whole presentation (flash, chime, music, frame, banner) and its
	# clock start together when the catch is settled, not at landing.
	game.music.set_fever(false); game.fever_flash_t=0.0; fx.fever_target=0.0
	game.combo=2; fx.counters.clear()
	game.cast_candidate={'name':'Sunrise bream','rarity':'COMMON'}; game._resolve_fishing_timing(0.5)
	game.reveal_t=2.0; game.reveal_stage=4
	game._sync_fx_outputs()
	check(game.fever_active and game.fever_flash_t==0.0 and not game.music.get_snapshot().fever and fx.fever_target==0.0,'FEVER flash, music and frame wait for the catch to be settled')
	game.register_pending_catch()
	game._sync_fx_outputs()
	check(game.fever_flash_t>0.0 and game.music.get_snapshot().fever and fx.fever_target==1.0,'settling the catch starts the FEVER flash, music and frame together')
	game._break_chain(); game._reset_fishing()
	# A held FEVER restored from a save keeps its music quiet until it is settled.
	game.combo=2; game._resolve_fishing_timing(0.5)
	game.reveal_t=2.0; game.reveal_stage=4
	game._save_game('res://.smoke-fever-pending-music.json')
	game._break_chain(); game._reset_fishing()
	game._load_game('res://.smoke-fever-pending-music.json')
	check(game.fever_announce_pending and not game.music.get_snapshot().fever,'a loaded held FEVER keeps the music quiet until it is settled')
	game.register_pending_catch()
	check(game.music.get_snapshot().fever,'registering the restored catch starts the FEVER music')
	game._break_chain(); game._reset_fishing()
	# The music hush is applied as player gain, because the generator queue runs
	# over a second ahead of what is heard and a baked-in duck would lag the cue.
	var music_base_db: float = game.music.get_music_volume_db()
	game.music.set_duck(0.1); game.music._update_transport(1.0)
	check(is_equal_approx(game.music._stream_player.volume_db,music_base_db+linear_to_db(0.1)),'music duck is applied through the player gain')
	game.music.set_duck(1.0); game.music._update_transport(1.0)
	check(is_equal_approx(game.music._stream_player.volume_db,music_base_db),'releasing the duck restores the player gain')
	game._reset_fishing()
	# The tide ledger pauses the whole cue show, not only the fishing clock: no
	# scheduled banner, heartbeat or particle may advance (or draw) behind it.
	game.notebook_open=false
	fx.cast(0); fx.premium_omen(); fx.zoom_punch(0.1, 2.0); fx.music_duck=0.1
	fx.counters.clear(); fx.cutins.clear()
	var ledger_time: float = fx.time
	game.notebook_open=true
	game._process(0.5)
	check(is_equal_approx(fx.time,ledger_time) and fx.cutins.is_empty() and int(fx.counters.get('cutin_premium',0))==0 and not fx.scheduled.is_empty(),'opening the tide ledger pauses the cue show timers')
	check(not game.fx_back.visible and not game.fx_front.visible and not game.post_fx.visible,'cue show layers are hidden behind the tide ledger')
	check(game.cam.zoom==Vector2.ONE and game.cam.offset==Vector2.ZERO and is_equal_approx(game.music.get_duck(),1.0),'the ledger shows a still camera and normal music')
	game.notebook_open=false
	game._process(0.5)
	check(int(fx.counters.get('cutin_premium',0))>=1 and game.fx_front.visible and is_equal_approx(game.music.get_duck(),fx.music_duck),'closing the ledger resumes the paused cue where it stopped')
	game._reset_fishing()
	game.queue_free()
	await process_frame
	print('RESULT: %d failure(s)' % failures)
	quit(failures)
