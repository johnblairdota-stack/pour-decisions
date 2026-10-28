## The fences and gates round Riverlight: the 2017 estate's houses (slatted
## front fences with a gate and a driveway gate, Colorbond between the lots,
## pool glass to the golf course), low walls and slat fences round the
## apartment blocks, chain-link round the car yards with the gates where the
## road goes in, chain-link and palisade round the sheds, the golf course's
## fence along the road, and timber bollards along the park's road edges.
## The models are tools/blender/fences.py (assets/fences/fences.glb): one
## 3 m bay each, stretched a little to fit a run; scripts/surrounds.gd makes
## them with the map.
extends RefCounted

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/fences/fences.glb"
const ESTATE := "res://data/hamilton_reach_2017.json"
const BAY := 3.0
const TILE := 120.0
const NEAR := 650.0          # fence runs this close to the site
const SEE := 700.0           # and seen this far off

const COLORS := {
	"galv": Color("a9b0b5"), "timber": Color("b98a55"), "timber_dark": Color("8e6a44"), "render": Color("e8e2d6"),
	"glass": Color("9cc3d6"), "steel_black": Color("2e3236"), "boom_red": Color("d9302c"), "boom_white": Color("f4f7fa"),
	"concrete": Color("c4c2bb"), "letterbox": Color("3a3f44"), "rubber": Color("222222"), "yellow": Color("ffc72c"),
}
## Colorbond fence colours of the day: Woodland Grey, Basalt,
## Surfmist, Dune, Shale Grey, Paperbark
const COLORBOND := [Color("4b4f4a"), Color("6d6c6e"), Color("e4e2d5"), Color("b1ada3"),
	Color("bdbfba"), Color("cabfa4")]
const SLATS := [Color("4a4f55"), Color("9a6b45"), Color("f4f4f2"), Color("6d6c6e"), Color("b98a55")]
const PALINGS := [Color("b08f68"), Color("9c7b58"), Color("c2a47e")]
const RENDER := [Color("e8e2d6"), Color("d8d2c4"), Color("f2efe8")]

static var _lib: Node
static var _meshes := {}
static var _mats := {}

## Lays the fences. `ok(p)`: whether a bay can stand at p (off the site and
## clear of what's there); `road(p, pad)`: whether p is within pad of a road
## or path.
static func build(root: Node3D, d: Dictionary, ok: Callable, road: Callable, rng: RandomNumberGenerator) -> void:
	var items: Array = []
	var est: Dictionary = {}
	if FileAccess.file_exists(ESTATE):
		est = JSON.parse_string(FileAccess.get_file_as_string(ESTATE))
	var on := func(p: Vector2) -> bool: return ok.call(p) and not road.call(p, 0.6)
	_houses(est, items, on, rng)
	_blocks(est, items, func(p: Vector2) -> bool: return ok.call(p) and not road.call(p, 1.2), rng)
	_yards(est, items, ok, road)
	_areas(d, items, ok, road, rng)
	place(root, items)

# ------------------------------------------------------------------ runs

## A run of `kind` from a to b, a bay at a time where `ok`, a post where the
## run stops. Returns the gaps (each [from, to]) where bays were left out.
static func run(items: Array, kind: String, a: Vector2, b: Vector2, col: Color, ok: Callable, post := "") -> Array:
	var gaps: Array = []
	var ln := a.distance_to(b)
	if ln < 0.5:
		return gaps
	var n := maxi(1, roundi(ln / BAY))
	var dir := (b - a) / ln
	var basis := Basis(Vector3.UP, atan2(-dir.y, dir.x)).scaled(Vector3(ln / n / BAY, 1, 1))
	var was := false
	var gap_from := a
	for k in n:
		var c := a.lerp(b, (k + 0.5) / n)
		var s := a.lerp(b, float(k) / n)
		var e := a.lerp(b, float(k + 1) / n)
		if ok.call(c):
			if not was and k > 0:
				gaps.append([gap_from, s])
			items.append([kind, Transform3D(basis, Vector3(c.x, 0, c.y)), col])
			was = true
		else:
			if was and post != "":
				items.append([post, Transform3D(Basis(), Vector3(s.x, 0, s.y)), col])
			if was or k == 0:
				gap_from = s
			was = false
	if was and post != "":
		items.append([post, Transform3D(Basis(), Vector3(b.x, 0, b.y)), col])
	elif not was:
		gaps.append([gap_from, b])
	return gaps

## One model standing at p, its x along `dir`.
static func one(items: Array, kind: String, p: Vector2, dir: Vector2, col := Color.WHITE) -> void:
	items.append([kind, Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), Vector3(p.x, 0, p.y)), col])

# ------------------------------------------------------------------ the estate

## Each house's lot: the front fence and its gates where the lot meets the
## street, Colorbond down the side to the next lot and between the rows,
## pool glass along the back where it looks onto the golf course.
static func _houses(est: Dictionary, items: Array, ok: Callable, rng: RandomNumberGenerator) -> void:
	var hs: Array = est.get("houses", [])
	var pts: Array = []
	for h in hs:
		pts.append(Vector2(h["at"][0], h["at"][1]))
	for i in hs.size():
		var p: Vector2 = pts[i]
		var f := Vector2(hs[i]["face"][0], hs[i]["face"][1]).normalized()
		var r := Vector2(f.y, -f.x)
		var front := 9.5
		var back := -10.5
		var left := -8.5
		var right := 8.5
		var street := true
		var garden := true
		var lone_right := true
		for j in pts.size():
			if j == i:
				continue
			var q: Vector2 = pts[j] - p
			var lx := q.dot(r)
			var ly := q.dot(f)
			if absf(lx) < 6.0 and ly > 5.0 and ly < 30.0:
				front = ly * 0.5
				street = false
			elif absf(lx) < 6.0 and ly < -5.0 and ly > -30.0:
				back = ly * 0.5
				garden = false
			elif absf(ly) < 6.0 and lx < -5.0 and lx > -30.0:
				left = maxf(left, lx * 0.5)
			elif absf(ly) < 6.0 and lx > 5.0 and lx < 30.0:
				right = minf(right, lx * 0.5)
				lone_right = false
		var w := func(x: float, y: float) -> Vector2: return p + r * x + f * y
		# Colorbond mostly; the odd lot with a timber paling fence
		var side := "Paling" if rng.randf() < 0.25 else "Colorbond"
		var cb: Color = PALINGS[rng.randi() % PALINGS.size()] if side == "Paling" else COLORBOND[rng.randi() % COLORBOND.size()]
		var slat: Color = SLATS[rng.randi() % SLATS.size()]
		if street:
			# a slatted front fence: the gate near one end, the driveway gate
			# at the other (the garage side)
			run(items, "SlatFence", w.call(left, front), w.call(left + 1.6, front), slat, ok, "FencePier")
			one(items, "PedGate", w.call(left + 2.45, front), r, slat)
			run(items, "SlatFence", w.call(left + 3.3, front), w.call(right - 4.65, front), slat, ok, "FencePier")
			one(items, "DrivewayGate", w.call(right - 2.33, front), r, slat)
		else:
			run(items, side, w.call(left, front), w.call(right, front), cb, ok)
		if garden:
			run(items, "PoolGlass", w.call(left, back), w.call(right, back), Color.WHITE, ok)
		run(items, side, w.call(left, back), w.call(left, front - (0.5 if street else 0.0)), cb, ok)
		if lone_right:
			run(items, side, w.call(right, back), w.call(right, front - (0.5 if street else 0.0)), cb, ok)

## The apartment blocks and terraces: a rendered low wall or a slat fence on
## a plinth round each, a few metres out, gaps where the paths go in.
static func _blocks(est: Dictionary, items: Array, ok: Callable, rng: RandomNumberGenerator) -> void:
	for b in est.get("blocks", []):
		var poly := PackedVector2Array()
		for q in b["pts"]:
			poly.append(Vector2(q[0], q[1]))
		var out := Geometry2D.offset_polygon(poly, 4.0, Geometry2D.JOIN_MITER)
		if out.is_empty():
			continue
		var ring: PackedVector2Array = out[0]
		var kind := "LowWall" if rng.randf() < 0.45 else "SlatFence"
		var col: Color = RENDER[rng.randi() % RENDER.size()] if kind == "LowWall" else SLATS[rng.randi() % SLATS.size()]
		for i in ring.size():
			run(items, kind, ring[i], ring[(i + 1) % ring.size()], col, ok, "FencePier" if kind == "SlatFence" else "")

# ------------------------------------------------------------------ car yards

## Chain-link round the car yard and the car park: where a road runs in,
## the yard's gate slid open beside it, or a boom at the car park.
static func _yards(est: Dictionary, items: Array, ok: Callable, road: Callable) -> void:
	for y in est.get("yards", []):
		var ring := PackedVector2Array()
		for q in y["pts"]:
			ring.append(Vector2(q[0], q[1]))
		var fence_ok := func(p: Vector2) -> bool: return ok.call(p) and not road.call(p, 1.0)
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			var dir := (b - a).normalized()
			for g in run(items, "ChainLink", a, b, Color.WHITE, fence_ok, "FencePost"):
				var g0: Vector2 = g[0]
				var g1: Vector2 = g[1]
				if g0.distance_to(g1) < 4.0 or g0.distance_to(g1) > 30.0:
					continue
				if y["kind"] == "car_park":
					one(items, "BoomGate", g0 + dir * 0.6, dir)
				else:
					# open: slid back behind the fence before the gap
					var at := g0 - dir * 3.0 + Vector2(-dir.y, dir.x) * 0.25
					if ok.call(at):
						one(items, "SlidingGate", at, dir)

# ------------------------------------------------------------------ the map's areas

## The sheds' yards (chain-link or palisade, a sliding gate open where the
## road goes in), the golf course's fence along the road, and timber
## bollards along the park's road edges.
static func _areas(d: Dictionary, items: Array, ok: Callable, road: Callable, rng: RandomNumberGenerator) -> void:
	var n := 0
	for ar in d.get("areas", []):
		var kind: String = ar["kind"]
		if not kind in ["industrial", "golf", "park"]:
			continue
		var ring := PackedVector2Array()
		for q in ar["pts"]:
			ring.append(Vector2(q[0], q[1]))
		if ring.size() > 2 and ring[0].is_equal_approx(ring[ring.size() - 1]):
			ring.remove_at(ring.size() - 1)
		var near := false
		for q in ring:
			if q.length() < NEAR:
				near = true
				break
		if not near:
			continue
		n += 1
		var model := "ChainLink"
		var post := "FencePost"
		var test: Callable
		match kind:
			"industrial":
				if n % 2 == 0:
					model = "Palisade"
					post = ""
				test = func(p: Vector2) -> bool: return p.length() < NEAR and ok.call(p) and not road.call(p, 1.0)
			"golf":
				test = func(p: Vector2) -> bool: return p.length() < NEAR and ok.call(p) and not road.call(p, 1.5) and road.call(p, 25.0)
			"park":
				model = "Bollards"
				post = ""
				test = func(p: Vector2) -> bool: return p.length() < NEAR and ok.call(p) and not road.call(p, 1.5) and road.call(p, 7.0)
		for i in ring.size():
			var a := ring[i]
			var b := ring[(i + 1) % ring.size()]
			if a.length() > NEAR + 60.0 and b.length() > NEAR + 60.0:
				continue
			var dir := (b - a).normalized()
			# a little inside the boundary, so neighbours' fences don't meet
			var into := Vector2(-dir.y, dir.x)
			if not Geometry2D.is_point_in_polygon((a + b) * 0.5 + into * 1.0, ring):
				into = -into
			var gaps := run(items, model, a + into * 0.5, b + into * 0.5, Color.WHITE, test, post)
			if kind != "industrial":
				continue
			for g in gaps:
				var g0: Vector2 = g[0]
				var g1: Vector2 = g[1]
				var w := g0.distance_to(g1)
				var mid := (g0 + g1) * 0.5
				if w > 4.0 and w < 20.0 and road.call(mid, 0.0) and rng.randf() < 0.8:
					var at := g0 - dir * 3.0 + into * 0.3
					if test.call(at):
						one(items, "SlidingGate", at, dir)

# ------------------------------------------------------------------ drawing

## A model's mesh, painted by part: "paint" takes each run's colour, "wire"
## is the chain-link shader.
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(name) as MeshInstance3D
	if mi == null:
		push_warning("fences: no model " + name)
		_meshes[name] = null
		return null
	var m := mi.mesh
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		m.surface_set_material(i, _mat(src.resource_name if src != null else ""))
	_meshes[name] = m
	return m

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if key == "paint":
		var s := ShaderMaterial.new()
		s.shader = preload("res://shaders/fence_paint.gdshader")
		m = s
	elif key == "wire":
		var s := ShaderMaterial.new()
		s.shader = preload("res://shaders/chainlink.gdshader")
		m = s
	else:
		m = F.color_mat(COLORS.get(key, Color.MAGENTA), false)
	_mats[key] = m
	return m

## Places `items` (each [model name, Transform3D, Color]) under `root`, as
## multimeshes by model and tile.
static func place(root: Node3D, items: Array) -> void:
	var groups := {}
	for it in items:
		var t: Transform3D = it[1]
		var key := "%s|%d|%d" % [it[0], floori(t.origin.x / TILE), floori(t.origin.z / TILE)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(it)
	var holder := Node3D.new()
	holder.name = "Fences"
	root.add_child(holder)
	for key in groups:
		var name: String = (key as String).split("|")[0]
		var m := mesh(name)
		if m == null:
			continue
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = m
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][1])
			mm.set_instance_color(i, list[i][2])
		var mi := MultiMeshInstance3D.new()
		mi.name = (key as String).replace("|", "_")
		mi.multimesh = mm
		mi.visibility_range_end = SEE
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
