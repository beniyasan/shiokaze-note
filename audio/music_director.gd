class_name MusicDirector
extends Node
## Procedural 8-bit music director for Tidebound Notebook.
##
## The director owns only music. It renders a tiny original chiptune in memory
## through AudioStreamGenerator, so no third-party audio files or licences are
## needed. Field and fishing share the same motif; fishing adds one layer at a
## time at a beat boundary as combo grows.

signal mode_changed(mode: String)
signal combo_layer_changed(combo: int)
signal fanfare_finished

const MODE_FIELD := "field"
const MODE_FISHING := "fishing"
const MODE_FANFARE := "fanfare"
const MODE_SILENT := "silent"

# A modest rate keeps this safe on low-end machines while retaining the crisp
# edges of a small 8-bit voice bank. Existing SE in main.gd use 22.05 kHz too.
const SAMPLE_RATE := 22050.0
const BUFFER_SECONDS := 1.35
const PUMP_FRAMES := 768
const TARGET_BUFFER_FRAMES := 4096
const BPM := 108.0
const BEAT_SECONDS := 60.0 / BPM
const STEP_SECONDS := BEAT_SECONDS * 0.5
const BAR_BEATS := 8
const BAR_SECONDS := BEAT_SECONDS * BAR_BEATS
const MAX_COMBO_LAYER := 4
const TWO_PI := TAU

# A minor-ish seaside motif. Values are semitone offsets from A3 (220 Hz).
# It is intentionally short and loopable: 8 eighth-notes make one bar.
const MOTIF := [0, 3, 7, 10, 7, 3, 2, 3]
const HARMONY := [12, 10, 7, 5, 7, 10, 12, 10]
const BASS_ROOTS := [0, -5, -3, -7]
const ARP_OFFSETS := [0, 7, 12, 7, 3, 10, 15, 10]

var mode := MODE_SILENT
var target_mode := MODE_SILENT
var mode_mix := 0.0
var target_mode_mix := 0.0
var pending_combo := 0
var active_combo := 0
var elapsed := 0.0
var _sample_cursor := 0.0
var _last_beat := -1
var _fanfare_time := 0.0
var _fanfare_length := 0.0
var _fanfare_start_sample := 0.0
var _fanfare_legendary := false
var _fanfare_done_emitted := false
var _fade_out_seconds := 0.0
var _fade_out_elapsed := 0.0
var _music_volume_db := -15.0
var _muted := false
var _enabled := true
var _stream_player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _rng_state := 0x4D534943 # deterministic noise, no global RNG side effects

func _ready() -> void:
	# This class is intentionally usable before entering the scene tree as well,
	# but creating the player here keeps integration to one `add_child` call.
	_create_player()

func _exit_tree() -> void:
	if _stream_player != null:
		_stream_player.stop()

func _create_player() -> void:
	if _stream_player != null:
		return
	_stream_player = AudioStreamPlayer.new()
	_stream_player.name = "MusicStream"
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = BUFFER_SECONDS
	_stream_player.stream = _generator
	_stream_player.volume_db = _music_volume_db
	add_child(_stream_player)
	_stream_player.play()
	_playback = _stream_player.get_stream_playback() as AudioStreamGeneratorPlayback

func start_field() -> void:
	_set_target_mode(MODE_FIELD)

func start_fishing(combo: int = 0) -> void:
	pending_combo = clampi(combo, 0, 99)
	_set_target_mode(MODE_FISHING)

func set_combo(combo: int) -> void:
	# Layer changes intentionally wait for a beat. This avoids clicks and makes
	# each combo tier feel like a musical response rather than a switch.
	pending_combo = clampi(combo, 0, 99)

func get_combo() -> int:
	return pending_combo

func play_fanfare(legendary: bool = false) -> void:
	_fanfare_legendary = legendary
	_fanfare_time = 0.0
	_fanfare_length = 4.4 if legendary else 1.8
	_fanfare_start_sample = _sample_cursor
	_fanfare_done_emitted = false
	_set_target_mode(MODE_FANFARE)

func stop_music(fade_seconds: float = 0.6) -> void:
	_fade_out_seconds = maxf(0.0, fade_seconds)
	_fade_out_elapsed = 0.0
	if _fade_out_seconds <= 0.0:
		_set_target_mode(MODE_SILENT)

func set_music_volume_db(value: float) -> void:
	_music_volume_db = clampf(value, -40.0, 2.0)
	if _stream_player != null:
		_stream_player.volume_db = _music_volume_db

func get_music_volume_db() -> float:
	return _music_volume_db

func set_muted(value: bool) -> void:
	_muted = value
	if _stream_player != null:
		_stream_player.volume_db = -80.0 if _muted else _music_volume_db

func is_muted() -> bool:
	return _muted

func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		# Disabled means silent immediately. _process() intentionally returns
		# early while disabled, so a deferred fade here would leave snapshots
		# reporting the previous mode until audio is enabled again.
		_fade_out_seconds = 0.0
		_fade_out_elapsed = 0.0
		var changed := mode != MODE_SILENT or target_mode != MODE_SILENT
		mode = MODE_SILENT
		target_mode = MODE_SILENT
		mode_mix = 0.0
		target_mode_mix = 0.0
		active_combo = 0
		pending_combo = 0
		_playback = null
		if _stream_player != null:
			_stream_player.stop()
		if changed:
			mode_changed.emit(MODE_SILENT)
	elif mode == MODE_SILENT:
		if _stream_player != null and _stream_player.is_inside_tree():
			_stream_player.play()
			_playback = _stream_player.get_stream_playback() as AudioStreamGeneratorPlayback
		start_field()

func get_snapshot() -> Dictionary:
	return {
		"mode": mode,
		"target_mode": target_mode,
		"combo": active_combo,
		"pending_combo": pending_combo,
		"muted": _muted,
		"volume_db": _music_volume_db,
		"beat": maxi(0, _last_beat),
		"playing": _playback != null and mode != MODE_SILENT,
	}

func _set_target_mode(next_mode: String) -> void:
	if next_mode != MODE_FIELD and next_mode != MODE_FISHING and next_mode != MODE_FANFARE and next_mode != MODE_SILENT:
		return
	target_mode = next_mode
	if mode == MODE_SILENT and next_mode != MODE_SILENT:
		mode = next_mode
		mode_mix = 0.0
		target_mode_mix = 1.0
		mode_changed.emit(mode)
	elif next_mode == MODE_SILENT:
		# Fade the active mode down before committing to silence.
		target_mode_mix = 0.0
	elif next_mode == mode:
		# The active mode may be recovering from stop_music(); start it back up.
		target_mode_mix = 1.0
	else:
		# For a mode switch, mode_mix is the current-mode gain. Move it toward
		# zero while _sample_at() raises the target gain, then commit the new mode
		# at full gain. The previous implementation moved toward 1 here, which
		# left field -> fishing/fanfare transitions permanently stuck in field.
		target_mode_mix = 0.0

func _process(delta: float) -> void:
	if not _enabled:
		return
	if _playback == null and _stream_player != null:
		_playback = _stream_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_update_transport(delta)
	_pump_audio()

func _update_transport(delta: float) -> void:
	elapsed += delta
	# Mode crossfades happen over a fraction of a beat. The note clock is never
	# reset, so field -> fishing returns on the same motif phase.
	var fade_rate := 1.0 / maxf(0.08, BEAT_SECONDS * 0.75)
	if mode != target_mode:
		# Crossfade out of the current mode; _sample_at() uses (1 - mode_mix)
		# for the incoming target. Keep the note clock running throughout.
		mode_mix = move_toward(mode_mix, 0.0, delta * fade_rate)
	else:
		mode_mix = move_toward(mode_mix, target_mode_mix, delta * fade_rate)
	if mode != target_mode and mode_mix <= 0.001:
		mode = target_mode
		mode_mix = 0.0 if mode == MODE_SILENT else 1.0
		target_mode_mix = 0.0 if mode == MODE_SILENT else 1.0
		mode_changed.emit(mode)
		if mode == MODE_SILENT:
			active_combo = 0
			pending_combo = 0
	if mode == MODE_FANFARE:
		_fanfare_time += delta
		if _fanfare_time >= _fanfare_length:
			if not _fanfare_done_emitted:
				_fanfare_done_emitted = true
				fanfare_finished.emit()
			# Return to field on the next smooth fade. Integration may call
			# start_field() sooner when it knows the result screen is closed.
			_set_target_mode(MODE_FIELD)
	if _fade_out_seconds > 0.0:
		_fade_out_elapsed += delta
		var fade := clampf(1.0 - _fade_out_elapsed / _fade_out_seconds, 0.0, 1.0)
		target_mode_mix = fade
		if fade <= 0.0:
			_fade_out_seconds = 0.0
			_set_target_mode(MODE_SILENT)
	var beat := int(floor(elapsed / BEAT_SECONDS))
	if beat != _last_beat:
		_last_beat = beat
		if target_mode == MODE_FISHING or mode == MODE_FISHING:
			var next_layer := clampi(pending_combo, 0, MAX_COMBO_LAYER)
			if next_layer != active_combo:
				active_combo = next_layer
				combo_layer_changed.emit(active_combo)

func _pump_audio() -> void:
	if _playback == null:
		return
	var available := _playback.get_frames_available()
	if available <= 0:
		return
	# Keep enough audio queued to avoid starvation but never flood the buffer.
	var frames := mini(available, PUMP_FRAMES)
	if frames < 1:
		return
	var samples := PackedVector2Array()
	samples.resize(frames)
	for i in range(frames):
		var value := _sample_at(_sample_cursor)
		samples[i] = Vector2(value, value)
		_sample_cursor += 1.0 / SAMPLE_RATE
	_playback.push_buffer(samples)

func _sample_at(t: float) -> float:
	if mode == MODE_SILENT and target_mode == MODE_SILENT:
		return 0.0
	var lead_gain := 0.0
	var fishing_gain := 0.0
	var fanfare_gain := 0.0
	if mode == MODE_FIELD:
		lead_gain = mode_mix
	elif mode == MODE_FISHING:
		fishing_gain = mode_mix
	elif mode == MODE_FANFARE:
		fanfare_gain = mode_mix
	# During a mode change, old mode fades while target mode fades in.
	if target_mode == MODE_FIELD and mode != MODE_FIELD:
		lead_gain = maxf(lead_gain, 1.0 - mode_mix)
	elif target_mode == MODE_FISHING and mode != MODE_FISHING:
		fishing_gain = maxf(fishing_gain, 1.0 - mode_mix)
	elif target_mode == MODE_FANFARE and mode != MODE_FANFARE:
		fanfare_gain = maxf(fanfare_gain, 1.0 - mode_mix)
	var v := 0.0
	v += _field_voice(t) * lead_gain
	v += _fishing_voice(t) * fishing_gain
	v += _fanfare_voice(t) * fanfare_gain
	# Master guard leaves headroom for main.gd's SE player. A final tanh soft
	# clip catches rare stacked peaks without hard digital clipping.
	var master := 0.34
	if _muted:
		master = 0.0
	return tanh(v * master)

func _field_voice(t: float) -> float:
	var step := int(floor(t / STEP_SECONDS))
	var local := fmod(t, STEP_SECONDS)
	var index := posmod(step, MOTIF.size())
	var freq := _note_hz(220.0, MOTIF[index])
	var env := _note_envelope(local, STEP_SECONDS, 0.025, 0.18)
	# Gentle square lead with a very quiet triangle octave for warmth.
	var lead := _square(freq, t, 0.42) * env * 0.46
	lead += _triangle(freq * 2.0, t) * env * 0.07
	# A soft off-beat pluck gives the calm field loop a sense of forward motion.
	var off_env := _note_envelope(local, STEP_SECONDS, 0.01, 0.08)
	lead += _square(freq * 1.5, t + STEP_SECONDS * 0.23, 0.25) * off_env * 0.055
	# Light root bass is present in the field but deliberately tucked below SE.
	var beat := int(floor(t / BEAT_SECONDS))
	var bass_root: int = BASS_ROOTS[posmod(beat / 2, BASS_ROOTS.size())]
	var bass := _triangle(_note_hz(110.0, bass_root), t) * _note_envelope(fmod(t, BEAT_SECONDS), BEAT_SECONDS, 0.02, 0.12) * 0.16
	return lead + bass

func _fishing_voice(t: float) -> float:
	var step := int(floor(t / STEP_SECONDS))
	var local := fmod(t, STEP_SECONDS)
	var index := posmod(step, MOTIF.size())
	var freq := _note_hz(220.0, MOTIF[index] + 12)
	var env := _note_envelope(local, STEP_SECONDS, 0.012, 0.12)
	var v := _square(freq, t, 0.50) * env * 0.54
	# Keep the core motif audible even before combo layers arrive.
	v += _triangle(freq * 0.5, t) * env * 0.08
	var level := active_combo
	# Layer 1: clear low-end pulse as soon as the player starts a combo.
	if level >= 1:
		var beat_pos := fmod(t, BEAT_SECONDS)
		var bass_root: int = BASS_ROOTS[posmod(int(floor(t / BEAT_SECONDS)) / 2, BASS_ROOTS.size())]
		v += _square(_note_hz(110.0, bass_root), t, 0.50) * _note_envelope(beat_pos, BEAT_SECONDS, 0.01, 0.16) * 0.26
	# Layer 2: noise kick/snare, one event per beat (snare on off-beats).
	if level >= 2:
		var beat_index := int(floor(t / BEAT_SECONDS))
		var beat_pos2 := fmod(t, BEAT_SECONDS)
		var drum_env := exp(-beat_pos2 * (24.0 if posmod(beat_index, 2) == 0 else 30.0))
		var drum := _noise(t) * drum_env * (0.17 if posmod(beat_index, 2) == 0 else 0.12)
		v += drum
	# Layer 3: a high harmony, phrased to the same motif for cohesion.
	if level >= 3:
		var harmony_freq := _note_hz(220.0, HARMONY[index] + 12)
		v += _square(harmony_freq, t, 0.25) * env * 0.15
	# Layer 4: sixteenth-note arpeggio for the top combo tier.
	if level >= 4:
		var arp_step := int(floor(t / (STEP_SECONDS * 0.5)))
		var arp_pos := fmod(t, STEP_SECONDS * 0.5)
		var arp_freq := _note_hz(440.0, ARP_OFFSETS[posmod(arp_step, ARP_OFFSETS.size())])
		v += _square(arp_freq, t, 0.125) * _note_envelope(arp_pos, STEP_SECONDS * 0.5, 0.004, 0.07) * 0.12
	return v

func _fanfare_voice(t: float) -> float:
	# AudioStreamGenerator can pump before the first catch starts a fanfare.
	# Avoid a zero-length fmod (and the resulting invalid note index) in that
	# initial field-only window.
	if _fanfare_length <= 0.0:
		return 0.0
	var local := fmod(maxf(0.0, t - _fanfare_start_sample), _fanfare_length)
	var beat := BEAT_SECONDS
	if _fanfare_legendary:
		# Omen -> rising arpeggio -> bright resolve -> afterglow. The same A
		# motif is retained in the final chord so returning to field feels natural.
		var stage := int(floor(local / 1.1))
		var stage_t := fmod(local, 1.1)
		var idx := int(floor(stage_t / (beat * 0.5)))
		var offsets := [0, 3, 7, 10, 12, 15, 19, 24]
		var f := _note_hz(220.0, offsets[posmod(idx, offsets.size())] + stage * 2)
		var env := _note_envelope(fmod(stage_t, beat * 0.5), beat * 0.5, 0.005, 0.16)
		var v := _square(f, t, 0.5) * env * 0.58
		if stage >= 2:
			v += _square(_note_hz(220.0, 12), t, 0.25) * exp(-stage_t * 2.5) * 0.24
		if stage >= 3:
			v += _noise(t) * exp(-stage_t * 5.0) * 0.10
		return v
	# Normal catch: short three-note lift with a gentle tail.
	var notes := [0, 4, 7, 12]
	var idx2 := mini(int(floor(local / (beat * 0.5))), notes.size() - 1)
	var nlocal := fmod(local, beat * 0.5)
	var freq := _note_hz(330.0, notes[idx2])
	return _square(freq, t, 0.5) * _note_envelope(nlocal, beat * 0.5, 0.005, 0.22) * 0.45

func _note_hz(root: float, semitone: int) -> float:
	return root * pow(2.0, float(semitone) / 12.0)

func _square(freq: float, t: float, duty: float = 0.5) -> float:
	var p := fmod(freq * t, 1.0)
	return 1.0 if p < duty else -1.0

func _triangle(freq: float, t: float) -> float:
	var p := fmod(freq * t, 1.0)
	return 1.0 - 4.0 * absf(p - 0.5)

func _note_envelope(local: float, duration: float, attack: float, release: float) -> float:
	var a := clampf(local / maxf(0.0001, attack), 0.0, 1.0)
	var r := clampf((duration - local) / maxf(0.0001, release), 0.0, 1.0)
	return minf(a, r)

func _noise(_t: float) -> float:
	# 32-bit LFSR, deterministic per process and inexpensive. The occasional
	# repeating pattern is musically useful at 8-bit resolution.
	_rng_state = int(((_rng_state << 1) ^ ((_rng_state >> 31) & 1) ^ ((_rng_state >> 21) & 1) ^ ((_rng_state >> 1) & 1)) & 0x7fffffff)
	return 1.0 if (_rng_state & 1) == 0 else -1.0
