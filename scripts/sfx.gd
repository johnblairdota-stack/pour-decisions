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

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	stream = gen
	volume_db = -14.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback

## kind: "bang", "clank", "thunk", "buzz", "ding", "clang", "tink", "hiss",
## "knock", "ring", "thud", "beep", "whip", "rain",
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

func _whistle_on(code: String, a: float) -> bool:
	var t := 0.0
	for seg in WHISTLES.get(code, []):
		if a >= t and a < t + seg[0]:
			return true
		t += seg[0] + seg[1]
	return false

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(n)
	var dt := 1.0 / RATE
	var r2 := rattle * rattle
	for f in n:
		_t += dt
		var s := 0.0
		if pumping:
			_stroke += dt
			if _stroke > 0.8:
				_stroke -= 0.8
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
		# Soft limiter so stacked sounds never clip into a wall of noise
		s = tanh(s * 1.1) * 0.85
		buf[f] = Vector2(s, s)
	for e in _events:
		e[1] += n * dt
	_events = _events.filter(func(e): return e[1] < 2.0)
	_playback.push_buffer(buf)
