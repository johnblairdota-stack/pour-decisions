## The slump test's guide: a header strip joined onto the top of its zoom-in.
## One line: a dot per step (ticked when done, the one being done lit gold),
## then the step's name and what you're doing and why (or what the reading
## means). The words shrink a little to stay on one line, and only wrap when
## they really can't fit; the strip grows to take them.
extends Control

const GOLD := Color("ffd23f")
const DONE := Color("7cd992")
const BG := Color(0.04, 0.07, 0.12, 0.97)
const DOT := 13.0
const DOT_GAP := 5.0
const PAD := 8.0
const MAX_FS := 17
const MIN_FS := 13

var steps: Array = []      # the step names
var at := 0                # the step being done (steps.size(): all done)
var text := ""
var accent := Color.WHITE  # the job's colour, for the edge
var width := 400.0
var _font: Font
var _bold: Font
var _t := 0.0
var _fs := MAX_FS
var _lines: Array = []     # [[name part, rest]] per line

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = _font
	fv.variation_embolden = 0.8
	_bold = fv

func _name() -> String:
	return "READING" if at >= steps.size() else String(steps[at])

func _text_x() -> float:
	return PAD + steps.size() * (DOT + DOT_GAP) + 6.0

## Lays it out for this width; returns its height.
func fit(w: float) -> float:
	if _font == null:
		_ready()
	width = w
	var room := w - _text_x() - PAD
	var name := _name() + "  "
	_fs = MAX_FS
	while _fs > MIN_FS and _bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x + _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x > room:
		_fs -= 1
	# Word-wrap name + text into the room left of the dots
	_lines = []
	var cur_name := name
	var cur := ""
	var used := _bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
	for word in text.split(" "):
		var tryit := word if cur == "" else cur + " " + word
		if cur != "" and used + _font.get_string_size(tryit, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x > room:
			_lines.append([cur_name, cur])
			cur_name = ""
			used = 0.0
			cur = word
		else:
			cur = tryit
	_lines.append([cur_name, cur])
	var h := maxf(DOT, _lines.size() * (_fs + 4.0)) + PAD * 2.0
	size = Vector2(w, h)
	custom_minimum_size = size
	return h

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if steps.is_empty():
		return
	# Joined to the zoom-in under it: rounded on top, square at the bottom,
	# edged in the job's colour like the zoom-in's frame
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.border_color = accent
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	# A dot per step
	var cy := PAD + DOT * 0.5
	for i in steps.size():
		var c := Vector2(PAD + DOT * 0.5 + i * (DOT + DOT_GAP), cy)
		if i < at:
			draw_circle(c, DOT * 0.5, DONE)
			draw_polyline(PackedVector2Array([c + Vector2(-3.5, 0), c + Vector2(-1, 2.8), c + Vector2(3.8, -2.8)]), Color("0f1b2d"), 2.0, true)
		elif i == at:
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_circle(c, DOT * 0.5 + 1.5 * pulse, Color(GOLD, 0.35))
			draw_circle(c, DOT * 0.5, GOLD)
		else:
			draw_arc(c, DOT * 0.5 - 1.0, 0.0, TAU, 20, Color(1, 1, 1, 0.45), 2.0, true)
	# The step's name in gold, then what it's for
	var lh := _fs + 4.0
	var top := PAD + maxf(0.0, (DOT - lh) * 0.5)
	for li in _lines.size():
		var y := top + li * lh + _fs * 0.85
		var x := _text_x()
		var nm: String = _lines[li][0]
		if nm != "":
			draw_string(_bold, Vector2(x, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, GOLD)
			x += _bold.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
		draw_string(_font, Vector2(x, y), _lines[li][1], HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, Color.WHITE)
