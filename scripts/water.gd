## What's on and along the river off Northshore: the rock revetment down the
## bank, boats swinging on their moorings, the channel piles, a pontoon, a
## rowing eight and a tinny going up and down, and the cruise ship alongside
## Portside Wharf. The models are tools/blender/water.py
## (assets/water/water.glb); the river itself is surrounds.gd's.
extends RefCounted

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/water/water.glb"

const COLORS := {
	"hull_white": Color("f2f2ee"), "hull_navy": Color("1f3550"), "alloy": Color("b8c0c6"), "alloy_dark": Color("8a949b"),
	"antifoul": Color("a8423a"), "deck": Color("d9c9a6"), "glass": Color("3a5068"), "mast": Color("d8dcdf"),
	"sail": Color("e9e4d6"), "sail_cover": Color("2c5f8a"), "motor": Color("2b2d30"), "seat": Color("e8e2d0"),
	"shell": Color("f4f1e8"), "oar": Color("e9e1c8"), "blade": Color("c8302c"), "rower": Color("2f6fd1"),
	"skin": Color("d9a07a"), "pile": Color("6b5a48"), "green": Color("2f8a4a"), "red": Color("d0342c"),
	"buoy": Color("f4f7fa"), "pontoon": Color("c4c2bb"), "float": Color("2b2d30"), "rail": Color("a9b0b5"),
	"rock": Color("8a8478"), "rock_dark": Color("6e695f"), "funnel": Color("1f4f9a"), "funnel_top": Color("2b2b2b"),
	"lifeboat": Color("ff7a1a"), "balcony": Color("dfe3e6"), "window": Color("34495e"), "pool": Color("4fa3c7"),
}
const BANK_R := 1200.0    # the revetment this far from the site
const ROCK := Color("8a8478")
const SAND := Color("d8c9a3")
## The river's surface, below the land (GROUND_Y in surrounds.gd): the
## riverwalk and the estate stand 3 to 4 m above mean river level in the 2019
## LiDAR ground; this is a bit under that, so the drop reads from the deck
## without towering over the riverwalk
const RIVER_Y := -2.5
## The rock wall's profile, across the bank (m into the water from the edge,
## height): from the riverwalk's edge down under the water
const WALL := [[-2.0, 0.25], [0.0, 0.08], [1.8, RIVER_Y + 0.8], [3.6, RIVER_Y - 0.6]]
## ...and the beach's: sand running down into the water
const SHORE := [[-0.5, 0.03], [3.0, RIVER_Y * 0.45], [7.0, RIVER_Y - 0.3]]

static var _lib: Node
static var _meshes := {}
static var _mats := {}

static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(name) as MeshInstance3D
	if mi == null:
		push_warning("water: no model " + name)
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

## One model as its own node (for the boats that move or bob).
static func node(name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(name)
	mi.name = name
	return mi

## Everything, given the map data (`d`), the water's edge sampled by
## surrounds.gd (`bank`: cell -> [[point, towards the water], ...]) and where
## not to put things.
static func build(root: Node3D, d: Dictionary, bank: Dictionary, keep_clear: Callable, rng: RandomNumberGenerator) -> void:
	var ferry: Array = []
	for fe in d.get("ferry", []):
		ferry.append(Vector2(fe["at"][0], fe["at"][1]))
	var beach: Array = []
	var water: Array = []
	for a in d["areas"]:
		if a["kind"] == "beach":
			beach.append(_v2(a["pts"]))
		elif a["kind"] == "water":
			water.append(_v2(a["pts"]))
	var route: Array = []
	for r in d.get("cat_route", []):
		route.append(Vector2(r[0], r[1]))
	_revetment(root, water, ferry, beach, keep_clear, rng)
	# everything afloat, down at the river's level
	var river := Node3D.new()
	river.name = "OnTheRiver"
	river.position.y = RIVER_Y
	root.add_child(river)
	_moorings(river, bank, water, ferry, route, rng)
	_piles(river, route, water)
	_pontoon(river, bank, ferry, water)
	_traffic(river, route, water)
	_cruise_ship(river, d, water)

static func _v2(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	if out.size() > 2 and out[0].is_equal_approx(out[out.size() - 1]):
		out.remove_at(out.size() - 1)
	return out

static func _wet(p: Vector2, water: Array) -> bool:
	for w in water:
		if Geometry2D.is_point_in_polygon(p, w):
			return true
	return false

# ------------------------------------------------------------------ the bank

## The rock wall down the bank: a sloping strip from just behind the edge to
## under the water, rocks heaped along it; on the beach, sand running down
## into the water instead. None at the ferry terminal (its wall's
## surrounds.gd's plain bank).
static func _revetment(root: Node3D, water: Array, ferry: Array, beach: Array, keep_clear: Callable,
		rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rocks: Array = []
	for poly in water:
		for i in poly.size():
			var p0: Vector2 = poly[i]
			var p1: Vector2 = poly[(i + 1) % poly.size()]
			if p0.length() > BANK_R and p1.length() > BANK_R:
				continue
			var e := p1 - p0
			var ln := e.length()
			if ln < 0.5:
				continue
			var dir := e / ln
			var into := Vector2(-dir.y, dir.x)
			if not Geometry2D.is_point_in_polygon((p0 + p1) * 0.5 + into * 2.0, poly):
				into = -into
			var n := maxi(1, ceili(ln / 4.0))
			for k in n:
				var a := p0.lerp(p1, float(k) / n)
				var b := p0.lerp(p1, float(k + 1) / n)
				var m := (a + b) * 0.5
				if m.length() > BANK_R or not keep_clear.call(m):
					continue
				var skip := false
				for f in ferry:
					if m.distance_to(f) < 40.0:
						skip = true
				var sandy := false
				for bp in beach:
					if Geometry2D.is_point_in_polygon(m - into * 2.0, bp) or Geometry2D.is_point_in_polygon(m + into * 1.0, bp):
						sandy = true
				if skip:
					continue
				# Rows across: behind the edge, at it, and on down under the water
				var rows: Array = SHORE if sandy else WALL
				var va: Array = []
				var vb: Array = []
				for r in rows:
					va.append(Vector3(a.x + into.x * r[0], r[1], a.y + into.y * r[0]))
					vb.append(Vector3(b.x + into.x * r[0], r[1], b.y + into.y * r[0]))
				var nrm := Vector3(into.x, 1.2, into.y).normalized()
				for j in rows.size() - 1:
					var c := SAND.darkened(rng.randf_range(0.0, 0.06) + 0.1 * j) if sandy else ROCK.darkened(rng.randf_range(0.0, 0.15))
					_quad(st, va[j], vb[j], vb[j + 1], va[j + 1], nrm, c)
				if sandy:
					continue
				# Rocks along it, half sunk
				for q in 4:
					var t := rng.randf()
					var across := rng.randf_range(-1.8, 2.8)
					var at := a.lerp(b, t) + into * across
					var y := wall_y(across)
					var s := rng.randf_range(0.7, 1.4)
					var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
					rocks.append(["Rock%d" % rng.randi_range(0, 2), Transform3D(basis.scaled(Vector3(s, s, s)), Vector3(at.x, y, at.y))])
	var mi := MeshInstance3D.new()
	mi.name = "Revetment"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_multi(root, rocks, false)

## How high the rock wall stands this far out from the bank's edge.
static func wall_y(across: float) -> float:
	for i in WALL.size() - 1:
		if across <= WALL[i + 1][0]:
			return lerpf(WALL[i][1], WALL[i + 1][1], clampf((across - WALL[i][0]) / (WALL[i + 1][0] - WALL[i][0]), 0.0, 1.0))
	return WALL[WALL.size() - 1][1]

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(n)
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)

## Many copies of the models in `items` ([name, Transform3D]), one multimesh each.
static func _multi(root: Node3D, items: Array, shadows: bool) -> void:
	var groups := {}
	for it in items:
		if not groups.has(it[0]):
			groups[it[0]] = []
		groups[it[0]].append(it[1])
	for name in groups:
		var m := mesh(name)
		if m == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		mm.instance_count = groups[name].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, groups[name][i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Water_" + name
		mi.multimesh = mm
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

# ------------------------------------------------------------------ on the water

## Yachts and cruisers on swing moorings out from the bank, all lying the same
## way to the tide, each nodding on its buoy.
static func _moorings(root: Node3D, bank: Dictionary, water: Array, ferry: Array, route: Array,
		rng: RandomNumberGenerator) -> void:
	var spots: Array = []
	for cell in bank:
		for e in bank[cell]:
			var p: Vector2 = e[0]
			if p.length() < 380.0 or p.length() > 1500.0 or rng.randf() > 0.08:
				continue
			var into: Vector2 = e[1]
			var at := p + into * rng.randf_range(45.0, 75.0)
			if not _wet(at, water) or not _wet(at + into * 40.0, water):
				continue
			var ok := true
			for f in ferry:
				if at.distance_to(f) < 140.0:
					ok = false
			for r in route:
				if at.distance_to(r) < 70.0:
					ok = false
			for s in spots:
				if at.distance_to(s) < 35.0:
					ok = false
			if ok:
				spots.append(at)
	spots = spots.slice(0, 14)
	for i in spots.size():
		var at: Vector2 = spots[i]
		var kind := "Yacht" if i % 3 != 2 else "Cruiser"
		var boat := node(kind)
		var heading := 0.12 + rng.randf_range(-0.12, 0.12)   # (bows upstream, into the ebb)
		boat.position = Vector3(at.x, 0, at.y)
		boat.rotation.y = heading
		root.add_child(boat)
		var buoy := node("MooringBuoy")
		buoy.position = boat.position + Vector3(cos(heading), 0, -sin(heading)) * 8.0
		root.add_child(buoy)
		_bob(boat, rng.randf_range(2.6, 3.6), rng.randf_range(0.015, 0.03))

## A gentle roll and pitch, forever.
static func _bob(n: Node3D, period: float, amp: float) -> void:
	var tw := n.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "rotation:x", amp, period * 0.5)
	tw.parallel().tween_property(n, "rotation:z", -amp * 0.6, period * 0.5)
	tw.tween_property(n, "rotation:x", -amp, period * 0.5)
	tw.parallel().tween_property(n, "rotation:z", amp * 0.6, period * 0.5)

## The channel piles either side of the CityCat's course: green on the north
## side (starboard, coming up the river), red on the south.
static func _piles(root: Node3D, route: Array, water: Array) -> void:
	var items: Array = []
	var run := 0.0
	for i in range(1, route.size()):
		var a: Vector2 = route[i - 1]
		var b: Vector2 = route[i]
		var ln := a.distance_to(b)
		var up := (a - b).normalized()      # (the route runs down from the city)
		var right := Vector2(-up.y, up.x)
		var t := 350.0 - run
		while t < ln:
			var p := b.lerp(a, 1.0 - t / ln)
			if p.length() < 1700.0:
				for sd in [1.0, -1.0]:
					var q: Vector2 = p + right * 58.0 * sd
					if _wet(q, water):
						items.append(["PileGreen" if sd > 0 else "PileRed", Transform3D(Basis(), Vector3(q.x, 0, q.y))])
			t += 350.0
		run = fmod(run + ln, 350.0)
	_multi(root, items, false)

## A private pontoon off the park, its gangway up to the bank.
static func _pontoon(root: Node3D, bank: Dictionary, ferry: Array, water: Array) -> void:
	if ferry.is_empty():
		return
	var want: Vector2 = ferry[0] + Vector2(-420.0, 0.0)
	var best: Array = []
	var bd := INF
	for cell in bank:
		for e in bank[cell]:
			var dd: float = (e[0] as Vector2).distance_to(want)
			if dd < bd:
				bd = dd
				best = e
	if best.is_empty() or bd > 200.0:
		return
	var into: Vector2 = best[1]
	var at: Vector2 = best[0] + into * 10.5
	var p := node("Pontoon")
	p.position = Vector3(at.x, 0, at.y)
	p.rotation.y = atan2(into.x, into.y)
	root.add_child(p)
	var tinny := node("Tinny")
	tinny.position = p.position + p.basis.x * 2.0 + p.basis.z * 2.6
	tinny.rotation.y = p.rotation.y + PI * 0.5
	root.add_child(tinny)
	_bob(tinny, 2.4, 0.03)

## A rowing eight and a tinny working up and down the reach, off to either
## side of the CityCat's course.
static func _traffic(root: Node3D, route: Array, water: Array) -> void:
	if route.size() < 2:
		return
	for spec in [["RowingEight", -32.0, 4.2, 0.0], ["Tinny", 26.0, 3.0, 50.0]]:
		var pts: Array = []
		for i in route.size():
			var a: Vector2 = route[maxi(i - 1, 0)]
			var b: Vector2 = route[mini(i + 1, route.size() - 1)]
			var up := (a - b).normalized()
			var q: Vector2 = route[i] + Vector2(-up.y, up.x) * float(spec[1])
			if _wet(q, water) and q.length() < 2200.0:
				pts.append(Vector3(q.x, 0, q.y))
		if pts.size() < 2:
			continue
		var boat := node(spec[0])
		boat.position = pts[0]
		root.add_child(boat)
		var tw := boat.create_tween().set_loops()
		tw.tween_interval(spec[3] + 0.01)
		var legs := [pts, pts.duplicate()]
		legs[1].reverse()
		for leg in legs:
			for i in range(1, leg.size()):
				var a: Vector3 = leg[i - 1]
				var b: Vector3 = leg[i]
				var dir := b - a
				tw.tween_callback(func(): boat.rotation.y = atan2(-dir.z, dir.x))
				tw.tween_property(boat, "position", b, a.distance_to(b) / float(spec[2]))
			tw.tween_interval(30.0)

## The cruise ship alongside Portside Wharf, by the old Brisbane Cruise
## Terminal at Hamilton (where they tied up in 2017).
static func _cruise_ship(root: Node3D, d: Dictionary, water: Array) -> void:
	var term := Vector2.INF
	for b in d["buildings"]:
		if b["name"] == "Brisbane Cruise Terminal":
			var pts := _v2(b["pts"])
			var c := Vector2.ZERO
			for p in pts:
				c += p
			term = c / pts.size()
	if term == Vector2.INF:
		return
	var best := Vector2.INF
	var bdir := Vector2.RIGHT
	var binto := Vector2.UP
	for poly in water:
		for i in poly.size():
			var p0: Vector2 = poly[i]
			var p1: Vector2 = poly[(i + 1) % poly.size()]
			var q := Geometry2D.get_closest_point_to_segment(term, p0, p1)
			if q.distance_to(term) < best.distance_to(term) and (p1 - p0).length() > 20.0:
				best = q
				bdir = (p1 - p0).normalized()
				binto = Vector2(-bdir.y, bdir.x)
				if not Geometry2D.is_point_in_polygon(q + binto * 3.0, poly):
					binto = -binto
	if best == Vector2.INF or best.distance_to(term) > 250.0:
		return
	var at := best + binto * 22.0
	var ship := node("CruiseShip")
	ship.position = Vector3(at.x, 0, at.y)
	if bdir.x < 0.0:
		bdir = -bdir    # (bow upstream)
	ship.rotation.y = atan2(-bdir.y, bdir.x)
	root.add_child(ship)
