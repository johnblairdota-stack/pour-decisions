## The CityCat and the Northshore Hamilton terminal it calls at, from
## tools/blender/citycat.py (assets/citycat/citycat.glb): the pontoon and its
## gangway back to the bank (scripts/surrounds.gd), the boat running up and
## down the river, and the same boat in the top-out fly-past (main.gd).
extends RefCounted

const F := preload("res://scripts/factory.gd")
const Water := preload("res://scripts/water.gd")
const LIB := "res://assets/citycat/citycat.glb"
const SPAN := 6.0          # one GangwaySpan, m

const COLORS := {
	"navy": Color("1f4f8f"), "white": Color("f4f7fa"), "glass": Color("2a3a48"), "rubber": Color("222222"),
	"rail": Color("d2d6d8"), "ring": Color("ff7a1a"), "yellow": Color("ffc72c"), "concrete": Color("b9b7b0"),
	"deck": Color("8d9196"), "screen": Color("9cc3d6"), "seat": Color("2f6fd1"), "fascia": Color("5a6b78"), "pile": Color("4a5056"),
	"sign_blue": Color("1f4f9a"), "bin": Color("2f5f3f"), "antifoul": Color("7a2a24"),
}

static var _lib: Node
static var _meshes := {}
static var _mats := {}

## One model's mesh, its parts given toon materials.
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(name) as MeshInstance3D
	if mi == null:
		push_warning("citycat: no model " + name)
		_meshes[name] = null
		return null
	var m := mi.mesh
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		var key := src.resource_name if src != null else ""
		if not _mats.has(key):
			_mats[key] = F.color_mat(COLORS.get(key, Color.MAGENTA), false)
		m.surface_set_material(i, _mats[key])
	_meshes[name] = m
	return m

static func model(name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh(name)
	return mi

## A CityCat, bow towards +x, waterline at its origin (put it at Water.RIVER_Y).
static func boat() -> Node3D:
	return model("CityCat")

## The Northshore Hamilton terminal: the pontoon (its river side away from
## the bank) and a gangway of spans back to the bank edge.
static func terminal(root: Node3D, fe: Dictionary) -> void:
	var at := Vector2(fe["at"][0], fe["at"][1])
	var edge := Vector2(fe["edge"][0], fe["edge"][1])
	var t := model("Terminal")
	t.position = Vector3(at.x, Water.RIVER_Y, at.y)
	t.rotation.y = -deg_to_rad(float(fe["bank_deg"]))
	root.add_child(t)
	# gangway: from the pontoon's bank side to the bank, as whole spans
	var dir := (edge - at).normalized()
	var start := at + dir * 4.5
	var run := start.distance_to(edge)
	var n := maxi(1, ceili(run / SPAN))
	var yaw := atan2(dir.x, dir.y)
	# (up from the pontoon's deck to the landing on the bank)
	var y0 := Water.RIVER_Y + 0.82
	var y1 := 0.8
	var pitch := -atan2(y1 - y0, run)
	var step := Vector2(run, y1 - y0).length() / n
	for i in n:
		var g := model("GangwaySpan")
		var p := start + dir * (run * i / n)
		g.position = Vector3(p.x, lerpf(y0, y1, float(i) / n), p.y)
		g.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis.from_scale(Vector3(1, 1, step / SPAN))
		root.add_child(g)
	var land := model("GangwayLanding")
	land.position = Vector3(edge.x, 0.8, edge.y) + Vector3(dir.x, 0, dir.y) * 1.5
	land.rotation.y = yaw
	root.add_child(land)

## A CityCat comes down the river from the city, berths at the terminal, and
## heads back.
static func run(root: Node3D, fe: Dictionary, route: Array) -> void:
	var b := boat()
	var at := Vector2(fe["at"][0], fe["at"][1])
	var edge := Vector2(fe["edge"][0], fe["edge"][1])
	var berth := at + (at - edge).normalized() * 9.0
	var pts: Array = []
	for r in route:
		pts.append(Vector3(r[0], Water.RIVER_Y, r[1]))
	pts.append(Vector3(berth.x, Water.RIVER_Y, berth.y))
	b.position = pts[0]
	b.name = "CityCatRun"
	root.add_child(b)
	var tw := b.create_tween().set_loops()
	# (explore.gd: you can catch it at the terminal when you knock off, and
	# hurry the trip along)
	b.set_meta("tween", tw)
	b.set_meta("berth", berth)
	var legs := [pts, pts.duplicate()]
	legs[1].reverse()
	for leg in legs:
		for i in range(1, leg.size()):
			var a: Vector3 = leg[i - 1]
			var c: Vector3 = leg[i]
			var dir := c - a
			tw.tween_callback(func(): b.rotation.y = atan2(-dir.z, dir.x))
			tw.tween_property(b, "position", c, a.distance_to(c) / 10.0)
		tw.tween_interval(40.0 if leg == legs[0] else 20.0)
