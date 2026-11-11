## "This way": for each person whose job wants them somewhere off the edge
## of their view (the coffee van, the pin bags, the haul rope), an arrow in
## their job's colour at that edge, pointing at it, with the place's name.
## Main view or street band, whichever they're in.
extends Control

const UI := preload("res://scripts/ui.gd")
const EDGE := 46.0      # px in from the view's edge
const TOP := 170.0      # px (at 900 tall) kept clear for the boom arm along the top
const R := 22.0         # arrow size

var game
var _marks: Array = []   # [screen pos, angle, colour, text]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	_marks.clear()
	if game == null or game.skyline or game.hud_off or not game.phase in ["inspect", "pour", "climb"]:
		queue_redraw()
		return
	var vs: Vector2 = get_viewport_rect().size
	var k := vs.y / 900.0
	for p in game.humans():
		if game.where_to(p) == "":
			continue
		var g: Array = game.go_to.get(p.role, [])
		if g.is_empty():
			continue
		var at: Vector3 = g[1]
		# Which view they're in, and where on the screen that is
		var in_band: bool = game.band_box != null and game.band_box.visible and game._height_group(p) == "street"
		var cam: Camera3D = game.band_cam if in_band else game.camera
		var region := Rect2(0, vs.y - game._band_h, vs.x, game._band_h) if in_band else Rect2(0, 0, vs.x, vs.y - (game._band_h if game.band_box != null and game.band_box.visible else 0.0))
		var inner := Rect2(region.position + Vector2(EDGE, (10.0 if in_band else TOP * k)), region.size - Vector2(EDGE * 2.0, (10.0 if in_band else TOP * k) + EDGE))
		if inner.size.x < 20.0 or inner.size.y < 20.0:
			continue
		var behind := cam.is_position_behind(at)
		var sp: Vector2 = cam.unproject_position(at)
		if in_band:
			var bv: SubViewport = game.band_view
			sp = region.position + sp * (region.size / Vector2(maxf(1.0, bv.size.x), maxf(1.0, bv.size.y)))
		if not behind and inner.has_point(sp):
			continue   # (on screen: its station ring and name show it)
		var c := inner.get_center()
		var dir := sp - c
		if behind:
			dir = -dir
		if dir.length() < 1.0:
			dir = Vector2(0, 1)
		# Out along that line to the edge of the inner box
		var tx := (inner.size.x * 0.5) / maxf(0.001, absf(dir.x))
		var ty := (inner.size.y * 0.5) / maxf(0.001, absf(dir.y))
		var edge := c + dir * minf(tx, ty)
		_marks.append([edge, dir.angle(), UI.ROLE.get(p.role, Color.WHITE), String(g[0])])
	queue_redraw()

func _draw() -> void:
	var f := UI.font("head")
	var k := get_viewport_rect().size.y / 900.0
	var r := R * k
	var fs := int(26 * k)
	for m in _marks:
		var at: Vector2 = m[0]
		var a: float = m[1]
		var col: Color = m[2]
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var tip := at + d * r
		var pts := PackedVector2Array([tip, at - d * r * 0.6 + n * r, at - d * r * 0.2, at - d * r * 0.6 - n * r])
		draw_colored_polygon(pts, col)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(0.08, 0.09, 0.1), 3.0 * k, true)
		# The place's name, on the inside of the arrow
		var text: String = m[3]
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tc := at - d * (r * 1.4 + tw * 0.5 * absf(d.x) + fs * 0.6 * absf(d.y))
		var box := Rect2(tc - Vector2(tw * 0.5 + 8.0 * k, fs * 0.62), Vector2(tw + 16.0 * k, fs * 1.24))
		draw_rect(box, Color(0.08, 0.09, 0.1, 0.82))
		draw_rect(Rect2(box.position, Vector2(4.0 * k, box.size.y)), col)
		draw_string(f, Vector2(box.position.x + 8.0 * k, tc.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
