## The button cue again, flat, in the corner of a close-up camera: the same
## button, hold ring and gold "let go here" band the player has floating by
## their head, so someone watching the close-up can time a hammer swing off
## it. In the gold band the fill turns gold, the button flashes and sparks fly.
extends Control

const PLAYER := preload("res://scripts/player.gd")
const GOLD := Color("ffd23f")
const DARK := Color(0.06, 0.08, 0.12, 0.85)

var cue: Array = []        # [btn, verb, progress, urgent, zone, alarm] or []
var _t := 0.0
var _flash := 0.0
var _sparks: Array = []    # {pos, vel, life}
var _was_in := false
var _font: Font
var max_w := 0.0           # the width it has to fit in (its close-up's); 0: any

func _ready() -> void:
	custom_minimum_size = Vector2(190, 70)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func show_cue(c: Array) -> void:
	cue = c
	visible = not c.is_empty()

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	var now_in := false
	if not cue.is_empty():
		var z: Vector2 = cue[4]
		var pr: float = cue[2]
		now_in = PLAYER.is_gold(cue) and not cue[5]
	if now_in and not _was_in:
		_flash = 1.0
		for k in 14:
			var a := randf() * TAU
			_sparks.append({"pos": Vector2(34, 35), "vel": Vector2(cos(a), sin(a)) * randf_range(60, 150), "life": randf_range(0.3, 0.6)})
	if now_in and randf() < delta * 18.0:
		var a2 := randf() * TAU
		_sparks.append({"pos": Vector2(34, 35) + Vector2(cos(a2), sin(a2)) * 30.0, "vel": Vector2(cos(a2), sin(a2)) * 70.0, "life": 0.35})
	_was_in = now_in
	for s in _sparks:
		s["pos"] += s["vel"] * delta
		s["vel"] *= 0.9
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	queue_redraw()

func _draw() -> void:
	if cue.is_empty():
		return
	var btn: String = cue[0]
	var verb: String = cue[1]
	var pr: float = cue[2]
	var urgent: bool = cue[3]
	var z: Vector2 = cue[4]
	var alarm: bool = cue[5]
	var c := Vector2(34, 35)
	var col: Color = Color("ff2d2d") if alarm else PLAYER.BTN_COLORS.get(btn, Color.WHITE)
	var in_zone: bool = PLAYER.is_gold(cue) and not alarm
	var pulse := 0.5 + 0.5 * sin(_t * (18.0 if alarm or in_zone else (9.0 if urgent else 5.0)))
	# Halo
	var halo_col := (GOLD if in_zone else col)
	halo_col.a = 0.25 + 0.35 * pulse + 0.4 * _flash
	draw_circle(c, 30.0 + 4.0 * pulse + 8.0 * _flash, halo_col)
	# Track for the hold ring
	draw_arc(c, 25.0, 0, TAU, 40, DARK, 7.0, true)
	# The gold band, outside the ring: thick and bright so it's easy to spot
	if z.x >= 0.0:
		var a0 := -PI * 0.5 + z.x * TAU
		var a1 := -PI * 0.5 + z.y * TAU
		var band := GOLD.lightened(0.3 * pulse) if in_zone else GOLD
		draw_arc(c, 31.0, a0, a1, 16, band, 6.0, true)
		draw_arc(c, 31.0, a0, a1, 16, Color(1, 1, 1, 0.5 * pulse), 2.0, true)
	# Hold progress fill: white, gold while you're in the band, red past it
	if pr >= 0.0:
		var fill := Color.WHITE
		if z.x >= 0.0 and pr > z.y:
			fill = Color("ff5a5f")
		elif in_zone:
			fill = GOLD
		draw_arc(c, 25.0, -PI * 0.5, -PI * 0.5 + clampf(pr, 0.0, 1.0) * TAU, 40, fill, 7.0, true)
	# The button
	var bc := col.lerp(GOLD, 0.6 * _flash + (0.35 if in_zone else 0.0))
	draw_circle(c, 19.0, Color.WHITE)
	draw_circle(c, 17.0, bc)
	draw_string(_font, c + Vector2(-8, 8), btn, HORIZONTAL_ALIGNMENT_CENTER, 16, 22, Color("0f1b2d"))
	# Sparks
	for s in _sparks:
		var p: Vector2 = s["pos"]
		var v: Vector2 = s["vel"]
		draw_line(p, p - v.normalized() * 6.0, Color(1.0, 0.85, 0.3, clampf(s["life"] * 3.0, 0.0, 1.0)), 2.0)
	# The word, on a dark tag sized to it: shrunk a little, then wrapped onto
	# a second line, so it always fits inside the close-up
	if verb != "":
		var txt := verb.to_upper() if in_zone else verb
		var room := (max_w - 70.0 - 8.0) if max_w > 0.0 else 9999.0
		var fs := 18
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while w > room and fs > 14:
			fs -= 1
			w = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lines := [txt]
		if w > room:
			lines = _wrap(txt, fs, room)
			w = 0.0
			for ln in lines:
				w = maxf(w, _font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var lh := fs + 4.0
		var top := 35.0 - lh * lines.size() * 0.5
		draw_rect(Rect2(62, top - 4, w + 16, lh * lines.size() + 8), Color(0.03, 0.05, 0.09, 0.72))
		for i in lines.size():
			var at := Vector2(70, top + lh * i + fs * 0.85)
			draw_string(_font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD if in_zone else Color.WHITE)

## Splits a line into words that fit `room` px at size `fs`.
func _wrap(txt: String, fs: int, room: float) -> Array:
	var out: Array = []
	var cur := ""
	for word in txt.split(" "):
		var tryit := word if cur == "" else cur + " " + word
		if cur != "" and _font.get_string_size(tryit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
			out.append(cur)
			cur = word
		else:
			cur = tryit
	if cur != "":
		out.append(cur)
	return out
