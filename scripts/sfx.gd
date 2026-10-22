## Synthesised site audio, so the prototype needs no sound files: the pump's
## stroke thump, a worn clamp's rattle, the dogman's whistle and one-shot hits.
extends AudioStreamPlayer

const RATE := 22050.0

# Dogman whistle code as used on Australian sites: [blast seconds, gap seconds].
# One short = stop, two short = hoist, three short = lower, four short = move
# horizontally (slew or trolley), one long continuous blast = emergency stop.
const SHORT := [0.14, 0.11]
const WHISTLES := {
	"stop": [SHORT],
	"hoist": [SHORT, SHORT],
	"lower": [SHORT, SHORT, SHORT],
	"horizontal": [SHORT, SHORT, SHORT, SHORT],
	"emergency": [[1.5, 0.0]],
}

var pumping := false
var stroke_beats := 1       # beats of the beat clock each pump stroke takes
var rattle := 0.0           # 0..1, how hard the worn clamp is shaking
var muted := false
var rumble := 0.0           # 0..1, a poker running in the concrete
var rumble_pitch := 0.0     # 0..1, rises as the concrete compacts and stops fighting it
var _rum := 0.0
var _rph := 0.0
var _scr := 0.0
var _playback: AudioStreamGeneratorPlayback
var _t := 0.0
var _stroke := 0.0
var _gate := 0.0
var _events: Array = []     # [kind, age_seconds]
var _hiss := 0.0

# ------------------------------------------------------------------ the Site Band
# While the concrete's going in, the site plays a tune built out of its own
# noises, one part per job, on the pump's beat (one stroke a beat, 75 BPM):
#   pump     the stroke thump grows a kick drum
#   hose     the end hose's slap is the snare, on 2 and 4
#   poker    the drive unit's drone becomes the bass line
#   screed   the board's rasp is the hi-hat
#   line     the truck's reversing beeper plays the hook
#   boom     the boom's hydraulics hum the chords
# Each part plays only while that job's working (main sets band[lane] each
# frame), so a job that's gone quiet drops out of the mix: you hear who's idle.
# A part can be a recorded sound instead: drop res://sounds/band/<lane>.wav
# (or .ogg) into the project and it plays on that part's beats in place of
# the made-up one.
const BEAT := 0.8
const LANES := ["pump", "hose", "poker", "screed", "line", "boom"]
# Am, F, C, G: a bar each. Bass roots, and the pad's three notes.
const ROOTS := [55.0, 43.65, 65.41, 49.0]
const CHORDS := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
# The beeper's hook over two bars of eighths (0: a rest), A minor pentatonic
const HOOK := [659.25, 0.0, 587.33, 659.25, 783.99, 0.0, 659.25, 587.33, 523.25, 0.0, 440.0, 523.25, 587.33, 0.0, 0.0, 0.0]
var band_on := true
var band := {}              # lane -> 0..1, how hard that job's working right now
var band_live := false      # the band plays at all (the concrete's on)
var _lv := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _master := 0.0
var _bt := 0.0              # the beat clock (the pump's stroke runs on it)
var _hp := 0.0              # last noise sample, for the hi-hat's high pass
var _samples := {}          # lane -> AudioStreamPlayer for a recorded part
var _queued: Array = []     # [seconds from now, lane] recorded hits waiting to sound

## How loud each part is in the mix right now (0..1), for the crew bar.
func band_level(lane: String) -> float:
	var i := LANES.find(lane)
	return _lv[i] * _master if i >= 0 else 0.0

## Where the beat is, 0 on the beat to 1 just before the next.
func beat_phase() -> float:
	return fmod(_bt, BEAT) / BEAT

## Beats gone by on the beat clock (the pump's strokes land on them). It
## only moves while the audio's running.
func beats() -> int:
	return int(_bt / BEAT)

func _load_samples() -> void:
	for lane in LANES:
		for ext in ["wav", "ogg"]:
			var path := "res://sounds/band/%s.%s" % [lane, ext]
			if ResourceLoader.exists(path):
				var pl := AudioStreamPlayer.new()
				pl.stream = load(path)
				add_child(pl)
				_samples[lane] = pl
				break

## Which eighth notes of the four-bar loop each part plays on (0..31).
static func _hits_on(lane: String, step: int) -> bool:
	var e := step % 8
	match lane:
		"pump":
			return e % 2 == 0
		"hose":
			return e == 2 or e == 6
		"poker":
			return true
		"screed":
			return true
		"line":
			return HOOK[step % 16] > 0.0
		"boom":
			return e == 0
	return false

## One sample of the band at beat-clock time `bt`.
func _band_sample(bt: float) -> float:
	var s := 0.0
	var b := bt / BEAT
	var bar := int(b / 4.0) % 4
	var e8 := fmod(b * 2.0, 1.0) * BEAT * 0.5   # s since the last eighth
	var step := int(b * 2.0) % 32
	var x := fmod(b, 1.0) * BEAT                # s since the last beat
	# Kick: a falling sine on every beat
	var l := _lv[0]
	if l > 0.005 and not _samples.has("pump"):
		s += sin(TAU * (48.0 + 70.0 * exp(-x * 30.0)) * x) * exp(-x * 9.0) * 0.32 * l
	# Snare on 2 and 4: a noise burst with a body
	l = _lv[1]
	if l > 0.005 and not _samples.has("hose") and int(b) % 2 == 1:
		s += ((randf() * 2.0 - 1.0) * exp(-x * 20.0) * 0.16 + sin(TAU * 190.0 * x) * exp(-x * 28.0) * 0.14) * l
	# Bass: a soft triangle on the chord's root in eighths, up the octave on the off-beats
	l = _lv[2]
	if l > 0.005 and not _samples.has("poker"):
		var f: float = ROOTS[bar] * (2.0 if step % 4 == 3 else 1.0)
		var ph := fmod(f * bt, 1.0)
		s += (1.0 - 4.0 * absf(ph - 0.5)) * exp(-e8 * 5.0) * 0.17 * l
	# Hi-hat: high-passed noise, the off-beats louder
	l = _lv[3]
	if l > 0.005 and not _samples.has("screed"):
		var n := randf() * 2.0 - 1.0
		var hp := n - _hp
		_hp = n
		s += hp * exp(-e8 * 70.0) * (0.06 if step % 2 == 1 else 0.035) * l
	# The hook, in the reversing beeper's square wave
	l = _lv[4]
	if l > 0.005 and not _samples.has("line"):
		var hf: float = HOOK[step % 16]
		if hf > 0.0 and e8 < 0.3:
			s += (1.0 if fmod(hf * bt, 1.0) < 0.5 else -1.0) * minf(1.0, e8 * 200.0) * exp(-e8 * 7.0) * 0.035 * l
	# Pad: the chord, held, swelling in each bar
	l = _lv[5]
	if l > 0.005 and not _samples.has("boom"):
		var swell := minf(1.0, fmod(b, 4.0) * 1.5) * (1.0 - 0.3 * fmod(b, 4.0) / 4.0)
		for cf in CHORDS[bar]:
			s += sin(TAU * cf * bt) * 0.028 * swell * l
	return s * _master

## Recorded parts: work out which of their beats fall in the stretch of
## audio just made, and play each when that audio reaches the speakers.
func _queue_samples(t0: float, t1: float, latency: float) -> void:
	if _samples.is_empty() or _master < 0.05:
		return
	var s0 := int(ceil(t0 / (BEAT * 0.5)))
	var s1 := int(floor(t1 / (BEAT * 0.5)))
	for st in range(s0, s1 + 1):
		for lane in _samples:
			var i := LANES.find(lane)
			if _lv[i] > 0.1 and _hits_on(lane, st % 32):
				_queued.append([latency + st * BEAT * 0.5 - t0, lane])

func _play_queued(delta: float) -> void:
	for q in _queued:
		q[0] -= delta
		if q[0] <= 0.0:
			var pl: AudioStreamPlayer = _samples[q[1]]
			pl.volume_db = linear_to_db(maxf(0.001, _lv[LANES.find(q[1])] * _master)) + volume_db + 8.0
			pl.play()
	_queued = _queued.filter(func(q): return q[0] > 0.0)

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	stream = gen
	volume_db = -14.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_load_samples()

## kind: "bang", "clank", "thunk", "buzz", "ding", "clang", "tink", "hiss",
## "knock", "ring", "thud", "beep", "whip", "rain", "horn", "clunk", "suck",
## or "whistle:<code>" with a code from WHISTLES
func hit(kind: String) -> void:
	# Never stack: a new whistle replaces the one still sounding, and the same
	# hit twice within a fraction of a second only plays once
	if kind.begins_with("whistle:") and get_parent()._dbg:
		print("[sfx] %s" % kind)
	if kind.begins_with("whistle:"):
		_events = _events.filter(func(e): return not String(e[0]).begins_with("whistle:"))
	else:
		for e in _events:
			if e[0] == kind and e[1] < 0.18:
				return
	_events.append([kind, 0.0])

func toggle_mute() -> void:
	muted = not muted
	volume_db = -80.0 if muted else -14.0
	for lane in _samples:
		(_samples[lane] as AudioStreamPlayer).volume_db = -80.0

func _whistle_on(code: String, a: float) -> bool:
	var t := 0.0
	for seg in WHISTLES.get(code, []):
		if a >= t and a < t + seg[0]:
			return true
		t += seg[0] + seg[1]
	return false

func _process(delta: float) -> void:
	if _playback == null:
		return
	_play_queued(delta)
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var dt := 1.0 / RATE
	var r2 := rattle * rattle
	# The parts ease in and out over about a second, and the whole band
	# fades with the pour
	var want_m := 1.0 if band_on and band_live else 0.0
	var tgt := PackedFloat32Array()
	for lane in LANES:
		tgt.append(clampf(float(band.get(lane, 0.0)), 0.0, 1.0))
	# (what's already buffered plays before this stretch does)
	_queue_samples(_bt, _bt + n * dt, maxf(0.0, (0.12 * RATE - n) / RATE))
	for f in n:
		_t += dt
		_bt += dt
		var s := 0.0
		if f % 64 == 0:
			_master += (want_m - _master) * 0.01
			for i in 6:
				_lv[i] += (tgt[i] - _lv[i]) * 0.012
		if _master > 0.002:
			s += _band_sample(_bt)
		if pumping and int(_bt / BEAT) % maxi(1, stroke_beats) == 0:
			# (on the beat clock, so the band's kick lands on the stroke; a
			# stroke takes a few beats)
			_stroke = fmod(_bt, BEAT)
			# The stroke's thump, with its 2nd and 3rd harmonics so TV and
			# laptop speakers (which can't play 46 Hz) still carry it, and a
			# short hydraulic "chuff" on top
			var env := exp(-_stroke * 13.0)
			s += (sin(TAU * 46.0 * _stroke) * 0.3 + sin(TAU * 92.0 * _stroke) * 0.2 + sin(TAU * 138.0 * _stroke) * 0.12) * env
			s += (randf() * 2.0 - 1.0) * sin(TAU * 1400.0 * _stroke) * exp(-_stroke * 55.0) * 0.14
			s += (randf() * 2.0 - 1.0) * exp(-_stroke * 45.0) * 0.05
		if rattle > 0.01:
			# A loose clamp chatters in bursts; keep it audible, never harsh
			var want := 0.5 + 0.5 * sin(TAU * (6.0 + rattle * 9.0) * _t)
			_gate += (want - _gate) * 0.002
			s += (randf() * 2.0 - 1.0) * _gate * r2 * 0.16
			# ...and clicks you can hear on any speaker: metal on metal
			var click := exp(-fmod(_t * (6.0 + rattle * 9.0) * 2.0, 1.0) * 30.0)
			s += sin(TAU * 420.0 * _t) * click * r2 * 0.14
		# The poker: a petrol drive unit droning, the head chattering in the mix
		_rum += (rumble - _rum) * 0.0008
		if _rum > 0.005:
			_rph += dt * (95.0 + 75.0 * rumble_pitch)
			var saw := fmod(_rph, 1.0) * 2.0 - 1.0
			var chatter := 0.6 + 0.4 * sin(TAU * (23.0 - 9.0 * rumble_pitch) * _t)
			s += (saw * 0.07 + (randf() * 2.0 - 1.0) * 0.025 * (1.0 - rumble_pitch)) * _rum * chatter
		for e in _events:
			var a: float = e[1] + f * dt
			var kind: String = e[0]
			if kind.begins_with("whistle:"):
				if _whistle_on(kind.substr(8), a):
					s += sin(TAU * (2850.0 + 60.0 * sin(TAU * 32.0 * a)) * a) * 0.07
				continue
			match kind:
				"bang":
					s += ((randf() * 2.0 - 1.0) * 0.6 + sin(TAU * 38.0 * a) * 0.3 + sin(TAU * 110.0 * a) * 0.3) * exp(-a * 4.5)
				"clank":
					s += (sin(TAU * 780.0 * a) + 0.6 * sin(TAU * 1270.0 * a)) * exp(-a * 16.0) * 0.3
				"clang":
					s += (sin(TAU * 420.0 * a) + 0.7 * sin(TAU * 1130.0 * a) + 0.4 * sin(TAU * 1870.0 * a)) * exp(-a * 5.0) * 0.28
				"tink":
					s += sin(TAU * 2600.0 * a) * exp(-a * 30.0) * 0.18
				"thunk":
					s += (sin(TAU * 70.0 * a) * 0.45 + sin(TAU * 140.0 * a) * 0.25 + sin(TAU * 210.0 * a) * 0.1) * exp(-a * 9.0)
				"hiss":
					if a < 0.6:
						_hiss += ((randf() * 2.0 - 1.0) - _hiss) * 0.3
						s += _hiss * (0.6 - a) * 0.25
				"buzz":
					if a < 0.2:
						s += (1.0 if fmod(a * 110.0, 1.0) < 0.5 else -1.0) * 0.1
				"knock":
					s += (sin(TAU * 140.0 * a) + 0.5 * sin(TAU * 360.0 * a)) * exp(-a * 28.0) * 0.35
				"ring":
					s += (sin(TAU * 1650.0 * a) + 0.6 * sin(TAU * 2480.0 * a)) * exp(-a * 6.0) * 0.16
				"thud":
					s += (sin(TAU * 90.0 * a) * 0.35 + sin(TAU * 180.0 * a) * 0.2) * exp(-a * 22.0)
				"beep":
					if a < 0.25:
						s += (1.0 if fmod(a * 1100.0, 1.0) < 0.5 else -1.0) * 0.035
				"whip":
					s += ((randf() * 2.0 - 1.0) * 0.5 * exp(-a * 7.0) + sin(TAU * 55.0 * a) * 0.4 * exp(-a * 5.0))
				"scrape":
					if a < 0.26:
						_scr += ((randf() * 2.0 - 1.0) - _scr) * 0.08
						s += _scr * sin(a / 0.26 * PI) * 0.22
				"plop":
					s += sin(TAU * (520.0 - 900.0 * a) * a) * exp(-a * 30.0) * 0.12
				"chime":
					s += (sin(TAU * 1568.0 * a) * 0.14 + sin(TAU * 2093.0 * a) * 0.08) * exp(-a * 6.0)
				"ding":
					s += sin(TAU * 988.0 * a) * exp(-a * 3.5) * 0.2 + sin(TAU * 1318.0 * a) * exp(-a * 4.0) * 0.14
				"horn":
					# The boom's horn: two short tones, high then low, a bit of rasp
					if a < 0.5:
						var hf := 440.0 if a < 0.22 else 349.0
						var on := 1.0 if (a < 0.2 or (a > 0.26 and a < 0.48)) else 0.0
						s += ((1.0 if fmod(a * hf, 1.0) < 0.5 else -1.0) * 0.07 + sin(TAU * hf * 2.0 * a) * 0.05) * on
				"clunk":
					# A boom section locking out: heavy steel and a hydraulic thud
					s += (sin(TAU * 62.0 * a) * 0.4 + sin(TAU * 133.0 * a) * 0.2) * exp(-a * 6.0) + (sin(TAU * 610.0 * a) + 0.5 * sin(TAU * 1020.0 * a)) * exp(-a * 22.0) * 0.18
				"suck":
					# A stroke in reverse: the concrete pulled back up the hose
					if a < 0.4:
						_hiss += ((randf() * 2.0 - 1.0) - _hiss) * 0.15
						s += _hiss * sin(a / 0.4 * PI) * 0.18 + sin(TAU * (180.0 - 220.0 * a) * a) * exp(-a * 6.0) * 0.12
		# Soft limiter so stacked sounds never clip into a wall of noise
		s = tanh(s * 1.1) * 0.85
		buf[f] = Vector2(s, s)
	for e in _events:
		e[1] += n * dt
	_events = _events.filter(func(e): return e[1] < 2.0)
	_playback.push_buffer(buf)
