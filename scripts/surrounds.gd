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
const Flora := preload("res://scripts/flora.gd")
const Street := preload("res://scripts/street.gd")
const Water := preload("res://scripts/water.gd")
const Neighbours := preload("res://scripts/neighbours.gd")
const People := preload("res://scripts/people.gd")
const Cars := preload("res://scripts/cars.gd")
const CityCat := preload("res://scripts/citycat.gd")
const Fences := preload("res://scripts/fences.gd")
const Wildlife := preload("res://scripts/wildlife.gd")

const DATA := "res://data/riverlight_osm.json"
const SKYLINE := "res://data/riverlight_skyline.json"   # tools/skyline_to_game.py
const LIDAR_TREES := "res://data/riverlight_trees_2019.json"   # tools/lidar_trees_to_game.py
const BANKS := "res://data/river_banks.json"   # tools/river_banks.py
const MASK := "res://data/river_mask.png"      # ...the same
const CITY := 7000.0          # the suburbs' houses reach out to here
const NEAR := 1600.0          # the map data reaches this far
const FAR := 2500.0           # the haze ring of houses goes out to here

## Left clear for the game's own site: the building, the boom tower, the pump
## and truck bay, the strip the trucks drive along, and the crane's base and
## the laydown south of the building.
const SITE_CLEAR := [Rect2(-45, -14, 95, 38), Rect2(-50, 10, 88, 22), Rect2(-26, -32, 46, 19)]
const TRUCK_ROAD := Rect2(-44.5, 21.1, 80.0, 9.0)
## The map's ground sits a little above the plain grass and under the game's own
## hardstand (6 cm) and truck road (4.5 cm), clear of both so nothing flickers.
const GROUND_Y := 0.02
## The river's surface: the land round it stands 3 to 4 m above the river
## (2019 LiDAR ground; the game's land is all at GROUND_Y)
const RIVER_Y := Water.RIVER_Y
const BANK := Color("6f6a5f")

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
	pm.size = Vector2(40000, 40000)
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/base_ground.gdshader")
	gm.set_shader_parameter("albedo", F.COLORS["grass"])
	gm.set_shader_parameter("wet", load(MASK))
	ground.material_override = gm
	# (sunk a little: with the camera reaching 16 km the map's own ground,
	# 2 cm up, would fight it for the depth buffer)
	ground.position.y = -0.4
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
		var foot := _buildings(root, d, rng)
		var roads := _road_grid(d)
		var bank := _bank_grid(d)
		var taken := {}
		for poly in foot:
			_take_area(poly, taken)
		_street(root, d, roads, bank, taken, rng)
		_trees(root, d, roads, bank, taken, rng)
		Fences.build(root, d, func(p: Vector2) -> bool: return _street_ok(p) and not _is_taken(p, taken, 0.9),
			func(p: Vector2, pad: float) -> bool: return _on_road(p, roads, pad), _seeded(11))
		Water.build(root, d, bank, func(p: Vector2) -> bool: return _clear(p), rng)
		People.build(root, d, func(p: Vector2) -> bool: return _clear(p) and not TRUCK_ROAD.grow(2.0).has_point(p), rng)
		Cars.build(root, d, func(p: Vector2) -> bool: return _clear(p) and not TRUCK_ROAD.grow(2.0).has_point(p),
			func(p: Vector2) -> bool: return _is_taken(p, taken, 2.5), func(p: Vector2, pad: float) -> bool: return _on_road(p, roads, pad),
			rng)
		var grass := func(p: Vector2) -> bool: return _street_ok(p) and not _on_road(p, roads, 1.0) and not _is_taken(p, taken, 1.5)
		Wildlife.build(root, d, grass, _seeded(12))
		_lamps(root, d)
		_haze_ring(root, d, rng)
		_gateway(root, d)
		for fe in d.get("ferry", []):
			CityCat.terminal(root, fe)
			CityCat.run(root, fe, d.get("cat_route", []))
	_skyline(root, rng)

## Its own random numbers, so adding a layer leaves the rest as it was.
static func _seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

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
				t.add_vertex(Vector3(tris[i + k * 2], RIVER_Y if wet else GROUND_Y, tris[i + k * 2 + 1]))
	for pr in d["piers"]:
		var line: PackedVector2Array
		if pr.has("pts"):
			line = _v2(pr["pts"])
			_flat(st, line, 0.3, Color("9a968c"))
		else:
			line = _v2(pr["line"])
			_ribbon(st, line, pr["w"], 0.3, Color("9a968c"), false)
		# on piles down into the river
		for i in line.size() - 1:
			var n := maxi(1, ceili(line[i].distance_to(line[i + 1]) / 6.0))
			for k in n:
				_post(st, line[i].lerp(line[i + 1], float(k) / n), 0.3, RIVER_Y - 0.5, 0.18, Color("5a5650"))
	_banks(st)
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

## The river's banks, from the land down into the water (data/river_banks.json).
## Near the site water.gd lays the rock wall and the beach over them.
static func _banks(st: SurfaceTool) -> void:
	if not FileAccess.file_exists(BANKS):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BANKS))
	for b in data["banks"]:
		for i in range(0, b.size() - 3, 2):
			var a := Vector2(b[i], b[i + 1])
			var c := Vector2(b[i + 2], b[i + 3])
			var e := c - a
			if e.length() < 0.05:
				continue
			# (the water's on the left; x is west, so left of (dx, dz) is (-dz, dx))
			var into := Vector2(-e.y, e.x).normalized()
			var n := Vector3(into.x, 0.3, into.y).normalized()
			var col := BANK.darkened(0.08 * float(i % 3))
			st.set_color(col)
			st.set_normal(n)
			for v in [Vector3(a.x, GROUND_Y, a.y), Vector3(c.x, GROUND_Y, c.y), Vector3(c.x, RIVER_Y - 0.4, c.y),
					Vector3(a.x, GROUND_Y, a.y), Vector3(c.x, RIVER_Y - 0.4, c.y), Vector3(a.x, RIVER_Y - 0.4, a.y)]:
				st.add_vertex(v)

## A square post from y0 down to y1.
static func _post(st: SurfaceTool, p: Vector2, y0: float, y1: float, r: float, c: Color) -> void:
	st.set_color(c)
	var q := [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]
	for i in 4:
		var a: Vector2 = p + q[i]
		var b: Vector2 = p + q[(i + 1) % 4]
		var m: Vector2 = (q[i] + q[(i + 1) % 4]).normalized()
		st.set_normal(Vector3(m.x, 0, m.y))
		for v in [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y),
				Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)]:
			st.add_vertex(v)

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
## The map's buildings: the warehouses, sheds and containers near the site
## go to scripts/neighbours.gd to be drawn properly, with the estate next
## door; the rest are extruded here. Returns the footprints drawn there.
static func _buildings(root: Node3D, d: Dictionary, rng: RandomNumberGenerator) -> Array:
	Neighbours.begin()
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
		if Neighbours.claim(kind, poly, float(b["h"]), c.length(), rng):
			continue
		var cols: Array = BUILDING.get(kind, [WALLS[rng.randi() % WALLS.size()], ROOFS[rng.randi() % ROOFS.size()]])
		if kind == "container":
			var cc: Color = CONTAINERS[rng.randi() % CONTAINERS.size()]
			cols = [cc, cc.darkened(0.1)]
		_extrude(st, poly, float(b["h"]), cols[0], cols[1])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _solid_mat()
	root.add_child(mi)
	return Neighbours.build(root, rng)

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

# ------------------------------------------------------------------ the street

const STREET_R := 450.0     # kerbs, lines, lights and signs this far from the site
const PARK_R := 380.0       # park furniture this far
const LOCAL := ["residential", "unclassified", "tertiary", "secondary", "living_street"]
const SHORT := {" Avenue": " Av", " Road": " Rd", " Street": " St", " Circuit": " Cct", " Drive": " Dr",
	" Parade": " Pde", " Place": " Pl", " Lane": " La", " Crescent": " Cr", " Court": " Ct"}

## The streets near the site the way the council finished them: kerbs, centre
## lines, street lights on outreach arms, name blades and give way signs at
## the corners, a bus stop on MacArthur Avenue; along the park paths post-top
## lights, benches and bins; BBQ shelters in the park, and the riverwalk's
## railing along the bank (scripts/street.gd, tools/blender/street.py).
static func _street(root: Node3D, d: Dictionary, roads: Dictionary, bank: Dictionary, taken: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var items: Array = []
	var kerbs: Array = []
	var dashes: Array = []
	var corners := {}
	var id := 0
	for r in d["roads"]:
		id += 1
		var local: bool = r["kind"] in LOCAL
		var pts := _v2(r["pts"])
		var w := float(r["w"])
		var hw := w * 0.5
		var carry := rng.randf_range(4.0, 24.0)
		var side := 1.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			if a.length() > STREET_R and b.length() > STREET_R:
				continue
			var e := b - a
			var ln := e.length()
			if ln < 0.5:
				continue
			var dir := e / ln
			var nrm := Vector2(-dir.y, dir.x)
			# Kerbs, 2 m at a time, wherever they don't cross another road
			var n := ceili(ln / 2.0)
			for k in n:
				var p0 := a + dir * (ln * k / n)
				var p1 := a + dir * (ln * (k + 1) / n)
				for sd in [-1.0, 1.0]:
					var o: Vector2 = nrm * (hw + 0.15) * sd
					var m: Vector2 = (p0 + p1) * 0.5 + o
					if m.length() < STREET_R and _street_ok(m) and not _on_road(m, roads, 0.1, id):
						kerbs.append([p0 + o, p1 + o])
			if not local:
				continue
			# Centre line: 3 m dashes, 6 m gaps, on the two-way streets
			if w >= 6.5:
				var t := 1.5
				while t + 3.0 < ln:
					var m := a + dir * (t + 1.5)
					if m.length() < STREET_R and _street_ok(m) and not _on_road(m, roads, -0.5, id):
						dashes.append([a + dir * t, a + dir * (t + 3.0)])
					t += 9.0
			# Street lights every 32 m or so, alternating sides
			var s := carry
			while s < ln:
				var p := a + dir * s + nrm * (hw + 0.9) * side
				if p.length() < STREET_R and _street_ok(p) and not _on_road(p, roads, 0.2) and not _is_taken(p, taken, 6.0):
					items.append(["StreetLight", Street.at(p, -nrm * side)])
					_take(p, taken)
				side = -side
				s += rng.randf_range(29.0, 35.0)
			carry = s - ln
		# Note the street's vertices for its corners
		if r["name"] != "" and local:
			for i in pts.size():
				if pts[i].length() > STREET_R:
					continue
				var key := Vector2i(roundi(pts[i].x * 2.0), roundi(pts[i].y * 2.0))
				var dv := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
				var end := 0 if i == 0 else (1 if i == pts.size() - 1 else -1)
				if not corners.has(key):
					corners[key] = []
				corners[key].append([r["name"], dv, hw, id, end, pts[i]])
	_corners(root, corners, roads, taken, items)
	_bus_stop(d, roads, taken, items)
	_park_paths(d, roads, taken, items, rng)
	_bbq(d, roads, bank, taken, items, rng)
	_riverwalk(d, items)
	Street.place(root, items)
	Street.kerbs(root, kerbs)
	Street.lines(root, dashes)

static func _street_ok(p: Vector2) -> bool:
	return _clear(p) and not TRUCK_ROAD.has_point(p)

## Where two named streets meet: the name blades on a post at the corner, and
## a give way sign on the street that ends there.
static func _corners(root: Node3D, corners: Dictionary, roads: Dictionary, taken: Dictionary, items: Array) -> void:
	for key in corners:
		var at: Array = corners[key]
		var names := {}
		for c in at:
			names[c[0]] = c
		if names.size() < 2:
			continue
		var r1: Array = names.values()[0]
		var r2: Array = names.values()[1]
		var v: Vector2 = r1[5]
		var n1: Vector2 = Vector2(-r1[1].y, r1[1].x)
		var n2: Vector2 = Vector2(-r2[1].y, r2[1].x)
		for s1 in [1.0, -1.0]:
			var placed := false
			for s2 in [1.0, -1.0]:
				var p: Vector2 = v + n1 * (r1[2] + 1.6) * s1 + n2 * (r2[2] + 1.6) * s2
				if not _street_ok(p) or _on_road(p, roads, 0.3) or _is_taken(p, taken, 3.0):
					continue
				for k in 2:
					var rr: Array = r1 if k == 0 else r2
					var dv: Vector2 = rr[1]
					var t := Transform3D(Basis(Vector3.UP, atan2(-dv.y, dv.x)), Vector3(p.x, 0.24 * k, p.y))
					items.append(["StreetSign", t])
					var name: String = rr[0]
					for long in SHORT:
						name = name.replace(long, SHORT[long])
					Street.letter(root, t, name)
				_take(p, taken)
				placed = true
				break
			if placed:
				break
		# Give way on each street that ends at the corner, on its left
		for c in at:
			if c[4] == -1:
				continue
			var dv: Vector2 = c[1] * (1.0 if c[4] == 1 else -1.0)   # (towards the corner)
			var left := Vector2(dv.y, -dv.x)
			var p: Vector2 = v - dv * (c[2] + 4.0) + left * (c[2] + 0.8)
			if _street_ok(p) and not _on_road(p, roads, 0.2) and not _is_taken(p, taken, 2.0):
				items.append(["GiveWaySign", Street.at(p, -dv)])
				_take(p, taken)

## The bus stop on MacArthur Avenue across from the site.
static func _bus_stop(d: Dictionary, roads: Dictionary, taken: Dictionary, items: Array) -> void:
	var best := Vector2.ZERO
	var best_d := INF
	var bdir := Vector2.RIGHT
	var bhw := 3.0
	for r in d["roads"]:
		if r["name"] != "MacArthur Avenue":
			continue
		var pts := _v2(r["pts"])
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			for k in 11:
				var p := a.lerp(b, k / 10.0)
				var dist := p.length()
				if dist < best_d and dist > 70.0 and _street_ok(p):
					best_d = dist
					best = p
					bdir = (b - a).normalized()
					bhw = float(r["w"]) * 0.5
	if best_d == INF:
		return
	var nrm := Vector2(-bdir.y, bdir.x)
	if (best + nrm).length() < best.length():
		nrm = -nrm    # (the side away from the site)
	var p := best + nrm * (bhw + 2.2)
	if _on_road(p, roads, 0.5):
		return
	items.append(["BusShelter", Street.at(p, -nrm)])
	items.append(["BusStopSign", Street.at(best + nrm * (bhw + 0.6) + bdir * 3.0, -nrm)])
	_take(p, taken)

## Along the park paths: post-top lights one side, benches and bins the other.
static func _park_paths(d: Dictionary, roads: Dictionary, taken: Dictionary, items: Array, rng: RandomNumberGenerator) -> void:
	for r in d["paths"]:
		var pts := _v2(r["pts"])
		var hw := float(r["w"]) * 0.5
		var light := rng.randf_range(3.0, 20.0)
		var seat := rng.randf_range(10.0, 40.0)
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			if a.length() > PARK_R and b.length() > PARK_R:
				continue
			var e := b - a
			var ln := e.length()
			if ln < 0.5:
				continue
			var dir := e / ln
			var nrm := Vector2(-dir.y, dir.x)
			while light < ln:
				var p := a + dir * light + nrm * (hw + 0.7)
				if p.length() < PARK_R and _street_ok(p) and not _on_road(p, roads, 0.2) and not _is_taken(p, taken, 5.0):
					items.append(["ParkLight", Street.at(p, -nrm)])
					_take(p, taken)
				light += rng.randf_range(34.0, 44.0)
			light -= ln
			while seat < ln:
				var p := a + dir * seat - nrm * (hw + 0.9)
				var q := p + dir * 1.6
				if p.length() < PARK_R and _street_ok(p) and not _on_road(p, roads, 0.4) and not _is_taken(p, taken, 4.0):
					items.append(["ParkBench", Street.at(p, nrm)])
					if rng.randf() < 0.6:
						items.append(["ParkBin", Street.at(q, nrm)])
					_take(p, taken)
				seat += rng.randf_range(60.0, 100.0)
			seat -= ln

## The park's electric BBQ shelters: two or three, each with a picnic table
## either side, a bubbler and a bin, and bike hoops out the back.
static func _bbq(d: Dictionary, roads: Dictionary, bank: Dictionary, taken: Dictionary, items: Array,
		rng: RandomNumberGenerator) -> void:
	var made := 0
	for a in d["areas"]:
		if a["kind"] != "park" or made >= 3:
			continue
		var poly := _v2(a["pts"])
		var box := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			box = box.expand(p)
		if box.get_center().length() > 400.0 or box.get_area() < 1500.0:
			continue
		for tries in 60:
			var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
			if not Geometry2D.is_point_in_polygon(p, poly) or not _street_ok(p) or _on_road(p, roads, 6.0) \
					or _near_bank(p, bank, 12.0) or _is_taken(p, taken, 14.0):
				continue
			var face := Vector2.from_angle(rng.randi_range(0, 3) * PI * 0.5 + 0.3)
			var t := Street.at(p, face)
			items.append(["BBQShelter", t])
			for lx in [-4.8, 4.8]:
				items.append(["PicnicTable", t * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(lx, 0, 0))])
			items.append(["Bubbler", t * Transform3D(Basis(), Vector3(1.5, 0, 3.6))])
			items.append(["ParkBin", t * Transform3D(Basis(), Vector3(-1.6, 0, 3.4))])
			for k in 3:
				items.append(["BikeHoop", t * Transform3D(Basis(), Vector3(-1.0 + k * 0.9, 0, -3.8))])
			_take(p, taken)
			made += 1
			break

## The riverwalk's balustrade along the bank in front of the park, a 3 m bay
## at a time, a metre back from the edge; clear of the ferry terminal.
static func _riverwalk(d: Dictionary, items: Array) -> void:
	var ferry: Array = []
	for fe in d.get("ferry", []):
		ferry.append(Vector2(fe["at"][0], fe["at"][1]))
	var beach: Array = []
	for a in d["areas"]:
		if a["kind"] == "beach":
			beach.append(_v2(a["pts"]))
	for a in d["areas"]:
		if a["kind"] != "water":
			continue
		var poly := _v2(a["pts"])
		for i in poly.size():
			var p0 := poly[i]
			var p1 := poly[(i + 1) % poly.size()]
			if p0.length() > PARK_R and p1.length() > PARK_R:
				continue
			var e := p1 - p0
			var ln := e.length()
			if ln < 1.0:
				continue
			var dir := e / ln
			var into := Vector2(-dir.y, dir.x)
			if not Geometry2D.is_point_in_polygon((p0 + p1) * 0.5 + into * 2.0, poly):
				into = -into
			var n := maxi(1, roundi(ln / 3.0))
			for k in n:
				var p := p0.lerp(p1, (k + 0.5) / n) - into * 1.0
				if p.length() > PARK_R or not _street_ok(p):
					continue
				var skip := false
				for f in ferry:
					if p.distance_to(f) < 45.0:
						skip = true
				for bp in beach:
					if Geometry2D.is_point_in_polygon(p - into * 2.0, bp):
						skip = true
				if skip:
					continue
				var t := Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)).scaled(Vector3(ln / n / 3.0, 1, 1)),
					Vector3(p.x, 0, p.y))
				items.append(["RiverwalkRail", t])

## Round the site, the trees the LiDAR found (_lidar_trees). Past that, the
## map's own trees, the parks, the golf course and the scrub planted out
## at about the density the aerial photos show, street trees down the roads
## near the site, and mangroves in patches along the river's edge. Each spot
## gets a species from what grows there (scripts/flora.gd), kept off the roads.
static func _trees(root: Node3D, d: Dictionary, roads: Dictionary, bank: Dictionary, taken: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var plant: Array = []
	var lidar := _lidar_trees(d, roads, bank, taken, plant, rng)
	var ok := func(p: Vector2) -> bool:
		return _clear(p) and not TRUCK_ROAD.has_point(p) and not _on_road(p, roads, 1.2) and not _is_taken(p, taken, 2.0) \
			and not Geometry2D.is_point_in_polygon(p, lidar)
	for t in d["trees"]:
		var p := Vector2(t[0], t[1])
		if ok.call(p):
			plant.append([Flora.pick("street", rng), Vector3(p.x, 0, p.y)])
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
			if ok.call(p) and Geometry2D.is_point_in_polygon(p, poly):
				var mix: String = a["kind"]
				if mix == "park" and _near_bank(p, bank, 45.0):
					mix = "riverside"
				plant.append([Flora.pick(mix, rng), Vector3(p.x, 0, p.y)])
	_street_trees(d, roads, taken, lidar, plant, rng)
	_mangroves(d, bank, lidar, plant, rng)
	Flora.plant(root, plant, rng)

## Inside the 1 km LiDAR tile round the site, a tree at every tree top the
## 2019 LiDAR found, at its real height, the species going by where it stands:
## mangroves on the drains and the river's edge, the golf course's gums and
## paperbarks, street trees by the roads, park trees in the parks, garden trees
## elsewhere. Returns the tile's outline, so the made-up planting stays out.
static func _lidar_trees(d: Dictionary, roads: Dictionary, bank: Dictionary, taken: Dictionary, plant: Array,
		rng: RandomNumberGenerator) -> PackedVector2Array:
	if not FileAccess.file_exists(LIDAR_TREES):
		return PackedVector2Array()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIDAR_TREES))
	var areas := {"golf": [], "park": [], "water": [], "scrub": []}
	for a in d["areas"]:
		if areas.has(a["kind"]):
			areas[a["kind"]].append(_v2(a["pts"]))
	var drains: Array = []
	for r in d.get("drains", []):
		drains.append(_v2(r["pts"]))
	var inside := func(p: Vector2, kind: String) -> bool:
		for poly in areas[kind]:
			if Geometry2D.is_point_in_polygon(p, poly):
				return true
		return false
	for t in data["trees"]:
		var p := Vector2(t[0], t[1])
		var h: float = t[2]
		if not _clear(p) or TRUCK_ROAD.has_point(p) or _on_road(p, roads, 0.5) or _is_taken(p, taken, 1.0):
			continue
		var sp: String
		var y := 0.0
		if inside.call(p, "water"):
			# (standing in the shallows, below the riverwalk)
			sp = "Mangrove" if h < 12.0 else "Paperbark"
			y = RIVER_Y + 0.3
		elif (p.length() > 260.0 and _near_bank(p, bank, 10.0) and rng.randf() < 0.7) \
				or (_near_line(p, drains, 14.0) and rng.randf() < 0.75):
			sp = "Mangrove" if h < 12.0 else "Paperbark"
		elif inside.call(p, "golf"):
			sp = Flora.pick("golf", rng)
		elif _on_road(p, roads, 7.0):
			sp = Flora.pick("street", rng)
		elif inside.call(p, "park"):
			sp = Flora.pick("riverside" if _near_bank(p, bank, 45.0) else "park", rng)
		elif inside.call(p, "scrub"):
			sp = Flora.pick("scrub", rng)
		else:
			sp = Flora.pick("suburb", rng)
		# The tall ones are figs and gums whatever the mix says
		if h > 15.0 and not sp in ["Fig", "Gum", "Paperbark"]:
			sp = "Fig" if rng.randf() < 0.4 else "Gum"
		plant.append([sp, Vector3(p.x, y, p.y), h])
	return _v2(data["tile"])

static func _near_line(p: Vector2, lines: Array, dist: float) -> bool:
	for line in lines:
		for i in line.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])) < dist:
				return true
	return false

## Street trees both sides of the local streets near the site, every 13 m or
## so, with lomandra and bottlebrush in the beds between.
static func _street_trees(d: Dictionary, roads: Dictionary, taken: Dictionary, lidar: PackedVector2Array, plant: Array,
		rng: RandomNumberGenerator) -> void:
	for r in d["roads"]:
		if not r["kind"] in ["residential", "unclassified", "tertiary", "secondary", "living_street"]:
			continue
		var pts := _v2(r["pts"])
		var off := float(r["w"]) * 0.5 + 2.2
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			if a.length() > 450.0 and b.length() > 450.0:
				continue
			var e := b - a
			var ln := e.length()
			if ln < 1.0:
				continue
			var dir := e / ln
			var nrm := Vector2(-dir.y, dir.x)
			var s := rng.randf_range(2.0, 8.0)
			while s < ln:
				for side in [-1.0, 1.0]:
					var p: Vector2 = a + dir * s + nrm * off * side
					if p.length() > 450.0 or not _clear(p) or TRUCK_ROAD.has_point(p) or _on_road(p, roads, 1.0) \
							or _is_taken(p, taken, 2.5):
						continue
					if not Geometry2D.is_point_in_polygon(p, lidar):
						plant.append([Flora.pick("street", rng), Vector3(p.x, 0, p.y)])
					if p.length() < 260.0:
						for k in 3:
							var q: Vector2 = p + dir * rng.randf_range(2.5, 10.0) + nrm * side * rng.randf_range(-0.6, 0.6)
							if not _on_road(q, roads, 0.4) and _clear(q):
								plant.append([Flora.pick("bed", rng), Vector3(q.x, 0, q.y)])
				s += rng.randf_range(11.0, 15.0)

## Grey mangroves in patches on the river's edge, standing in the shallows;
## none on the frontage in front of Riverlight (rock wall and riverwalk) or by
## the ferry terminal.
static func _mangroves(d: Dictionary, bank: Dictionary, lidar: PackedVector2Array, plant: Array, rng: RandomNumberGenerator) -> void:
	var avoid: Array = []
	for fe in d.get("ferry", []):
		avoid.append(Vector2(fe["at"][0], fe["at"][1]))
	for cell in bank:
		for e in bank[cell]:
			var p: Vector2 = e[0]
			var dist := p.length()
			if dist < 260.0 or dist > 1100.0 or Geometry2D.is_point_in_polygon(p, lidar):
				continue
			var near_ferry := false
			for f in avoid:
				if p.distance_to(f) < 90.0:
					near_ferry = true
			if near_ferry:
				continue
			# (patches: where two slow waves along the bank agree)
			if sin(p.x * 0.021) + sin(p.y * 0.017 + 1.3) < 0.4 or rng.randf() > 0.75:
				continue
			var into: Vector2 = e[1]
			var q := p + into * rng.randf_range(0.5, 3.0) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
			plant.append(["Mangrove", Vector3(q.x, Water.wall_y(p.distance_to(q)) - 0.2, q.y)])

## The roads and paths near the site, sampled every 4 m into a 20 m grid:
## each sample its point and half-width.
static func _road_grid(d: Dictionary) -> Dictionary:
	var g := {}
	var id := 0
	for list in [d["roads"], d["paths"]]:
		for r in list:
			id += 1
			var pts := _v2(r["pts"])
			var hw := float(r["w"]) * 0.5
			for i in pts.size() - 1:
				var a := pts[i]
				var b := pts[i + 1]
				if a.length() > 1000.0 and b.length() > 1000.0:
					continue
				var n := maxi(1, ceili(a.distance_to(b) / 4.0))
				for k in n + 1:
					var p := a.lerp(b, float(k) / n)
					var c := Vector2i(floori(p.x / 20.0), floori(p.y / 20.0))
					if not g.has(c):
						g[c] = []
					g[c].append([p, hw, id])
	return g

## Whether `p` is on (or within `pad` of) a road or path; `skip` leaves one
## out (by its place in the grid's numbering: roads from 1, then paths).
static func _on_road(p: Vector2, g: Dictionary, pad: float, skip := 0) -> bool:
	var c := Vector2i(floori(p.x / 20.0), floori(p.y / 20.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for s in g.get(c + Vector2i(dx, dz), []):
				if s[2] != skip and p.distance_to(s[0]) < float(s[1]) + pad:
					return true
	return false

## Spots already taken by street furniture (a 10 m grid of points).
static func _take(p: Vector2, taken: Dictionary) -> void:
	var c := Vector2i(floori(p.x / 10.0), floori(p.y / 10.0))
	if not taken.has(c):
		taken[c] = []
	taken[c].append(p)

## Marks a building's footprint taken, every 2.5 m.
static func _take_area(poly: PackedVector2Array, taken: Dictionary) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var x := box.position.x
	while x <= box.end.x:
		var z := box.position.y
		while z <= box.end.y:
			var p := Vector2(x, z)
			if Geometry2D.is_point_in_polygon(p, poly):
				_take(p, taken)
			z += 2.5
		x += 2.5

static func _is_taken(p: Vector2, taken: Dictionary, r: float) -> bool:
	var c := Vector2i(floori(p.x / 10.0), floori(p.y / 10.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for q in taken.get(c + Vector2i(dx, dz), []):
				if p.distance_to(q) < r:
					return true
	return false

## The river's edge within 1.3 km, sampled every 8 m into a 50 m grid: each
## sample its point and which way the water is.
static func _bank_grid(d: Dictionary) -> Dictionary:
	var g := {}
	for a in d["areas"]:
		if a["kind"] != "water":
			continue
		var poly := _v2(a["pts"])
		for i in poly.size():
			var p0 := poly[i]
			var p1 := poly[(i + 1) % poly.size()]
			if p0.length() > 1300.0 and p1.length() > 1300.0:
				continue
			var e := p1 - p0
			var ln := e.length()
			if ln < 0.5:
				continue
			var nrm := Vector2(-e.y, e.x) / ln
			var mid := (p0 + p1) * 0.5
			if not Geometry2D.is_point_in_polygon(mid + nrm * 2.0, poly):
				nrm = -nrm
			var n := maxi(1, ceili(ln / 8.0))
			for k in n:
				var p := p0.lerp(p1, (k + 0.5) / n)
				var c := Vector2i(floori(p.x / 50.0), floori(p.y / 50.0))
				if not g.has(c):
					g[c] = []
				g[c].append([p, nrm])
	return g

static func _near_bank(p: Vector2, g: Dictionary, dist: float) -> bool:
	var c := Vector2i(floori(p.x / 50.0), floori(p.y / 50.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for s in g.get(c + Vector2i(dx, dz), []):
				if p.distance_to(s[0]) < dist:
					return true
	return false

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
	var plant: Array = []
	for t in trees:
		plant.append([Flora.pick("suburb", rng), t])
	Flora.plant(root, plant, rng)

static func _house_field(root: Node3D, at: Array, rng: RandomNumberGenerator) -> void:
	Neighbours.house_field(root, at, rng)

static func _add_multi(root: Node3D, mm: MultiMesh, shadows := false) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _tinted()
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

# ------------------------------------------------------------------ materials

## The river (shaders/river.gdshader): the Brisbane River's olive green-grey,
## rippling, picking up the sky.
static var _river: ShaderMaterial
static func _water() -> ShaderMaterial:
	if _river == null:
		_river = ShaderMaterial.new()
		_river.shader = preload("res://shaders/river.gdshader")
		_river.set_shader_parameter("water", F.COLORS["river"])
	return _river

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

## The real skyline out to the city: every building 18 m and up from the map
## (the CBD and Kangaroo Point 6-7 km up the river, Newstead and Teneriffe,
## Portside, Bulimba), the river through its bends to the city, far
## landmarks and the hills behind. Vertex coloured, windows from the shader.
static func _skyline(root: Node3D, rng: RandomNumberGenerator) -> void:
	if not FileAccess.file_exists(SKYLINE):
		push_warning("surrounds: %s missing, no skyline" % SKYLINE)
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SKYLINE))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in d["towers"]:
		var poly := _v2(t["pts"])
		if poly.size() < 3:
			continue
		var c := Color(t["c"])
		_extrude(st, poly, float(t["h"]), c, c.darkened(0.12))
	var towers := MeshInstance3D.new()
	towers.mesh = st.commit()
	var m := F.window_mat(Color.WHITE, 0.0, 0.0)
	m.set_shader_parameter("vertex_tint", true)
	m.set_shader_parameter("cell", Vector2(3.0, 3.2))
	towers.material_override = m
	towers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(towers)
	# The river up through Hamilton Reach and the bends to the city
	var wt := SurfaceTool.new()
	wt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wet: Array = []
	for w in d["water"]:
		var poly := _v2(w)
		wet.append(poly)
		_flat(wt, poly, RIVER_Y, Color.WHITE)
	var water := MeshInstance3D.new()
	water.mesh = wt.commit()
	water.material_override = _water()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	# Suburbs: houses and trees thinning out to the edge of the haze, up over
	# the hills
	var hills: Array = d.get("hills", [])
	var houses: Array = []
	var trees: Array = []
	for i in 9000:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf_range(FAR * FAR, CITY * CITY))
		var p := Vector2(cos(ang), sin(ang)) * r
		var dry := true
		for w in wet:
			if Geometry2D.is_point_in_polygon(p, w):
				dry = false
				break
		if not dry:
			continue
		var y := _hill_y(hills, p) - 0.5
		if i % 3 == 0:
			trees.append(Vector3(p.x, y, p.y))
		else:
			houses.append(Vector3(p.x, y, p.y))
	# The Hamilton ridge close by is leafy streets: thick with trees
	for h in hills:
		var r := float(h["r"])
		if r > 1200.0:
			continue
		var c := Vector2(h["at"][0], h["at"][1])
		for i in int(r * r / 900.0):
			var p := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r
			var y := _hill_y(hills, p) - 0.5
			if i % 4 == 0:
				houses.append(Vector3(p.x, y, p.y))
			else:
				trees.append(Vector3(p.x, y, p.y))
	_house_field(root, houses, rng)
	var plant: Array = []
	for t in trees:
		plant.append([Flora.pick("suburb", rng), t])
	Flora.plant(root, plant, rng)
	# Hills: soft green mounds (Mt Coot-tha, Mt Gravatt, the Hamilton ridge)
	for h in hills:
		var mound := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = float(h["r"])
		sm.height = float(h["h"]) * 2.0
		sm.is_hemisphere = true
		sm.radial_segments = 32
		sm.rings = 8
		mound.mesh = sm
		mound.position = Vector3(h["at"][0], -0.3, h["at"][1])
		mound.material_override = F.color_mat(Color(h.get("c", "5f7f4a")))
		mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mound)
	# Masts and far landmarks: the TV towers on Mt Coot-tha, the airport's
	# control tower, Riparian Plaza's mast, the crane still on Skytower
	for t in d.get("masts", []):
		var h := float(t["h"])
		var base := float(t.get("base", 0.0))
		if h < 20.0 and base <= 0.0:
			continue
		var w := float(t.get("w", maxf(3.0, h * 0.04)))
		var mat := F.color_mat(Color(t.get("c", "c8ccd0")))
		var at := Vector3(t["at"][0], base, t["at"][1])
		match t.get("kind", "mast"):
			"gasholder":
				# the gasholder's empty iron frame: posts round a ring, tied at the top
				var span := TAU * w * 0.5 / 16.0
				for k in 16:
					var a := TAU * k / 16.0
					var q := at + Vector3(cos(a), 0, sin(a)) * w * 0.5
					root.add_child(F.box(Vector3(1.6, h, 1.6), mat, q + Vector3(0, h * 0.5, 0), false))
					var a2 := a + TAU / 32.0
					var tie := F.box(Vector3(1.2, 1.2, span), mat, at + Vector3(cos(a2), 0, sin(a2)) * w * 0.5 + Vector3(0, h - 0.6, 0), false)
					tie.rotation.y = -a2
					root.add_child(tie)
			"gantry":
				# a quayside container crane: legs, and the boom out over the water
				root.add_child(F.box(Vector3(w, h * 0.6, w * 1.5), mat, at + Vector3(0, h * 0.3, 0), false))
				root.add_child(F.box(Vector3(w * 4.0, 4.0, 5.0), mat, at + Vector3(0, h * 0.6, 0), false))
			"crane":
				root.add_child(F.box(Vector3(w, h, w), mat, at + Vector3(0, h * 0.5, 0), false))
				root.add_child(F.box(Vector3(55.0, 2.5, 2.5), mat, at + Vector3(10.0, h, 0), false))
			_:
				root.add_child(F.box(Vector3(w, h, w), mat, at + Vector3(0, h * 0.5, 0), false))

## How high the hills lift the ground at `p` (they're half ellipsoids).
static func _hill_y(hills: Array, p: Vector2) -> float:
	var y := 0.0
	for h in hills:
		var r := float(h["r"])
		var k := p.distance_to(Vector2(h["at"][0], h["at"][1])) / r
		if k < 1.0:
			y = maxf(y, float(h["h"]) * sqrt(1.0 - k * k))
	return y

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
			var pier := F.box(Vector3(t, h - RIVER_Y, t * 1.6), concrete, Vector3(q.x, (h + RIVER_Y) * 0.5, q.y), false)
			pier.rotation.y = atan2(dir.x, dir.y)
			root.add_child(pier)

static func _gateway_deck(u: float) -> float:
	return 4.0 + 60.5 * (1.0 - u * u)
