## The traffic round Riverlight on a weekday morning: cars, utes, vans and the
## odd bus driving the real roads in their lanes (keeping left, one-way
## carriageways one way, turning onto the next road at a corner); cars parked
## in the streets' parking lanes; and the riverside car park, with cars traced
## off the aerial (data/hamilton_reach.json, tools/estate_to_game.py). The
## models are tools/blender/cars.py (assets/cars/cars.glb); scripts/
## surrounds.gd makes one of these with the map.
extends Node3D

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/cars/cars.glb"
const ESTATE := "res://data/hamilton_reach.json"
const TILE := 80.0
const DETAIL := 260.0        # parked cars are full models this close to the camera, boxes past it
const DRIVE_R := 700.0       # roads this close to the site get traffic
const KERB_R := 380.0        # local streets this close get cars parked along them
const DRIVERS := 26
const ROADS := ["trunk", "secondary", "tertiary", "unclassified", "residential", "living_street"]
const LANE_W := 3.2          # as tools/osm_to_game.py: a traffic lane and a kerb parking lane
const PARK_W := 2.2

## Brisbane car park colours: mostly white and silver, some dark, a few bright
const PAINT := [Color("f4f4f2"), Color("f4f4f2"), Color("f4f4f2"), Color("c4c8cc"), Color("c4c8cc"), Color("8d9196"),
	Color("2b2f36"), Color("1d1f24"), Color("1f3a5f"), Color("8c1c1c"), Color("d9302c"), Color("3a5f8f"), Color("e8e2d0"),
	Color("2f5f4f")]
const KINDS := [["Sedan", 0.3], ["Hatch", 0.22], ["SUV", 0.24], ["Ute", 0.16], ["Van", 0.08]]
const BUS := Color("f4f4f2")

static var _lib: Node
static var _meshes := {}
static var _mats := {}

var _drivers: Array = []
var _routes_all: Array = []
var _rng: RandomNumberGenerator

## `keep_clear(p)`: off the site; `taken(p)`: where street furniture stands;
## `road(p, pad)`: on (or within pad of) a road or path.
static func build(root: Node3D, d: Dictionary, keep_clear: Callable, taken: Callable, road: Callable,
		rng: RandomNumberGenerator) -> Node3D:
	var c: Node3D = (load("res://scripts/cars.gd") as GDScript).new()
	c.name = "Traffic"
	root.add_child(c)
	c.setup(d, keep_clear, taken, road, rng)
	return c

func setup(d: Dictionary, keep_clear: Callable, taken: Callable, road: Callable, rng: RandomNumberGenerator) -> void:
	var parked: Array = []
	if FileAccess.file_exists(ESTATE):
		var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ESTATE))
		for p in e.get("parked", []):
			var at := Vector2(p[0], p[1])
			if keep_clear.call(at) and not road.call(at, 1.5):
				parked.append([_kind(rng), Transform3D(Basis(Vector3.UP, deg_to_rad(float(p[2]))), Vector3(at.x, 0, at.y)),
					PAINT[rng.randi() % PAINT.size()]])
	_kerbs(d, keep_clear, taken, parked, rng)
	_place_parked(parked)
	var routes := _routes(d, keep_clear)
	_link(routes)
	var starts := routes.filter(func(r: Dictionary) -> bool: return float(r["len"]) > 60.0)
	if starts.is_empty():
		return
	_routes_all = routes
	_rng = RandomNumberGenerator.new()
	_rng.seed = rng.randi()
	for i in DRIVERS:
		var r: Dictionary = starts[rng.randi() % starts.size()]
		var bus := i < 2
		var name := "Bus" if bus else _kind(rng)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh(name)
		mi.set_instance_shader_parameter("tint", BUS if bus else PAINT[rng.randi() % PAINT.size()])
		mi.visibility_range_end = 900.0
		add_child(mi)
		var limit := 12.5 if r["kind"] == "trunk" else 10.0
		_drivers.append({"node": mi, "route": r, "s": rng.randf() * float(r["len"]),
			"dir": 1.0 if r["oneway"] or rng.randf() < 0.5 else -1.0,
			"speed": limit * rng.randf_range(0.75, 1.0) * (0.8 if bus else 1.0), "pick": rng.randf(), "yaw": 0.0})
		_drive(_drivers[-1], 0.0)

static func _kind(rng: RandomNumberGenerator) -> String:
	var x := rng.randf()
	for k in KINDS:
		x -= float(k[1])
		if x <= 0.0:
			return k[0]
	return "Sedan"

# ------------------------------------------------------------------ models

## A model's mesh, painted by part; "body" takes each car's own colour.
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(name) as MeshInstance3D
	if mi == null:
		push_warning("cars: no model " + name)
		_meshes[name] = null
		return null
	var m := mi.mesh
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		m.surface_set_material(i, _mat(src.resource_name if src != null else ""))
	_meshes[name] = m
	return m

## Car paint: toon, coloured per instance (a multimesh's instance colour or
## a lone car's `tint`).
static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if key == "body":
		var s := ShaderMaterial.new()
		s.shader = preload("res://shaders/car_paint.gdshader")
		m = s
	else:
		var c: Color = {"glass": Color("2c3a46"), "tyre": Color("222222"), "rim": Color("a9b0b5"), "light": Color("fff4d0"),
			"tail": Color("c8282a"), "trim": Color("2a2d31"), "plate": Color("f4f4f2"), "rack": Color("8d9196"),
			"bus_band": Color("f2c14e")}.get(key, Color.MAGENTA)
		m = F.color_mat(c, false)
	_mats[key] = m
	return m

# ------------------------------------------------------------------ parked

## Cars parked in the streets' parking lanes near the site: a car in about a
## third of the 7 m spaces, on both kerbs (the left one on a one-way
## carriageway), clear of corners, street furniture and the council's No
## Stopping lines, bus bays and loading zones.
static func _kerbs(d: Dictionary, keep_clear: Callable, taken: Callable, out: Array, rng: RandomNumberGenerator) -> void:
	var no_park: Array = []
	for ln in d.get("no_park", []):
		for i in (ln as Array).size() - 1:
			no_park.append([Vector2(ln[i][0], ln[i][1]), Vector2(ln[i + 1][0], ln[i + 1][1])])
	for r in d["roads"]:
		var park := int(r.get("park", 0))
		if park == 0:
			continue
		var pts: Array = r["pts"]
		var off := float(r["w"]) * 0.5 - PARK_W * 0.5
		# (n is the right of the way's direction: a one-way's parking lane is on its left)
		var sides: Array = [1.0, -1.0] if park == 2 else [-1.0]
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			if a.length() > KERB_R and b.length() > KERB_R:
				continue
			var e := b - a
			var ln := e.length()
			if ln < 20.0:
				continue
			var u := e / ln
			var n := Vector2(-u.y, u.x)
			var s := 9.0
			while s < ln - 9.0:
				for side: float in sides:
					if rng.randf() < 0.32:
						var p := a + u * s + n * off * side
						if keep_clear.call(p) and not taken.call(p) and not _near_any(p, no_park, 3.5):
							var face := u * (-side)   # nose the way that side's traffic goes (keep left)
							out.append([_kind(rng), Transform3D(Basis(Vector3.UP, atan2(face.x, face.y)), Vector3(p.x, 0, p.y)),
								PAINT[rng.randi() % PAINT.size()]])
				s += 7.0

static func _near_any(p: Vector2, segs: Array, dist: float) -> bool:
	for sg in segs:
		if Geometry2D.get_closest_point_to_segment(p, sg[0], sg[1]).distance_to(p) < dist:
			return true
	return false

## Parked cars as multimeshes by tile: the models close up, boxes further off.
func _place_parked(items: Array) -> void:
	var groups := {}
	for it in items:
		var t: Transform3D = it[1]
		var key := "%s|%d|%d" % [it[0], floori(t.origin.x / TILE), floori(t.origin.z / TILE)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(it)
	for key in groups:
		var name: String = (key as String).split("|")[0]
		var far := {"Sedan": "SedanFar", "Hatch": "SedanFar", "SUV": "SUVFar", "Ute": "UteFar", "Van": "SUVFar"}[name] as String
		for lod in [[name, 0.0, DETAIL], [far, DETAIL, 2500.0]]:
			var m := mesh(lod[0])
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
			mi.name = "Parked_" + (key as String).replace("|", "_") + ("_far" if lod[1] > 0.0 else "")
			mi.multimesh = mm
			mi.visibility_range_begin = lod[1]
			mi.visibility_range_end = lod[2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)

# ------------------------------------------------------------------ driving

## The roads near the site as routes to drive up and down, cut where they'd
## cross the site.
static func _routes(d: Dictionary, keep_clear: Callable) -> Array:
	var out: Array = []
	for r in d["roads"]:
		if not r["kind"] in ROADS:
			continue
		var run := PackedVector2Array()
		for q in r["pts"]:
			var v := Vector2(q[0], q[1])
			if v.length() < DRIVE_R and keep_clear.call(v):
				run.append(v)
			else:
				_add_route(out, run, r)
				run = PackedVector2Array()
		_add_route(out, run, r)
	return out

static func _add_route(out: Array, pts: PackedVector2Array, r: Dictionary) -> void:
	if pts.size() < 2:
		return
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	if cum[cum.size() - 1] > 1.0:
		out.append({"pts": pts, "cum": cum, "len": cum[cum.size() - 1], "kind": r["kind"], "w": float(r["w"]),
			"oneway": bool(r.get("oneway", false)), "lanes": int(r.get("lanes", 0)), "park": int(r.get("park", 0)),
			"next": [], "prev": []})

static func _key(p: Vector2) -> String:
	return "%d,%d" % [roundi(p.x * 2.0), roundi(p.y * 2.0)]

## Which roads go on from each end, so a car runs on round the corner instead
## of turning round where one bit of the map stops: [route, entering forwards].
static func _link(routes: Array) -> void:
	var at := {}
	for r in routes:
		var pts: PackedVector2Array = r["pts"]
		for end in [0, 1]:
			var k := _key(pts[0] if end == 0 else pts[pts.size() - 1])
			if not at.has(k):
				at[k] = []
			at[k].append([r, end])
	for r in routes:
		var pts: PackedVector2Array = r["pts"]
		for end in [0, 1]:
			var list: Array = []
			for o in at.get(_key(pts[0] if end == 0 else pts[pts.size() - 1]), []):
				if is_same(o[0], r):
					continue
				var fwd: bool = o[1] == 0
				# (a one-way is only driven from its start)
				if o[0]["oneway"] and not fwd:
					continue
				list.append([o[0], fwd])
			r["next" if end == 1 else "prev"] = list

## How far left of the way's line a car drives: in its lane (the left one on a
## two-way street, the travel lane beside the parking lane on a one-way).
static func _lane(r: Dictionary, pick: float) -> float:
	var w := float(r["w"])
	var lanes := int(r["lanes"])
	if r["oneway"]:
		if lanes == 0:
			lanes = maxi(1, floori(w / 3.5))
		var i := mini(floori(pick * lanes), lanes - 1)
		var lw := (w - int(r["park"]) * PARK_W) / lanes
		return w * 0.5 - int(r["park"]) * PARK_W - lw * (i + 0.5)
	if lanes == 0:
		return w * 0.25
	return LANE_W * 0.5

func _process(delta: float) -> void:
	for dv in _drivers:
		_drive(dv, delta)

func _drive(dv: Dictionary, delta: float) -> void:
	var r: Dictionary = dv["route"]
	var s: float = float(dv["s"]) + float(dv["speed"]) * float(dv["dir"]) * delta
	if s < 0.0 or s > float(r["len"]):
		var over := -s if s < 0.0 else s - float(r["len"])
		var on: Array = r["next"] if s > 0.0 else r["prev"]
		if not on.is_empty():
			# round the corner onto the next road
			var o: Array = on[_rng.randi() % on.size()]
			r = o[0]
			dv["route"] = r
			dv["dir"] = 1.0 if o[1] else -1.0
			s = over if o[1] else float(r["len"]) - over
		elif not r["oneway"]:
			# the map ends: come back the other way
			s = clampf(s, 0.0, float(r["len"]))
			dv["dir"] = -float(dv["dir"])
		else:
			# (a one-way that runs off the map: come back in at the start of
			# another road well away from the site, out of sight)
			var far := _routes_all.filter(func(q: Dictionary) -> bool:
				return q["oneway"] and (q["pts"] as PackedVector2Array)[0].length() > 450.0 and float(q["len"]) > 40.0)
			if far.is_empty():
				s = 0.0
			else:
				r = far[_rng.randi() % far.size()]
				dv["route"] = r
				dv["dir"] = 1.0
				s = 0.0
	dv["s"] = s
	var cum: PackedFloat32Array = r["cum"]
	var pts: PackedVector2Array = r["pts"]
	var i := 1
	while i < cum.size() - 1 and cum[i] < s:
		i += 1
	var a := pts[i - 1]
	var b := pts[i]
	var p := a.lerp(b, clampf((s - cum[i - 1]) / maxf(cum[i] - cum[i - 1], 0.001), 0.0, 1.0))
	var fwd := (b - a).normalized() * float(dv["dir"])
	# keep left
	p += Vector2(fwd.y, -fwd.x) * _lane(r, float(dv["pick"]))
	var yaw := atan2(fwd.x, fwd.y)
	dv["yaw"] = yaw if delta == 0.0 else lerp_angle(float(dv["yaw"]), yaw, minf(1.0, delta * 4.0))
	var n: Node3D = dv["node"]
	n.position = Vector3(p.x, 0.02, p.y)
	n.rotation.y = float(dv["yaw"])
