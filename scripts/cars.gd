## The traffic round Riverlight on a weekday morning: cars, utes, vans and the
## odd bus driving the real roads (keeping left, turning round where the map
## ends); cars parked along the local streets; and the 2017 car yard over
## MacArthur Avenue and the riverside car park, packed with cars traced off
## the aerial (data/hamilton_reach_2017.json, tools/estate_to_game.py). The
## models are tools/blender/cars.py (assets/cars/cars.glb); scripts/
## surrounds.gd makes one of these with the map.
extends Node3D

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/cars/cars.glb"
const ESTATE := "res://data/hamilton_reach_2017.json"
const TILE := 80.0
const DETAIL := 260.0        # parked cars are full models this close to the camera, boxes past it
const DRIVE_R := 700.0       # roads this close to the site get traffic
const KERB_R := 380.0        # local streets this close get cars parked along them
const DRIVERS := 26
const ROADS := ["trunk", "secondary", "tertiary", "unclassified", "residential", "living_street"]

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
	if routes.is_empty():
		return
	for i in DRIVERS:
		var r: Dictionary = routes[rng.randi() % routes.size()]
		var bus := i < 2
		var name := "Bus" if bus else _kind(rng)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh(name)
		mi.set_instance_shader_parameter("tint", BUS if bus else PAINT[rng.randi() % PAINT.size()])
		mi.visibility_range_end = 900.0
		add_child(mi)
		var limit := 12.5 if r["kind"] == "trunk" else 10.0
		_drivers.append({"node": mi, "route": r, "s": rng.randf() * float(r["len"]), "dir": 1.0 if rng.randf() < 0.5 else -1.0,
			"speed": limit * rng.randf_range(0.75, 1.0) * (0.8 if bus else 1.0), "lane": float(r["w"]) * 0.25,
			"yaw": 0.0})
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

## Cars parked along the local streets near the site: a car in about a third
## of the 7 m spaces each side, clear of corners and street furniture.
static func _kerbs(d: Dictionary, keep_clear: Callable, taken: Callable, out: Array, rng: RandomNumberGenerator) -> void:
	for r in d["roads"]:
		if not r["kind"] in ["residential", "unclassified", "living_street"]:
			continue
		var pts: Array = r["pts"]
		var off := float(r["w"]) * 0.5 - 1.1
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
				for side: float in [1.0, -1.0]:
					if rng.randf() < 0.32:
						var p := a + u * s + n * off * side
						if keep_clear.call(p) and not taken.call(p):
							var face := u * (-side)   # nose the way that side's traffic goes (keep left)
							out.append([_kind(rng), Transform3D(Basis(Vector3.UP, atan2(face.x, face.y)), Vector3(p.x, 0, p.y)),
								PAINT[rng.randi() % PAINT.size()]])
				s += 7.0

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
	if cum[cum.size() - 1] > 120.0:
		out.append({"pts": pts, "cum": cum, "len": cum[cum.size() - 1], "kind": r["kind"], "w": float(r["w"])})

func _process(delta: float) -> void:
	for dv in _drivers:
		_drive(dv, delta)

func _drive(dv: Dictionary, delta: float) -> void:
	var r: Dictionary = dv["route"]
	var s: float = float(dv["s"]) + float(dv["speed"]) * float(dv["dir"]) * delta
	if s < 0.0 or s > float(r["len"]):
		# the map ends: come back the other way
		s = clampf(s, 0.0, float(r["len"]))
		dv["dir"] = -float(dv["dir"])
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
	p += Vector2(fwd.y, -fwd.x) * float(dv["lane"])
	var yaw := atan2(fwd.x, fwd.y)
	dv["yaw"] = yaw if delta == 0.0 else lerp_angle(float(dv["yaw"]), yaw, minf(1.0, delta * 4.0))
	var n: Node3D = dv["node"]
	n.position = Vector3(p.x, 0.02, p.y)
	n.rotation.y = float(dv["yaw"])
