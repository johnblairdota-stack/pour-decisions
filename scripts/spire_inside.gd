## What's inside Spire round the boom's column, for the section view (main._section_slot): the stair
## shaft climbing beside it, the hand rails round the column's opening on each floor, and the
## formworkers' and steel fixers' gear on the floors under it. All dressing: nothing here is walked on
## or pressed. Rebuilt when the level changes, and merged into a few meshes.
extends Node3D

const F := preload("res://scripts/factory.gd")
const SpireSite := preload("res://scripts/spire_site.gd")
const LineScript := preload("res://scripts/line.gd")

const SHAFT_W := 2.5         # the stair shaft, east of the column: across, and front to back
const SHAFT_D := 5.6
const RAIL_FLOORS := 8       # floors under the deck that get a rail round the opening
const GEAR_FLOORS := 3       # ...and that have the trades' gear on them

var game
var _built := -1

func build(k: int) -> void:
	if k == _built:
		return
	_built = k
	for c in get_children():
		c.queue_free()
	var g = game
	var m := SpireSite.mast_xz()
	var fh: float = g.FH
	var under: float = g.level_y(k - 1) if k >= 1 else g.base_y - fh   # the floor under it
	_stairs(m, under, fh)
	_rails(m, k)
	for i in GEAR_FLOORS:
		var lv := k - 2 - i
		if lv >= 0:
			_gear(m, g.level_y(lv), i)
	for i in 5:
		var lv2 := k - 1 - i
		if lv2 >= 0:
			_lights(m, g.level_y(lv2) + fh - 0.42)
	for c in get_children():
		if c is Node3D and c.get_child_count() > 1:
			F.bake(c)

func _group(nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	add_child(n)
	return n

## A flat slab from `a` to `b` (its top face's ends), `w` wide.
func _ramp(parent: Node3D, a: Vector3, b: Vector3, w: float, t: float, mat: Material) -> void:
	var len := a.distance_to(b)
	var mi := F.box(Vector3(w, t, len), mat, Vector3.ZERO)
	parent.add_child(mi)
	mi.position = (a + b) * 0.5 - Vector3(0, t * 0.5, 0)
	var dir := (b - a).normalized()
	mi.basis = Basis.looking_at(dir, Vector3.UP)

## The stair shaft: a dog-leg flight a storey, its landings, hand rails, and the shaft's back and far
## walls, from the street up to the floor under the deck.
func _stairs(m: Vector2, top: float, fh: float) -> void:
	var n := _group("Stairs")
	var conc := F.color_mat(Color("b9bcc0"))
	var wall := F.color_mat(Color("9a9da2"))
	var rail := F.mat("yellow")
	var x0 := m.x + 2.3
	var x1 := x0 + SHAFT_W
	var z1 := m.y + 0.5            # its open front, toward Ann St
	var z0 := z1 - SHAFT_D         # its back wall
	var storeys := maxi(1, int(round(top / fh)))
	var sh := top / float(storeys)
	n.add_child(F.box(Vector3(SHAFT_W + 0.4, top + 1.2, 0.2), wall, Vector3((x0 + x1) * 0.5, (top + 1.2) * 0.5, z0 - 0.1)))
	n.add_child(F.box(Vector3(0.2, top + 1.2, SHAFT_D), wall, Vector3(x1 + 0.1, (top + 1.2) * 0.5, (z0 + z1) * 0.5)))
	var fw := SHAFT_W * 0.5 - 0.08
	var run0 := z1 - 1.1
	var run1 := z0 + 1.1
	for s in storeys:
		var y := s * sh
		# (up the near side going back, a half landing, then up the far side coming forward)
		_ramp(n, Vector3(x0 + fw * 0.5, y, run0), Vector3(x0 + fw * 0.5, y + sh * 0.5, run1), fw, 0.16, conc)
		n.add_child(F.box(Vector3(SHAFT_W, 0.16, 1.1), conc, Vector3((x0 + x1) * 0.5, y + sh * 0.5 - 0.08, z0 + 0.55)))
		_ramp(n, Vector3(x1 - fw * 0.5, y + sh * 0.5, run1), Vector3(x1 - fw * 0.5, y + sh, run0), fw, 0.16, conc)
		n.add_child(F.box(Vector3(SHAFT_W, 0.16, 1.1), conc, Vector3((x0 + x1) * 0.5, y + sh - 0.08, z1 - 0.55)))
		for side in 2:
			var rx := x0 + 0.06 if side == 0 else x1 - 0.06
			var ya := y if side == 0 else y + sh * 0.5
			var za := run0 if side == 0 else run1
			var zb := run1 if side == 0 else run0
			n.add_child(F.beam(Vector3(rx, ya + 0.95, za), Vector3(rx, ya + sh * 0.5 + 0.95, zb), 0.05, rail))
			for u in [0.0, 0.5, 1.0]:
				var pz := lerpf(za, zb, u)
				var py: float = ya + sh * 0.5 * u
				n.add_child(F.box(Vector3(0.04, 0.95, 0.04), rail, Vector3(rx, py + 0.47, pz)))

## A hand rail round the column's opening on each of the floors under the deck (the deck's own is main's).
func _rails(m: Vector2, k: int) -> void:
	var n := _group("OpeningRails")
	var rail := F.mat("yellow")
	var kick := F.mat("yellow_dark")
	var op := SpireSite.opening()
	var x0 := op[0].x - 0.2
	var x1 := op[2].x + 0.2
	var z0 := op[0].y - 0.2
	var z1 := op[2].y + 0.2
	for i in RAIL_FLOORS:
		var lv := k - 1 - i
		if lv < 0:
			break
		var y: float = game.level_y(lv)
		for hy in [0.5, 1.0]:
			n.add_child(F.box(Vector3(x1 - x0, 0.05, 0.05), rail, Vector3((x0 + x1) * 0.5, y + hy, z0)))
			n.add_child(F.box(Vector3(0.05, 0.05, z1 - z0), rail, Vector3(x0, y + hy, (z0 + z1) * 0.5)))
			n.add_child(F.box(Vector3(0.05, 0.05, z1 - z0), rail, Vector3(x1, y + hy, (z0 + z1) * 0.5)))
		n.add_child(F.box(Vector3(x1 - x0, 0.15, 0.03), kick, Vector3((x0 + x1) * 0.5, y + 0.08, z0)))
		for p in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
			n.add_child(F.box(Vector3(0.05, 1.05, 0.05), rail, Vector3(p.x, y + 0.52, p.y)))

func _on_plate(x: float, z: float) -> bool:
	if not Geometry2D.is_point_in_polygon(Vector2(x, z), SpireSite.poly("plate")):
		return false
	# (not inside the core's walls, where they'd never show)
	return not Geometry2D.is_point_in_polygon(Vector2(x, z), Geometry2D.offset_polygon(SpireSite.poly("core"), 0.35)[0])

## The trades' gear on a floor under the deck (`i`: 0 the nearest floor clear of the formwork's props,
## where the ply and the steel are staged; further down there's less of it). In the strip in front of
## the core, west of the column: behind the section view's cut line, so it's on a floor that shows.
func _gear(m: Vector2, y: float, i: int) -> void:
	var n := _group("Gear%d" % i)
	var ply := F.mat("ply")
	var timber := F.color_mat(Color("b98a55"))
	var rebar := F.color_mat(Color("8a5a3c"))
	var steel := F.mat("steel")
	var w := m.x - 3.3
	var e := m.x - 1.4
	var zf := m.y - 0.35
	if i == 0:
		# A stack of form ply on gluts with a few bearers on it
		for g in 2:
			n.add_child(F.box(Vector3(0.1, 0.1, 1.0), timber, Vector3(w - 0.7 + g * 1.4, y + 0.05, zf)))
		n.add_child(F.box(Vector3(2.0, 0.42, 1.0), ply, Vector3(w, y + 0.31, zf)))
		for b in 4:
			n.add_child(F.box(Vector3(2.3, 0.1, 0.1), timber, Vector3(w + 0.1, y + 0.57, zf - 0.3 + 0.14 * b)))
		# A bundle of bar on timbers, tagged, and a few bags of chairs
		for g in 2:
			n.add_child(F.box(Vector3(0.1, 0.1, 0.5), timber, Vector3(m.x - 3.6 + g * 2.0, y + 0.05, zf + 0.8)))
		for b in 9:
			var bar := F.cylinder(0.022, 3.0, rebar, Vector3(m.x - 2.6, y + 0.13 + 0.045 * (b / 3), zf + 0.74 + 0.05 * (b % 3)), 5)
			bar.rotation.z = PI * 0.5
			n.add_child(bar)
		n.add_child(F.box(Vector3(0.12, 0.08, 0.02), F.color_mat(Color("f2d21b")), Vector3(m.x - 1.9, y + 0.3, zf + 0.9)))
		for b in 3:
			n.add_child(F.box(Vector3(0.3, 0.3, 0.45), F.color_mat(Color("e9e4d6")), Vector3(e - 0.3 + b * 0.34, y + 0.15, zf - 0.1)))
	elif i == 1:
		# A stillage of spare props and a gang box
		n.add_child(F.box(Vector3(1.6, 0.06, 1.0), steel, Vector3(w, y + 0.12, zf)))
		for c in [Vector2(-0.78, -0.48), Vector2(0.78, -0.48), Vector2(-0.78, 0.48), Vector2(0.78, 0.48)]:
			n.add_child(F.box(Vector3(0.05, 0.9, 0.05), steel, Vector3(w + c.x, y + 0.5, zf + c.y)))
		for b in 8:
			var pr := F.cylinder(0.04, 1.5, F.color_mat(Color("c9422e")), Vector3(w, y + 0.22 + 0.09 * (b / 4), zf - 0.3 + 0.2 * (b % 4)), 6)
			pr.rotation.z = PI * 0.5
			n.add_child(pr)
		n.add_child(F.box(Vector3(1.2, 0.7, 0.6), F.color_mat(Color("2c5fa8")), Vector3(e - 0.2, y + 0.35, zf)))
		n.add_child(F.box(Vector3(1.24, 0.06, 0.64), F.color_mat(Color("234c86")), Vector3(e - 0.2, y + 0.73, zf)))
	else:
		# A skip bin of offcuts and a roll of mesh stood on end
		n.add_child(F.box(Vector3(1.5, 0.8, 1.0), F.color_mat(Color("3d7a4a")), Vector3(w, y + 0.4, zf)))
		n.add_child(F.box(Vector3(1.3, 0.08, 0.8), ply, Vector3(w, y + 0.82, zf)))
		n.add_child(F.cylinder(0.3, 2.0, rebar, Vector3(e, y + 1.0, zf), 10))

## A string of temporary lights under the soffit, across in front of the column.
func _lights(m: Vector2, y: float) -> void:
	var n := _group("Lights")
	var lamp := F.color_mat(Color("fff3c4"), false, Color("ffe9a0") * 1.6)
	var cord := F.color_mat(Color("e07b1a"))
	var z := m.y + 0.45
	n.add_child(F.box(Vector3(9.0, 0.02, 0.02), cord, Vector3(m.x + 0.5, y + 0.06, z)))
	for i in 4:
		n.add_child(F.box(Vector3(0.5, 0.1, 0.08), lamp, Vector3(m.x - 3.4 + i * 2.6, y, z)))
