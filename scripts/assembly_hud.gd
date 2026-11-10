extends Control
## The assembly HUD: a flat drawing of the real kit round the edge of the
## screen, and every reading shown on the part it belongs to.
##
##   - The placing boom reaches across the top. The job in hand is written on
##     its outer arm, what's coming next on the inner arm.
##   - The tower stands hard against the right edge, a section for each one
##     in the game (it fits the same space however tall it's climbed), with
##     the riser beside it: a lever clamp and a red pin at every joint, and
##     dashes that run while concrete's moving and stop dead when it isn't.
##   - The pump and its hopper sit at the foot of the tower: the gauge, the
##     fill level and the two keep-it-between lines.
##   - The agitators line up along the bottom and back up to the hopper,
##     each with its load's age on the drum.
##   - A hat stands where each person's working. A fault shows at its real
##     spot, with who, what and which button.
##
## It's all drawn in a 900-high space scaled to the screen, from `st` (set by
## hud.gd and main.gd each frame), in the look of the game's own models:
## flat fills, a dark outline.

const UI := preload("res://scripts/ui.gd")
const Icons := preload("res://scripts/icons.gd")

const INK := Color("141a26")
const STEEL := Color("dfe3ea")
const STEEL_D := Color("9aa3b2")
const YEL := Color("f6d743")
const YEL_D := Color("d9b21f")
const ORANGE := Color("ff8a1f")
const BLUE := Color("2f4f9e")
const CONC := Color("a4abb3")
const AMBER := Color("f2b51f")
const LW := 3.0
const KIT := 0.74         # the trucks, hopper and pump are drawn this much smaller than the tower
const TOP := 182.0        # the tower's collar
const TRUCK_L := 262.0    # a truck and its gap
const AGE_WARN := 78.0
const AGE_MAX := 90.0

## What to show. hud.gd fills the readings it's always had; main.gd adds the
## kit (assembly_state()).
var st := {
	"chip": "", "title": "", "progress": -1.0, "clock": "", "next": "", "next_chip": "NEXT UP", "alarm": false,
	"cash": 0, "bump": 0.0, "level": "",
	"sections": 4, "deck": 0.0, "deck_tag": "",
	"clamps": [], "bad": -1, "flow": false, "down": false,
	"fault": {},
	"wind": 0.0, "wind_stop": 72.0,
	"pump": false, "bar": 0.0, "spike": false, "tripped": false, "hopper": 0.0, "band": Vector2(0.4, 0.85), "startup": false,
	"trucks": [], "hats": [],
}
var lift := 0.0           # px the bottom's lifted, clear of the street band
var fault_rect := Rect2()  # where the fault's call-out is on the screen (px), for the close-ups to keep off

var _t := 0.0
var _flow := 0.0
var _truck_x := {}        # truck id -> where it's drawn (x)
var _boxes := {}
var _w := 1600.0
var _g := 872.0           # the ground line
var _gs := 1.0            # the trucks and pump are drawn smaller over a split screen
var _head: Font
var _body: Font
# Redrawing the lot every frame cost about 5 ms, so it's in three layers:
# the trucks (redrawn when one moves or its age ticks over), the kit as it
# stands (redrawn when the tower grows or the screen changes), and the
# moving parts and readings (every other frame).
var _c: CanvasItem
var _layers: Array[Layer] = []
var _static_key := ""
var _truck_key := ""
var _tick := 0
# UI motion: what changed, and when
var _title_was := ""
var _title_at := -10.0
var _next_was := ""
var _next_at := -10.0
var _fault_was := ""
var _fault_at := -10.0

## 0 to 1 over `secs` since `at`, easing out.
func _since(at: float, secs := 0.28) -> float:
	return ease(clampf((_t - at) / secs, 0.0, 1.0), 0.35)

class Layer extends Control:
	var hud
	var which := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		hud._paint(self, which)

func _ready() -> void:
	# (anchors AND offsets: set once it's in the tree, anchors alone keep
	# the empty rect it was added with)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head = UI.font("head")
	_body = UI.font("body")
	for i in 3:
		var l := Layer.new()
		l.hud = self
		l.which = i
		add_child(l)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_layers.append(l)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if st["flow"]:
		_flow = fmod(_flow + delta * 60.0, 24.0)
	# The trucks roll to their places
	var seen := {}
	for tr in st["trucks"]:
		var id: int = tr["id"]
		seen[id] = true
		var want := _slot_x(int(tr["slot"]))
		if not _truck_x.has(id):
			_truck_x[id] = -TRUCK_L - 40.0
		_truck_x[id] = move_toward(_truck_x[id], want, delta * maxf(90.0, absf(want - _truck_x[id]) * 1.6))
	for id in _truck_x.keys():
		if not seen.has(id):
			_truck_x.erase(id)
	_tick += 1
	var skey := "%s|%d" % [str(size), int(st["sections"])]
	var tkey := skey
	for tr in st["trucks"]:
		tkey += "|%d:%d:%d" % [int(_truck_x.get(tr["id"], 0.0)), int(tr["age"]), int(tr["slot"])]
	var moved := skey != _static_key
	if moved:
		_static_key = skey
		_layers[1].queue_redraw()
	if tkey != _truck_key:
		_truck_key = tkey
		_layers[0].queue_redraw()
	if _tick % 2 == 0 or moved:
		_layers[2].queue_redraw()

## Where the hopper stands, and so where the trucks back up to.
func _hopper_x() -> float:
	return _w - 330.0

func _slot_x(slot: int) -> float:
	if slot < 0:
		return -TRUCK_L - 60.0   # (off down the road)
	return _hopper_x() - 34.0 - 250.0 - slot * TRUCK_L

## Paints one layer (see Layer). 0 the trucks, 1 the kit as it stands, 2
## everything that moves or reads out.
func _paint(c: CanvasItem, which: int) -> void:
	_c = c
	var k := size.y / 900.0
	if k <= 0.0:
		return
	_w = size.x / k
	# (the kit's the full height of the screen, split or not, and sits on
	# its bottom edge)
	_g = 900.0 - 12.0
	# (with the street band along the bottom, the real trucks and pump are
	# right there in it: the drawn ones shrink, to leave the deck in view)
	_gs = KIT
	var pivot := Vector2(_riser_x(), _g)
	_c.draw_set_transform(pivot * (1.0 - _gs) * k, 0.0, Vector2(k, k) * _gs)
	match which:
		0:
			_draw_trucks()
		1:
			_draw_pump_static()
			_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
			_draw_tower_static()
			_draw_boom_static()
		2:
			_draw_pump_live()
			_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
			_draw_tower_live()
			_draw_boom_live()
			_draw_wind()
			_draw_cash()
			_draw_hats()
			_draw_fault()

# ------------------------------------------------------------------ helpers

func _box(r: Rect2, fill: Color, radius := 8.0, edge := INK, w := LW) -> void:
	var key := "%s|%s|%d|%d" % [fill.to_html(), edge.to_html(), int(radius), int(w * 10.0)]
	if not _boxes.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(int(radius))
		sb.border_color = edge
		sb.set_border_width_all(int(w))
		sb.anti_aliasing = true
		_boxes[key] = sb
	_c.draw_style_box(_boxes[key], r)

func _poly(pts: PackedVector2Array, fill: Color, edge := INK, w := LW) -> void:
	_c.draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	_c.draw_polyline(loop, edge, w, true)

func _disc(c: Vector2, r: float, fill: Color, edge := INK, w := LW) -> void:
	_c.draw_circle(c, r, fill, true, -1.0, true)
	_c.draw_arc(c, r, 0.0, TAU, 32, edge, w, true)

func _tw(s: String, fs: int, f: Font = null) -> float:
	return (f if f != null else _head).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## Text with its baseline at `at`. `outline` for text over the world.
func _text(at: Vector2, s: String, fs: int, col: Color, outline := 0, f: Font = null) -> void:
	var font := f if f != null else _head
	if outline > 0:
		_c.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(INK, 0.9))
	_c.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## The biggest size from `fs` down to `least` at which `s` fits in `room`.
func _fit(s: String, fs: int, room: float, least := 24) -> int:
	while fs > least and _tw(s, fs) > room:
		fs -= 2
	return fs

func _pipe(pts: PackedVector2Array, w := 9.0) -> void:
	_c.draw_polyline(pts, INK, w + 4.0, true)
	_c.draw_polyline(pts, STEEL, w - 2.0, true)

## Dashes along a run of pipe, `off` px along (so they can move).
func _dashes(pts: PackedVector2Array, off: float, col: Color, w := 3.0) -> void:
	const ON := 14.0
	const GAP := 10.0
	var d := -fmod(off, ON + GAP)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ln := a.distance_to(b)
		if ln < 0.01:
			continue
		var dir := (b - a) / ln
		while d < ln:
			var s := maxf(d, 0.0)
			var e := minf(d + ON, ln)
			if e > s:
				_c.draw_line(a + dir * s, a + dir * e, col, w, true)
			d += ON + GAP
		d -= ln

## A spot on the trucks and pump, as it lands on the screen at their scale.
func _gp(v: Vector2) -> Vector2:
	var pivot := Vector2(_riser_x(), _g)
	return pivot + (v - pivot) * _gs

## A text size that stays readable when the trucks and pump are drawn small.
func _gfs(fs: int) -> int:
	return int(minf(fs * 1.5, fs / _gs))

func _pulse(rate := 2.0) -> float:
	return 0.5 + 0.5 * sin(_t * TAU * rate)

# ------------------------------------------------------------------ the tower

func _tower_x() -> Vector2:
	return Vector2(_w - 112.0, _w - 48.0)   # its two legs

func _riser_x() -> float:
	return _w - 128.0

func _base() -> float:
	return _g - 6.0

## How far up the screen a share of the tower's height is.
func _tower_y(f: float) -> float:
	return lerpf(_base() - 10.0, TOP + 10.0, clampf(f, 0.0, 1.0))

func _draw_tower_static() -> void:
	var tx := _tower_x()
	var base := _base()
	var n: int = maxi(1, int(st["sections"]))
	var sh := (base - TOP) / n
	var cx := (tx.x + tx.y) * 0.5
	# The ladder and the haul rope, on the far side
	var lx := tx.y + 14.0
	_c.draw_line(Vector2(lx, TOP), Vector2(lx, base), ORANGE.darkened(0.25), 2.5)
	_c.draw_line(Vector2(lx + 11.0, TOP), Vector2(lx + 11.0, base), ORANGE.darkened(0.25), 2.5)
	var ry := TOP + 6.0
	while ry < base:
		_c.draw_line(Vector2(lx, ry), Vector2(lx + 11.0, ry), ORANGE.darkened(0.25), 2.0)
		ry += 9.0
	_dashes(PackedVector2Array([Vector2(lx + 20.0, TOP), Vector2(lx + 20.0, base - 26.0)]), 0.0, Color(INK, 0.7), 1.5)
	_c.draw_colored_polygon(PackedVector2Array([Vector2(lx + 16.0, base - 26.0), Vector2(lx + 24.0, base - 26.0), Vector2(lx + 20.0, base - 16.0)]), INK)
	# Lattice sections: K bracing between two legs, a flange at each joint
	for i in n:
		var y0 := TOP + i * sh
		var y1 := y0 + sh
		var brace := PackedVector2Array([Vector2(tx.x + 6.0, y1 - 3.0), Vector2(cx, y0 + 5.0), Vector2(tx.y - 6.0, y1 - 3.0)])
		_c.draw_polyline(brace, INK, 6.0, true)
		_c.draw_polyline(brace, STEEL_D, 2.5, true)
		_c.draw_line(Vector2(tx.x, y0 + sh * 0.5), Vector2(tx.y, y0 + sh * 0.5), Color(INK, 0.55), 2.0)
	for x in [tx.x, tx.y]:
		_c.draw_rect(Rect2(x - 5.5, TOP, 11.0, base - TOP), INK)
		_c.draw_rect(Rect2(x - 2.5, TOP, 5.0, base - TOP), STEEL)
	for i in n + 1:
		var y := TOP + i * sh
		for x in [tx.x, tx.y]:
			_c.draw_rect(Rect2(x - 8.0, y - 3.0, 16.0, 6.0), INK)
		# (the pipe bracket that holds the riser off the mast)
		if i < n:
			_c.draw_line(Vector2(_riser_x(), y + sh * 0.5), Vector2(tx.x, y + sh * 0.5), INK, 3.0)
	_box(Rect2(tx.x - 14.0, base - 4.0, tx.y - tx.x + 28.0, 14.0), Color("3a4252"), 3.0)
	_pipe(_line_run())
	# The head: railed platform, slew ring, turret, counterweight, tank
	_c.draw_rect(Rect2(tx.x - 22.0, TOP - 10.0, tx.y - tx.x + 56.0, 10.0), INK)
	_c.draw_rect(Rect2(tx.x - 19.0, TOP - 7.0, tx.y - tx.x + 50.0, 4.0), Color("596275"))
	_c.draw_line(Vector2(tx.x - 22.0, TOP - 26.0), Vector2(tx.y + 34.0, TOP - 26.0), ORANGE, 3.0)
	for i in 5:
		var px := lerpf(tx.x - 21.0, tx.y + 33.0, i / 4.0)
		_c.draw_line(Vector2(px, TOP - 26.0), Vector2(px, TOP - 10.0), ORANGE, 2.5)
	_box(Rect2(cx - 20.0, TOP - 22.0, 40.0, 12.0), Color("3a4252"), 3.0)
	_box(Rect2(tx.y + 6.0, TOP - 62.0, 36.0, 34.0), Color("3a4252"), 5.0)          # counterweight
	_box(Rect2(cx - 36.0, TOP - 74.0, 76.0, 54.0), YEL, 9.0)                        # turret
	_box(Rect2(tx.y - 4.0, TOP - 66.0, 20.0, 40.0), Color("f4f7fa"), 4.0, INK, 2.5) # hydraulic tank
	_c.draw_rect(Rect2(tx.y + 2.0, TOP - 72.0, 8.0, 7.0), INK)

## What changes on the tower: the deck's plate, the dashes in the line, and
## the clamps (the one in trouble rings red).
func _draw_tower_live() -> void:
	var tx := _tower_x()
	var base := _base()
	# The deck being poured: a plate across the mast at its height
	if st["deck_tag"] != "":
		var dy := clampf(_tower_y(st["deck"]), TOP + 24.0, base - 24.0)
		var tag: String = String(st["deck_tag"]).get_slice(" ", 0)
		var r := Rect2(tx.x - 9.0, dy - 16.0, tx.y - tx.x + 18.0, 32.0)
		_box(r, ORANGE, 6.0, INK, 2.5)
		var fs := _fit(tag, 26, r.size.x - 10.0, 14)
		_text(Vector2(r.get_center().x - _tw(tag, fs) * 0.5, dy + fs * 0.36), tag, fs, INK)
	# The riser: 3 m pipes, a lever clamp and a red pin at every joint
	var rx := _riser_x()
	var run := _line_run()
	if st["down"]:
		_dashes(run, 0.0, UI.ALARM, 3.0)
	elif st["flow"]:
		_dashes(run, -_flow, Color("6d7686"), 3.0)
	var clamps: Array = st["clamps"]
	for i in clamps.size():
		var cy := _tower_y(float(clamps[i]))
		var bad: bool = i == int(st["bad"])
		if bad:
			var a := _pulse(2.0)
			_c.draw_circle(Vector2(rx, cy), 22.0 + 6.0 * a, Color(UI.ALARM, 0.25 + 0.25 * a), true, -1.0, true)
			_c.draw_arc(Vector2(rx, cy), 22.0 + 6.0 * a, 0.0, TAU, 32, UI.ALARM, 3.0, true)
		_box(Rect2(rx - 10.0, cy - 5.0, 20.0, 10.0), UI.ALARM if bad else STEEL, 3.0, INK, 2.0)
		_c.draw_line(Vector2(rx + 10.0, cy), Vector2(rx + 17.0, cy - 5.0), INK, 2.5, true)   # the lever
		_c.draw_circle(Vector2(rx + 12.0, cy + 3.0), 2.6, Color("e0352b"), true, -1.0, true)

## The whole delivery line: out of the pump, up the riser, along under the
## boom and down the end hose.
func _line_run() -> PackedVector2Array:
	var rx := _riser_x()
	var low := _g - 20.0 * _gs
	return PackedVector2Array([_gp(Vector2(_hopper_x() + 118.0, _g - 20.0)), Vector2(rx - 8.0, low), Vector2(rx, low - 8.0),
			Vector2(rx, 134.0), Vector2(rx - 10.0, 124.0), Vector2(254.0, 124.0), Vector2(244.0, 134.0), Vector2(244.0, 152.0)])

# ------------------------------------------------------------------ the boom

func _draw_boom_static() -> void:
	var x0 := 262.0
	var x1 := _w - 96.0
	var xm := lerpf(x0, x1, 0.43)
	# The luffing ram over the knuckle
	_c.draw_line(Vector2(xm - 84.0, 47.0), Vector2(xm + 20.0, 47.0), INK, 9.0)
	_c.draw_line(Vector2(xm - 82.0, 47.0), Vector2(xm + 20.0, 47.0), STEEL, 4.0)
	_box(Rect2(xm + 16.0, 39.0, 150.0, 16.0), Color("3a4252"), 8.0)
	_box(Rect2(xm - 92.0, 40.0, 18.0, 14.0), Color("3a4252"), 3.0)
	# Two tapered arms
	_poly(PackedVector2Array([Vector2(x0, 64.0), Vector2(xm, 58.0), Vector2(xm, 110.0), Vector2(x0, 106.0)]), YEL)
	_poly(PackedVector2Array([Vector2(xm, 58.0), Vector2(x1, 52.0), Vector2(x1, 114.0), Vector2(xm, 110.0)]), YEL)
	_c.draw_line(Vector2(x0 + 4.0, 101.0), Vector2(xm - 2.0, 105.0), YEL_D, 3.0)
	_c.draw_line(Vector2(xm + 2.0, 105.0), Vector2(x1 - 4.0, 109.0), YEL_D, 3.0)
	for bx in [x0 + 4.0, xm, x1 - 4.0]:
		_disc(Vector2(bx, 84.0), 15.0, Color("2a3140"))
		_c.draw_circle(Vector2(bx, 84.0), 5.0, STEEL_D, true, -1.0, true)
	# The pipe clamped along it, and the end hose
	var hose := PackedVector2Array([Vector2(244.0, 150.0), Vector2(247.0, 172.0), Vector2(241.0, 192.0), Vector2(238.0, 206.0)])
	_c.draw_polyline(hose, INK, 15.0, true)
	_c.draw_polyline(hose, Color("2a3140"), 9.0, true)
	_box(Rect2(235.0, 144.0, 20.0, 9.0), STEEL, 3.0, INK, 2.0)
	_box(Rect2(235.0, 155.0, 20.0, 7.0), STEEL, 3.0, INK, 2.0)
	var cxp := 304.0
	while cxp < _riser_x() - 40.0:
		_box(Rect2(cxp - 4.0, 117.0, 8.0, 14.0), STEEL, 2.0, INK, 2.0)
		cxp += 96.0

## The words on the boom: the job in hand on the outer arm, what's coming on
## the inner one.
func _draw_boom_live() -> void:
	var x0 := 262.0
	var x1 := _w - 96.0
	var xm := lerpf(x0, x1, 0.43)
	# The job in hand, on the outer arm
	var title: String = st["title"]
	if title != "":
		var x := x0 + 30.0
		var room := xm - 26.0 - x
		var chip: String = st["chip"]
		if chip != "":
			var cw := _tw(chip, 28) + 24.0
			_box(Rect2(x, 68.0, cw, 36.0), UI.ALARM if st["alarm"] else INK, 8.0, INK, 0.0)
			_text(Vector2(x + 12.0, 96.0), chip, 28, Color.WHITE if st["alarm"] else YEL)
			x += cw + 14.0
			room -= cw + 14.0
		var clock: String = st["clock"]
		var cw2 := (_tw(clock, 32) + 14.0) if clock != "" else 0.0
		var bar_w := 110.0 if float(st["progress"]) >= 0.0 else 0.0
		var fs := _fit(title, 42, room - cw2 - (bar_w + 16.0 if bar_w > 0.0 else 0.0), 26)
		# (a new job drops into place)
		if title != _title_was:
			_title_was = title
			_title_at = _t
		var te := _since(_title_at)
		_text(Vector2(x, 84.0 + fs * 0.36 - (1.0 - te) * 16.0), title, fs, Color(INK, te))
		x += minf(_tw(title, fs), room - cw2 - bar_w) + 16.0
		if bar_w > 0.0 and x + bar_w + cw2 <= xm - 22.0:
			bar_w = minf(160.0, xm - 26.0 - cw2 - x)
			_c.draw_line(Vector2(x, 85.0), Vector2(x + bar_w, 85.0), INK, 9.0, true)
			var p := clampf(float(st["progress"]), 0.0, 1.0)
			if p > 0.01:
				_c.draw_line(Vector2(x + 2.0, 85.0), Vector2(x + 2.0 + (bar_w - 4.0) * p, 85.0), ORANGE, 5.0, true)
		if clock != "":
			_text(Vector2(xm - 24.0 - _tw(clock, 32), 96.0), clock, 32, INK)
	# What's coming, on the inner arm
	var next: String = st["next"]
	if next != "":
		var nx := xm + 30.0
		var nchip: String = st["next_chip"]
		var lw := _tw(nchip, 28) + 24.0
		_box(Rect2(nx, 68.0, lw, 36.0), INK, 8.0, INK, 0.0)
		_text(Vector2(nx + 12.0, 96.0), nchip, 28, YEL)
		nx += lw + 12.0
		var fs2 := _fit(next, 30, x1 - 30.0 - nx, 24)
		if next != _next_was:
			_next_was = next
			_next_at = _t
		var ne := _since(_next_at)
		_text(Vector2(nx + (1.0 - ne) * 22.0, 86.0 + fs2 * 0.36), next, fs2, Color(INK, ne))

# ------------------------------------------------------------------ the pump

func _draw_pump_static() -> void:
	var hx := _hopper_x()
	var g := _g
	# The hopper: the grate, the level and the two lines to keep it between
	var top := g - 82.0
	var bot := g - 26.0
	_c.draw_line(Vector2(hx - 20.0, bot), Vector2(hx - 20.0, g), INK, 7.0)
	_c.draw_line(Vector2(hx + 20.0, bot), Vector2(hx + 20.0, g), INK, 7.0)
	_c.draw_line(Vector2(hx - 20.0, bot), Vector2(hx - 20.0, g), YEL, 3.0)
	_c.draw_line(Vector2(hx + 20.0, bot), Vector2(hx + 20.0, g), YEL, 3.0)
	var body := PackedVector2Array([Vector2(hx - 32.0, top), Vector2(hx + 32.0, top), Vector2(hx + 20.0, bot), Vector2(hx - 20.0, bot)])
	_c.draw_colored_polygon(body, Color("2a3140"))
	var loop := body.duplicate()
	loop.append(body[0])
	_c.draw_polyline(loop, INK, LW, true)
	var band: Vector2 = st["band"]
	for f in [band.x, band.y]:
		var by := lerpf(bot, top + 4.0, f)
		_dashes(PackedVector2Array([Vector2(hx - 38.0, by), Vector2(hx + 38.0, by)]), 0.0, YEL, 2.5)
	for i in 5:
		var gx := lerpf(hx - 26.0, hx + 26.0, i / 4.0)
		_c.draw_line(Vector2(gx, top - 5.0), Vector2(gx, top), INK, 2.5)
	# The trailer pump: jack legs, exhaust, and the big pressure gauge
	var px := hx + 44.0
	_c.draw_line(Vector2(px + 6.0, g - 30.0), Vector2(px + 6.0, g), INK, 5.0)
	_c.draw_line(Vector2(px + 84.0, g - 30.0), Vector2(px + 84.0, g), INK, 5.0)
	_c.draw_rect(Rect2(px + 4.0, g - 104.0, 7.0, 16.0), INK)
	_c.draw_rect(Rect2(px + 1.0, g - 108.0, 13.0, 5.0), INK)
	_box(Rect2(px - 10.0, g - 44.0, 20.0, 12.0), Color("3a4252"), 3.0)
	_box(Rect2(px, g - 90.0, 78.0, 62.0), YEL, 8.0)
	for i in 3:
		_c.draw_line(Vector2(px + 8.0 + i * 6.0, g - 80.0), Vector2(px + 8.0 + i * 6.0, g - 40.0), YEL_D, 2.5)
	_box(Rect2(px + 76.0, g - 74.0, 14.0, 40.0), Color("3a4252"), 4.0)
	_disc(Vector2(px + 22.0, g - 14.0), 11.0, Color("2a3140"))
	_disc(Vector2(px + 44.0, g - 14.0), 11.0, Color("2a3140"))
	_c.draw_circle(Vector2(px + 22.0, g - 14.0), 4.0, STEEL, true, -1.0, true)
	_c.draw_circle(Vector2(px + 44.0, g - 14.0), 4.0, STEEL, true, -1.0, true)
	var gc := Vector2(px + 50.0, g - 58.0)
	_disc(gc, 25.0, Color("f4f2ec"))
	var bands := [[0.0, 120.0, UI.DONE], [120.0, 180.0, AMBER], [180.0, 250.0, UI.ALARM]]
	for b in bands:
		_c.draw_arc(gc, 18.0, PI * 0.75 + PI * 1.5 * float(b[0]) / 250.0, PI * 0.75 + PI * 1.5 * float(b[1]) / 250.0, 16, b[2], 6.0, true)

## The readings on the pump and hopper: the level, the needle, the numbers.
func _draw_pump_live() -> void:
	var hx := _hopper_x()
	var g := _g
	var top := g - 82.0
	var bot := g - 26.0
	var fill := clampf(float(st["hopper"]), 0.0, 1.0)
	if fill > 0.01:
		var fy := lerpf(bot, top + 4.0, fill)
		var half := lerpf(20.0, 32.0, (bot - fy) / (bot - top))
		_c.draw_colored_polygon(PackedVector2Array([Vector2(hx - half + 2.0, fy), Vector2(hx + half - 2.0, fy), Vector2(hx + 18.0, bot - 2.0), Vector2(hx - 18.0, bot - 2.0)]), CONC)
		var band: Vector2 = st["band"]
		for f in [band.x, band.y]:
			var by := lerpf(bot, top + 4.0, f)
			_dashes(PackedVector2Array([Vector2(hx - 38.0, by), Vector2(hx + 38.0, by)]), 0.0, YEL, 2.5)
	if st["pump"]:
		var pct := "%d%%" % int(round(fill * 100.0))
		var low: bool = fill < 0.2 and not st["startup"]
		var pfs := _gfs(30)
		_text(Vector2(hx - _tw(pct, pfs) * 0.5, top - 12.0), pct, pfs, UI.ALARM if low and _pulse(2.0) > 0.4 else Color.WHITE, 8)
	var px := hx + 44.0
	var gc := Vector2(px + 50.0, g - 58.0)
	var spike: bool = st["spike"]
	if spike and fmod(_t, UI.SHAKE_T * 2.0) < UI.SHAKE_T:
		_c.draw_arc(gc, 31.0, 0.0, TAU, 32, UI.ALARM, 8.0, true)
	var v := clampf(float(st["bar"]) / 250.0, 0.0, 1.0)
	if spike:
		v = clampf(v + 0.02 * sin(_t * 70.0), 0.0, 1.0)
	var ang := PI * 0.75 + PI * 1.5 * v
	_c.draw_line(gc, gc + Vector2(cos(ang), sin(ang)) * 17.0, INK, 3.5, true)
	_c.draw_circle(gc, 4.0, INK, true, -1.0, true)
	if st["pump"]:
		var txt := "%d bar" % int(st["bar"])
		var col := Color.WHITE
		if spike:
			col = UI.ALARM
		elif st["tripped"]:
			txt = "OFF"
			col = Color("ff6b5f")
		var bfs := _gfs(28)
		_text(Vector2(px + 50.0 - _tw(txt, bfs) * 0.5, g - 100.0), txt, bfs, col, 8)

# ------------------------------------------------------------------ trucks

func _draw_trucks() -> void:
	var list: Array = st["trucks"]
	# (the ones pulling out first, so they pass behind the queue)
	for pass_i in 2:
		for tr in list:
			if (int(tr["slot"]) < 0) != (pass_i == 0):
				continue
			var x: float = _truck_x.get(tr["id"], -9999.0)
			# (as many as there's room for beside the job list)
			if x < -TRUCK_L - 30.0 or int(tr["slot"]) > 4:
				continue
			_draw_truck(x, float(tr["age"]), int(tr["slot"]) < 0)

func _draw_truck(x: float, age: float, leaving: bool) -> void:
	var g := _g
	# (in steps, so the boxes' styles are few)
	var a := snappedf(clampf((x + TRUCK_L) / 200.0, 0.0, 1.0), 0.125) if leaving else 1.0
	if a <= 0.0:
		return
	var m := Color(1, 1, 1, a)
	var ink := Color(INK, a)
	# Chassis
	_c.draw_rect(Rect2(x - 2.0, g - 44.0, 240.0, 16.0), ink)
	_c.draw_rect(Rect2(x + 1.0, g - 41.0, 234.0, 10.0), BLUE * m)
	# The frame under the drum
	_c.draw_colored_polygon(PackedVector2Array([Vector2(x + 196.0, g - 44.0), Vector2(x + 236.0, g - 44.0), Vector2(x + 220.0, g - 84.0)]), BLUE.darkened(0.2) * m)
	# Drum: white, with the plant's yellow swirl
	var dc := Vector2(x + 150.0, g - 82.0)
	var drum := PackedVector2Array()
	var swirl := PackedVector2Array()
	for i in 28:
		var t := TAU * i / 28.0
		var p := Vector2(cos(t) * 76.0, sin(t) * 40.0).rotated(-0.12)
		drum.append(dc + p)
	_c.draw_colored_polygon(drum, Color("f4f7fa") * m)
	for i in 9:
		var t2 := lerpf(-1.25, 0.2, i / 8.0)
		swirl.append(dc + Vector2(cos(t2) * 70.0, sin(t2) * 36.0).rotated(-0.12))
	for i in 9:
		var t3 := lerpf(0.2, -1.25, i / 8.0)
		swirl.append(dc + Vector2(cos(t3) * 44.0 + 10.0, sin(t3) * 20.0 - 6.0).rotated(-0.12))
	_c.draw_colored_polygon(swirl, YEL * m)
	var dl := drum.duplicate()
	dl.append(drum[0])
	_c.draw_polyline(dl, ink, LW, true)
	# The chute, swung over the hopper
	_c.draw_line(Vector2(x + 222.0, g - 104.0), Vector2(x + 266.0, g - 90.0), ink, 11.0, true)
	_c.draw_line(Vector2(x + 224.0, g - 104.0), Vector2(x + 264.0, g - 91.0), STEEL_D * m, 5.0, true)
	_disc(Vector2(x + 222.0, g - 102.0), 9.0, STEEL * m, ink, 2.5)
	# Cab
	_box(Rect2(x + 6.0, g - 110.0, 64.0, 70.0), Color("f4f7fa") * m, 9.0, ink)
	_box(Rect2(x + 14.0, g - 102.0, 34.0, 30.0), Color("6fb4ff") * m, 5.0, ink, 2.5)
	_c.draw_rect(Rect2(x - 2.0, g - 52.0, 12.0, 10.0), ink)
	_c.draw_circle(Vector2(x + 8.0, g - 58.0), 4.0, YEL * m, true, -1.0, true)
	for wx in [x + 50.0, x + 166.0, x + 206.0]:
		_disc(Vector2(wx, g - 18.0), 18.0, Color("2a3140") * m, ink)
		_c.draw_circle(Vector2(wx, g - 18.0), 6.0, STEEL * m, true, -1.0, true)
	# The load's age, on the drum
	var txt := "%d MIN" % int(age)
	var bg := INK
	var fg := Color.WHITE
	if age > AGE_MAX:
		txt += " · TOO OLD"
		bg = UI.ALARM
	elif age >= AGE_WARN:
		bg = AMBER
		fg = INK
	var afs := _gfs(26)
	var tw := _tw(txt, afs) + 26.0
	var r := Rect2(dc.x - tw * 0.5 - 6.0, dc.y - afs * 0.75, tw, afs * 1.46)
	_box(r, bg * m, 7.0, (Color.WHITE if age > AGE_MAX else ink) * m, 2.5)
	_text(Vector2(r.position.x + 13.0, r.position.y + afs * 1.08), txt, afs, fg * m)

# ------------------------------------------------------------------ wind, cash

func _draw_wind() -> void:
	var wind: float = st["wind"]
	var stop: float = maxf(1.0, st["wind_stop"])
	var px := _w - 30.0
	_c.draw_line(Vector2(px, 62.0), Vector2(px, 14.0), INK, 5.0)
	_c.draw_line(Vector2(px, 62.0), Vector2(px, 14.0), STEEL, 2.0)
	# The sock lifts as it blows
	var ang := deg_to_rad(lerpf(72.0, 6.0, clampf(wind / 60.0, 0.0, 1.0))) + 0.05 * sin(_t * (2.0 + wind * 0.08))
	var dir := Vector2(-cos(ang), sin(ang))
	var nor := Vector2(dir.y, -dir.x)
	var a0 := Vector2(px, 20.0)
	for i in 4:
		var s0 := a0 + dir * (i * 11.0)
		var s1 := a0 + dir * ((i + 1) * 11.0)
		var w0 := 9.0 - i * 1.3
		var w1 := 9.0 - (i + 1) * 1.3
		_c.draw_colored_polygon(PackedVector2Array([s0 + nor * w0, s1 + nor * w1, s1 - nor * w1, s0 - nor * w0]), Color("ff5a2b") if i % 2 == 0 else Color("f4f7fa"))
	var e := a0 + dir * 44.0
	_c.draw_polyline(PackedVector2Array([a0 + nor * 9.0, e + nor * 3.8, e - nor * 3.8, a0 - nor * 9.0, a0 + nor * 9.0]), INK, 2.0, true)
	# The bar: up to the red line and the boom has to park
	var bx := _w - 14.0
	_c.draw_rect(Rect2(bx - 4.0, 14.0, 8.0, 50.0), Color(INK, 0.85))
	var over := wind >= stop
	var f := clampf(wind / (stop * 1.25), 0.0, 1.0)
	_c.draw_rect(Rect2(bx - 2.0, 62.0 - 46.0 * f, 4.0, 46.0 * f), UI.ALARM if over else (AMBER if wind >= stop * 0.75 else UI.GREEN))
	_c.draw_line(Vector2(bx - 7.0, 62.0 - 46.0 * 0.8), Vector2(bx + 7.0, 62.0 - 46.0 * 0.8), UI.ALARM, 2.5)
	var txt := "%d km/h" % int(wind)
	_text(Vector2(px - 58.0 - _tw(txt, 26), 38.0), txt, 26, UI.ALARM if over and _pulse(2.0) > 0.4 else Color.WHITE, 8)

func _draw_cash() -> void:
	var r := Rect2(24.0, 14.0, 200.0, 86.0)
	_box(r, Color("10151f"), 10.0, Color("f4f7fa"), 3.0)
	var cash := "$" + UI.thousands(int(st["cash"]))
	var fs := int(44.0 * (1.0 + 0.12 * float(st["bump"])))
	fs = _fit(cash, fs, 184.0, 28)
	_text(Vector2(r.get_center().x - _tw(cash, fs) * 0.5, 60.0), cash, fs, YEL)
	var lv: String = st["level"]
	_text(Vector2(r.get_center().x - _tw(lv, 24) * 0.5, 90.0), lv, 24, Color("f4f7fa"))

# ------------------------------------------------------------------ people

## A hat where each person's working: the deck crew under the boom, the
## truck hand by the hopper, the pump operator at the pump (or up the riser).
func _draw_hats() -> void:
	var deck_i := 0
	for h in st["hats"]:
		var at := Vector2.ZERO
		match String(h["where"]):
			"deck":
				at = Vector2(316.0 + deck_i * 62.0, 174.0)
				deck_i += 1
			"truck":
				at = _gp(Vector2(_hopper_x() - 62.0, _g - 150.0)) - Vector2(0, 26)
			"pump":
				# (over the pump's reading)
				at = _gp(Vector2(_hopper_x() + 94.0, _g - 104.0)) - Vector2(0, _gfs(28) * _gs + 28.0)
			"riser":
				at = Vector2(_riser_x() - 44.0, _tower_y(float(h["at"])))
			_:
				continue
		var col: Color = UI.ROLE.get(h["role"], Color.WHITE)
		var nudge: int = h.get("nudge", 0)
		if nudge > 0:
			var a := _pulse(1.6)
			_c.draw_arc(at, 27.0 + 3.0 * a, 0.0, TAU, 32, Color(UI.ALARM, 0.6 + 0.4 * a), 4.0, true)
		_disc(at, 22.0, col)
		_c.draw_texture_rect(Icons.texture(h["role"], 64), Rect2(at - Vector2(15, 15), Vector2(30, 30)), false, INK)
		if not h.get("bot", true):
			var tag := "P%d" % int(h["p"])
			var tw := _tw(tag, 22) + 14.0
			var r := Rect2(at.x + 8.0, at.y - 34.0, tw, 26.0)
			_box(r, UI.P_COLORS[(int(h["p"]) - 1) % UI.P_COLORS.size()], 13.0, INK, 0.0)
			_text(Vector2(r.position.x + 7.0, r.position.y + 21.0), tag, 22, Color.WHITE)

## A fault, at its real spot: who, what, and which button.
func _draw_fault() -> void:
	var f: Dictionary = st["fault"]
	if f.is_empty():
		fault_rect = Rect2()
		_fault_was = ""
		return
	var title: String = f.get("title", "")
	# (it pops in: a touch small, then a springy overshoot)
	if title != _fault_was:
		_fault_was = title
		_fault_at = _t
	var fe := _since(_fault_at, 0.3)
	var sub: String = f.get("sub", "")
	var on_riser: bool = f.get("where", "riser") == "riser"
	var y := 238.0
	var w := clampf(maxf(_tw(title, 30), _tw(sub, 24)) + 96.0, 250.0, 430.0)
	var r := Rect2(_riser_x() - 44.0 - w, y - 36.0, w, 72.0)
	# (the call-out's always in the one place, clear of the close-ups; a
	# line runs from it to the spot on the kit)
	var spot := Vector2(_riser_x(), _tower_y(float(f.get("at", 0.5)))) if on_riser else _gp(Vector2(_hopper_x() + 94.0, _g - 96.0))
	var from := Vector2(clampf(spot.x - 30.0, r.position.x + 40.0, r.end.x - 20.0), r.end.y)
	if spot.y > r.end.y + 20.0:
		_c.draw_polyline(PackedVector2Array([from, Vector2(from.x, spot.y - 34.0), spot + Vector2(-22.0, -22.0) if not on_riser else Vector2(spot.x - 24.0, spot.y)]), Color.WHITE, 6.0, true)
		_c.draw_polyline(PackedVector2Array([from, Vector2(from.x, spot.y - 34.0), spot + Vector2(-22.0, -22.0) if not on_riser else Vector2(spot.x - 24.0, spot.y)]), UI.ALARM, 3.0, true)
	fault_rect = Rect2(r.position * (size.y / 900.0), r.size * (size.y / 900.0))
	var a := _pulse(1.6)
	_box(r.grow(1.0 + 2.0 * a), Color(UI.ALARM, 0.35), 13.0, Color(1, 1, 1, 0.0), 0.0)
	r = r.grow(-(1.0 - fe) * 12.0 + sin(fe * PI) * 5.0)
	_box(r, UI.ALARM, 11.0, Color.WHITE, 2.5)
	var tx := r.position.x + 16.0
	var btn: String = f.get("btn", "")
	if btn != "":
		var c := Vector2(r.position.x + 38.0, y)
		_c.draw_circle(c + Vector2(0, 3), 24.0, UI.LIP.get(btn, INK), true, -1.0, true)
		_disc(c, 24.0, UI.GLYPH.get(btn, Color.WHITE), Color.WHITE, 2.5)
		_text(Vector2(c.x - _tw(btn, 30) * 0.5, c.y + 10.0), btn, 30, UI.GLYPH_INK.get(btn, INK))
		tx = r.position.x + 72.0
	var room := r.end.x - 14.0 - tx
	var fs := _fit(title, 30, room, 24)
	_text(Vector2(tx, y + (0.0 if sub != "" else 10.0)), title, fs, Color.WHITE)
	if sub != "":
		_text(Vector2(tx, y + 26.0), sub, _fit(sub, 24, room, 20), Color.WHITE)
