## "UNDER CONSTRUCTION... COMING SOON" (John, 28 Nov: design A, the site hoarding). A tower whose
## pours aren't built yet still has its card, its fly-in and its level select, but nothing on the
## level select can be started: the picture behind goes grey, a blue site hoarding runs across it with
## a viewing window through to the tower, the floors are padlocked, and B goes back to the hand.
##
## A tower is "coming soon" when its card (tower_hand.gd TOWERS) says "soon": true. Its fly-in is the
## film at res://assets/fly/<id>_soon.ogv when that's there (it ends on the finished tower, and is
## held on its last frame); with no film yet, the card's roof view stays up behind the hoarding.
## Dev: `--soon=<id>` makes a playable tower's card act as one that isn't.
extends CanvasLayer

const UI := preload("res://scripts/ui.gd")
const GREY := preload("res://shaders/soon_grey.gdshader")
const GREY_TEX := preload("res://shaders/soon_grey_tex.gdshader")

const BLUE := Color("2f6fb3")
const BAND_Y := 350.0 / 900.0  # the hoarding on the level select: its top and its height, of the screen's
const BAND_H := 300.0 / 900.0  # (the screen is 900 high at "Screen text 100%", 720 at 125%, 600 at 150%)
const WIN := Vector2(245.0, 152.0)   # the viewing window on a hoarding 330 high: in from the right, down from the top
const WIN_RIM := 105.0               # its dark rim's radius, and the hole's
const WIN_R := 93.0
const FILM_IN_T := 0.6       # s: the film fades up over the roof view
const UP_T := 1.0            # s: the hoarding comes up as the film lands
const NO_FILM_T := 0.5       # s on the roof view first, when there's no film

static var _dev := ""

static func is_soon(c: Dictionary) -> bool:
	if _dev == "":
		_dev = "-"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--soon="):
				_dev = a.substr(7)
	return bool(c.get("soon", false)) or String(c.get("id", "")) == _dev

## The tower's fly-in film, or "" when it hasn't one yet.
static func film(c: Dictionary) -> String:
	var p := "res://assets/fly/%s_soon.ogv" % String(c.get("id", ""))
	return p if ResourceLoader.exists(p) else ""

## On the tower's card: its picture greyed, the hoarding across it.
static func mark_card(pic: Control, art: TextureRect, s: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = GREY_TEX
	art.material = m
	var h := Hoarding.new()
	h.small = true
	h.position = Vector2(0, 92) * s
	h.size = Vector2(268, 72) * s
	pic.add_child(h)

var card := {}
var game = null
var up_t := 0.0              # s since the hoarding was all the way up
var _t := 0.0
var _video: VideoStreamPlayer
var _grey: ShaderMaterial
var _ui: Control
var _landed := false
var _land_t := -1.0
var _left := false
var _hoard: Hoarding

func open(c: Dictionary, g) -> void:
	card = c
	game = g
	layer = 91                # (over the card's roof view, which tower_hand.gd leaves up on 90)
	var f := film(c)
	if f != "":
		_video = VideoStreamPlayer.new()
		_video.stream = load(f)
		_video.expand = true
		_video.volume_db = -80.0
		_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_video.modulate.a = 0.0
		_video.finished.connect(func(): _landed = true)
		add_child(_video)
		_video.play()
	else:
		_land_t = NO_FILM_T
	var gr := ColorRect.new()
	gr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grey = ShaderMaterial.new()
	_grey.shader = GREY
	_grey.set_shader_parameter("fade", 0.0)
	gr.material = _grey
	add_child(gr)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.modulate.a = 0.0
	add_child(_ui)
	_build()

func _build() -> void:
	var nm := String(card.get("name", ""))
	# the floors, padlocked
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 5)
	_ui.add_child(rail)
	UI.place(rail, Vector2(0, 0), Vector2(36, 26))
	rail.add_child(UI.head(nm, 24, UI.BONE, 6))
	var top := int(card.get("levels", 0))
	var sh := get_viewport().get_visible_rect().size.y if get_viewport() != null else 900.0
	for i in mini(clampi(int((sh * BAND_Y - 62.0) / 39.0), 2, 6), top):      # (as many as fit over the hoarding)
		rail.add_child(_row("L%02d" % (top - i)))
	if top <= 0:
		rail.add_child(_row("NO FLOORS OPEN"))
	# the hoarding
	var h := Hoarding.new()
	_hoard = h
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(h)
	# the plate
	var plate := UI.panel(Color(UI.CARD, 0.92), 22, Color(1, 1, 1, 0.08), 1, Vector4(20, 14, 26, 16))
	_ui.add_child(plate)
	UI.place(plate, Vector2(0, 1), Vector2(190, -30))
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 20)
	plate.add_child(ph)
	var lock := Padlock.new()
	lock.custom_minimum_size = Vector2(72, 80)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(lock)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	ph.add_child(pv)
	pv.add_child(UI.head(String(card.get("caption", nm)), 24, UI.GOLD))
	pv.add_child(UI.head("NOT OPEN YET", 50, UI.BONE))
	pv.add_child(UI.label("You can't start a pour here. Pick another tower.", 24, Color("d5d2c8"), 0))
	# the buttons: A's off, B goes back to the hand
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 22)
	bar.alignment = BoxContainer.ALIGNMENT_END
	_ui.add_child(bar)
	UI.place(bar, Vector2(1, 1), Vector2(-44, -36))
	var go := UI.pill(Color(UI.CARD, 0.6), Vector4(8, 6, 22, 6))
	go.add_child(_key("A", "POUR", Color("6b6f78")))
	go.modulate.a = 0.6
	bar.add_child(go)
	var back := UI.pill(UI.TRACK, Vector4(8, 6, 22, 6), UI.GOLD, 2)
	back.add_child(_key("B", "BACK TO TOWERS"))
	bar.add_child(back)

func _row(text: String) -> Control:
	var row := UI.pill(Color(UI.CARD, 0.55), Vector4(14, 1, 12, 1))
	row.custom_minimum_size = Vector2(150, 34)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var lab := UI.head(text, 26, Color("9a9da6"))
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lab)
	var lock := Padlock.new()
	lock.custom_minimum_size = Vector2(16, 18)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(lock)
	return row

func _key(letter: String, text: String, disc := Color(-1, 0, 0)) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var g := UI.glyph(letter, 46, disc)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(g)
	var l := UI.head(text, 28, UI.BONE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h

## One frame, with the crew's people: true once B has been pressed (the caller goes back to the hand).
func step(delta: float, people: Array) -> bool:
	_t += delta
	var sz := get_viewport().get_visible_rect().size
	var a := false
	var b := false
	for p in people:
		a = a or p.action_pressed()
		b = b or p.leave_pressed()
	if _video != null:
		# (the film covers the screen, whatever its shape)
		var ts := Vector2(_video.get_video_texture().get_size()) if _video.get_video_texture() != null else Vector2(16, 9)
		var k := maxf(sz.x / maxf(ts.x, 1.0), sz.y / maxf(ts.y, 1.0))
		_video.size = ts * k
		_video.position = (sz - ts * k) * 0.5
		_video.modulate.a = smoothstep(0.0, FILM_IN_T, _t)
		var length := _video.get_stream_length()
		if not _landed and length > 0.0 and _video.stream_position >= length - 0.12:
			_video.paused = true          # (held on its last frame)
			_landed = true
		if a and _t > 0.4:
			_landed = true                # (A: straight to the hoarding, the film runs out behind it)
	if _landed and _land_t < 0.0:
		_land_t = _t
		if game != null:
			game.sfx.hit("thunk")
	elif a and _land_t >= 0.0 and _t > _land_t + UP_T and game != null:
		game.sfx.hit("tink")              # (nothing to start here)
	var up := smoothstep(0.0, UP_T, _t - _land_t) if _land_t >= 0.0 else 0.0
	_ui.modulate.a = up
	_grey.set_shader_parameter("fade", up)
	_hoard.position = Vector2(0, sz.y * BAND_Y)
	_hoard.size = Vector2(sz.x, sz.y * BAND_H)
	var hk := _hoard.size.y / 330.0
	_grey.set_shader_parameter("hole", Vector2((sz.x - WIN.x * hk) / sz.x, (_hoard.position.y + WIN.y * hk) / sz.y))
	_grey.set_shader_parameter("hole_r", WIN_R * hk / sz.y)
	if up >= 1.0:
		up_t += delta
	if b and _t > 0.4 and not _left:
		_left = true
		return true
	return false

## What a phone's banner says while this is up.
func phone_line() -> String:
	return String(card.get("name", "")) + " · COMING SOON · B = BACK"

# ------------------------------------------------------------------ drawn bits

## The site hoarding: blue ply sheets, hazard stripes top and bottom, UNDER CONSTRUCTION... painted
## on it and a COMING SOON poster. Full size it has the line under it and a viewing window cut
## through (the picture behind shows in colour there); `small` is the card's.
class Hoarding extends Control:
	var small := false

	func _draw() -> void:
		var UIc := load("res://scripts/ui.gd")
		var f: Font = UIc.font("head")
		var w := size.x
		var h := size.y
		if w < 8.0 or h < 8.0:
			return                           # (not laid out yet)
		var k := h / 330.0
		var st := (16.0 if small else 22.0) * k * (2.0 if small else 1.0)
		var win := Vector2(w - WIN.x * k, WIN.y * k) if not small else Vector2(-9999, -9999)
		var wr := WIN_RIM * k
		# the ply, cut round the window
		if small:
			draw_rect(Rect2(0, 0, w, h), BLUE)
		else:
			for half in 2:
				var pts := PackedVector2Array()
				var y_edge := 0.0 if half == 0 else h
				pts.append(Vector2(0, y_edge))
				pts.append(Vector2(0, win.y))
				pts.append(Vector2(win.x - wr, win.y))
				for s in 25:
					var a := PI + (PI * s / 24.0) * (1.0 if half == 0 else -1.0)
					pts.append(win + Vector2(cos(a), sin(a)) * wr)
				pts.append(Vector2(w, win.y))
				pts.append(Vector2(w, y_edge))
				draw_colored_polygon(pts, BLUE)
			draw_arc(win, wr - 6.0 * k, 0, TAU, 64, Color("1a1d24"), 12.0 * k, true)
		# the joins between the sheets
		var step := 200.0 * k * (2.6 if small else 1.0)
		var x := step
		while x < w:
			if absf(x - win.x) < wr:
				var dy := sqrt(wr * wr - (x - win.x) * (x - win.x))
				draw_rect(Rect2(x - 2, st, 4, win.y - dy - st), Color(0, 0, 0, 0.28))
				draw_rect(Rect2(x - 2, win.y + dy, 4, h - st - win.y - dy), Color(0, 0, 0, 0.28))
			else:
				draw_rect(Rect2(x - 2, st, 4, h - st * 2.0), Color(0, 0, 0, 0.28))
			x += step
		# the stripes
		for y in [0.0, h - st]:
			draw_rect(Rect2(0, y, w, st), Color("ffd23f"))
			var sx := -st
			while sx < w:
				draw_colored_polygon(PackedVector2Array([Vector2(sx, y + st), Vector2(sx + st, y + st), Vector2(sx + st * 2.0, y), Vector2(sx + st, y)]), Color("1a1d24"))
				sx += st * 2.0
		# the paint
		var t1 := "UNDER CONSTRUCTION..."
		var left := (230.0 if not small else 34.0) * k * (1.0 if not small else 2.0)
		var room := (win.x - wr - 40.0 * k - left) if not small else (w - left * 2.0)
		var fs := int(128.0 * k) if not small else int(h * 0.36)
		var tw := f.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if tw > room:
			fs = int(fs * room / tw)
		var top := st + (h - st * 2.0) * (0.1 if not small else 0.06)
		draw_string(f, Vector2(left, top + fs * 0.82), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		# the poster
		var t2 := "COMING SOON"
		var fs2 := int(fs * 0.5) if not small else int(fs * 0.62)
		var w2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var pad := Vector2(fs2 * 0.34, fs2 * 0.16)
		var pr := Rect2(Vector2.ZERO, Vector2(w2, fs2) + pad * 2.0)
		draw_set_transform(Vector2(left, top + fs * 1.02 + (14.0 * k if not small else 0.0)), deg_to_rad(-2.0))
		draw_rect(Rect2(pr.position + Vector2(0, 4.0 * maxf(k, 0.5)), pr.size), Color(0, 0, 0, 0.35))
		draw_rect(pr, Color("ffd23f"))
		draw_string(f, pad + Vector2(0, fs2 * 0.8), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color("1a1d24"))
		draw_set_transform(Vector2.ZERO)
		if small:
			return
		var body: Font = UIc.font("body")
		var lines := ["This tower's pours aren't built yet.", "Have a look through the fence."]
		for i in lines.size():
			draw_string(body, Vector2(left + pr.size.x + 26.0, top + fs * 1.02 + 14.0 * k + 30.0 + i * 32.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
		var t3 := "VIEWING WINDOW"
		var w3 := f.get_string_size(t3, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(f, Vector2(win.x - w3 * 0.5, win.y + wr + 22.0), t3, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

## A padlock: a body and a shackle, in outline.
class Padlock extends Control:
	var color := Color("9a9da6")
	func _draw() -> void:
		var s := size
		var lw := maxf(2.0, s.x * 0.11)
		draw_rect(Rect2(s.x * 0.12, s.y * 0.45, s.x * 0.76, s.y * 0.5), color, false, lw)
		draw_arc(Vector2(s.x * 0.5, s.y * 0.45), s.x * 0.2, PI, TAU, 16, color, lw, true)
