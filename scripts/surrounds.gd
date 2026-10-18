## The real surroundings of Riverlight at Hamilton Reach, Brisbane. The streets,
## footpaths, parks, the golf course, the river and every building within
## about 1.6 km come from OpenStreetMap (data/riverlight_osm.json, made by
## tools/osm_to_game.py; map data (c) OpenStreetMap contributors, ODbL 1.0).
## Past that: houses in the haze, the CBD upstream and the Gateway Bridge
## downstream. Sources: /mnt/project-files/visuals/riverlight-site-reference.md.
##
## Frame: metres from Riverlight's centroid, turned so the building's long side
## lies along x. +x is west (upstream, the city), +z is north, so the river's
## at -z, about 185 m south of the building, as on the real site.
extends RefCounted

const F := preload("res://scripts/factory.gd")

const DATA := "res://data/riverlight_osm.json"
const NEAR := 1600.0          # the map data reaches this far
const FAR := 2500.0           # the haze ring of houses goes out to here

## Left clear for the game's own site: the building, the boom tower, the pump
## and truck bay, and the strip the trucks drive along.
const SITE_CLEAR := [Rect2(-45, -14, 95, 38), Rect2(-50, 10, 95, 13)]
const TRUCK_ROAD := Rect2(-47, 11.6, 88, 9.0)
## The map's ground sits a little above the plain grass and under the game's own
## hardstand (6 cm) and truck road (4.5 cm), clear of both so nothing flickers.
const GROUND_Y := 0.02

## Ground colours by land use, drawn in this order (later on top)
const AREA := {
	"residential": Color("b9b6a4"), "industrial": Color("c9c4bd"), "vacant": Color("a39a68"),
	"golf": Color("7fae58"), "park": Color("78a457"), "scrub": Color("5d7f45"),
	"pitch": Color("6fae5c"), "parking": Color("8e9196"), "paving": Color("c8c4ba"),
	"beach": Color("e6d7aa"), "golf_water": Color("4f6660"), "bridge": Color("9a9a96"),
}
const ROAD := Color("4a4e55")
const PATH := Color("cfcabd")
const ROOFS := [Color("8a9096"), Color("5e6670"), Color("b4634a"), Color("e8e6df"), Color("9c8b74"), Color("6f7a72")]
const WALLS := [Color("f1eee6"), Color("e5ddcc"), Color("d7dde0"), Color("f4f2ec")]
const LEAVES := [Color("4f7d43"), Color("5d8a48"), Color("426b3c"), Color("6b9150")]
const BUILDING := {
	"industrial": [Color("cfccc4"), Color("b6bcc0")], "warehouse": [Color("c9c6bd"), Color("aab0b4")],
	"apartments": [Color("f1efe9"), Color("e8e8e4")], "school": [Color("e2d8c4"), Color("b4634a")],
	"commercial": [Color("dcd8d0"), Color("b6bcc0")], "retail": [Color("e8dcc8"), Color("b6bcc0")],
	"office": [Color("c9d3d8"), Color("e8e8e4")], "house": [Color("f1eee6"), Color("8a9096")],
	"shed": [Color("b8b4aa"), Color("a9adb0")], "roof": [Color("e8e6df"), Color("dcdcd6")],
}
const CONTAINERS := [Color("b04a3a"), Color("2f5f8f"), Color("6f7a72"), Color("c98a3a"), Color("e8e6df")]

static func build(root: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8000, 8000)
	ground.mesh = pm
	ground.material_override = F.mat("grass")
	root.add_child(ground)
	# The game's truck lane in from the street
	root.add_child(F.box(Vector3(TRUCK_ROAD.size.x, 0.05, TRUCK_ROAD.size.y), F.mat("road"),
		Vector3(TRUCK_ROAD.get_center().x, 0.02, TRUCK_ROAD.get_center().y), false))
	var d := _load()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2017
	if d.is_empty():
		push_warning("surrounds: %s missing, the world's bare" % DATA)
	else:
		_ground(root, d)
		_buildings(root, d, rng)
		_trees(root, d, rng)
		_lamps(root, d)
		_haze_ring(root, d, rng)
		_gateway(root, d)
		for fe in d.get("ferry", []):
			_terminal(root, fe)
			_citycat(root, fe, d.get("cat_route", []))
	_cbd(root, rng)

static func _load() -> Dictionary:
	if not FileAccess.file_exists(DATA):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return parsed if parsed is Dictionary else {}

static func _v2(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	# (the data closes each ring; the triangulator wants it open)
	if out.size() > 2 and out[0].is_equal_approx(out[out.size() - 1]):
		out.remove_at(out.size() - 1)
	return out

static func _clear(p: Vector2) -> bool:
	for r in SITE_CLEAR:
		if r.has_point(p):
			return false
	return true

# ------------------------------------------------------------------ the ground

## Land use, the river, roads, footpaths and drains, all flat and all in two
## meshes (one for the water, so it can shine). The converter has already cut
## them into pieces that don't overlap, so they can all lie at one height
## without flickering; the game's own slabs and roads sit on top.
static func _ground(root: Node3D, d: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wt := SurfaceTool.new()
	wt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for g in d.get("ground", []):
		var kind: String = g["kind"]
		var wet := kind in ["water", "drain"]
		var t: SurfaceTool = wt if wet else st
		t.set_color(Color.WHITE if wet else (ROAD if kind == "road" else (PATH if kind == "path" else AREA.get(kind, ROAD))))
		t.set_normal(Vector3.UP)
		var tris: Array = g["tris"]
		for i in range(0, tris.size() - 5, 6):
			for k in 3:
				t.add_vertex(Vector3(tris[i + k * 2], GROUND_Y, tris[i + k * 2 + 1]))
	for pr in d["piers"]:
		if pr.has("pts"):
			_flat(st, _v2(pr["pts"]), 0.3, Color("9a968c"))
		else:
			_ribbon(st, _v2(pr["line"]), pr["w"], 0.3, Color("9a968c"), false)
	var land := MeshInstance3D.new()
	land.mesh = st.commit()
	land.material_override = _flat_mat()
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(land)
	var water := MeshInstance3D.new()
	water.mesh = wt.commit()
	water.material_override = _water()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)

static func _flat(st: SurfaceTool, poly: PackedVector2Array, y: float, c: Color) -> void:
	if poly.size() < 3:
		return
	var idx := Geometry2D.triangulate_polygon(poly)
	st.set_color(c)
	st.set_normal(Vector3.UP)
	for i in idx:
		st.add_vertex(Vector3(poly[i].x, y, poly[i].y))

## A strip of width `w` along a line, with round-ish joints so bends don't gap.
static func _ribbon(st: SurfaceTool, line: PackedVector2Array, w: float, y: float, c: Color, joints: bool) -> void:
	st.set_color(c)
	st.set_normal(Vector3.UP)
	var h := w * 0.5
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		if a.distance_to(b) < 0.01:
			continue
		var n := (b - a).normalized().orthogonal() * h
		for q in [a + n, a - n, b - n, a + n, b - n, b + n]:
			st.add_vertex(Vector3(q.x, y, q.y))
	if not joints:
		return
	for i in range(1, line.size() - 1):
		var p := line[i]
		for k in 8:
			var a0 := TAU * k / 8.0
			var a1 := TAU * (k + 1) / 8.0
			for q in [p, p + Vector2(cos(a0), sin(a0)) * h, p + Vector2(cos(a1), sin(a1)) * h]:
				st.add_vertex(Vector3(q.x, y, q.y))

# ------------------------------------------------------------------ buildings

## Every building in the map data, extruded to its height (from its levels
## where the map has them). Shipping containers get their colours.
static func _buildings(root: Node3D, d: Dictionary, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in d["buildings"]:
		var poly := _v2(b["pts"])
		if poly.size() < 3:
			continue
		var c := Vector2.ZERO
		for p in poly:
			c += p
		c /= poly.size()
		if not _clear(c):
			continue
		var kind: String = b["kind"]
		var cols: Array = BUILDING.get(kind, [WALLS[rng.randi() % WALLS.size()], ROOFS[rng.randi() % ROOFS.size()]])
		if kind == "container":
			var cc: Color = CONTAINERS[rng.randi() % CONTAINERS.size()]
			cols = [cc, cc.darkened(0.1)]
		_extrude(st, poly, float(b["h"]), cols[0], cols[1])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _solid_mat()
	root.add_child(mi)

static func _extrude(st: SurfaceTool, poly: PackedVector2Array, h: float, wall: Color, roof: Color) -> void:
	# Which way round the ring goes decides which side of each wall is out
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	var turn := 1.0 if area > 0.0 else -1.0
	st.set_color(wall)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := (b - a).normalized()
		var out := Vector3(e.y, 0, -e.x) * turn
		st.set_normal(out)
		for q in [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(b.x, h, b.y),
				Vector3(a.x, 0, a.y), Vector3(b.x, h, b.y), Vector3(a.x, h, a.y)]:
			st.add_vertex(q)
	_flat(st, poly, h, roof)

# ------------------------------------------------------------------ trees and lamps

## The map's own trees, and the parks, the golf course and the scrub planted
## out at about the density the aerial photos show.
static func _trees(root: Node3D, d: Dictionary, rng: RandomNumberGenerator) -> void:
	var at: Array = []
	for t in d["trees"]:
		var p := Vector2(t[0], t[1])
		if _clear(p):
			at.append(Vector3(p.x, 0, p.y))
	var per := {"park": 220.0, "golf": 1400.0, "scrub": 70.0}
	for a in d["areas"]:
		if not per.has(a["kind"]):
			continue
		var poly := _v2(a["pts"])
		var box := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			box = box.expand(p)
		if box.get_center().length() > 900.0:
			continue
		var n := mini(int(box.get_area() / per[a["kind"]]), 1500)
		for i in n:
			var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
			if _clear(p) and Geometry2D.is_point_in_polygon(p, poly):
				at.append(Vector3(p.x, 0, p.y))
	_tree_field(root, at, rng)

static func _lamps(root: Node3D, d: Dictionary) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 7.0, 0.18)
	mm.mesh = bm
	var keep: Array = []
	for l in d["lamps"]:
		var p := Vector2(l[0], l[1])
		if _clear(p) and p.length() < 600.0:
			keep.append(p)
	mm.instance_count = keep.size()
	for i in keep.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(keep[i].x, 3.5, keep[i].y)))
		mm.set_instance_color(i, Color("8a9096"))
	_add_multi(root, mm, true)

# ------------------------------------------------------------------ out in the haze

## Past the map data: houses under trees out to the haze, wherever there's no
## water.
static func _haze_ring(root: Node3D, d: Dictionary, rng: RandomNumberGenerator) -> void:
	var water: Array = []
	for a in d["areas"]:
		if a["kind"] == "water":
			water.append(_v2(a["pts"]))
	var houses: Array = []
	var trees: Array = []
	for i in 2600:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf_range(NEAR * NEAR, FAR * FAR))
		var p := Vector2(cos(ang), sin(ang)) * r
		var wet := false
		for w in water:
			if Geometry2D.is_point_in_polygon(p, w):
				wet = true
				break
		if wet:
			continue
		if i % 3 == 0:
			trees.append(Vector3(p.x, 0, p.y))
		else:
			houses.append(Vector3(p.x, 0, p.y))
	_house_field(root, houses, rng)
	_tree_field(root, trees, rng)

static func _house_field(root: Node3D, at: Array, rng: RandomNumberGenerator) -> void:
	var walls := MultiMesh.new()
	walls.transform_format = MultiMesh.TRANSFORM_3D
	walls.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	walls.mesh = bm
	walls.instance_count = at.size()
	var roofs := MultiMesh.new()
	roofs.transform_format = MultiMesh.TRANSFORM_3D
	roofs.use_colors = true
	var pr := PrismMesh.new()
	pr.size = Vector3(1, 1, 1)
	roofs.mesh = pr
	roofs.instance_count = at.size()
	for i in at.size():
		var w := rng.randf_range(9, 14)
		var dd := rng.randf_range(10, 16)
		# Queenslanders stand up on stumps: a taller box under the roof
		var h := rng.randf_range(3.2, 5.5)
		var b := Basis(Vector3.UP, rng.randf() * PI)
		walls.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3(w, h, dd)), at[i] + Vector3(0, h * 0.5, 0)))
		walls.set_instance_color(i, WALLS[rng.randi() % WALLS.size()])
		roofs.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3(w + 1.0, 2.4, dd + 1.0)), at[i] + Vector3(0, h + 1.2, 0)))
		roofs.set_instance_color(i, ROOFS[rng.randi() % ROOFS.size()])
	_add_multi(root, walls)
	_add_multi(root, roofs)

static func _tree_field(root: Node3D, at: Array, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	mm.mesh = sm
	mm.instance_count = at.size()
	for i in at.size():
		var r := rng.randf_range(3.0, 6.5)
		var b := Basis.from_scale(Vector3(r * 2.0, r * 1.6, r * 2.0))
		mm.set_instance_transform(i, Transform3D(b, at[i] + Vector3(0, r * 1.3, 0)))
		mm.set_instance_color(i, LEAVES[rng.randi() % LEAVES.size()])
	_add_multi(root, mm, true)

static func _add_multi(root: Node3D, mm: MultiMesh, shadows := false) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _tinted()
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

# ------------------------------------------------------------------ materials

## The river: the Brisbane River's olive-brown, glossy enough to pick up the
## sky so it reads as water from up high.
static func _water() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = F.COLORS["river"]
	m.roughness = 0.12
	m.metallic_specular = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static var _tint: StandardMaterial3D
static var _flat_m: StandardMaterial3D
static var _solid_m: StandardMaterial3D

## Toon-lit, coloured per instance (for the fields of houses and trees).
static func _tinted() -> StandardMaterial3D:
	if _tint == null:
		_tint = _vertex_mat()
	return _tint

## The ground meshes: coloured per vertex, seen from either side.
static func _flat_mat() -> StandardMaterial3D:
	if _flat_m == null:
		_flat_m = _vertex_mat()
		_flat_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _flat_m

static func _solid_mat() -> StandardMaterial3D:
	if _solid_m == null:
		_solid_m = _vertex_mat()
		_solid_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _solid_m

static func _vertex_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.9
	return m

# ------------------------------------------------------------------ landmarks

## The CBD, about 6 km to the west-south-west, brought in to 2.3 km so it shows
## through the haze.
static func _cbd(root: Node3D, rng: RandomNumberGenerator) -> void:
	var centre := Vector3(4658, 0, -4413).normalized() * 2300.0
	var tones := [Color("8fa6b8"), Color("a7b7c2"), Color("7d93a6"), Color("c3ccd2"), Color("9aa9b0")]
	for i in 38:
		var p := centre + Vector3(rng.randf_range(-260, 260), 0, rng.randf_range(-200, 200))
		var near := 1.0 - clampf(p.distance_to(centre) / 300.0, 0.0, 1.0)
		var h := rng.randf_range(40, 90) + near * rng.randf_range(60, 180)
		var w := rng.randf_range(24, 44)
		var b := F.box(Vector3(w, h, rng.randf_range(24, 44)), F.color_mat(tones[i % tones.size()]), p + Vector3(0, h * 0.5, 0), false)
		b.rotation.y = rng.randf_range(-0.3, 0.3)
		root.add_child(b)

## The Gateway Bridge (Sir Leo Hielscher Bridges), on the map's own line:
## twin concrete box girders, 1.6 km long, the deck 64.5 m over the river.
static func _gateway(root: Node3D, d: Dictionary) -> void:
	var concrete := F.mat("bridge")
	for a in d["areas"]:
		if a["kind"] != "bridge":
			continue
		var poly := _v2(a["pts"])
		# The long axis of the deck's outline
		var p0 := poly[0]
		var far0 := p0
		for p in poly:
			if p.distance_to(p0) > far0.distance_to(p0):
				far0 = p
		var far1 := far0
		for p in poly:
			if p.distance_to(far0) > far1.distance_to(far0):
				far1 = p
		var length := far0.distance_to(far1)
		if length < 1000.0:
			continue
		var mid := (far0 + far1) * 0.5
		var dir := (far1 - far0).normalized()
		var half := length * 0.5
		var n := 40
		var prev := Vector3.ZERO
		for i in n + 1:
			var u := -1.0 + 2.0 * i / n
			var q := mid + dir * u * half
			var p := Vector3(q.x, _gateway_deck(u), q.y)
			if i > 0:
				var seg := F.box(Vector3(22.0, 4.0, prev.distance_to(p) + 0.5), concrete, (prev + p) * 0.5, false)
				seg.basis = Basis.looking_at(p - prev, Vector3.UP)
				root.add_child(seg)
			prev = p
		var piers := [-130.0, 130.0]
		for k in range(1, 10):
			piers.append(-130.0 - k * 75.0)
			piers.append(130.0 + k * 75.0)
		for s: float in piers:
			var u: float = s / half
			if absf(u) > 1.0:
				continue
			var h := _gateway_deck(u) - 2.0
			if h < 2.0:
				continue
			var q := mid + dir * s
			var t := 7.0 if absf(s) < 140.0 else 3.5
			var pier := F.box(Vector3(t, h, t * 1.6), concrete, Vector3(q.x, h * 0.5, q.y), false)
			pier.rotation.y = atan2(dir.x, dir.y)
			root.add_child(pier)

static func _gateway_deck(u: float) -> float:
	return 4.0 + 60.5 * (1.0 - u * u)

## The Northshore Hamilton CityCat terminal: a pontoon with a white and blue
## shelter, and a gangway back to the bank.
static func _terminal(root: Node3D, fe: Dictionary) -> void:
	var at := Vector2(fe["at"][0], fe["at"][1])
	var edge := Vector2(fe["edge"][0], fe["edge"][1])
	var t := Node3D.new()
	t.position = Vector3(at.x, 0, at.y)
	t.rotation.y = -deg_to_rad(float(fe["bank_deg"]))
	root.add_child(t)
	t.add_child(F.box(Vector3(30, 1.0, 9), F.mat("podium"), Vector3(0, 0.3, 0)))
	t.add_child(F.box(Vector3(26, 0.4, 8), F.mat("white"), Vector3(0, 3.6, 0)))
	t.add_child(F.box(Vector3(26.2, 0.6, 8.2), F.mat("citycat_blue"), Vector3(0, 3.2, 0)))
	for x in [-11.0, 0.0, 11.0]:
		for z in [-3.5, 3.5]:
			t.add_child(F.box(Vector3(0.25, 2.6, 0.25), F.mat("white"), Vector3(x, 2.0, z)))
	root.add_child(F.beam(Vector3(at.x, 0.8, at.y), Vector3(edge.x, 0.8, edge.y), 2.2, F.mat("steel")))

## A CityCat comes down the river from the city, berths at the terminal, and
## heads back.
static func _citycat(root: Node3D, fe: Dictionary, route: Array) -> void:
	var boat := Node3D.new()
	var navy := F.mat("citycat_blue")
	for z in [-2.6, 2.6]:
		boat.add_child(F.box(Vector3(25, 1.6, 1.8), navy, Vector3(0, 0.6, z)))
	boat.add_child(F.box(Vector3(24, 1.4, 7.0), F.mat("white"), Vector3(0, 1.9, 0)))
	boat.add_child(F.box(Vector3(18, 1.3, 6.4), F.color_mat(Color("2a3a48")), Vector3(-1.0, 3.2, 0)))
	boat.add_child(F.box(Vector3(19, 0.35, 6.8), F.mat("white"), Vector3(-1.0, 4.0, 0)))
	boat.add_child(F.box(Vector3(24.2, 0.4, 7.05), navy, Vector3(0, 2.3, 0)))
	var at := Vector2(fe["at"][0], fe["at"][1])
	var edge := Vector2(fe["edge"][0], fe["edge"][1])
	var berth := at + (at - edge).normalized() * 9.0
	var pts: Array = []
	for r in route:
		pts.append(Vector3(r[0], 0, r[1]))
	pts.append(Vector3(berth.x, 0, berth.y))
	boat.position = pts[0]
	root.add_child(boat)
	var tw := boat.create_tween().set_loops()
	var legs := [pts, pts.duplicate()]
	legs[1].reverse()
	for leg in legs:
		for i in range(1, leg.size()):
			var a: Vector3 = leg[i - 1]
			var b: Vector3 = leg[i]
			var dir := b - a
			tw.tween_callback(func(): boat.rotation.y = atan2(-dir.z, dir.x))
			tw.tween_property(boat, "position", b, a.distance_to(b) / 10.0)
		tw.tween_interval(40.0 if leg == legs[0] else 20.0)
