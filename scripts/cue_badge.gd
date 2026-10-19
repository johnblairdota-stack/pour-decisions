## The button cue again, flat, in the corner of a close-up camera: the same
## Site Kit button the player has floating by their head (disc on its lip,
## white rim, hold ring with the gold "let go here" arc, concrete filling it
## while held), so someone watching the close-up can time a hammer swing off
## it. In the gold moment it beats fast and throws gold star sparks.
extends Control

const PLAYER := preload("res://scripts/player.gd")
const UI := preload("res://scripts/ui.gd")
const GOLD := Color("ffd23f")
const CONCRETE := Color("9e9b94")

var cue: Array = []        # [btn, verb, progress, urgent, zone, alarm] or []
var dot_color := Color(-1, 0, 0)   # the job's dot on the verb tag (none if unset)
var _t := 0.0
var _flash := 0.0
var _sparks: Array = []    # {pos, vel, life, rot}
var _was_in := false
var _font: Font
var _body: Font
var max_w := 0.0           # the width it has to fit in (its close-up's); 0: any

func _ready() -> void:
	custom_minimum_size = Vector2(190, 70)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UI.font("head")

func show_cue(c: Array) -> void:
	cue = c
	visible = not c.is_empty()

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	var now_in := false
	if not cue.is_empty():
		now_in = PLAYER.is_gold(cue) and not cue[5]
	var c := Vector2(34, 35)
	if now_in and not _was_in:
		_flash = 1.0
		for k in 14:
			var a := randf() * TAU
			_sparks.append({"pos": c, "vel": Vector2(cos(a), sin(a)) * randf_range(90, 190), "life": randf_range(0.4, 0.7), "rot": randf() * TAU})
	if now_in and randf() < delta * 10.0:
		var a2 := randf() * TAU
		_sparks.append({"pos": c + Vector2(cos(a2), sin(a2)) * 28.0, "vel": Vector2(cos(a2), sin(a2)) * 60.0, "life": 0.45, "rot": randf() * TAU})
	_was_in = now_in
	for s in _sparks:
		s["pos"] += s["vel"] * delta
		s["vel"] *= 0.9
		s["life"] -= delta
		s["rot"] += delta * 5.0
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
	var in_zone: bool = PLAYER.is_gold(cue) and not alarm
	# The motion, as on the phone: breathe, press-now pulse, gold beat, shake
	var period := UI.BREATHE_T
	var amp := UI.BREATHE_S - 1.0
	if alarm:
		period = UI.SHAKE_T * 2.0
		amp = 0.08
	elif in_zone:
		period = UI.GOLD_T
		amp = 0.1
	elif urgent:
		period = UI.URGENT_T
		amp = UI.URGENT_S - 1.0
	var pl := 0.5 - 0.5 * cos(_t * TAU / period)
	var k := 1.0 + amp * pl
	var c := Vector2(34, 35)
	if alarm:
		var w := _t * TAU / UI.SHAKE_T
		c += Vector2(sin(w), sin(w * 0.8 + 1.0)) * 2.0
	var face: Color = UI.ALARM if alarm else UI.GLYPH.get(btn, Color.WHITE)
	var lip: Color = face.darkened(0.45) if alarm else UI.LIP.get(btn, face.darkened(0.45))
	if in_zone:
		face = GOLD
		lip = Color("b17a00")
	# Halo
	var halo_col := GOLD if in_zone else face
	halo_col.a = 0.18 + 0.25 * pl + 0.4 * _flash
	draw_circle(c, (28.0 + 4.0 * pl + 8.0 * _flash) * k, halo_col, true, -1.0, true)
	# Hold ring track, then its fill: white, gold in the band, red past it
	if pr >= 0.0 or z.x >= 0.0:
		draw_arc(c, 25.0 * k, 0, TAU, 48, UI.TRACK, 6.0, true)
	if z.x >= 0.0:
		var a0 := -PI * 0.5 + z.x * TAU
		var a1 := -PI * 0.5 + z.y * TAU
		draw_arc(c, 31.0 * k, a0, a1, 16, Color(1.0, 0.97, 0.6) if in_zone else GOLD, 5.0, true)
	if pr >= 0.0:
		var fill := Color.WHITE
		if z.x >= 0.0 and pr > z.y:
			fill = UI.ALARM
		elif in_zone:
			fill = GOLD
		draw_arc(c, 25.0 * k, -PI * 0.5, -PI * 0.5 + clampf(pr, 0.0, 1.0) * TAU, 48, fill, 6.0, true)
	# The button: white rim, lip, face
	var r := 17.0 * k
	var drop := 3.0 * k
	draw_circle(c + Vector2(0, drop * 0.5), r + 2.0, Color.WHITE, true, -1.0, true)
	draw_circle(c + Vector2(0, drop), r, lip, true, -1.0, true)
	var fc := face.lerp(Color.WHITE, 0.4 * _flash)
	draw_circle(c, r, fc, true, -1.0, true)
	# Concrete rising in it while it's held
	if pr > 0.0:
		var lvl := clampf(pr, 0.0, 1.0)
		var pts := PackedVector2Array()
		var top := r - 2.0 * r * lvl
		for i in 33:
			var a := TAU * i / 32.0
			var p := Vector2(cos(a), sin(a)) * r
			if p.y < top:
				p.y = top
			pts.append(c + p)
		draw_colored_polygon(pts, Color(CONCRETE, 0.6))
	var ink: Color = Color.WHITE if alarm else (Color("2a1d00") if in_zone else UI.GLYPH_INK.get(btn, Color("0f1b2d")))
	var fs := int(24 * k)
	var lw := _font.get_string_size(btn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, c + Vector2(-lw * 0.5, fs * 0.36), btn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# Star sparks
	for s in _sparks:
		_star(s["pos"], 5.0 * clampf(s["life"] * 2.5, 0.2, 1.0), s["rot"], Color(GOLD, clampf(s["life"] * 3.0, 0.0, 1.0)))
	# The verb tag: a dark pill with the job's dot, shrunk a little and then
	# wrapped onto a second line so it always fits inside the close-up
	if verb != "":
		var txt := verb.to_upper() if in_zone else verb
		var dot_w := 16.0 if dot_color.r >= 0.0 or alarm else 0.0
		var room := (max_w - 70.0 - 20.0 - dot_w) if max_w > 0.0 else 9999.0
		var tfs := 20
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		while w > room and tfs > 15:
			tfs -= 1
			w = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
		var lines := [txt]
		if w > room:
			lines = _wrap(txt, tfs, room)
			w = 0.0
			for ln in lines:
				w = maxf(w, _font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x)
		var lh := tfs + 3.0
		var hgt := lh * lines.size() + 8.0
		var top2 := 35.0 - hgt * 0.5
		var box := Rect2(60, top2, w + 24 + dot_w, hgt)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UI.TRACK, 0.92)
		sb.set_corner_radius_all(int(minf(hgt * 0.5, 18.0)))
		sb.anti_aliasing = true
		if in_zone or alarm:
			sb.border_color = GOLD if in_zone else UI.ALARM
			sb.set_border_width_all(2)
		draw_style_box(sb, box)
		if dot_w > 0.0:
			draw_circle(Vector2(box.position.x + 14, 35.0), 5.0, UI.ALARM if alarm else dot_color, true, -1.0, true)
		var col: Color = Color("ff6b5f") if alarm else (GOLD if in_zone else UI.BONE)
		for i in lines.size():
			var at := Vector2(box.position.x + 12 + dot_w, top2 + 4 + lh * i + tfs * 0.82)
			draw_string(_font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, col)

## A four-point star spark.
func _star(at: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot + PI * 0.25 * i
		var rr := r if i % 2 == 0 else r * 0.32
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)

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
