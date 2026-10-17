## The slump test's guide, over its close-up: the six steps in a row, ticked
## off as they're done with the one being done lit up, and a line under them
## saying what this step is for (or what the reading means). It sizes itself
## to its text: the line wraps to the close-up's width, and the box grows to
## take it.
extends Control

const GOLD := Color("ffd23f")
const DONE := Color("7cd992")
const BG := Color(0.04, 0.07, 0.12, 0.9)

var steps: Array = []      # the step names
var at := 0                # the step being done (steps.size(): all done)
var text := ""
var accent := Color.WHITE  # the job's colour, for the edge
var width := 563.0
var _font: Font
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

## Lays it out for this width; returns its height.
func fit(w: float) -> float:
	width = w
	var h := 12.0 + 30.0 + 8.0 + _text_size().y + 12.0
	size = Vector2(w, h)
	custom_minimum_size = size
	return h

func _text_size() -> Vector2:
	return _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 19)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if steps.is_empty():
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(8)
	sb.border_color = accent
	sb.set_border_width_all(2)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	# The steps, as numbered pills that share the width
	var n := steps.size()
	var gap := 4.0
	var pw := (width - 24.0 - gap * (n - 1)) / n
	var fs := 13
	for i in n:
		var r := Rect2(12.0 + i * (pw + gap), 12.0, pw, 30.0)
		var col := Color(1, 1, 1, 0.12)
		var tc := Color(1, 1, 1, 0.55)
		var label := "%d %s" % [i + 1, steps[i]]
		if i < at:
			col = Color(DONE, 0.3)
			tc = DONE
			label = "✓ " + String(steps[i])
		elif i == at:
			col = GOLD.lerp(Color.WHITE, 0.15 * (0.5 + 0.5 * sin(_t * 5.0)))
			tc = Color("0f1b2d")
		var ps := StyleBoxFlat.new()
		ps.bg_color = col
		ps.set_corner_radius_all(6)
		draw_style_box(ps, r)
		# (shrinks to fit its pill)
		var f := fs
		while f > 9 and _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, f).x > pw - 6.0:
			f -= 1
		draw_string(_font, Vector2(r.position.x, r.position.y + 15.0 + f * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, pw, f, tc)
	# What this step is for
	draw_multiline_string(_font, Vector2(14.0, 12.0 + 30.0 + 8.0 + 19.0 * 0.85), text, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 19, -1, Color.WHITE)
